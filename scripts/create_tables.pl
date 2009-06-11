#!/usr/bin/env perl
#
#  $Source: /opt/cvsroot/projects/Spamity/scripts/create_tables.pl,v $
#  $Name:  $
#
#  Copyright (c) 2006, 2007
#
#  Author: Francis Lachapelle <francis@Sophos.ca>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details
#
#  This script creates multiple tables in your PostgreSQL or MySQL database.
#  If you currently have a single, populated table, it will also inserts the
#  entries from this initial single spamity table in the new tables.
#  This script will not delete your current spamity table.
#
#  Using mulitple tables usually result in speed improvement for your users.
#  However, statistic graphs for administrators can take a while to generate.
#

use Spamity qw(conf logPrefix userKey);
use Spamity::Database;

################################################################################
# Configuration parameters
################################################################################

my $DROP_BEFORE_CREATE = 1;
my $MIGRATE_DATA = 1;

# NOTES:
#
# - The number of tables to create/populate is defined in the main configuration
#   file /etc/spamity.conf. The parameter is named "tables_count".
# - The entries associated to unknown recipients are migrated to a specific
#   table, "spamity_unknown".

################################################################################
# You should not have to modify anything bellow this line.
################################################################################

my %sqlcreate;
$sqlcreate{'pgsql'} = <<'CREATE';
CREATE TABLE %s (
  id serial,
  logdate timestamp,
  username varchar(64),
  host varchar(64),
  to_user varchar(64),
  to_host varchar(64),
  from_user varchar(64),
  from_host varchar(64),
  filter_type varchar(64),
  filter_id varchar(128),
  description text,
  rawsource bytea,
  primary key (id)
)
CREATE
$sqlcreate{'mysql'} = <<'CREATE';
CREATE TABLE %s (
  id int unsigned not null auto_increment,
  logdate timestamp,
  username varchar(64),
  host varchar(64),
  to_user varchar(64),
  to_host varchar(64),
  from_user varchar(64),
  from_host varchar(64),
  filter_type varchar(64),
  filter_id varchar(128),
  description text,
  rawsource blob,
  primary key (id)
)
CREATE
$sqlcreate{'oracle'} = <<'CREATE';
CREATE TABLE %s (
  id number(9) primary key,
  logdate timestamp,
  username varchar2(64),
  host varchar2(64),
  to_user varchar2(64),
  to_host varchar2(64),
  from_user varchar2(64),
  from_host varchar2(64),
  filter_type varchar2(64),
  filter_id varchar2(128),
  description varchar2(512),
  rawsource blob
)
CREATE

my %predrop;
$predrop{'oracle'} =
    [ 'DROP TRIGGER %s_id_trigger' ];

my %postdrop;
$postdrop{'oracle'} =
    [ 'DROP SEQUENCE seq_%s_id' ];

my %postcreate;
$postcreate{'pgsql'} =
    [ 'CREATE INDEX spamity_%s_logdate_index ON spamity_%s (logdate)',
      'CREATE INDEX spamity_%s_username_index ON spamity_%s (username)' ];
$postcreate{'oracle'} =
    [ 'CREATE SEQUENCE seq_%s_id
        START WITH 1
        INCREMENT BY 1
        NOMAXVALUE',
      'CREATE TRIGGER %s_id_trigger
        BEFORE INSERT ON %s
        FOR EACH ROW
        BEGIN
          SELECT seq_%s_id.NEXTVAL INTO :new.id FROM dual;
        END %s_id_trigger;' ];

my $db;
my $sth;
my $row;
my $changed;
my $i;
my $create;
my $username;
my $count;
my @table_suffixes = (1 .. &conf('tables_count', 1), 'unknown');

# Verify configuration
unless (&conf('tables_count', 1)) {
    die "Error: Your installation of Spamity is not currently configured to use multiple tables.\nSet the parameter 'tables_count' in /etc/spamity.conf.\n";
}

# Set STDOUT unbuffered
$| = 1;

# Establish database connection
die $Spamity::Database::message unless ($db = Spamity::Database->new(database => 'spamity'));

# Create tables
foreach $i (@table_suffixes) {
    $create = 1;
    $tablename = "spamity_$i";

    # Verify if the table exists
    if (($sth = $db->dbh->prepare("select min(id) from $tablename")) && 
        $sth->execute &&
        $sth->fetchrow_hashref) {
        if ($DROP_BEFORE_CREATE) {
            print "Dropping table $tablename\n";
            if ($predrop{$db->{_module}}) {
                foreach (@{$predrop{$db->{_module}}}) {
                    my $stmt = $_; $stmt =~ s/%s/$tablename/g;
                    warn $db->dbh->errstr unless $db->dbh->do($stmt);
                }
            }
            die $db->dbh->errstr unless $db->dbh->do("DROP TABLE $tablename");
            if ($postdrop{$db->{_module}}) {
                foreach (@{$postdrop{$db->{_module}}}) {
                    my $stmt = $_; $stmt =~ s/%s/$tablename/g;
                    warn $db->dbh->errstr unless $db->dbh->do($stmt);
                }
            }
        }
        else {
            print "Table $tablename already exists; skipping\n";
            $create = 0;
        }
    }

    if ($create) {
        print "Creating table $tablename\n";
        die $db->dbh->errstr unless $db->dbh->do(sprintf($sqlcreate{$db->{_module}}, $tablename));
        die $db->dbh->errstr unless $db->dbh->do(sprintf("CREATE INDEX spamity_%s_logdate_index on %s (logdate)",$i,$tablename));
        die $db->dbh->errstr unless $db->dbh->do(sprintf("CREATE INDEX spamity_%s_username_index on %s (username)",$i,$tablename));
        if ($postcreate{$db->{_module}}) {
            foreach (@{$postcreate{$db->{_module}}}) {
                my $stmt = $_; $stmt =~ s/%s/$tablename/g; print "$stmt\n";
                die $db->dbh->errstr unless $db->dbh->do($stmt);
            }
        }
    }
}

# Stop here if we don't migrate the data
exit unless $MIGRATE_DATA;

# Verify fields length
print "Verifying length of fields ..\n";
my $too_long = 0;
unless ($sth = $db->dbh->prepare(sprintf('SELECT username, %s AS email FROM spamity WHERE char_length(username) > 64 OR char_length(to_user) > 64 OR char_length(to_host) > 64', $db->concatenate(qw/to_user '@' to_host/)))) {
    die "The table named 'spamity' doesn't seem to exist; no data was migrated.\n";
}
if ($sth->execute()) {
    if ($row = $sth->fetchrow_hashref) {
        $too_long = 1;
        print "Username of email address too long for user \"",$row->{username},"\" (",$row->{email},")\n";
    }
}
die "Can't truncate fields\n" if ($too_long);

# Populate the tables
print "Selecting unique usernames .. (this may take a while)\n";
my %buckets;
my $bucket;
my $sth_count;
my $sth_insert;
$sth = $db->dbh->prepare('SELECT username, count(*) AS count FROM spamity GROUP BY username');
if ($sth->execute()) {
    my $users, $total;
    my $username, $count;
    my $cur_count;
    
    $users = $sth->fetchall_arrayref([0,1]);
    $i = 0;
    $total = $#$users + 1;
    $j = int($total/100);
    print "\t",$total," users\n";
    
    foreach $row (@$users) {
        ($username, $count) = @$row;
        $i += 1;

        # Print progress every interval of 1%
        print int($i/$total*100),"%" if (($i % $j) == 0);

        if ($username eq &conf('unknown_recipient')) {
            # Expect a lot of entries; place unknown recipient spam in its own table.
            $bucket = 'unknown';
        }
        else {
            # Compute the user hask key
            $bucket = &userKey($username);
        }

        # Verify if the user has already been migrated (simply based on rows count)
        $sth_count = $db->dbh->prepare(sprintf('SELECT count(*) FROM spamity_%s WHERE username = ?',$bucket));
        if ($sth_count->execute($username)) {
            $cur_count = $sth_count->fetchrow_arrayref;
            if ($$cur_count[0] == $count) {
#               print $username," => already migrated (",$count,")\n";
                print ",";
                next;
            }
        }
#       print $username," => $bucket\n";
        print ".";

        # Peform the SQL insertion
        $sth_insert = $db->dbh->prepare(sprintf('INSERT INTO spamity_%s (logdate, username, to_user, to_host, from_user, from_host, filter_type, filter_id, description, rawsource) SELECT logdate, username, to_user, to_host, substring(from_user from 0 for 64), substring(from_host from 0 for 64), filter_type, filter_id, description, rawsource FROM spamity WHERE username = ?',$bucket));
        die $dbh->errstr unless $sth_insert->execute($username);
    }
}

print "\nDone!\n";

# Print tables size
my $total = 0;
foreach $i (@table_suffixes) {
    $sth = $db->dbh->prepare("SELECT count(*) FROM spamity_$i");
    if ($sth->execute()) {
        $count = $sth->fetchrow_arrayref;
        $total += $$count[0];
        print "spamity_$i\t",$$count[0],"\n";
    }
}
print "\nTotal: $total rows migrated.\n";
$sth = $db->dbh->prepare("SELECT count(*) FROM spamity");
if ($sth->execute()) {
    $count = $sth->fetchrow_arrayref;
    if ($$count[0] != $total) {
        die "Inconsistent number of rows: $total rows in new tables, ",$$count[0]," rows in spamity table.\n";
    }
}

print "You may now delete table 'spamity'\n";

$db->dbh->disconnect;

exit 0;

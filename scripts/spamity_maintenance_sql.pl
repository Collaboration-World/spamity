#!/usr/bin/env perl
#
#  $Source: /opt/cvsroot/projects/Spamity/scripts/spamity_maintenance_sql.pl,v $
#  $Name:  $
#
#  Copyright (c) 2006
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
# This script removes messages older than X days from the database.
# The number of days must be specified at the command-line.
#

# Uncomment and modify the following line if you installed Spamity's Perl modules
# and/or dependent modules in some non-standard directory.
#
# use lib '/opt/spamity/lib';

use Spamity qw(conf);
use Spamity::Database;
use POSIX qw(strftime);

my $db;
my $days;
my $stmt;
my $sth;
my @table_suffixes = ('');
my $total = 0;
my $rows;

# Set STDOUT unbuffered
$| = 1;

# Verify command-line argument
if ($#ARGV < 0) {
    die "Usage: $0 <number-of-days-to-keep>\n";
}
$days = $ARGV[0];

# Establish database connection
die $Spamity::Database::message unless ($db = Spamity::Database->new(database => 'spamity'));

# Table suffixes
if (&conf('tables_count', 1)) {
    @table_suffixes = (1 .. &conf('tables_count'), 'unknown');
    @table_suffixes = map ("_$_", @table_suffixes);
}

# Prepare SQL statement
$stmt = 'delete from %s where not ('
    . $db->getAfterByDay('logdate', strftime('%Y-%m-%d', localtime()), $days)
    . ')';

format STDOUT_TOP =

Table                   Number of messages deleted
--------------------------------------------------
.
format STDOUT =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>>>>>>>>>
$tablename, int($rows)
.


# Delete entries
foreach $i (@table_suffixes) {
    $tablename = "spamity$i";
    print sprintf($stmt,$tablename),"\n" if (int(&Spamity::conf('log_level')) > 0);
    $sth = $db->dbh->prepare(sprintf($stmt,$tablename));
    if ($rows = $sth->execute()) {
	if ($sth->rows() > 0) {
	    $rows = $sth->rows();
	}
	$total += $rows;
	write;
    }
    else {
	warn logPrefix, 'Database error: '.$DBI::errstr.' ('.$DBI::err.')';
    }
}

print "--------------------------------------------------\n";
$tablename = "Total";
$rows= $total;
write;

$db->dbh->disconnect;

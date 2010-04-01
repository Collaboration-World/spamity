#!/usr/bin/perl
#
#  $Source:  $
#  $Name:  $
#
#  Copyright (c) 2004-2007, 2010
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

# 
# Note: This module currently assumes the tables used my AMaViSd-new
# to be in the same database as the tables used by Spamity. Therefore,
# it uses the same database handler. It should and will eventually
# changed.
#

package Spamity::Preference::amavisdnew;

use DBD::Pg;


sub _setList
{
    my $user_id;
    my $chars;
    my $addresses_ref;
    my @addresses_arr = ();
    my $address;
    my $db;
    my $stmt;
    my ($sth, $sth_seq, $sth_update);
    my $row;
    my $id;

    ($user_id, $chars, $addresses_ref) = @_;

    $db = Spamity::Database->new(database => 'amavisd-new');

    if ($db && int($user_id)) {
	# Delete previous list	
	my $addresses_prev = &_getList($chars, $user_id);
	
	return \@addresses_arr if (!keys(%$addresses_prev) && !@$addresses_ref);

	my @common = ();
	my @new = ();
	foreach $address (@$addresses_ref) {
	    next if $address =~ m/^$/;
	    if (exists $addresses_prev->{$address}) {
		push(@common, $addresses_prev->{$address});
		push(@addresses_arr, $address);
	    }
	    else {
		push(@new, "'$address'");
	    }
	}

	# Delete removed addresses
	if (@common > 0) {
	    $stmt = sprintf('delete from %s where rid = ? and wb in (%s) and sid not in (%s)',
			    &conf('amavisd-new_table_wblist'), join(',',@$chars), join(',', @common));
	}
	else {
	    $stmt = sprintf('delete from %s where rid = ? and wb in (%s)',
			    &conf('amavisd-new_table_wblist'), join(',',@$chars));
	}
	$sth = $db->dbh->prepare($stmt);
	if (!$sth->execute($user_id)) {
	    $message = 'Delete-statement error: '.$DBI::errstr.' ('.$DBI::err.').';
	    warn logPrefix, "Spamity::Preference::amavisdnew::pgsql _setList $message";
	}
	
	if (@new > 0) {
	
	    # Search for addresses ids
	    my %addresses;
	    $stmt = sprintf('select id, email from %s where email in (%s)',
			    &conf('amavisd-new_table_mailaddr'), join(',', @new));
	    $sth = $db->dbh->prepare($stmt);
	    if ($sth->execute()) {
		while ($row = $sth->fetchrow_arrayref) {
		    $addresses{$$row[1]} = $$row[0];
		}
	    }
	    else {
		$message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.').';
		warn logPrefix, "Spamity::Preference::amavisdnew::pgsql _setList $message";
	    }
	    
	    my $size = @new;
	    if (keys(%addresses) < $size) {
		# Add missing addresses to table mailaddr
		$stmt = sprintf("select nextval('%s_id_seq')",
				&conf('amavisd-new_table_mailaddr'));
		$sth_seq = $db->dbh->prepare($stmt);
		
		$stmt = sprintf('insert into %s (id, email) values (?, ?)',
				&conf('amavisd-new_table_mailaddr'));
		$sth = $db->dbh->prepare($stmt);

		foreach $address (@new) {
		    $address =~ s/^\'(.+)\'$/$1/;
		    next if exists($addresses{$address});
		    # Get next id from mailaddr sequence
		    $id = undef;
		    if ($sth_seq->execute()) {
			if ($row  = $sth_seq->fetchrow_arrayref) {
			    $id = $$row[0];
			}
		    }
		    if (!defined($id)) {
			# error
			return 0;
		    }
		    if (!$sth->execute($id, $address)) {
			# error
			return 0;
		    }
		    $addresses{$address} = $id;
		}
	    }
	    
	    # Insert new addresses
	    $stmt = sprintf('insert into %s (rid, sid, wb) values (?, ?, %s)',
			    &conf('amavisd-new_table_wblist'), $$chars[0]);
	    $sth = $db->dbh->prepare($stmt);
	    while (($address, $id) = each(%addresses)) {
		if (!$sth->execute($user_id, $id)) {
		    # Address probably in the 'other' list; update entry
		    $stmt = sprintf('update %s set wb = %s where rid = ? and sid = ?',
				    &conf('amavisd-new_table_wblist'), $$chars[0]);
		    $sth_update = $db->dbh->prepare($stmt);
		    if ($sth_update->execute($user_id, $id)) {
			push(@addresses_arr, $address);
		    }
		    else {
			$message = 'Insert-statement error: '.$DBI::errstr.' ('.$DBI::err.').';
			warn logPrefix, "Spamity::Preference::amavisdnew::pgsql _setList $message";
		    }
		}
		else {
		    push(@addresses_arr, $address);
		}
	    }
	}

	# Clean unused addresses
	$stmt = 'delete from mailaddr where mailaddr.id not in (select sid from wblist)';
	$sth = $db->dbh->prepare($stmt);
	if (!$sth->execute()) {
	    $message = 'Delete-statement error: '.$DBI::errstr.' ('.$DBI::err.').';
	    warn logPrefix, "Spamity::Preference::amavisdnew::pgsql _setList $message";
	}
	
	@addresses_arr = sort(@addresses_arr);
	return \@addresses_arr;
    }
    
    return 0;
} # _setList


sub getPolicyColumns
{
    my @columns = ();
    my $db;
    my $sth;
    my $row;

    $db = Spamity::Database->new(database => 'amavisd-new');

    if ($db) {
	$sth = $db->dbh->column_info('%', '%', &conf('amavisd-new_table_policy'), '%');
	while ($row = $sth->fetchrow_hashref(NAME_lc)) {
	    #warn logPrefix, join(' ',keys(%$row));
	    push(@columns, $row->{COLUMN_NAME}) if (exists($COLUMNS{$row->{COLUMN_NAME}}));
	}
	$sth->finish();

	if (!@columns) {
	    # The driver didn't return any information with the 'column_info' function;
	    # Query the database's catalog.
	    $sth = $db->dbh->prepare('select a.attname from pg_class as c, pg_attribute as a where c.oid = a.attrelid and c.relname = ?');
	    if ($sth->execute(&conf('amavisd-new_table_policy'))) {
		while ($row = $sth->fetchrow_arrayref) {
		    push(@columns, $$row[0]) if (exists($COLUMNS{$$row[0]}));
		}
	    }
	}
    }
    
    return undef if (!@columns);

    return \@columns;
} # getPolicyColumns


sub insertPolicy
{
    my $columns;
    my $values;
    my $policy_id;
    my $db;
    my $stmt;
    my $sth;

    ($columns, $values) = @_;

    return 0 unless ($db = Spamity::Database->new(database => 'amavisd-new'));

    # Get next id from policy sequence
    $stmt = sprintf("select nextval('%s_id_seq')",
		    &conf('amavisd-new_table_policy'));
    $sth = $db->dbh->prepare($stmt);
    if ($sth->execute()) {
	if (my $row  = $sth->fetchrow_arrayref) {
	    $policy_id = $$row[0];
	}
    }
    if (!int($policy_id)) {
	# Error!
	return 0;
    }
    
    push(@$columns, 'id');
    push(@$values, $policy_id);

    my @s = ();
    foreach (@$columns) { push(@s, '?'); }
    $stmt = sprintf('insert into %s (%s) values (%s)',
		    &conf('amavisd-new_table_policy'), join(', ', @$columns), join(', ', @s));
    $sth = $db->dbh->prepare($stmt);
    for (my $i = 0; $i < @$values; $i++) {
	$sth->bind_param($i+1, $$values[$i]);
    }
    if (!$sth->execute()) {
	$message = 'SQL-statement error: '.$DBI::errstr.' ('.$DBI::err.').';
	warn logPrefix, "Spamity::Preference::amavisdnew::pgsql insertPolicy $message";
	return 0;
    }

    return $policy_id;
} # insertPolicy


1;

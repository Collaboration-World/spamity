#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/lib/Spamity/Preference/amavisdnew/mysql.pm,v $
#  $Name:  $
#
#  Copyright (c) 2005, 2006
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

use DBD::mysql;


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
	    warn logPrefix, "Spamity::Preference::amavisdnew::mysql _setList $message";
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
		warn logPrefix, "Spamity::Preference::amavisdnew::mysql _setList $message";
	    }
	    
	    my $size = @new;
	    if (keys(%addresses) < $size) {
		# Add missing addresses to table mailaddr
		$stmt = 'select last_insert_id()';
		$sth_seq = $db->dbh->prepare($stmt);
		
		$stmt = sprintf('insert into %s (email) values (?)',
				&conf('amavisd-new_table_mailaddr'));
		$sth = $db->dbh->prepare($stmt);

		foreach $address (@new) {
		    $address =~ s/^\'(.+)\'$/$1/;
		    next if exists($addresses{$address});
		    if (!$sth->execute($address)) {
			# error
			return 0;
		    }
		    # Get id for last mailaddr entry
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
			warn logPrefix, "Spamity::Preference::amavisdnew::mysql _setList $message";
		    }
		}
		else {
		    push(@addresses_arr, $address);
		}
	    }
	}

	# Clean unused addresses
	$stmt = 'delete mailaddr from mailaddr left join wblist on mailaddr.id = wblist.sid where wblist.sid is null';

	warn "[DEBUG SQL] Spamity::Preference::amavisdnew _setList (mysql) $stmt\n" if (int(&conf('log_level')) > 0);

	$sth = $db->dbh->prepare($stmt);
	unless ($sth->execute()) {
	    $message = 'Delete-statement error: '.$DBI::errstr.' ('.$DBI::err.').';
	    warn logPrefix, "Spamity::Preference::amavisdnew::mysql _setList $message";
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

    # Query the database's catalog.
    if ($db) {
	$sth = $db->dbh->prepare('describe '.&conf('amavisd-new_table_policy'));
	if ($sth->execute()) {
	    while ($row = $sth->fetchrow_arrayref) {
		push(@columns, $$row[0]) if (exists($COLUMNS{$$row[0]}));
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
    my $policy_id = 0;
    my $db;
    my $stmt;
    my $sth;

    ($columns, $values) = @_;
    
    return 0 unless ($db = Spamity::Database->new(database => 'amavisd-new'));

    my @s = ();
    foreach (@$columns) { push(@s, '?'); }
    $stmt = sprintf('insert into %s (%s) values (%s)',
		    &conf('amavisd-new_table_policy'), join(', ', @$columns), join(', ', @s));
    
    warn "[DEBUG SQL] Spamity::Preference::amavisdnew insertPolicy (mysql) $stmt\n" if (int(&conf('log_level')) > 0);

    $sth = $db->dbh->prepare($stmt);
    for (my $i = 0; $i < @$values; $i++) {
	$sth->bind_param($i+1, $$values[$i]);
    }
    if (!$sth->execute()) {
	$message = 'Insert-statement error: '.$DBI::errstr.' ('.$DBI::err.').';
	warn logPrefix, "Spamity::Preference::amavisdnew::mysql insertPolicy $message";
	return 0;
    }
    # Retrieve new policy id
    $stmt = 'select last_insert_id()';
    $sth = $db->dbh->prepare($stmt);
    if (!$sth->execute()) {
	$message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.').';
	warn logPrefix, "Spamity::Preference::amavisdnew::mysql insertPolicy $message";
	return 0;
    }
    if (my $row  = $sth->fetchrow_arrayref) {
	$policy_id = $$row[0];
    }
    
    return $policy_id;
    
} #insertPolicy


1;

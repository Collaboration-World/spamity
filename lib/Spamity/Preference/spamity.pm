#!/usr/bin/perl
#
#  $Source$
#  $Name$
#
#  Copyright (c) 2007
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

package Spamity::Preference::spamity;


use Spamity qw(conf logPrefix);
use Spamity::Database;


BEGIN {
    use Exporter;
    @Spamity::Preference::spamity::ISA = qw(Exporter);
    @Spamity::Preference::spamity::EXPORT = qw();
    @Spamity::Preference::spamity::EXPORT_OK = qw($message getPrefs setPrefs);
}
use vars qw($message);

$message = undef;


sub getPrefs
{
    my $username;

    my $db;
    my $prefs = undef;
    my $stmt;
    my $sth;

    ($username) = @_;
    $username = lc($username);
    
    if ($db = Spamity::Database->new(database => 'spamity_prefs')) {
	$stmt = 'select * from spamity_prefs where username = ?';
	warn "[DEBUG SQL] Spamity::Preference::spamity getPrefs $stmt [$username]\n" if (int(&conf('log_level')) > 0);
	$sth = $db->dbh->prepare($stmt);
	if ($sth->execute($username)) {
	    $prefs = $sth->fetchrow_hashref();
	    if (defined $prefs) {
		$prefs->{active} = 1;
	    }
	    else {
		# No preferences for user
		$prefs = {};
	    }
	}
	else {
	    $message = 'Select-statement error: '.$DBI::errstr;
	    warn logPrefix, "Spamity::Preference::spamity getPrefs $message\n";
	}
    }

    return $prefs;
}


sub setPrefs
{
    my $username;
    my @vars;

    my $stmt;
    my $sth;
    
    ($username, @vars) = @_;
    $username = lc($username);

    if ($db = Spamity::Database->new(database => 'spamity_prefs')) {
	# Delete previous prefs
	$stmt = 'delete from spamity_prefs where username = ?';
	warn "[DEBUG SQL] Spamity::Preference::spamity setPrefs $stmt [$username]\n" if (int(&conf('log_level')) > 0);
	$sth = $db->dbh->prepare($stmt);
	unless ($sth->execute($username)) {
	    $message = 'Delete-statement error: '.$DBI::errstr;
	    warn logPrefix, "Spamity::Preference::spamity setPrefs $message\n";
	    return 0;
	}
	
	if (@vars > 0) {
	    # Set new preferences
	    $stmt = 'insert into spamity_prefs (username, lang, report_freq_day, email) values (?, ?, ?, ?)';
	    warn "[DEBUG SQL] Spamity::Preference::spamity setPrefs $stmt [$username, ".join(", ",@vars)."]\n" if (int(&conf('log_level')) > 0);
	    $sth = $db->dbh->prepare($stmt);
	    if (!$sth->execute($username, @vars)) {
		$message = 'Insert-statement error: '.$DBI::errstr;
		warn logPrefix, "Spamity::Preference::spamity setPrefs $message\n";
		return 0;
	    }
	}
    }
    
    return 1;
}

1;

#!/usr/bin/env perl
#
#  $Source: /opt/cvsroot/projects/Spamity/scripts/sessions_maintenance_sql.pl,v $
#  $Name:  $
#
#  Copyright (c) 2006-2009
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
# This script removes expired session from the database.
#
# See http://article.gmane.org/gmane.comp.lang.perl.modules.cgi-session.user/30

# Uncomment and modify the following line if you installed Spamity's Perl modules
# and/or dependent modules in some non-standard directory.
#
# use lib '/opt/spamity/lib';

use Spamity qw(conf logPrefix);
use Spamity::Database;
use Spamity::Web;
use POSIX qw(strftime);

################################################################################
# You should not have to modify anything bellow this line.
################################################################################

my $db;
my $sth_select;
my $sth_delete;
my $row;
my $rows;
my $sid;
my @sid_delete = ();
my $session;

die "Your session handler is not a database!\n" unless &conf('session_database', 1);

# Set STDOUT unbuffered
$| = 1;

# Establish database connection
die $Spamity::Database::message unless ($db = Spamity::Database->new(database => 'session'));

# Prepare SQL statements
$sth_select = $db->dbh->prepare("SELECT id FROM sessions");
$sth_delete = $db->dbh->prepare("DELETE FROM sessions WHERE id = ?");

if ($sth_select->execute()) {
  while ($row = $sth_select->fetchrow_arrayref) {
    $sid = $$row[0];
	
	# Only version 4.x of CGI::Session implements the load and is_expired methods;
	# avoid using it as version 3.95 is still largely used .. !
	# 
	# http://search.cpan.org/~sherzodr/CGI-Session-3.95/Session.pm
	# http://search.cpan.org/~markstos/CGI-Session-4.11/lib/CGI/Session.pm

	unless ($session = new CGI::Session($Spamity::Web::SESSION_DRIVER, $sid,
					    &Spamity::Web::sessionConfig())) {
	    print "FATAL ERROR (deleting session $sid): ", $CGI::Session::errstr;
	    push(@sid_delete, $sid);
	}
	else {
	  if (defined $session->param('username')) { # normal web session
	    print "User web session $sid: ";
	  }
	  elsif (defined $session->param('filtertypes')) { # persistent session
	    print "Persistent web session $sid: ";
	  }
	  elsif (defined $session->param('domains')) { # persistent admin session
	    print "Persistent admin web session $sid: ";
	  }
	  else {
	    print "Invalid session $sid: ";
	  }

	  if ($session->ctime + $session->expire <= time()) {
	    push(@sid_delete, $sid);
	    print "expired on ";
	  }
	  elsif (!defined ($session->param('username'))) {
	    push(@sid_delete, $sid);
	    print "valid until ";
	  }
	  else {
	    print "valid until ";
	  }
	  
	  print strftime("%b %d %Y %T", localtime($session->ctime()+$session->expire())),"\n";
	}
  }
}

foreach $sid (@sid_delete) {
    die $db->dbh->errstr unless $sth_delete->execute($sid);
}

print "Number of sessions deleted: ",scalar(@sid_delete),"\n";

$sth_select->finish();
$sth_delete->finish();
$db->dbh->disconnect;

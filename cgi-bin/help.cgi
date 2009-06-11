#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/cgi-bin/help.cgi,v $
#  $Name:  $
#
#  Copyright (c) 2005, 2006, 2007
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

# Uncomment and modify the following line if you installed Spamity's Perl module
# and/or dependent modules in some non-standard directory.
#
# use lib "/opt/spamity/lib";

use Spamity qw(conf logPrefix);
use Spamity::i18n qw(setLanguage translate);
use Spamity::Web;

# Variables
my $tt;
my $query;
my $vars;
my $url;
my $session_config;
my $session;
my $cookie;
my $user;
my %users;
my %msgs;
my @addresses;


# Prepare template
$query = new CGI;
$tt = &Spamity::Web::getTemplate();

# Retrieve parameters from HTTP post and action from URL
$vars = &Spamity::Web::getParameters($query);

# Prepare redirection URL
$url = substr($query->url(-full=>1), 0, index($query->url(-full=>1), $query->url(-relative=>1)));

# Verify session handler
$session_config = &Spamity::Web::sessionConfig();
if ($session_config->{error}) {
    $vars->{error} = $session_config->{error};
    print $query->header;
    $tt->process('login.html', $vars) || warn logPrefix,"login.cgi: " . $tt->error();
    exit;
}

# Load session
$vars->{sid} = $query->cookie("CGISESSID") || undef;
if (defined $vars->{sid}) {
    $session = new CGI::Session($Spamity::Web::SESSION_DRIVER, $vars->{sid}, $session_config);
    
    $vars->{username} = $session->param('username');
    if (! defined $vars->{username}) {
	# Username not found in session; go back to login page
	$session->delete();
	$cookie = $query->cookie(-name=>'CGISESSID',
				 -value=>'',
				 -expires=>'-1s');
	print $query->redirect(-uri=>$url.'login.cgi/expired',-cookie=>$cookie);
	exit;
    }
    $vars->{lang} = $session->param('lang');
    $vars->{amavisdnew} = defined(&conf('amavisd-new_database', 1)) && (@addresses > 0 || $session->param('admin'));
    $vars->{cache} = $session->param('cache');
    &setLanguage($vars->{lang});
    
    if (defined $session->param('admin')) {
	$vars->{admin} = 1;
	$vars->{admin_cache} = $session->param('admin_cache');
    }
}

# Output html
if (defined $session) {
    print $session->header;
}
else {
    print $query->header;
}

if ($tt) {
    $tt->process('help.html', $vars) || warn logPrefix,"help.cgi: " . $tt->error();
}


1;

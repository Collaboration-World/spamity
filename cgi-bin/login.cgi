#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/cgi-bin/login.cgi,v $
#  $Name:  $
#
#  Copyright (c) 2003, 2004, 2005, 2006, 2007
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
use Spamity::Authentication qw(authenticate);
use Spamity::i18n qw(setLanguage translate);
use Spamity::Lookup qw(getAddressesByUser);
use Spamity::Web qw(cache);

# Variables
my $tt;
my $query;
my $vars;
my $session_config;
my $session;
my $cookie;
#my $url;

# Prepare template
$query = new CGI;
$tt = &Spamity::Web::getTemplate();

# Retrieve parameters from HTTP post and action from URL
$vars = &Spamity::Web::getParameters($query);

# Language
if (defined $query->param('lang') && not $query->param('lang') =~ m/^\s*$/) {
    $vars->{lang} = $query->param('lang');
    &setLanguage($vars->{lang});
}

# Verify session handler
$session_config = &Spamity::Web::sessionConfig();
if ($session_config->{error}) {
    $vars->{error} = $session_config->{error};
    &print_html();
}

$vars->{sid} = $query->cookie("CGISESSID") || undef;
if (defined $vars->{sid}) {
    # Restore session
    $session = new CGI::Session($Spamity::Web::SESSION_DRIVER, $vars->{sid}, $session_config);

    $vars->{username} = $session->param('username');
    $vars->{lang} = $session->param('lang');

    if ($vars->{action} eq 'logout' || $query->param('logout') || ! defined $vars->{username}) {
	# Logout
	$session->delete;
	$cookie = $query->cookie(-name=>'CGISESSID',
				 -value=>'',
				 -expires=>'-1s');
	print $query->redirect(-uri => $vars->{url}.'login.cgi',-cookie => $cookie);
	exit;
    }
    else {
	# Redirect to start page
	$cookie = new CGI::Cookie(-name => 'CGISESSID', -value => $session->id);
	$vars->{url} .= ((&conf((($session->param('admin') && &conf('admin_start_page', 1))?'admin_':'').
			'start_page') eq 'stats')?'stats':'search').'.cgi';
    	print $query->redirect(-uri => $vars->{url}, -cookie => $cookie);
	exit;
    }
}
elsif ($vars->{action} eq 'expired') {
    $vars->{error} = &translate('Your session has expired.');
}

# username
if (defined $query->param('username') && not $query->param('username') =~ m/^\s*$/) {
    $vars->{username} = lc($query->param('username'));
}

# password
if (defined $query->param('password') && not $query->param('password') =~ m/^\s*$/) {
    $vars->{password} = $query->param('password');
}

# Authenticate to IMAP server
if (defined $vars->{username} && defined $vars->{password}) {
    if (&authenticate($vars->{username}, $vars->{password})) {
	# Create session
	$session = new CGI::Session($Spamity::Web::SESSION_DRIVER, undef, $session_config);
	$session->expires('+1h');
	$session->param('username', $vars->{username});
	$session->param('lang', $vars->{lang});
	$vars->{cache} = &Spamity::Web::getCacheSID($vars->{username});
	$session->param('cache', $vars->{cache});
	$vars->{addresses} = join(",", &getAddressesByUser($vars->{cache}, $vars->{username}));
	$session->param('addresses', $vars->{addresses});
	
	if (length($Spamity::Web::message) > 0) {
	    # An error occured during a function call
	    $vars->{error} = $Spamity::Web::message;
	    &print_html();
	}

	my $admins = &conf('admin');
	foreach (split(/[,\s]\s*/, $admins)) {
	    if ($_ eq $$vars{username}) {
		$session->param('admin', 1);
		$session->param('admin_cache', &Spamity::Web::getCacheSID(&conf('admin_id')));
		last;
	    }
	}
	
	$vars->{sid} = $session->id();
	$session->flush();
	
	# Redirect to start page
	my $cookie = new CGI::Cookie(-name => 'CGISESSID', -value => $session->id);
	$vars->{url} .= ((&conf((($session->param('admin') && &conf('admin_start_page', 1))?'admin_':'').
			'start_page') eq 'stats')?'stats':'search').'.cgi';
	print $query->redirect(-uri => $vars->{url}, -cookie => $cookie);
	exit;
    }
    else {
	$vars->{error} = &translate('Authentication failed.');
	if (defined $vars->{sid}) {
	    $session->delete;
	    undef $vars->{sid};
	}
    }
}
elsif (defined $query->param('login')) {
    $vars->{error} = &translate('Specify your username and password to login.');
}

&print_html();

sub print_html {
# Output html
    if (defined $session) {
	print $session->header;
    }
    else {
	print $query->header;
    }
    
    if ($tt) {
	$tt->process('login.html', $vars) || warn logPrefix,"login.cgi: ",$tt->error();
    }
    
    exit;
}

1;

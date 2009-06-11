#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/cgi-bin/search.cgi,v $
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
use Spamity::Database;
use Spamity::i18n qw(setLanguage translate);
use Spamity::Lookup qw(getDomains);
use Spamity::Web;
use POSIX qw(strftime);

# Variables
my $tt;
my $query;
my $vars;
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

# Verify session handler
$session_config = &Spamity::Web::sessionConfig();
if ($session_config->{error}) {
    #$vars->{i18n} = \&translate;
    $vars->{error} = $session_config->{error};
    print $query->header;
    $tt->process('login.html', $vars) || warn logPrefix,'search.cgi: ',$tt->error();
    exit;
}

# Load session
$vars->{sid} = $query->cookie("CGISESSID") || undef;
if (defined $vars->{sid}) {
    $session = new CGI::Session($Spamity::Web::SESSION_DRIVER, $vars->{sid}, $session_config);
    
    $vars->{username} = $session->param('username');
    $vars->{lang} = $session->param('lang');
    @addresses = split(",", $session->param('addresses'));
    $vars->{addresses} = \@addresses;
    $vars->{prefs} = defined(&conf('amavisd-new_database', 1)) && (@addresses > 0 || $session->param('admin'));
    $vars->{cache} = $session->param('cache');
    if (defined $session->param('admin')) {
	$vars->{admin} = 1;
	$vars->{admin_cache} = $session->param('admin_cache');
    }
    
    if (! defined $vars->{username} || ! defined $vars->{addresses}) {
	# Username not found in session; go back to login page
	$session->delete();
	$cookie = $query->cookie(-name=>'CGISESSID',
				 -value=>'',
				 -expires=>'-1s');
	print $query->redirect(-uri=>$vars->{url}.'login.cgi/expired',-cookie=>$cookie);
	exit;
    }
}
else {
    # No cookie found; go back to login page
    print $query->redirect(-uri=>$vars->{url}.'login.cgi');
    exit;
}

# Language
&setLanguage($vars->{lang});

$vars->{filter_types} = &Spamity::Web::getFilterTypes($vars->{cache});
$vars->{strip} = \&Spamity::Web::strip;
$vars->{domains} = &getDomains($vars->{admin_cache}) if ($vars->{admin} == 1);

# Get years for search form
my $current_year = strftime("%Y", localtime);
my @years = (int($current_year) - 1, 
	     int($current_year), 
	     int($current_year) + 1);
$vars->{years} = \@years;

# Process query if necessary
if (defined $vars->{submit}) {
    
    # Test connection to database
    unless (Spamity::Database->new(database => 'spamity')) {
	$vars->{error} = $Spamity::Database::message;
	print $query->header;
	$tt->process('login.html', $vars) || warn logPrefix,'search.cgi: ', $tt->error();
	exit;
    }
    
    my $domain;

    if ($vars->{admin} == 1) {
	# Administration mode: don't limit search to current user's addresses by default
	$user = undef;
	$domain = undef;
	if ($vars->{domain} =~ m/^all$/) {
	    # No restriction on domain
	}
	else {
	    # Search is limited to one domain
	    $domain = $vars->{domain};
	}
	if ($vars->{un}) {
	    # Search is limited to the specified username
	    $user = $vars->{un};
	}
    }
    else {
	$user = $vars->{username};
    }

    if ($vars->{display} eq 'email' || ! $vars->{admin}) {
	$vars->{display} = 'email'; # force non-admin user to display results by email
	%msgs = &Spamity::Web::getMessagesByEmail($vars->{from_date},
						  $vars->{to_date},
						  $vars->{email},
						  $vars->{filter_type},
						  $user,
						  $domain,
						  $vars->{page} - 1,
						  $vars->{results});
	foreach $user (keys %msgs) {
	    unless (grep(/^$user$/, ('USERS','COUNT'))) { # special keys
		my @days = @{$msgs{$user}->{DATES}};
		$users{$user} = \@days;
	    }
	}
	$vars->{users} = \%users;
    }
    elsif ($vars->{display} eq 'date') {
	%msgs = &Spamity::Web::getMessagesByDate($vars->{from_date},
						 $vars->{to_date},
						 $vars->{email},
						 $vars->{filter_type},
						 $user,
						 $domain,
						 $vars->{page} - 1,
						 $vars->{results});
    }
    
    $vars->{msgs} = \%msgs;

    # Build pages references
    $vars->{pages} = int($msgs{COUNT}/$vars->{results});
    $vars->{pages} += 1 unless ($vars->{PAGES} == ($msgs{COUNT}/$vars->{results}));
    
    my @pages = ();
    my $dot = 0;
    foreach my $i (1 .. $vars->{pages}) {
	unless ($vars->{pages} > 9) {
	    push(@pages, $i);
	    next;
	}
	if ($i <= 3 || $i >= ($vars->{pages} - 2) ||
	    ($i >= ($vars->{page} - 1) &&  $i <= ($vars->{page} + 1))) {
	    push(@pages, $i);
	    $dot = 0;
	}
	elsif (!$dot) {
	    push(@pages, '...');
	    $dot = 1;
	}
    }

    $vars->{pages} = \@pages;
    $vars->{self_url} = $query->url(-relative=>1, -query=>1);
    $vars->{self_url} =~ s/page=\d+;?//;
}

# Output html
print $session->header;
$tt->process('search.html', $vars) || warn logPrefix,'search.cgi: ',$tt->error();

1;

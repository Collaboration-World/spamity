#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/cgi-bin/stats.cgi,v $
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
    $tt->process('login.html', $vars) || warn logPrefix,'stats.cgi: ',$tt->error();
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

my $current_year = strftime("%Y", localtime);
my @years = (int($current_year) - 1, 
	     int($current_year), 
	     int($current_year) + 1);
$vars->{years} = \@years;

if ($vars->{action} =~ m/^day$/) {
    # Stats: last 24 hours
    $vars->{graphs} = [{url => 'day',
			title => &translate('number of rejected messages').' '.&translate('for the 24 hours')}];
}
elsif ($vars->{action} =~ m/^week$/) {
    # Stats: week
    if (&conf('show_graph_dow', 1) eq 'true') {
	$vars->{graphs} = [{url => 'week',
			    title => &translate('number of rejected messages').' '.&translate('for the last week')},
			   {url => 'week_avg',
			    title => &translate('average number of rejected msgs').' '.&translate('by day of week')}];
    }
    else {
	$vars->{graphs} = [{url => 'week',
			    title => &translate('number of rejected messages').' '.&translate('for the last week')}];
    }
}
elsif ($vars->{action} =~ m/^month$/) {
    # Stats: month
    $vars->{graphs} = [{url => 'month',
			title => &translate('number of rejected messages').' '.&translate('for the last month')}];
}
elsif ($vars->{admin} == 1) {
    # Admin
    if ($vars->{action} =~ m/^all_day$/) {
	# Stats: last 24 hours
	$vars->{graphs} = [{url => 'all_day',
			    title => &translate('number of rejected messages').' '.&translate('for the 24 hours')}];
    }
    elsif ($vars->{action} =~ m/^all_week$/) {
	# Stats: week
	if (&conf('show_graph_dow', 1) =~ m/true/i) {
	    $vars->{graphs} = [{url => 'all_week', 
				title => &translate('number of rejected messages').' '.&translate('for the last week')},
			       {url => 'all_week_avg',
				title => &translate('average number of rejected messages').' '.&translate('by day of week')}];
	}
	else {
	    $vars->{graphs} = [{url => 'all_week',
				title => &translate('number of rejected messages').' '.&translate('for the last week')}];
	}
    }
    elsif ($vars->{action} =~ m/^all_month$/) {
        # Stats: month
	$vars->{graphs} = [{url => 'all_month',
			    title => &translate('number of rejected messages').' '.&translate('for the last month')}];
    }
    elsif ($vars->{action} =~ m/^most_day$/) {
	# Most spammed addresses for the last 24 hours
	my $time = time - 24*60*60;
	$vars->{from_year} = strftime("%Y", localtime($time));
	$vars->{from_month} = strftime("%m", localtime($time));
	$vars->{from_day} = strftime("%d", localtime($time));
	$vars->{stats} = &Spamity::Web::getStatsMostSpammed('24', 'hour', 20,
							    &translate('most spammed addresses').' '.&translate('for the 24 hours'));
    }
    elsif ($vars->{action} =~ m/^most_week$/) {
	# Most spammed addresses for the last week
	my $time = time - 7*24*60*60;
	$vars->{from_year} = strftime("%Y", localtime($time));
	$vars->{from_month} = strftime("%m", localtime($time));
	$vars->{from_day} = strftime("%d", localtime($time));
	$vars->{stats} = &Spamity::Web::getStatsMostSpammed('8', 'day', 20,
							    &translate('most spammed addresses').' '.&translate('for the last week'));
    }
    elsif ($vars->{action} =~ m/^most_month$/) {
	# Most spammed addresses for the last month
	my $time = time - 31*24*60*60;
	$vars->{from_year} = strftime("%Y", localtime($time));
	$vars->{from_month} = strftime("%m", localtime($time));
	$vars->{from_day} = strftime("%d", localtime($time));
	$vars->{stats} = &Spamity::Web::getStatsMostSpammed('32', 'day', 20,
							    &translate('most spammed addresses').' '.&translate('for the last month'));
    }
    else {
	# Stats: number of rejected messages per filter type
	$vars->{graphs} = [{url => 'count',
			    title => &translate('number of rejected messages')}];
	
	if (! Spamity::Database->new(database => 'spamity')) {
	    $vars->{error} = $Spamity::Database::message;
	    print $query->header;
	    $tt->process('login.html', $vars) || warn logPrefix,'stats.cgi: ',$tt->error();
	}
	
	my %users;
	my %msgs = &Spamity::Web::getMessagesByDate(undef,
						    undef,
						    undef,
						    undef,
						    undef,
						    undef,
						    0,
						    20);
	
	$vars->{msgs} = \%msgs;	
    }
}
else {
    # Present graph of average number of rejected messages per filter type
    $vars->{graphs} = [{url => 'user',
			title => &translate('number of rejected messages')}];
    
    # Connect to database
    if (! Spamity::Database->new(database => 'spamity')) {
	$vars->{error} = $Spamity::Database::message;
	print $query->header;
	$tt->process('login.html', $vars) || warn logPrefix,'stats.cgi: ',$tt->error();
    }

    my %users;
    my %msgs = &Spamity::Web::getMessagesByDate(undef,
						undef,
						undef,
						undef,
						$vars->{username},
						undef,
						0,
						10);

    $vars->{msgs} = \%msgs;
}

# Output html
print $session->header;
$tt->process('stats.html', $vars) || warn logPrefix,'stats.cgi: ',$tt->error();

1;

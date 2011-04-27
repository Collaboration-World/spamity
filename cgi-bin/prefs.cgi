#!/usr/bin/perl
# -*- Mode: CPerl tab-width: 4; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4; cperl-indent-level: 4 -*-
#
#  Copyright (c) 2004-2010
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

use Spamity qw(conf logPrefix);
use Spamity::Database;
use Spamity::i18n qw(setLanguage translate);
use Spamity::Lookup qw(getDomains);
use Spamity::Preference::spamity qw(getPrefs setPrefs);
use Spamity::Preference::amavisdnew qw($message getPolicyColumns getPolicies getPolicy setPolicy getBlacklist setBlacklist getWhitelist setWhitelist);
use Spamity::Web;
use POSIX qw(strftime);

# Variables
my $tt;
my $cookie;
my $session;
my $session_config;
my $vars;
my $user;
my %users;
my %msgs;
my $query;
my @addresses;

# Prepare template
$query = new CGI;
$tt = &Spamity::Web::getTemplate();

# Retrieve parameters from HTTP post and action from URL
$vars = &Spamity::Web::getParameters($query);

# Language (in case a message has to be displayed)
#&setLanguage($vars->{lang});

# Verify session handler
$session_config = &Spamity::Web::sessionConfig();
if ($session_config->{error}) {
    #$vars->{i18n} = \&translate;
    $vars->{error} = $session_config->{error};
    print $query->header(-charset=>'UTF-8');
    $tt->process('login.html', $vars) || warn logPrefix,"login.cgi: ",$tt->error();
    exit;
}

# Prepare redirection URL
#$url = substr($query->url(-full=>1), 0, index($query->url(-full=>1), $query->url(-relative=>1)));

# Load session
$vars->{sid} = $query->cookie("CGISESSID") || undef;
if (defined $vars->{sid}) {
    $session = new CGI::Session($Spamity::Web::SESSION_DRIVER, $vars->{sid}, $session_config);
    $vars->{username} = $session->param('username');
    $vars->{lang} = $session->param('lang');
    @addresses = split(",", $session->param('addresses'));
    $vars->{addresses} = \@addresses;
    $vars->{cache} = $session->param('cache');
    if (defined $session->param('admin')) {
        $vars->{admin} = 1;
        $vars->{admin_cache} = $session->param('admin_cache');
    }
    
    unless ($vars->{username} && (length($vars->{addresses}) > 0) || $vars->{admin}) {
        # Username not found in session; go back to login page
        $session->delete();
        $cookie = $query->cookie(-name=>'CGISESSID',
                                 -value=>'',
                                 -expires=>'-1s');
        print $query->redirect(-uri=>$vars->{url}.'login.cgi/expired',-cookie=>$cookie);
        exit;
    }
} else {
    # No cookie found; go back to login page
    print $query->redirect(-uri=>$vars->{url}.'login.cgi');
    exit;
}

&setLanguage($vars->{lang});
$vars->{amavisdnew} = defined(&conf('amavisd-new_database', 1));
$vars->{spamity_prefs} = defined(&conf('spamity_prefs_database', 1));

unless ($vars->{amavisdnew} || $vars->{spamity_prefs}) {
    # No preferences
    print $query->redirect(-uri=>$vars->{url}.'search.cgi');
    exit;
}

if ($vars->{amavisdnew}) {
    # Test connection to database
    unless (Spamity::Database->new(database => 'amavisd-new')) {
        #$vars->{i18n} = \&translate;
        $vars->{error} = $Spamity::Database::message;
        print $query->header(-charset=>'UTF-8');
        $tt->process('login.html', $vars) || warn logPrefix,"login.cgi: ",$tt->error();
        exit;
    }
}

if ($vars->{spamity_prefs}) {
    # Test connection to database
    unless (Spamity::Database->new(database => 'spamity_prefs')) {
        #$vars->{i18n} = \&translate;
        $vars->{error} = $Spamity::Database::message;
        print $query->header(-charset=>'UTF-8');
        $tt->process('login.html', $vars) || warn logPrefix,"login.cgi: ",$tt->error();
        exit;
    }
}

unless (@addresses > 0 || $vars->{admin} && !$vars->{amavisdnew}) {
    # No address and not admin
    $vars->{error} = &translate('No email address found for your username.');
    print $session->header(charset=>'UTF-8');
    $tt->process('prefs.html', $vars) || warn logPrefix,"prefs.cgi: ",$tt->error();
    exit;
}

# Retrieve email from URL and don't set a default value
if ($vars->{action}) {
    if ($vars->{action} =~ m/^\d+$/) {
        # Action is an index to user's addresses array
        my $address_index = $vars->{action};
        if ($address_index <= @addresses) {
            $vars->{email} = $addresses[$address_index - 1];
        }
    } elsif ($vars->{admin}) {
        # User is administrator; assume action is a full email address
        $vars->{email} = $vars->{action};
    }
} elsif (!$vars->{spamity_prefs}) {
    # Spamity preferences are disabled; default to amavisd-new preferences
    # for the first address of the user
    if (1 <= @addresses) {
        $vars->{action} = 1;
        $vars->{email} = $addresses[0];
    }
}

if ($vars->{email}) {
    # Handle amavis form

    $vars->{policies} = &getPolicies();

    my $columns = &getPolicyColumns();
    my $column;
    foreach $column (@$columns) {
        $vars->{policy_columns}->{$column} = 1;
    }
    
    if (defined $query->param('save')) {
        # Save preferences
        unless (&setPolicy($vars->{email},
                           $columns,
                           $query)) {
            # An error occured
            $vars->{message} = $message;
        } else {
            $vars->{policy} = &getPolicy($vars->{email});
            
            if (defined($vars->{policy})) {
                my @wl = split("\r\n", lc($query->param('wl')));
                $vars->{whitelist} = &setWhitelist($vars->{policy}->{user_id}, \@wl);
                my @bl = split("\r\n", lc($query->param('bl')));
                $vars->{blacklist} = &setBlacklist($vars->{policy}->{user_id}, \@bl);
            }
            
            $vars->{message} = &translate('Preferences saved for address').' <b>'.$vars->{email}.'</b>';
        }
    } else {
        if (defined $query->param('policy') && $query->param('policy') =~ m/^\d+$/) {
            # Switching to a pre-defined policy
            $vars->{policy} = &getPolicy($vars->{email}, $query->param('policy'));
        } elsif (defined $query->param('policy') && !defined $query->param('cancel')) {
            # Switching to a default or custom policy
            $vars->{policy} = undef;
        } else {
            # Initial load of the page or cancelling; retrieve current policy
            $vars->{policy} = &getPolicy($vars->{email});
        }
        
        if (defined $query->param('policy')) {
            # Preserve submitted WB lists
            my @wl = split("\r\n", lc($query->param('wl')));
            $vars->{whitelist} = \@wl;
            my @bl = split("\r\n", lc($query->param('bl')));
            $vars->{blacklist} = \@bl;
        } elsif (defined $vars->{policy}) {
            # User is defined
            $vars->{whitelist} = &getWhitelist($vars->{policy}->{user_id});
            $vars->{blacklist} = &getBlacklist($vars->{policy}->{user_id});
        }
    }
    
    if (length($Spamity::Preference::amavisdnew::message)) {
        # An error occured
        $vars->{error} = $Spamity::Preference::amavisdnew::message;
    }
    if (!defined($vars->{policy}) || $vars->{policy}->{id} eq '0') {
        # User has no policy or is switching to a default or custom policy
        $vars->{policy}->{policy_name} = undef;
        $vars->{policy}->{id} = (defined($query->param('policy'))?$query->param('policy'):'DEFAULT');
        $vars->{policy}->{virus_lover} = &conf('amavisd-new_virus_lover', 1) eq 'true';
        $vars->{policy}->{spam_lover} = &conf('amavisd-new_spam_lover', 1) eq 'true';
        $vars->{policy}->{banned_files_lover} = &conf('amavisd-new_banned_files_lover', 1) eq 'true';
        $vars->{policy}->{bad_header_lover} = &conf('amavisd-new_bad_header_lover', 1) eq 'true';
        $vars->{policy}->{spam_tag_level} = &conf('amavisd-new_spam_tag_level', 1);
        $vars->{policy}->{spam_tag2_level} = &conf('amavisd-new_spam_tag2_level', 1);
        $vars->{policy}->{spam_kill_level} = &conf('amavisd-new_spam_kill_level', 1);
    }
} elsif ($vars->{spamity_prefs}) {
    # Handle preferences form
    
    if (defined $query->param('save')) {
        my @args = ();
        if ($query->param('active')) {
            my $day_freq = 7;
            $day_freq = 1 if ($query->param('freq') eq 'day');
            $day_freq = 30 if ($query->param('freq') eq 'month');
            @args = ($query->param('lang'),
                     $day_freq,
                     $addresses[int($query->param('index_email')) - 1]);
        }
        unless (&setPrefs($vars->{username}, @args)) {
            $vars->{error} = $Spamity::Preference::spamity::message;
        } else {
            $vars->{prefs} = &getPrefs($vars->{username});
            $vars->{message} = &translate('Your preferences were saved');
        }
    } elsif (defined $query->param('cancel')) {
        $vars->{prefs} = &getPrefs($vars->{username});
    } elsif (defined $query->param('active')) {
        $vars->{prefs} = {
                          active => 1,
                          lang => 'fr_CA',
                          report_freq_day => '0',
                          email => $addresses[0]
                         };
    } elsif (defined $query->param('index_email')) {
        # Not active
        $vars->{prefs} = {};
    } else {
        $vars->{prefs} = &getPrefs($vars->{username});
    }
}

# Output html
print $session->header(charset=>'UTF-8');
$tt->process('prefs.html', $vars) || warn logPrefix,"prefs.cgi: ",$tt->error();

1;

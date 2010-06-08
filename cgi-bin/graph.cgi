#!/usr/bin/perl
# -*- Mode: CPerl tab-width: 4; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4; cperl-indent-level: 4 -*-
#
#  Copyright (c) 2003-2010
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
use Spamity::i18n qw(setLanguage translate);
use Spamity::Web;

# Variables
my $query;
my $vars;
my @addresses;

my $session;
my $url;
my $image;

$query = new CGI;

$vars->{sid} = $query->cookie("CGISESSID") || undef;
if (! (defined $vars->{sid})) {
    warn "[DEBUG] No cookie found -- exiting" if (int(&conf('log_level')) > 0);
    exit;
}

$session = new CGI::Session($Spamity::Web::SESSION_DRIVER, $vars->{sid},
                            &Spamity::Web::sessionConfig()) || warn logPrefix,$CGI::Session::errstr;
$vars->{username} = $session->param('username');
$vars->{lang} = $session->param('lang');
$vars->{addresses} = $session->param('addresses');
unless ((defined $vars->{username}) && (defined $vars->{addresses})) {
    warn "[DEBUG] Missing information in cookie -- exiting"  if (int(&conf('log_level')) > 0);
    exit;
}
@addresses = split(",", $session->param('addresses'));
$vars->{addresses} = \@addresses;
$vars->{cache} = $session->param('cache');
if (defined $session->param('admin')) {
    $vars->{admin} = 1;
    $vars->{admin_cache} = $session->param('admin_cache');
}

&setLanguage($vars->{lang});

$url = $query->url(-relative=>1, -path=>1);
if ($url =~ m[/day/.+]) {
    $image = &Spamity::Web::getGraphByUserAndLast24Hours($vars->{cache}, $vars->{username});
} elsif ($url =~ m[/week_avg/.+]) {
    $image = &Spamity::Web::getAvgGraphByUserAndDoW($vars->{cache}, $vars->{username});
} elsif ($url =~ m[/week/.+]) {
    $image = &Spamity::Web::getGraphByUserAndWeek($vars->{cache}, $vars->{username});
} elsif ($url =~ m[/month/.+]) {
    $image = &Spamity::Web::getGraphByUserAndMonth($vars->{cache}, $vars->{username});
} elsif ($vars->{admin}) {
    if ($url =~ m[/count/.+]) {
        $image = &Spamity::Web::getGraphByCount($vars->{admin_cache});
    } elsif ($url =~ m[/all_day/.+]) {
        $image = &Spamity::Web::getGraphByUserAndLast24Hours($vars->{admin_cache}, undef);
    } elsif ($url =~ m[/all_week/.+]) {
        $image = &Spamity::Web::getGraphByUserAndWeek($vars->{admin_cache}, undef);
    } elsif ($url =~ m[/all_week_avg/.+]) {
        $image = &Spamity::Web::getAvgGraphByUserAndDoW($vars->{admin_cache}, undef);
    } elsif ($url =~ m[/all_month/.+]) {
        $image = &Spamity::Web::getGraphByUserAndMonth($vars->{admin_cache}, undef);
    }
} else {
    $image = &Spamity::Web::getGraphByUser($vars->{cache}, $vars->{username});
}

unless ($image) {
    warn "[DEBUG] No data -- generating empty image" if (int(&conf('log_level')) > 0);
    $image = new GD::Image(1,1);
    $image->colorAllocate(255,255,255);
    $image = $image->png;
}

print "Content-type: image/png\n\n";
print $image;

1;

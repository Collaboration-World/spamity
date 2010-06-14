#!/usr/bin/perl -w
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
use Spamity::Web;
use Spamity::Quarantine;

# Variables
my $query;
my $tt;
my $vars;
my @addresses;

my $session;
my $session_config;
my $url;
my $id;

# Prepare template
$query = new CGI;
$tt = &Spamity::Web::getTemplate();

# Retrieve parameters from HTTP post
if ($query->param('id')) {
    $vars->{message_id} = $query->param('id');
} elsif ($query->url(-absolute=>1,-path=>1) =~ m/\.cgi\/+([\d:]+)\/?/) {
    $vars->{message_id} = lc($1);
}

$vars->{cgibin_path} = &conf('cgibin_path');
$vars->{htdocs_path} = &conf('htdocs_path', 1);
$vars->{htdocs_path} = '' if ($vars->{htdocs_path} eq '/');
$vars->{allow_reinjection} = 1 if (defined &conf('reinjection_smtp_server', 1));
$vars->{version} = $Spamity::VERSION . '';

# Test connection to database
unless (Spamity::Database->new(database => 'spamity')) {
    &close_popup;
}

# Verify session handler
$session_config = &Spamity::Web::sessionConfig();
if ($session_config->{error}) {
    &close_popup;
}

# Retrieve message id from URL
$url = $query->url(-relative=>1, -path=>1);
if ($url =~ m/\/(\d+(\:(\d+|unknown))?)\/$/) {
    $vars->{message_id} = $1;
}

# Load session
$vars->{sid} = $query->cookie("CGISESSID") || undef;
if (!(defined $vars->{sid} && defined $vars->{message_id})) {
    # No session or no message id;
    # Use JavaScript to close the window
    &close_popup;
}

$session = new CGI::Session($Spamity::Web::SESSION_DRIVER, $vars->{sid}, $session_config);
$vars->{username} = $session->param('username');
$vars->{lang} = $session->param('lang');
$vars->{addresses} = $session->param('addresses');
$id = $vars->{username};
if (!(defined $vars->{username}) || !(defined $vars->{addresses})) {
    # Session timed out;
    # Use JavaScript to close the window
    &close_popup;
}
@addresses = split(",", $session->param('addresses'));
$vars->{addresses} = \@addresses;
$vars->{cache} = $session->param('cache');
if (defined $session->param('admin')) {
    $vars->{admin} = 1;
    $vars->{admin_cache} = $session->param('admin_cache');
    $id = undef;
}

&setLanguage($vars->{lang});
$vars->{i18n} = \&translate;

my ($mail_from, $rcpt_to, $mailObj, $virus_id) = &Spamity::Quarantine::getRawSource($vars->{message_id}, $id);
&close_popup unless defined ($mailObj);

if (defined $virus_id && defined &conf('allow_virus_reinjection')) {
    # Verify if virus reinjection has been desactivate
    $vars->{allow_reinjection} = 0 unless &conf('allow_virus_reinjection') =~ m/true/i;
}

if (defined $query->param('confirm')) {
    $vars->{confirmation} = &translate('You are about to reinject a virus to your account. Do you want to continue?');
} elsif ($vars->{allow_reinjection} && defined $query->param('reinject')) {
    if (! &Spamity::Quarantine::sendMail($mail_from, $rcpt_to, $mailObj)) {
        $vars->{error} = &translate('Reinjecting currently not possible.');
    } else {
        # Message was successfully reinjected
        &close_popup;
    }
} else {
    $vars->{virus} = $virus_id if (defined $virus_id);
    my $body_arrayref =  $mailObj->body();
    my $body = &CGI::escapeHTML(join("\n", @{$body_arrayref}));
    $vars->{body} = $body;
}

# Format headers
my $header_arrayref = $mailObj->head->header();
my %headers = ();
my @keys = ();
foreach (@{$header_arrayref}) {
    chomp;
    if ($_ =~ m/^(\S+):\s+(.+)$/s) {
        $headers{$1} =  &CGI::escapeHTML($2);
        push(@keys, $1);
    }
}
$vars->{headers} = \%headers;
$vars->{keys} = \@keys;
$vars->{strip} = \&Spamity::Web::strip;

# Output HTML
print $session->header(charset=>'UTF-8');
$tt->process('rawsource.html', $vars) || warn logPrefix,'rawsource.cgi: ',$tt->error();


sub close_popup {

    # Use JavaScript to close the window
    print $query->header(-charset=>'UTF-8');
    $vars->{close_window} = '1';
    $tt->process('rawsource.html', $vars) || warn logPrefix,'rawsource.cgi: ',$tt->error();
    exit;
}

1;

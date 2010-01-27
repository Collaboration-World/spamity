#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/lib/Spamity/Authentication.pm,v $
#  $Name:  $
#
#  Copyright (c) 2004, 2005, 2006
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

package Spamity::Authentication;

use Spamity qw(conf logPrefix);

BEGIN {
    use Exporter;
    @Spamity::Authentication::ISA = qw(Exporter);
    @Spamity::Authentication::EXPORT = qw();
    @Spamity::Authentication::EXPORT_OK = qw($message authenticate);
}
use vars qw($message);

$message = undef;

# Load the appropriate (single) module for authentication
if (&conf('authentication_backend') =~ m/^(\S+):\S+/) {
    my $module = $1;
    $module =~ s/imaps/imap/; # imaps is supported in module imap.pm
    unless (eval('require "Spamity/Authentication/$module.pm"')) {
	$message = "Error loading module $module ",$@ if $@;
	warn logPrefix,"Spamity::Authentication ", $message;
    }
}
else {
    # Unknown syntax
    warn logPrefix,"Spamity::Authentication Unkown syntax for authentication_backend: ",&conf('authentication_backend', 1),".";
}

1;

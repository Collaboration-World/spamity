#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/lib/Spamity.pm,v $
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

package Spamity;

use POSIX qw(strftime);

BEGIN {
    use Exporter;
    @Spamity::ISA = qw(Exporter);
    @Spamity::EXPORT = qw();
    @Spamity::EXPORT_OK = qw(conf logPrefix userKey VERSION);
}
use vars qw($VERSION);

$VERSION = 0.97;

my $CONFIG_FILE_PATH = "/etc/spamity.conf";

#*********************************************************************
# Module variables
#*********************************************************************
my %vars = ();

#*********************************************************************
# Load configuration file variables
#*********************************************************************
if (!%vars) {
    open(CONFIG, "$CONFIG_FILE_PATH") or die "Can't open config file $CONFIG_FILE_PATH: $!\n";
    while (<CONFIG>) {
	if (m/^(?<!=\#)\s*([\-\w]+)\s*=\s*(.+?)\s*(?:\#.*)?$/) {
	    $vars{$1} = $2;
	}
    }
    close(CONFIG);
    warn "[DEBUG] Spamity configuration file loaded\n" if (int(&conf('log_level')) > 2);
}

#*********************************************************************
# Set environment variables
#*********************************************************************
foreach (keys %vars) {
    if (m/^(ENV_(\w+))$/) {
	$ENV{$2} = $vars{$1};
    }
}

sub conf
{
    return \%vars if (!defined $_[0]);
    warn &logPrefix, "Required configuration variable '$_[0]' not defined; correct the config file $CONFIG_FILE_PATH\n" unless (defined $vars{$_[0]} || $_[1]);
    return $vars{$_[0]};
} # conf


sub logPrefix
{
    my @now = localtime(time);
    
    return strftime("%b %e %T $0 ", @now);
} # logPrefix


sub userKey
{
    my $username;
    my $total;
    my @numbers;
    my $sum = 0;

    ($username) = @_;
    $total = &conf('tables_count', 1);
    
    return undef unless(defined($total));
    return 'unknown' if ($username eq &conf('unknown_recipient'));

    @numbers = unpack("C*", $username);
    foreach (@numbers) {
	$sum += $_;
    }
    return (($sum % $total) + 1);
} # userKey

1;

#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/lib/Spamity/Lookup/file.pm,v $
#  $Name:  $
#
#  Copyright (c) 2004, 2005, 2006, 2007
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

package Spamity::Lookup::file;

=head1 NAME

Spamity::Lookup::file - Spamity file source map.
    
=head1 DESCRIPTION
    
This Perl module allows to specify a flat text file as the source of a map for
the following parameters in Spamity configuration file:

=over 4

=item * lookup_username_maps

=item * lookup_local_username_maps

=item * lookup_address_maps

=item * domains_maps

=back

=head1 USAGE

Simply specify the absolute path of the text file.

=head1 EXAMPLE

domains_maps = /etc/postfix/virtual

=cut

use Spamity qw(conf logPrefix);

my %addresses;
my %localAddresses;


sub getAddressesByUser
{
    my $file;
    my $id;
        
    my @addresses = ();
    
    ($file, $id) = @_;
    
    # Read addresses table
    if (! open (FILE, $file)) {
	$message = "Can't open addresses table: $!";
	warn logPrefix,"Spamity::Lookup::file getAddressesByUser ($file, $id) $message\n";
    }
    else {
	while (<FILE>) {
	    if (m/^(?!#)(.*?@.*?)\s+$id(?:@.+)?(?:,.*)?$/) {
		push(@addresses, $1);
	    }
	    elsif (m/^(.+):\s+(?:.*,\s*)?$id(?:,.*)?$/) {
		# File is an aliases table
		push(@addresses, "$1\@".&conf('master_domain'));
	    }
	}
	close FILE;
    }
	
    warn "[DEBUG] Spamity::Lookup::file getAddressesByUser $id ($file): ",join(', ',@addresses),"\n" if (int(&conf('log_level')) > 2);
   
    return @addresses;
    
} # getAddressesByUser

    
sub getDomains
{
    my $file;
    
    my @domains;
    my @domains_unique;
    my $domain;
    my %seen;

    ($file) = @_;
    
    # Read domains table
    if (! open (FILE, $file)) {
	$message = "Can't open domain table: $!";
	warn logPrefix,"Spamity::Lookup::file getDomains ($file) $message\n";
    }
    else {
	while (<FILE>) {
	    if (m/^(?!\#)zone\s+\"(.+?)(?<!arpa)\"/i) {
		# Support for BIND configuration file
		push(@domains, lc($1));
	    }
	    elsif (m/^(?!\#)([^@\s]+)\s+\S+?[^\{\};]$/) {
		# Expected format is "domain anything", where <anything>
		# must not contain {, }, and ;.
		push(@domains, lc($1));
	    }
	}
	close FILE;
    }
    
    # Remove duplicates
    foreach $domain (@domains) {
	$seen{$domain}++;
    }
    @domains_unique = keys %seen;

    @domains = sort @domains_unique;
    
    return @domains;
    
} # getDomains


sub getUsersByAddress
{
    my $file;
    my $address;
    
    my @users;
    my @users_unique;
    my $line;
    my $domain;
    my $list;
    my $alias;
    my $master_domain = &conf('master_domain');
    
    ($file, $address) = @_;
    $address = lc($address);
    if ($address =~ m/\@(.*)$/) { $domain = $1 }
    
    # We use a local hash to cache addresses since this function
    # is to be used by the daemon and not the CGI scripts
    if (%addresses && exists($addresses{$address})) {
	# Address has been previously resolved
#	warn "[DEBUG CACHE] Spamity::Lookup::file getUsersByAddress $address: ",join(',', @{$addresses{$address}}),"\n" if (int(&conf('log_level')) > 1);
	return @{$addresses{$address}};
    }
    
    if (! open (FILE, $file)) {
	$message = "Can't open addresses table $file: $!.";
	warn logPrefix,"Spamity::Lookup::file getUsersByAddress ($file, $address) $message\n";
    }
    else {
	while (<FILE>) {
	    chomp; $line = $_;
	    if ($line =~ m/^\@$domain\s+(.+(?:,.+)?)$/i ||     # catchall
		$line =~ m/^(?!#)$address\s+(.+(?:,.+)?)$/i)
	    {
		# File is an addresses table
		$list = $1;
		$list =~ s/\s//g;
		$list =~ s/\@$master_domain//g;
		push(@users, split(",", $list));
	    }
	    elsif ($address =~ m/^(.+)\@$master_domain$/i) {
		$alias = $1;
		if ($line =~ m/^$alias:\s+(.+(?:,.+)?)$/i) {
		    # File is an aliases table
		    $list = $1;
		    $list =~ s/\s//g;
		    push(@users, split(",", $list));
		}
	    }
	}
	close FILE;
    }
    
    # Remove duplicates and forwards
    my %seen = ();
    my $user;
    foreach $user (@users) {
	push(@users_unique, $user) unless ($seen{$user}++ || $user =~ m/\@/);
    }
    
    # Cache lookup
    push(@{$addresses{$address}}, @users_unique);
	    
    return @users_unique;

} # getUsersByAddress


sub getLocalUsersByAddress
{
    my $file;
    my $address;

    my $master_domain = &conf('master_domain');
    my $user;
    my @users;
    
    ($file, $address) = @_;

    if ($address =~ m/^(.+)\@$master_domain$/i) {
	$user = $1;
	# We use a local hash to cache addresses since this function
	# is to be used by the daemon and not the CGI scripts
	if (%localAddresses && exists($localAddresses{$user})) {
	    # User has been previously resolved
	    if ($localAddresses{$user} == 1) {
		warn "[DEBUG CACHE] Spamity::Lookup::file getLocalUsersByAddress $address: $user\n" if (int(&conf('log_level')) > 1);
		return $user;
	    }
	    return undef;
	}

        # Read passwd file
	if (! open (FILE, $file)) {
	    $message = "Can't open file: $!";
	    warn logPrefix,"Spamity::Lookup::file getLocalUsersByAddress ($file, $address) $message\n";
	}
	else {
	    while (<FILE>) {
		if (m/^\Q$user\E[\s:]+/) {
		    close FILE;
		    # Cache lookup
		    $localAddresses{$user} = 1;
		    return $user;
		}
	    }
	    close FILE;
	}
    }
    
    # Cache lookup
    $localAddresses{$user} = 0;
    
    return undef;
    
} # getLocalUsersByAddress

1;

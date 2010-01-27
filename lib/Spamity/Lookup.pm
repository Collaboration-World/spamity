#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/lib/Spamity/Lookup.pm,v $
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

package Spamity::Lookup;

use Spamity qw(conf logPrefix);

BEGIN {
    use Exporter;
    @Spamity::Lookup::ISA = qw(Exporter);
    @Spamity::Lookup::EXPORT = qw();
    @Spamity::Lookup::EXPORT_OK = qw($message getAddressesByUser getDomains getUsersByAddress);
}
use vars qw($message);

$message = undef;


sub getAddressesByUser
{
    my $sid;
    my $id;
    
    my $cid;
    my $cexp;

    my @sources;
    my $source;
    my $module;
    my $addresses_cached;
    my @addresses;
    my $rsub;

    ($sid, $id) = @_;
    $cid = "addresses";
    $cexp = '+1M';

    if (defined $sid) {
	$addresses_cached = &Spamity::Web::cache($sid, $cid, $cexp, undef);
	if (defined $addresses_cached) {
	    @addresses = split(',', $addresses_cached);
	    warn "[DEBUG CACHE] Spamity::Lookup getAddressesByUser $id: $addresses_cached\n" if (int(&conf('log_level')) > 1);
	    return @addresses;
	}
    }    
    
    @sources = split(/[,\s]\s*/, &conf('lookup_address_maps'));
    foreach $source (@sources) {
	if ($source =~ m/^(\/\S+)/) {
	    # File source
	    $source = $1;
	    use Spamity::Lookup::file;
	    push(@addresses, &Spamity::Lookup::file::getAddressesByUser($source, $id));
	}
	elsif ($source =~ m/^(\S+):(\S+)/) {
	    # Other source
	    ($module, $source) = ($1, $2);
	    if (eval 'require "Spamity/Lookup/$module.pm"') {
		$rsub = 'Spamity::Lookup::'.$module.'::getAddressesByUser';
		push(@addresses, &$rsub($source, $id));
	    }
	    else {
		# Error loading the module
		warn logPrefix,"Spamity::Lookup getAddressesByUser ",$@ if $@;
	    }
	}
	else {
	    # Unknown syntax
	    warn logPrefix,"Spamity::Lookup getAddressesByUser Unkown syntax: $source.";
	}
    }

#    if (&conf('lookup_local_username_maps', 1)) {
#	# Expect file path
#	use Spamity::Lookup::file;
#	my $address = $user.'@'.&conf('master_domain');
#	if (&Spamity::Lookup::file::getLocalUsersByAddress($source, $address)) {
#	    push(@addresses, $address);
#	}
#    }

    # Remove duplicates
    my %seen;
    foreach my $address (@addresses) {
	$seen{$address}++;
    }
    my @addresses_unique = keys %seen;

    warn "[DEBUG] Spamity::Lookup getAddressesByUser ($id) ",join(',', @addresses_unique),"\n" if (int(&conf('log_level')) > 2);

    &Spamity::Web::cache($sid, $cid , $cexp, join(',', @addresses_unique)) if (defined $sid);

    return @addresses_unique;

} # getAddressesByUser


sub getDomains
{
    my $sid;

    my $cid;
    my $cexp;
    
    my $address;
    my @sources;
    my $source;
    my $domains_cached;
    my @domains = ();
    my $rsub;

    ($sid) = @_;
    $cid = "domains";
    $cexp = '+1M';

    if (defined $sid) {
	$domains_cached = &Spamity::Web::cache($sid, $cid, $cexp, undef);
	if (defined $domains_cached) {
	    @domains = split(',', $domains_cached);
	    
	    return \@domains;
	}
    }

    @sources = split(/[,\s]\s*/, &conf('domains_maps'));

    foreach $source (@sources) {
	if ($source =~ m/^(\/\S+)/) {
	    # File source
	    $source = $1;
	    eval {
		require 'Spamity/Lookup/file.pm';
		push(@domains, &Spamity::Lookup::file::getDomains($source));
	    }; warn logPrefix,$@ if $@;
	}
	elsif ($source =~ m/^(\S+):(\S+)/) {
	    # Other source
	    ($module, $source) = ($1, $2);
	    if (eval "require 'Spamity/Lookup/$module.pm'") {
		$rsub = 'Spamity::Lookup::'.$module.'::getDomains';
		push(@domains, &$rsub($source));
	    }
	    else {
		# Error loading the module
		warn logPrefix,"Spamity::Lookup getDomains ",$@ if $@;
	    }
	}
	else {
	    push(@domains, $source);
	}
    }

    warn "[DEBUG] Spamity::Lookup getDomains ",join(', ', @domains),"\n" if (int(&conf('log_level')) > 2);
    
    &Spamity::Web::cache($sid, $cid, $cexp, join(',', @domains)) if (defined $sid);
    
    return \@domains;

} # getDomains


sub getUsersByAddress
{
    my $address;
    
    my @sources;
    my $source;
    my $module;
    my @users;
    my $rsub;

    ($address) = @_;
    
    @sources = split(/[,\s]\s*/, &conf('lookup_username_maps'));
    foreach $source (@sources) {
	if ($source =~ m/^(\/\S+)/) {
	    # File source
	    $source = $1;
	    use Spamity::Lookup::file;
	    push(@users, &Spamity::Lookup::file::getUsersByAddress($source, $address));
	}
	elsif ($source =~ m/^(\S+):(\S+)/) {
	    # Other source
	    ($module, $source) = ($1, $2);
	    if (eval 'require "Spamity/Lookup/$module.pm"') {
		$rsub = 'Spamity::Lookup::'.$module.'::getUsersByAddress';
		push(@users, &$rsub($source, $address));
	    }
	    else {
		# Error loading the module
		warn logPrefix,"Spamity::Lookup getUsersByAddress ",$@ if $@;
	    }
	}
	else {
	    # Unknown syntax
	    warn logPrefix,"Spamity::Lookup getUsersByAddress Unkown syntax: $source.";
	}
    }

    if (&conf('lookup_local_username_maps', 1)) {
	# Expect file paths
	@sources = split(/[,\s]\s*/, &conf('lookup_local_username_maps'));
	use Spamity::Lookup::file;
	my $user;
	foreach $source (@sources) {
	    if ($user = &Spamity::Lookup::file::getLocalUsersByAddress($source, $address)) {
		push(@users, $user);
	    }
	}
    }

    # Remove duplicates
    my %seen;
    foreach $user (@users) {
	$seen{$user}++;
    }
    my @users_unique = keys %seen;

    warn "[DEBUG] Spamity::Lookup getUsersByAddress $address = ",join(',', @users_unique),"\n" if (int(&conf('log_level')) > 2);

    return @users_unique;

} # getUsersByAddress

1;

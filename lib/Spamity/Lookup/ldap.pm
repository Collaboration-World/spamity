#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/lib/Spamity/Lookup/ldap.pm,v $
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

package Spamity::Lookup::ldap;

=head1 NAME

Spamity::Lookup::ldap - Spamity file source map.
    
=head1 DESCRIPTION
    
This Perl module allows to specify an ldap query as the source of a map for
the following parameters in Spamity configuration file:

=over 2

=item * lookup_username_maps

=item * lookup_local_username_maps

=item * lookup_address_maps

=item * domains_maps

=item * authentication_backend (single map)

=back

=head1 USAGE

Specify the map as C<ldap:source> where C<source> becomes the prefix of the
parameters of the map.

The parameters are the following:

=over 4

=item * B<host> (required)

One or many hostnames, IP addresss, or URIs of LDAP servers (such as ldaps://127.0.0.1:666).

=item * B<port> (default: 389)

The port to connect to the server.

=item * B<version> (default: 3)

The protocol version being used (2 or 3).

=item * B<bind_dn>

DN to bind to the server. Don't specify this parameter for anonymous bind.

=item * B<bind_password>

Password to bind to the server.

=item * B<search_base> (required)

The DN at which to perform the search. The parameter supports the '%' expansions 
(see bellow).

=item * B<scope> (default: sub)

The search scope. Either sub, base, or one.

=item * B<query_filter> (default: (mail=%s))

The LDAP query used to search the directory. The parameter supports the '%' 
expansions (see bellow).

=item * B<result_attribute> (default: cn)

The result attribute that the query should return.

=item * B<result_format> (default: %s)

CURRENTLY IGNORE; NOT IMPLEMENTED YET

A format template to be applied to the result attribute. The parameter supports
the '%' expansions (see bellow).

=back

=head2 % EXPANSIONS

=over 4

=item B<%s>

For the query_filter parameter, the value of the search key.

For the result_format parameter, the value of the result attribute.

=item B<%u>

For the query_filter parameter, when the input key is an address of the form
user@domain, %u is replaced by the user part of the address.

For the result_format parameter, when the result value is an address of the form
user@domain, %u is replaced by the user part of the address.

=item B<%d>

For the query_filter parameter, when the input key is an address of the form
user@domain, %d is replaced by the domain part of the address.

For the result_format parameter, when the result value is an address of the form
user@domain, %d is replaced by the domain part of the address.

=item B<%%>

The % character.

=head1 EXAMPLE

  lookup_username_maps = ldap:ldap_username
  ldap_username_host = ldaps://directory.mydomain.com:636
  ldap_username_search_base = ou=people,dc=mydomain,dc=com
  ldap_username_bind_dn = cn=spamity,ou=admin,dc=mydomain,dc=com
  ldap_username_bind_password = myscreetpassword
  ldap_username_query_filter = (|(mailNickname=%u)(proxyAddresses=smtp:%s))
  ldap_username_result_attribute = mailNickname

=cut

use Spamity qw(conf logPrefix);
use Net::LDAP;


sub getAddressesByUser
{
    return &_performQuery(@_);

} # getAddressesByUser


sub getDomains
{
    return &_performQuery(@_);

} # getDomains


sub getUsersByAddress
{
    return &_performQuery(@_);

} # getUsersByAddress


sub _performQuery
{
    my $source;
    my $key;
    
    my ($user, $domain);
    my @servers;
    my $ldap_server = undef;
    my $msg;
    my @values;

    ($source, $key) = @_;
    
    # Extract user and domain parts
    if ($key =~ m/^(\S+)\@(\S+)$/) {
	($user, $domain) = (lc($1), lc($2));
    }
    @servers = split(/[,\s]\s*/, &conf($source.'_host', 1));

    unless (scalar(@servers) > 0) {
	warn logPrefix, "Spamity::Lookup::ldap _performQuery missing host for map $source\n";
	return @values;
    }
    
    my %conf;
    $conf{port}               = &conf($source.'_port', 1)             || 389;
    $conf{version}            = &conf($source.'_version', 1)          || 3;
    $conf{bind_dn}            = &conf($source.'_bind_dn', 1);
    $conf{bind_password}      = &conf($source.'_bind_password', 1);
    $conf{search_base}        = &conf($source.'_search_base');        # required
    $conf{scope}              = &conf($source.'_scope', 1)            || 'sub';
    $conf{query_filter}       = &conf($source.'_query_filter', 1)     || '(mail=%s)';
    $conf{result_attribute}   = &conf($source.'_result_attribute')    || 'cn';
    $conf{result_format}      = &conf($source.'_result_format', 1)    || '%s';
    
    $ldap_server = Net::LDAP->new(\@servers,
				  port => $conf{port}, 
				  version => $conf{version});
    
    if (!defined $ldap_server) {
	$message = $@;
	warn logPrefix, "Spamity::Lookup::ldap _performQuery ($source, $key) $message.\n";
	return @values;
    }
    if (defined $conf{bind_dn}) {
	# Authenticated access
	$msg = $ldap_server->bind($conf{bind_dn},
				  password => $conf{bind_password}) or die logPrefix,$@;
	if ($msg->is_error()) {
	    $message = $msg->error();
	    warn logPrefix, "Spamity::Lookup::ldap _performQuery ($source, $key) $message\n";
	    return @values;
	}
    }
    else {
	$ldap_server->bind();
    }
    
    # Perform the % expansion on the query filter
    $conf{query_filter} =~ s/\%(.)/
	if ($1 eq 's') {
	    $key;
	}
#        elsif ($1 eq 'S') {
#	}
        elsif ($1 eq 'u') {
	    $user;
	}
#        elsif ($1 eq 'U') {
#	}
        elsif ($1 eq 'd') {
	    $domain;
	}
#        elsif ($1 eq 'D') {
#	}
        elsif ($1 eq '%') {
	    '%';
	}
        else {
	    warn logPrefix, "Spamity::Lookup::ldap _performQuery ($source, $key) Unknown % expansion: $1";
	    '';
	}
    /eg;

    warn "[DEBUG] Spamity::Lookup::ldap _performQuery search base: ",$conf{search_base},", query: ",$conf{query_filter},"\n" if (int(&conf('log_level')) > 2);

    # Perform the query
    my @attributes = split(/[,\s]\s*/, $conf{result_attribute});
    my $results = $ldap_server->search(filter => $conf{query_filter},
				       base => $conf{search_base},
				       attrs => [@attributes]);
    
    my $entry;
    for (my $i = 0; $i < $results->count; $i++) {
	$entry = $results->entry($i);
	my $attribute;
	foreach $attribute (@attributes) {
	    if ($attribute =~ m/^dn$/i) {
		push(@values, $entry->dn());
	    }
	    else {
		push(@values, $entry->get_value($attribute));
	    }
	}
    }
    $ldap_server->unbind or warn logPrefix, "Spamity::Lookup::ldap _performQuery ($source, $key) Could not unbind to the LDAP server.\n";
    
    # Lower case all results
    foreach (@values) {
	$_ = lc($_);
    }

    warn "[DEBUG] Spamity::Lookup::ldap _performQuery ",join(', ',@attributes),": ",join(', ',@values),"\n" if (int(&conf('log_level')) > 2);
    
    return @values;

} # _performQuery

1;

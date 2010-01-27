#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/lib/Spamity/Authentication/ldap.pm,v $
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

=head1 NAME

Spamity::Authentication - Spamity authentication to an LDAP server.

=head1 DESCRIPTION

This Perl module allows the web interface of Spamity to use an LDAP server to
authenticate users.

The module first lookups the DN of the user and then tries to bind using the 
found DN and the supplied password. The DN lookup can be formed anonymously or 
using a specific username and password.

=head1 USAGE

See perldoc Spamity::Lookup::ldap.

=head1 EXAMPLE

  authentication_backend = ldap:ldap_auth
  ldap_auth_host = ldaps://directory.mydomain.com:636
  ldap_auth_search_base = ou=people,dc=mydomain,dc=com
  ldap_auth_bind_dn = cn=spamity,ou=admin,dc=mydomain,dc=com
  ldap_auth_bind_password = myscreetpassword
  ldap_auth_query_filter = (mailNickname=%s)
  ldap_auth_result_attribute = dn

=cut

use Spamity::Lookup::ldap;
use Net::LDAP;


sub authenticate
{
    my $id;
    my $pass;
    
    my $source;
    my @values;
    my @servers;
    my $ldap_server = undef;
    my $result = 0;
    my $msg;

    ($id, $pass) = @_;
    
    # Assume the format to be valid since module loaded from Authentication.pm
    &conf('authentication_backend') =~ m/^\S+:(\S+)/;
    $source = $1;
    
    # Lookup the DN
    @values = &Spamity::Lookup::ldap::_performQuery($source, $id);
    unless (scalar(@values) == 1) {
	$message = "No DN found for $id.";
	warn logPrefix, "Spamity::Authentication::ldap authenticate ($source) $message" if (int(&conf('log_level')) > 2);
	warn logPrefix, "Authentication failed for $id";
	return $result;
    }
    
    @servers = split(/[,\s]\s*/, &conf($source.'_host', 1));
        
    unless (scalar(@servers) > 0) {
	warn logPrefix, "Spamity::Lookup::ldap _performQuery missing host for map $source\n";
	return $result;
    }

    my %conf;
    $conf{host}               = &conf($source.'_host');
    $conf{port}               = &conf($source.'_port', 1)             || 389;
    $conf{version}            = &conf($source.'_version', 1)          || 3;
    $conf{scope}              = &conf($source.'_scope', 1)            || 'sub';
    
    $ldap_server = Net::LDAP->new(\@servers,
				  port => $conf{port}, 
				  version => $conf{version});
    
    if (!defined $ldap_server) {
	$message = $@;
	warn logPrefix, "Spamity::Authentication::ldap authenticate ($source, $id) $message.\n";
	return $result;
    }
    
    warn logPrefix, "Spamity::Authentication::ldap authenticate DN: $values[0].\n" if (int(&conf('log_level')) > 2);
    
    # Authenticate user
    $msg = $ldap_server->bind(shift(@values),
			      password => $pass);
    $result = !$msg->is_error();

    $ldap_server->unbind or warn logPrefix, "Spamity::Authentication::ldap authenticate ($server) Could not unbind to the LDAP server.\n";

    if ($result) {
	warn logPrefix, "Authentication successful for user $id\n";
    }
    else {
	warn logPrefix, "Authentication failed for $id\n";
    }
    
    return $result;

} # authenticate

1;

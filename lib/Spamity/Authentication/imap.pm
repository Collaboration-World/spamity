#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/lib/Spamity/Authentication/imap.pm,v $
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

#
# The following parameters must be defined in your Spamity configuration file (/etc/spamity.conf):
#
# imap_server: The IMAP server name or address
#   Example:
#   imap_server = imap.yourdomain.com
#

package Spamity::Authentication;

=head1 NAME

Spamity::Authentication - Spamity authentication to an IMAP server.

=head1 DESCRIPTION
    
This Perl module allows the web interface of Spamity to use an IMAP server to
authenticate users.

=head1 USAGE

Define the value of the parameter 'authentication_backend' as a URL to an IMAP
or IMAPS server.

=head1 EXAMPLE

authentication_backend = imaps://mail.mydomain.com

=cut

use Mail::IMAPClient;

sub authenticate
{
    my $id;
    my $pass;
    my $imap_server;
    my $imap_port;
    my $socket;
    my $imap;
    my $result;
    
    ($id, $pass) = @_;
    $result = 0;
    
    $imap_server = &conf('authentication_backend');
    if ($imap_server =~ m/^(.+?):(\d+)$/) {
	$imap_server = $1;
	$imap_port = $2;
    }
    if ($imap_server =~ m#^imaps://(.+)$#) {
	# Establish IMAP connection over SSL
	$imap_server = $1;
	unless (eval "require IO::Socket::SSL") {
	    warn logPrefix, "Spamity::Authentication::imap authenticate ($imap_server) Unable to load IO::Socket::SSL library.";
	    return 0;
	}
	$socket = new IO::Socket::SSL(PeerAddr => $imap_server,
				      PeerPort => $imap_port || '993');
	if (!$socket) {
	    warn logPrefix,"Spamity::Authentication::imap authenticate Error with IMAP/SSL socket ($imap_server)\n";
	    return 0;
	}
	$imap = Mail::IMAPClient->new(Socket        => $socket,
				      Server        => $imap_server,
				      User          => $id,
				      Password      => $pass,
				      Authmechanism => 'plain',
				      Authcallback  => sub {
					  my @params = @_;
					  $params[1] = encodeBase64($id."\000".$id."\000".$pass);
				      },
				      Clear    => 5 # Unnecessary since '5' is the default
				      );
	unless ($imap) {
	    warn logPrefix, "IMAPS connection failed to server $imap_server.\n";
	    return 0;
	}
	$imap->State($imap->Connected);
	$result = 1 if $imap->login();
    }
    else {
	# Establish IMAP connection
	$imap_server =~ s#^imap://##;
	$imap_port = '143' unless ($imap_port);
	$imap = Mail::IMAPClient->new(Server        => "$imap_server:$imap_port",
				      User          => $id,
				      Password      => $pass,
				      Clear    => 5 # Unnecessary since '5' is the default
				      );
	unless($imap) {
	    warn logPrefix, "IMAP connection failed to server $imap_server.\n";
	    return 0;
	}
	$result = 1 if $imap->IsAuthenticated;
    }
    
    if (!$imap->disconnect) {
	warn logPrefix, "Spamity::Authentication::imap authenticate Could not disconnect: $@";
    }

    if ($result) {
	warn logPrefix, "Authentication successful for user $id\n";
    }
    else {
	warn logPrefix, "Authentication failed for $id\n";
    }

    return $result;
    
} # authenticate

sub encodeBase64
{
    # Inspired from MIME::Base64 by Gisle Aas
    
    my $encoded = "";
    my $eol = "\n";
    my $result;

    # ensure start at the beginning
    pos($_[0]) = 0;
    $result = join '', map( pack('u',$_)=~ /^.(\S*)/, ($_[0]=~/(.{1,45})/gs));

    $result =~ tr|` -_|AA-Za-z0-9+/|;               # `# help emacs
    # fix padding at the end
    my $padding = (3 - length($_[0]) % 3) % 3;
    $result =~ s/.{$padding}$/'=' x $padding/e if $padding;
    # break encoded string into lines of no more than 76 characters each
    if (length $eol) {
        $result =~ s/(.{1,76})/$1$eol/g;
    }
    
    return $result;
} # encodeBase64

1;

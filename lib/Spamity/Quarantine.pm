#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/lib/Spamity/Quarantine.pm,v $
#  $Name:  $
#
#  Copyright (c) 2004, 2006
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

package Spamity::Quarantine;

use Spamity qw(conf logPrefix);
use Spamity::Database;
use Spamity::i18n qw(translate);
use Net::SMTP;
use Mail::Internet;


$message = undef;


sub getRawSource
{
    my $id;
    my $username;

    my $index = '';
    my $db;
    my $stmt;
    my $sth;
    my $filter_type;
    my $filter_id;
    my $virus_id;
    my $rawsource;
    my $obj;
    my $mail_from;
    my $rcpt_to;
    my $headers;
    my @parts;

    ($id, $username) = @_;

    return undef unless ($db = Spamity::Database->new(database => 'spamity'));

    if ($id =~ m/^(\d+):((\d+|unknown))$/) {
	# Multiple tables
	($id, $index) = ($1, '_'.$2);
    }

    $stmt = sprintf('select %s as to_rcpt, filter_type, filter_id, rawsource from spamity%s where id = %s', 
		    $db->concatenate(qw/to_user '@' to_host/), $index, $id);
    $stmt .= " and username = '$username'" if (defined $username);

    warn "[DEBUG SQL] Spamity::Quarantine getRawSource $stmt\n" if (int(&conf('log_level')) > 0);
    
    $sth = $db->dbh->prepare($stmt);
    if ($sth && $sth->execute()) {
	$rawsource = $sth->fetchrow_arrayref;
	$rcpt_to = $$rawsource[0];
	$filter_type = $$rawsource[1];
	$filter_id = $$rawsource[2];
	$rawsource = $$rawsource[3];
    }
    else {
	$message = 'Select-statement error: '.$sth->errstr.' ('.$DBI::err.')';
	warn logPrefix, "Spamity::Quarantine getRawSource $message";
	return undef;
    }
    $sth->finish();

    # We create our email instance
    $obj = Mail::Internet->new([ split /\n/, $rawsource ]);
    
    $mail_from = $obj->head->get("X-Envelope-From");
    $mail_from =~ s/\n//;

    # We strip AMaViSd-new headers and some more (from SpamAssassin, the SMTP server itself, etc.)
    $obj->head->delete("Delivered-To");
    $obj->head->delete("Return-Path");
    $obj->head->delete("X-Envelope-From");
    $obj->head->delete("X-Envelope-To");
    $obj->head->delete("X-Quarantine-id");
    $obj->head->delete("X-Spam-Status");
    $obj->head->delete("X-Spam-Level");
    
    if ($filter_type =~ m/virus/) {
	if ($filter_id =~ m/^(?:W32\/)?(\S+)\b/) {
	    $virus_id = $1;
	}
	else {
	    # When the message is infected, virus_id MUST be defined.
	    $virus_id = $filter_id;
	}
    }

    return ($mail_from, $rcpt_to, $obj, $virus_id);
} # getRawSource


sub sendMail
{
    my $mail_from;
    my $rctp_to;
    my $obj;
    my $smtp;
    my $headers;
    my $body;
    my $message_id;
    my @parts;

    ($mail_from, $rcpt_to, $obj) = @_;

    $smtp = Net::SMTP->new(&conf('reinjection_smtp_server'),
			   Hello => &conf('master_domain'),
			   Timeout => 30, 
			   Debug => (int(&conf('log_level')) > 2));
    return 0 unless ($smtp);

    $message_id = time;
    $headers = $obj->head->as_string();
    $headers =~ s/(Message-Id: \<)(.*\>)/$1$message_id.$2/;
    $body = $obj->body();

    $smtp->mail($mail_from);
    $smtp->to($rcpt_to) || return 0;
    $smtp->data();
    $smtp->datasend($headers);
    $smtp->datasend("\n\n" . join("\n", @$body));
    $smtp->dataend();	
    $smtp->quit;
    
    return 1;
} # sendMail


1;

#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/lib/Spamity/Database.pm,v $
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

#
# The following parameters must be defined in your Spamity configuration file (/etc/spamity.conf):
#
# database_backend: Module used to handle database access. Either 'pgsql' or 'mysql'.
#   Example:
#   database_backend = pgsql
#

package Spamity::Database;

=head1 NAME

Spamity::Database - Generic database handler for PostgreSQL, MySQL, and Oracle
 (Oracle is supported only for the Spamity database).
 
=head1 DESCRIPTION
    
This Perl module handles the communication with a database server. 
A database source definition can be specified for the following parameters in 
Spamity configuration file:

=over 2

=item * spamity_database

=item * session_database

=item * amavisd-new_database

=back

=head1 USAGE

Specify the database source as "type:source" where "type" is either pgsql or 
mysql and "source" becomes the prefix of the source parameters.

The parameters are the following:

=over 4

=item * host (required)

The hostname or IP address of the database server.

=item * port

The port to connect to the server.

=item * name (required)

The name of the database.

=item * username (required)

Username to authenticate to the database server.

=item * password (required)

Password to authenticate to the database server.

=back

=head1 EXAMPLE

  spamity_database = mysql:localdb
  localdb_host = localhost
  localdb_name = spamitydb
  localdb_username = spamity
  localdb_password = myscreetpassword

=cut

use Spamity qw(conf logPrefix);
use DBI qw(:sql_types);

BEGIN {
    use Exporter;
    @Spamity::Database::ISA = qw(Exporter);
    @Spamity::Database::EXPORT = qw();
    @Spamity::Database::EXPORT_OK = qw($message);
}
use vars qw($message);

$message = undef;
my %ATTRIBUTES = (PrintError       => 0, 
		  RaiseError       => 0, 
		  AutoCommit       => 1, 
		  InactiveDestroy  => 1,
		  LongTruncOk      => 1,
		  LongReadLen      => &conf('quarantine_size_max') * 1024);
my %handlers;


sub DUPLICATE_KEY_ERROR
{
    my $self = shift;
    
    return eval('$Spamity::Database::'.$self->{_module}.'::DUPLICATE_KEY_ERROR');
};


sub BLOB_ATTR
{
    my $self = shift;

    return eval('$Spamity::Database::'.$self->{_module}.'::BLOB_ATTR');
};


my $moduleSub = sub
{
    my $self;
    my $rname;
    my @args;

    my $rsub;

    ($rname, $self, @args) = @_;
    $rsub = 'Spamity::Database::'.$self->{_module}.'::'.$rname;
    
    return &$rsub(@args);
}; # moduleSub


sub new
{
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $self = {
	database      => "spamity",
	autoconnect   => 0,
        _definition   => undef,
	_module       => undef,
	@_,
    };
    my $result = 1;

    $self = bless($self, $class);
    unless ($self->{_definition}) {
	$self->{_definition} = &conf($self->{database}.'_database');
    } 
    unless ($self->{_definition}) {
	$message = 'The database is not configured ('.$self->{database}.')';
	warn logPrefix, "Spamity::Database new $message";
	return 0;
    }
    elsif ($self->{_definition} =~ m/^(\S+):(\S+)/) {
	$self->{_module} = $1;
	my $source = $2;
	
	unless ($handlers{$self->{_definition}} && $handlers{$self->{_definition}}->ping()) {
	    unless (eval('require "Spamity/Database/$self->{_module}.pm"')) {
		$message = "Error loading database module ".$self->{_module};
		$message .= ': '.$@ if $@;
		warn logPrefix, "Spamity::Database new (",$self->{_definition},") $message\n";
		return 0;
	    }
	    $message = "Database connection error (".$self->{_definition}."): %s (%s)";
	    unless ($handlers{$self->{_definition}} = DBI->connect($self->getUrl($source),
								   &conf($source.'_username'),
								   &conf($source.'_password'),
								   \%ATTRIBUTES)) {
		$message = sprintf($message, $DBI::errstr, $DBI::err);
		warn logPrefix, "Spamity::Database new ", $message;
	    }
	    while (!$handlers{$self->{_definition}} || !$handlers{$self->{_definition}}->ping()) {
		$result = 0;
		last unless ($self->{autoconnect} > 0);
		sleep $self->{autoconnect};
		$message = sprintf($message, $DBI::errstr, $DBI::err);
		warn logPrefix, "Spamity::Database new ", $message;
		$handlers{$self->{_definition}} = DBI->connect($self->getUrl($source),
							       &conf($source.'_username'),
							       &conf($source.'_password'),
							       \%ATTRIBUTES);
		$result = 1;
	    }
	}
	
	my $rsub = 'Spamity::Database::'.$self->{_module}.'::postNew'; 
	if (exists &$rsub) {
	    &$rsub($handlers{$self->{_definition}});
	}
    }
    else {
	$message = "Unknown syntax: ",$self->{_definition};
	warn logPrefix, "Spamity::Database new $message\n";
	return 0;
    }
    
    return $result && $self;
} # constructor


sub dbh
{
    my $self = shift;

    return $handlers{$self->{_definition}};
} #dbh


sub formatFromSubquery
{
    return $moduleSub->('formatFromSubquery', @_);
} # formatFromSubquery


sub formatLimitWithOffset
{
    return $moduleSub->('formatLimitWithOffset', @_);
} # formatOffsetWithLimit


sub formatUnion
{
    my $self = shift;
    my $sql;
    my $hashref;

    my $currentsql;
    my $union = '';
    my @indexes;

    ($sql, $hashref) = @_;
    
    if ($hashref) {
	@indexes = keys(%{$hashref});
    }
    else {
	@indexes = (1 .. &conf('tables_count'), 'unknown');
    }

    for my $i (@indexes) {
	$union .= ' UNION ALL ' unless ($i == 1);
	$currentsql = $sql;
	$currentsql =~ s/\%i/$i/g;
	if ($hashref) {
	    $currentsql = sprintf($currentsql, join(q/' ,'/, @{$hashref->{$i}}));
	}
	$union .= $currentsql;
    }
    
    return $union;
} # formatUnion


sub getUrl
{
    return $moduleSub->('getUrl', @_);
} # getUrl


sub concatenate
{
    return $moduleSub->('concatenate', @_);
} # concatenate

sub getAfterByDay
{
    return $moduleSub->('getAfterByDay', @_);
} # getAfterByDay


sub getAfterByHour
{
    return $moduleSub->('getAfterByHour', @_);
} # getAfterByHour


sub getDay
{
    return $moduleSub->('getDay', @_);
} # getDay


sub getDOW
{
    return $moduleSub->('getDOW', @_);
} # getDOW


sub getHour
{
    return $moduleSub->('getHour', @_);
} # getHour


sub getOctetLength
{
    return $moduleSub->('getOctetLength', @_);
} # getOctetLength


sub getPeriodByDay
{
    return $moduleSub->('getPeriodByDay', @_);
} # getPeriodByDay

sub getUnixTime
{
    return $moduleSub->('getUnixTime', @_);
} # getMinUnixTime


sub getWeek
{
    return $moduleSub->('getWeek', @_);
} # getWeek


1;

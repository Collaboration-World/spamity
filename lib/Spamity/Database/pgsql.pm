#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/lib/Spamity/Database/pgsql.pm,v $
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

package Spamity::Database::pgsql;

use DBD::Pg;

$DUPLICATE_KEY_ERROR = 7;
$BLOB_ATTR = { pg_type => DBD::Pg::PG_BYTEA };

sub getUrl
{
    my $source;

    my $url;
    my $port;

    ($source) = @_;

    $port = &Spamity::Database::conf($source.'_port', 1) || '5432';
    $url = sprintf('dbi:Pg:dbname=%s;host=%s;port=%s',
		   &Spamity::Database::conf($source.'_name'), &Spamity::Database::conf($source.'_host'), $port);
    
    return $url;
} # getUrl


sub concatenate
{
    my @strings;
    
    @strings = @_;
    
    return join(' || ', @strings);
} # concatenate


sub formatFromSubquery
{
    # subquery in FROM must have an alias
    # For example, FROM (SELECT ...) [AS] foo.
    my $columns;
    my $subquery;
    my $tail;

    ($columns, $subquery, $tail) = @_;

    return "select $columns from ($subquery) as spamity".($tail?" $tail":"");
} # formatFromSubquery


sub formatLimitWithOffset
{
    my $stmt_ref;
    my $columns_ref;
    my $limit;
    my $offset;

    ($stmt_ref, $columns_ref, $limit, $offset) = @_;

    $$stmt_ref .= sprintf(' limit %i offset %i', $limit, $offset);
} # formatOffsetWithLimit


sub getAfterByDay
{
    my $column;
    my $date;
    my $interval;

    ($column, $date, $interval) = @_;
    
    return "DATE_TRUNC('day', $column) > (date '$date' - interval '$interval days')";
} # getAfterByDay


sub getAfterByHour
{
    my $column;
    my $date;
    my $interval;
    
    ($column, $date, $interval) = @_;
    
    return "DATE_TRUNC('hour', $column) > (timestamp '$date' - interval '$interval hours')";
} # getAfterByHour


sub getDay
{
    my $column;
    
    ($column) = @_;
    
    return "DATE_TRUNC('day', $column)";
} # getDay


sub getDOW
{
    # Spamity expects Sunday to be 0
    # In PostgreSQL, Sunday is 0
    my $column;

    ($column) = @_;
    
    return "EXTRACT(dow from $column)";
} # getDOW


sub getHour
{
    my $column;

    ($column) = @_;

    return "DATE_TRUNC('hour', $column)";
} # getHour


sub getOctetLength
{
    my $column;

    ($column) = @_;

    return "octet_length($column)";
} # getOctetLength done


sub getPeriodByDay
{
    my $column;
    my $from_day;
    my $to_day;

    ($column, $from_day, $to_day) = @_;

    return "DATE_TRUNC('day', $column) BETWEEN date '$from_day' AND date '$to_day'";
} # getPeriodByDay


sub getUnixTime
{
    my $column;

    ($column) = @_;

    return "EXTRACT(epoch from $column)::integer";
} # getMinUnixTime


sub getWeek
{
    my $column;

    ($column) = @_;

    return "EXTRACT(week from $column)";
} # getWeek

1;

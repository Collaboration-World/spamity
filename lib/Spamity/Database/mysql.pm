#!/usr/bin/perl
#
#  $Source: /opt/cvsroot/projects/Spamity/lib/Spamity/Database/mysql.pm,v $
#  $Name:  $
#
#  Copyright (c) 2005, 2006, 2007
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

package Spamity::Database::mysql;

use DBD::mysql;

$DUPLICATE_KEY_ERROR = 1062;
$BLOB_ATTR = { };

sub getUrl
{
    my $source;

    my $url;
    my $port;

    ($source) = @_;

    $port = &Spamity::Database::conf($source.'_port', 1) || '3306';
    $url = sprintf('DBI:mysql:database=%s;host=%s;port=%s',
		   &Spamity::Database::conf($source.'_name'), &Spamity::Database::conf($source.'_host'), $port);
    
    return $url;
} # getUrl


sub concatenate
{
    my @strings;

    @strings = @_;

    return 'CONCAT('.join(', ', @strings).')';
} # concatenate


sub formatFromSubquery
{
    # http://dev.mysql.com/doc/refman/4.1/en/unnamed-views.html
    # The [AS] name  clause is mandatory, because every table in a FROM clause
    # must have a name. 
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

    return "FROM_DAYS(TO_DAYS($column)) > DATE_SUB(\'$date\', interval $interval day)";
} # getAfterByDay


sub getAfterByHour
{
    my $column;
    my $date;
    my $interval;

    ($column, $date, $interval) = @_;

    return "FROM_UNIXTIME(UNIX_TIMESTAMP($column) - 60*MINUTE($column) - SECOND($column)) > DATE_SUB(\'$date\', interval $interval hour)";
} # getAfterByHour


sub getDay
{
    my $column;

    ($column) = @_;
    
    return "FROM_DAYS(TO_DAYS($column))";
} # getDay


sub getDOW
{
    # Spamity defines Sunday to be 0
    # In MySQL, Sunday is 6
    my $column;

    ($column) = @_;
    
    return "MOD(WEEKDAY($column)+1,7)";
} # getDOW


sub getHour
{
    my $column;

    ($column) = @_;

    return 'TIME_FORMAT(logdate, "%H:00:00")';
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

    return "TO_DAYS($column) >= TO_DAYS('$from_day') and TO_DAYS($column) <= TO_DAYS('$to_day')";
} # getPeriodByDay

sub getUnixTime
{
    my $column;

    ($column) = @_;

    return "UNIX_TIMESTAMP($column)";
} # getMinUnixTime


sub getWeek
{
    # From http://dev.mysql.com/doc/mysql/en/date-and-time-functions.html :
    # function week, mode 3 = first day of week is Monday, range is 1-53
    my $column;

    ($column) = @_;

    return "WEEK($column, 3)";
} # getWeek

1;

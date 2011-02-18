#!/usr/bin/perl
# -*- Mode: CPerl tab-width: 4; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4; cperl-indent-level: 4 -*-
#
#  Copyright (c) 2007-2011
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

package Spamity::Database::oracle;

use DBD::Oracle qw(:ora_types);

#$DUPLICATE_KEY_ERROR = 7;
$BLOB_ATTR = { ora_type => DBD::Oracle::ORA_BLOB };

sub getUrl
{
    my $source;

    my $url;
    my $port;

    ($source) = @_;

    $port = &Spamity::Database::conf($source.'_port', 1) || '1526';
    $url = sprintf('dbi:Oracle:host=%s;port=%s;sid=%s',
		   &Spamity::Database::conf($source.'_host'), $port, &Spamity::Database::conf($source.'_name'));
    
    return $url;
} # getUrl


sub postNew
{
    my $dbh;
    my $stmt;

    ($dbh) = @_;

    $stmt = "ALTER SESSION SET nls_timestamp_format = 'YYYY-MM-DD HH24:MI:SS'";

    warn "[DEBUG SQL] Spamity::Database::oracle postNew $stmt\n" if (int(&Spamity::Database::conf('log_level')) > 0);
    
    unless ($dbh->do($stmt)) {
	$message = 'Alter session-statement error: '.$DBI::errstr.' ('.$DBI::err.').';
	warn logPrefix, "Spamity::Database::oracle postNew $message";
    }
} # postNew


sub concatenate
{
    my @strings;
    
    @strings = @_;
    
    return join(' || ', @strings);
} # concatenate


sub formatFromSubquery
{
    # subquery in FROM must *not* have an alias
    my $columns;
    my $subquery;
    my $tail;

    ($columns, $subquery, $tail) = @_;

    return "select $columns from ($subquery)".($tail?" $tail":"");
} # formatFromSubquery


sub formatLimitWithOffset
{
    my $stmt_ref;
    my $columns_ref;
    my $limit;
    my $offset;

    ($stmt_ref, $columns_ref, $limit, $offset) = @_;

    $$stmt_ref = 'select ' 
	. join(', ', @$columns_ref)
	. ' from (select '
	. join(', ', @$columns_ref)
	. ', ROWNUM r from ('
	. $$stmt_ref
	. sprintf(')) where r between %i and %i', $offset, $offset+$limit);
} # formatOffsetWithLimit


sub getAfterByDay
{
    my $column;
    my $date;
    my $interval;

    ($column, $date, $interval) = @_;
    
    return "TRUNC(CAST($column AS DATE), 'DDD') > (TO_DATE('$date', 'YYYY-MM-DD') - $interval)";
} # getAfterByDay


sub getAfterByHour
{
    my $column;
    my $date;
    my $interval;
    
    ($column, $date, $interval) = @_;
    
    return "TRUNC(CAST($column AS DATE), 'HH24') > (TO_TIMESTAMP('$date', 'YYYY-MM-DD HH24:MI:SS') - INTERVAL '$interval' HOUR)";
} # getAfterByHour


sub getDay
{
    my $column;
    
    ($column) = @_;
    
    return "TO_CHAR($column, 'YYYY-MM-DD')";
} # getDay done


sub getDOW
{
    # Spamity expects Sunday to be 0
    # In Oracle, Sunday is 1
    my $column;

    ($column) = @_;
    
    return "TO_CHAR($column, 'D') - 1";
} # getDOW done


sub getHour
{
    my $column;

    ($column) = @_;

    return "TO_CHAR($column, 'YYYY-MM-DD HH24')";
} #getHour


sub getOctetLength
{
    my $column;

    ($column) = @_;

    return "DBMS_LOB.GETLENGTH($column)";
} # getOctetLength


sub getPeriodByDay
{
    my $column;
    my $from_day;
    my $to_day;

    ($column, $from_day, $to_day) = @_;

    return "TRUNC(CAST($column AS DATE), 'DDD') >= TO_DATE('$from_day', 'YYYY-MM-DD') AND TRUNC(CAST($column AS DATE), 'DDD') <= TO_DATE('$to_day', 'YYYY-MM-DD')";
} # getPeriodByDay


sub getUnixTime
{
    my $column;

    ($column) = @_;

    return "86400 * (TO_DATE(TO_CHAR(SYS_EXTRACT_UTC($column),'YYYYMMDD-HH24:MI:SS'),'YYYYMMDD-HH24:MI:SS') - TO_DATE('01.01.1970','DD.MM.YYYY'))";
} # getMinUnixTime


sub getWeek
{
    # From http://download-east.oracle.com/docs/cd/B19306_01/server.102/b14200/sql_elements004.htm#i34510 :
    # Week of year (1-52 or 1-53) based on the ISO standard.
    my $column;

    ($column) = @_;

    return "TO_CHAR($column, 'IW')";
} # getWeek

1;

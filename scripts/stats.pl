#!/usr/bin/env perl
#
#  $Source: /opt/cvsroot/projects/Spamity/scripts/stats.pl,v $
#  $Name:  $
#
#  Copyright (c) 2006, 2007
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
#  This script outputs some statistics on Spamity's database:
#  - data distribution by table (when you have multiple tables!)
#  - data distribution by server (when you have multiple servers!)
#
#  WIP - Comments/suggestions are welcomed!
#

use FileHandle;
use Spamity qw(conf logPrefix userKey);
use Spamity::Database;

my $db;
my $sth;
my $row;
my $i;
my @table_suffixes = ('');

# Set STDOUT unbuffered
$| = 1;

if (&conf('tables_count', 1)) {
    @table_suffixes = (1 .. &conf('tables_count'), 'unknown');
    @table_suffixes = map ("_$_", @table_suffixes);
}

# Establish database connection
die $Spamity::Database::message unless ($db = Spamity::Database->new(database => 'spamity'));

######################################################################
# Stats: Data distribution by table
######################################################################
my $count = 0;
my $maxdate = undef;
my $mindate = undef;

format TABLE_TOP =

Table                   Count  First entry          Last entry
-----------------------------------------------------------------------
.
format TABLE =
@<<<<<<<<<<<<<<<<<<  @>>>>>>>  @||||||||||||||||||  @||||||||||||||||||
$tablename, $$row[0], $$row[1], $$row[2]
.

format_name STDOUT "TABLE";
format_top_name STDOUT "TABLE_TOP";

foreach $i (@table_suffixes) {
    $tablename = "spamity$i";
    $sth = $db->dbh->prepare("SELECT count(id), min(logdate), max(logdate) FROM $tablename");
    if ($sth->execute && ($row = $sth->fetchrow_arrayref)) {
	$count += $$row[0];
	$mindate = $$row[1] unless ($mindate && $$row[1] gt $mindate);
	$maxdate = $$row[2] if ($$row[2] gt $maxdate);
	write;
    }
}

print '-----------------------------------------------------------------------', "\n";
$tablename = '';
$row = [ $count, $mindate, $maxdate ];
write;

######################################################################
# Stats: Data distribution by server
######################################################################
my $stmt;

format_lines_left STDOUT 0;

format HOST_TOP =

Host                    Count  First entry          Last entry
-----------------------------------------------------------------------
.
format HOST =
@<<<<<<<<<<<<<<<<<<  @>>>>>>>  @||||||||||||||||||  @||||||||||||||||||
$$row[0], $$row[1], $$row[2], $$row[3]
.

format_name STDOUT "HOST";
format_top_name STDOUT "HOST_TOP";

if (&conf('tables_count', 1)) {
    $stmt = $db->formatFromSubquery('host, sum(count) as count, min(mindate) as mindate, max(maxdate) as maxdate',
	$db->formatUnion('select host, count(id) as count, min(logdate) as mindate, max(logdate) as maxdate from spamity_%i group by host'),
	'group by host order by host');
}
else {
    $stmt = 'select host, count(id), min(logdate), max(logdate) from spamity group by host order by host';
}
$sth = $db->dbh->prepare($stmt);
if ($sth->execute()) {
    while ($row = $sth->fetchrow_arrayref()) {
	write;
    }
}

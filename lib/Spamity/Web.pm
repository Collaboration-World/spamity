#!/usr/bin/perl
# -*- Mode: CPerl tab-width: 4; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4; cperl-indent-level: 4 -*-
#
#  Copyright (c) 2003-2011
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

package Spamity::Web;

use Spamity qw(conf logPrefix userKey);
use Spamity::Database;
use Spamity::Lookup qw(getUsersByAddress);
use Spamity::i18n qw(setLanguage translate);
use CGI;
use CGI qw(escapeHTML unescapeHTML :cgi-lib);
use CGI::Session;
use Encode qw(encode decode);
use POSIX qw(strftime mktime);
use Template;
use GD::Graph::hbars;
use GD::Graph::colour qw(:colours);

BEGIN {
    use Exporter;
    @Spamity::Web::ISA = qw(Exporter);
    @Spamity::Web::EXPORT = qw();
    @Spamity::Web::EXPORT_OK = qw(cache @FILTERS @ACTIONS);
}
use vars qw(@FILTERS @ACTIONS);

$message = undef;

# Redirect errors to logfile
if (! -t STDIN && ! -t STDOUT && &conf('logfile', 1)) {
    open (STDERR, ">>".&conf('logfile')) or warn "Spamity::Web Can't write to logfile ".&conf('logfile').": $!";
}

# Filters
# (probably no use to be changed)
@FILTERS = ('rbl',
            'rhsbl client',
            'rhsbl server',
            'header date',
            'header subject',
            'header x-mailer',
            'header content-disposition',
            'header content-type',
            'body',
            'access username',
            'virus',
            'spam',
            'banned',
            'helo');

# External actions supported (implemented in external.cgi)
@ACTIONS = ('view',
            'reinject',
            'disablereport',
            'whitelist',
            'blacklist');

# Colors associated to the above filters, used for the statistics graphs
# (probably no use to be changed)
my @COLOURS = ('red',
               'green',
               'blue',
               'yellow',
               'orange',
               'lgreen',
               'lblue',
               'dpurple',
               'lred',
               'dyellow',
               'cyan',
               'dgray',
               'marine',
               'lorange');

# Templates
my $TT_CONFIG = {INCLUDE_PATH => &conf('templates_path'),
                 DEBUG        => 0};
my $TT;

# Sessions
if (&conf('session_path', 1)) {
    $SESSION_DRIVER = "driver:File";
} elsif (&conf('session_database') =~ m/^pgsql:/) {
    $SESSION_DRIVER = "driver:PostgreSQL";
} elsif (&conf('session_database') =~ m/^mysql:/) {
    $SESSION_DRIVER = "driver:MySQL";
} elsif (&conf('session_database') =~ m/^oracle:/) {
    $SESSION_DRIVER = "driver:Oracle";
}


sub getTemplate
  {
      return $TT if (defined $TT);
      $TT = Template->new($TT_CONFIG);
      if (!$TT) {
          $message = $Template::ERROR;
          warn logPrefix, "Spamity::Web::getTemplate $message\n";
          return 0;
      }
      return $TT;

  }                             # getTemplate


sub sessionConfig
  {
      my $db;

      if (&conf('session_path', 1)) {
          if (! -e &conf('session_path')) {
              return {error=>sprintf(&translate('Session directory %s doesn\'t exist.'),&conf('session_path'))};
          } elsif (! -w &conf('session_path')) {
              return {error=>sprintf(&translate('Session directory %s is not writable.'),&conf('session_path'))};
          }
          return {Directory=>&conf('session_path')};
      } elsif (&conf('session_database', 1)) {
          if (!($db = Spamity::Database->new(database => 'session'))) {
              return {error=>&translate('Database connection error.')};
          }
          return {Handle=>$db->dbh, ColumnType=>"binary"};
      }
      return 0;

  }                             # sessionConfig


sub strip
  {
      # Returns modulo 2 of a integer.
      # <parameters>
      #   count (integer)
      # <returns>
      #   the string "Odd" or "Even"
    
      my $count;
      my $id;

      ($count) = @_;

      $id = int($count)/2;

      if ($id == int($id)) {
          return "Odd";
      } else {
          return "Even";
      }

  }                             # strip


sub getFilterTypes
  {
      my $cid;
      my $cexp;
      my $sid;
      my $id;
    
      my $types_cached;
      my $type;
      my @types;
      my $stmt;
      my $db;
      my $sth;
    
      ($sid, $id) = @_;
      $cid = 'filtertypes';
      $cexp = '+1M';
    
      $types_cached = &cache($sid, $cid, $cexp, undef);
      if (defined $types_cached) {
          @types = split(',', $types_cached);
	
          return \@types;
      }
    
      return undef unless ($db = Spamity::Database->new(database => 'spamity'));
    
      $stmt = 'select distinct filter_type from spamity';
      if ($id) {
          # Limited to a username
          my $index = (&conf('tables_count', 1))?'_'.&userKey($id):'';
          $stmt .= $index." where username = '$id'";
      } elsif (&conf('tables_count', 1)) {
          # Multiple tables, no constraint on username
          $stmt = $db->formatFromSubquery('distinct filter_type',
                                          $db->formatUnion($stmt.'_%i'));
      }
      $stmt .= ' order by filter_type';

      warn "[DEBUG SQL] Spamity::Web getFilterTypes $stmt\n" if (int(&conf('log_level')) > 0);
    
      $sth = $db->dbh->prepare($stmt);
      if ($sth && $sth->execute()) {
          while ($type = $sth->fetchrow_arrayref) {
              push(@types, lc($$type[0]));
          }
      } else {
          $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.')';
          warn logPrefix, "Spamity::Web getFilterTypes $message\n";
      }
      $sth->finish();
    
      &cache($sid, $cid, $cexp, join(',', @types));
    
      return \@types;
    
  }                             # getFilterTypes


sub byfilter ($$)
  {
      my $filter;
    
      foreach $filter (@FILTERS) {
          return -1 if $filter =~ m/$_[0]/;
          return 1 if $filter =~ m/$_[1]/;
      }
    
      return -1;

  }                             # byfilter


sub getParameters
  {
      # Parses the supported parameters from a CGI query.
      # <parameters>
      #   a CGI query object
      # <returns>
      #   reference to a hash table of the valid query parameters

      my ($query) = @_;
      my %parameters;
    
      # Parse action from url; make it as simple as possible to support older
      # versions of the CGI module (< 3.0x)
      if ($query->url(-absolute=>1,-path=>1) =~ m/\.cgi\/+(\w+)\/?/) {
          $parameters{action} = lc($1);
      }

      # Default values
      $parameters{from_year} = $parameters{to_year} = strftime("%Y", localtime);
      $parameters{from_month} = $parameters{to_month} = strftime("%m", localtime);
      $parameters{from_day} = $parameters{to_day} = strftime("%d", localtime);
      $parameters{to_date_option} = 'now';
      $parameters{display} = 'email';
      $parameters{results} = &conf('results_page', 1) || 25;
      $parameters{page} = 1;
      $parameters{lang} = &conf('default_language', 1) || 'en_US';
      $parameters{cgibin_path} = &conf('cgibin_path');
      $parameters{htdocs_path} = &conf('htdocs_path', 1);
      $parameters{htdocs_path} = '' if ($parameters{htdocs_path} eq '/');
      $parameters{version} = $Spamity::VERSION . '';
    
      # Language
      &setLanguage($parameters{lang});
      $parameters{i18n} = \&translate;
    
      # Redirection url
      $parameters{url} = $query->url(-base=>1);
      $parameters{url} .= $parameters{cgibin_path};
      $parameters{url} =~ s/(?<!\/)$/\//; # make sure there's a trailing slash
      $parameters{url} =~ s/^http:/https:/ if (&conf('force_https', 1));

      # Form submit?
      if ($query->param('submit')) {
          $parameters{submit} = $query->param('submit');
      }
    
      # From date
      if ($query->param('from_year') && $query->param('from_month') && $query->param('from_day')) {
          $parameters{from_year} = $query->param('from_year');
          $parameters{from_month} = $query->param('from_month');
          $parameters{from_day} = $query->param('from_day');
          $parameters{from_date} = $query->param('from_year').'-'.$query->param('from_month').'-'.$query->param('from_day');
	
          # To date
          if ($query->param('to_date')) {
              $parameters{to_date_option} = $query->param('to_date');
              if ($query->param('to_date') =~ m/^now$/) {
                  $parameters{to_date} = strftime("%Y-%m-%d", localtime);
              } elsif ($query->param('to_date') =~ m/^same$/) {
                  $parameters{to_year} = $parameters{from_year};
                  $parameters{to_month} = $parameters{from_month};
                  $parameters{to_day} = $parameters{from_day};
                  $parameters{to_date} = $parameters{from_date};
              } elsif ($query->param('to_date') =~ m/^date$/ &&  $query->param('to_year') && $query->param('to_month') && $query->param('to_day')) {
                  $parameters{to_date} = $query->param('to_year').'-'.$query->param('to_month').'-'.$query->param('to_day');
                  if ($parameters{to_date} ge $parameters{from_date}) {
                      $parameters{to_year} = $query->param('to_year');
                      $parameters{to_month} = $query->param('to_month');
                      $parameters{to_day} = $query->param('to_day');
                  } else {
                      # To date is before from date
                      $parameters{to_year} = $parameters{from_year};
                      $parameters{to_month} = $parameters{from_month};
                      $parameters{to_day} = $parameters{from_day};
                      $parameters{to_date} = $parameters{from_date};
                  }
              }
          }
      }
    
      # Email or domain
      if ($query->param('email') && $query->param('email') !~ m/^\s*$/) {
          $parameters{email} = lc $query->param('email');
      }
    
      # Filter type
      if ($query->param('filter_type') && $query->param('filter_type') !~ m/^all$/) {
          $parameters{filter_type} = $query->param('filter_type');
      }
    
      # Display type
      if ($query->param('display') && $query->param('display') !~ m/^\s*$/) {
          $parameters{display} = $query->param('display');
      }

      # Number of results per page
      if ($query->param('results') && $query->param('results') =~ m/^\d+$/ && 
          $query->param('results') > 0) {
          $parameters{results} = $query->param('results');
      }
    
      # Page number
      if ($query->param('page') && $query->param('page') =~ m/^\d+$/) {
          $parameters{page} = $query->param('page');
      }

      # Override URL action
      if ($query->param('action')) {
          $parameters{action} = $query->param('action');
      }
    
      # Domain (admin only)
      if ($query->param('domain')) {
          $parameters{domain} = $query->param('domain');
      }
    
      # Username (admin only)
      if ($query->param('un')) {
          $parameters{un} = $query->param('un');
      }

      return \%parameters;
    
  }                             # getParameters


sub formatAddresses
  {
      # <parameters>
      #   a reference to an array prefixes ('to', 'from')
      #   a reference to an array of addresses
      # <returns>
      #   a SQL formatted string of the addresses for the specified prefixes

      my $prefix;
      my @prefixes;
      my $address;
      my @addresses;
      my $user;
      my $host;
    
      my @conditions = ();
    
      ($prefix, $address) = @_;
    
      @prefixes = @{$prefix};
      @addresses = @{$address};
    
      foreach $address (@addresses) {
          if ($address =~ m/^(.+?)@(.*?)$/) {
              $user = $1;
              $host = $2;
              foreach $prefix (@prefixes) { 
                  push(@conditions, "($prefix\_user='$user' and $prefix\_host='$host')");
              }
          } elsif ($address =~ m/^@(.*?)$/) {
              $host = $1;
              foreach $prefix (@prefixes) {
                  push(@conditions, "$prefix\_host='$host'");
              }
          } elsif ($address =~ m/(?<!=@)(.*?)$/) {
              $host = $1;
              foreach $prefix (@prefixes) {
                  push(@conditions, "$prefix\_user like '$host' or $prefix\_host like '$host'");
              }
          }
      }
    
      return join(' or ', @conditions);
    
  }                             # formatAddresses


sub formatMessage
  {
      my $msg;
    
      $msg = $_[0];
    
      if ($msg->{filter_type} =~ m/^(spam|virus)$/) {
          if ($msg->{filter_id} =~ m/(-\d{5}-\d{2})$/) {
              $msg->{filter_id} = $msg->{filter_type} . $1;
          }
      }
      $msg->{description} = escapeHTML($msg->{description});
      $msg->{logepoch} = int($msg->{logepoch});
      $msg->{day} = strftime(&translate('day-format'), localtime($msg->{logepoch}));
      if ($msg->{day} =~ m/\b([[:alpha:]]+)\b/) {
          my $month = $1;
          $msg->{day} =~ s/$month/&translate($month)/e;
      }
      $msg->{logtime} = strftime(&translate('time-format'), localtime($msg->{logepoch}));

  }                             # formatMessage


sub getMessagesByDate
  {
      my $from_date;
      my $to_date;
      my $email;
      my $filter_type;
      my $is_quarantined;
      my $id;
      my $domain;
      my $page;
      my $results_page;

      my @usernames;
      my %keys = ();
      my $key;
      my $index = undef;
      my $stmt;
      my @columns = ();
      my @conditions;
      my $msg;
      my %msgs;
      my @days;
      my $db;
      my $sth;
    
      ($from_date, $to_date, $email, $filter_type, $is_quarantined, $id, $domain, $page, $results_page) = @_;

      $db = Spamity::Database->new(database => 'spamity');

      push(@columns, 'id', 'logdate', 'logepoch', 'to_addr', 'from_addr', 'filter_type', 'filter_id', 'description', 'rawsource_length');
      $stmt = sprintf('select %%s as id, logdate, %s as logepoch, %s as to_addr, %s as from_addr, filter_type, filter_id, description, %s as rawsource_length from spamity%%s',
                      $db->getUnixTime('logdate'),
                      $db->concatenate(qw/to_user '@' to_host/),
                      $db->concatenate(qw/from_user '@' from_host/),
                      $db->getOctetLength('rawsource'));

      if ($id) {
          # Restrict search to a username
          push(@usernames, $id);
      } elsif ($email =~ m/\S+\@\S\.\w{2,4}/) {
          # If email address is local, restrict search to the appropriate usernames
          push(@usernames, &getUsersByAddress($email));
      }
      #    warn "keys are ",join(", ",(keys %keys)),"\n";
      if (scalar(@usernames) > 0) {
          push(@conditions, sprintf(q/username IN ('%s')/, join(q/', '/, @usernames)));
      }

      # Date range
      if ($from_date && $to_date) {
          push(@conditions, $db->getPeriodByDay('logdate', $from_date, $to_date));
      }
    
      # Local domain (only defined if user is administrator)
      if ($domain) {
          push(@conditions, '(' . &formatAddresses(['to','from'], ['@'.$domain]) . ')');
      }
    
      # Filter types
      if ($filter_type) {
          push(@conditions, "filter_type = '$filter_type'");
      }
    
      # Must be quarantined
      if ($is_quarantined) {
          push(@conditions, sprintf("%s > 0", $db->getOctetLength('rawsource')));
      }

      # Email/domain
      if ($email) {
          push(@conditions, '(' . &formatAddresses(['to','from'], [$email]) . ')');
      }

      # Complete SQL statement
      $stmt .= ' where ' . join(' and ', @conditions) if (@conditions > 0);
    
      if (&conf('tables_count', 1)) {
          # Multiple tables; find what tables to select depending on the username (if any)
          foreach (@usernames) {
              $key = &userKey($_);
              if (! defined $keys{$key}) {
                  $keys{$key} = [];
              }
              push(@{$keys{$key}}, $_);
          }
      }
    
      if (! defined &conf('tables_count', 1) || scalar(keys(%keys)) == 1) {
          # Only one table has to be accessed
          my @keys = keys(%keys);
          my $id;
          $key = shift(@keys);
          if (&conf('tables_count', 1)) {
              $index= '_'.$key;
              $id = $db->concatenate('id', q/':'/, $key);
          } else {
              $index = '';
              $id = 'id';
          }
          $stmt = sprintf($stmt, $id, $index);
      } elsif (scalar(keys(%keys)) > 0) {
          # Multiple tables, constraint on username
          $stmt = sprintf($stmt, $db->concatenate(qw/id ':' '%i'/), '_%i');
          $stmt = $db->formatUnion($stmt, \%keys);
      } else {
          # Multiple tables, no constraint on username
          $stmt = sprintf($stmt, $db->concatenate(qw/id ':' '%i'/), '_%i');
          $stmt = $db->formatUnion($stmt);
      }

      $stmt .= ' order by logdate desc';
      if (defined $page && int($results_page) > 0) {
          $db->formatLimitWithOffset(\$stmt, \@columns, $results_page, $page*$results_page);
      }

      warn logPrefix, "[DEBUG SQL] Spamity::Web getMessagesByDate $stmt\n" if (int(&conf('log_level', 1)) > 0);
    
      $sth = $db->dbh->prepare($stmt);
      if ($sth && $sth->execute()) {
          while (defined ($msg = $sth->fetchrow_hashref(NAME_lc))) {
              &formatMessage($msg);
              if (! defined $msgs{$msg->{day}}) {
                  $msgs{$msg->{day}} = [];
                  push(@days, $msg->{day});
              }
              push(@{$msgs{$msg->{day}}}, $msg);
          }
      } else {
          $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.').';
          warn logPrefix, "Spamity::Web getMessagesByDate $message\n";
      }
      $sth->finish();

      $msgs{DAYS} = \@days;
    
      # SQL statement to compute total number of rows
      $stmt = 'select count(*) as count from spamity%s';
      $stmt .= ' where '.join(' and ', @conditions) if (@conditions > 0);
      if (defined $index) {
          $stmt = sprintf($stmt, $index);
      } elsif (scalar(keys(%keys)) > 0) {
          $stmt = sprintf($stmt, '_%i');
          $stmt = $db->formatFromSubquery('sum(count) as count',
                                          $db->formatUnion($stmt, \%keys));
      } else {
          $stmt = sprintf($stmt, '_%i');
          $stmt = $db->formatFromSubquery('sum(count) as count',
                                          $db->formatUnion($stmt));
      }

      warn "[DEBUG SQL] Spamity::Web getMessagesByDate $stmt\n" if (int(&conf('log_level', 1)) > 0);

      $sth = $db->dbh->prepare($stmt);
      if ($sth && $sth->execute()) {
          if ($msg = $sth->fetchrow_arrayref) {
              $msgs{COUNT} = $$msg[0];
          } else {
              $msgs{COUNT} = 0;
          }
      } else {
          $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.').';
          warn logPrefix, "Spamity::Web getMessagesByDate $message\n";
      }
      $sth->finish();

      return %msgs;
    
  }                             # getMessagesByDate


sub getMessagesByEmail
  {
      my $from_date;
      my $to_date;
      my $email;
      my $filter_type;
      my $id;
      my $domain;
      my $page;
      my $results_page;

      my @usernames;
      my %keys = ();
      my $key;
      my $index = undef;
      my $stmt;
      my @columns = ();
      my @conditions;
      my $msg;
      my %msgs;
      my @ids;
      my $db;
      my $sth;
    
      ($from_date, $to_date, $email, $filter_type, $id, $domain, $page, $results_page) = @_;
    
      $db = Spamity::Database->new(database => 'spamity');

      push(@columns, 'id', 'logdate', 'logepoch', 'to_host', 'to_user', 'to_addr', 'from_addr', 'filter_type', 'filter_id', 'description', 'rawsource_length');
      $stmt = sprintf('select %%s as id, logdate, %s as logepoch, to_host, to_user, %s as to_addr, %s as from_addr, filter_type, filter_id, description, %s as rawsource_length from spamity%%s', 
                      $db->getUnixTime('logdate'), 
                      $db->concatenate(qw/to_user '@' to_host/), 
                      $db->concatenate(qw/from_user '@' from_host/),
                      $db->getOctetLength('rawsource'));
    
      if ($id) {
          # Restrict search to a username
          push(@usernames, $id);
      } elsif ($email =~ m/\S+\@\S\.\w{2,4}/) {
          # If email address is local, restrict search to the appropriate usernames
          push(@usernames, &getUsersByAddress($email));
      }

      if (scalar(@usernames) > 0) {
          push(@conditions, sprintf(q/username IN ('%s')/, join(q/', '/, @usernames)));
      }
    
      # Date range
      push(@conditions, $db->getPeriodByDay('logdate', $from_date, $to_date));
    
      # Local domain (only defined if user is administrator)
      if ($domain) {
          push(@conditions, '(' . &formatAddresses(['to','from'], ['@'.$domain]) . ')');
      }
    
      # Filter types
      if ($filter_type) {
          push(@conditions, "filter_type = '$filter_type'");
      }
    
      # Email/domain
      if ($email) {
          push(@conditions, '(' . &formatAddresses(['to','from'], [$email]) . ')');
      }
    
      # Complete SQL statement
      $stmt .= ' where ' . join(' and ', @conditions) if (@conditions > 0);

      if (&conf('tables_count', 1)) {
          # Multiple tables; find what tables to select depending on the username (if any)
          foreach (@usernames) {
              $key = &userKey($_);
              if (! defined $keys{$key}) {
                  $keys{$key} = [];
              }
              push(@{$keys{$key}}, $_);
          }
      }
    
      if (! defined &conf('tables_count', 1) || scalar(keys(%keys)) == 1) {
          # Only one table has to be accessed
          my @keys = keys(%keys);
          my $id;
          $key = shift(@keys);
          if (&conf('tables_count', 1)) {
              $index= '_'.$key;
              $id = $db->concatenate('id', q/':'/, $key);
          } else {
              $index = '';
              $id = 'id';
          }
          $stmt = sprintf($stmt, $id, $index);
      } elsif (scalar(keys(%keys)) > 0) {
          # Multiple tables, constraint on username
          $stmt = sprintf($stmt, $db->concatenate(qw/id ':' '%i'/), '_%i');
          $stmt = $db->formatUnion($stmt, \%keys);
      } else {
          # Multiple tables, no constraint on username
          $stmt = sprintf($stmt, $db->concatenate(qw/id ':' '%i'/), '_%i');
          $stmt = $db->formatUnion($stmt);
      }

      $stmt .= ' order by to_host, to_user, logdate';
      $db->formatLimitWithOffset(\$stmt, \@columns, $results_page, $page*$results_page);
    
      warn "[DEBUG SQL] Spamity::Web getMessagesByEmail $stmt\n" if (int(&conf('log_level', 1)) > 0);

      $sth = $db->dbh->prepare($stmt);
      if ($sth && $sth->execute()) {
          while (defined ($msg  = $sth->fetchrow_hashref(NAME_lc))) {
              &formatMessage($msg);
              if (! defined $msgs{$msg->{to_addr}}) {
                  $msgs{$msg->{to_addr}} = {};
                  push(@ids, $msg->{to_addr});
              }
              if (! defined $msgs{$msg->{to_addr}}->{$msg->{day}}) {
                  $msgs{$msg->{to_addr}}->{$msg->{day}} = [];
                  if (! defined $msgs{$msg->{to_addr}}->{DATES}) {
                      $msgs{$msg->{to_addr}}->{DATES} = [];
                  }
                  push(@{$msgs{$msg->{to_addr}}->{DATES}}, $msg->{day});
              }
              push(@{$msgs{$msg->{to_addr}}->{$msg->{day}}}, $msg);
          }
      } else {
          $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.').';
          warn logPrefix, "Spamity::Web getMessagesByEmail $message\n";
      }
      $sth->finish();
    
      $msgs{USERS} = \@ids;     # sorted array of users
    
      # SQL statement to compute total number of rows
      $stmt = 'select count(*) as count from spamity%s where '.join(' and ', @conditions);
      if (defined $index) {
          $stmt = sprintf($stmt, $index);
      } elsif (scalar(keys(%keys)) > 0) {
          $stmt = sprintf($stmt, '_%i');
          $stmt = $db->formatFromSubquery('sum(count) as count',
                                          $db->formatUnion($stmt, \%keys));
      } else {
          $stmt = sprintf($stmt, '_%i');
          $stmt = $db->formatFromSubquery('sum(count) as count',
                                          $db->formatUnion($stmt));
      }

      warn "[DEBUG SQL] Spamity::Web getMessagesByEmail $stmt\n" if (int(&conf('log_level', 1)) > 0);
    
      $sth = $db->dbh->prepare($stmt);
      if ($sth && $sth->execute()) {
          if ($msg = $sth->fetchrow_arrayref) {
              $msgs{COUNT} = $$msg[0];
          } else {
              $msgs{COUNT} = 0;
          }
      } else {
          $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.').';
          warn logPrefix, "Spamity::Web getMessagesByEmail $message\n";
      }
      $sth->finish();
 
      return %msgs;
    
  }                             # getMessagesByEmail


sub getStatsMostSpammed
  {
      my $interval;
      my $unit;
      my $limit;
      my $title;
    
      my $date;
      my $stmt;
      my %stats;
      my @stats;
      my $stat;
      my $db;
      my $sth;
    
      ($interval, $unit, $limit, $title) = @_;
    
      return undef unless ($db = Spamity::Database->new(database => 'spamity'));

      $date = ($unit =~ m/hour/)? strftime('%Y-%m-%d %H:00:00', localtime()) : strftime('%Y-%m-%d', localtime());
    
      my @columns = ('count', 'to_addr');
      $stmt = sprintf("select count(*) as count, lower(%s) as to_addr from spamity%%s where %s group by lower(%s)",
                      $db->concatenate(qw(to_user '@' to_host)),
                      eval('$db->getAfterBy'.ucfirst($unit).'(\'logdate\', $date, $interval)'),
                      $db->concatenate(qw(to_user '@' to_host)));

      if (&conf('tables_count', 1)) {
          # Multiple tables
          $stmt = $db->formatFromSubquery('sum(count) as count, to_addr',
                                          $db->formatUnion(sprintf($stmt, '_%i')),
                                          'group by to_addr');
      } else {
          # One table
          $stmt = sprintf($stmt, '');
      }

      $stmt .= ' order by count desc';
      $db->formatLimitWithOffset(\$stmt, \@columns, $limit, 0);

      warn "[DEBUG SQL] Spamity::Web getStatsMostSpammed $stmt\n" if (int(&conf('log_level', 1)) > 0);

      $sth = $db->dbh->prepare($stmt);
      if ($sth && $sth->execute()) {
          while ($stat = $sth->fetchrow_hashref(NAME_lc)) {
              push(@stats, $stat);
          }
      } else {
          $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.').';
          warn logPrefix, "Spamity::Web getStatsMostSpammed $message\n";
      }
      $sth->finish();
    
      %stats = ( title => $title, data => \@stats );
    
      return \%stats;
  }                             # getStatsMostSpammed


sub getCacheSID
  {
      # <parameters>
      #   id (username)
      # <returns>
      #   a session id
    
      my $id;
      my $sid;
      my $session;
      my $append;
      my $db;
      my $sth;

      ($id) = @_;
      $append = 1;
    
      if (&conf('session_path', 1)) {
          # The mapping of session IDs and usernames are stored
          # in a text file.
          if (open (FILE, "<" . &conf('session_path') . "/.cache")) {
              while (<FILE>) {
                  if (m/^$id\s+(\w+)$/) {
                      $sid = $1;
                      warn "[DEBUG CACHE] Spamity::Web getCacheSID (file) $id = $sid\n" if (int(&conf('log_level')) > 1);
                      last;
                  }
              }
              close (FILE);
          }
      } elsif (&conf('session_database')) {
          if ($db = Spamity::Database->new(database => 'session')) {
              # In the sessions database, the name of the column is the opposite
              # of the local variables (column id = $sid, column sid = $id)
              $sth = $db->dbh->prepare("select id from sessions where sid = ?");
              if ($sth && $sth->execute($id)) {
                  if (my $row = $sth->fetchrow_arrayref) {
                      $sid = $$row[0];
                      warn "[DEBUG CACHE] Spamity::Web getCacheSID (database) $id = $sid\n" if (int(&conf('log_level')) > 1);
                  }
              } else {
                  $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.')';
                  warn logPrefix, "Spamity::Web getCacheSID $message\n";
              }
              $sth->finish();
          }
      }
    
      if (defined $sid) {
          # Verify that session file exists
          $session = new CGI::Session($Spamity::Web::SESSION_DRIVER, $sid,
                                      &Spamity::Web::sessionConfig()) || warn logPrefix, $CGI::Session::errstr;
          if ($session->id() !~ m/$sid/) {
              # Session has expired
              $sid = undef;
              $append = 0;
              warn "[DEBUG CACHE] Spamity::Web getCacheSID Cache session for $id has expired\n" if (int(&conf('log_level')) > 1);
              $session->delete();
          } else {
              warn "[DEBUG CACHE] Spamity::Web getCacheSID $id = $sid\n" if (int(&conf('log_level')) > 1);
          }

          # Synchronizes data in the buffer with its copy in disk/database
          $session->flush();
      }
    
      if (! defined $sid) {
          $session = new CGI::Session($Spamity::Web::SESSION_DRIVER, undef,
                                      &Spamity::Web::sessionConfig()) || warn logPrefix, $CGI::Session::errstr;
          $session->expires('+1M');
          $sid = $session->id();

          # Synchronizes data in the buffer with its copy in disk/database
          $session->flush();

          warn "[DEBUG CACHE] Spamity::Web getCacheSID new cache session id for $id is $sid" if (int(&conf('log_level')) > 1);
	
          if (&conf('session_path', 1)) {
              if ($append) {
                  # New user; append session id to file
                  open (FILE, ">>" . &conf('session_path') . "/.cache") or return undef;
                  print FILE "$id $sid\n";
              } else {
                  # Existing user; update file
                  open (FILE, "+<" . &conf('session_path') . "/.cache") or return undef;
                  my @lines = <FILE>;
                  for (my $i = 0; $i < $#lines; $i++) {
                      if ($lines[$i] =~ m/^$id\s+/) {
                          $lines[$i] = "$id $sid\n";
                          last;
                      }
                  }
                  seek (FILE, 0, 0);
                  print FILE @lines;
                  truncate (FILE, tell(FILE));
                  close (FILE);
              }
          } elsif (&conf('session_database')) {
              if ($db = Spamity::Database->new(database => 'session')) {
                  # Associated the new session with the id (username)
                  $sth = $db->dbh->prepare("update sessions set sid = ? where id = ?");
                  unless ($sth && $sth->execute($id, $sid)) {
                      $message = 'Update-statement error: '.$DBI::errstr.' ('.$DBI::err.')';
                      warn logPrefix, "Spamity::Web getCacheSID $message\n";
                  }
                  # Note: when using the MySQL driver, the column sid will be lost when
                  # loading the session since it uses REPLACE INTO statements (crap).
                  # MySQL would require a new table only to map usernames to session ids.
              }
          }
      }
    
      return $sid;
    
  }                             # getCacheSID


sub cache
  {
      # <parameters>
      #   sid (session id)
      #   cid (cached data id)
      #   cexp (expiration)
      #   data
      # <returns>
      #   the cached data (can be undefined)

      my $sid;
      my $cid;
      my $cexp;
      my $data;
    
      my $session;
    
      ($sid, $cid, $cexp, $data) = @_;
    
      #return undef; # no cache
      #    warn "Spamity::Web cache no session id!\n" unless (defined $sid);
      return undef unless (defined $sid);
    
      $session = new CGI::Session($Spamity::Web::SESSION_DRIVER, $sid,
                                  &Spamity::Web::sessionConfig()) || warn logPrefix, $CGI::Session::errstr;
      warn "[DEBUG CACHE] Spamity::Web cache ",(defined $session->param($cid))?"hit":"miss"," $cid for $cexp in $sid" if (int(&conf('log_level')) > 1);
      if (defined $data) {
          warn "[DEBUG CACHE] Spamity::Web cache caching $cid for $cexp in $sid\n" if (int(&conf('log_level')) > 1);
          $session->param($cid, $data);
          $session->expires($cid, $cexp);
      }
    
      return $session->param($cid); # can be undef
    
  }                             # cached


sub colorsForFilters
  {
      my @filters;
      my $filter;
      my @colours;
      my $i = 0;
      my $j = 0;

      @filters = @{$_[0]};

      foreach (@FILTERS) {
          if (defined $filters[$i] && m/^$filters[$i]$/) {
              push(@colours, $COLOURS[$j]);
              $i++;
          }
          $j++;
      }

      return \@colours;
  }                             # colorsForFilters


sub getGraphByCount
  {
      my $cid;
      my $cexp;
      my $sid;
    
      my $filter_type;
      my %stats;
      my $date;
      my $image;
      my $stmt;
      my $db;
      my $sth;
    
      my @filters;
      my @stats_sorted;
    
      $cid = "GraphByCount";
      $cexp = '+1d';
      ($sid) = @_;
    
      $image = &cache($sid, $cid, $cexp, undef);
      if (defined $image) {
          return $image;
      }
    
      return undef unless ($db = Spamity::Database->new(database => 'spamity'));
    
      $stmt = 'select count(*) as count, filter_type from spamity%s group by filter_type';
      if (&conf('tables_count', 1)) {
          # Multiple tables
          $stmt = $db->formatFromSubquery('sum(count) as count, filter_type', 
                                          $db->formatUnion(sprintf($stmt, '_%i')),
                                          'group by filter_type');
      } else {
          # One table
          $stmt = sprintf($stmt, '');
      }

      warn "[DEBUG SQL] Spamity::Web getGraphByCount $stmt\n" if (int(&conf('log_level', 1)) > 0);

      $sth = $db->dbh->prepare($stmt);
      if ($sth && $sth->execute()) {
          while ($filter_type = $sth->fetchrow_arrayref) {
              $stats{$$filter_type[1]} = $$filter_type[0];
          }
      } else {
          $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.')';
          warn logPrefix, "Spamity::Web getGraphByCount $message\n";
      }
      $sth->finish();
    
      $stmt = sprintf('select %s as logdate from spamity', $db->getUnixTime('min(logdate)'));
      if (&conf('tables_count', 1)) {
          $stmt = $db->formatFromSubquery('min(logdate)',
                                          $db->formatUnion($stmt.'_%i'));
      }

      warn "[DEBUG SQL] Spamity::Web getGraphByCount $stmt\n" if (int(&conf('log_level', 1)) > 0);

      $sth = $db->dbh->prepare($stmt);
      if ($sth && $sth->execute()) {
          $date = $sth->fetchrow_arrayref;
          $date = int($$date[0]);
          $date = strftime(&translate('day-format'), localtime($date));
      } else {
          $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.')';
          warn logPrefix, "Spamity::Web getGraphByCount $message\n";
      }
      $sth->finish();

      if (defined $date) {
          my @filters_unsorted = (keys %stats);
          @filters = sort byfilter @filters_unsorted;
          foreach $filter_type (@filters) {
              push(@stats_sorted, $stats{$filter_type});
          }
          if ($date =~ m/\b([[:alpha:]]+)\b/) {
              my $month = $1;
              $date =~ s/$month/&translate($month)/e;
          }
      } else {
          @stats_sorted = (undef);
          @filters = @FILTERS;
      }
    
      my @data = (\@filters, \@stats_sorted);
    
      my $graph = GD::Graph::hbars->new(500, 350);
      $graph->set(
                  x_label      => '',
                  x_label_position => 0,
                  y_label      => encode('iso-8859-1', decode('utf-8', &translate('number of rejected messages')
                                                              . ((defined $date)?
                                                                 ' '.&translate('since')." $date":""))),
                  y_min_value  => 0,
                  y_label_skip => ((defined $date)?1:10),
                  dclrs        => ['dblue'],
                  accentclr    => 'gray',
                  textclr      => 'black',
                  labelclr     => 'black',
                  axislabelclr => 'black',
                  valuesclr    => 'black',
                  fgclr        => 'lgray',
                  cumulate     => 1,
                  show_values  => 1
                 ) or warn logPrefix, $graph->error;
    
      $image = $graph->plot(\@data)->png or warn logPrefix, $graph->error;
      &cache($sid, $cid, $cexp, $image);
    
      return $image;
    
  }                             # getGraphByCount


sub getGraphByUser
  {
      my $cexp;
      my $cid;
      my $sid;
      my $id;
    
      my $filter_type;
      my %stats;
      my $date;
      my $image;
      my $stmt;
      my $db;
      my $sth;
    
      my @filters;
      my @stats_sorted;
    
      $cid = 'GraphByUser';
      $cexp = '+1d';
      ($sid, $id) = @_;
    
      $image = &cache($sid, $cid, $cexp, undef);
      if (defined $image) {
          return $image;
      }
    
      return undef unless ($db = Spamity::Database->new(database => 'spamity'));
    
      $stmt = 'select count(*) as count, filter_type from spamity'
        . (&conf('tables_count', 1)?'_'.&userKey($id):'')
          . " where username = '$id' group by filter_type";
    
      warn "[DEBUG SQL] Spamity::Web getGraphByUser ($id) $stmt\n" if (int(&conf('log_level')) > 0);

      $sth = $db->dbh->prepare($stmt);
      if ($sth && $sth->execute()) {
          while ($filter_type = $sth->fetchrow_arrayref) {
              $stats{$$filter_type[1]} = $$filter_type[0];
          }
      } else {
          $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.')';
          warn logPrefix, "Spamity::Web getGraphByUser $message\n";
      }
      $sth->finish();

      if (keys(%stats) > 0) {
          $stmt = sprintf('select %s from spamity' . (&conf('tables_count', 1)?'_'.&userKey($id):''),
                          $db->getUnixTime('min(logdate)'));
	
          warn "[DEBUG SQL] Spamity::Web getGraphByUser ($id) $stmt\n" if (int(&conf('log_level')) > 0);
	
          $sth = $db->dbh->prepare($stmt);
	
          if ($sth && $sth->execute()) {
              $date = $sth->fetchrow_arrayref;
              $date = int($$date[0]);
              $date = strftime(&translate('day-format'), localtime($date));
              if ($date =~ m/\b([[:alpha:]]+)\b/) {
                  my $month = $1;
                  $date =~ s/$month/&translate($month)/e;
              }
          } else {
              $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.')';
              warn logPrefix, "Spamity::Web getGraphByUser $message\n";
          }
          $sth->finish();
	
          my @filters_unsorted = (keys %stats);
          @filters = sort byfilter @filters_unsorted;
          foreach $filter_type (@filters) {
              push(@stats_sorted, $stats{$filter_type});
          }
      } else {
          @stats_sorted = (0);
          @filters = @FILTERS;
      }
    
      my @data = (\@filters, \@stats_sorted);
    
      my $graph = GD::Graph::hbars->new(500, 350);
      $graph->set(
                  x_label      => '',
                  y_label      => encode('iso-8859-1', decode('utf-8', &translate('number of rejected messages')
                                                              . ((keys(%stats) > 0)?
                                                                 ' '. &translate('since')." $date":""))),
                  y_min_value  => 0,
                  y_label_skip => ((keys(%stats) > 0)?1:10),
                  dclrs        => ['dblue'],
                  accentclr    => 'gray',
                  textclr      => 'black',
                  labelclr     => 'black',
                  axislabelclr => 'black',
                  valuesclr    => 'black',
                  fgclr        => 'lgray',
                  cumulate     => 1,
                  show_values  => 1
                 ) or warn logPrefix, $graph->error;
    
      $image = $graph->plot(\@data)->png or warn logPrefix, $graph->error;
      &cache($sid, $cid, $cexp, $image);
    
      return $image;
    
  }                             # getGraphByUser


sub getGraphByUserAndLast24Hours
  {
      my $cid;
      my $cexp;
      my $sid;
      my $id;
    
      my $stmt;
      my @filters_unsorted;
      my @filters;
      my $filter_type;
      my %stats;
      my @stats;
      my $stat;
      my $hour;
      my @hours;
      my $count;
      my $size;
      my $image;
      my $db;
      my $sth;
    
      ($sid, $id) = @_;
      $cid = 'GraphByUserAndLast24Hours';
      $cexp = '+30m';
    
      $image = &cache($sid, $cid, $cexp, undef);
      if (defined $image) {
          return $image;
      }
    
      return undef unless ($db = Spamity::Database->new(database => 'spamity'));
    
      for ($count = 23; $count >= 0; $count = $count - 1) {
          push(@hours, strftime("%H", localtime(time() - 60*60*$count)));
      }
    
      $stmt = 'select count(*) as count, '
        . $db->getHour('logdate')
          . ' as hour, filter_type from spamity%s where %s'
            . $db->getAfterByHour('logdate', strftime('%Y-%m-%d %H:00:00', localtime()), '24')
              . ' group by ' . $db->getHour('logdate') . ', filter_type';

      if ($id) {
          # Limited to a username
          my $index = (&conf('tables_count', 1))?'_'.&userKey($id):'';
          $stmt = sprintf($stmt, $index, "username = '$id' and ");
      } elsif (&conf('tables_count', 1)) {
          # Multiple tables, no constraint on username (admin)
          $stmt = $db->formatFromSubquery('sum(count) as count, hour, filter_type',
                                          $db->formatUnion(sprintf($stmt, '_%i', '')),
                                          'group by hour, filter_type');
      } else {
          # One table, no constraint on username (admin)
          $stmt = sprintf($stmt, '', '');
      }
      $stmt .= ' order by filter_type, hour';

      warn "[DEBUG SQL] Spamity::Web getGraphByUserAndLast24Hours $stmt\n" if (int(&conf('log_level')) > 0);

      $sth = $db->dbh->prepare($stmt);
      if ($sth && $sth->execute()) {
	
          while (defined ($stat = $sth->fetchrow_hashref(NAME_lc))) {
	    
              if (! defined $stats{$stat->{filter_type}}) {
                  # New filter type
                  $stats{$stat->{filter_type}} = [];
                  $count = 0;
              }
	    
              # Push zeros if hours are not sequential
              for ($hour = $hours[$count++]; $stat->{hour} !~ m/\b$hour(:\d{2}:\d{2}.*)?$/; $hour = $hours[$count++]) {
                  push (@{$stats{$stat->{filter_type}}}, 0);
              }
	    
              push (@{$stats{$stat->{filter_type}}}, $stat->{count});
	    
          }                     # while
	
          # Adjust arrays to maximum size
          foreach $filter_type (keys %stats) {
              $size = @{$stats{$filter_type}};
              while ($size <= 23) {
                  push(@{$stats{$filter_type}}, 0);
                  $size = $size + 1;
              }
          }
      } else {
          $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.')';
          warn logPrefix, "Spamity::Web getGraphByUserAndLast24Hours $message\n";
      }
      $sth->finish();
    
      my $graph = GD::Graph::bars->new(500, 350);
    
      if (keys(%stats) > 0) {
          @filters_unsorted = (keys %stats);
          @filters = sort byfilter @filters_unsorted;
          foreach $filter_type (@filters) {
              push(@stats, [@{$stats{$filter_type}}]);
          }
          $graph->set_legend(@filters);
      } else {
          @stats = [0];
          @filters = @FILTERS;
      }
    
      my @data = (\@hours, @stats);
    
      $graph->set(
                  x_label          => '',
                  y_label          => &translate('number of messages'),
                  y_label_position => 0.5,
                  y_min_value      => 0,
                  y_label_skip     => ((keys(%stats) > 0)?1:10),
                  dclrs            => &colorsForFilters(\@filters),
                  accentclr        => 'gray',
                  textclr          => 'black',
                  labelclr         => 'black',
                  axislabelclr     => 'black',
                  valuesclr        => 'black',
                  fgclr            => 'lgray',
                  cumulate         => 1,
                  bar_spacing      => 2
                 ) or warn logPrefix, $graph->error;
    
      $image = $graph->plot(\@data)->png or warn logPrefix, $graph->error;
      &cache($sid, $cid, $cexp, $image);
    
      return $image;

  }                             # getGraphByUserAndLast24Hours


sub getGraphByUserAndWeek
  {
      my $cid;
      my $cexp;
      my $sid;
      my $id;
    
      my $stmt;
      my $time;
      my @filters_unsorted;
      my @filters;
      my $filter_type;
      my %stats;
      my @stats;
      my $stat;
      my @days;
      my $day;
      my @dow;
      my $count;
      my $size;
      my $image;
      my $db;
      my $sth;
    
      $cid = 'GraphByUserAndWeek';
      $cexp = '+6h';
      ($sid, $id) = @_;
    
      $image = &cache($sid, $cid, $cexp, undef);
      if (defined $image) {
          return $image;
      }
    
      return undef unless ($db = Spamity::Database->new(database => 'spamity'));

      for ($count = 6; $count >= 0; $count = $count - 1) {
          $time = time() - 60*60*24*$count;
          push(@days, strftime("%Y-%m-%d", localtime($time)));
          push(@dow, strftime("%a", localtime($time)));
      }
    
      $stmt = 'select count(*) as count, '
        . $db->getDay('logdate')
          . ' as day, filter_type from spamity%s where %s'
            . $db->getAfterByDay('logdate', strftime('%Y-%m-%d', localtime()), '7')
              . ' group by ' . $db->getDay('logdate') . ', filter_type';

      if ($id) {
          # Limited to a username
          my $index = (&conf('tables_count', 1))?'_'.&userKey($id):'';
          $stmt = sprintf($stmt, $index, "username = '$id' and ");
      } elsif (&conf('tables_count', 1)) {
          # Multiple tables, no constraint on username (admin)
          $stmt = $db->formatFromSubquery('sum(count) as count, day, filter_type',
                                          $db->formatUnion(sprintf($stmt, '_%i', '')),
                                          'group by day, filter_type');
      } else {
          # One table, no constraint on username (admin)
          $stmt = sprintf($stmt, '', '');
      }
      $stmt .= ' order by filter_type, day';

      warn "[DEBUG SQL] Spamity::Web getGraphByUserAndWeek $stmt\n" if (int(&conf('log_level')) > 0);
   
      my $graph = GD::Graph::bars->new(500, 350);

      $sth = $db->dbh->prepare($stmt);
      if ($sth && $sth->execute()) {

          while (defined ($stat  = $sth->fetchrow_hashref(NAME_lc))) {
	    
              if (! defined $stats{$stat->{filter_type}}) {
                  # New filter type
                  $stats{$stat->{filter_type}} = [];
                  $count = 0;
              }
	    
              # Push zeros if dates are not sequential
              for ($day = $days[$count++]; $stat->{day} !~ m/^$day/; $day = $days[$count++]) {
                  push (@{$stats{$stat->{filter_type}}}, 0);
              }
              push (@{$stats{$stat->{filter_type}}}, $stat->{count});
          }
	
          # Adjust arrays to maximum size
          foreach $filter_type (keys %stats) {
              $size = @{$stats{$filter_type}};
              while ($size <= 6 ) {
                  push(@{$stats{$filter_type}}, 0);
                  $size = $size + 1;
              }
          }
      } else {
          $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.')';
          warn logPrefix, "Spamity::Web getGraphByUserAndWeek $message\n";
      }
      $sth->finish();
    
      if (keys(%stats) > 0) {
          @filters_unsorted = (keys %stats);
          @filters = sort byfilter @filters_unsorted;
          foreach $filter_type (@filters) {
              push(@stats, [@{$stats{$filter_type}}]);
          }
          $graph->set_legend(@filters);
      } else {
          @stats = [0];
          @filters = @FILTERS;
      }
    
      my @data = (\@dow, @stats);
    
      $graph->set(
                  x_label          => &translate('day of week'),
                  x_label_position => 0.5,
                  y_label          => &translate('number of messages'),
                  y_label_position => 0.5,
                  y_min_value      => 0,
                  y_label_skip     => ((keys(%stats) > 0)?1:10),
                  dclrs            => &colorsForFilters(\@filters),
                  accentclr        => 'gray',
                  textclr          => 'black',
                  labelclr         => 'black',
                  axislabelclr     => 'black',
                  valuesclr        => 'black',
                  fgclr            => 'lgray',
                  cumulate         => 1,
                  bar_spacing      => 4,
                 ) or warn logPrefix, $graph->error;
    
      $image = $graph->plot(\@data)->png or warn logPrefix, $graph->error;
      &cache($sid, $cid, $cexp, $image);
    
      return $image;
    
  }                             # getGraphByUserAndWeek


sub getAvgGraphByUserAndDoW
  {
      my $cid;
      my $cexp;
      my $sid;
      my $id;
    
      my $index;
      my $stmt;
      my $day;
      my $filter_type;
      my @filters_unsorted;
      my @filters;
      my %stats;
      my @stats;
      my $image;
      my $db;
      my $sth;
    
      $cid = 'AvgGraphByUserAndDoW';
      $cexp = '+6h';
      ($sid, $id) = @_;
    
      $image = &cache($sid, $cid, $cexp, undef);
      if (defined $image) {
          return $image;
      }
    
      return undef unless ($db = Spamity::Database->new(database => 'spamity'));
    
      $stmt = 'select count(*) as count, '
        . $db->getDOW('logdate')
          . ' as dow, filter_type from spamity%s'
            . ' group by ' . $db->getDOW('logdate') . ', filter_type';

      if ($id) {
          # Limited to a username
          $index = (&conf('tables_count', 1))?'_'.&userKey($id):'';
          $stmt = sprintf($stmt, $index, "where username = '$id' ");
      } elsif (&conf('tables_count', 1)) {
          # Multiple tables, no constraint on username (admin)
          $stmt = $db->formatFromSubquery('sum(count) as count, dow, filter_type',
                                          $db->formatUnion(sprintf($stmt, '_%i', '')),
                                          'group by dow, filter_type');
      } else {
          # One table, no constraint on username (admin)
          $stmt = sprintf($stmt, '', '');
      }
      $stmt .= ' order by dow, filter_type';

      warn "[DEBUG SQL] Spamity::Web getAvgGraphByUserAndDoW $stmt\n" if (int(&conf('log_level')) > 0);

      my $graph = GD::Graph::bars->new(500, 350);

      $sth = $db->dbh->prepare($stmt);
      if ($sth && $sth->execute()) {
	
          while (defined ($day  = $sth->fetchrow_hashref(NAME_lc))) {
	    
              $stats{$day->{filter_type}} = [] if (! defined $stats{$day->{filter_type}});
	    
              foreach $filter_type (keys %stats) {
                  while ((@{$stats{$filter_type}}+1) < $day->{dow}) {
                      push (@{$stats{$filter_type}}, 0);
                  }
              }
              push(@{$stats{$day->{filter_type}}}, $day->{count});
          }
      } else {
          $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.')';
          warn logPrefix, "Spamity::Web getAvgGraphByUserAndDoW $message\n";
      }
      $sth->finish();
    
      if (keys(%stats) > 0) {
          $stmt = 'select count(distinct '
            . $db->getWeek('logdate')
              . ') as count, '
                . $db->getDOW('logdate')
                  . ' as dow from spamity%s group by ' . $db->getDOW('logdate');
	
          if ($id) {
              # Limited to a username
              $stmt = sprintf($stmt, $index, "where username = '$id' ");
          } elsif (&conf('tables_count', 1)) {
              # Multiple tables, no constraint on username (admin)
              $stmt = $db->formatFromSubquery('sum(count) as count, dow',
                                              $db->formatUnion(sprintf($stmt, '_%i', '')),
                                              'group by dow');
          } else {
              # One table, no constraint on username (admin)
              $stmt = sprintf($stmt, '', '');
          }
          $stmt .= ' order by dow';
	
          warn "[DEBUG SQL] Spamity::Web getAvgGraphByUserAndDoW $stmt\n" if (int(&conf('log_level')) > 0);

          $sth = $db->dbh->prepare($stmt);
          if ($sth && $sth->execute()) {
              while (defined ($day  = $sth->fetchrow_hashref(NAME_lc))) {
                  foreach $filter_type (keys %stats) {
                      if (defined ${$stats{$filter_type}}[$day->{dow}] && $day->{count} > 0) {
                          ${$stats{$filter_type}}[$day->{dow}] = ${$stats{$filter_type}}[$day->{dow}] / $day->{count};
                      }
                  }
              }
          } else {
              $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.')';
              warn logPrefix, "Spamity::Web getAvgGraphByUserAndDoW $message\n";
          }
          $sth->finish();
	
          @filters_unsorted = (keys %stats);
          @filters = sort byfilter @filters_unsorted;
          foreach my $filter_type (@filters) {
              push(@stats, [@{$stats{$filter_type}}]);
          }
          $graph->set_legend(@filters);
      } else {
          @filters = @FILTERS;
          @stats = [0];
      }
    
      @wdays = ();
      for (my $i = 0; $i < 6; $i++) {
          push(@wdays, strftime('%a', 0,0,0,0,0,0,$i));
      }

      my @data = (\@wdays, @stats);
    
      $graph->set(
                  x_label          => &translate('day of week'),
                  x_label_position => 0.5,
                  y_label          => &translate('average number of messages'),
		y_label_position => 0.5,
                  y_min_value      => 0,
                  y_label_skip     => ((keys(%stats) > 0)?1:10),
		dclrs            => &colorsForFilters(\@filters),
		accentclr        => 'gray',
		textclr          => 'black',
		labelclr         => 'black',
		axislabelclr     => 'black',
		valuesclr        => 'black',
		fgclr            => 'lgray',
		cumulate         => 1,
		bar_spacing      => 4,
                 ) or warn logPrefix, $graph->error;
    
      $image = $graph->plot(\@data)->png or warn logPrefix, $graph->error;
      &cache($sid, $cid, $cexp, $image);

      return $image;

  }                             # getAvgGraphByUserAndDoW


sub getGraphByUserAndMonth
  {
      my $cid;
      my $cexp;
      my $sid;
      my $id;
    
      my $stmt;
      my @filters_unsorted;
      my @filters;
      my $filter_type;
      my %stats;
      my @stats;
      my $stat;
      my @days;
      my $day;
      my $count;
      my $size;
      my $image;
      my $db;
      my $sth;
    
      ($sid, $id) = @_;
      $cid = 'GraphByUserAndMonth';
      $cexp = '+12h';
    
      $image = &cache($sid, $cid, $cexp, undef);
      if (defined $image) {
          return $image;
      }
    
      return undef unless ($db = Spamity::Database->new(database => 'spamity'));
    
      for ($count = 30; $count >= 0; $count = $count - 1) {
          push(@days, strftime("%Y-%m-%d", localtime(time() - 60*60*24*$count)));
      }
    
      $stmt = 'select count(*) as count, '
        . $db->getDay('logdate')
          . ' as day, filter_type from spamity%s where %s'
            . $db->getAfterByDay('logdate', strftime('%Y-%m-%d', localtime()), '31')
              . ' group by ' . $db->getDay('logdate') . ', filter_type';
    
      if ($id) {
          # Limited to a username
          my $index = (&conf('tables_count', 1))?'_'.&userKey($id):'';
          $stmt = sprintf($stmt, $index, "username = '$id' and ");
      } elsif (&conf('tables_count', 1)) {
          # Multiple tables, no constraint on username (admin)
          $stmt = $db->formatFromSubquery('sum(count) as count, day, filter_type',
                                          $db->formatUnion(sprintf($stmt, '_%i', '')),
                                          'group by day, filter_type');
      } else {
          # One table, no constraint on username (admin)
          $stmt = sprintf($stmt, '', '');
      }
      $stmt .= ' order by filter_type, day';

      warn "[DEBUG SQL] Spamity::Web getGraphByUserAndMonth $stmt\n" if (int(&conf('log_level')) > 0);

      my $graph = GD::Graph::bars->new(500, 350);
    
      $sth = $db->dbh->prepare($stmt);
      if ($sth && $sth->execute()) {
	
          while (defined ($stat = $sth->fetchrow_hashref(NAME_lc))) {
	    
              if (! defined $stats{$stat->{filter_type}}) {
                  # New filter type
                  $stats{$stat->{filter_type}} = [];
                  $count = 0;
              }	 
	    
              # Push zeros if dates are not sequential
              for ($day = $days[$count++]; $stat->{day} !~ m/^$day/; $day = $days[$count++]) {
                  push (@{$stats{$stat->{filter_type}}}, 0);
              }
	    
              push (@{$stats{$stat->{filter_type}}}, $stat->{count});
	    
          }                     # while
	
          # Adjust arrays to maximum size
          foreach $filter_type (keys %stats) {
              $size = @{$stats{$filter_type}};
              while ($size <= 30 ) {
                  push(@{$stats{$filter_type}}, 0);
                  $size = $size + 1;
              }
          }
      } else {
          $message = 'Select-statement error: '.$DBI::errstr.' ('.$DBI::err.')';
          warn logPrefix, "Spamity::Web getGraphByUserAndMonth $message\n";
      }
      $sth->finish();
    
      # Format days
      for ($count = 0; $count <= $#days; $count++) {
          $days[$count] =~ s/\d{4}-\d{2}-(\d{2})/$1/;
      }
    
      if (keys(%stats) > 0) {    
          @filters_unsorted = (keys %stats);
          @filters = sort byfilter @filters_unsorted;
          foreach $filter_type (@filters) {
              push(@stats, [@{$stats{$filter_type}}]);
          }
          $graph->set_legend(@filters);
      } else {
          @filters = @FILTERS;
          @stats = [0];
      }
    
      my @data = (\@days, @stats);
    
      $graph->set(
                  x_label          => '',
                  x_label_position => 0.5,
                  y_label          => &translate('number of messages'),
                  y_label_position => 0.5,
                  y_min_value      => 0,
                  y_label_skip     => ((keys(%stats) > 0)?1:10),
                  dclrs            => &colorsForFilters(\@filters),
                  accentclr        => 'gray',
                  textclr          => 'black',
                  labelclr         => 'black',
                  axislabelclr     => 'black',
                  valuesclr        => 'black',
                  fgclr            => 'lgray',
                  cumulate         => 1,
                  bar_spacing      => 2
                 ) or warn logPrefix, $graph->error;
    
      $image = $graph->plot(\@data)->png or warn logPrefix, $graph->error;
      &cache($sid, $cid, $cexp, $image);
    
      return $image;

  }                             # getGraphByUserAndMonth


1;

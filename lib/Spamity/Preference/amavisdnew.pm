#!/usr/bin/perl
# -*- Mode: CPerl; tab-width: 4; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4; cperl-indent-level: 4 -*-
#
#  Copyright (c) 2004-2010
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

package Spamity::Preference::amavisdnew;

=head1 NAME

Spamity::Preference::amavisdnew - Spamity support for AMaViSd-new SQL-based policies.

=head1 DESCRIPTION
    
This Perl module allows from the web interface of Spamity to display and modify
the user's policies of her/his address(es) for AMaViSd-new.

=head1 USAGE

The following parameters must be defined in Spamity configuration file:

=over 4

=item * amavisd-new_database

Database source definition where the AMaViSd-new tables are defined.

=item * amavisd-new_table_users

The name of the users table.

=item * amavisd-new_table_policy

The name of the policies table.

=item * amavisd-new_table_mailaddr

The name of the mail addresses table.

=item * amavisd-new_table_wblist

The name of the white/black lists table.

=item * amavisd-new_spam_tag_level

Default spam tag level, as configured in AMaViSd-new.

=item * amavisd-new_spam_tag2_level

Default spam tag2 level, as configured in AMaViSd-new.

=item * amavisd-new_spam_kill_level

Default spam kill level, as configured in AMaViSd-new.

=item * amavisd-new_spam_dsn_cutoff_level

CURRENTLY IGNORE; NOT IMPLEMENTED YET

Default spam dsn cutoff level, as configured in AMaViSd-new.

=back

=head1 EXAMPLE

  amavisd-new_database = pgsql:localdb
  amavisd-new_table_users = users
  amavisd-new_table_policy = policy
  amavisd-new_table_mailaddr = mailaddr
  amavisd-new_table_wblist = wblist
  amavisd-new_spam_tag_level = 3.0
  amavisd-new_spam_tag2_level = 6.3
  amavisd-new_spam_kill_level = 6.3
  amavisd-new_spam_dsn_cutoff_level = 10

=cut

use Spamity qw(conf logPrefix);
use Spamity::Database;


BEGIN {
    use Exporter;
    @Spamity::Preference::amavisdnew::ISA = qw(Exporter);
    @Spamity::Preference::amavisdnew::EXPORT = qw();
    @Spamity::Preference::amavisdnew::EXPORT_OK = qw($message getPolicyColumns getPolicies getPolicy setPolicy getBlacklist setBlacklist getWhitelist setWhitelist);
}
use vars qw($message %COLUMNS);

$message = undef;

# All AMaViSd columns names with their data types
# Those names also appear in templates/prefs.html and the localizations files.
# Note: your database policy table doesn't have to defined all columns.
%COLUMNS = ('virus_lover'               => 'BOOL',
            'spam_lover'                => 'BOOL',
            'banned_files_lover'        => 'BOOL',
            'bad_header_lover'          => 'BOOL',
            'bypass_virus_checks'       => 'BOOL',
            'bypass_spam_checks'        => 'BOOL',
            'bypass_banned_checks'      => 'BOOL',
            'bypass_header_checks'      => 'BOOL',
            'spam_modifies_subj'        => 'BOOL',
            'virus_quarantine_to'       => 'VCHAR',
            'spam_quarantine_to'        => 'VCHAR',
            'banned_quarantine_to'      => 'VCHAR',
            'bad_header_quarantine_to'  => 'VCHAR',
            'spam_tag_level'            => 'DEC',
            'spam_tag2_level'           => 'DEC',
            'spam_kill_level'           => 'DEC',
            'spam_dsn_cutoff_level'     => 'DEC',
            'addr_extension_virus'      => 'VCHAR',
            'addr_extension_spam'       => 'VCHAR',
            'addr_extension_banned'     => 'VCHAR',
            'addr_extension_bad_header' => 'VCHAR',
            'spam_subject_tag'          => 'VCHAR',
            'spam_subject_tag2'         => 'VCHAR');

eval('require \'Spamity/Preference/amavisdnew/'.Spamity::Database->new(database => 'amavisd-new')->{_module}.'.pm\'');
warn logPrefix,$@ if $@;

sub _getList
  {
      my $chars;
      my $user_id;
 
      my $db;
      my $stmt;
      my $sth;
      my $row;
      my %addresses;
    
      ($chars, $user_id) = @_;
    
      $db = Spamity::Database->new(database => 'amavisd-new');

      if ($db && int($user_id)) {
          $stmt = sprintf('select m.id, m.email from %s as m, %s as l where l.rid = ? and l.sid = m.id and l.wb in (%s)',
                          &conf('amavisd-new_table_mailaddr'), &conf('amavisd-new_table_wblist'),
                          join(',',@$chars));

          warn "[DEBUG SQL] Spamity::Preference::amavisdnew _getList($user_id) $stmt\n" if (int(&conf('log_level')) > 0);
	
          $sth = $db->dbh->prepare($stmt);
          if ($sth->execute($user_id)) {
              while ($row = $sth->fetchrow_arrayref) {
                  $addresses{lc($$row[1])} = $$row[0];
              }
          } else {
              $message = 'Select-statement error: '.$DBI::errstr;
              warn logPrefix, "Spamity::Preference::amavisdnew _getList $message\n";
          }
      }

      return \%addresses;
  }                             # _getList


sub getBlacklist 
  {
      my $user_id;
      my @chars = qw('B' 'N');
      my $hashref;
      my @addresses;

      ($user_id) = @_;

      $hashref = &_getList(\@chars, $user_id);
      @addresses = sort(keys(%$hashref));

      return \@addresses;
  }                             # getBlacklist


sub getPolicies
  {
      my $db;
      my $stmt;
      my $sth;
      my $row;
      my %policies;
    
      if ($db = Spamity::Database->new(database => 'amavisd-new')) {
          $stmt = sprintf("select id, policy_name from %s where policy_name != 'NULL' order by policy_name", &conf('amavisd-new_table_policy'));

          warn "[DEBUG SQL] Spamity::Preference::amavisdnew getPolicies $stmt\n" if (int(&conf('log_level')) > 0);

          $sth = $db->dbh->prepare($stmt);
          if ($sth->execute()) {
              while ($row = $sth->fetchrow_arrayref) {
                  $policies{$$row[0]} = $$row[1];
              }
          } else {
              $message = 'Select-statement error: '.$DBI::errstr;
              warn logPrefix,"Spamity::Preference::amavisdnew getPolicies $message\n";
          }
      }

      return \%policies;
  }                             # getPoliicies


sub getPolicy
  {
      my $email;
      my $id;

      my $db;
      my $policy;
      my $stmt;
      my $sth;
      my @vars;

      ($email, $id) = @_;
      $email = lc($email);

      if ($db = Spamity::Database->new(database => 'amavisd-new')) {
          if (defined $id) {
              # Select policy; user may not exist
              $stmt = sprintf("select id as policy_id, p.* from %s as p where id = ? and policy_name != 'NULL'",
                              &conf('amavisd-new_table_policy'));
              @vars = ($id);
          } else {
              # The user's policy can be dummy (ID = 0)
              $stmt = sprintf('select u.id as user_id, u.policy_id, p.* from %s as u left join %s as p on u.policy_id = p.id where lower(u.email) = ?',
                              &conf('amavisd-new_table_users'), &conf('amavisd-new_table_policy'));
              @vars = ($email);
          }

          warn "[DEBUG SQL] Spamity::Preference::amavisdnew getPolicy(",join(", ", @vars),") $stmt\n" if (int(&conf('log_level')) > 0);

          $sth = $db->dbh->prepare($stmt);
          if ($sth->execute(@vars)) {
              $policy = $sth->fetchrow_hashref(NAME_lc);
              if (defined $policy) {
                  $policy->{id} = $policy->{policy_id};
                  unless ($policy->{id} == 0) {
                      # Format boolean data types
                      while (my ($key, $value) = each(%COLUMNS)) {
                          next if ($value ne 'BOOL');
                          if (exists($policy->{$key})) {
                              if ($policy->{$key} eq 'Y') {
                                  $policy->{$key} = 1;
                              } else {
                                  $policy->{$key} = undef;
                              }
                          }
                      }
                      $policy->{id} = 'CUSTOM' if (not defined $policy->{policy_name});
                  }
              }
              if (defined $email) {
                  # Retrieve user id, if it exists
                  $stmt = sprintf('select id from %s where lower(email) = ?', &conf('amavisd-new_table_users'));
		
                  warn "[DEBUG SQL] Spamity::Preference::amavisdnew getPolicy($email) $stmt\n" if (int(&conf('log_level')) > 0);
		
                  $sth = $db->dbh->prepare($stmt);
                  if ($sth->execute($email)) {
                      if (my $row = $sth->fetchrow_arrayref) {
                          $policy->{user_id} = $$row[0];
                      }
                  }
              }
          } else {
              $message = 'Select-statement error: '.$DBI::errstr;
              warn logPrefix, "Spamity::Preference::amavisdnew getPolicy $message\n";
          }
      }
    
      return $policy;
  }                             # getPolicy


sub getWhitelist
  {
      my $user_id;
      my @chars = qw('W' 'Y');
      my $hashref;
      my @addresses;
    
      ($user_id) = @_;

      $hashref = &_getList(\@chars, $user_id);
      @addresses = sort(keys(%$hashref));

      return \@addresses;
  }                             # getWhitelist


sub setPolicy
  {
      my $email;
      my $defined_columns;
      my $query;

      my $db;
      my @columns = ();
      my @values = ();
      my $stmt;
      my $sth;
      my $policy_id = 0;
      my $user_id = undef;
      my $previous_policy_id = undef;
      my $was_custom = 0;

      ($email, $defined_columns, $query) = @_;
      $email = lc($email);

      if ($db = Spamity::Database->new(database => 'amavisd-new')) {

          # Retrieve user id and previous policy id (can be a dummy policy ie ID = 0)
          $stmt = sprintf("select u.policy_id, u.id as user_id, p.policy_name from %s as u left join %s as p on p.id = u.policy_id where lower(u.email) = ?",
                          &conf('amavisd-new_table_users'), &conf('amavisd-new_table_policy'));
	
          warn "[DEBUG SQL] Spamity::Preference::amavisdnew setPolicy($email) $stmt\n" if (int(&conf('log_level')) > 0);
	
          $sth = $db->dbh->prepare($stmt);
          if ($sth->execute($email)) {
              if (my $row = $sth->fetchrow_arrayref) {
                  $previous_policy_id = $$row[0];
                  $user_id = $$row[1];
                  $was_custom = (!defined($$row[2]) && $previous_policy_id > 0);
              }
          } else {
              $message = 'Select-statement error: '.$DBI::errstr;
              warn logPrefix, "Spamity::Preference::amavisdnew setPolicy($email) $message\n";
              return 0;
          }
	
          if ($query->param('policy') eq 'DEFAULT') {
              # No policy
              if (defined $user_id) {
                  my $wl = $query->param('wl'); $wl =~ s/\s//g;
                  my $bl = $query->param('bl'); $bl =~ s/\s//g;
		
                  if ($was_custom) {
                      # Delete previous custom policy
                      $stmt = sprintf('delete from %s where id = ?',
                                      &conf('amavisd-new_table_policy'));
		    
                      warn "[DEBUG SQL] Spamity::Preference::amavisdnew setPolicy($previous_policy_id) $stmt\n" if (int(&conf('log_level')) > 0);
		    
                      $sth = $db->dbh->prepare($stmt);
                      if (!$sth->execute($previous_policy_id)) {
                          $message = 'Delete-statement error: '.$DBI::errstr;
                          warn logPrefix, "Spamity::Preference::amavisdnew setPolicy($previous_policy_id) $message\n";
                          return 0;
                      }
                  }

                  if ($wl || $bl) {
                      # Use the dummy policy (ID = 0)
                      $policy_id = 0;
                  } else {
                      # Delete the user's profile only if there's no WB list
                      $stmt = sprintf('delete from %s where id = ?',
                                      &conf('amavisd-new_table_users'));
		    
                      warn "[DEBUG SQL] Spamity::Preference::amavisdnew setPolicy($user_id) $stmt\n" if (int(&conf('log_level')) > 0);
		    
                      $sth = $db->dbh->prepare($stmt);
                      if (!$sth->execute($user_id)) {
                          $message = 'Delete-statement error: '.$DBI::errstr;
                          warn logPrefix, "Spamity::Preference::amavisdnew setPolicy($user_id) $message\n";
                          return 0;
                      }
                      # Delete WB lists
                      &setBlacklist($user_id);
                      &setWhitelist($user_id);
		    
                      return 1;
                  }
              }
          } elsif ($query->param('policy') eq 'CUSTOM') {
              # New policy is custom
              foreach my $column (@$defined_columns) {
                  push(@columns, $column);
		
                  if ($COLUMNS{$column} eq 'BOOL') {
                      if ($query->param($column) =~ m/Y$/) {
                          push(@values, 'Y');
                      } else {
                          push(@values, 'N');
                      }
                  } elsif ($COLUMNS{$column} eq 'DEC') {
                      if (!defined($query->param($column))) {
                          push(@values, &conf("amavisd-new_$column"));
                      } else {
                          push(@values, $query->param($column));
                      }
                  } else {
                      push(@values, (defined $query->param($column))?$query->param($column):'');
                  }
              }
	    
              if ($was_custom) {
                  # Update custom policy
                  foreach my $column (@columns) {
                      $column .= ' = ?';
                  }
                  $stmt = sprintf('update %s set %s where id = ?',
                                  &conf('amavisd-new_table_policy'), join(', ', @columns));

                  warn "[DEBUG SQL] Spamity::Preference::amavisdnew setPolicy(", join(', ', @values), ", $previous_policy_id) $stmt\n" if (int(&conf('log_level')) > 0);

                  $sth = $db->dbh->prepare($stmt);
                  push(@values, $previous_policy_id);
                  for (my $i = 0; $i < @values; $i++) {
                      $sth->bind_param($i+1, $values[$i]);
                  }
                  if (!$sth->execute()) {
                      $message = 'Update-statement error: '.$DBI::errstr;
                      warn logPrefix, "Spamity::Preference::amavisdnew setPolicy $message\n";
                      return 0;
                  }
                  $policy_id = $previous_policy_id;
              } else {
                  # New custom policy
                  $policy_id = &insertPolicy(\@columns, \@values);
                  if (!$policy_id) {
                      $message = 'Error inserting policy (no id)';
                      warn logPrefix, "Spamity::Preference::amavisdnew setPolicy $message";
                      return 0;
                  }
              }
          } else {
              # New policy is static
              if ($was_custom) {
                  # Delete previous custom policy
                  $stmt = sprintf('delete from %s where id = ?',
                                  &conf('amavisd-new_table_policy'));

                  warn "[DEBUG SQL] Spamity::Preference::amavisdnew setPolicy($previous_policy_id) $stmt\n" if (int(&conf('log_level')) > 0);

                  $sth = $db->dbh->prepare($stmt);
                  if (!$sth->execute($previous_policy_id)) {
                      $message = 'Delete-statement error: '.$DBI::errstr;
                      warn logPrefix, "Spamity::Preference::amavisdnew setPolicy($previous_policy_id) $message\n";
                      return 0;
                  }
              }
              $policy_id = sprintf('%i', $query->param('policy'));
          }
	
          if (defined $user_id) {
              # Update user's profile
              $stmt = sprintf('update %s set policy_id = ? where id = ?',
                              &conf('amavisd-new_table_users'));

              warn "[DEBUG SQL] Spamity::Preference::amavisdnew setPolicy($policy_id, $user_id) $stmt\n" if (int(&conf('log_level')) > 0);

              $sth = $db->dbh->prepare($stmt);
              if (!$sth->execute($policy_id, $user_id)) {
                  $message = 'Update-statement error: '.$DBI::errstr;
                  warn logPrefix, "Spamity::Preference::amavisdnew setPolicy $message\n";
                  return 0;
              }
          } else {
              # Create user's profile
              $stmt = sprintf('insert into %s (email, policy_id) values (?, ?)',
                              &conf('amavisd-new_table_users'));

              warn "[DEBUG SQL] Spamity::Preference::amavisdnew setPolicy($email, $policy_id) $stmt\n" if (int(&conf('log_level')) > 0);

              $sth = $db->dbh->prepare($stmt);
              if (!$sth->execute($email, $policy_id)) {
                  $message = 'Insert-statement error: '.$DBI::errstr;
                  warn logPrefix, "Spamity::Preference::amavisdnew setPolicy $message\n";
                  return 0;
              }
          }
    
          return 1;
      }
    
      return 0;
  }                             # setPolicy


sub setBlacklist
  {
      my $user_id;
      my $addresses;
      my @chars = qw('B' 'N');

      ($user_id, $addresses) = @_;

      return &_setList($user_id, \@chars, $addresses);
  }                             # setBlacklist


sub setWhitelist
  {
      my $user_id;
      my @chars = qw('W' 'Y');
      my $addresses;
    
      ($user_id, $addresses) = @_;
    
      return &_setList($user_id, \@chars, $addresses);
  }                             # setWhitelist


1;

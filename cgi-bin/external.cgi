#!/usr/bin/env perl
# -*- Mode: CPerl tab-width: 4; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4; cperl-indent-level: 4 -*-
#
#  Copyright (c) 2010
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

use Spamity qw(conf logPrefix);
use Spamity::Web;
use Spamity::Lookup qw(getAddressesByUser);
use Spamity::Quarantine;
use Spamity::i18n qw(setLanguage translate);
use Spamity::Preference::amavisdnew qw(getPolicy getBlacklist setBlacklist getWhitelist setWhitelist);

use Crypt::CBC;
use Crypt::Blowfish;
use MIME::Base64;
use Encode qw(encode);

# Variables
my $tt;
my $query;
my $vars;
my $cipher;
my $session_config;
my $session;
my $db;
my $script;
my $request;

# Prepare template
$query = new CGI;
$tt = &Spamity::Web::getTemplate();

# Retrieve parameters from HTTP post and action from URL
$vars = &Spamity::Web::getParameters($query);

# Prepare cipher
$cipher = new Crypt::CBC(&conf('encryption_secret_key'), 'Blowfish');

# Verify session
$session_config = &Spamity::Web::sessionConfig();
unless ($session_config->{error}) {
    $vars->{sid} = $query->cookie("CGISESSID") || undef;
    if (defined $vars->{sid}) {
        $session = new CGI::Session($Spamity::Web::SESSION_DRIVER, $vars->{sid}, $session_config);
        if ($vars->{authenticated} = (defined $session->param('username') && defined $session->param('addresses'))) {
            $vars->{prefs} = defined(&conf('amavisd-new_database', 1)) && ($session->param('addresses') || $session->param('admin'));
        }
    }
}

# Establish database connection for Spamity preferences
unless ($db = Spamity::Database->new(database => 'spamity_prefs')) {
    $vars->{error} = $Spamity::Database::message;
    print $query->header(-charset=>'UTF-8');
    $tt->process('login.html', $vars) || warn logPrefix,'external.cgi: ', $tt->error();
    exit;
}

# Parse URL
$script = $query->url(-relative=>1);
if ($query->url(-relative=>1, -path=>1) =~ m/$script\/+(.+)\/?$/) {
    $request = $1;

    # Request form:
    # <username>|<action>|<parameter1>|<parameter2>|...

    # Possible actions:
    # - view
    # - reinject
    # - whitelist
    # - blacklist

    eval {
        $request = $cipher->decrypt(decode_base64($request));
        warn logPrefix, "Decoded request: $request\n";
    };
    if ($@) {
        warn logPrefix, "Can't decrypt action \"$action\": $@\n";
        $vars->{error} = 'Invalid action.';
        $vars->{action} = undef;
    } else {
        my ($username, $action, @parameters) = split('\|', $request);
        #warn "parameters = ",join("|", @parameters),"\n";

        # Debugging purposes
        $vars->{username} = $username;
        $vars->{parameters} = \@parameters;

        $vars->{action} = $action;
        if (grep(/^$action$/, @Spamity::Web::ACTIONS) && defined &$action) {
            # Retrieve the user's preferred language
            my $stmt = "SELECT lang FROM spamity_prefs WHERE username = '$username'";
            my $sth = $db->dbh->prepare($stmt);
            if ($sth->execute()) {
                if (my $row = $sth->fetchrow_hashref()) {
                    $vars->{lang} = $row->{lang};
                    &setLanguage($vars->{lang});
                    
                    # Call function associated to action 
                    eval("&$action(\@parameters)");
                    if ($@) {
                        $vars->{error} = $@;
                    }
                }
                $sth->finish();
            }
        } else {
            $vars->{action} = undef;
            $vars->{error} = &translate("Unknown action.");
            warn "Unknown action \"$action\"\n";
        }
    }
} else {
    print $query->redirect(-uri=>$vars->{url}.'login.cgi');
    exit;
}

# Output html
if (defined $session) {
    print $session->header(charset=>'UTF-8');
} else {
    print $query->header(-charset=>'UTF-8');
}
$tt->process('external.html', $vars) || warn logPrefix,'external.cgi: ',$tt->error();


sub view
  {
      # <parameters>
      #   message id
      # <returns>
      #   1 on success

      my ($id) = @_;

      $vars->{action_title} = 'view a rejected message';

      die &translate("Missing parameter.") unless $id;

      $vars->{message_id} = $id;
      $vars->{allow_reinjection} = 1 if (defined &conf('reinjection_smtp_server', 1));
    
      # Test connection to database
      unless (Spamity::Database->new(database => 'spamity')) {
          die $Spamity::Database::message;
      }

      my ($mail_from, $rcpt_to, $mailObj, $virus_id) = &Spamity::Quarantine::getRawSource($id, $vars->{username});
      unless (defined ($mailObj)) {
          die &translate("The message is no longer available.");
      }

      if (defined $virus_id && defined &conf('allow_virus_reinjection')) {
          # Verify if virus reinjection has been desactivate
          $vars->{allow_reinjection} = 0 unless (\&conf('allow_virus_reinjection') =~ m/true/i);
      }

      my $body_arrayref = $mailObj->body();
      my $body = &CGI::escapeHTML(join("\n", @{$body_arrayref}));
      $vars->{body} = $body;

      # Format headers
      my $header_arrayref = $mailObj->head->header();
      my %headers = ();
      my @keys = ();
      foreach (@{$header_arrayref}) {
          chomp;
          if ($_ =~ m/^(\S+):\s+(.+)$/s) {
              $headers{$1} =  &CGI::escapeHTML($2);
              push(@keys, $1);
          }
      }
    
      # Set template variables
      $vars->{virus} = $virus_id if (defined $virus_id);
      $vars->{headers} = \%headers;
      $vars->{keys} = \@keys;
      $vars->{strip} = \&Spamity::Web::strip;

      if ($vars->{allow_reinjection}) {
          # Build action string for reinjection
          $vars->{reinjection_action} = encode_base64($cipher->encrypt($vars->{username}."|reinject|".$id.((defined $virus_id)?'|1':'')));
          $vars->{reinjection_action} =~ s/\n//g;
      }
    
      return 1;
  }

sub reinject
  {
      # <parameters>
      #   message id
      #   boolean (true if confirmation is required)
      # <returns>
      #   1 on success

      my ($id, $confirmation_required) = @_;

      $vars->{action_title} = 'receive a rejected message';

      die &translate("Missing parameter.\n") unless $id;

      $vars->{message_id} = $id;
      $vars->{allow_reinjection} = 1 if (defined &conf('reinjection_smtp_server', 1));
    
      # Test connection to database
      unless (Spamity::Database->new(database => 'spamity')) {
          die $Spamity::Database::message;
      }

      my ($mail_from, $rcpt_to, $mailObj, $virus_id) = &Spamity::Quarantine::getRawSource($id, $vars->{username});
      unless (defined ($mailObj)) {
          die &translate("The message is no longer available.");
      }

      if ($confirmation_required) {
          $vars->{confirmation} = &translate('You are about to reinject a virus to your account. Do you want to continue?');
	
          # Build action string for reinjection
          $vars->{reinjection_action} = encode_base64($cipher->encrypt($vars->{username}."|reinject|".$id));
          $vars->{reinjection_action} =~ s/\n//g;
      } elsif ($vars->{allow_reinjection}) {
          if (&Spamity::Quarantine::sendMail($mail_from, $rcpt_to, $mailObj)) {
              # Message was successfully reinjected
              # "From" address is extracted from the headers; it might be quoted with <>
              $mail_from =~ s/^<(.+)>$/$1/; $vars->{mail_from} = $mail_from;
              $vars->{rcpt_to} = $rcpt_to;
          } else {
              die &translate('Reinjecting currently not possible.');
          }
      }

      return 1;
  }


sub whitelist
  {
      # <parameters>
      #   recipient address
      #   sender address (optional if submitted through a form)
      # <returns>
      #   1 on success

      return &_addList('White', @_);
  }


sub blacklist
  {
      # <parameters>
      #   recipient address
      #   sender address (optional if submitted through a form)
      # <returns>
      #   1 on success

      return &_addList('Black', @_);
  }


sub _addList
  {
      my $db;
      my $list = [];
      my $rsub;
    
      my ($type, $recipient_addr, $sender_addr) = @_;
    
      $vars->{action_title} = lc($type) . 'list';

      die &translate("Missing parameter.\n") unless ($recipient_addr);

      # Find the user's email addresses and make sure it contains the
      # recipient address
      my @addresses = &getAddressesByUser(undef, $vars->{username});
      unless (grep (/^$recipient_addr$/, @addresses)) {
          die sprintf(&translate("The recipient address %s is not associated to your account."), '<b>'.$recipient_addr.'</b>'),"\n";
      }

      # Test connection to database
      unless ($db = Spamity::Database->new(database => 'amavisd-new')) {
          die $Spamity::Database::message,"\n";
      }
        
      # Build the domain & user
      my @choices = ($sender_addr || $query->param('address'));
      if ($sender_addr =~ m/^(.+)(\@.+)$/) {
          push(@choices, lc($2), lc($1));
      }

      # Verify if the user has a policy
      my $policy = &getPolicy($recipient_addr);

      if (defined $policy) {
          # Retrieve list
          $rsub = 'get'.$type.'list';
          $list = &$rsub($policy->{user_id});
	
          # Verify if the address/domain is already whitelisted
          foreach my $entry (@{$list}) {
              foreach (@choices) {
                  if (m/^$entry$/) {
                      if (m/^\@/) {
                          die sprintf(&translate('The domain %s is already '.lc($type).'listed.'), '<b>'.$_.'</b>')."\n";
                      } elsif (m/\@/) {
                          die sprintf(&translate('The address %s is already '.lc($type).'listed.'), '<b>'.$_.'</b>')."\n";
                      }
                  }
              }
          }
      }
    
      if (my $address = $query->param('address')) {
          # White/blacklist the argument

          if (not defined ($policy)) {
              # Create user profile with dummy policy
              my $stmt = sprintf('insert into %s (email, policy_id) values (?, ?)',
                                 &conf('amavisd-new_table_users'));
            
              warn "[DEBUG SQL] external.cgi $stmt\n" if (int(&conf('log_level')) > 0);
            
              my $sth = $db->dbh->prepare($stmt);
              if (!$sth->execute($recipient_addr, 0)) {
                  warn logPrefix, 'external.cgi Insert-statement error: '.$DBI::errstr;
                  die 'Insert-statement error: '.$DBI::errstr."\n";
              }
              $policy = &getPolicy($recipient_addr);
              die "Insert-statement error: the user profile wasn't created.\n" unless (defined $policy);
          }
        
          push(@{$list}, $address);
          $rsub = 'set'.$type.'list';
          &$rsub($policy->{user_id}, $list);
          $vars->{sender_addr} = $address;
      } else {
          $vars->{options} = \@choices;
          # Build action string for white/blacklisting
          $vars->{action_url} = encode_base64($cipher->encrypt($vars->{username}."|".lc($type)."list|".$recipient_addr));
          $vars->{action_url} =~ s/\n//g;
      }
      $vars->{recipient_addr} = $recipient_addr;
    
      return 1;
  }

1;

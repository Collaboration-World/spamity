#!/usr/bin/perl
#
#  Spamity/i18n.pm
#
#  Copyright (c) 2004
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
# default_language: Default language for the web interface.
#   Example:
#   default_language = fr_CA
#

package Spamity::i18n;

BEGIN {
    use Exporter;
    use Locale::Maketext;
    use POSIX qw(locale_h);
    @Spamity::i18n::ISA = qw(Exporter Locale::Maketext);
    @Spamity::i18n::Lexicon = (_AUTO => 1);
    @Spamity::i18n::EXPORT_OK = qw(setLanguage translate);
}

my $LH;


sub language_name 
{
    my $tag = $_[0]->language_tag;
    require I18N::LangTags::List;
    I18N::LangTags::List::name($tag);
}


sub encoding
{
  'utf-8';
}

    
sub setLanguage
{    
    $LH = Spamity::i18n->get_handle($_[0]);
    &POSIX::setlocale(&POSIX::LC_ALL, $_[0]);
}

sub translate
{
    return $LH->maketext($_[0]);
}


1;

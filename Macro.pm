# $Source: /usr/cvsroot/ConveyPerl/lib/Macro.pm,v $
# $Id: Macro.pm,v 1.2 2002/02/14 16:42:15 marco Exp $
#
# Copyright (c) 2002, Edward Marco Baringer. All Rights Reserved.
# This module is free software. It may be used, redistributed
# and/or modified under the terms of the Perl Artistic License
# (see http://www.perl.com/perl/misc/Artistic.html)
package Macro;

require 5.005_62;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = ( );
our $VERSION = '0.2';

use Filter::Simple;
use Text::Balanced qw ( extract_codeblock );
use Parse::RecDescent;

$::RD_HINT = 1;
#$::RD_TRACE = 1;

sub build_macro_grammar {
    my $template = Filter::Simple::show(shift);
    my $generator = Filter::Simple::show(shift);
    my $prefix = "__MACRO_HELPER_RULE";
    $template =~ s/^\s*{//;
    $template =~ s/\}\s*$//;
    $template =~ s/^\s*//;
    $template =~ s/\s*$//;
    # we want to allow regexp like repeat specifiers *, +, ?, {n,m},
    # but Parse::RecDescent wants a different format, (s?), (s), (?)
    # and (n..m) repesctivley
    $template =~ s/\)\s*\+/)(s)/g;
    $template =~ s/\)\s*\*/)(s\?)/g;
    $template =~ s/\)\s*\?/)(?)/g;
    $template =~ s/\)\s*{\s*(\d+)\s*,\s*(\d+)\s*}/)($1..$2)/g;
    my $name = gensym();
    return
      { name => $name,
        grammar =>
        # ok, this is what the user specified
        $name . ' : ' . $template . ' { &{ sub ' . $generator . '}(do { shift @item; @item}) }' . "\n\n"
      };
}

sub extract_macro {
    my $coderef = shift();
    my $code = ${$coderef};
    my $grammar = undef;
    # now we go and search for the _first_ macro template
    if ($code =~ /^(macro\s*)/g) {
        my $start = pos($code) - length($1);
        my $code_pre = substr($code, 0, $start);
        # we have already consumed all the white space, so if this is
        # followed by a {} pair
        my $code_chunk = substr($code, pos($code));
        my ($template, $remainder) = extract_codeblock($code_chunk, '{}', '');
        if (defined $template) {
            # ok, now just check and see if we have another block
            # (this time the optional white space is ok not, the
            # remainder refered to here is what was returned by the
            # previous call to extract_codeblock
            my ($generator, $remainder) = extract_codeblock($remainder, '{}');
            if (defined $generator) {
                # ok, we've got a macro
                $grammar = build_macro_grammar($template, $generator);
                # remove this from $code
                $code = $code_pre . $remainder;
            }
        }
    }
    $$coderef = $code;
    return $grammar;
}

FILTER_ONLY
  code => sub {
      my $code = $_;
      my (undef, @macro_files) = @_;
      my @macros;
      foreach my $ext_macro (@macro_files) {
          open MACRO_FILE, "<$ext_macro" or die "Can't open $ext_macro: $!\n";
          local $/ = undef;
          # quick note, since this $code is in this block the "other"
          # $code will be ok
          my $code = <MACRO_FILE>;
          close MACRO_FILE;
          my $seen_code = "";
          while ($code ne '') {
              if (my $new_macro_grammar = extract_macro(\$code)) {
                  push @macros, $new_macro_grammar;
              }
              $seen_code = substr($code, 0, 1);
              $code = substr($code, 1);
          }
      }
      my $macro_parser;
      # we go through the code expanding and defining new macros. this
      # used to be two distinct steps, but if we want macros which
      # define macros we need to do these together
      my $seen_code = "";
      # this first pass will get all the macros explicitly written in
      # the source code, if there are macro defining macros we'll get
      # them later and it will slow things down a bit, oh well.
      while ($code ne '') {
          if (my $new_macro_grammar = extract_macro(\$code)) {
              push @macros, $new_macro_grammar;
          }
          $seen_code .= substr($code, 0, 1);
          $code = substr($code, 1);
      }
      $code = $seen_code;
      my $standard_grammar_rules =
        # and these are all the 'standard' rules (notice how we're
        # assholes and don't let the user define their own rules? ha ha ha
        'integer       : /[-+]?\d+/ { $return = $item[1]; }' . "\n\n" .
        'real          : /[-+]?\d+\.?\d*/ { $return = $item[1]; }' . "\n\n" .
        'function_name : /[A-Za-z_][A-Za-z0-9_]*/ { $return = $item[1]; }' . "\n\n" .
        'arg_list      : <rulevar: $seperator   = quotemeta($arg[0] || ","           )> ' . "\n\n" .
        'arg_list      : <rulevar: $open_delim  = quotemeta($arg[1] || "("           )> ' . "\n\n" .
        'arg_list      : <rulevar: $close_delim = quotemeta($arg[2] || $arg[1] || ")")> ' . "\n\n" .
        'arg_list      : { $thisparser->{"local"}{"seperator"} = $seperator;' . "\n" .
        '                  $thisparser->{"local"}{"close_delim"} = $close_delim; } ' . "\n" .
        '                /$open_delim/ __MACRO_INNER_arg_list_element(s? /$seperator/) /$close_delim/ ' .
        '                { $return = $item[3]; }' . "\n\n" .
        '__MACRO_INNER_arg_list_element : <rulevar: $seperator = $thisparser->{"local"}{"seperator"}> ' . "\n\n" .
        '__MACRO_INNER_arg_list_element : <rulevar: $close_delim = $thisparser->{"local"}{"close_delim"}> ' . "\n\n" .
        '__MACRO_INNER_arg_list_element : <perl_quotelike>' . "\n" .
        '                                 { $return = join "", map { $_ || "" } @{ $item[1] } } |' . "\n" .
        '                                 /' . $Filter::Simple::placeholder . '/' . "\n" .
        '                                 { $return = Filter::Simple::show($item[1]) } |' . "\n" .
        '                                 /(\\\\(\\s|$seperator|$close_delim)|.*?(?=$seperator|\\s|$close_delim))+/ ' . "\n" .
        '                                 { $item[1] =~ s/\\\\(\\s|$seperator|$close_delim)/$1/g; $return = $item[1]; }' . "\n\n";
      my $all_grammar = "macro : " . join(" | ", map { $_->{name} } @macros) . "\n\n" .
                        join("\n\n", map { $_->{grammar} } @macros) . "\n\n" .
                        $standard_grammar_rules;
      @macros = (Parse::RecDescent->new($all_grammar));
      $seen_code = "";
      while ($code ne '') {
          foreach my $macro (@macros) {
              if (defined ($macro->macro($code))) {
                  # ok, we have a match. in order to get around a weird
                  # maybe bug in Parse::RecDescent we need to redo it
                  my $expansion = $macro->macro(\$code);
                  $code = $expansion . $code;
              }
          }
          while (my $new_macro_grammar = extract_macro(\$code)) {
              my $grammar = $new_macro_grammar->{grammar};
              my $name = $new_macro_grammar->{name};
              $grammar =~ s/^\s*$name/macro/;
              push @macros, Parse::RecDescent->new($new_macro_grammar->{grammar} . $standard_grammar_rules);
          }
          $code =~ s/^(\s+|.)//;
          $seen_code .= $1;
      }
      $code = $seen_code;
      $_ = $code;
  };

{
    my $gen_sym_counter = 0;

    sub gensym {
        my $sym = shift || "G";
        return $sym . sprintf("%010d", $gen_sym_counter++);
    }
}

1;
__END__;

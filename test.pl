# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..6\n"; }
END {print "not ok 1\n" unless $loaded;}
use Macro;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# simple test helpers

sub do_test {
    my ($number, $desc, $code) = @_;
    print "$desc\n";
    unless ($code->()) {
        print "not ";
    }
    print "ok $number\n";
}

macro
  { 'TRUE' }
  { "1" }

do_test 2, "constant macro (part I)", sub { TRUE };

macro
  { 'FALSE' }
  { "0" }

do_test 3, "constant macro (part II)",
  sub { ! FALSE };

macro
  { 'aif' <perl_codeblock:()>  }
  { "if (my \$it = $_[1])" };

sub foo {
    return 5;
}

do_test 4, "aif perl one",
  sub { aif (foo()) { $it == foo(); } };

macro
  { 'if' <perl_codeblock:()> 'then' }
  { "if $_[1]" };

do_test 5, "then/if (part I)",
  sub { if (1) then { return 1; } else { return 0; } };

macro { integer '..' integer }
      { my $ret;
        my ($start, $end) = @_[0,2];
        if ($start !~ /-?\d+/ || $end !~ /-?\d+/) {
            $ret = "$start .. $end";
        } else {
            my $skip = $start < $end ? 1 : -1;
            my @vals;
            for (my $i = $start; $i <= $end; $i += $skip) {
                push @vals, $i;
            }
            $ret = join ",", @vals;
        }
        return $ret;
    }

do_test 6, "compile time .. expansion",
  sub { 1 .. 4};

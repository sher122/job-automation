#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

require "$Bin/../automation.pl";

# ------------------------------------------------------------
# Test 1:
# Default success rate is 0.80.
# ------------------------------------------------------------

{
    local @ARGV = ();

    my $config = parse_cli();

    is(
        $config->{success_rate},
        0.80,
        "Default success rate is 0.80"
    );
}

# ------------------------------------------------------------
# Test 2:
# A normal custom value is accepted.
# ------------------------------------------------------------

{
    local @ARGV = (
        "--success-rate",
        "0.75"
    );

    my $config = parse_cli();

    is(
        $config->{success_rate},
        0.75,
        "Custom success rate is accepted"
    );
}

# ------------------------------------------------------------
# Test 3:
# Lower boundary 0.0 is valid.
# ------------------------------------------------------------

{
    local @ARGV = (
        "--success-rate",
        "0"
    );

    my $config = parse_cli();

    is(
        $config->{success_rate},
        0,
        "Success rate 0.0 is valid"
    );
}

# ------------------------------------------------------------
# Test 4:
# Upper boundary 1.0 is valid.
# ------------------------------------------------------------

{
    local @ARGV = (
        "--success-rate",
        "1"
    );

    my $config = parse_cli();

    is(
        $config->{success_rate},
        1,
        "Success rate 1.0 is valid"
    );
}

# ------------------------------------------------------------
# Test 5:
# Values greater than 1 are rejected.
# ------------------------------------------------------------

{
    local @ARGV = (
        "--success-rate",
        "5"
    );

    my $error;

    {
        local $@;

        eval {
            parse_cli();
            1;
        }
        or do {
            $error = $@;
        };
    }

    like(
        $error,
        qr/Invalid success rate/,
        "Success rate greater than 1 is rejected"
    );
}

# ------------------------------------------------------------
# Test 6:
# Negative values are rejected.
# ------------------------------------------------------------

{
    local @ARGV = (
        "--success-rate",
        "-1"
    );

    my $error;

    {
        local $@;

        eval {
            parse_cli();
            1;
        }
        or do {
            $error = $@;
        };
    }

    like(
        $error,
        qr/Invalid success rate/,
        "Negative success rate is rejected"
    );
}

# ------------------------------------------------------------
# Test 7:
# Non-numeric values are rejected.
# ------------------------------------------------------------

{
    local @ARGV = (
        "--success-rate",
        "abc"
    );

    my $error;

    {
        local $@;

        eval {
            parse_cli();
            1;
        }
        or do {
            $error = $@;
        };
    }

    like(
        $error,
        qr/Invalid success rate/,
        "Non-numeric success rate is rejected"
    );
}

# ------------------------------------------------------------
# Test 8:
# Public application interface returns exit code 2
# for an invalid success rate.
# ------------------------------------------------------------

{
    local @ARGV = (
        "--success-rate",
        "5"
    );

    my $stderr = "";
    my $exit_code;

    {
        local *STDERR;

        open(STDERR, ">", \$stderr)
            or die "Cannot capture STDERR: $!";

        $exit_code = main();
    }

    is(
        $exit_code,
        2,
        "Invalid success rate returns application error exit code 2"
    );

    like(
        $stderr,
        qr/Application error: Invalid success rate/,
        "Invalid success rate produces a clear application error"
    );
}

done_testing();
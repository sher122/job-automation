#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

require "$Bin/../automation.pl";

# ------------------------------------------------------------
# Test 1:
# Default configuration is returned when no CLI options exist.
# ------------------------------------------------------------

{
    local @ARGV = ();

    my $config = parse_cli();

    is(
        $config->{job_file},
        "jobs/jobs.json",
        "Default job file is used"
    );

    is(
        $config->{log_directory},
        "logs",
        "Default log directory is used"
    );

    is(
        $config->{log_file},
        "logs/job_results.csv",
        "Default log file is used"
    );
}

# ------------------------------------------------------------
# Test 2:
# CLI values override defaults.
# ------------------------------------------------------------

{
    local @ARGV = (
        "--job-file",
        "test-jobs.json",
        "--log-directory",
        "test-logs",
        "--log-file",
        "test-logs/results.csv"
    );

    my $config = parse_cli();

    is(
        $config->{job_file},
        "test-jobs.json",
        "--job-file overrides default"
    );

    is(
        $config->{log_directory},
        "test-logs",
        "--log-directory overrides default"
    );

    is(
        $config->{log_file},
        "test-logs/results.csv",
        "--log-file overrides default"
    );
}

# ------------------------------------------------------------
# Test 3:
# Unknown option must fail at parser level.
# ------------------------------------------------------------

{
    local @ARGV = (
        "--jobfile",
        "wrong.json"
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
        qr/Invalid command-line options/,
        "Unknown CLI option produces an error"
    );
}

# ------------------------------------------------------------
# Test 4:
# Missing option value must fail at parser level.
# ------------------------------------------------------------

{
    local @ARGV = (
        "--job-file"
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
        qr/Invalid command-line options/,
        "Missing CLI option value produces an error"
    );
}

# ------------------------------------------------------------
# Test 5:
# Unexpected positional argument must fail at parser level.
# ------------------------------------------------------------

{
    local @ARGV = (
        "unexpected-file.json"
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
        qr/Unexpected command-line argument/,
        "Unexpected positional argument produces an error"
    );
}

# ------------------------------------------------------------
# Test 6:
# Unknown option through the PUBLIC main() entry point.
# ------------------------------------------------------------

{
    local @ARGV = (
        "--jobfile",
        "wrong.json"
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
        "Unknown CLI option returns application error exit code 2"
    );

    like(
        $stderr,
        qr/Application error: Invalid command-line options/,
        "Unknown CLI option produces a human-readable application error"
    );
}

# ------------------------------------------------------------
# Test 7:
# Missing option value through the PUBLIC main() entry point.
# ------------------------------------------------------------

{
    local @ARGV = (
        "--job-file"
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
        "Missing CLI option value returns application error exit code 2"
    );

    like(
        $stderr,
        qr/Application error: Invalid command-line options/,
        "Missing CLI option value produces a human-readable application error"
    );
}

# ------------------------------------------------------------
# Test 8:
# Unexpected positional argument through the PUBLIC main()
# entry point.
# ------------------------------------------------------------

{
    local @ARGV = (
        "unexpected-file.json"
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
        "Unexpected positional argument returns application error exit code 2"
    );

    like(
        $stderr,
        qr/Application error: Unexpected command-line argument/,
        "Unexpected positional argument produces a human-readable application error"
    );
}

done_testing();
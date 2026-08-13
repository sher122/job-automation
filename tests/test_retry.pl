#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use File::Temp qw(tempdir);

require "$Bin/../automation.pl";

# ------------------------------------------------------------
# Test setup
# ------------------------------------------------------------

my $temp_dir = tempdir(CLEANUP => 1);

my $log_file =
    "$temp_dir/retry_results.csv";

my $job = {
    job_id      => "TEST-RETRY-001",
    priority    => "high",
    type        => "etch",
    submitted_at => "2026-08-13T10:00:00Z"
};

# ------------------------------------------------------------
# Test 1:
# A fake executor lets us deterministically simulate:
#
# FAILURE
# FAILURE
# SUCCESS
#
# without relying on rand().
# ------------------------------------------------------------

{
    my @results = (
        0,
        0,
        1
    );

    my $fake_executor = sub {
        my ($job) = @_;

        return shift @results;
    };

    my $success = process_with_retry(
        $job,
        3,
        $log_file,
        $fake_executor
    );

    ok(
        $success,
        "Job succeeds after retrying"
    );
}

# ------------------------------------------------------------
# Test 2:
# Three attempts must be logged.
# ------------------------------------------------------------

{
    open(
        my $handle,
        "<",
        $log_file
    ) or die "Cannot open test log: $!";

    my @lines = <$handle>;

    close($handle);

    is(
        scalar(@lines),
        3,
        "Three attempts were logged"
    );
}

# ------------------------------------------------------------
# Test 3:
# First attempt was a failure.
# ------------------------------------------------------------

{
    open(
        my $handle,
        "<",
        $log_file
    ) or die "Cannot open test log: $!";

    my @lines = <$handle>;

    close($handle);

    like(
        $lines[0],
        qr/,1,FAILURE$/,
        "First attempt logged as FAILURE"
    );
}

# ------------------------------------------------------------
# Test 4:
# Second attempt was a failure.
# ------------------------------------------------------------

{
    open(
        my $handle,
        "<",
        $log_file
    ) or die "Cannot open test log: $!";

    my @lines = <$handle>;

    close($handle);

    like(
        $lines[1],
        qr/,2,FAILURE$/,
        "Second attempt logged as FAILURE"
    );
}

# ------------------------------------------------------------
# Test 5:
# Third attempt succeeded.
# ------------------------------------------------------------

{
    open(
        my $handle,
        "<",
        $log_file
    ) or die "Cannot open test log: $!";

    my @lines = <$handle>;

    close($handle);

    like(
        $lines[2],
        qr/,3,SUCCESS$/,
        "Third attempt logged as SUCCESS"
    );
}

# ------------------------------------------------------------
# Test 6:
# A fake executor can force permanent failure.
# ------------------------------------------------------------

{
    my $failure_log =
        "$temp_dir/permanent_failure.csv";

    my @results = (
        0,
        0,
        0
    );

    my $fake_executor = sub {
        my ($job) = @_;

        return shift @results;
    };

    my $success = process_with_retry(
        $job,
        3,
        $failure_log,
        $fake_executor
    );

    ok(
        !$success,
        "Job fails after maximum retry attempts"
    );
}

done_testing();
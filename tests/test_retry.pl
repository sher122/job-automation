#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use File::Temp qw(tempfile);

require "$Bin/../automation.pl";

# ------------------------------------------------------------
# Test job
# ------------------------------------------------------------

my $test_job = {
    job_id       => "TEST-RETRY-001",
    priority     => "high",
    type         => "etch",
    submitted_at => "2026-08-13T10:00:00"
};

# ------------------------------------------------------------
# Create temporary log file
#
# The test should not modify the real production log.
# ------------------------------------------------------------

my ($log_handle, $log_file) = tempfile();

close($log_handle);

# ------------------------------------------------------------
# TEST 1
#
# Expected:
#
# Attempt 1 -> FAILURE
# Attempt 2 -> FAILURE
# Attempt 3 -> SUCCESS
# Final result -> SUCCESS
# ------------------------------------------------------------

my @retry_results = (0, 0, 1);

my $success = process_with_retry(
    $test_job,
    3,
    $log_file,
    \@retry_results
);

ok(
    $success,
    "Job succeeds after retrying"
);

# ------------------------------------------------------------
# Read the generated test log
# ------------------------------------------------------------

open(my $read_handle, "<", $log_file)
    or die "Cannot open test log: $!";

my @lines = <$read_handle>;

close($read_handle);

# ------------------------------------------------------------
# Verify that exactly three attempts were logged
# ------------------------------------------------------------

is(
    scalar(@lines),
    3,
    "Three attempts were logged"
);

# ------------------------------------------------------------
# Verify attempt results
# ------------------------------------------------------------

like(
    $lines[0],
    qr/,1,FAILURE$/,
    "First attempt logged as FAILURE"
);

like(
    $lines[1],
    qr/,2,FAILURE$/,
    "Second attempt logged as FAILURE"
);

like(
    $lines[2],
    qr/,3,SUCCESS$/,
    "Third attempt logged as SUCCESS"
);

# ------------------------------------------------------------
# TEST 2
#
# Expected:
#
# Attempt 1 -> FAILURE
# Attempt 2 -> FAILURE
# Attempt 3 -> FAILURE
# Final result -> FAILURE
# ------------------------------------------------------------

my @failure_results = (0, 0, 0);

my $permanent_failure = process_with_retry(
    $test_job,
    3,
    $log_file,
    \@failure_results
);

ok(
    !$permanent_failure,
    "Job fails after maximum retry attempts"
);

# ------------------------------------------------------------
# Finish test suite
# ------------------------------------------------------------

done_testing();
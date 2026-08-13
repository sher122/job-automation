#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

require "$Bin/../automation.pl";

# ------------------------------------------------------------
# Test 1: Valid job
# ------------------------------------------------------------

my $valid_job = {
    job_id       => "TEST-001",
    priority     => "critical",
    type         => "etch",
    submitted_at => "2026-08-13T10:00:00"
};

my ($valid, $message) = validate_job($valid_job);

ok($valid, "Valid job passes validation");
is($message, "Valid", "Valid job returns correct message");

# ------------------------------------------------------------
# Test 2: Missing required field
# ------------------------------------------------------------

my $missing_field_job = {
    job_id   => "TEST-002",
    priority => "high",
    type     => "etch"
};

my ($missing_valid, $missing_message) =
    validate_job($missing_field_job);

ok(!$missing_valid, "Job with missing field fails validation");

is(
    $missing_message,
    "Missing required field: submitted_at",
    "Correct missing-field error is returned"
);

# ------------------------------------------------------------
# Test 3: Invalid priority
# ------------------------------------------------------------

my $invalid_priority_job = {
    job_id       => "TEST-003",
    priority     => "urgent",
    type         => "etch",
    submitted_at => "2026-08-13T10:00:00"
};

my ($priority_valid, $priority_message) =
    validate_job($invalid_priority_job);

ok(!$priority_valid, "Invalid priority fails validation");

is(
    $priority_message,
    "Invalid priority: urgent",
    "Correct invalid-priority error is returned"
);

# ------------------------------------------------------------
# Test summary
# ------------------------------------------------------------

done_testing();
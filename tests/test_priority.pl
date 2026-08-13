#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

require "$Bin/../automation.pl";

# ------------------------------------------------------------
# Create jobs in deliberately mixed priority order
# ------------------------------------------------------------

my @jobs = (

    {
        job_id       => "TEST-LOW-001",
        priority     => "low",
        type         => "etch",
        submitted_at => "2026-08-13T10:00:00"
    },

    {
        job_id       => "TEST-CRITICAL-001",
        priority     => "critical",
        type         => "inspection",
        submitted_at => "2026-08-13T10:01:00"
    },

    {
        job_id       => "TEST-MEDIUM-001",
        priority     => "medium",
        type         => "clean",
        submitted_at => "2026-08-13T10:02:00"
    },

    {
        job_id       => "TEST-HIGH-001",
        priority     => "high",
        type         => "deposition",
        submitted_at => "2026-08-13T10:03:00"
    },

    {
        job_id       => "TEST-CRITICAL-002",
        priority     => "critical",
        type         => "etch",
        submitted_at => "2026-08-13T10:04:00"
    },

    {
        job_id       => "TEST-LOW-002",
        priority     => "low",
        type         => "inspection",
        submitted_at => "2026-08-13T10:05:00"
    }
);

# ------------------------------------------------------------
# Sort jobs
# ------------------------------------------------------------

my @sorted_jobs =
    sort_jobs_by_priority(@jobs);

# ------------------------------------------------------------
# Extract priorities from sorted jobs
# ------------------------------------------------------------

my @actual_priorities =
    map { $_->{priority} } @sorted_jobs;

# ------------------------------------------------------------
# Expected order
# ------------------------------------------------------------

my @expected_priorities = (
    "critical",
    "critical",
    "high",
    "medium",
    "low",
    "low"
);

# ------------------------------------------------------------
# Test 1:
# Verify complete priority ordering
# ------------------------------------------------------------

is_deeply(
    \@actual_priorities,
    \@expected_priorities,
    "Jobs are sorted from highest to lowest priority"
);

# ------------------------------------------------------------
# Test 2:
# Verify highest priority job appears first
# ------------------------------------------------------------

is(
    $sorted_jobs[0]->{priority},
    "critical",
    "Critical jobs are processed first"
);

# ------------------------------------------------------------
# Test 3:
# Verify lowest priority jobs appear last
# ------------------------------------------------------------

is(
    $sorted_jobs[-1]->{priority},
    "low",
    "Low priority jobs are processed last"
);

# ------------------------------------------------------------
# Test 4:
# Verify critical jobs retain their relative order
# ------------------------------------------------------------

is(
    $sorted_jobs[0]->{job_id},
    "TEST-CRITICAL-001",
    "First critical job retains relative order"
);

is(
    $sorted_jobs[1]->{job_id},
    "TEST-CRITICAL-002",
    "Second critical job retains relative order"
);

# ------------------------------------------------------------
# Test summary
# ------------------------------------------------------------

done_testing();
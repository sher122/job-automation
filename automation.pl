#!/usr/bin/perl

use strict;
use warnings;
use JSON::PP;

# ------------------------------------------------------------
# Validate a single job
# ------------------------------------------------------------

sub validate_job {
    my ($job) = @_;

    # Required fields that every job must contain
    my @required_fields = (
        "job_id",
        "priority",
        "type",
        "submitted_at"
    );

    # Check that every required field exists
    for my $field (@required_fields) {
        unless (exists $job->{$field}) {
            return (0, "Missing required field: $field");
        }
    }

    # Valid priority values
    my %valid_priorities = (
        critical => 1,
        high     => 1,
        medium   => 1,
        low      => 1
    );

    # Check whether the job priority is valid
    unless (exists $valid_priorities{$job->{priority}}) {
        return (0, "Invalid priority: $job->{priority}");
    }

    return (1, "Valid");
}

# ------------------------------------------------------------
# Program configuration
# ------------------------------------------------------------

my $project_name = "Job Automation Tool";
my $job_file     = "jobs/jobs.json";

# ------------------------------------------------------------
# Start program
# ------------------------------------------------------------

print "Starting $project_name\n";

# ------------------------------------------------------------
# Open job file
# ------------------------------------------------------------

open(my $file_handle, "<", $job_file)
    or die "Cannot open $job_file: $!\n";

# Read the complete file
local $/;

my $json_text = <$file_handle>;

# Close the file
close($file_handle);

# ------------------------------------------------------------
# Decode JSON
# ------------------------------------------------------------

my $jobs = decode_json($json_text);

# ------------------------------------------------------------
# Count jobs
# ------------------------------------------------------------

my $job_count = scalar(@{$jobs});

print "Loaded $job_count jobs\n";

# ------------------------------------------------------------
# Validate each job
# ------------------------------------------------------------

for my $job (@{$jobs}) {

    my ($valid, $message) = validate_job($job);

    if ($valid) {
        print "$job->{job_id}: VALID\n";
    }
    else {
        print "$job->{job_id}: INVALID - $message\n";
    }
}
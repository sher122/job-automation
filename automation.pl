#!/usr/bin/perl

use strict;
use warnings;
use JSON::PP;
use Time::HiRes qw(sleep);

# ------------------------------------------------------------
# Priority configuration
# ------------------------------------------------------------

my %priority_order = (
    critical => 1,
    high     => 2,
    medium   => 3,
    low      => 4
);

# ------------------------------------------------------------
# Validate a single job
# ------------------------------------------------------------

sub validate_job {
    my ($job) = @_;

    my @required_fields = (
        "job_id",
        "priority",
        "type",
        "submitted_at"
    );

    for my $field (@required_fields) {
        unless (exists $job->{$field}) {
            return (0, "Missing required field: $field");
        }
    }

    my %valid_priorities = (
        critical => 1,
        high     => 1,
        medium   => 1,
        low      => 1
    );

    unless (exists $valid_priorities{$job->{priority}}) {
        return (0, "Invalid priority: $job->{priority}");
    }

    return (1, "Valid");
}

# ------------------------------------------------------------
# Simulate processing a single job
# ------------------------------------------------------------

sub process_job {
    my ($job) = @_;

    print "\nProcessing job $job->{job_id}\n";
    print "Priority: $job->{priority}\n";
    print "Type: $job->{type}\n";

    # Simulate processing time between 1 and 3 seconds
    my $processing_time = 1 + int(rand(3));

    print "Processing for $processing_time seconds...\n";

    sleep($processing_time);

    # Simulate approximately 80% success rate
    my $result = rand();

    if ($result < 0.80) {
        print "Result: SUCCESS\n";

        return 1;
    }

    print "Result: FAILURE\n";

    return 0;
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

local $/;

my $json_text = <$file_handle>;

close($file_handle);

# ------------------------------------------------------------
# Decode JSON
# ------------------------------------------------------------

my $jobs = decode_json($json_text);

my $job_count = scalar(@{$jobs});

print "Loaded $job_count jobs\n";

# ------------------------------------------------------------
# Validate jobs
# ------------------------------------------------------------

my @valid_jobs;

for my $job (@{$jobs}) {

    my ($valid, $message) = validate_job($job);

    if ($valid) {
        push @valid_jobs, $job;
    }
    else {
        print "$job->{job_id}: INVALID - $message\n";
    }
}

# ------------------------------------------------------------
# Sort valid jobs by priority
# ------------------------------------------------------------

@valid_jobs = sort {
    $priority_order{$a->{priority}}
        <=>
    $priority_order{$b->{priority}}
} @valid_jobs;

# ------------------------------------------------------------
# Process jobs
# ------------------------------------------------------------

print "\nStarting job processing...\n";

my $successful_jobs = 0;
my $failed_jobs     = 0;

for my $job (@valid_jobs) {

    my $success = process_job($job);

    if ($success) {
        $successful_jobs++;
    }
    else {
        $failed_jobs++;
    }
}

# ------------------------------------------------------------
# Processing summary
# ------------------------------------------------------------

print "\nProcessing summary:\n";
print "Successful jobs: $successful_jobs\n";
print "Failed jobs:     $failed_jobs\n";
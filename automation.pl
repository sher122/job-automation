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
# Log a job processing result
# ------------------------------------------------------------

sub log_result {
    my ($log_file, $job, $attempt, $status) = @_;

    my $timestamp = scalar localtime();

    open(my $log_handle, ">>", $log_file)
        or die "Cannot open log file $log_file: $!\n";

    print $log_handle
        "$timestamp,$job->{job_id},$job->{priority},$job->{type},$attempt,$status\n";

    close($log_handle);
}

# ------------------------------------------------------------
# Process a job with retry logic
# ------------------------------------------------------------

sub process_with_retry {
    my ($job, $max_attempts, $log_file) = @_;

    for my $attempt (1 .. $max_attempts) {

        print "\nAttempt $attempt/$max_attempts for $job->{job_id}\n";

        my $success = process_job($job);

        if ($success) {

            log_result(
                $log_file,
                $job,
                $attempt,
                "SUCCESS"
            );

            return 1;
        }

        log_result(
            $log_file,
            $job,
            $attempt,
            "FAILURE"
        );

        if ($attempt < $max_attempts) {
            print "Job $job->{job_id} failed. Retrying...\n";
        }
    }

    print "Job $job->{job_id} failed after $max_attempts attempts.\n";

    return 0;
}

# ------------------------------------------------------------
# Main application
# ------------------------------------------------------------

sub main {

    # --------------------------------------------------------
    # Program configuration
    # --------------------------------------------------------

    my $project_name  = "Job Automation Tool";
    my $job_file      = "jobs/jobs.json";
    my $log_directory = "logs";
    my $log_file      = "$log_directory/job_results.csv";

    # --------------------------------------------------------
    # Start program
    # --------------------------------------------------------

    print "Starting $project_name\n";

    # --------------------------------------------------------
    # Initialize log directory
    # --------------------------------------------------------

    unless (-d $log_directory) {

        mkdir($log_directory)
            or die "Cannot create log directory $log_directory: $!\n";
    }

    # --------------------------------------------------------
    # Initialize log file
    # --------------------------------------------------------

    unless (-e $log_file) {

        open(my $log_handle, ">", $log_file)
            or die "Cannot create log file $log_file: $!\n";

        print $log_handle
            "timestamp,job_id,priority,type,attempt,status\n";

        close($log_handle);
    }

    # --------------------------------------------------------
    # Open job file
    # --------------------------------------------------------

    open(my $file_handle, "<", $job_file)
        or die "Cannot open $job_file: $!\n";

    local $/;

    my $json_text = <$file_handle>;

    close($file_handle);

    # --------------------------------------------------------
    # Decode JSON
    # --------------------------------------------------------

    my $jobs = decode_json($json_text);

    my $job_count = scalar(@{$jobs});

    print "Loaded $job_count jobs\n";

    # --------------------------------------------------------
    # Validate jobs
    # --------------------------------------------------------

    my @valid_jobs;
    my $invalid_job_count = 0;

    for my $job (@{$jobs}) {

        my ($valid, $message) = validate_job($job);

        if ($valid) {

            push @valid_jobs, $job;

        }
        else {

            print "$job->{job_id}: INVALID - $message\n";

            $invalid_job_count++;
        }
    }

    # --------------------------------------------------------
    # Sort valid jobs by priority
    # --------------------------------------------------------

    @valid_jobs = sort {
        $priority_order{$a->{priority}}
            <=>
        $priority_order{$b->{priority}}
    } @valid_jobs;

    # --------------------------------------------------------
    # Process jobs
    # --------------------------------------------------------

    print "\nStarting job processing...\n";

    my $successful_jobs = 0;
    my $failed_jobs     = 0;
    my $max_attempts    = 3;

    for my $job (@valid_jobs) {

        my $success = process_with_retry(
            $job,
            $max_attempts,
            $log_file
        );

        if ($success) {
            $successful_jobs++;
        }
        else {
            $failed_jobs++;
        }
    }

    # --------------------------------------------------------
    # Processing summary
    # --------------------------------------------------------

    print "\nProcessing summary:\n";
    print "Successful jobs: $successful_jobs\n";
    print "Failed jobs:     $failed_jobs\n";
    print "Invalid jobs:    $invalid_job_count\n";

    # --------------------------------------------------------
    # Exit status
    # --------------------------------------------------------

    if ($invalid_job_count > 0 || $failed_jobs > 0) {
        return 1;
    }

    return 0;
}

# ------------------------------------------------------------
# Run main only when this file is executed directly
# ------------------------------------------------------------

unless (caller) {
    exit main();
}
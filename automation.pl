#!/usr/bin/perl

use strict;
use warnings;
use JSON::PP;
use Time::HiRes qw(sleep);

# Priority ranking: lower number means higher priority.
my %priority_order = (
    critical => 1,
    high     => 2,
    medium   => 3,
    low      => 4
);

# Default application configuration.
my %default_config = (
    job_file      => "jobs/jobs.json",
    log_directory => "logs",
    log_file      => "logs/job_results.csv",
);

# Validate one job record.
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
        return (
            0,
            "Invalid priority: $job->{priority}"
        );
    }

    return (1, "Valid");
}

# Sort jobs from highest to lowest priority.
sub sort_jobs_by_priority {
    my (@jobs) = @_;

    my @sorted_jobs = sort {
        $priority_order{$a->{priority}}
            <=>
        $priority_order{$b->{priority}}
    } @jobs;

    return @sorted_jobs;
}

# Simulate processing one job.
#
# During tests, an optional array reference can provide deterministic
# results:
#
# 0 = FAILURE
# 1 = SUCCESS
#
# Normal execution uses random success/failure.
sub process_job {
    my ($job, $test_results) = @_;

    print "\nProcessing job $job->{job_id}\n";
    print "Priority: $job->{priority}\n";
    print "Type: $job->{type}\n";

    if (defined $test_results && @{$test_results}) {

        my $test_result = shift @{$test_results};

        if ($test_result) {
            print "Result: SUCCESS\n";
            return 1;
        }

        print "Result: FAILURE\n";
        return 0;
    }

    my $processing_time = 1 + int(rand(3));

    print "Processing for $processing_time seconds...\n";

    sleep($processing_time);

    if (rand() < 0.80) {
        print "Result: SUCCESS\n";
        return 1;
    }

    print "Result: FAILURE\n";

    return 0;
}

# Write one processing attempt to the CSV log.
sub log_result {
    my ($log_file, $job, $attempt, $status) = @_;

    my $timestamp = scalar localtime();

    open(my $log_handle, ">>", $log_file)
        or die "Cannot open log file $log_file: $!\n";

    print $log_handle
        "$timestamp,$job->{job_id},$job->{priority},$job->{type},$attempt,$status\n";

    close($log_handle);
}

# Process a job with a bounded retry policy.
sub process_with_retry {
    my ($job, $max_attempts, $log_file, $test_results) = @_;

    for my $attempt (1 .. $max_attempts) {

        print "\nAttempt $attempt/$max_attempts for $job->{job_id}\n";

        my $success = process_job(
            $job,
            $test_results
        );

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
            print
                "Job $job->{job_id} failed. Retrying...\n";
        }
    }

    print
        "Job $job->{job_id} failed after $max_attempts attempts.\n";

    return 0;
}

# Run the application workflow.
#
# This function contains operations that may fail because of
# filesystem or input errors.
sub run_application {
    my ($runtime_config) = @_;

    my $project_name  = "Job Automation Tool";
    my $job_file      = $runtime_config->{job_file};
    my $log_directory = $runtime_config->{log_directory};
    my $log_file      = $runtime_config->{log_file};
    my $test_results  = $runtime_config->{test_results};

    print "Starting $project_name\n";

    # Create the log directory if necessary.
    unless (-d $log_directory) {

        mkdir($log_directory)
            or die
                "Cannot create log directory $log_directory: $!\n";
    }

    # Create the log file if necessary.
    unless (-e $log_file) {

        open(my $log_handle, ">", $log_file)
            or die
                "Cannot create log file $log_file: $!\n";

        print $log_handle
            "timestamp,job_id,priority,type,attempt,status\n";

        close($log_handle);
    }

    # Read the job file.
    open(my $file_handle, "<", $job_file)
        or die
            "Cannot open $job_file: $!\n";

    local $/;

    my $json_text = <$file_handle>;

    close($file_handle);

    # Parse JSON inside its own error boundary so that we can
    # provide a useful application-level message.
    my $jobs;

    {
        local $@;

        eval {
            $jobs = decode_json($json_text);
            1;
        }
        or do {
            my $json_error = $@;

            chomp $json_error;

            # Remove the low-level Perl source location from the
            # message. The application should report the problem,
            # not expose an internal source-code location.
            $json_error =~ s/\s+at\s+.*\s+line\s+\d+\.\s*$//;

            die
                "Invalid JSON in $job_file: $json_error\n";
        };
    }

    # The job file must contain a JSON array.
    unless (ref($jobs) eq "ARRAY") {
        die
            "Invalid job file $job_file: root element must be a JSON array\n";
    }

    my $job_count = scalar(@{$jobs});

    print "Loaded $job_count jobs\n";

    # Validate jobs.
    my @valid_jobs;

    my $invalid_job_count = 0;

    for my $job (@{$jobs}) {

        my ($valid, $message) = validate_job($job);

        if ($valid) {

            push @valid_jobs, $job;
        }
        else {

            print
                "$job->{job_id}: INVALID - $message\n";

            $invalid_job_count++;
        }
    }

    # Sort valid jobs by priority.
    @valid_jobs =
        sort_jobs_by_priority(@valid_jobs);

    print "\nStarting job processing...\n";

    my $successful_jobs = 0;
    my $failed_jobs     = 0;
    my $max_attempts    = 3;

    for my $job (@valid_jobs) {

        my $success = process_with_retry(
            $job,
            $max_attempts,
            $log_file,
            $test_results
        );

        if ($success) {
            $successful_jobs++;
        }
        else {
            $failed_jobs++;
        }
    }

    print "\nProcessing summary:\n";

    print
        "Successful jobs: $successful_jobs\n";

    print
        "Failed jobs:     $failed_jobs\n";

    print
        "Invalid jobs:    $invalid_job_count\n";

    # Exit code 1 means the application completed, but
    # the job run contained invalid or failed jobs.
    if (
        $invalid_job_count > 0
        ||
        $failed_jobs > 0
    ) {
        return 1;
    }

    # Exit code 0 means the application completed successfully.
    return 0;
}

# Public application entry point.
#
# Runtime/application errors are converted into exit code 2.
sub main {
    my ($config) = @_;

    my %runtime_config = %default_config;

    if (defined $config) {

        %runtime_config = (
            %runtime_config,
            %{$config}
        );
    }

    my $exit_code;
    my $error_message;

    {
        local $@;

        eval {
            $exit_code = run_application(
                \%runtime_config
            );

            1;
        }
        or do {
            $error_message = $@;
        };
    }

    # Application error.
    if (defined $error_message) {

        chomp $error_message;

        print STDERR
            "Application error: $error_message\n";

        return 2;
    }

    return $exit_code;
}

# Only execute the application when this file is run directly.
#
# When required by tests, main() is not automatically executed.
unless (caller) {
    exit main();
}
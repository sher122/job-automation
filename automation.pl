#!/usr/bin/perl

use strict;
use warnings;
use JSON::PP;
use Time::HiRes qw(sleep);
use Getopt::Long qw(GetOptions);

Getopt::Long::Configure(
    "no_ignore_case",
    "no_auto_abbrev"
);

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
    success_rate  => 0.80,
);

# ------------------------------------------------------------
# Command-line configuration
# ------------------------------------------------------------

sub parse_cli {
    my %config = %default_config;

    my $job_file;
    my $log_file;
    my $log_directory;
    my $success_rate;

    my $success = GetOptions(
        "job-file=s"      => \$job_file,
        "log-file=s"      => \$log_file,
        "log-directory=s" => \$log_directory,
        "success-rate=s"  => \$success_rate
    );

    unless ($success) {
        die "Invalid command-line options\n";
    }

    if (@ARGV) {
        die
            "Unexpected command-line argument: $ARGV[0]\n";
    }

    if (defined $job_file) {
        $config{job_file} = $job_file;
    }

    if (defined $log_file) {
        $config{log_file} = $log_file;
    }

    if (defined $log_directory) {
        $config{log_directory} = $log_directory;
    }

    if (defined $success_rate) {

        unless ($success_rate =~ /\A(?:0(?:\.\d+)?|1(?:\.0+)?)\z/) {
            die
                "Invalid success rate: $success_rate. " .
                "Expected a value between 0.0 and 1.0\n";
        }

        $config{success_rate} = $success_rate + 0;
    }

    return \%config;
}

# ------------------------------------------------------------
# Job validation
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
        return (
            0,
            "Invalid priority: $job->{priority}"
        );
    }

    return (1, "Valid");
}

# ------------------------------------------------------------
# Priority sorting
# ------------------------------------------------------------

sub sort_jobs_by_priority {
    my (@jobs) = @_;

    my @sorted_jobs = sort {
        $priority_order{$a->{priority}}
            <=>
        $priority_order{$b->{priority}}
    } @jobs;

    return @sorted_jobs;
}

# ------------------------------------------------------------
# Job processing
# ------------------------------------------------------------

sub process_job {
    my ($job, $test_results, $success_rate) = @_;

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

    if (rand() < $success_rate) {
        print "Result: SUCCESS\n";
        return 1;
    }

    print "Result: FAILURE\n";

    return 0;
}

# ------------------------------------------------------------
# CSV serialization
# ------------------------------------------------------------

sub csv_escape {
    my ($field) = @_;

    $field = "" unless defined $field;

    my $needs_quotes =
           $field =~ /,/
        || $field =~ /"/
        || $field =~ /\n/;

    return $field unless $needs_quotes;

    $field =~ s/"/""/g;

    return qq{"$field"};
}

# ------------------------------------------------------------
# CSV logging
# ------------------------------------------------------------

sub log_result {
    my ($log_file, $job, $attempt, $status) = @_;

    my $timestamp = scalar localtime();

    my @fields = (
        $timestamp,
        $job->{job_id},
        $job->{priority},
        $job->{type},
        $attempt,
        $status
    );

    my @escaped_fields =
        map { csv_escape($_) } @fields;

    open(my $log_handle, ">>", $log_file)
        or die "Cannot open log file $log_file: $!\n";

    print $log_handle
        join(",", @escaped_fields) . "\n";

    close($log_handle);
}

# ------------------------------------------------------------
# Retry processing
# ------------------------------------------------------------

sub process_with_retry {
    my (
        $job,
        $max_attempts,
        $log_file,
        $test_results,
        $success_rate
    ) = @_;

    for my $attempt (1 .. $max_attempts) {

        print
            "\nAttempt $attempt/$max_attempts " .
            "for $job->{job_id}\n";

        my $success = process_job(
            $job,
            $test_results,
            $success_rate
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

# ------------------------------------------------------------
# Main application workflow
# ------------------------------------------------------------

sub run_application {
    my ($runtime_config) = @_;

    my $project_name  = "Job Automation Tool";
    my $job_file      = $runtime_config->{job_file};
    my $log_directory = $runtime_config->{log_directory};
    my $log_file      = $runtime_config->{log_file};
    my $test_results  = $runtime_config->{test_results};
    my $success_rate  = $runtime_config->{success_rate};

    print "Starting $project_name\n";

    unless (-d $log_directory) {

        mkdir($log_directory)
            or die
                "Cannot create log directory $log_directory: $!\n";
    }

    unless (-e $log_file) {

        open(my $log_handle, ">", $log_file)
            or die
                "Cannot create log file $log_file: $!\n";

        print $log_handle
            "timestamp,job_id,priority,type,attempt,status\n";

        close($log_handle);
    }

    open(my $file_handle, "<", $job_file)
        or die
            "Cannot open $job_file: $!\n";

    local $/;

    my $json_text = <$file_handle>;

    close($file_handle);

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

            $json_error =~
                s/\s+at\s+.*\s+line\s+\d+\.\s*$//;

            die
                "Invalid JSON in $job_file: $json_error\n";
        };
    }

    unless (ref($jobs) eq "ARRAY") {
        die
            "Invalid job file $job_file: " .
            "root element must be a JSON array\n";
    }

    my $job_count = scalar(@{$jobs});

    print "Loaded $job_count jobs\n";

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
            $test_results,
            $success_rate
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

    if (
        $invalid_job_count > 0
        ||
        $failed_jobs > 0
    ) {
        return 1;
    }

    return 0;
}

# ------------------------------------------------------------
# Public application entry point
# ------------------------------------------------------------

sub main {
    my ($config) = @_;

    my $exit_code;
    my $error_message;

    {
        local $@;

        eval {

            my $runtime_config;

            if (defined $config) {

                $runtime_config = {
                    %default_config,
                    %{$config}
                };
            }
            else {

                $runtime_config = parse_cli();
            }

            $exit_code = run_application(
                $runtime_config
            );

            1;
        }
        or do {
            $error_message = $@;
        };
    }

    if (defined $error_message) {

        chomp $error_message;

        print STDERR
            "Application error: $error_message\n";

        return 2;
    }

    return $exit_code;
}

# Only execute the application when run directly.
unless (caller) {
    exit main();
}
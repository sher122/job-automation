#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use File::Temp qw(tempdir);

require "$Bin/../automation.pl";

# ------------------------------------------------------------
# Test helpers
# ------------------------------------------------------------

sub capture_main {
    my ($config) = @_;

    my $stderr = "";
    my $exit_code;

    {
        local *STDERR;

        open(STDERR, ">", \$stderr)
            or die "Cannot capture STDERR: $!";

        $exit_code = main($config);
    }

    return ($exit_code, $stderr);
}

sub write_file {
    my ($path, $content) = @_;

    open(
        my $handle,
        ">",
        $path
    ) or die "Cannot create $path: $!";

    print $handle $content;

    close($handle);
}

# ------------------------------------------------------------
# Test 1 and 2:
# Missing job file
# ------------------------------------------------------------

{
    my $temp_dir = tempdir(CLEANUP => 1);

    my $missing_job_file =
        "$temp_dir/does_not_exist.json";

    my $log_directory =
        "$temp_dir/logs";

    my $log_file =
        "$log_directory/results.csv";

    my $config = {
        job_file      => $missing_job_file,
        log_directory => $log_directory,
        log_file      => $log_file
    };

    my ($exit_code, $stderr) =
        capture_main($config);

    is(
        $exit_code,
        2,
        "Missing job file returns application error exit code 2"
    );

    like(
        $stderr,
        qr/Application error: Cannot open .*does_not_exist\.json/,
        "Missing job file produces a human-readable error message"
    );
}

# ------------------------------------------------------------
# Test 3 and 4:
# Malformed JSON
# ------------------------------------------------------------

{
    my $temp_dir = tempdir(CLEANUP => 1);

    my $job_file =
        "$temp_dir/malformed.json";

    my $log_directory =
        "$temp_dir/logs";

    my $log_file =
        "$log_directory/results.csv";

    write_file(
        $job_file,
        '[{"job_id":"BAD-JSON","priority":"high"'
    );

    my $config = {
        job_file      => $job_file,
        log_directory => $log_directory,
        log_file      => $log_file
    };

    my ($exit_code, $stderr) =
        capture_main($config);

    is(
        $exit_code,
        2,
        "Malformed JSON returns application error exit code 2"
    );

    like(
        $stderr,
        qr/Application error: Invalid JSON/,
        "Malformed JSON produces a human-readable error message"
    );
}

# ------------------------------------------------------------
# Test 5 and 6:
# Valid JSON but incorrect root type.
# ------------------------------------------------------------

{
    my $temp_dir = tempdir(CLEANUP => 1);

    my $job_file =
        "$temp_dir/object.json";

    my $log_directory =
        "$temp_dir/logs";

    my $log_file =
        "$log_directory/results.csv";

    write_file(
        $job_file,
        '{"not":"an array"}'
    );

    my $config = {
        job_file      => $job_file,
        log_directory => $log_directory,
        log_file      => $log_file
    };

    my ($exit_code, $stderr) =
        capture_main($config);

    is(
        $exit_code,
        2,
        "Valid JSON with non-array root returns exit code 2"
    );

    like(
        $stderr,
        qr/Application error: Invalid job file .*root element must be a JSON array/,
        "Wrong JSON root produces a clear application error"
    );
}

# ------------------------------------------------------------
# Test 7 and 8:
# Log directory failure.
# ------------------------------------------------------------

{
    my $temp_dir = tempdir(CLEANUP => 1);

    my $job_file =
        "$temp_dir/jobs.json";

    my $blocked_parent =
        "$temp_dir/blocked";

    my $log_directory =
        "$blocked_parent/logs";

    my $log_file =
        "$log_directory/results.csv";

    write_file(
        $job_file,
        '[]'
    );

    # Create a file where the application expects a directory.
    write_file(
        $blocked_parent,
        "not a directory"
    );

    my $config = {
        job_file      => $job_file,
        log_directory => $log_directory,
        log_file      => $log_file
    };

    my ($exit_code, $stderr) =
        capture_main($config);

    is(
        $exit_code,
        2,
        "Log directory failure returns application error exit code 2"
    );

    like(
        $stderr,
        qr/Application error: Cannot create log directory/,
        "Log directory failure produces a clear application error"
    );
}

# ------------------------------------------------------------
# Test 9 and 10:
# Job fails after maximum retry attempts.
#
# IMPORTANT:
# The executor is injected into the application.
#
# This replaces the old test_results mechanism.
# ------------------------------------------------------------

{
    my $temp_dir = tempdir(CLEANUP => 1);

    my $job_file =
        "$temp_dir/jobs.json";

    my $log_directory =
        "$temp_dir/logs";

    my $log_file =
        "$log_directory/results.csv";

    write_file(
        $job_file,
        <<'JSON'
[
    {
        "job_id": "FAILED-001",
        "priority": "high",
        "type": "etch",
        "submitted_at": "2026-08-13T10:00:00Z"
    }
]
JSON
    );

    # Deterministic executor:
    # every execution fails.
    my $fake_executor = sub {
        my ($job) = @_;

        return 0;
    };

    my $config = {
        job_file  => $job_file,
        log_directory => $log_directory,
        log_file  => $log_file,
        executor  => $fake_executor
    };

    my ($exit_code, $stderr) =
        capture_main($config);

    is(
        $exit_code,
        1,
        "Job failure after maximum retries returns exit code 1"
    );

    unlike(
        $stderr,
        qr/Application error:/,
        "Job-level failure does not produce an application error"
    );
}

# ------------------------------------------------------------
# Test 11 and 12:
# Successful application run.
# ------------------------------------------------------------

{
    my $temp_dir = tempdir(CLEANUP => 1);

    my $job_file =
        "$temp_dir/jobs.json";

    my $log_directory =
        "$temp_dir/logs";

    my $log_file =
        "$log_directory/results.csv";

    write_file(
        $job_file,
        <<'JSON'
[
    {
        "job_id": "VALID-001",
        "priority": "critical",
        "type": "etch",
        "submitted_at": "2026-08-13T10:00:00Z"
    }
]
JSON
    );

    # Deterministic successful executor.
    my $fake_executor = sub {
        my ($job) = @_;

        return 1;
    };

    my $config = {
        job_file  => $job_file,
        log_directory => $log_directory,
        log_file  => $log_file,
        executor  => $fake_executor
    };

    my ($exit_code, $stderr) =
        capture_main($config);

    is(
        $exit_code,
        0,
        "Successful run returns exit code 0"
    );

    unlike(
        $stderr,
        qr/Application error:/,
        "Successful run produces no application error"
    );
}

done_testing();
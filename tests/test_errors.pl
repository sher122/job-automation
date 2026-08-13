#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use File::Temp qw(tempdir);
use File::Spec;

require "$Bin/../automation.pl";

# ------------------------------------------------------------
# Test helper
# ------------------------------------------------------------

sub capture_stderr {
    my ($code_ref) = @_;

    my $stderr = "";
    my $result;

    {
        local *STDERR;

        open(STDERR, ">", \$stderr)
            or die "Cannot capture STDERR: $!";

        $result = $code_ref->();
    }

    return ($result, $stderr);
}

# ------------------------------------------------------------
# Create an isolated temporary test environment.
# ------------------------------------------------------------

my $test_directory = tempdir(CLEANUP => 1);

my $log_directory = File::Spec->catdir(
    $test_directory,
    "logs"
);

my $log_file = File::Spec->catfile(
    $log_directory,
    "job_results.csv"
);

# ------------------------------------------------------------
# Test 1:
# Missing job file must return exit code 2.
# ------------------------------------------------------------

my $missing_job_file = File::Spec->catfile(
    $test_directory,
    "does_not_exist.json"
);

my ($exit_code, $stderr) = capture_stderr(
    sub {
        return main({
            job_file      => $missing_job_file,
            log_directory => $log_directory,
            log_file      => $log_file
        });
    }
);

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

# ------------------------------------------------------------
# Test 2:
# Malformed JSON must return exit code 2.
# ------------------------------------------------------------

my $malformed_job_file = File::Spec->catfile(
    $test_directory,
    "malformed.json"
);

open(my $malformed_handle, ">", $malformed_job_file)
    or die "Cannot create malformed JSON fixture: $!";

print $malformed_handle <<'JSON';
[
    {
        "job_id": "BROKEN-001",
        "priority": "high",
        "type": "etch",
        "submitted_at": "2026-08-13T10:00:00"
    }
JSON

close($malformed_handle);

($exit_code, $stderr) = capture_stderr(
    sub {
        return main({
            job_file      => $malformed_job_file,
            log_directory => $log_directory,
            log_file      => $log_file
        });
    }
);

is(
    $exit_code,
    2,
    "Malformed JSON returns application error exit code 2"
);

like(
    $stderr,
    qr/Application error: Invalid JSON in .*malformed\.json:/,
    "Malformed JSON produces a human-readable error message"
);

# ------------------------------------------------------------
# Test 3:
# Valid JSON syntax, but root element is not an array.
# ------------------------------------------------------------

my $wrong_root_job_file = File::Spec->catfile(
    $test_directory,
    "wrong_root.json"
);

open(my $wrong_root_handle, ">", $wrong_root_job_file)
    or die "Cannot create wrong-root JSON fixture: $!";

print $wrong_root_handle <<'JSON';
{
    "not": "an array"
}
JSON

close($wrong_root_handle);

($exit_code, $stderr) = capture_stderr(
    sub {
        return main({
            job_file      => $wrong_root_job_file,
            log_directory => $log_directory,
            log_file      => $log_file
        });
    }
);

is(
    $exit_code,
    2,
    "Valid JSON with non-array root returns exit code 2"
);

like(
    $stderr,
    qr/root element must be a JSON array/,
    "Wrong JSON root produces a clear application error"
);

# ------------------------------------------------------------
# Test 4:
# Log directory failure must return exit code 2.
#
# We deliberately create a FILE where the application expects
# a DIRECTORY. mkdir() must therefore fail.
# ------------------------------------------------------------

my $invalid_log_directory = File::Spec->catfile(
    $test_directory,
    "not_a_directory"
);

open(my $fake_directory_handle, ">", $invalid_log_directory)
    or die "Cannot create fake log directory: $!";

print $fake_directory_handle "This is a file, not a directory.\n";

close($fake_directory_handle);

my $valid_for_log_failure = File::Spec->catfile(
    $test_directory,
    "valid_for_log_failure.json"
);

open(my $log_failure_job_handle, ">", $valid_for_log_failure)
    or die "Cannot create log failure fixture: $!";

print $log_failure_job_handle <<'JSON';
[
    {
        "job_id": "LOG-FAIL-001",
        "priority": "high",
        "type": "etch",
        "submitted_at": "2026-08-13T10:00:00"
    }
]
JSON

close($log_failure_job_handle);

my $invalid_log_file = File::Spec->catfile(
    $invalid_log_directory,
    "job_results.csv"
);

($exit_code, $stderr) = capture_stderr(
    sub {
        return main({
            job_file      => $valid_for_log_failure,
            log_directory => $invalid_log_directory,
            log_file      => $invalid_log_file
        });
    }
);

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

# ------------------------------------------------------------
# Test 5:
# Job-level failure must return exit code 1.
#
# The application itself runs correctly.
# The job fails all three attempts.
# ------------------------------------------------------------

my $failed_job_file = File::Spec->catfile(
    $test_directory,
    "failed_job.json"
);

open(my $failed_job_handle, ">", $failed_job_file)
    or die "Cannot create failed-job fixture: $!";

print $failed_job_handle <<'JSON';
[
    {
        "job_id": "FAILED-001",
        "priority": "high",
        "type": "etch",
        "submitted_at": "2026-08-13T10:00:00"
    }
]
JSON

close($failed_job_handle);

my $failed_log_directory = File::Spec->catdir(
    $test_directory,
    "failed_logs"
);

my $failed_log_file = File::Spec->catfile(
    $failed_log_directory,
    "job_results.csv"
);

($exit_code, $stderr) = capture_stderr(
    sub {
        return main({
            job_file      => $failed_job_file,
            log_directory => $failed_log_directory,
            log_file      => $failed_log_file,

            # Three deterministic failures.
            test_results => [0, 0, 0]
        });
    }
);

is(
    $exit_code,
    1,
    "Job failure after maximum retries returns exit code 1"
);

is(
    $stderr,
    "",
    "Job-level failure does not produce an application error"
);

# ------------------------------------------------------------
# Test 6:
# Successful application run must return exit code 0.
# ------------------------------------------------------------

my $valid_job_file = File::Spec->catfile(
    $test_directory,
    "valid.json"
);

open(my $valid_handle, ">", $valid_job_file)
    or die "Cannot create valid JSON fixture: $!";

print $valid_handle <<'JSON';
[
    {
        "job_id": "VALID-001",
        "priority": "critical",
        "type": "etch",
        "submitted_at": "2026-08-13T10:00:00"
    }
]
JSON

close($valid_handle);

my $valid_log_directory = File::Spec->catdir(
    $test_directory,
    "valid_logs"
);

my $valid_log_file = File::Spec->catfile(
    $valid_log_directory,
    "job_results.csv"
);

($exit_code, $stderr) = capture_stderr(
    sub {
        return main({
            job_file      => $valid_job_file,
            log_directory => $valid_log_directory,
            log_file      => $valid_log_file,

            # Deterministic success.
            test_results => [1]
        });
    }
);

is(
    $exit_code,
    0,
    "Successful run returns exit code 0"
);

is(
    $stderr,
    "",
    "Successful run produces no application error"
);

# ------------------------------------------------------------
# Finish.
# ------------------------------------------------------------

done_testing();
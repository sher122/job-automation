#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use File::Temp qw(tempdir);
use File::Spec;

require "$Bin/../automation.pl";

# ------------------------------------------------------------
# Test 1:
# A normal field should remain unchanged.
# ------------------------------------------------------------

is(
    csv_escape("etch"),
    "etch",
    "Normal field is unchanged"
);

# ------------------------------------------------------------
# Test 2:
# A comma requires quoting.
# ------------------------------------------------------------

is(
    csv_escape("etch, plasma"),
    '"etch, plasma"',
    "Field containing comma is quoted"
);

# ------------------------------------------------------------
# Test 3:
# A double quote must be doubled before quoting.
# ------------------------------------------------------------

is(
    csv_escape('etch "deep"'),
    '"etch ""deep"""',
    "Double quotes are escaped correctly"
);

# ------------------------------------------------------------
# Test 4:
# A newline requires quoting.
# ------------------------------------------------------------

is(
    csv_escape("line one\nline two"),
    "\"line one\nline two\"",
    "Field containing newline is quoted"
);

# ------------------------------------------------------------
# Test 5:
# Multiple special characters are handled together.
# ------------------------------------------------------------

is(
    csv_escape('etch, "deep"'),
    '"etch, ""deep"""',
    "Comma and double quote are escaped together"
);

# ------------------------------------------------------------
# Test 6:
# Undefined values become empty CSV fields.
# ------------------------------------------------------------

is(
    csv_escape(undef),
    "",
    "Undefined field becomes empty field"
);

# ------------------------------------------------------------
# Integration test:
# Write a real log entry and inspect the generated CSV line.
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

mkdir($log_directory)
    or die "Cannot create test log directory: $!";

my $job = {
    job_id       => "CSV-001",
    priority     => "high",
    type         => "etch, plasma",
    submitted_at => "2026-08-13T10:00:00"
};

log_result(
    $log_file,
    $job,
    1,
    "SUCCESS"
);

open(my $log_handle, "<", $log_file)
    or die "Cannot open generated CSV log: $!";

# log_result() writes the data record only.
# The production application creates the header separately.
my $record = <$log_handle>;

close($log_handle);

# ------------------------------------------------------------
# Test 7:
# The generated record must contain the quoted type field.
# ------------------------------------------------------------

like(
    $record,
    qr/,high,"etch, plasma",1,SUCCESS$/,
    "CSV log preserves comma-containing type as one field"
);

# ------------------------------------------------------------
# Test 8:
# The generated record should retain the expected structure.
# ------------------------------------------------------------

like(
    $record,
    qr/^[^,]+,CSV-001,high,"etch, plasma",1,SUCCESS$/,
    "CSV record retains the expected six-field structure"
);
# ------------------------------------------------------------
# Test 9:
# A field containing a carriage return must be quoted.
#
# This specifically tests \r rather than relying on the
# existing newline test to cover all line-ending cases.
# ------------------------------------------------------------

{
    my $value = "etch\rplasma";

    my $escaped = csv_escape($value);

    is(
        $escaped,
        "\"etch\rplasma\"",
        "Field containing carriage return is quoted"
    );
}

# ------------------------------------------------------------
# Test 10:
# A field containing carriage return and comma must preserve
# both characters while remaining a single CSV field.
# ------------------------------------------------------------

{
    my $value = "etch,\rplasma";

    my $escaped = csv_escape($value);

    is(
        $escaped,
        "\"etch,\rplasma\"",
        "Carriage return and comma are escaped together"
    );
}
done_testing();
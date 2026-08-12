#!/usr/bin/perl

use strict;
use warnings;
use JSON::PP;

my $project_name = "Job Automation Tool";
my $job_file     = "jobs/jobs.json";

print "Starting $project_name\n";

open(my $file_handle, "<", $job_file)
    or die "Cannot open $job_file: $!\n";

local $/;

my $json_text = <$file_handle>;

close($file_handle);

my $jobs = decode_json($json_text);

my $job_count = scalar(@{$jobs});

print "Loaded $job_count jobs\n";
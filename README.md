# Job Automation Tool

A Perl-based job automation system that validates jobs, schedules them by priority, processes them with retry handling, and records each attempt to a CSV result log.

Project 1 is the **job execution layer** of the larger automation/reporting workflow.

It is intentionally responsible for:

- loading jobs from JSON
- validating job definitions
- scheduling jobs by priority
- processing jobs
- retrying failed jobs
- recording attempt results
- returning explicit process exit codes

The generated CSV results are consumed by **Project 2**, which imports them into SQLite and provides reporting and dashboard functionality.

---

## Project Overview

The system models a simple automated job-processing pipeline:

```text
jobs/jobs.json
      |
      v
+------------------+
| Load JSON jobs   |
+------------------+
      |
      v
+------------------+
| Validate jobs    |
+------------------+
      |
      v
+------------------+
| Priority sort    |
+------------------+
      |
      v
+------------------+
| Process jobs     |
+------------------+
      |
      v
+------------------+
| Retry failures   |
| up to 3 attempts |
+------------------+
      |
      v
+------------------+
| CSV result log   |
+------------------+
      |
      v
Project 2
job-reporting
```

Project 1 produces the execution results.

Project 2 consumes those results and provides persistent reporting.

---

## Features

### Job validation

Each job is validated before processing.

Validation covers required job fields and supported priority values.

Invalid jobs are rejected before execution and reported with a clear validation error.

The validation test suite verifies:

- valid jobs are accepted
- missing fields are rejected
- invalid priorities are rejected
- appropriate validation messages are returned

---

### Priority scheduling

Jobs are processed according to priority.

Supported priorities are:

```text
critical
high
medium
low
```

Higher-priority jobs are processed before lower-priority jobs.

Jobs with the same priority retain their relative ordering.

The priority test suite verifies:

- highest priority is processed first
- critical jobs precede lower priorities
- low-priority jobs are processed last
- relative order is retained within a priority level

---

### Retry handling

Failed jobs are retried automatically.

The retry limit is intentionally fixed at **three total attempts**.

```text
Attempt 1
   |
   +-- SUCCESS --> completed
   |
   +-- FAILURE
          |
          v
       Attempt 2
          |
          +-- SUCCESS --> completed
          |
          +-- FAILURE
                 |
                 v
              Attempt 3
                 |
                 +-- SUCCESS --> completed
                 |
                 +-- FAILURE --> job failed
```

A job that succeeds after a retry is still considered successfully completed.

A job that fails all three attempts is reported as a job-level failure.

The retry tests verify:

- jobs can succeed after retrying
- all attempts are logged
- individual attempt statuses are recorded correctly
- jobs that fail three times are reported as failed

---

## Deterministic Testing

The production job-processing code uses an executor abstraction.

The default production executor performs the real job-processing behavior and closes over the configured success rate.

Tests can provide a deterministic executor instead of relying on random production behavior.

This separates:

```text
Production execution
        |
        v
Default executor
```

from:

```text
Automated tests
        |
        v
Deterministic test executor
```

The processing functions receive the executor rather than a test-results array.

This makes retry and failure scenarios deterministic without changing the production processing logic.

For example, tests can explicitly control a sequence such as:

```text
FAILURE
FAILURE
SUCCESS
```

and verify that the job succeeds on the third attempt.

---

## Configurable Success Rate

The simulated job-processing success rate is configurable from the command line.

The value is a decimal between:

```text
0.0
```

and:

```text
1.0
```

inclusive.

Examples:

```powershell
perl automation.pl --success-rate 0.8
```

80% simulated success probability.

75%:

```powershell
perl automation.pl --success-rate 0.75
```

Always successful:

```powershell
perl automation.pl --success-rate 1
```

Always unsuccessful:

```powershell
perl automation.pl --success-rate 0
```

The value is validated before execution.

Values outside the `0.0–1.0` range are rejected.

---

## Command-Line Interface

The application supports configuration through command-line options.

### Run with defaults

```powershell
perl automation.pl
```

The application uses the default job file, log directory, and log file.

---

### Specify a job file

```powershell
perl automation.pl --job-file jobs/jobs.json
```

The default job file is:

```text
jobs/jobs.json
```

---

### Specify a log directory

```powershell
perl automation.pl --log-directory logs
```

---

### Specify a log file

```powershell
perl automation.pl --log-file logs/job_results.csv
```

---

### Configure success rate

```powershell
perl automation.pl --success-rate 0.8
```

---

### Combine options

```powershell
perl automation.pl --job-file jobs/jobs.json --log-directory logs --log-file logs/job_results.csv --success-rate 0.8
```

---

## Configuration Summary

| Option            | Description                                       |
| ----------------- | ------------------------------------------------- |
| `--job-file`      | JSON file containing jobs                         |
| `--log-directory` | Directory for result logs                         |
| `--log-file`      | CSV result-log path                               |
| `--success-rate`  | Simulated success probability from `0.0` to `1.0` |

The retry limit is **not configurable**.

It is fixed at three total attempts by design.

---

## Exit-Code Contract

The application uses explicit exit codes so that callers such as schedulers, shell scripts, CI systems, or other automation can distinguish between successful execution, job failure, and application errors.

| Exit code | Meaning                                                                            |
| --------: | ---------------------------------------------------------------------------------- |
|       `0` | Application completed successfully and all processed jobs succeeded                |
|       `1` | Application ran successfully, but one or more jobs failed after all retry attempts |
|       `2` | Application/configuration error prevented normal execution                         |

### Exit code 0

A successful run returns:

```text
0
```

Example:

```powershell
perl automation.pl
$LASTEXITCODE
```

A successful job run does not produce an application error.

---

### Exit code 1

If a job fails after the maximum of three attempts, the application returns:

```text
1
```

This represents a **job-level failure**, not an application failure.

For example:

```text
Attempt 1/3
Result: FAILURE

Attempt 2/3
Result: FAILURE

Attempt 3/3
Result: FAILURE

Job FAILED-001 failed after 3 attempts.
```

The application can still produce a valid processing summary and CSV result log.

---

### Exit code 2

Exit code `2` represents an application/configuration error.

Examples include:

- missing job file
- malformed JSON
- JSON root is not an array
- log-directory failure
- unknown command-line option
- missing command-line option argument
- unexpected positional argument
- invalid command-line configuration

These errors are accompanied by human-readable error messages.

---

## Why the Exit-Code Contract Matters

The distinction between job failure and application failure is intentional.

For example:

```text
Job failed after retries
        |
        v
Exit code 1
```

means the automation system itself ran correctly, but the workload failed.

Whereas:

```text
Invalid JSON
        |
        v
Exit code 2
```

means the application could not perform its normal job-processing operation.

This allows an external scheduler or automation system to make different decisions depending on the failure type.

---

## CSV Result Logging

Project 1 **writes** job-attempt results to CSV.

It does not read or import the CSV file.

The CSV writer handles fields requiring quoting, including values containing:

- commas
- double quotes
- embedded newlines
- undefined values

The CSV tests verify the escaping behavior and preservation of the expected six-field record structure.

The output records contain:

```text
timestamp
job_id
priority
type
attempt
status
```

A typical record has the structure:

```text
2026-08-16 12:00:00,JOB-001,critical,etch,1,SUCCESS
```

If a field contains a comma, it is quoted appropriately.

For example:

```text
2026-08-16 12:00:00,JOB-001,critical,"inspection,clean",1,SUCCESS
```

Project 2 is responsible for reading these CSV results and importing them into SQLite.

---

## Project 1 / Project 2 Boundary

The two projects have deliberately separated responsibilities.

### Project 1 — `job-automation`

Responsible for:

```text
JSON input
    |
    v
Validation
    |
    v
Priority scheduling
    |
    v
Execution and retry
    |
    v
CSV result logging
```

### Project 2 — `job-reporting`

Responsible for:

```text
CSV results
    |
    v
CSV parsing
    |
    v
Validation/import
    |
    v
SQLite
    |
    v
CLI reporting
    |
    v
HTML dashboard
```

This separation keeps job execution independent from reporting and persistence.

---

## Error Handling

Application-level errors are handled explicitly.

The application distinguishes between:

### Input/configuration errors

Examples:

```text
Missing job file
Malformed JSON
Invalid JSON structure
Invalid CLI option
Missing CLI argument
Invalid configuration
```

These return exit code:

```text
2
```

### Job-level failures

A valid job that fails all three attempts returns:

```text
1
```

The application itself remains operational and can produce its processing summary and result log.

### Successful processing

Successful processing returns:

```text
0
```

---

## Example Execution

A normal run looks conceptually like:

```text
Starting Job Automation Tool
Loaded 3 jobs

Starting job processing...

Attempt 1/3 for JOB-001

Processing job JOB-001
Priority: critical
Type: etch
Result: SUCCESS

Attempt 1/3 for JOB-002

Processing job JOB-002
Priority: high
Type: inspection
Result: FAILURE
Job JOB-002 failed. Retrying...

Attempt 2/3 for JOB-002

Processing job JOB-002
Priority: high
Type: inspection
Result: SUCCESS

Processing summary:
Successful jobs: 2
Failed jobs:     0
Invalid jobs:    0
```

---

## Testing

The project has dedicated Perl test scripts covering the major application behaviors.

Run them from the project directory.

### Validation

```powershell
perl tests/test_validation.pl
```

Covers:

- valid jobs
- missing fields
- invalid priorities
- validation messages

---

### Retry behavior

```powershell
perl tests/test_retry.pl
```

Covers:

- successful retry
- attempt logging
- per-attempt statuses
- failure after maximum attempts

---

### Priority scheduling

```powershell
perl tests/test_priority.pl
```

Covers:

- priority ordering
- critical jobs first
- low-priority jobs last
- stable ordering within a priority

---

### CSV logging

```powershell
perl tests/test_csv.pl
```

Covers:

- normal CSV fields
- comma-containing fields
- double-quote escaping
- newline-containing fields
- combined comma/quote escaping
- undefined values
- six-field record structure

---

### CLI configuration

```powershell
perl tests/test_cli.pl
```

Covers:

- default job file
- default log directory
- default log file
- `--log-directory`
- `--log-file`
- unknown options
- missing option arguments
- unexpected positional arguments
- application exit code `2`
- human-readable CLI errors

---

### Success-rate configuration

```powershell
perl tests/test_success_rate.pl
```

Covers validation and behavior of the configurable success-rate value.

The accepted interface is a decimal in the range:

```text
0.0 <= success-rate <= 1.0
```

---

### Application errors and exit codes

```powershell
perl tests/test_errors.pl
```

Covers:

- missing job file
- malformed JSON
- invalid JSON root
- log-directory failure
- job failure after maximum retries
- successful execution
- exit code `0`
- exit code `1`
- exit code `2`
- human-readable application errors

---

## Test Summary

The project has dedicated tests for:

```text
test_validation.pl
test_retry.pl
test_priority.pl
test_csv.pl
test_cli.pl
test_success_rate.pl
test_errors.pl
```

The test suite is designed around behavior rather than only individual functions.

In particular, the error tests exercise the application as an external process so that exit-code behavior is verified at the same boundary used by a scheduler or shell script.

---

## Syntax Checks

Individual Perl files can also be checked without executing them:

```powershell
perl -c automation.pl
```

For example:

```text
automation.pl syntax OK
```

---

## Project Structure

The project is organized approximately as follows:

```text
job-automation/
|
+-- automation.pl
|
+-- jobs/
|   +-- jobs.json
|
+-- logs/
|   +-- job_results.csv
|
+-- tests/
|   +-- test_validation.pl
|   +-- test_retry.pl
|   +-- test_priority.pl
|   +-- test_csv.pl
|   +-- test_cli.pl
|   +-- test_success_rate.pl
|   +-- test_errors.pl
|
+-- README.md
```

Generated logs and other runtime artifacts should not be treated as source code.

---

## Design Decisions

### Fixed retry limit

The application uses a fixed maximum of three attempts.

This keeps the retry policy simple and predictable while leaving the success rate independently configurable.

---

### Priority before execution

Jobs are sorted by priority before processing.

This ensures that higher-priority work is handled before lower-priority work.

---

### Deterministic execution in tests

The production executor is separated from the processing and retry logic.

Tests can inject a deterministic executor so that specific sequences of outcomes can be reproduced reliably.

For example:

```text
FAILURE
FAILURE
SUCCESS
```

can be tested without depending on randomness.

---

### Explicit exit-code contract

The application distinguishes:

```text
0 = success
1 = job failure
2 = application/configuration error
```

This is designed specifically to make the program usable as a component inside a larger automation pipeline.

---

### Separation from reporting

Project 1 does not contain the database reporting layer.

Its responsibility ends after producing the job-attempt result log.

Project 2 consumes those results and provides:

- SQLite persistence
- reporting
- metrics
- HTML dashboard generation

This keeps execution and reporting independently testable.

---

## Requirements

The project requires Perl and the Perl modules used by the application and test suite.

The application is intended to be run from the project directory.

Example:

```powershell
cd E:\Projects\job-automation
perl automation.pl
```

---

## Typical Workflow

A complete two-project workflow is:

```text
                 PROJECT 1
              job-automation
                    |
                    v
             jobs/jobs.json
                    |
                    v
             Job validation
                    |
                    v
            Priority scheduling
                    |
                    v
             Job processing
                    |
                    v
              Retry handling
                    |
                    v
           CSV result logging
                    |
                    v
             job_results.csv
                    |
                    |
                    v
                 PROJECT 2
              job-reporting
                    |
                    v
              CSV import
                    |
                    v
                 SQLite
                    |
                    v
             CLI reporting
                    |
                    v
            HTML dashboard
```

The projects therefore form a small but complete automation pipeline:

```text
Execute → Record → Import → Report
```

---

## What This Project Demonstrates

This project demonstrates several practical automation concepts:

- Perl application development
- structured JSON input
- input validation
- priority-based scheduling
- retry handling
- deterministic testing
- dependency injection
- CSV output and escaping
- command-line configuration
- explicit process exit codes
- application-level error handling
- automated behavioral testing
- separation of execution from reporting

The design emphasizes predictable behavior and clear interfaces between components.

---

## Project 2

Project 2 extends the system by consuming the CSV results generated here.

It adds:

- SQLite storage
- job and attempt tables
- CSV import
- reporting queries
- CLI reporting
- HTML dashboard generation
- reporting metrics

Repository:

```text
job-reporting
```

The two projects are intentionally kept separate so that the job executor does not depend on the reporting database or dashboard implementation.

---

## Author

Sher

## License

This project is provided for educational and portfolio purposes.

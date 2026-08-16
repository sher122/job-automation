# Job Automation System

A Perl-based job processing engine that validates jobs, schedules them by priority, retries failures automatically, and logs a full audit trail to CSV — built as the first half of a two-part automation-and-reporting pipeline.

**Live pipeline:** this project produces the data; [`job-reporting`](../job-reporting) turns it into a SQLite-backed dashboard.

---

## At a Glance

| | |
|---|---|
| **Language** | Perl 5 |
| **Tests** | 7 test suites, 90+ automated assertions, all passing |
| **Key skills demonstrated** | error handling & exit-code contracts, dependency injection, CLI design, CSV serialization, retry logic, priority scheduling |
| **What it does** | Takes a batch of jobs, processes them by priority with automatic retries, and produces an auditable CSV log other tools can consume |

---

## Why This Project

Most "automation script" portfolio pieces stop at "it runs." This one is built the way a production tool would need to be: it has a defined contract for how it reports success/failure to whatever calls it (a shell script, a scheduler, a CI pipeline), it's tested against real failure conditions (missing files, malformed input, filesystem errors) — not just the happy path, and its test suite uses dependency injection so retry and failure behavior can be verified deterministically instead of relying on chance.

---

## What It Does

```text
Jobs in (JSON) → Validate → Sort by priority → Process → Retry on failure (up to 3x) → CSV audit log out
```

- **Validates** every job before processing; invalid jobs are rejected up front, not discovered mid-run.
- **Schedules** by priority (`critical → high → medium → low`), so the most important work runs first.
- **Retries** failed jobs automatically, up to 3 attempts, and logs every attempt — not just the final outcome.
- **Reports outcome via exit code** (`0` = success, `1` = job failures, `2` = application error) so it plugs cleanly into a scheduler or shell pipeline.
- **Writes a structured, RFC-compliant CSV log** that a downstream reporting tool (Project 2) reads and turns into a dashboard.

---

## Run It

```powershell
perl automation.pl
```

With options:

```powershell
perl automation.pl --job-file jobs\jobs.json --success-rate 0.8
```

Full CLI reference and test-by-test breakdown are in [`DETAILS.md`](DETAILS.md).

---

## Testing

```powershell
perl tests\test_validation.pl
perl tests\test_retry.pl
perl tests\test_priority.pl
perl tests\test_errors.pl
perl tests\test_csv.pl
perl tests\test_cli.pl
perl tests\test_success_rate.pl
```

All 7 suites pass. Coverage includes malformed JSON, missing files, filesystem failures, CSV special-character escaping, and CLI validation — not just successful runs.

---

## Engineering Highlights

- **Dependency injection for deterministic tests** — the job executor is injected rather than hardcoded, so retry/failure paths are tested with predetermined outcomes instead of relying on randomness.
- **Explicit error boundaries** — every failure mode (bad input, filesystem error, invalid config) is caught and converted into a documented exit code rather than leaking a raw stack trace.
- **CSV safety** — fields with commas or embedded quotes are correctly escaped so downstream parsing never breaks, verified with dedicated regression tests.

---

## Part of a Larger System

```text
Job Automation (this repo)  →  job_results.csv  →  Job Reporting (SQLite + dashboard)
```

The two projects are deliberately decoupled — this one has zero database dependencies and can run entirely on its own; the reporting layer treats the CSV as its only contract with this system.

---

*Full technical documentation, architecture diagrams, and design-decision rationale: [`DETAILS.md`](DETAILS.md)*

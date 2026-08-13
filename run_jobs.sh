#!/bin/bash

# ------------------------------------------------------------
# Determine the directory containing this script
# ------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------
# Move to the project directory
# ------------------------------------------------------------

cd "$SCRIPT_DIR" || exit 1

# ------------------------------------------------------------
# Start application
# ------------------------------------------------------------

echo "========================================"
echo "Starting Job Automation Tool"
echo "========================================"

echo "Project directory: $SCRIPT_DIR"
echo "Running Perl job processor..."

# ------------------------------------------------------------
# Run Perl application
# ------------------------------------------------------------

perl automation.pl

EXIT_CODE=$?

# ------------------------------------------------------------
# Report result
# ------------------------------------------------------------

echo ""
echo "Perl process exited with code: $EXIT_CODE"

if [ "$EXIT_CODE" -eq 0 ]; then
    echo "Job automation completed successfully."
else
    echo "Job automation failed."
fi

# ------------------------------------------------------------
# Return Perl exit code
# ------------------------------------------------------------

exit "$EXIT_CODE"
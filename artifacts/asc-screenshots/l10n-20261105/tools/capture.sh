#!/bin/sh
set -eu
cd "$(dirname "$0")/../../../.."
exec artifacts/asc-screenshots/l10n-20261105/.venv/bin/python artifacts/asc-screenshots/l10n-20261105/tools/capture.py "$@"

#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
status=0
bash "$HERE/hook_test.sh" || status=1
bash "$HERE/validators_test.sh" || status=1
bash "$HERE/security_test.sh" || status=1
bash "$HERE/parser_test.sh" || status=1
python3 "$HERE/drivers_test.py" || status=1
exit $status

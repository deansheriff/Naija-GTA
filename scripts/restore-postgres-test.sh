#!/usr/bin/env bash
set -euo pipefail
archive=${1:?Usage: bash scripts/restore-postgres-test.sh backup.dump nsl_restore_testname}
database=${2:?Choose a new disposable database name}
if [[ ! "$database" =~ ^nsl_restore_[a-z0-9_]{1,40}$ ]] || [[ ! -f "$archive" ]]; then echo "Use an existing archive and a new nsl_restore_ database name." >&2; exit 1; fi
# createdb fails if the target exists. Never clean or overwrite the live database.
docker compose exec -T postgres createdb -U nsl "$database"
docker compose exec -T postgres pg_restore -U nsl --exit-on-error --no-owner --no-privileges --dbname "$database" < "$archive"
echo "Restored into a separate private database. Verify recovery, balances, receipts and audit before relying on this backup."

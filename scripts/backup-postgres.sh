#!/usr/bin/env bash
set -euo pipefail
umask 077
output=${1:?Usage: bash scripts/backup-postgres.sh /secure/path/backup.dump}
if [[ -e "$output" ]]; then echo "Refusing to overwrite an existing backup." >&2; exit 1; fi
if [[ ! -d "$(dirname -- "$output")" ]]; then echo "Create the private backup directory first." >&2; exit 1; fi
set -o noclobber
docker compose exec -T postgres pg_dump -U nsl -d nsl --format=custom --no-owner --no-privileges > "$output"
echo "Backup written. Copy it to your encrypted off-host storage and test a restore."

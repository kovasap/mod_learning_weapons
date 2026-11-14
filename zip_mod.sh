#!/usr/bin/env bash
# Builds mod_learning_weapons.zip with the same layout the game expects
# (and the same directories the CI workflow packages).
set -euo pipefail

cd "$(dirname "$0")"

MOD_NAME="mod_learning_weapons"
ZIP_FILE="${MOD_NAME}.zip"
CONTENTS=(scripts "${MOD_NAME}" ui)

if ! command -v zip >/dev/null 2>&1; then
	echo "error: 'zip' is required but was not found in PATH" >&2
	exit 1
fi

for dir in "${CONTENTS[@]}"; do
	if [ ! -d "${dir}" ]; then
		echo "error: missing directory '${dir}'" >&2
		exit 1
	fi
done

rm -f "${ZIP_FILE}"

zip -r "${ZIP_FILE}" "${CONTENTS[@]}" \
	-x '*.DS_Store' '*.swp' '*~'

echo "Created $(pwd)/${ZIP_FILE}"

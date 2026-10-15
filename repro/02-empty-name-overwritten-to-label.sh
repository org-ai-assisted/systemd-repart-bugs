#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## Issue 2: on adoption, systemd-repart OVERWRITES an existing partition's empty
## GPT name with the definition's Label=. A partition you deliberately left
## unnamed comes back named after whatever def happened to match it.

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
shopt -s inherit_errexit
shopt -s shift_verbose
export LC_ALL=C

cd -- "$(dirname -- "$(readlink --canonicalize -- "${BASH_SOURCE[0]}")")"
# shellcheck source=./lib.sh
source ./lib.sh

repro_init
make_loop_image 128
gpt_one_linux_partition

before_name="$(part_name)"

defs="${repro_scratch}/defs"
write_def "${defs}" "[Partition]
Type=linux-generic
Label=adopted-by-repart"

printf '%s\n' "== running systemd-repart (Label= only, no Format/Encrypt) =="
rc=0
systemd-repart --dry-run=no --definitions="${defs}" "${repro_loop}" || rc="$?"
settle_partitions
printf '%s\n' "repart exit code: ${rc}"

after_name="$(part_name)"

printf '%s\n' "== observed =="
printf '%s\n' "name: [${before_name}] -> [${after_name}]"

check "repart exit 0"    "${rc}"          "0"
check "name was empty"   "${before_name}" ""
check "name overwritten" "${after_name}"  "adopted-by-repart"

finish

#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## Issue 4: on a blank disk with NO partition table, systemd-repart's default
## --empty=refuse refuses to act and exits 77 ("... has no GPT disk label, not
## repartitioning."). Initializing a blank existing disk requires --empty=allow
## (or force). Surprising next to sfdisk/sgdisk, which happily write a fresh
## table. (--empty=create is for a MISSING image file, not an existing blank
## block device -- on a loop device it fails with "File exists".)

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
no_gpt

defs="${repro_scratch}/defs"
write_def "${defs}" "[Partition]
Type=linux-generic
Label=data"

printf '%s\n' "== run with DEFAULT --empty=refuse on a blank (no-GPT) disk =="
out_refuse="${repro_scratch}/refuse.txt"
rc_refuse=0
systemd-repart --dry-run=no --definitions="${defs}" "${repro_loop}" >"${out_refuse}" 2>&1 || rc_refuse="$?"
cat -- "${out_refuse}"

said_no_gpt="no"
if grep --quiet --ignore-case "no gpt disk label" -- "${out_refuse}"; then
  said_no_gpt="yes"
fi

printf '%s\n' "== run with --empty=allow on the same blank disk =="
rc_create=0
systemd-repart --dry-run=no --empty=allow --definitions="${defs}" "${repro_loop}" || rc_create="$?"
settle_partitions
created_name="$(part_name)"

printf '%s\n' "== observed =="
printf '%s\n' "default --empty=refuse exit: ${rc_refuse} (expected 77)"
printf '%s\n' "refuse message mentioned no-GPT: ${said_no_gpt}"
printf '%s\n' "empty=allow exit: ${rc_create}, partition name: ${created_name}"

check "refuse exits 77"            "${rc_refuse}"    "77"
check "refuse explains no-GPT"     "${said_no_gpt}"  "yes"
check "empty=allow succeeds"       "${rc_create}"    "0"
check "empty=allow made partition" "${created_name}" "data"

finish

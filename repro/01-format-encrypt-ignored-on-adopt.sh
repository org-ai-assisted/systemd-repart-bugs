#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## Issue 1: Format= and Encrypt= are SILENTLY IGNORED on an existing partition
## that systemd-repart adopts (matches by Type=). The partition is grown and
## renamed to Label=, but NOT reformatted and NOT encrypted, while repart exits
## 0. An "encrypted" target is left as plaintext ext4 and its stale data
## survives.

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
format_ext4_with_sentinel "STALE-SECRET-DATA"

before_sectors="$(part_sectors)"

defs="${repro_scratch}/defs"
key="$(make_keyfile)"
write_def "${defs}" "[Partition]
Type=linux-generic
Label=persistence
Format=ext4
Encrypt=key-file"

printf '%s\n' "== running systemd-repart (adopt existing Type=linux-generic partition) =="
rc=0
systemd-repart --dry-run=no --definitions="${defs}" --key-file="${key}" "${repro_loop}" || rc="$?"
settle_partitions
printf '%s\n' "repart exit code: ${rc}"

after_name="$(part_name)"
after_fstype="$(part_fstype)"
after_sectors="$(part_sectors)"
after_sentinel="$(sentinel_present)"

printf '%s\n' "== observed =="
printf '%s\n' "name:     ${after_name}"
printf '%s\n' "fstype:   ${after_fstype}"
printf '%s\n' "sectors:  ${before_sectors} -> ${after_sectors}"
printf '%s\n' "sentinel: ${after_sentinel}"

grew="no"
if [ "${after_sectors}" -gt "${before_sectors}" ]; then
  grew="yes"
fi

luks="no"
if [ "${after_fstype}" = "crypto_LUKS" ]; then
  luks="yes"
fi

## The footgun: repart succeeds, renames + grows, but leaves the partition as
## plaintext ext4 with the old data intact -- Format=/Encrypt= did nothing.
check "repart exit 0"           "${rc}"             "0"
check "renamed to Label"        "${after_name}"     "persistence"
check "grew to fill disk"       "${grew}"           "yes"
check "fstype still plain ext4" "${after_fstype}"   "ext4"
check "NOT LUKS-encrypted"      "${luks}"           "no"
check "stale data survived"     "${after_sentinel}" "yes"

finish

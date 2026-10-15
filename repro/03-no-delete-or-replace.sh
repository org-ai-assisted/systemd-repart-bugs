#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## Issue 3: systemd-repart has no delete/replace semantics. It never removes or
## reformats a partition it matched; once a partition exists, a changed
## definition no-ops ("No changes.") on it. There is no --force-style reformat --
## you must delete the partition yourself (e.g. sgdisk) first.

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
format_ext4_with_sentinel "KEEP-ME"

defs="${repro_scratch}/defs"

## First run: definition asks for vfat, but the partition already exists as ext4.
write_def "${defs}" "[Partition]
Type=linux-generic
Label=data
Format=vfat"

printf '%s\n' "== run 1: adopt existing ext4 partition, def asks Format=vfat =="
rc1=0
systemd-repart --dry-run=no --definitions="${defs}" "${repro_loop}" || rc1="$?"
settle_partitions
fstype_after_1="$(part_fstype)"
printf '%s\n' "exit=${rc1} fstype=${fstype_after_1}"

## Second run: identical state -> repart reports it has nothing to do.
printf '%s\n' "== run 2: identical def, nothing to change =="
out2="${repro_scratch}/run2.txt"
rc2=0
systemd-repart --dry-run=no --definitions="${defs}" "${repro_loop}" >"${out2}" 2>&1 || rc2="$?"
settle_partitions
fstype_after_2="$(part_fstype)"
cat -- "${out2}"

no_changes="no"
if grep --quiet --ignore-case "no changes" -- "${out2}"; then
  no_changes="yes"
fi

printf '%s\n' "== observed =="
printf '%s\n' "fstype after run1: ${fstype_after_1} (def wanted vfat)"
printf '%s\n' "fstype after run2: ${fstype_after_2}"
printf '%s\n' "run2 said No changes.: ${no_changes}"

## The matched partition is never reformatted to the def's Format=, and a
## repeated run is a declarative no-op -- no imperative replace is possible.
check "run1 exit 0"              "${rc1}"            "0"
check "run2 exit 0"              "${rc2}"            "0"
check "ext4 NOT replaced"        "${fstype_after_1}" "ext4"
check "still ext4 after run2"    "${fstype_after_2}" "ext4"
check "run2 reported No changes" "${no_changes}"     "yes"

finish

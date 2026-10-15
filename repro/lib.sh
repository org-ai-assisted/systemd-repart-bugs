#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## Shared helpers for the systemd-repart minimal reproductions.
## Each repro sources this, builds a loop-backed GPT image, drives
## systemd-repart against it, and asserts the observed on-disk state.
## Must run as real root (losetup + mount). Never on the host dev VM.

## style-ok: R-120 -- portable repro: runs on a stock systemd host that has no
## Kicksecure safe-rm shadow, so plain rm is intended here.

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
shopt -s inherit_errexit
shopt -s shift_verbose
export LC_ALL=C

## Generic Linux filesystem data GPT type GUID == systemd-repart Type=linux-generic.
LINUX_GENERIC_GUID="0fc63daf-8483-4772-8e79-3d69d8477de4"

repro_scratch=""
repro_loop=""

require_root() {
  if [ "$(id --user)" != "0" ]; then
    printf '%s\n' "ERROR: must run as root (losetup + mount)." >&2
    exit 2
  fi
}

## Detach the loop device (and its partition maps) and remove the scratch dir.
## Each step is best-effort so one failure does not abort the rest of cleanup.
repro_cleanup() {
  if [ -n "${repro_loop}" ]; then
    umount --quiet "${repro_loop}p1" 2>/dev/null || true
    losetup --detach "${repro_loop}" 2>/dev/null || true
  fi
  if [ -n "${repro_scratch}" ]; then
    rm --recursive --force -- "${repro_scratch}" || true
  fi
}

repro_init() {
  require_root
  repro_scratch="$(mktemp --directory)"
  trap repro_cleanup EXIT
}

## make_loop_image <size_mib> -> sets repro_loop to the attached /dev/loopN
make_loop_image() {
  local size_mib image
  size_mib="${1}"
  image="${repro_scratch}/disk.img"
  truncate --size="${size_mib}M" -- "${image}"
  repro_loop="$(losetup --find --show --partscan -- "${image}")"
}

## gpt_one_linux_partition: GPT with ONE linux-generic partition, EMPTY name,
## 20 MiB, leaving the rest of the disk free so repart can grow it.
gpt_one_linux_partition() {
  sfdisk --quiet --label gpt "${repro_loop}" >/dev/null <<-EOF
	start=2048, size=40960, type=${LINUX_GENERIC_GUID}
	EOF
  settle_partitions
}

## no_gpt: zero any disk label so the device has NO partition table.
no_gpt() {
  wipefs --all --quiet "${repro_loop}" >/dev/null
}

settle_partitions() {
  partprobe "${repro_loop}" 2>/dev/null || true
  udevadm settle 2>/dev/null || true
  ## Wait for the kernel partition node to appear.
  local _
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if [ -b "${repro_loop}p1" ]; then
      return 0
    fi
    sleep 0.3
  done
}

## format_ext4_with_sentinel <sentinel-text>: mkfs ext4 on p1, write a file so
## we can later tell whether repart wiped the partition.
format_ext4_with_sentinel() {
  local sentinel mnt
  sentinel="${1}"
  mnt="${repro_scratch}/mnt"
  mkfs.ext4 -q -F "${repro_loop}p1"
  mkdir --parents -- "${mnt}"
  mount "${repro_loop}p1" "${mnt}"
  printf '%s\n' "${sentinel}" > "${mnt}/SENTINEL"
  umount "${mnt}"
}

## Observers (echo a single token so callers can compare).
part_fstype() {
  blkid --match-tag TYPE --output value "${repro_loop}p1" 2>/dev/null || printf '%s' "none"
}

part_name() {
  sfdisk --dump "${repro_loop}" | sed --quiet "s|^${repro_loop}p1 .*name=\"\\([^\"]*\\)\".*|\\1|p"
}

part_sectors() {
  blockdev --getsz "${repro_loop}p1"
}

## sentinel_present: echo yes|no -- is the ext4 SENTINEL file still there?
sentinel_present() {
  local mnt present
  mnt="${repro_scratch}/mnt"
  mkdir --parents -- "${mnt}"
  present="no"
  if mount "${repro_loop}p1" "${mnt}" 2>/dev/null; then
    if [ -f "${mnt}/SENTINEL" ]; then
      present="yes"
    fi
    umount "${mnt}"
  fi
  printf '%s' "${present}"
}

## write_def <dir> <conf-body>: create a repart definitions dir with one .conf.
write_def() {
  local dir body
  dir="${1}"
  body="${2}"
  mkdir --parents -- "${dir}"
  printf '%s\n' "${body}" > "${dir}/10-test.conf"
}

make_keyfile() {
  local kf
  kf="${repro_scratch}/key"
  head --bytes=64 /dev/urandom > "${kf}"
  chmod 0600 -- "${kf}"
  printf '%s' "${kf}"
}

## PASS/FAIL bookkeeping.
repro_fail=0
check() {
  local label got want
  label="${1}"
  got="${2}"
  want="${3}"
  if [ "${got}" = "${want}" ]; then
    printf '%s\n' "  ok   ${label} (got=${got})"
  else
    printf '%s\n' "  FAIL ${label} (got=${got} want=${want})"
    repro_fail=1
  fi
}

finish() {
  if [ "${repro_fail}" -ne 0 ]; then
    printf '%s\n' "RESULT: FAIL (behavior did not match the documented reproduction)"
    exit 1
  fi
  printf '%s\n' "RESULT: PASS (issue reproduced as documented)"
}

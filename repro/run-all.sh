#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## Runs every systemd-repart reproduction, capturing each one's output under
## results/ as the committed evidence. Must run as real root. Prints a summary
## and exits non-zero if any reproduction failed.

## style-ok: R-120 -- portable repro: runs on a stock systemd host that has no
## Kicksecure safe-rm shadow, so plain rm is intended here.

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
shopt -s inherit_errexit
shopt -s shift_verbose
export LC_ALL=C

cd -- "$(dirname -- "$(readlink --canonicalize -- "${BASH_SOURCE[0]}")")"

if [ "$(id --user)" != "0" ]; then
  printf '%s\n' "ERROR: run as root, e.g. sudo bash ./run-all.sh" >&2
  exit 2
fi

results="results"
rm --recursive --force -- "${results}"
mkdir --parents -- "${results}"

## Each repro attaches its own loop device and detaches it in its EXIT trap, so
## no suite-wide loop cleanup is needed here. A host-wide `losetup --detach-all`
## would tear out unrelated loop devices (mounted snaps, ISOs, image builds).

## First line of each version string, without a head-on-pipe SIGPIPE.
sctl_ver="$(systemctl --version)"
repart_ver="$(systemd-repart --version)"
# shellcheck disable=SC1091
. /etc/os-release
{
  printf '%s\n' "== environment =="
  printf '%s\n' "${sctl_ver%%$'\n'*}"
  printf '%s\n' "${repart_ver%%$'\n'*}"
  printf '%s\n' "os: ${PRETTY_NAME:-${NAME:-Linux}}"
} | tee "${results}/env.txt"
printf '%s\n' ""

overall=0
for script in \
  01-format-encrypt-ignored-on-adopt.sh \
  02-empty-name-overwritten-to-label.sh \
  03-no-delete-or-replace.sh \
  04-empty-refuse-blank-disk.sh
do
  log="${results}/${script%.sh}.log"
  printf '%s\n' "########## ${script} ##########"
  rc=0
  bash "./${script}" 2>&1 | tee "${log}" || rc="${PIPESTATUS[0]}"
  if [ "${rc}" -ne 0 ]; then
    overall=1
    printf '%s\n' ">>> ${script} FAILED (rc=${rc})"
  else
    printf '%s\n' ">>> ${script} ok"
  fi
done

## Hand the root-created evidence back to the invoking (sudo) user so the next
## unprivileged pull/sync can overwrite it. Ownership alone suffices -- the owner
## already has write via the default mode, so no world-writable bits are added.
if [ -n "${SUDO_UID:-}" ]; then
  chown --recursive "${SUDO_UID}:${SUDO_GID:-${SUDO_UID}}" -- "${results}"
fi

if [ "${overall}" -ne 0 ]; then
  printf '%s\n' "SUMMARY: at least one reproduction did not reproduce."
  exit 1
fi
printf '%s\n' "SUMMARY: all reproductions reproduced as documented."

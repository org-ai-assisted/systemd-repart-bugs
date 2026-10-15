# systemd-repart-bugs

Minimal, empirically-reproduced reports of surprising / footgun behaviors in
`systemd-repart`, found while building a live-USB persistence provisioner on
Kicksecure / Debian trixie. Each issue has a self-checking reproduction script
that builds a loop-backed GPT image, drives `systemd-repart` against it, and
asserts the observed on-disk state.

All reproductions were run and pass on:

```
systemd 257 (257.13-1~deb13u1)
Debian GNU/Linux 13 (trixie)
```

**None of these is an undocumented bug.** Each behavior is spelled out in the
current `repart.d(5)` / `systemd-repart(8)` man pages, and a search of
github.com/systemd/systemd found no issue reporting any of them. They are
collected here because they are documented-but-easy-to-miss footguns for
*imperative* provisioning, and one of them is a silent data-safety trap.

The headline is **issue 01**: `Format=` and `Encrypt=` are silently ignored when
repart adopts an already-existing partition, so an "encrypted" target can be left
as plaintext with its old data intact while repart exits 0. This is documented
("This option has no effect if the partition already exists."), but repart emits
no warning that it skipped the format/encrypt, which is the dangerous part.

## Index

| # | Classification | Issue | Triggers when |
|---|---|---|---|
| [01](issues/01-format-encrypt-ignored-on-adopt.md) | documented footgun (data-safety; silent) | `Format=`/`Encrypt=` silently ignored on an adopted existing partition | the target disk already has a partition matching the def's `Type=` |
| [02](issues/02-empty-name-overwritten-to-label.md) | working-as-designed-but-surprising | an existing partition's empty GPT name is overwritten with `Label=` | repart adopts an unnamed existing partition |
| [03](issues/03-no-delete-or-replace.md) | working-as-designed (documented gap) | no delete/replace: a matched partition is never reformatted | you re-run with a changed `Format=` to re-provision |
| [04](issues/04-empty-refuse-blank-disk.md) | doc-clarity | default `--empty=refuse` refuses a blank (no-GPT) disk, exit 77 | you point repart at a fresh disk with no partition table |

## Run the reproductions

Needs real root and loop devices (`losetup`, `mount`, `mkfs.ext4`,
`systemd-repart`). Run in a disposable VM, never on a host you care about.

```
sudo bash repro/run-all.sh
```

Each reproduction prints `RESULT: PASS` when the behavior reproduces as
documented; `run-all.sh` writes per-issue evidence logs under `repro/results/`
and exits non-zero if any reproduction fails. Individual scripts can also be run
directly, e.g. `sudo bash repro/01-format-encrypt-ignored-on-adopt.sh`.

The committed `repro/results/` logs are the captured output of a real run on the
systemd version above.

## Classification vocabulary

- **documented footgun** -- behavior is documented, but dangerous and silent
  enough that it deserves a louder warning (issue 01).
- **doc-gap / doc-clarity** -- behavior is defensible but easy to get wrong from
  the docs.
- **working-as-designed-but-surprising** -- intended, documented behavior that
  still surprises, listed for the record.

## Provenance

Found and **empirically confirmed** while building a live-USB persistence
provisioner on Kicksecure / Debian trixie, 2026-10, in an AI-assisted pass. Each
report is reproduced on a loop device at the exact systemd version recorded
above, and checked against the systemd man pages and github.com/systemd/systemd
issues. This repository is the record; it does not file upstream.

AI-Assisted.

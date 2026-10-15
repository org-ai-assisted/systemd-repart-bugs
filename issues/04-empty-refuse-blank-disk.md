# 04 - Default `--empty=refuse` refuses a blank (no partition table) disk

- Classification: **doc-clarity** (documented default; a common first-run
  stumbling block).
- Reproduction: [`../repro/04-empty-refuse-blank-disk.sh`](../repro/04-empty-refuse-blank-disk.sh)

## Environment

```
systemd 257 (257.13-1~deb13u1)
Debian GNU/Linux 13 (trixie)
```

## What happens

systemd-repart defaults to `--empty=refuse`. On a disk that has **no** GPT
partition table, that default makes repart refuse to do anything: it exits `77`
with `Disk /dev/... has no GPT disk label, not repartitioning.`

To initialize a truly blank existing disk you must pass `--empty=allow`, which
"extend[s] an existing partition table or create[s] a new one if none exists"
(`systemd-repart(8)`) -- it does not disturb any partitions already present.
This surprises anyone coming from `sfdisk`/`sgdisk`, which happily write a fresh
table onto a blank disk by default. This reproduction only exercises
`--empty=allow`.

Note the other modes are **not** interchangeable with `allow`:

- `--empty=create` creates a backing image **file** that does not yet exist; on
  an existing blank block device it fails with `File exists`.
- `--empty=force` writes a fresh partition table **unconditionally, erasing the
  disk fully** -- "no existing partitions will be taken into account or survive
  the operation. Hence: use with care, this is a great way to lose all your
  data" (`systemd-repart(8)`). It is for a deliberate full wipe, never a drop-in
  for `allow` on a disk that may already hold partitions.

### Observed (from `repro/results/04-...log`)

```
== run with DEFAULT --empty=refuse on a blank (no-GPT) disk ==
Disk /dev/loop0 has no GPT disk label, not repartitioning.
== run with --empty=allow on the same blank disk ==
...
Adding new partition 0 to partition table.
...
All done.
== observed ==
default --empty=refuse exit: 77 (expected 77)
refuse message mentioned no-GPT: yes
empty=allow exit: 0, partition name: data
```

## Observed vs expected

- Observed: default run on a blank disk exits `77` and does nothing;
  `--empty=allow` is required to initialize it.
- Expectation gap: a first-time user pointing repart at a fresh disk expects it
  to create the table, as other partitioning tools do.

## Notes

The exit `77` is deliberate: the shipped `systemd-repart.service` unit lists it
in `SuccessExitStatus`, so the "no GPT disk label" refusal is treated as success
by the unit. Reported here as a doc-clarity / UX note, not a systemd bug.

## Upstream search

Documented, working-as-designed; **no existing bug report found** on
github.com/systemd/systemd.

- `systemd-repart(8)` **--empty=**: accepts `refuse`, `allow`, `require`,
  `force`, `create`; "If this switch is not specified, the implied default is
  refuse." With `refuse` it "requires that the block device ... already carries a
  partition table and refuses operation if none is found."
  - https://manpages.debian.org/testing/systemd/systemd-repart.8
- `units/systemd-repart.service.in` lists `77` in `SuccessExitStatus` (the "no
  GPT disk label" case).
  - https://github.com/systemd/systemd/blob/main/units/systemd-repart.service.in

# 03 - No delete / replace semantics: a matched partition is never reformatted

- Classification: **working-as-designed (documented gap)** -- repart is
  declarative and incremental by design; the gap bites imperative provisioning.
- Reproduction: [`../repro/03-no-delete-or-replace.sh`](../repro/03-no-delete-or-replace.sh)

## Environment

```
systemd 257 (257.13-1~deb13u1)
Debian GNU/Linux 13 (trixie)
```

## What happens

systemd-repart never deletes or reformats a partition it matched. Once a
partition exists and matches a definition by `Type=`:

- a `Format=` that differs from the on-disk filesystem is ignored (same root
  cause as [issue 01](01-format-encrypt-ignored-on-adopt.md)), and
- a repeated run with no structural change is a no-op: repart prints
  `No changes.` and exits `0`.

There is no `--force`-style option to make repart replace or reformat an existing
partition. To re-provision a partition you must delete it yourself first (e.g.
`sgdisk --delete`), then let repart recreate it.

### Definition used

```ini
[Partition]
Type=linux-generic
Label=data
Format=vfat
```

(run against a disk whose existing matching partition is already `ext4`)

### Observed (from `repro/results/03-...log`)

```
== run 1: adopt existing ext4 partition, def asks Format=vfat ==
...
All done.
exit=0 fstype=ext4
== run 2: identical def, nothing to change ==
...
No changes.
== observed ==
fstype after run1: ext4 (def wanted vfat)
fstype after run2: ext4
run2 said "No changes.": yes
```

## Observed vs expected

- Observed: the partition stays `ext4` even though the definition asks for
  `vfat`; the second run reports `No changes.`.
- An operator used to `sfdisk`/`sgdisk` imperative tools might expect a way to
  force repart to bring the partition to the declared state (reformat to vfat).

## Notes

This is intended behavior -- repart converges a disk toward a declarative target
and only formats partitions it creates. It is listed here because it is a real
gap for imperative, re-run-to-reset provisioning, and because combined with
issue 01 it means "change the definition and re-run" silently does nothing to an
already-adopted partition.

## Upstream search

Documented, working-as-designed; **no existing bug report found** on
github.com/systemd/systemd requesting a general delete/replace/reformat verb.

- `systemd-repart(8)`: repart "(mostly) operates in a purely incremental mode: it
  only grows existing and adds new partitions; it does not shrink, delete or move
  existing partitions."
  - https://manpages.debian.org/testing/systemd/systemd-repart.8
- The only sanctioned deletion path is factory reset: partitions marked
  `FactoryReset=yes` are erased and recreated on a factory-reset boot. This is a
  narrow, opt-in mechanism, not a general reformat verb.
  - https://github.com/systemd/systemd/blob/main/docs/FACTORY_RESET.md
  - `repart.d(5)` **FactoryReset=**:
    https://manpages.debian.org/testing/systemd/repart.d.5

# 01 - `Format=` / `Encrypt=` silently ignored on an adopted existing partition

- Classification: **documented footgun (data-safety; silent)** -- the behavior
  is documented in `repart.d(5)`, but repart gives no warning that it skipped the
  requested format/encrypt on an adopted partition, and exits 0. That silence,
  on an option whose whole point is security, is the dangerous part.
- Reproduction: [`../repro/01-format-encrypt-ignored-on-adopt.sh`](../repro/01-format-encrypt-ignored-on-adopt.sh)

## Environment

```
systemd 257 (257.13-1~deb13u1)   # systemctl --version
systemd 257 (257.13-1~deb13u1)   # systemd-repart --version
Debian GNU/Linux 13 (trixie)
```

## What happens

systemd-repart matches a partition definition to an existing GPT partition by
`Type=`. Once a definition is matched to an existing partition, repart only
**grows** and **relabels** that partition. `Format=` and `Encrypt=` have **no
effect** on a partition repart did not create itself.

So pointing repart at a disk whose existing partition matches the definition's
`Type=`, with a definition that asks for `Format=ext4` and `Encrypt=key-file`,
leaves the partition:

- **renamed** to the definition's `Label=`,
- **grown** to fill the free space,
- but **NOT reformatted** (its old filesystem and data are untouched),
- and **NOT encrypted** (no LUKS header is written),

while repart prints `All done.` and exits `0`.

### Definition used

```ini
[Partition]
Type=linux-generic
Label=persistence
Format=ext4
Encrypt=key-file
```

### Observed (from `repro/results/01-...log`)

```
Applying changes to /dev/loop0.
Growing existing partition 0.
Setting partition label of existing partition 0.
Writing new partition table.
Telling kernel to reread partition table.
All done.
repart exit code: 0
== observed ==
name:     persistence
fstype:   ext4
sectors:  40960 -> 260056
sentinel: yes
```

The partition was grown (`40960 -> 260056` sectors) and renamed (`persistence`),
but `fstype` is still plain `ext4` (not `crypto_LUKS`), and the pre-existing
`SENTINEL` file (`STALE-SECRET-DATA`) is still present.

## Observed vs expected

| | Observed | A caller would expect |
|---|---|---|
| Filesystem | old ext4, untouched | fresh `Format=ext4` |
| Encryption | none (plaintext) | LUKS (`Encrypt=key-file`) |
| Old data | survives | wiped by the reformat |
| Exit / output | `0`, `All done.`, silent | at least a warning that format/encrypt was skipped |

## Why it is a footgun

A provisioning script that hands repart a definition with `Encrypt=key-file`
reasonably assumes the resulting partition is encrypted. On a disk that already
carries a matching partition (a re-provisioned USB stick, a recycled disk), the
"encrypted persistence" partition is in fact plaintext, and whatever data was
there before is still readable. repart gives no indication that the encrypt/
format step was skipped.

## Upstream search

Documented, working-as-designed; **no existing bug report found** on
github.com/systemd/systemd.

- `repart.d(5)` states it verbatim for both options:
  - **Format=**: "... This option has no effect if the partition already exists."
  - **Encrypt=**: "... This option has no effect if the partition already exists."
  - https://manpages.debian.org/testing/systemd/repart.d.5
- `systemd-repart(8)`: repart "only grows existing and adds new partitions; it
  does not shrink, delete or move existing partitions", and by default "does not
  create or resize any file systems within these partitions, unless the Format=
  configuration option is specified."
  - https://manpages.debian.org/testing/systemd/systemd-repart.8

Related but NOT the same report:

- systemd#37892 (closed) -- expose `--key-file`/`--tpm2-*` to the
  `systemd-repart.service` unit; not about adoption leaving data plaintext.
  https://github.com/systemd/systemd/issues/37892
- systemd#33863 -- a different disk-label safety footgun (label wiped on an
  invalid `--definitions` path). https://github.com/systemd/systemd/issues/33863

The behavior is documented, so this is not an undocumented bug; the reportable
gap is the **silent success** -- no warning that `Format=`/`Encrypt=` was skipped
on an adopted partition. The human decides whether to raise that upstream.

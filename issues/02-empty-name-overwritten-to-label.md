# 02 - An existing partition's empty GPT name is overwritten with `Label=`

- Classification: **working-as-designed-but-surprising** (documented; side effect
  of adoption, closely related to
  [issue 01](01-format-encrypt-ignored-on-adopt.md)).
- Reproduction: [`../repro/02-empty-name-overwritten-to-label.sh`](../repro/02-empty-name-overwritten-to-label.sh)

## Environment

```
systemd 257 (257.13-1~deb13u1)
Debian GNU/Linux 13 (trixie)
```

## What happens

When repart adopts an existing partition (matched by `Type=`), it sets that
partition's GPT name to the definition's `Label=`, provided the partition has no
name yet. A partition that was deliberately left **unnamed** (empty GPT name)
comes back named after whichever definition happened to match it by type. (A
partition that already has a non-empty name is left alone.)

### Definition used

```ini
[Partition]
Type=linux-generic
Label=adopted-by-repart
```

### Observed (from `repro/results/02-...log`)

```
Growing existing partition 0.
Setting partition label of existing partition 0.
...
All done.
repart exit code: 0
== observed ==
name: [] -> [adopted-by-repart]
```

## Observed vs expected

- Observed: the empty name is replaced by `adopted-by-repart`.
- A caller might expect repart to leave an existing partition's name alone, since
  the partition is matched by `Type=`, not by name.

## Notes

This is the relabel half of the adoption behavior in issue 01 and is benign on
its own, but it is surprising: a single stray definition file whose `Type=`
matches can rename an unrelated, unnamed partition on the target disk.

## Upstream search

Documented, working-as-designed; **no existing bug report found** on
github.com/systemd/systemd.

- `repart.d(5)` **Label=**: "The textual label to assign to the partition if none
  is assigned yet. Note that this setting is not used for matching. It is also
  not used when a label is already set for an existing partition. It is thus only
  used when a partition is newly created or when an existing one had a no label
  set (that is: an empty label)."
  - https://manpages.debian.org/testing/systemd/repart.d.5
- `systemd-repart(8)` restates it: "all existing partitions for which
  configuration files exist and which currently have no GPT partition label set
  will be assigned a label."
  - https://manpages.debian.org/testing/systemd/systemd-repart.8

---
description: Use when changing a live schema or moving data in a running system -- apply expand/contract (parallel change) so old and new shapes coexist, backfill in resumable batches, verify integrity, and switch reads only after the new shape is proven.
---

# Data migration

A schema change or data migration against a live system is production-outage
grade work. One blocking `ALTER` on a hot table, one unbounded `UPDATE`, one
rename that ships ahead of the code that reads it -- any of these stalls or
corrupts a running service, and the blast radius is every request in flight.
Treat every such change as high-stakes and irreversible until proven otherwise.

The governing move is to never make a breaking change in one step. Split it into
a sequence of small, individually deployable, individually reversible steps
where old code and new code coexist at every point. That sequence is
**expand / contract** (parallel change).

## When to use / When not to

- **Use** for any change to a live store's shape or contents: adding, renaming,
  splitting, or dropping a column/table/field; changing a type or constraint;
  re-keying; backfilling or transforming existing rows; moving data between
  stores.
- **Do not use** for a fresh table or store nothing reads yet (no coexistence
  problem), or for a change fully gated behind a migration window with the
  system offline and a tested restore path. Even then, keep the batching and
  integrity checks below.

## Why this is a T3-floor task

A data migration is one of the named triggers that forces the T3 verification
floor in `/sutra:effort-calibration`, no matter how small the diff looks. A
one-line `DROP COLUMN` is still T3: the stakes, not the line count, set the
floor. Bring the full floor -- a rehearsed rollback, an independent reviewer,
and a gate that re-runs the integrity checks -- and cut breadth elsewhere if you
need to save energy. This work also sits under the strict-profile safety
guardrails: never run a destructive command on a hunch, confirm the target, and
prefer the reversible path.

## The four phases

Each phase is a separate, deployable, reversible step. Ship it, watch it settle,
then start the next. Never collapse two phases into one deploy.

### 1. Expand -- add the new shape additively

Introduce the new column/table/field alongside the old one. Add only; change
nothing existing. Old code keeps reading and writing the old shape and does not
know the new shape exists. A new nullable column with no default is the cheapest
expand -- it does not rewrite existing rows. This step is safe to roll back by
dropping the thing you just added, because nothing depends on it yet.

### 2. Migrate -- dual-write, then backfill

Deploy code that writes **both** shapes on every create and update, so new and
changed rows carry correct data in the new shape from now on. Only then backfill
the historical rows that predate dual-write (see rule 2). Dual-write first,
backfill second -- reversing the order leaves a gap where fresh writes land only
in the old shape and the backfill misses them.

### 3. Switch -- move reads to the new shape

Once the backfill is complete and integrity-verified (rule 6), deploy code that
**reads** from the new shape. Keep dual-writing during and after this deploy:
until every reader is confirmed on the new shape, a rollback must still find the
old shape populated. Move reads behind a flag if you want a fast, reversible
cutover.

### 4. Contract -- remove the old shape

Only after nothing reads the old shape -- confirmed, not assumed -- stop writing
it and drop it. This is the one irreversible step; it lands last, on its own, in
a separate deploy from the switch, with the switch already proven stable.

## Rules

1. **Backward-compatible steps only.** Old and new code must coexist through the
   whole rollout; any single step must be safe with the previous version still
   running. Decouple the deploy from the migration -- a migration is its own
   gated, explicitly triggered step, never a silent on-boot side effect that
   fires whenever a process starts.
2. **Backfills are batched, throttled, resumable, and idempotent.** Never one
   giant locking `UPDATE`. Walk the table in bounded batches (by primary-key
   range or a cursor), pause between batches to spare the store, checkpoint
   progress so an interrupted run resumes instead of restarting, and write the
   backfill so re-running a batch is a no-op. A backfill you cannot safely
   re-run is a backfill you cannot trust.
3. **No blocking DDL in the hot path.** Know your store's locking behavior
   before you run the statement. Prefer online/concurrent variants (add the
   index concurrently, add the column without a table rewrite). A schema change
   must not take a long lock on a busy table -- validate the lock cost on a
   copy first.
4. **Reversible or forward-fixable, rehearsed before you run it.** Have the
   rollback (or the roll-forward fix) written and tested on a staging copy
   *before* touching production. "We will figure out the rollback if it breaks"
   is not a plan.
5. **Hold the dual-write window open.** Keep writing both shapes until every
   reader has moved to the new shape and been verified there. Close the window
   only in the contract phase.
6. **Verify integrity after backfill, before switching reads.** Compare row
   counts old vs new, checksum or hash the migrated values, and spot-check a
   sample by hand. Reconcile every mismatch before any read moves. Switching
   reads onto an unverified backfill is how silent data loss ships.

## Anti-patterns -- name them and stop

- **Rename-in-place.** `ALTER ... RENAME COLUMN` in one deploy. The instant it
  lands, every running instance on the old name breaks. Expand/contract instead.
- **Drop-then-add.** Removing the old shape and adding the new in the same
  change. There is no coexistence window and no rollback that preserves data.
- **Unbounded backfill.** One `UPDATE users SET ...` across the whole table. It
  takes a long lock, blocks live traffic, and cannot resume if it dies halfway.
- **Blocking DDL on a hot table.** A schema statement that locks a table serving
  live reads/writes. Measure the lock first; use the concurrent variant.
- **Dropping the old column before reads moved.** Contracting while a reader --
  including a rolled-back instance or a lagging consumer -- still needs the old
  shape. Confirm zero readers first.
- **Migration as an on-boot side effect.** Running the schema change silently
  when a process starts, so a deploy or an autoscale event fires it
  unannounced. Make it an explicit, gated step (rule 1).

## Worked example (neutral)

Splitting `users.full_name` into `first_name` and `last_name`:

1. **Expand** -- add nullable `first_name`, `last_name`; ship it; nothing reads
   them.
2. **Migrate** -- deploy code that populates all three columns on every write;
   then backfill old rows in 5,000-row batches keyed by id, checkpointing the
   last id and skipping rows already split (idempotent).
3. **Verify** -- count rows where the split columns are null but `full_name` is
   not (expect zero); checksum a sample re-joined against `full_name`.
4. **Switch** -- deploy code that reads `first_name`/`last_name`; keep writing
   `full_name`.
5. **Contract** -- once no reader touches `full_name`, stop writing it, then drop
   it in a final deploy.

Each numbered step is a separate deploy with its own rollback.

## Checklist

- [ ] Classified as T3; rehearsed rollback and independent review are in place
      (`/sutra:effort-calibration`).
- [ ] Change is split into expand / migrate / switch / contract, each a separate
      reversible deploy -- no phase collapsed into another.
- [ ] Every step is backward compatible with the previous running version.
- [ ] Migration is an explicit gated step, not an on-boot side effect.
- [ ] Backfill is batched, throttled, resumable, and idempotent -- no unbounded
      locking `UPDATE`.
- [ ] Schema DDL uses online/concurrent variants; lock cost measured on a copy.
- [ ] Dual-write is live before backfill and stays open until all reads moved.
- [ ] Integrity verified after backfill (counts, checksums, spot-checks); every
      mismatch reconciled before reads switched.
- [ ] Old shape dropped only after zero readers confirmed.
- [ ] Migration logic and rollback are covered by tests
      (`/sutra:test-authoring`); if something goes wrong live, contain first via
      `/sutra:debugging`.

# Annual segment filesystem publication: process-kill probe

Date: 2026-10-15
Status: **research only, disposable filesystem prototype**
Related: [Issue #1969](https://github.com/shumoku88-bit/loam/issues/1969), merged #2010 (bounded TLA+ committed-head model).

## Objective

Bridge a narrow part of the gap between the abstract TLA+ requirement
*segment durable before committed head* and actual filesystem operations.
The tested prototype deliberately uses **Python and synthetic opaque
source pairs**, not native LOAM Actual/Scheduled codecs or a replacement
for the current `HouseholdAuthority`.

The ordinary application should still keep one logical household, with
one current published head, immutable prior-year segments, automatic
year rollover when the next normal write occurs, no user annual/daily
confirmation, and no always-running reader daemon.

## Candidate write order

Under an exclusive `fcntl.flock` ownership file:

1. Validate the currently published `HEAD`, its SHA-256-selected
   manifest and **all** head-referenced content-addressed segments.
2. Compare the caller's observed head to the actual current head.
   Reject stale publication attempts; if the stable operation ID is
   already committed, a retry is a no-op.
3. Stage a complete new synthetic annual segment. Write to a sibling
   temporary file, `fsync` file, hard-link into its immutable SHA-256
   content address, and synchronize its containing directory.
   A linked destination is never overwritten.
4. Build a new immutable manifest naming both the old and the new
   segment, repeat stage/fsync/link/directory synchronization.
5. Write `HEAD` temporary file, `fsync`, and atomically
   `os.replace` the old `HEAD`, then synchronize the root directory.
   This is the **single publication point** in the process-kill test.
6. Qualify the now-published head again. Unreferenced staged/orphan
   blobs are not input to any read. A repeated logical operation
   never creates a second accepted publication.

A content hash is **integrity evidence relative to a trusted selected
head**, not evidence against malicious rollback of that head itself.

## Reproduce

On Linux with Python 3 and `fcntl`:

```bash
python3 tools/research-annual-fs-killpoints.py --check
```

The command creates and destroys **only its own temporary directories**.
The test harness starts an actual child process and terminates it with
`SIGKILL` at each of these points:

- Before the next segment file
- After writing/fsyncing its stage file, before final hard-link
- After the segment is safely named and its directory synchronized
- After the manifest is likewise named/synchronized
- Before replacing the authoritative head
- After replacing the head, before synchronizing its directory
- After synchronizing the head directory

After every forced process death, a fresh reader must see an entirely
old or entirely new manifest and **all referenced shard data**.
A normal retry then commits *exactly once* or returns an already
committed operation, without duplicating its original source pair.

Additional negative/integration probes:

- Two concurrent writer processes that saw one old head are serialized:
  one accepted, one rejected as stale.
- Missing newer referenced annual segment: refusal, not a silent
  substitute or an old/zero-valued household answer.
- Modified older sealed segment: refusal.
- Modified selected manifest: refusal.
- Idle year with no normal write: no new file or head.
- **Critical negative limitation:** replacing a new `HEAD` with an
  older *valid* `HEAD` causes an old but internally consistent view.
  The prototype **cannot detect a deliberate valid rollback** without
  an independent trusted monotonic reference or stronger retained
  generation/restore semantics. This is explicitly asserted as a
  limitation rather than a passed safety property.

## Important limitations

This experiment is **NOT** a crash-consistency proof for LOAM.

- `SIGKILL` is a real process death but **not** sudden loss of power
  or durable-storage cache loss. The post-`os.replace` pre-directory-
  fsync case can appear committed under a process kill but need not
  survive a sudden machine shutdown. The test has no block fault
  injection, actual ENOSPC, torn write or filesystem-specific sync
  semantics proof.
- The synthetic segment carries a toy pair of Actual/Scheduled-labelled
  identifiers. It is **not** admitted through LOAM's actual typed
  encoders, completion terminal graph or ledger policies. The real
  source correctness obligations from #2008 remain separate.
- The manifest is a single immutable list in this prototype. A
  production solution may need bounded indexing/compaction and
  version retention that avoids copying an entire twenty-year manifest
  on every write.
- `flock` provides the experiment's mutual exclusion on one local
  Linux filesystem only. This is not a claim about NFS, Windows,
  exotic Mac filesystem behavior, lock identity across migrations,
  or concurrent LOAM writers.
- Only reader-visible complete generation selection is tested;
  a missing or corrupt current `HEAD` and the trust/rollback
  question need a separately qualified recovery strategy before
  any user data can migrate.
- A future native prototype must cover actual source identity,
  Scheduled completion endpoints, Current Quantity/Zero Origin support,
  policy versions and historical learned-time admission, not
  replace them with cached numeric Daily Pace snapshots.
- The existing household remains untouched. Do not run real file
  migration or replace current production `HouseholdImage` based
  only on this result.

## Decision after passing

The **one trusted head + immutable content-addressed segments**
candidate is concrete enough for a second gate: disposable
**native Lean integration** (same-generation Actual+Scheduled),
explicit partial restore, and compiled benchmark against current
single HouseholdImage at 1, 5, 10 and 20 years.

**Stop-rule:** resolve acceptable detectability of old valid head
rollback and power-loss durability semantics before promoting any
segmented layout to the canonical storage authority.

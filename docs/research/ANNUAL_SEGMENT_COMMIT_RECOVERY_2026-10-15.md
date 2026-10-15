# Annual immutable segments: atomic-head commit and recovery obligations

Date: 2026-10-15
Status: **bounded executable research, NOT a production filesystem guarantee**
Tracking: storage [Issue #1969](https://github.com/shumoku88-bit/loam/issues/1969)
Previous qualification: #2007 synthetic lazy-year reader, #2008 native
Actual/Scheduled reference closure, #2009 hypothetical externally pinned
annual segment index.

## Goal

A household remains **logically one authority**, even when older source
evidence is physically separated into immutable yearly segments.

The current `HouseholdAuthority.publishObserved?` validates a whole
HouseholdImage and then exposes one generation. A split format cannot
replace this with **independently current year files**: between writes
there would be no consistent answer to a late correction, completion,
FX, Scheduled or Daily Pace question.

The proposed publication topology has **one visible head selector**:

```text
head (one qualified/atomically selected authority generation)
  -> manifest of exact immutable segment identities, content hashes,
     source/terminal relation closure and learned-time membership
  -> old sealed segment(s) + current committed segment
  -> optional derived rebuildable query index (not financial authority)
```

**Proposed ordering for ONE normal semantic write:**

1. Read and qualify the **current exact head** under writer ownership.
2. Construct the next immutable **segment candidate** in staging.
   This may contain more than one source family (e.g. a Scheduled
   completion and corresponding Actual) but must not split one
   accepted semantic transaction across independently visible heads.
3. Complete the segment, validate its typed source grammar, all
   relevant cross-segment dependency references and index closure,
   and persist the segment before it is referenced. Explicit durable
   ordering is an engineering requirement, **not proved** by the model.
4. Stage a manifest naming the immutable old+new segments (plus
   hashes, complete source coverage, and one new learned-time cut).
   Validate its references and the exact observed prior head.
5. **Publish the head reference as the sole atomic commit point**.
   A reader pins that exact head and loads the referenced versions.
6. Treat any precommit segment not referenced by the committed head
   as an orphan candidate, eligible for separately safe cleanup.
   Retry of a committed source operation is idempotent, not a second
   publication. Preserve the previous committed head/segments for
   explicit recovery.

There is no year-end closure operation. A transition from 2026 to
2027 with **no accepted write** does not create a canonical file, a
Daily Pace daily snapshot, a forced user confirmation or any daemon.
The next ordinary publication can create the next physical segment.

## Executable bounded model

`tla/AnnualSegmentCommitRecovery.tla` abstracts:

- an immutable old segment and one new staged segment;
- year advance, ordinary publication, partial stage, completion,
  qualification, durable segment admission, and last-step atomic
  published head;
- observation solely via the selected committed head;
- crash before or after commit, restart, already-committed retry,
  and explicit refusal of unqualified restore;
- one committed chronology counter and preservation of old evidence.

**Positive TLC obligations:** the published head always references
the durable segment set, the sealed old segment is never modified,
head agrees with committed chronology, no observation of a partial
head, no second commit on retry, no annual calendar-only writes and
no implicit backwards head selection.

**Negative TLC controls (must produce actual counterexamples):**

| Deliberately unsafe strategy | Expected violation |
|---|---|
| Move manifest/head first, write segment later | Published head references missing evidence |
| Edit sealed old year in place for a correction | Old immutable evidence altered |
| Restore a manifest without the newer referenced segment | Committed head references missing evidence |
| Silently rewind head after successful publication | Accepted chronology and visible head diverge |
| Claim year can never advance without write | Counterexample: inactive year rollover |
| Claim a crash prevents all later publication | Counterexample: restart and successful normal retry |

The last two are expected **reachability witnesses**, not production
safety requirements. The first four are expected negative safety
counterexamples. Passing a negative configuration means TLC **found**
the deliberately exposed error.

### Existing LOAM evidence reused

- `tla/CompleteImagePublication.tla`: complete staging before a
  single authority switch.
- `tla/DailyPaceAutomaticKnowledge.tla`: one semantic source change
  and learned-day membership per admitted generation; no idle day
  record and no duplicate retry knowledge.
- `tools/NativeAnnualReadProbe.lean`: cross-year Actual correction
  identities and *real* Scheduled false reopen when the completion
  Actual is omitted from a pruned Event set.
- `tools/research-annual-index-closure.py`: bounded read selection
  from a hypothetical independently pinned complete manifest.

## Limits: do not confuse TLC success with crash-safe filesystem IO

The model assumes that *durable segment admission* really means
durable bytes and verified hashes, and that the final head transition
is atomic and durably ordered with those bytes. It **does not**
verify Lean codecs, POSIX directory fsync/rename semantics, sudden
power loss, disk-full, Git restoration or a real multi-file writer.

It models only one annual rollover and one semantic publication,
not concurrent multi-writer CAS, 20 years of compaction, multiple
physical restore generations, snapshot migration, same-day policy
winning order or historical Current Quantity anchors. Those remain
separate **implementation gates**.

In particular:

- A single file's current `household.loam.prev` is **not** a general
  multi-segment archival backup.
- A stored hash in an unqualified manifest is not an authority. The
  manifest/head selection needs an independently qualified exact
  generation and its own durable rollback/refusal story.
- Crash before published head may leave an orphan segment; it is not
  permission to select it at startup merely because the file exists.
- A corrupt/missing head-referenced segment means **unavailable**,
  never zero, never an earlier apparently valid balance or a
  newly reopened Scheduled obligation.
- Old years should not be mutated by backdated or corrected Events;
  the new observation belongs in the year **it became known**, with
  source references across segments.
- Published index claims must not silently drop dependency edges
  or financial coverage, and an index must remain derived/rebuildable.
- Full-range balance/Daily Pace queries still require qualified
  historical support/policy and completeness, or the conservative
  relevant prefix. The model does not create these facts.

## Decision and next practical gate

**Candidate protocol:** immutable content-addressed segments +
one committed manifest/head, and a callable on-demand reading module.
This is a **hypothesis to test**, not migration approval.

Before implementing year files, build a disposable native Lean
prototype of *one publication/one crash* with named stage files,
documented file and directory synchronization, refusal after partial
restore, stale-writer rejection, and source-ID closure from
qualified Actual/Scheduled. Test kill points, no-op rollover,
restart, and the ability to preserve old generations. Then
compare compiled native read/write/RSS/write-amplification across
current single HouseholdImage versus 1-/5-/10-year split and
sealed history plus active writer.

**No production canonical format, `loam-data`, Daily Pace logic,
TUI or user-confirmation procedure is changed in this research.**

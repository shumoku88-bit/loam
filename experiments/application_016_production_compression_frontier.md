# Application 016: Production compression frontier

## Pressure

LOAM's semantic core is still comparatively small, but the practical runtime has
accumulated enough CLI and orchestration code that code volume itself is now a
useful pressure source.

The question is not simply:

```text
can repeated code be made shorter?
```

It is:

```text
which repeated production mechanics can be shared or deleted
without hiding or merging semantic authority?
```

This observation is based on `main` at:

```text
3491a1511ed8b069d8638e76a74ebbb9fbc594e5
```

No household data is required. No production behavior is changed here.

## Snapshot

Git tree object sizes show that the practical runtime is no longer uniformly
small. The rough production-facing split, excluding historical Observation/Test
sources and formal-model directories, is:

```text
Core                  about 132 KiB
Application           about  90 KiB
Persistence           about  72 KiB
CLI                   about 301 KiB
other runtime/support about 103 KiB
```

The precise byte totals are less important than the shape: `Core + Application`
remains much smaller than the terminal/runtime shell around it, and CLI is the
largest single practical layer.

That makes the CLI a reasonable compression target, but not evidence that the
Core ontology should be compressed further.

## Exact mechanical duplication already present

### Line input

Thirteen modules currently carry the same private interactive helper shape:

```lean
private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString
```

The copies occur across date, Movement, Capacity, Scheduled, correction, and
completion entrances. `ReviewCli` has one closely related fixed-prompt variant.
Its fixed prompt and full ASCII trimming are deliberately not counted as an
identical copy.

This helper carries terminal mechanics, not household meaning. Sharing it would
not merge Event, Scheduled, Capacity, correction, or relation authority.

**Classification: A — pure mechanical duplication.**

A later refactor may share or otherwise delete these copies directly. No generic
CLI framework is earned by this fact alone.

### List selection

The same private recursive `getAt?` helper appears in three correction-oriented
CLI modules.

It only selects the nth element of an already-built list. The semantic decision
about which candidates belong in that list has already happened elsewhere.

**Classification: A — pure mechanical duplication.**

Prefer deletion in favor of an existing suitable library operation if one fits;
otherwise one tiny shared helper is enough. Do not generalize candidate
selection policy along with it.

### Optional EventDescription input

`MovementCli` and `ScheduledCli` contain the same `practicalDescription` body:

```text
LOAM_DESCRIPTION environment value when present
otherwise prompt only on an interactive stdin/stdout pair
empty text means no description
redirected input without the environment value means no description
```

Both paths are collecting the same retained `EventDescription` meaning for a
new Actual Event. One originates from ordinary Movement recording and the other
from Scheduled completion, but the description-input policy itself is not a new
semantic authority.

**Classification: C — same meaning and same mechanics.**

This is a stronger extraction candidate than a generic prompt library: the
shared unit may retain its EventDescription-specific name and contract.

## Repetition that should not automatically become an abstraction

### Missing file interpreted as empty evidence

`ScheduledCli`, `OpenScheduledCli`, and `ScheduledBalanceCli` each currently
contain the same local helpers for:

```text
loadScheduledMemoryOrEmpty?
loadEventMemoryOrEmpty?
```

There are similar local pairs such as `loadCorrectionMemoryOrEmpty?` elsewhere.

The implementation shape is tiny and repeated, but the important part is not
file I/O. It is the claim that *absence of this file at this particular caller*
means *no evidence yet* rather than *a missing required authority*.

Publishing a broad persistence helper merely because the code is identical can
make that caller policy look globally canonical. Some LOAM paths correctly fail
when a canonical file is absent.

**Classification: B — same mechanics with evidence-policy meaning.**

Keep these local unless a shared operation makes the missing-evidence contract
explicit at each call site. Fewer lines are not worth weakening the distinction
between optional evidence and required authority.

### `historyMentionsEvent`

The same small Actual-validity-history membership predicate appears in multiple
writer paths. The predicate itself is pure and shareable, but its callers use it
inside distinct fresh-identity reservation rules.

**Classification: B — shareable predicate inside different authority rules.**

If extracted later, extract only the predicate. Do not turn the surrounding
Event-id allocation policies into one generic allocator without a separate
semantic observation.

## The large shapes are not yet duplication evidence

Several writers have a broad family resemblance:

```text
load retained evidence
-> validate / admit
-> allocate fresh identities
-> publish related evidence
-> publish the activating Event at the required boundary
```

That resemblance is not enough to justify a generic writer pipeline.

Publication order, activation, recovery, identity reservation, correction
frontiers, and optional sibling streams differ because they preserve different
household evidence. Recent relation/discharge work in particular depends on
specific Event-last activation rules. Hiding those rules behind a parameterized
framework would shorten source while making semantic authority harder to read.

**Classification: B/C boundary — same outer shape, different semantic protocol.**

No generic writer, loader, repository, command, or CRUD framework is earned by
this observation.

## Compression rule produced by the observation

The practical code now supports a three-way rule:

```text
A. pure mechanics
   share or delete directly

B. repeated shape carrying caller evidence policy
   keep local unless the policy remains explicit after sharing

C. same household meaning plus same mechanics
   extract the narrow meaning-specific unit
```

A fourth negative rule follows:

```text
same control-flow silhouette != same semantic operation
```

This is the production-code counterpart of LOAM's standing rule to share
mechanics without erasing meaning.

## Second-pass result: safe duplication is not the main source of size

The first obvious compression candidates are real, but they are small compared
with the current runtime shell.

Measured directly from the repeated source bodies on the fixed snapshot:

```text
13 promptLine bodies        about 2.6 KiB total
2 description-input bodies  about 0.9 KiB total
3 getAt? bodies              about 0.5 KiB total
```

If each family were reduced to one implementation, or the list selector were
deleted in favor of a suitable standard operation, the theoretical raw-source
saving is only about 3.3 KiB before adding imports, names, and the shared module
itself. Against roughly 301 KiB of CLI source, that is around one percent at
most, and the actual net reduction would be smaller.

So the visible mechanical duplication is **not** the primary reason the runtime
has grown.

The larger source volume is mostly explicit behavior: admission, recovery,
identity reservation, interactive workflows, projections, and publication
protocols. Some of that may still be simplifiable, but a large reduction will
not come from helper extraction alone.

This changes the interpretation of the first refactor:

```text
small helper extraction
    = hygiene / boundary test
    != meaningful size reduction by itself
```

A substantial later reduction should therefore be earned by deleting obsolete
paths, deriving behavior from already-retained evidence, or discovering a
smaller semantic mechanism. A generic framework that merely compresses source
spelling would not satisfy the central compression rule.

## Smallest earned follow-up

If production compression is implemented next, keep the first slice deliberately
small:

1. remove the repeated line-input helper behind one tiny terminal-input
   operation;
2. share the duplicated EventDescription input policy under an
   EventDescription-specific name;
3. delete or share the three trivial list-index helpers without changing how
   candidate sets are formed.

Stop there and remeasure before touching loader policy or writer orchestration.

The purpose of that refactor is now sharper: it is a controlled test that LOAM
can become mechanically smaller while leaving semantic boundaries more visible,
not a claim that these helpers explain the current code volume.

## Qualification

No extra formal instrument is needed for this observation. The claim is a source
boundary classification, not a new structural or temporal household law.

Qualification consists of:

- exact-source comparison of repeated helpers on the fixed main snapshot;
- repository-tree size comparison to locate the current pressure;
- checking the proposed extraction boundary against `AGENTS.md` and
  `DESIGN_PHILOSOPHY.md`;
- making no production or persistence change in this PR.

A follow-up refactor should use existing practical build and CLI qualification
for every touched entrance and should add no new canonical fact or persistence
format.
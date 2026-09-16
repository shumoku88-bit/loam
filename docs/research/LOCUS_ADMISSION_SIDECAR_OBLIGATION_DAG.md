# G2-014 — Locus admission placement obligation DAG

Status: **Generation-2 audit evidence — SIMPLIFY QUALIFIED**

Primary instruments: **DRAKONview + reachability search + authority/persistence boundary inspection**.

## Question

Locus admission is current new-write policy, independent of historical Actual evidence.
Generation 2 asks whether any retained code still exposes the older EventMemory-sidecar
placement after production moved to the local `LocusAdmissionAuthority` boundary.

## Current production path

```text
HouseholdCommand / TUI administration
        |
        v
LocusAdmissionPublisher.publishAdmission
        |
        v
LocusAdmissionAuthority.updateCurrent?
        |
        +--> locusAdmissionPath(root)
        |      = root/locus-admission.loam
        |
        +--> writer ownership on canonical policy path
        |
        +--> loadCurrent?
        |      |
        |      v
        |   Persistence.loadLocusAdmissionVocabulary?(path)
        |
        +--> publisher-local propose?
        |      valid stable token
        |      not already admitted
        |      unique vocabulary
        |
        +--> Persistence.saveLocusAdmissionVocabulary?(path)
```

The physical placement decision belongs to `LocusAdmissionAuthority`. Persistence only
encodes or decodes the vocabulary at the path supplied by its caller.

## Historical residue

`LocusAdmissionPersistence` still retained:

```text
locusAdmissionVocabularyPathForEventMemory(memoryPath)
    = memoryPath ++ ".locus-admission"
```

Its own documentation identified it as a legacy sidecar writer surface.
Repository-wide symbol search found no caller other than the definition itself.

The helper therefore carried an obsolete physical topology:

```text
EventMemory path
     |
     v
append .locus-admission sibling suffix
```

That topology is no longer the production authority contract.

## Obligation decomposition

```text
O1  New-write Locus policy has one current physical authority owner.
    Owner: LocusAdmissionAuthority

O2  Production read/modify/write takes writer ownership on that canonical path.
    Owner: LocusAdmissionAuthority.updateCurrent?

O3  Persistence validates tokens, uniqueness and format at a supplied path.
    Owner: LocusAdmissionPersistence

O4  Historical EventMemory placement must not silently define current policy.
    Supported by the independent authority design and existing tests.

O5  A second path-construction API is justified only if a live caller needs the
    old EventMemory-sidecar topology.
```

Reachability falsifies O5: no live caller exists.

## Why the Authority boundary stays

This audit does **not** support folding the authority into the publisher or persistence.
The current split carries independent reasons:

- Publisher owns add-only policy proposal semantics and user diagnostics.
- Authority owns canonical placement, writer ownership, and read/modify/write protocol.
- Persistence owns text representation and fail-closed decode/encode.

Removing the authority would re-expose physical placement to callers. Moving add-only
semantics into persistence would mix policy with representation.

## Historical cross-check

The current design was earned in stages:

- #703 introduced a local Locus admission authority to hide physical placement.
- #756 normalized production Actual into `actual.loam` while keeping Locus admission as
  an independent policy authority.
- #757 retired remaining runtime legacy manifest/Actual vocabulary surfaces.

The sidecar path helper survived those topology changes without a caller.

## Production change

Delete only:

```text
Persistence.locusAdmissionVocabularyPathForEventMemory
```

Keep:

```text
LocusAdmissionAuthority.locusAdmissionPath
LocusAdmissionAuthority.loadCurrent?
LocusAdmissionAuthority.publishCurrent?
LocusAdmissionAuthority.updateCurrent?
Persistence encode/decode/load/save
LocusAdmissionPublisher.propose? / publishAdmission
```

No compatibility replacement is introduced because doing so would preserve the dead
physical-topology concept the audit is retiring.

## Qualification

Production/audit head `ce61aa2aa8c64a485a6c4444f1e739e5a924ffbf` qualified green:

- Compression Audit run `35049794948`: **SUCCESS**
  - production source inventory: SUCCESS
  - production import reachability: SUCCESS
  - semantic candidate vocabulary scan: SUCCESS
  - mechanics multiplication scan: SUCCESS
- Selected Lean Observations run `35049794894`: **SUCCESS**
  - selected live observation umbrella build: SUCCESS

No Production TUI workflow was triggered because the changed persistence file is outside
that workflow's PR path filter. No production execution path changed: the removed symbol
had no caller and the canonical Locus admission authority path is untouched.

Relevant existing integration evidence remains the Locus admission publisher test, which
pins add-only admission, duplicate and persistence-invalid token refusal, Actual evidence
isolation, and agreement between the selected Actual world and the current local policy.

## Final verdict

**G2-014: SIMPLIFY QUALIFIED — retire dead legacy sidecar path helper; KEEP local authority boundary.**

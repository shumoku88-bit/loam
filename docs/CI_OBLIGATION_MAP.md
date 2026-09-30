# CI Obligation Map

Status: item-2 repository tightening map after PR #1289.

This document is the human-readable map for LOAM's live CI obligations. The
machine inventory remains `python3 tools/audit-ci-topology`; use that command
when exact workflow counts, toolchains, triggers, permissions, or command lists
are needed.

## Compression ledger

The item-2 baseline had 97 workflow files. After retiring two graduated standalone Lean witnesses, the item-2 completion topology had 48. Retiring the native LOAM Web frontend later reduced the live topology to 47. A later product-CI consolidation folded the two Movement Proposal workflows into one file, reducing the live topology to 46. The three Scheduled publisher workflows were then grouped into one workflow with three independent jobs, reducing the live topology to 44. The Actual Routing persistence and writer workflows were next grouped into one workflow with separate jobs, reducing the live topology to 43. The Capacity publisher and practical entrance workflows were then grouped into one workflow with separate jobs, reducing the live topology to 42. The Event Merchant publisher and TUI input workflows were next grouped into one workflow with separate jobs, reducing the live topology to 41. The two runtime shadow workflows were then grouped into one workflow with separate redaction/projection and quantity jobs, reducing the live topology to 40. A final full-inventory pass found one remaining high-confidence grouping: Scheduled lifecycle persistence and the Scheduled publisher qualification surface, reducing the live topology to 39 while keeping four independent jobs.

The first 47 retired workflow files are accounted for by four explicit
consolidation families:

| Family | Before | After | Net | Surviving control surface |
| --- | ---: | ---: | ---: | --- |
| Alloy research witnesses | 24 | 1 | -23 | `alloy-research-witnesses.yml` |
| SPIN research witnesses | 6 | 1 | -5 | `spin-research-witnesses.yml` |
| TLA+ research witnesses | 16 | 1 | -15 | `tla-research-witnesses.yml` |
| Lean application qualifications | 5 | 1 | -4 | `lean-application-qualifications.yml` |
| **Total** | **51** | **4** | **-47** | |

The corresponding manifests preserve the individual obligations:

- Alloy: `verification/ci/alloy-research-cases.json`
- SPIN: `verification/ci/spin-research-cases.json`
- TLA+: `verification/ci/tla-research-cases.json`
- Lean: `verification/ci/lean-qualification-cases.json`

No solver model, Lean qualification program, branch eligibility rule, or
path-sensitive trigger was removed merely to reduce workflow count.

A later graduation pass retired two additional standalone Lean workflows:

- `application-006-conservative-fact-extension.yml`: the abstract conservative
  extension witness is now retained as research prose/Git history and is marked
  absorbed/redundant by the structural falsification ledger;
- `opening-support-reuse-seam.yml`: Observation 245's seam was promoted
  into production OpeningSupport / RoleBalance behavior and production tests;
  its standalone witness and research prose now live only in Git history.

The item-2 graduation pass therefore reached `97 -> 48`. The later native Web
frontend retirement brought the live workflow count to `47`. The Movement
Proposal consolidation then reached `46`; Scheduled publisher consolidation reaches
`44`; Actual Routing consolidation then reaches `43`; Capacity consolidation reaches `42`; Event Merchant consolidation reaches `41`; runtime shadow consolidation reaches `40`; Scheduled lifecycle qualification consolidation reaches `39`, or 58 retired workflow files in total.
The surviving `movement-proposal.yml` retains separate read-only transport and
explicit publication jobs under one shared path-trigger surface. The surviving
`scheduled-publishers.yml` likewise retains separate Creation, Replacement, and
Terminal publication jobs; no Scheduled semantic publisher is merged.
Presentation-neutral Home / Reports / ReadState checks remain qualified by `tui.yml`.

## Shared Lean build mechanics

Nineteen surviving workflows use the shared build-only composite action while retaining their relevant job identity, runner,
checkout behavior, permissions, concurrency, triggers, build target, and later
qualification steps, but share one build-only composite action:

`.github/actions/lean-build/action.yml`

This removes duplicated Lean setup without merging publisher, writer,
persistence, review, UI/CLI, or read-only trust boundaries.

## Pull-request fast lane and full qualification

Repository-wide distillation creates many small production-code PRs. Those PRs
still need a compile/regression barrier, but they do not all need release
packaging or every durable/research witness on every head commit.

The CI timing policy is therefore two-stage without changing the semantic
ownership of the checks:

- `tui.yml` keeps the existing `Production TUI / Build production household TUI`
  check name. Pull requests build `loamTui` plus the shared Actual fixture and
  run representative Record, Actual, Scheduled, Capacity, Settlement, Reports,
  and HelpFooter interaction checks. Pushes to `main` and manual runs retain
  the full production executable and TUI qualification suite.
- `standalone-distribution.yml` keeps the repository-independent binary smoke
  on pull requests. The four-platform packaging matrix and release-asset
  collection run after merge on `main`, on tags, or by manual dispatch rather
  than on every TUI edit.
- `selected-lean-observations.yml` always retains the product `Loam` build on
  relevant pull requests. The expensive durable-proof and live-observation
  surfaces are skipped only for presentation-local `Loam/Tui/**`,
  `Loam/Tests/**`, and `Loam/Presentation/**` changes; non-presentation
  product changes, pushes to `main`, and manual runs retain them.

This changes *when* expensive evidence is replayed, not which evidence owns a
boundary. Specialized path-scoped publisher, persistence, UI, and formal-method
workflows remain independently triggered. Seven narrow consolidation groups share
union path triggers while preserving independently named jobs: Movement Proposal
keeps read-only transport separate from explicit publication, Scheduled
publication keeps Creation, Replacement, and Terminal qualification separate,
and Actual Routing keeps persistence qualification separate from the practical
writer. The routing persistence story is executed once and the writer job depends
on that qualification rather than replaying the same test. Capacity likewise keeps
publisher qualification separate from the practical CLI entrance; the latter remains
suppressed on the historical `feat/tui` push lane. Event Merchant keeps canonical
publisher qualification separate from TUI input qualification; on the historical
`feat/tui-event-merchant` push lane only the TUI job runs. Runtime shadow
qualification keeps the redacted projection audit separate from the stateless
quantity projection while sharing one trigger surface; Observation 078 remains an
independent axiom-audited proof contract. Scheduled lifecycle qualification keeps
persistence separate from Creation, Replacement, and Terminal publication while
sharing the same main / `feat/tui` trigger surface.

## Live obligation families

### Product, durable proof, and live Lean research surfaces

- `selected-lean-observations.yml` keeps the three explicit Lean surfaces:
  product `Loam`, durable `Loam.DurableProofs`, and research
  `Loam.Observations`.
- `lean-application-qualifications.yml` keeps the five consolidated
  application/core qualification obligations individually named.
- Specialized Lean checks that differ in trust or tool contract stay separate,
  including `core-finite-keyed-lookup.yml`,
  `non-household-core-probe.yml`,
  `observation-274-global-done-correspondence.yml`, and
  `stateless-shadow-identity-observation.yml`.

### External formal-method research

- `alloy-research-witnesses.yml`: 24 Alloy obligations.
- `spin-research-witnesses.yml`: 6 SPIN obligations.
- `tla-research-witnesses.yml`: 16 TLA+ cases and their success/counterexample
  variants.
- Mixed or semantically special research remains isolated where its contract is
  different, including `cross-tool-checking-regime-observation.yml`,
  `observation-155-complete-image-publication.yml`,
  `split-publication-recovery-observation.yml`, and
  `application-003-writer-interleaving.yml`.

### Household product and publication boundaries

These workflows remain separate because each names an independently useful
operational or trust boundary:

- `application.yml`
- `accounting-projection-basis.yml`
- `cycle-funding-inspection.yml`
- `merchant-expense-review.yml`
- `boundary-preset-config.yml`
- `actual-validity-publisher.yml`
- `capacity.yml` (separate publisher and practical-entrance jobs)
- `event-merchant.yml` (separate publisher and TUI-input jobs)
- `scheduled-lifecycle.yml` (separate persistence, Creation, Replacement, and Terminal jobs)
- `practical-actual-routing.yml` (separate persistence and practical-writer jobs)
- `practical-scheduled-routing.yml`
- `practical-slice-a2.yml`
- `practical-slice-b.yml`
- `measure-scale-stability.yml`
- `attention-administration.yml`
- `movement-proposal.yml` (separate read-only transport and explicit publication jobs)
- `operational-continuity.yml`
- `shadow-runtime.yml` (separate redacted projection and stateless quantity jobs)
- `purpose-catalog.yml`

### User interfaces, interchange, distribution, and repository audits

These remain separately named because their triggers, outputs, credentials, or
operational roles differ:

- `tui.yml`
- `tui-foundation.yml`
- `beancount-export.yml`
- `standalone-distribution.yml`
- `compression-audit.yml`
- `module-granularity-audit.yml`
- `repository-hygiene.yml`

## Current stopping point after the 40-workflow audit

The post-shadow full inventory classified the remaining workflows by current
evidence rather than by naming similarity. It found one high-confidence GROUP
pair, the Scheduled lifecycle persistence and publisher qualification surfaces,
and no workflow that could be retired outright without dropping a distinct
operational, proof, solver, packaging, repository-audit, or path-local
qualification contract.

After that grouping, the remaining 39 workflow files are therefore treated as
KEEP by default. Future consolidation should require fresh evidence of mechanical
and semantic equivalence rather than a target workflow count.

## Protected distinctions

The item-2 consolidation deliberately does not merge away:

- Review / Publisher separation;
- complete-image Actual admission;
- writer ownership and staged publication;
- persistence-specific qualification;
- product / durable-proof / research Lean surfaces;
- solver-specific success/counterexample semantics;
- release/distribution permissions;
- expensive or intentionally isolated integration witnesses.

A workflow that remains individually named should therefore be treated as an
intentional control surface unless a later audit demonstrates that its
obligation has become mechanically and semantically equivalent to another one.

## Reproducing the current topology

Run:

```sh
python3 tools/audit-ci-topology
```

At the completion point for item 2, the measured topology was:

```text
workflow files:      48
workflow YAML bytes: 225221
```

The original issue baseline was 97 workflows / 315035 workflow YAML bytes.
The first instrumented measurement after adding the topology audit was
97 / 315151. Subsequent feature/qualification work brought the pre-graduation
live topology to 50 / 227627. Retiring the two graduated Lean witnesses produced
the item-2 completion measurement above. The later native Web retirement reduced
the live workflow-file count to 47, the Movement Proposal consolidation reduced
it to 46, the Scheduled publisher consolidation reduced it to 44, the Actual Routing consolidation reduced it to 43, the Capacity consolidation reduced it to 42, the Event Merchant consolidation reduced it to 41, the runtime shadow consolidation reduced it to 40, and the Scheduled lifecycle qualification consolidation reduces it to 39; use
`python3 tools/audit-ci-topology` for the current YAML byte measurement after
subsequent feature changes.

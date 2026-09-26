# CI Obligation Map

Status: item-2 repository tightening map after PR #1289.

This document is the human-readable map for LOAM's live CI obligations. The
machine inventory remains `python3 tools/audit-ci-topology`; use that command
when exact workflow counts, toolchains, triggers, permissions, or command lists
are needed.

## Compression ledger

The item-2 baseline had 97 workflow files. After retiring two graduated standalone Lean witnesses, the current topology has 48.

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
- `opening-support-reuse-seam.yml`: Observation 245's seam has been promoted
  into production OpeningSupport / RoleBalance behavior and production tests.

Thus the cumulative workflow reduction is now `97 -> 48`, or 49 retired
workflow files.

## Shared Lean build mechanics

Twenty-six surviving workflows retain their own workflow/job identity, runner,
checkout behavior, permissions, concurrency, triggers, build target, and later
qualification steps, but share one build-only composite action:

`.github/actions/lean-build/action.yml`

This removes duplicated Lean setup without merging publisher, writer,
persistence, review, UI/CLI, or read-only trust boundaries.

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
- `capacity-publisher.yml`
- `event-merchant-publisher.yml`
- `scheduled-creation-publisher.yml`
- `scheduled-replacement-publisher.yml`
- `scheduled-terminal-publisher.yml`
- `scheduled-lifecycle-persistence.yml`
- `practical-actual-routing-persistence.yml`
- `practical-actual-routing-writer.yml`
- `practical-capacity.yml`
- `practical-scheduled-routing.yml`
- `practical-slice-a2.yml`
- `practical-slice-b.yml`
- `measure-scale-stability.yml`
- `attention-administration.yml`
- `movement-proposal.yml`
- `movement-proposal-record.yml`
- `operational-continuity.yml`
- `tui-event-merchant.yml`
- `private-shadow-projection-observation.yml`
- `stateless-shadow-quantity.yml`
- `purpose-catalog.yml`

### User interfaces, interchange, distribution, and repository audits

These remain separately named because their triggers, outputs, credentials, or
operational roles differ:

- `tui.yml`
- `tui-foundation.yml`
- `web.yml`
- `beancount-export.yml`
- `standalone-distribution.yml`
- `compression-audit.yml`
- `module-granularity-audit.yml`
- `repository-hygiene.yml`

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

At the completion point for item 2, the measured topology is:

```text
workflow files:      48
workflow YAML bytes: 216030
```

The original issue baseline was 97 workflows / 315035 workflow YAML bytes.
The first instrumented measurement after adding the topology audit was
97 / 315151. The later 48 / 216030 figure includes the two graduated Lean
witness retirements described above.

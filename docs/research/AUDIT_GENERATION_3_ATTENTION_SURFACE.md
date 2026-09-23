# Generation 3 Attention surface observation

## Question

After PR #1128 connected Home `i` to `AttentionAdministration`, does the older
`Loam.Tui.Attention` read-only workspace still own a production responsibility?

## Evidence

- PR #484 introduced `Loam.Tui.Attention` as the first production read-only
  Attention workspace.
- PR #927 added the separate `loamAttention` administration executable while
  deliberately leaving the integrated reader unchanged.
- PR #1128 then replaced the integrated `loamTui` reader loop with
  `AttentionAdministration` / `AttentionAdministrationSession`.
- The standalone `loamAttention` executable also enters
  `AttentionAdministration`; no declared executable root enters
  `Loam.Tui.Attention`.
- The old module remained referenced only by its dedicated test, TUI CI, and
  historical/research documentation.
- `AttentionReview` already qualifies unavailable vs configured-empty evidence
  and the three due meanings.

## Experiment

Retire `Loam.Tui.Attention` and `Loam.Tests.TuiAttention`, remove their explicit
CI retention, and move the still-relevant presentation checks to the production
`TuiAttentionAdministration` test.

The retired properties that were purely historical, such as "this surface is
read-only", are intentionally not preserved because #1128 changed the product
contract.

## Expected boundary

```text
AttentionReview
      |
      v
AttentionAdministration
      |
      +--> loamTui Home i
      |
      +--> loamAttention

write intent
      |
      v
HouseholdCommand -> AttentionPublisher -> attention.loam
```

## Decision rule

Keep this retirement only if production TUI qualification and module-granularity
checks remain green. A failure that reveals a real consumer or unique semantic
obligation is evidence to restore or reshape the boundary rather than forcing the
deletion.

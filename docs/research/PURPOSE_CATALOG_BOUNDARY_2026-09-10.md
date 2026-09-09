# Purpose catalog boundary — 2026-09-10

Status: candidate practical boundary pending CI qualification

This checkpoint records the small result earned by Observation 239.

- `PurposeId` stays the stable semantic coordinate used by Capacity and routing.
- Human-facing label/help are replaceable presentation metadata only.
- Missing metadata falls back to the stable token.
- Catalog decoration consumes already-existing Purpose identities and cannot admit new ones.
- Capacity semantics remain independent of catalog contents.

No Purpose registry, rename event, alias graph, retirement model, or migration ontology is introduced.

If CI remains green, the next practical slice is to load `config/purpose-catalog.tsv` at the TUI boundary and use its labels in Capacity/Budget rendering while keeping publication and routing on unchanged `PurposeId` values.

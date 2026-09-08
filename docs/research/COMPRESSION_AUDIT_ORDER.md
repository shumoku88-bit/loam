# Compression audit order

The active compression audit is tracked by Issue #535 and grounded by `COMPRESSION_AUDIT_CHECKPOINT_226.md`.

Work proceeds strictly in this order:

1. reproduce the production source surface;
2. inventory independently retained semantic meaning;
3. audit repeated mechanics across histories, frontiers, publishers, persistence, and writer protocols;
4. retire dead production surface;
5. compress research and CI history;
6. compare before/after complexity.

Do not start a later phase merely because it appears easier. Findings from an earlier phase may narrow or eliminate later work.

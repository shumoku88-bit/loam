# LOAM disposable SQLite projection experiment

This subproject is a bounded research instrument for
`LOAM_TEXT_SQLITE_PERSISTENCE_STUDY_2026-10.md`.

It does **not** change LOAM production persistence and it does **not** make
SQLite household authority.

The experiment:

1. constructs synthetic balanced LOAM Actual evidence;
2. publishes it through the real normalized `actual.loam` authority boundary;
3. reloads the fully admitted Actual image;
4. derives the existing Actual Review projection;
5. materializes that admitted read image into an indexed SQLite database;
6. compares selected SQL answers with the existing LOAM answers;
7. builds a second database independently and requires the same answers.

The intended authority relationship is:

~~~text
actual.loam
    -> typed decode / semantic admission
    -> Actual Review records
    -> disposable SQLite projection
~~~

No SQLite mutation writes back into LOAM.

## Run

From this directory:

~~~sh
lake update
lake build sqliteProjectionExperiment
tmp="$(mktemp -d)"
.lake/build/bin/sqliteProjectionExperiment "$tmp"
rm -rf "$tmp"
~~~

The SQLite dependency is pinned to the `leanprover/leansqlite` revision that
tracks Lean 4.33.0, while LOAM currently uses Lean 4.33.1. The experiment is
kept in its own Lake package so the production LOAM package does not acquire a
SQLite dependency merely to answer this research question.

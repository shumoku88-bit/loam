# Let's Kakeibo — data portability and recovery

## 1. Why portability belongs in UI research

For a household system used over many years, "Can I get my history out?" is part of the interaction contract.

Let's家計簿 exposes several escape/recovery routes:

- native household-book data;
- automatic backup;
- backup restore;
- CSV export;
- statement/history import;
- configurable data location;
- multiple household books.

These features help explain why the program could remain useful without a cloud account.

## 2. Automatic persistence

The current 窓の杜 library page states that changes are automatically saved.

This reduces one class of loss caused by forgetting an explicit Save command.

The exact atomicity and crash behavior remain unverified.

## 3. Native backup data

A 2024 long-term-user article documents an "自動バックアップ" folder and identifies backup files with the `.LBK` extension.

The same article demonstrates restoring a household book from such a backup on another PC.

Evidence status: **secondary hands-on source**.

## 4. Configurable data location

The same user report shows that the data storage location can be changed from the program.

This enabled a non-official Dropbox workflow:

```text
install program on each PC
      |
place household data in synced folder
      |
point each installation at that location
```

This is not official cloud synchronization and carries concurrency/race risks, but it demonstrates a valuable property: **household data is not trapped behind an online account**.

## 5. CSV export

Vector reviews document CSV output well before the final release.

The 2024 specialist series also converted final-release CSV export into an interchange format for other household applications.

This means the product had both:

- a richer native representation for its own operation;
- a simpler interoperable projection for escape/analysis.

That distinction is strongly relevant to LOAM.

## 6. Import surfaces

By the v5 era, review material lists import support for:

- online-banking statement data;
- Edy;
- Suica and related electronic-money history.

The 2024 specialist series additionally notes OFX import capability, though that author did not fully evaluate it.

## 7. Import failure behavior

The 2024 specialist research reports at least two import defects.

One documented issue is particularly instructive: cancelling an import could still leave newly encountered account/category definitions registered.

This is a negative lesson for LOAM:

```text
preview/cancel must not partially mutate semantic configuration
```

A future LOAM importer should preserve transactional admission: cancellation should be cancellation.

## 8. Multiple household books

The program supports multiple household data sets and later reviews say several could be open at the same time.

A 2005 review also notes visual customization such as toolbar color/design per household book to make them easy to distinguish.

This is a small but clever anti-error device when several books are open.

## 9. Sample book as recovery-free learning

The final release includes a populated sample household spanning roughly 18 months.

This lets users learn:

- navigation;
- graph behavior;
- report behavior;
- card markers;
- receipt grouping;

without touching real household data.

For durable software this functions as a **safe rehearsal environment**.

## 10. LOAM implications

Candidate principles, not requirements:

- keep canonical household data local and inspectable;
- maintain a simple export projection even if canonical semantics are richer;
- keep backup/restore explicit and testable;
- make import preview non-mutating;
- require one qualified commit point for import changes;
- provide deterministic demo data separate from household authority;
- ensure the UI can explain exactly which authority/data directory is active.

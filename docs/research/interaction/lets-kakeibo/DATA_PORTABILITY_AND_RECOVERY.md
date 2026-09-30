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

The bundled v5.93 help gives the precise behavior: automatic saving is enabled by default and occurs when the household book/application closes.

It can be disabled. When disabled, explicit Save and unsaved-close choices become part of the workflow.

This primary evidence corrects the earlier reading of a secondary product description as implying persistence after every edit. Crash atomicity still remains unverified.

## 3. Native backup data

The bundled v5.93 help confirms both automatic and manual backup.

Automatic backup is normally produced on application exit, at most one backup per day, with same-day replacement and a default ten-day retention window.

Manual backup uses an `.LBK` file whose name includes date/time/book name. Restore replaces a same-named book completely or creates it when absent.

A later long-term-user article independently demonstrates restoring such an `.LBK` backup on another PC.

## 4. Configurable data location

The bundled help confirms that both the household-data folder and automatic-backup folder can be changed independently. It explicitly presents separate storage devices/locations as a resilience option.

A later user report demonstrates the same setting in practice.

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

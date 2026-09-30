# Let's Kakeibo v5.93 package inspection

Date: 2026-10-01  
Status: **exact official ZIP verified; static inspection only; installer not executed**

## Input package

A user-supplied copy of `lets593.zip` was inspected locally without executing its Windows payload.

Observed package size:

```text
lets593.zip  6,052,373 bytes
```

ZIP contents:

```text
lets593.exe  6,135,648 bytes
```

## Identity verification

The ZIP MD5 is:

```text
875b05ddc22e5992d06f4d0ca672a7d4
```

This exactly matches the MD5 published by the official Let's Software site for `lets593.zip`.

Therefore this research pass can treat the supplied archive as the exact official v5.93 ZIP published by the author, subject to the normal limitation that an MD5 match establishes byte identity with the published artifact rather than modern cryptographic authenticity.

Additional local hash:

```text
SHA-256(lets593.zip)
1b3d1b3c24d136f7ff8485ead4d1250e0c27a8dcde740c3270327a45b064efc3
```

## Installer identity

Static file inspection reports:

```text
PE32 executable for MS Windows 5.00 (GUI), Intel i386
```

The executable contains the marker:

```text
Inno Setup Setup Data (5.5.0) (u)
```

and the loader string:

```text
This installation was built with Inno Setup.
```

Thus the package is an Inno Setup 5.5.0-era installer.

Installer hashes:

```text
MD5     180594805c03caf2f0eef147188fad02
SHA-256 f91f6adee9c572551fd99dd202abe5208b7f2707311bc59c170ad57e2ad938e3
```

## Safety boundary

The Windows installer was **not executed**.

Only the ZIP container, PE metadata, printable installer markers, and cryptographic hashes were inspected.

The current analysis environment does not include an Inno Setup extraction utility such as `innoextract`. Attempts to obtain one through the isolated environment were unsuccessful, so the embedded application files and bundled help/manual have not yet been extracted.

This is preferable to running the installer merely to obtain documentation.

## What this resolves

Previous research only knew that the official site exposed `lets593.zip`.

This inspection upgrades that statement:

```text
official published MD5
       ==
uploaded ZIP MD5
       ->
exact published v5.93 archive obtained for research
```

It does **not** yet upgrade claims about undocumented keyboard shortcuts, menu commands, internal data formats, or help topics. Those still require safe extraction or direct inspection of the bundled documentation.

## Next safe extraction target

Use a non-executing Inno Setup extractor capable of version 5.5.0.

Expected research sequence after extraction:

1. enumerate installed files;
2. identify CHM/HLP/HTML/TXT/manual assets;
3. hash and catalog those files;
4. inspect documentation without launching the application;
5. reconstruct menu, shortcut, entry, card, recurring, import, backup, and correction behavior;
6. keep primary-help evidence separate from earlier review-based reconstruction.

No binary from this package should be committed to the LOAM repository. Only derived research notes and hashes belong here.

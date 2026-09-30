# Let's Kakeibo v5.93 package inspection

Date: 2026-10-01  
Status: **exact official ZIP verified; payload safely extracted without executing installer**

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

The installer was parsed directly as Inno Setup 5.5.0 data without launching Windows code. The setup metadata blocks and one solid LZMA data chunk were decompressed, and Inno's executable instruction filter was reversed for the two executable payloads.

Six embedded payloads were recovered and verified against the SHA-1 digests stored in the installer metadata:

```text
License.txt                 2,520 bytes
ReadMe.txt                 44,635 bytes
Lets.exe                5,319,168 bytes
lets.chm                4,060,908 bytes
Thanks.txt                  1,435 bytes
LetsKakeiboReminder.exe    147,456 bytes
```

All six recovered payload SHA-1 values exactly match the installer metadata.

The extracted files remain temporary local research evidence and are not committed or redistributed.

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

It now upgrades claims about the final package's implementation language, file inventory, and CHM topic inventory. Exact keyboard-command semantics and help-page body details still require page-body decompression and reading.

## Extraction result

The package has now been safely extracted without execution. See:

- [IMPLEMENTATION_LINEAGE.md](IMPLEMENTATION_LINEAGE.md)
- [HELP_CONTENT_INDEX.md](HELP_CONTENT_INDEX.md)

The next frontier is page-level CHM help analysis, followed by reconstruction of the full command/shortcut model.

No binary from this package should be committed to the LOAM repository. Only derived research notes and hashes belong here.

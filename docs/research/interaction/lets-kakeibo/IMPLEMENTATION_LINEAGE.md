# Let's Kakeibo v5.93 — implementation lineage

Date: 2026-10-01  
Status: **primary package evidence, extracted without executing installer**

## 1. Development language is now confirmed

The bundled `ReadMe.txt` in the exact official v5.93 package identifies the development language as:

```text
Delphi 2007
```

It also gives the final build date as 2013-11-15 and says no separate DLL installation is required.

This upgrades the earlier "possibly Delphi/VCL" inference into direct primary-package evidence.

## 2. Development-environment history

The bundled version history records several explicit toolchain migrations:

- Ver1.25 -> 1.31 (1998-10-14): development environment upgraded to Delphi 4.0J;
- Ver3.x era (2005): development environment upgraded to Delphi 2005;
- Ver3.75 -> 3.78 (2006-10-19): development tools upgraded to Delphi 2006;
- final v5.93 metadata: Delphi 2007.

The surviving product therefore spans many years of Delphi evolution while retaining the same recognizable household-ledger interaction model.

## 3. Binary evidence independently agrees

Static inspection of the recovered `Lets.exe` finds strong Delphi/VCL runtime fingerprints, including names associated with:

- `SysUtils`;
- `Classes`;
- `Controls`;
- `Forms`;
- `Dialogs`;
- `TObject`;
- `TComponent`;
- `TWinControl`;
- `TCustomForm`;
- `TForm`;
- `TApplication`;
- Borland/Delphi locale and RTL registry paths;
- FastMM Borland Edition.

The main executable is a 32-bit PE GUI program with no CLR runtime header.

The smaller reminder executable carries the same Delphi/Borland runtime family.

## 4. Why this matters to LOAM / hra-n research

This gives the external comparison an unexpectedly relevant language lineage:

```text
Let's家計簿
  Delphi / Object Pascal
        |
        | long-lived native household desktop tool
        v
LOAM
  Lean 4
        |
        | semantics / proof / experimentation
        v
hra-n
  Ada / SPARK
        |
        | durable native implementation / GUI work
        v
future household tooling
```

This is not a claim that Delphi, Lean, and Ada/SPARK are equivalent languages.

The useful comparison is that the durable household interaction model survived multiple implementation/toolchain eras, while LOAM and hra-n intentionally explore whether household semantics can survive across two very different modern language systems.

## 5. Stronger longevity lesson

The product history now shows two kinds of continuity:

1. **within Delphi:** repeated migration across Delphi generations while preserving the product;
2. **within the product architecture:** the earlier near-total Ver.3 internal rewrite preserved visible behavior.

Together they support a stronger distinction:

```text
household meaning
    !=
interaction shell
    !=
compiler/toolkit generation
```

A long-lived LOAM should therefore avoid making any one terminal, GUI toolkit, compiler version, or executable packaging format the sole owner of household meaning.

## 6. Evidence boundary

This note does not infer the original PC-8801 implementation language.

It also does not claim that every historical Let's家計簿 release used the same Delphi version. Only explicitly documented toolchain milestones are listed.

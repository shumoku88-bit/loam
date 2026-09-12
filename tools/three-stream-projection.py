#!/usr/bin/env python3
"""Read-only experiment: project current LOAM household authority into three streams."""

from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
from pathlib import Path

MAGIC = b"LOAM-THREE-STREAM\t1\n"
MOVEMENT_MAGIC = "LOAM-MOVEMENT-MANIFEST\t2"

ACTUAL_SIDE_PATHS = (
    "corrections.loam",
    "actual-reversals.loam",
)

POLICY_PATHS = (
    "accounting-role.loam",
    "zero-origin-coverage.loam",
    "actual-routing.loam",
    "capacity.loam",
    "capacity.loam.effective",
    "scheduled-routing.loam",
)

SCHEDULED_PATHS = ("scheduled.loam",)


class ProjectionError(RuntimeError):
    pass


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def safe_section_name(name: str) -> None:
    if not name or "\t" in name or "\n" in name or "\r" in name:
        raise ProjectionError(f"invalid section name: {name!r}")


def write_stream(path: Path, sections: list[tuple[str, bytes]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as out:
        out.write(MAGIC)
        for name, data in sections:
            safe_section_name(name)
            out.write(
                f"SECTION\t{name}\t{len(data)}\t{sha256(data)}\n".encode("utf-8")
            )
            out.write(data)
            out.write(b"\n")


def read_stream(path: Path) -> list[tuple[str, bytes]]:
    with path.open("rb") as src:
        if src.readline() != MAGIC:
            raise ProjectionError(f"{path}: bad stream header")
        sections: list[tuple[str, bytes]] = []
        seen: set[str] = set()
        while True:
            header = src.readline()
            if header == b"":
                break
            try:
                text = header.decode("utf-8").rstrip("\n")
            except UnicodeDecodeError as exc:
                raise ProjectionError(f"{path}: non-UTF-8 section header") from exc
            fields = text.split("\t")
            if len(fields) != 4 or fields[0] != "SECTION":
                raise ProjectionError(f"{path}: malformed section header: {text!r}")
            _, name, length_text, expected_digest = fields
            safe_section_name(name)
            if name in seen:
                raise ProjectionError(f"{path}: duplicate section {name!r}")
            try:
                length = int(length_text)
            except ValueError as exc:
                raise ProjectionError(
                    f"{path}: invalid section length {length_text!r}"
                ) from exc
            if length < 0:
                raise ProjectionError(f"{path}: negative section length")
            data = src.read(length)
            if len(data) != length:
                raise ProjectionError(f"{path}: truncated section {name!r}")
            if src.read(1) != b"\n":
                raise ProjectionError(
                    f"{path}: missing section delimiter after {name!r}"
                )
            actual_digest = sha256(data)
            if actual_digest != expected_digest:
                raise ProjectionError(
                    f"{path}: digest mismatch for {name!r}: "
                    f"{actual_digest} != {expected_digest}"
                )
            seen.add(name)
            sections.append((name, data))
        return sections


def parse_selected_movement(root: Path) -> list[tuple[str, bytes]]:
    authority = root / "movement-authority"
    current = authority / "CURRENT"
    if not current.is_file():
        raise ProjectionError(f"missing Movement selector: {current}")
    try:
        lines = current.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError as exc:
        raise ProjectionError(f"{current}: not UTF-8") from exc
    if not lines or lines[0] != MOVEMENT_MAGIC:
        raise ProjectionError(f"{current}: unsupported Movement manifest")
    sections: list[tuple[str, bytes]] = []
    seen: set[str] = set()
    for line in lines[1:]:
        if not line:
            continue
        fields = line.split("\t")
        if len(fields) != 3:
            raise ProjectionError(f"{current}: malformed selector row {line!r}")
        family, relative, expected_digest = fields
        safe_section_name(family)
        if family in seen:
            raise ProjectionError(f"{current}: duplicate family {family!r}")
        rel = Path(relative)
        if rel.is_absolute() or ".." in rel.parts:
            raise ProjectionError(f"{current}: unsafe object path {relative!r}")
        object_path = authority / rel
        if not object_path.is_file():
            raise ProjectionError(f"{current}: selected object missing: {object_path}")
        data = object_path.read_bytes()
        actual_digest = sha256(data)
        if actual_digest != expected_digest:
            raise ProjectionError(
                f"{current}: digest mismatch for {family}: "
                f"{actual_digest} != {expected_digest}"
            )
        seen.add(family)
        sections.append((f"movement/{family}", data))
    if not sections:
        raise ProjectionError(f"{current}: no selected Movement families")
    return sections


def maybe_add(root: Path, relative: str, sections: list[tuple[str, bytes]]) -> None:
    path = root / relative
    if path.is_file():
        sections.append((relative, path.read_bytes()))


def project(root: Path) -> dict[str, list[tuple[str, bytes]]]:
    actual = parse_selected_movement(root)
    for relative in ACTUAL_SIDE_PATHS:
        maybe_add(root, relative, actual)

    policy: list[tuple[str, bytes]] = []
    for relative in POLICY_PATHS:
        maybe_add(root, relative, policy)

    scheduled: list[tuple[str, bytes]] = []
    for relative in SCHEDULED_PATHS:
        maybe_add(root, relative, scheduled)

    return {"actual": actual, "policy": policy, "scheduled": scheduled}


def pack(root: Path, output: Path) -> None:
    streams = project(root)
    output.mkdir(parents=True, exist_ok=True)
    for name, sections in streams.items():
        write_stream(output / f"{name}.stream", sections)

    count = sum(len(sections) for sections in streams.values())
    payload = sum(len(data) for sections in streams.values() for _, data in sections)
    stored = sum((output / f"{name}.stream").stat().st_size for name in streams)
    print(
        f"projected {count} current semantic sections: "
        f"{payload} payload bytes -> {stored} three-stream bytes"
    )


def write_file(root: Path, relative: str, data: bytes) -> None:
    target = root / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)


def unpack(stream_dir: Path, root: Path, support_from: Path | None) -> None:
    actual = read_stream(stream_dir / "actual.stream")
    policy = read_stream(stream_dir / "policy.stream")
    scheduled = read_stream(stream_dir / "scheduled.stream")

    root.mkdir(parents=True, exist_ok=True)
    movement_rows: list[str] = []

    for name, data in actual:
        if name.startswith("movement/"):
            family = name.removeprefix("movement/")
            safe_section_name(family)
            digest = sha256(data)
            relative = f"objects/{family}/{digest}.loam"
            write_file(root / "movement-authority", relative, data)
            movement_rows.append(f"{family}\t{relative}\t{digest}")
        elif name in ACTUAL_SIDE_PATHS:
            write_file(root, name, data)
        else:
            raise ProjectionError(f"actual.stream: unknown section {name!r}")

    if not movement_rows:
        raise ProjectionError("actual.stream: no Movement families")
    current = MOVEMENT_MAGIC + "\n" + "\n".join(movement_rows) + "\n"
    write_file(root, "movement-authority/CURRENT", current.encode("utf-8"))

    for name, data in policy:
        if name not in POLICY_PATHS:
            raise ProjectionError(f"policy.stream: unknown section {name!r}")
        write_file(root, name, data)

    for name, data in scheduled:
        if name not in SCHEDULED_PATHS:
            raise ProjectionError(f"scheduled.stream: unknown section {name!r}")
        write_file(root, name, data)

    if support_from is not None:
        source_config = support_from / "config"
        target_config = root / "config"
        if source_config.is_dir():
            if target_config.exists():
                shutil.rmtree(target_config)
            shutil.copytree(source_config, target_config)


def canonical_fingerprint(root: Path) -> dict[str, str]:
    streams = project(root)
    return {
        f"{stream}/{name}": sha256(data)
        for stream, sections in streams.items()
        for name, data in sections
    }


def check(root: Path, work: Path) -> None:
    packed = work / "streams"
    rebuilt = work / "rebuilt"
    pack(root, packed)
    unpack(packed, rebuilt, root)
    before = canonical_fingerprint(root)
    after = canonical_fingerprint(rebuilt)
    if before != after:
        missing = sorted(set(before) - set(after))
        added = sorted(set(after) - set(before))
        changed = sorted(
            key for key in set(before) & set(after) if before[key] != after[key]
        )
        raise ProjectionError(
            "round-trip mismatch: "
            f"missing={missing}, added={added}, changed={changed}"
        )
    print(f"round-trip preserved {len(before)} semantic sections exactly")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Project current LOAM authority into an experimental three-stream layout."
        )
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_pack = sub.add_parser("pack")
    p_pack.add_argument("data_root", type=Path)
    p_pack.add_argument("stream_dir", type=Path)

    p_unpack = sub.add_parser("unpack")
    p_unpack.add_argument("stream_dir", type=Path)
    p_unpack.add_argument("data_root", type=Path)
    p_unpack.add_argument("--support-from", type=Path)

    p_check = sub.add_parser("check")
    p_check.add_argument("data_root", type=Path)
    p_check.add_argument("work_dir", type=Path)

    args = parser.parse_args(argv)
    try:
        if args.command == "pack":
            pack(args.data_root, args.stream_dir)
        elif args.command == "unpack":
            unpack(args.stream_dir, args.data_root, args.support_from)
        else:
            check(args.data_root, args.work_dir)
    except (OSError, ProjectionError) as exc:
        print(f"three-stream projection failed: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

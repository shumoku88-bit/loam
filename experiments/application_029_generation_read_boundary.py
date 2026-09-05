#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path
import os
import re
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[1]

READ_ONLY_MODULES = [
    "Loam/Cli/BudgetWindowCli.lean",
    "Loam/Cli/CorrectionIntegrityCli.lean",
    "Loam/Cli/EffectiveCli.lean",
    "Loam/Cli/JournalExportCli.lean",
    "Loam/Cli/OpenScheduledCli.lean",
    "Loam/Cli/ReviewCli.lean",
    "Loam/Cli/ScheduledBalanceCli.lean",
]

FAMILIES = [
    "Event",
    "EventCorrection",
    "ActualValidity",
    "EventDescription",
    "Scheduled",
    "ScheduledCompletion",
    "ScheduledRetirement",
    "Capacity",
    "CapacityEffective",
    "ActualRouting",
]

HEADER = "LOAM-APPLICATION029-MANIFEST\t1"
QUALIFIED_LOAD_RE = re.compile(r"\bLoam\.Persistence\.load[A-Z][A-Za-z0-9_]*\?")


class PhysicalReadError(RuntimeError):
    pass


class MissingRequiredFamily(RuntimeError):
    pass


@dataclass(frozen=True)
class FamilyRef:
    path: str
    digest: str


@dataclass(frozen=True)
class Manifest:
    entries: dict[str, FamilyRef | None]


def digest_bytes(data: bytes) -> str:
    return sha256(data).hexdigest()


def object_path(family: str, digest: str) -> str:
    return f"objects/{family}/{digest}.loam"


def encode_manifest(manifest: Manifest) -> bytes:
    rows = [HEADER]
    for family in FAMILIES:
        ref = manifest.entries[family]
        if ref is None:
            rows.append(f"{family}\tABSENT")
        else:
            rows.append(f"{family}\tPRESENT\t{ref.path}\t{ref.digest}")
    return ("\n".join(rows) + "\n").encode()


def decode_manifest(data: bytes) -> Manifest:
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise PhysicalReadError("CURRENT is not UTF-8") from exc
    rows = text.splitlines()
    if not rows or rows[0] != HEADER or len(rows) != len(FAMILIES) + 1:
        raise PhysicalReadError("CURRENT has the wrong shape")
    entries: dict[str, FamilyRef | None] = {}
    for expected, row in zip(FAMILIES, rows[1:], strict=True):
        fields = row.split("\t")
        if fields == [expected, "ABSENT"]:
            entries[expected] = None
            continue
        if len(fields) != 4 or fields[0] != expected or fields[1] != "PRESENT":
            raise PhysicalReadError(f"CURRENT has malformed {expected} entry")
        _, _, relative, digest = fields
        if len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
            raise PhysicalReadError(f"CURRENT has malformed {expected} digest")
        if relative != object_path(expected, digest):
            raise PhysicalReadError(f"CURRENT has unsafe or mismatched {expected} path")
        entries[expected] = FamilyRef(relative, digest)
    return Manifest(entries)


def ensure_object(root: Path, family: str, data: bytes) -> FamilyRef:
    digest = digest_bytes(data)
    relative = object_path(family, digest)
    target = root / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        if target.read_bytes() != data:
            raise PhysicalReadError(f"content-addressed object mismatch: {relative}")
    else:
        stage = target.with_name(target.name + ".loam-stage")
        stage.write_bytes(data)
        if stage.read_bytes() != data:
            raise PhysicalReadError(f"staged object mismatch: {relative}")
        os.replace(stage, target)
    return FamilyRef(relative, digest)


def publish_generation(root: Path, values: dict[str, bytes | None]) -> Manifest:
    if set(values) != set(FAMILIES):
        raise PhysicalReadError("candidate generation must classify every family")
    entries: dict[str, FamilyRef | None] = {}
    for family in FAMILIES:
        data = values[family]
        entries[family] = None if data is None else ensure_object(root, family, data)
    manifest = Manifest(entries)
    stage = root / "CURRENT.loam-stage"
    target = root / "CURRENT"
    stage.write_bytes(encode_manifest(manifest))
    decoded = decode_manifest(stage.read_bytes())
    if decoded != manifest:
        raise PhysicalReadError("staged CURRENT changed family presence or references")
    os.replace(stage, target)
    return manifest


# APPLICATION029_SHARED_PHYSICAL_READER_START
@dataclass(frozen=True)
class GenerationSnapshot:
    root: Path
    manifest: Manifest

    def read(self, family: str) -> bytes | None:
        if family not in self.manifest.entries:
            raise PhysicalReadError(f"unknown family: {family}")
        ref = self.manifest.entries[family]
        if ref is None:
            return None
        target = self.root / ref.path
        try:
            data = target.read_bytes()
        except FileNotFoundError as exc:
            raise PhysicalReadError(f"selected {family} object is missing") from exc
        if digest_bytes(data) != ref.digest:
            raise PhysicalReadError(f"selected {family} object failed digest verification")
        return data


class GenerationReader:
    def __init__(self, root: Path):
        self.root = root
        self.capture_count = 0

    def capture(self) -> GenerationSnapshot:
        self.capture_count += 1
        try:
            current = (self.root / "CURRENT").read_bytes()
        except FileNotFoundError as exc:
            raise PhysicalReadError("CURRENT is missing") from exc
        return GenerationSnapshot(self.root, decode_manifest(current))
# APPLICATION029_SHARED_PHYSICAL_READER_END


def required(snapshot: GenerationSnapshot, family: str) -> bytes:
    value = snapshot.read(family)
    if value is None:
        raise MissingRequiredFamily(family)
    return value


def optional_empty(snapshot: GenerationSnapshot, family: str) -> bytes:
    value = snapshot.read(family)
    return b"" if value is None else value


# APPLICATION029_MEANING_ADAPTERS_START
def budget_window(snapshot: GenerationSnapshot) -> tuple[bytes, ...]:
    return (
        required(snapshot, "Capacity"),
        required(snapshot, "CapacityEffective"),
        required(snapshot, "Event"),
        optional_empty(snapshot, "EventCorrection"),
        required(snapshot, "ActualValidity"),
        required(snapshot, "ActualRouting"),
    )


def correction_integrity(snapshot: GenerationSnapshot) -> tuple[str, bytes | None]:
    corrections = snapshot.read("EventCorrection")
    if corrections is None:
        return ("no-corrections", None)
    return ("inspect", required(snapshot, "Event"))


def effective(snapshot: GenerationSnapshot) -> tuple[str, bytes, bytes]:
    events = snapshot.read("Event")
    if events is None:
        return ("no-recorded", b"", b"")
    return ("inspect", events, optional_empty(snapshot, "EventCorrection"))


def journal_export(snapshot: GenerationSnapshot) -> tuple[bytes, ...]:
    return (
        required(snapshot, "Event"),
        optional_empty(snapshot, "EventCorrection"),
        optional_empty(snapshot, "ActualValidity"),
        optional_empty(snapshot, "EventDescription"),
    )


def open_scheduled(snapshot: GenerationSnapshot) -> tuple[bytes, ...]:
    return (
        optional_empty(snapshot, "Scheduled"),
        optional_empty(snapshot, "ScheduledCompletion"),
        optional_empty(snapshot, "ScheduledRetirement"),
        optional_empty(snapshot, "Event"),
    )


def review(snapshot: GenerationSnapshot) -> tuple[bytes, ...]:
    return (
        required(snapshot, "Event"),
        optional_empty(snapshot, "EventCorrection"),
        optional_empty(snapshot, "ActualValidity"),
        optional_empty(snapshot, "EventDescription"),
    )


def scheduled_balance(snapshot: GenerationSnapshot) -> tuple[bytes, ...]:
    return (
        optional_empty(snapshot, "Scheduled"),
        optional_empty(snapshot, "ScheduledCompletion"),
        optional_empty(snapshot, "ScheduledRetirement"),
        optional_empty(snapshot, "Event"),
    )
# APPLICATION029_MEANING_ADAPTERS_END


ADAPTERS = [
    budget_window,
    correction_integrity,
    effective,
    journal_export,
    open_scheduled,
    review,
    scheduled_balance,
]


def run_view(reader: GenerationReader, adapter):
    return adapter(reader.capture())


def line_and_byte_count(path: Path, start: str, end: str) -> tuple[int, int]:
    text = path.read_text()
    body = text.split(start, 1)[1].split(end, 1)[0].strip("\n")
    return len(body.splitlines()), len(body.encode())


def source_surface() -> tuple[int, int, int, int, int, int]:
    load_calls = 0
    path_checks = 0
    for relative in READ_ONLY_MODULES:
        text = (ROOT / relative).read_text()
        load_calls += len(QUALIFIED_LOAD_RE.findall(text))
        path_checks += text.count("pathExists")
    own = Path(__file__)
    shared_lines, shared_bytes = line_and_byte_count(
        own,
        "# APPLICATION029_SHARED_PHYSICAL_READER_START",
        "# APPLICATION029_SHARED_PHYSICAL_READER_END",
    )
    adapter_lines, adapter_bytes = line_and_byte_count(
        own,
        "# APPLICATION029_MEANING_ADAPTERS_START",
        "# APPLICATION029_MEANING_ADAPTERS_END",
    )
    return load_calls, path_checks, shared_lines, shared_bytes, adapter_lines, adapter_bytes


def base_values(tag: str) -> dict[str, bytes | None]:
    return {family: f"{tag}:{family}\n".encode() for family in FAMILIES}


def expect_raises(exc_type, action, message: str) -> None:
    try:
        action()
    except exc_type:
        return
    raise AssertionError(message)


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="loam-application029-") as tmp:
        root = Path(tmp)
        g0 = base_values("g0")
        g0["EventCorrection"] = None
        g0["EventDescription"] = None
        manifest0 = publish_generation(root, g0)
        reader = GenerationReader(root)

        for adapter in ADAPTERS:
            run_view(reader, adapter)
        assert reader.capture_count == 7

        # One view captures CURRENT once. A later CURRENT replacement must not mix
        # the captured generation with the new generation midway through the view.
        stale = reader.capture()
        old_event = required(stale, "Event")
        g1 = base_values("g1")
        publish_generation(root, g1)
        old_validity = required(stale, "ActualValidity")
        fresh = reader.capture()
        assert old_event == b"g0:Event\n"
        assert old_validity == b"g0:ActualValidity\n"
        assert required(fresh, "Event") == b"g1:Event\n"
        assert required(fresh, "ActualValidity") == b"g1:ActualValidity\n"

        # Requested-family corruption fails closed, while an unrelated view does
        # not become unavailable merely because a family it never reads is bad.
        routing_ref = fresh.manifest.entries["ActualRouting"]
        assert routing_ref is not None
        routing_path = root / routing_ref.path
        routing_original = routing_path.read_bytes()
        routing_path.write_bytes(routing_original + b"corrupt")
        expect_raises(
            PhysicalReadError,
            lambda: budget_window(fresh),
            "budget window accepted corrupt requested routing",
        )
        assert effective(fresh)[0] == "inspect"
        routing_path.write_bytes(routing_original)

        # Explicit family absence stays visible to the meaning-specific adapter.
        # The physical layer never globally decides that missing means empty.
        empty = {family: None for family in FAMILIES}
        publish_generation(root, empty)
        empty_snapshot = reader.capture()
        assert correction_integrity(empty_snapshot) == ("no-corrections", None)
        assert effective(empty_snapshot)[0] == "no-recorded"
        assert open_scheduled(empty_snapshot) == (b"", b"", b"", b"")
        expect_raises(
            MissingRequiredFamily,
            lambda: review(empty_snapshot),
            "review silently converted required Event absence to empty",
        )
        expect_raises(
            MissingRequiredFamily,
            lambda: journal_export(empty_snapshot),
            "journal export silently converted required Event absence to empty",
        )
        expect_raises(
            MissingRequiredFamily,
            lambda: budget_window(empty_snapshot),
            "budget window silently converted required evidence absence to empty",
        )

        load_calls, path_checks, shared_lines, shared_bytes, adapter_lines, adapter_bytes = source_surface()

        print("Application 029 generation-scoped read boundary PASS")
        print(f"read_only_callsite_modules={len(READ_ONLY_MODULES)}")
        print(f"current_qualified_persistence_load_calls={load_calls}")
        print(f"current_path_exists_policy_checks={path_checks}")
        print("shared_generation_capture_mechanisms=1")
        print("shared_family_object_resolvers=1")
        print(f"meaning_specific_adapters={len(ADAPTERS)}")
        print("generation_captures_for_seven_views=7")
        print("cross_generation_mixed_reads=0")
        print("requested_corruption_fail_closed=1")
        print("unrequested_corruption_blocked_unrelated_view=0")
        print("missing_policy_cases_preserved=6")
        print("manifest_family_presence_is_explicit=1")
        print(f"scratch_shared_reader_lines={shared_lines}")
        print(f"scratch_shared_reader_bytes={shared_bytes}")
        print(f"scratch_meaning_adapter_lines={adapter_lines}")
        print(f"scratch_meaning_adapter_bytes={adapter_bytes}")


if __name__ == "__main__":
    main()

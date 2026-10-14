#!/usr/bin/env python3
"""One-shot #1963 qualification, not a verifier or an all-PR gate (Linux)."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import zipfile

REPO = Path.cwd()
OUT = Path(os.environ.get("QUALIFICATION_OUT", "/tmp/lean435-qualification")).resolve()
OUT.mkdir(parents=True, exist_ok=True)
ROWS = []


def run(label, args, *, cwd=REPO, expected=0, output=None, timeout=1200):
    log = OUT / f"{label}.log"
    start = time.monotonic()
    with log.open("w") as err:
        out = output.open("w") if output else err
        try:
            result = subprocess.run(["/usr/bin/time", "-v", *map(str, args)], cwd=cwd,
                                    stdout=out, stderr=err, timeout=timeout)
        finally:
            if output:
                out.close()
    row = dict(label=label, command=list(map(str, args)), cwd=str(cwd),
               exit=result.returncode, wall_s=round(time.monotonic() - start, 3))
    ROWS.append(row)
    (OUT / "commands.json").write_text(json.dumps(ROWS, indent=2) + "\n")
    print(json.dumps(row), flush=True)
    if expected is not None and result.returncode != expected:
        raise RuntimeError(f"{label}: expected {expected}, got {result.returncode}: {log.read_text()[-6000:]}")
    return log.read_text()


def official_check(label, artifact, expected=0, diagnostic=None):
    args = ["lake", "check", "--from-export", artifact]
    text = run(label + "-sandbox", args, expected=None)
    code = ROWS[-1]["exit"]
    if code != expected or (diagnostic and diagnostic not in text):
        # Trusted fixtures only. This fallback is logic evidence, NEVER sandbox acceptance.
        text = run(label + "-trusted-logic", args + ["--inadvisably-no-sandbox"], expected=expected)
    if diagnostic and diagnostic not in text:
        raise RuntimeError(f"{label}: missing proof/policy diagnostic {diagnostic!r}")


def main():
    run("version", ["lean", "--version"])
    run("update", ["lake", "update"])
    for target in ["Loam", "Loam.DurableProofs", "Loam.Observations", "loam", "loamTui"]:
        run("first-" + target, ["lake", "build", target])
        run("warm-" + target, ["lake", "build", target])
    run("product-tests", ["lake", "test"])
    run("replay", ["lake", "env", "lean", "tools/ReplayDurableProofs.lean"])
    run("sentinels", ["python3", "tests/test_durable_replay.py"])
    inventory = OUT / "inventory.jsonl"
    run("inventory", ["lake", "env", "lean", "--run",
                      "docs/experiments/lean435-qualification/Inventory.lean"], output=inventory)
    data = [json.loads(line) for line in inventory.read_text().splitlines()]
    owners, entries = data[0]["modules"], data[1:]
    roots = [r["name"] for r in entries if not r["unsafe"] and not r["partial"]]
    theorems = [r for r in entries if r["theorem"]]
    assert roots and theorems and len(set(roots)) == len(roots)
    replay = (OUT / "replay.log").read_text()
    checked = {line.split(" ", 4)[4] for line in replay.splitlines()
               if line.startswith("durable-replay: checked ")}
    assert checked == set(roots), "replay/inventory scope mismatch"
    (OUT / "roots.txt").write_text("\n".join(roots) + "\n")
    audit = OUT / "audit"
    run("audit-clone", ["git", "clone", "--depth", "1", "--branch", "v0.1.2",
                        "https://github.com/leanprover-community/axiom-audit.git", audit])
    sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=audit, text=True).strip()
    assert sha == "46024e005996495c65ef609368e11ab39c4222e3"
    shutil.copyfile(REPO / "lean-toolchain", audit / "lean-toolchain")
    run("audit-build", ["lake", "build"], cwd=audit)
    audit_bin = audit / ".lake/build/bin/axiom-audit"
    policy = ["--allow", "propext,Classical.choice,Quot.sound"]
    run("audit", ["lake", "env", audit_bin, "--root", "Loam", "--modules", "Loam.DurableProofs", *policy])
    if "v4.35.0" not in (REPO / "lean-toolchain").read_text():
        return
    artifact = OUT / "normalized.ndjson"
    run("export", ["lake", "env", "leanexport", "Loam.DurableProofs", "--", *roots], output=artifact)
    names, exported, partial = {0: ""}, set(), []
    for line in artifact.open():
        item = json.loads(line)
        if "in" in item:
            value = item.get("str", item.get("num"))
            piece = value["str"] if "str" in value else str(value["i"])
            prefix = names[value["pre"]]
            names[item["in"]] = prefix + "." + piece if prefix else piece
        for kind in ["axiom", "def", "thm", "opaque", "quot"]:
            if kind in item:
                exported.add(names[item[kind]["name"]])
                if item[kind].get("safety") == "partial":
                    partial.append(names[item[kind]["name"]])
        if "inductive" in item:
            for kind in ["types", "ctors", "recs"]:
                exported.update(names[v["name"]] for v in item["inductive"][kind])
    assert set(roots) <= exported and {r["name"] for r in theorems} <= exported and not partial
    report = dict(modules=owners, logical=len(roots), theorems=len(theorems),
                  skipped=[r for r in entries if r["unsafe"] or r["partial"]],
                  exported=len(exported), bytes=artifact.stat().st_size,
                  sha256=hashlib.sha256(artifact.read_bytes()).hexdigest())
    (OUT / "membership.json").write_text(json.dumps(report, indent=2) + "\n")
    run("stock-export-replay", ["lake", "env", "leanchecker", "--silent", "--from-export", artifact])
    official_check("selected-check", artifact)
    # Reuse already-qualified specimens, not another fixture ontology.
    fixtures = OUT / "fixtures"
    fixtures.mkdir()
    with zipfile.ZipFile(REPO / "docs/experiments/lean-435-reaudit/reaudit.zip") as z:
        for name in z.namelist():
            if name.startswith(("fixture165/", "fixture166/", "Dormant-b/", "Used-b/")):
                z.extract(name, fixtures)
    for name, expected in [("fixture165", 0), ("fixture166", 1)]:
        cwd = fixtures / name
        shutil.copyfile(REPO / "lean-toolchain", cwd / "lean-toolchain")
        run(name + "-build", ["lake", "build", "Challenge", "Solution"], cwd=cwd)
        args = ["lake", "comparator", "--config", "config.json"]
        text = run(name + "-comparator-sandbox", args, cwd=cwd, expected=None)
        if ROWS[-1]["exit"] != expected or (expected and "do not match" not in text):
            text = run(name + "-comparator-trusted-logic", args + ["--inadvisably-no-sandbox"], cwd=cwd, expected=expected)
        if expected:
            assert "do not match" in text, text
    for module, expected in [("Dormant", 0), ("Used", 1)]:
        cwd = fixtures / (module + "-b")
        shutil.copyfile(REPO / "lean-toolchain", cwd / "lean-toolchain")
        run(module + "-build", ["lake", "build", module], cwd=cwd)
        path = OUT / (module + ".ndjson")
        run(module + "-export", ["lake", "env", "leanexport", module], cwd=cwd, output=path)
        official_check(module + "-check", path, expected, "not permitted" if expected else None)
        text = run(module + "-audit", ["lake", "env", audit_bin, "--root", module, "--modules", module, *policy], cwd=cwd, expected=1)
        assert ("unused_fact" if module == "Dormant" else "bad") in text, text
    # The same compiled-invalid specimen used by the corrected driver, now via official export.
    sys.path.insert(0, str(REPO / "tests"))
    from test_durable_replay import DurableReplay
    probe = DurableReplay()
    probe.setUp()
    try:
        probe.test_kernel_rejects_invalid_compiled_import()
        path = OUT / "invalid.ndjson"
        run("invalid-export", ["lake", "env", "leanexport", "Loam.DurableProofs", "--", "Loam.ReplayProbe.invalid"], cwd=probe.root, output=path)
        text = run("invalid-stock-replay", ["lake", "env", "leanchecker", "--from-export", path], expected=1)
        assert "type mismatch" in text, text
    finally:
        probe.doCleanups()


if __name__ == "__main__":
    main()

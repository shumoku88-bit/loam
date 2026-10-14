#!/usr/bin/env python3
"""One-shot #1966 same-runner comparison; never carried into the production PR."""
import collections
import hashlib
import json
import os
from pathlib import Path
import resource
import statistics
import subprocess
import sys
import time


def timed_lake():
    start = time.monotonic()
    args = sys.argv[1:]
    result = subprocess.run([os.environ["REAL_LAKE"], *args])
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    row = dict(args=args, cwd=os.getcwd(), exit=result.returncode,
               wall_s=time.monotonic() - start, user_s=usage.ru_utime,
               sys_s=usage.ru_stime, maxrss_kib=usage.ru_maxrss)
    # The first-use race invokes Lake concurrently; append each row atomically.
    fd = os.open(os.environ["LAKE_TIMINGS"], os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    try:
        os.write(fd, (json.dumps(row) + "\n").encode())
    finally:
        os.close(fd)
    return result.returncode


def test_key(row):
    args = row["args"]
    if args[:3] != ["env", "lean", "--run"]:
        return None
    # Synthetic temporary-root arguments differ; retain meaningful race modes.
    mode = args[4] if len(args) > 4 and args[4].startswith("race-") else ""
    return args[3] + (" " + mode if mode else "")


def main():
    import run as measure  # Reuse the existing one-shot command/time/raw-log collector.
    out = measure.OUT
    source = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    measure.run("host", ["bash", "-c", "uname -a; lscpu; free -m; df -h ."])
    roots, binaries, hashes = {}, {}, {}
    original_path = os.environ["PATH"]
    wrapper = out / "wrapper"
    wrapper.mkdir()
    (wrapper / "lake").symlink_to(Path(__file__).resolve())
    # Lake prepends its own bin directory; restore the logger only in the Bash driver.
    bash_env = out / "bash-env"
    bash_env.write_text('export PATH="$TIMED_LAKE_DIR:$PATH"\n')
    for version in ["4.33.1", "4.35.0"]:
        pin = "leanprover/lean4:v" + version
        measure.run("setup-" + version, ["elan", "toolchain", "install", pin])
        root = out.parent / ("paired-source-" + version)
        measure.run("checkout-" + version, ["git", "worktree", "add", "--detach", root, source])
        (root / "lean-toolchain").write_text(pin + "\n")
        binary = Path(subprocess.check_output(["elan", "which", "lake"], cwd=root, text=True).strip())
        roots[version], binaries[version] = root, binary
        files = subprocess.check_output(["git", "ls-files", "Loam", "Loam.lean", "tests", "tools/test-product", "lakefile.lean"], cwd=root, text=True).splitlines()
        h = hashlib.sha256()
        for name in files:
            h.update(name.encode() + b"\0" + (root / name).read_bytes())
        hashes[version] = h.hexdigest()
        os.environ["PATH"] = str(binary.parent) + ":" + original_path
        measure.run("version-" + version, [binary.parent / "lean", "--version"], cwd=root)
        measure.run("update-" + version, [binary, "update"], cwd=root)
        measure.run("build-" + version, [binary, "build", "Loam", "Loam.DurableProofs", "Loam.Observations", "loam", "loamTui", "loamTests"], cwd=root)
    assert hashes["4.33.1"] == hashes["4.35.0"], "different tested source"
    rows = []
    # Prime both complete test-module caches, then ABBA reverses measured order.
    for label, version in [("prime-A", "4.33.1"), ("prime-B", "4.35.0"),
                           ("A1", "4.33.1"), ("B1", "4.35.0"),
                           ("B2", "4.35.0"), ("A2", "4.33.1")]:
        binary = binaries[version]
        os.environ.update(REAL_LAKE=str(binary), LAKE_TIMINGS=str(out / (label + ".jsonl")),
                          BASH_ENV=str(bash_env), TIMED_LAKE_DIR=str(wrapper),
                          PATH=str(wrapper) + ":" + str(binary.parent) + ":" + original_path)
        measure.run(label, [binary, "test"], cwd=roots[version])
        invocations = [json.loads(line) for line in (out / (label + ".jsonl")).read_text().splitlines()]
        explicit_build_s = sum(r["wall_s"] for r in invocations if r["args"][0] == "build")
        tests = collections.defaultdict(list)
        for row in invocations:
            if key := test_key(row):
                tests[key].append(row["wall_s"])
        rows.append(dict(label=label, version=version, wall_s=measure.ROWS[-1]["wall_s"],
                         explicit_inner_build_s=explicit_build_s, tests=dict(tests)))
        (out / "rounds.json").write_text(json.dumps(rows, indent=2) + "\n")
    scopes = [collections.Counter({k: len(v) for k, v in r["tests"].items()}) for r in rows]
    assert scopes[0] and all(s == scopes[0] for s in scopes), "test scope changed"
    a = rows[2]
    comparisons = []
    for key in a["tests"]:
        a_s = statistics.mean(sum(r["tests"][key]) for r in [rows[2], rows[5]])
        b_s = statistics.mean(sum(r["tests"][key]) for r in [rows[3], rows[4]])
        comparisons.append(dict(test=key, baseline_s=a_s, candidate_s=b_s,
                                delta_s=b_s - a_s, ratio=b_s / a_s))
    report = dict(source=source, tested_source_sha256=hashes, order=[r["label"] for r in rows],
                  rounds=[{k: v for k, v in r.items() if k != "tests"} for r in rows],
                  baseline_mean_s=statistics.mean(r["wall_s"] for r in [rows[2], rows[5]]),
                  candidate_mean_s=statistics.mean(r["wall_s"] for r in [rows[3], rows[4]]),
                  tests_equal=True, measured_test_invocations=sum(scopes[0].values()),
                  per_test=sorted(comparisons, key=lambda r: r["delta_s"], reverse=True))
    (out / "performance-summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "per_test"}), flush=True)


if __name__ == "__main__":
    if Path(sys.argv[0]).name == "lake":
        sys.exit(timed_lake())
    main()

from __future__ import annotations

import os
from pathlib import Path
import tempfile
import threading
import time

OLD = (
    b"LOAM-COMPLETE-ACTUAL\tpublic-fixture-old\n"
    + (b"old-section\t0123456789abcdef\n" * 16384)
    + b"END\tpublic-fixture-old\n"
)

NEW = (
    b"LOAM-COMPLETE-ACTUAL\tpublic-fixture-new\n"
    + (b"new-section\tfedcba9876543210\n" * 16384)
    + b"END\tpublic-fixture-new\n"
)


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="loam-observation-155-") as tmp:
        root = Path(tmp)
        target = root / "actual.loam"
        stage = root / "actual.loam.loam-stage"

        target.write_bytes(OLD)

        counts = {OLD: 0, NEW: 0}
        errors: list[str] = []
        lock = threading.Lock()
        start = threading.Event()
        stop = threading.Event()

        def reader() -> None:
            start.wait()
            while not stop.is_set():
                try:
                    observed = target.read_bytes()
                except Exception as exc:  # disappearance is itself a publication failure
                    with lock:
                        errors.append(f"reader exception: {exc!r}")
                    continue

                if observed not in (OLD, NEW):
                    with lock:
                        errors.append(
                            f"reader observed noncanonical image of {len(observed)} bytes"
                        )
                    continue

                with lock:
                    counts[observed] += 1

        readers = [threading.Thread(target=reader, daemon=True) for _ in range(4)]
        for thread in readers:
            thread.start()

        start.set()

        # Build the replacement image gradually at a sibling path so concurrent
        # readers have a long window in which the staged image is incomplete.
        chunk_size = max(1, len(NEW) // 128)
        with stage.open("wb", buffering=0) as handle:
            for offset in range(0, len(NEW), chunk_size):
                handle.write(NEW[offset : offset + chunk_size])
                time.sleep(0.0005)
            os.fsync(handle.fileno())

        if stage.read_bytes() != NEW:
            raise AssertionError("staged image was not complete before publication")

        if os.stat(stage).st_dev != os.stat(target).st_dev:
            raise AssertionError("stage and target are not on the same filesystem")

        os.replace(stage, target)

        deadline = time.monotonic() + 1.0
        while time.monotonic() < deadline:
            with lock:
                if counts[NEW] > 0:
                    break
            time.sleep(0.001)

        stop.set()
        for thread in readers:
            thread.join(timeout=2.0)

        if target.read_bytes() != NEW:
            raise AssertionError("published target is not the complete new image")
        if stage.exists():
            raise AssertionError("staging path still exists after successful replace")
        if errors:
            raise AssertionError("; ".join(errors[:5]))
        if counts[OLD] == 0:
            raise AssertionError("concurrent readers never observed the old image")
        if counts[NEW] == 0:
            raise AssertionError("concurrent readers never observed the new image")

        # Simulate interruption before rename. Partial sibling bytes may remain,
        # but the authority path must remain byte-identical to the old image.
        interrupted_target = root / "interrupted.loam"
        interrupted_stage = root / "interrupted.loam.loam-stage"
        interrupted_target.write_bytes(OLD)
        interrupted_stage.write_bytes(NEW[: len(NEW) // 3])

        if interrupted_target.read_bytes() != OLD:
            raise AssertionError("partial sibling staging changed the authority target")
        if interrupted_stage.read_bytes() in (OLD, NEW):
            raise AssertionError("interruption fixture did not leave a partial stage")

        print(
            "Observation 155 filesystem fixture PASS: "
            f"old_reads={counts[OLD]} new_reads={counts[NEW]} "
            "partial_reads=0 interrupted_target=old"
        )


if __name__ == "__main__":
    main()

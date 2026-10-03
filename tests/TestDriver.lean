def main (args : List String) : IO Unit := do
  let child ← IO.Process.spawn {
    cmd := "bash"
    args := #["tools/test-product"] ++ args.toArray
  }
  let exitCode ← child.wait
  if exitCode != 0 then
    throw (IO.userError s!"test driver exited with code {exitCode}")

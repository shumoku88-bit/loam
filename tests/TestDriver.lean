def main (args : List String) : IO Unit := do
  let output ← IO.Process.run {
    cmd := "bash"
    args := #["tools/test-product"] ++ args.toArray
  }
  IO.print output

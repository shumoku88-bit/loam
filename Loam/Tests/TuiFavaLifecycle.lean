import Loam.Tui.FavaLaunch

open Loam.Tui.FavaLaunch

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def hasUvx : IO Bool := do
  try
    let output ← IO.Process.output { cmd := "which", args := #["uvx"] }
    return output.exitCode == 0
  catch _ =>
    return false

def main : IO Unit := do
  IO.println "Running TUI Fava lifecycle qualification..."

  -- 1. Initial clean state verification
  expect (!(← hasActiveSession)) "Initial state should have no active session"
  expect ((← activeSessionPid?).isNone) "Initial state should have no active PID"

  -- Ensure clean slate: shut down any preexisting session
  shutdown
  expect (!(← hasActiveSession)) "State after shutdown should have no active session"

  unless ← hasUvx do
    IO.println "uvx is not installed in this environment; live Fava spawn skipped, clean state verified."
    return

  let testPort := 5003
  let tempBeancount := "/tmp/loam-test-fava-lifecycle.beancount"
  let tempLog := "/tmp/loam-test-fava-lifecycle.log"
  IO.FS.writeFile tempBeancount "2026-01-01 custom \"test\" \"lifecycle\"\n"

  try
    -- 2. Launch Fava server and verify ownership
    let launchResult ← ensureFavaRunning testPort tempBeancount tempLog
    match launchResult with
    | .error err =>
        throw (IO.userError s!"ensureFavaRunning failed: {err}")
    | .ok newlyStarted =>
        expect newlyStarted "First launch should report newlyStarted = true"

    expect (← hasActiveSession) "After launch, hasActiveSession must be true"
    let pidOpt ← activeSessionPid?
    expect pidOpt.isSome "After launch, activeSessionPid? must be some"
    let pid := pidOpt.get!

    -- Verify PID file was created and contains the correct PID
    let pidFileExists ← defaultPidPath.pathExists
    expect pidFileExists "PID file must exist after launch"
    let pidContent ← IO.FS.readFile defaultPidPath
    expect (pidContent.trimAscii == toString pid)
      s!"PID file content '{pidContent.trimAscii}' did not match child pid {pid}"

    -- Verify server is responding
    expect (← isFavaResponding testPort) "Fava must respond on test port after launch"

    -- 3. Idempotent second launch: must reuse existing owned session
    let secondLaunch ← ensureFavaRunning testPort tempBeancount tempLog
    match secondLaunch with
    | .error err =>
        throw (IO.userError s!"Second ensureFavaRunning failed: {err}")
    | .ok newlyStarted =>
        expect (!newlyStarted) "Second launch must reuse existing instance (newlyStarted = false)"

    let pidAfterSecond ← activeSessionPid?
    expect (pidAfterSecond == some pid) "Second launch must retain identical owned PID"

    -- 4. Clean shutdown: must terminate process group, remove PID file, release port
    shutdown
    expect (!(← hasActiveSession)) "After shutdown, hasActiveSession must be false"
    expect ((← activeSessionPid?).isNone) "After shutdown, activeSessionPid? must be none"

    let pidFileStillExists ← defaultPidPath.pathExists
    expect (!pidFileStillExists) "PID file must be removed after shutdown"

    -- Allow short grace period for sockets to close
    IO.sleep 300
    expect (!(← isFavaResponding testPort))
      "Fava must NOT be responding after shutdown (process group should be terminated)"

    -- 5. Idempotent shutdown: calling shutdown again must be harmless
    shutdown
    expect (!(← hasActiveSession)) "Second shutdown must be harmless"

    IO.println "TUI Fava lifecycle qualification passed: clean startup, reuse, and complete shutdown verified."
  finally
    -- Final cleanup guard
    shutdown
    try IO.FS.removeFile tempBeancount catch _ => pure ()
    try IO.FS.removeFile tempLog catch _ => pure ()

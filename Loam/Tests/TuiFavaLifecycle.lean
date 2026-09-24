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

private partial def waitForResponder (port attemptsLeft : Nat) : IO Bool := do
  if attemptsLeft == 0 then return false
  if ← isFavaResponding port then return true
  IO.sleep 100
  waitForResponder port (attemptsLeft - 1)

def main : IO Unit := do
  IO.println "Running TUI Fava lifecycle qualification..."

  -- 1. Initial clean state verification
  expect (!(← hasActiveSession)) "Initial state should have no active session"
  expect ((← activeSessionPid?).isNone) "Initial state should have no active PID"

  -- Ensure clean slate: shut down any preexisting session
  shutdown
  expect (!(← hasActiveSession)) "State after shutdown should have no active session"

  let testPort := 5003
  let tempBeancount := "/tmp/loam-test-fava-lifecycle.beancount"
  let tempLog := "/tmp/loam-test-fava-lifecycle.log"
  IO.FS.writeFile tempBeancount "2026-01-01 custom \"test\" \"lifecycle\"\n"

  -- An unowned Fava-like service must never be reused as LOAM's current ledger.
  let externalPort := 51373
  let externalDir : System.FilePath := "/tmp/loam-test-external-fava"
  let externalIndex := externalDir / "index.html"
  IO.FS.createDirAll externalDir
  IO.FS.writeFile externalIndex "<html><title>Fava</title><body>beancount external ledger</body></html>\n"
  let externalServer ← IO.Process.spawn {
    cmd := "python3"
    args := #["-m", "http.server", toString externalPort, "--bind", "127.0.0.1",
      "--directory", externalDir.toString]
    stdin := .null
    stdout := .null
    stderr := .null
  }
  try
    expect (← waitForResponder externalPort 30)
      "external Fava-like responder did not become ready"
    let externalResult ← ensureFavaRunning externalPort tempBeancount tempLog
    match externalResult with
    | .ok _ =>
        throw (IO.userError "unowned Fava-like responder was incorrectly reused")
    | .error message =>
        expect (message.contains "not owned by this LOAM session")
          s!"unowned Fava refusal did not explain ownership boundary: {message}"
        expect (message.contains "ledger identity cannot be established")
          s!"unowned Fava refusal did not explain ledger-identity uncertainty: {message}"
    expect (!(← hasActiveSession))
      "refusing an unowned Fava-like responder must not create an owned session"
  finally
    try externalServer.kill catch _ => pure ()
    discard <| externalServer.tryWait
    try IO.FS.removeFile externalIndex catch _ => pure ()

  unless ← hasUvx do
    IO.println "uvx is not installed in this environment; owned live Fava spawn skipped after external-server refusal qualification."
    return

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

    IO.println "TUI Fava lifecycle qualification passed: unowned-server refusal, clean owned startup, reuse, and complete shutdown verified."
  finally
    -- Final cleanup guard
    shutdown
    try IO.FS.removeFile tempBeancount catch _ => pure ()
    try IO.FS.removeFile tempLog catch _ => pure ()

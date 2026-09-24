import Loam.BeancountExportPipeline
import Loam.HouseholdPaths
import Loam.WriterOwnership

namespace Loam.Tui.FavaLaunch

set_option autoImplicit false

def defaultOutputPath : System.FilePath := "/tmp/loam-fava-household.beancount"
def defaultReportPath : System.FilePath := "/tmp/loam-fava-household-report.txt"
def defaultLogPath : System.FilePath := "/tmp/loam-fava.log"
def defaultPidPath : System.FilePath := "/tmp/loam-fava.pid"
def defaultPort : Nat := 5001

private structure OwnedSession where
  child : IO.Process.Child { stdin := .null }
  port : Nat

initialize activeSessionRef : IO.Ref (Option OwnedSession) ← IO.mkRef none

/-- Check if this TUI session currently owns an active Fava process. -/
def hasActiveSession : IO Bool := do
  return (← activeSessionRef.get).isSome

/-- Returns the OS process ID of the owned Fava process, if one is currently active. -/
def activeSessionPid? : IO (Option UInt32) := do
  return (← activeSessionRef.get).map fun s => s.child.pid

/--
Shutdown any Fava server owned by this TUI session.
Terminates the entire process group (setsid) so that both uvx wrapper and python/fava exit.
Cleans up the PID file and reaps the child process to prevent zombies.
-/
def shutdown : IO Unit := do
  if let some session ← activeSessionRef.get then
    activeSessionRef.set none
    try session.child.kill catch _ => pure ()
    discard <| session.child.tryWait
    try IO.FS.removeFile defaultPidPath catch _ => pure ()

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

/--
Check if Fava is healthy and responding to HTTP on the given port.
Verifies that the target service is indeed Fava and not an unrelated web server.
-/
def isFavaResponding (port : Nat) : IO Bool := do
  try
    let output ← IO.Process.output {
      cmd := "curl",
      args := #["-s", "-m", "1", s!"http://127.0.0.1:{port}/"]
    }
    -- Fava's root endpoint redirects and includes characteristic tokens
    return output.exitCode == 0 &&
      (contains "beancount" output.stdout ||
       contains "Fava" output.stdout ||
       contains "income_statement" output.stdout)
  catch _ =>
    return false

/-- Check if port is in LISTEN state by any process -/
def isPortListening (port : Nat) : IO Bool := do
  try
    let output ← IO.Process.output {
      cmd := "lsof",
      args := #["-i", s!":{port}", "-sTCP:LISTEN", "-t"]
    }
    return !output.stdout.trimAscii.isEmpty
  catch _ =>
    return false

/-- Open browser with target URL across macOS and Linux -/
def openBrowser (url : String) : IO Unit := do
  try
    discard <| IO.Process.run { cmd := "open", args := #[url] }
  catch _ =>
    try
      discard <| IO.Process.run { cmd := "xdg-open", args := #[url] }
    catch _ =>
      pure ()

/-- Wait for Fava to become healthy after spawn (polling up to maxAttempts * 200ms) -/
private partial def waitForFavaHealthy (port : Nat) (attemptsLeft : Nat) : IO Bool := do
  if attemptsLeft == 0 then return false
  if ← isFavaResponding port then return true
  IO.sleep 200
  waitForFavaHealthy port (attemptsLeft - 1)

/--
Ensure Fava is running on the given port.
Reuses only a healthy server owned by this TUI session, or launches a new owned
process group. An independently started Fava is refused because a generic HTTP
health check cannot establish which Beancount ledger that process is serving.
Guards against collision with unrelated non-Fava services on the same port.
-/
def ensureFavaRunning (port : Nat) (beancountPath logPath : System.FilePath) : IO (Except String Bool) := do
  -- Check if we already own an active, healthy session on this port
  if let some session ← activeSessionRef.get then
    if session.port == port && (← isFavaResponding port) then
      return .ok false
    else
      shutdown

  -- Never reuse an unowned Fava: health proves service kind, not ledger identity.
  if ← isFavaResponding port then
    return .error s!"Port {port} already serves a Fava process not owned by this LOAM session; served ledger identity cannot be established"

  -- Check if port is occupied by another non-Fava service
  if ← isPortListening port then
    return .error s!"Port {port} is occupied by an unrelated process; choose another port"

  -- Spawn in its own session / process group (setsid) using exec so uvx becomes the group leader.
  -- Redirect stdin from /dev/null so Python runtime does not fail with Errno 9 Bad file descriptor in a detached session.
  -- No trailing '&' is used because IO.Process.spawn runs asynchronously and retains direct Child ownership.
  let cmd := s!"exec uvx --from fava fava --read-only --port {port} {beancountPath.toString} < /dev/null > {logPath.toString} 2>&1"
  let child ←
    try
      IO.Process.spawn {
        cmd := "sh",
        args := #["-c", cmd],
        stdin := .null,
        setsid := true
      }
    catch e =>
      return .error s!"Failed to spawn Fava: {e}"

  let pid := child.pid
  try
    IO.FS.writeFile defaultPidPath s!"{pid}\n"
  catch _ =>
    pure ()

  activeSessionRef.set (some { child := child, port := port })

  -- Wait up to 3 seconds (15 * 200ms) for Fava to start listening
  if ← waitForFavaHealthy port 15 then
    return .ok true
  else
    shutdown
    return .error s!"Fava started but did not respond on port {port}; check {logPath}"

/--
Full launch workflow:
1. Acquires WriterOwnership exclusive lock on actual.loam to prevent dirty read during stage write.
2. Exports canonical Actual into disposable Beancount projection with source overwrite protection.
3. Verifies or spawns Fava in read-only mode with health check.
4. Opens browser only after confirming Fava is responding.
-/
def launch
    (dataDir root : System.FilePath)
    (port : Nat := defaultPort)
    (outputFile : System.FilePath := defaultOutputPath)
    (reportFile : System.FilePath := defaultReportPath) : IO String := do
  let actualPath := Loam.HouseholdPaths.actual root
  let rolePath := Loam.HouseholdPaths.accountingRole dataDir

  -- Protect against dirty reads or concurrent stage replacement
  let exportResult ← Loam.WriterOwnership.withOwnership actualPath do
    Loam.BeancountExportPipeline.exportSuspense actualPath rolePath outputFile reportFile

  match exportResult with
  | .error message =>
      return s!"Fava export refused: {message}"
  | .ok res =>
      match ← ensureFavaRunning port outputFile defaultLogPath with
      | .error message =>
          return s!"Fava server unavailable: {message}"
      | .ok newlyStarted =>
          let url := s!"http://127.0.0.1:{port}"
          if newlyStarted then
            openBrowser url
          let statusNote := if newlyStarted then "started & opened" else "refreshed projection (browser updated)"
          return s!"Exported {res.exportedCount} events ({res.unresolvedEffectCount} suspense) -> Fava {statusNote} at {url}"

end Loam.Tui.FavaLaunch

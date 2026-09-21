import Loam.BeancountExportPipeline
import Loam.WriterOwnership

namespace Loam.Tui.FavaLaunch

set_option autoImplicit false

def defaultOutputPath : System.FilePath := "/tmp/loam-fava-household.beancount"
def defaultReportPath : System.FilePath := "/tmp/loam-fava-household-report.txt"
def defaultLogPath : System.FilePath := "/tmp/loam-fava.log"
def defaultPort : Nat := 5001

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
Reuses healthy existing server or launches a detached background process.
Guards against collision with unrelated non-Fava services on the same port.
-/
def ensureFavaRunning (port : Nat) (beancountPath logPath : System.FilePath) : IO (Except String Bool) := do
  if ← isFavaResponding port then
    return .ok false  -- already running healthy Fava instance

  -- Check if port is occupied by another non-Fava service
  if ← isPortListening port then
    return .error s!"Port {port} is occupied by an unrelated process; choose another port"

  let cmd := s!"uvx --from fava fava --port {port} {beancountPath.toString} > {logPath.toString} 2>&1 &"
  try
    discard <| IO.Process.spawn {
      cmd := "sh",
      args := #["-c", cmd]
    }
  catch e =>
    return .error s!"Failed to spawn Fava: {e}"

  -- Wait up to 3 seconds (15 * 200ms) for Fava to start listening
  if ← waitForFavaHealthy port 15 then
    return .ok true
  else
    return .error s!"Fava started but did not respond on port {port}; check {logPath}"

/--
Full launch workflow:
1. Acquires WriterOwnership exclusive lock on actual.loam to prevent dirty read during stage write.
2. Exports canonical Actual into disposable Beancount projection with source overwrite protection.
3. Verifies or spawns Fava web server with health check.
4. Opens browser only after confirming Fava is responding.
-/
def launch
    (dataDir root : System.FilePath)
    (port : Nat := defaultPort)
    (outputFile : System.FilePath := defaultOutputPath)
    (reportFile : System.FilePath := defaultReportPath) : IO String := do
  let actualPath := root / "actual.loam"
  let rolePath := dataDir / "accounting-role.loam"

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
          openBrowser url
          let statusNote := if newlyStarted then "started & opened" else "reloaded & opened"
          return s!"Exported {res.exportedCount} events ({res.unresolvedEffectCount} suspense) -> Fava {statusNote} at {url}"

end Loam.Tui.FavaLaunch

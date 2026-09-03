import Loam.HistoricalPublisher

/-!
# Historical Actual publisher CLI

The sole publication entrance requires caller approval of the exact PREPARED
manifest digest.  It never prepares a candidate or issues identity.

Note: the `current-actual.journal` source argument is a pre-authority-commit
qualification input only.  Post-commit recovery and completed verification
are fully self-contained in LOAM and never read the external source.
-/

namespace Loam.Cli.HistoricalPublishCli

set_option autoImplicit false

private def usage : String :=
  "Historical Actual authority publisher\n\n" ++
  "  loamHistoricalPublish publish <prepared-bundle> <current-actual.journal> " ++
  "<destination-root> <expected-prepared-manifest-sha256>\n"

def run (args : List String) : IO UInt32 := do
  match args with
  | ["publish", bundle, source, destination, approvedManifestSha] =>
      match ← Loam.HistoricalPublisher.publish
          (System.FilePath.mk bundle)
          (System.FilePath.mk source)
          (System.FilePath.mk destination)
          approvedManifestSha with
      | Except.error message =>
          IO.eprintln s!"loam-historical-publish: {message}"
          return 1
      | Except.ok action =>
          IO.println s!"publish: {repr action}"
          return 0
  | _ =>
      IO.eprintln usage
      return 2

end Loam.Cli.HistoricalPublishCli

def main (args : List String) : IO UInt32 :=
  Loam.Cli.HistoricalPublishCli.run args

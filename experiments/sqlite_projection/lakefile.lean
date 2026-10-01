import Lake
open Lake DSL

package loamSqliteProjectionExperiment

require loam from "../.."
require leansqlite from git
  "https://github.com/leanprover/leansqlite" @
  "6168b7549738a19bc837a1625c60c5d1e5dd8aeb"

lean_exe sqliteProjectionExperiment where
  root := `Main

lean_exe sqliteProjectionScaleBenchmark where
  root := `ScaleBenchmark

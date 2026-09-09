import Loam.Core.LocusAdmission
import Loam.Persistence

namespace Loam.LocusCatalog

open Loam.Core
set_option autoImplicit false

/-!
# Human-readable Locus catalog

`LocusAdmissionVocabulary` remains the authority for which Locus identities may
appear in a new quantity-bearing write. Display metadata is deliberately broader:
it may describe historical/read-only identities so old Actual evidence remains
human-readable without re-admitting those identities for future publication.

A metadata row can never admit a Locus, assign AccountingRole, infer Purpose, or
rewrite historical evidence. Missing metadata always falls back to the stable
opaque token.
-/

structure Metadata where
  token : String
  label : String
  help : String
  deriving Repr, DecidableEq

structure Entry where
  locus : LocusId
  label : String
  help : String
  deriving Repr, DecidableEq

abbrev Catalog := List Entry

private def dropOneTrailingEmpty : List String → List String
  | rows =>
      match rows.reverse with
      | "" :: rest => rest.reverse
      | _ => rows

private def decodeRow? (row : String) : Option Metadata :=
  match row.splitOn "\t" with
  | [token, label, help] =>
      if Loam.Persistence.validToken token && !label.isEmpty && !help.isEmpty then
        some { token := token, label := label, help := help }
      else none
  | _ => none

private def uniqueTokens : List Metadata → Bool
  | [] => true
  | row :: rest =>
      !(rest.any fun other => other.token == row.token) && uniqueTokens rest

/-- Decode display metadata, rejecting malformed rows and duplicate token keys. -/
def decode? (input : String) : Option (List Metadata) := do
  let rows ← (dropOneTrailingEmpty (input.splitOn "\n")).mapM decodeRow?
  if uniqueTokens rows then some rows else none

/-- Lookup is display-only and deliberately does not consult admission. -/
def metadataForToken? (metadata : List Metadata) (token : String) : Option Metadata :=
  metadata.find? fun row => row.token == token

/-- Human-facing label for any current or historical token, with stable-token fallback. -/
def labelForToken (metadata : List Metadata) (token : String) : String :=
  (metadataForToken? metadata token).map (·.label) |>.getD token

/-- Human-facing help for any current or historical token. -/
def helpForToken (metadata : List Metadata) (token : String) : String :=
  (metadataForToken? metadata token).map (·.help) |>.getD ""

/--
Overlay display metadata onto exactly the approved new-write vocabulary.

Metadata for an unapproved or historical-only token is ignored by this operation.
An approved token without metadata remains selectable under its token, so display
configuration can never become a second admission authority.
-/
def forVocabulary
    (vocabulary : LocusAdmissionVocabulary) (metadata : List Metadata) : Catalog :=
  vocabulary.approved.map fun locus =>
    match metadataForToken? metadata locus.token with
    | some row => { locus := locus, label := row.label, help := row.help }
    | none => { locus := locus, label := locus.token, help := "" }

/-- Token-only fallback for absent/unusable presentation metadata. -/
def fallback (vocabulary : LocusAdmissionVocabulary) : Catalog :=
  forVocabulary vocabulary []

/--
Re-scope an already loaded picker catalog to a freshly re-read admission
vocabulary. Historical display metadata never enters this catalog unless the
identity is independently admitted.
-/
def restrict
    (vocabulary : LocusAdmissionVocabulary) (catalog : Catalog) : Catalog :=
  vocabulary.approved.map fun locus =>
    match catalog.find? (fun entry => entry.locus = locus) with
    | some entry => entry
    | none => { locus := locus, label := locus.token, help := "" }

/-- Empty query means “show the whole admitted list”; otherwise match token or label prefix. -/
def search (catalog : Catalog) (query : String) : Catalog :=
  if query.isEmpty then catalog
  else catalog.filter fun entry =>
    query.isPrefixOf entry.locus.token || query.isPrefixOf entry.label

/-- Exact stable-token lookup inside the admitted picker catalog. -/
def exactToken? (catalog : Catalog) (token : String) : Option Entry :=
  catalog.find? fun entry => entry.locus.token == token

/-- Load the complete replaceable display dictionary, including historical-only rows. -/
def loadMetadata (dataDir : System.FilePath) : IO (Except String (List Metadata)) := do
  let path := dataDir / "config" / "locus-catalog.tsv"
  try
    if ← path.pathExists then
      match decode? (← IO.FS.readFile path) with
      | none => return .error "locus catalog config is malformed"
      | some metadata => return .ok metadata
    else
      return .ok []
  catch error =>
    return .error ("locus catalog config unreadable: " ++ error.toString)

/-- Load display metadata and intersect it with one current admission vocabulary. -/
def loadForVocabulary
    (dataDir : System.FilePath) (vocabulary : LocusAdmissionVocabulary) :
    IO (Except String Catalog) := do
  match ← loadMetadata dataDir with
  | .error message => return .error message
  | .ok metadata => return .ok (forVocabulary vocabulary metadata)

end Loam.LocusCatalog

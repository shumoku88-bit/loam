namespace Loam.Tests.Support

def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw (IO.userError message)

def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

def requireOk {α : Type} (value : Except String α) (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error detail => throw (IO.userError (message ++ ": " ++ detail))

end Loam.Tests.Support

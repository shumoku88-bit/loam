{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Brick
import qualified Graphics.Vty as V
import Graphics.Vty.CrossPlatform (mkVty)

-- Synthetic interaction mechanics only. No LOAM files are read or written.
data Surface
  = Home
  | Actual
  | Scheduled
  | RecordDraft
  deriving (Eq, Show)

data State = State
  { currentSurface :: Surface
  , currentDay :: Int
  , currentRow :: Int
  , notice :: String
  }
  deriving (Eq, Show)

data Name = Root
  deriving (Eq, Ord, Show)

selectedAttr :: AttrName
selectedAttr = attrName "selected"

mutedAttr :: AttrName
mutedAttr = attrName "muted"

initialState :: State
initialState = State
  { currentSurface = Home
  , currentDay = 3
  , currentRow = 0
  , notice = ""
  }

days :: [String]
days = ["Sep 3", "Sep 4", "Sep 5", "Sep 6", "Sep 7"]

selectedDay :: State -> String
selectedDay state = days !! clamp 0 4 (currentDay state)

clamp :: Ord a => a -> a -> a -> a
clamp low high = max low . min high

moveDay :: Int -> State -> State
moveDay delta state =
  let next = clamp 0 4 (currentDay state + delta)
      message
        | next == currentDay state && delta < 0 = "Already at the first synthetic day."
        | next == currentDay state && delta > 0 = "Already at the last synthetic day."
        | otherwise = ""
  in state { currentDay = next, notice = message }

moveRow :: Int -> State -> State
moveRow delta state =
  let next = (currentRow state + delta) `mod` 2
  in state { currentRow = next, notice = "" }

calendarCell :: State -> Int -> String -> Widget Name
calendarCell state index label =
  padRight (Pad 1) $
    if currentDay state == index
      then withAttr selectedAttr (str (" " <> label <> " "))
      else str (" " <> label <> " ")

calendarRow :: State -> Widget Name
calendarRow state =
  hBox
    [ str "‹ "
    , calendarCell state 0 "Sep 3"
    , calendarCell state 1 "Sep 4"
    , calendarCell state 2 "Sep 5"
    , calendarCell state 3 "Sep 6"
    , calendarCell state 4 "Sep 7"
    , str "›"
    ]

selectedDayRow :: State -> Widget Name
selectedDayRow state =
  hBox
    [ str "Selected day: "
    , withAttr selectedAttr (str (" " <> selectedDay state <> " "))
    ]

sectionTitle :: Bool -> String -> Widget Name
sectionTitle selected label =
  let content = str ((if selected then "▶ " else "  ") <> label)
  in if selected then withAttr selectedAttr content else content

effectRow :: String -> String -> Widget Name
effectRow locus amount =
  hBox
    [ hLimit 18 (padLeft (Pad 4) (str locus))
    , hLimit 16 (padLeft Max (str amount))
    ]

homeView :: State -> Widget Name
homeView state =
  vBox
    [ str "LOAM UI Prototype 03  [SYNTHETIC / NO WRITES]"
    , withAttr mutedAttr (str "Brick stable-redraw mechanics spike")
    , str ""
    , calendarRow state
    , selectedDayRow state
    , str ""
    , sectionTitle (currentRow state == 0) "Actual"
    , effectRow "PayPay" "-138 JPY"
    , effectRow "coffee" "+138 JPY"
    , str ""
    , sectionTitle (currentRow state == 1) "Scheduled   Sep 10"
    , effectRow "bank" "-50,000 JPY"
    , effectRow "rent" "+50,000 JPY"
    , str ""
    , withAttr mutedAttr (str "←/→ Day    ↑/↓ Select    Enter Open    r Record    q Quit")
    , withAttr mutedAttr (str (notice state))
    ]

actualView :: Widget Name
actualView =
  vBox
    [ str "Actual evidence"
    , str ""
    , str "Sep 5   coffee"
    , effectRow "PayPay" "-138 JPY"
    , effectRow "coffee" "+138 JPY"
    , str ""
    , withAttr mutedAttr (str "The signs show this synthetic movement effect directly.")
    , withAttr mutedAttr (str "Esc/b Back    q Quit")
    ]

scheduledView :: Widget Name
scheduledView =
  vBox
    [ str "Scheduled expectation"
    , str ""
    , str "Sep 10   scheduled-7"
    , effectRow "bank" "-50,000 JPY"
    , effectRow "rent" "+50,000 JPY"
    , str ""
    , withAttr mutedAttr (str "This remains expectation, not Actual evidence.")
    , withAttr mutedAttr (str "r Record Actual mock    Esc/b Back    q Quit")
    ]

recordView :: State -> Widget Name
recordView state =
  vBox
    [ str "Record what happened  [MOCK DRAFT]"
    , str ""
    , selectedDayRow state
    , str "Movement"
    , effectRow "PayPay" "-138 JPY"
    , effectRow "coffee" "+138 JPY"
    , str ""
    , withAttr mutedAttr (str "Nothing is canonical. This prototype cannot write files.")
    , withAttr mutedAttr (str "Enter Mock publish    Esc/b Cancel    q Quit")
    ]

drawUI :: State -> [Widget Name]
drawUI state =
  [ padAll 1 $
      case currentSurface state of
        Home -> homeView state
        Actual -> actualView
        Scheduled -> scheduledView
        RecordDraft -> recordView state
  ]

backHome :: State -> State
backHome state = state { currentSurface = Home, notice = "" }

handleEvent :: BrickEvent Name () -> EventM Name State ()
handleEvent event = do
  state <- get
  case event of
    VtyEvent (V.EvKey (V.KChar 'q') []) -> halt
    VtyEvent (V.EvKey (V.KChar 'Q') []) -> halt
    VtyEvent (V.EvKey V.KEsc [])
      | currentSurface state /= Home -> put (backHome state)
    VtyEvent (V.EvKey (V.KChar 'b') [])
      | currentSurface state /= Home -> put (backHome state)
    VtyEvent (V.EvKey V.KLeft [])
      | currentSurface state == Home -> put (moveDay (-1) state)
    VtyEvent (V.EvKey V.KRight [])
      | currentSurface state == Home -> put (moveDay 1 state)
    VtyEvent (V.EvKey V.KUp [])
      | currentSurface state == Home -> put (moveRow (-1) state)
    VtyEvent (V.EvKey V.KDown [])
      | currentSurface state == Home -> put (moveRow 1 state)
    VtyEvent (V.EvKey V.KEnter []) ->
      case currentSurface state of
        Home ->
          put state
            { currentSurface = if currentRow state == 0 then Actual else Scheduled
            , notice = ""
            }
        RecordDraft ->
          put state
            { currentSurface = Home
            , notice = "MOCK ONLY: no file was written."
            }
        _ -> pure ()
    VtyEvent (V.EvKey (V.KChar 'r') []) ->
      case currentSurface state of
        Home -> put state { currentSurface = RecordDraft, notice = "" }
        Scheduled -> put state { currentSurface = RecordDraft, notice = "" }
        _ -> pure ()
    _ -> pure ()

app :: App State () Name
app = App
  { appDraw = drawUI
  , appChooseCursor = neverShowCursor
  , appHandleEvent = handleEvent
  , appStartEvent = pure ()
  , appAttrMap = const $
      attrMap V.defAttr
        [ (selectedAttr, V.black `on` V.cyan)
        , (mutedAttr, V.withStyle V.defAttr V.dim)
        ]
  }

main :: IO ()
main = do
  let buildVty = mkVty V.defaultConfig
  initialVty <- buildVty
  _ <- customMain initialVty buildVty Nothing app initialState
  pure ()

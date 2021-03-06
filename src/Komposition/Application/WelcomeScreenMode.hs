{-# LANGUAGE ConstraintKinds     #-}
{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE GADTs               #-}
{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE OverloadedLabels    #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE PolyKinds           #-}
{-# LANGUAGE RankNTypes          #-}
{-# LANGUAGE RebindableSyntax    #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators       #-}
module Komposition.Application.WelcomeScreenMode where

import           Komposition.Application.Base

import           Data.Row.Records                     hiding (split)
import           Data.String                          (fromString)
import           System.Directory

import           Komposition.Composition
import           Komposition.Focus
import           Komposition.Library
import           Komposition.Project
import           Komposition.Project.Store
import           Komposition.VideoSettings

import           Komposition.Application.KeyMaps
import           Komposition.Application.TimelineMode

welcomeScreenMode
  :: Application t m
  => Name n
  -> t m (n .== State (t m) WelcomeScreenMode) Empty ()
welcomeScreenMode gui = do
  updateWelcomeScreen gui
  nextEvent gui >>= \case
    OpenExistingProjectClicked -> do
      userDir <- iliftIO getUserDocumentsDirectory
      chooseFile gui (Open Directory) "Open Project Directory" userDir >>= \case
        Just path' -> do
          iliftIO (openExistingProject path') >>= \case
            Left err -> do
              iliftIO (putStrLn ("Opening existing project failed: " <> show err :: Text))
              welcomeScreenMode gui
            Right existingProject' -> toTimelineWithProject gui existingProject'
        Nothing -> welcomeScreenMode gui
    CreateNewProjectClicked -> do
      userDir <- iliftIO getUserDocumentsDirectory
      chooseFile gui (Save Directory) "Choose Project Directory" userDir >>= \case
        Just path' ->
          iliftIO (createNewProject path' initialProject) >>= \case
            Left err -> do
              beep gui
              iliftIO (putStrLn ("Create new project failed: " <> show err :: Text))
              welcomeScreenMode gui
            Right newProject -> toTimelineWithProject gui newProject
        Nothing -> welcomeScreenMode gui
    CommandKeyMappedEvent Cancel -> exit gui
    CommandKeyMappedEvent Help -> do
      help gui [ModeKeyMap STimelineMode (keymaps STimelineMode)]
      welcomeScreenMode gui

toTimelineWithProject
  :: Application t m
  => Name n
  -> ExistingProject
  -> t m (n .== State (t m) 'WelcomeScreenMode) Empty ()
toTimelineWithProject gui project = do
  let model = TimelineModel project initialFocus Nothing (ZoomLevel 1)
  returnToTimeline gui model
  runTimeline model
  where
    runTimeline model =
      timelineMode gui model >>= \case
        TimelineExit model' ->
          dialog gui "Confirm Exit" "Are you sure you want to exit?" [No, Yes] >>>= \case
            Just Yes -> exit gui
            Just No -> runTimeline model'
            Nothing -> runTimeline model'
        TimelineClose -> returnToWelcomeScreen gui >>> welcomeScreenMode gui

data Confirmation
  = Yes
  | No
  deriving (Show, Eq, Enum)

instance DialogChoice Confirmation where
  toButtonLabel = \case
    Yes -> "Yes"
    No -> "No"

initialProject :: Project
initialProject =
  Project
    { _projectName = "Test"
    , _timeline = emptyTimeline
    , _library = Library [] []
    , _videoSettings =
        VideoSettings {_frameRate = 25, _resolution = Resolution 1920 1080}
    , _proxyVideoSettings =
        VideoSettings {_frameRate = 25, _resolution = Resolution 960 540}
    }

initialFocus :: Focus SequenceFocusType
initialFocus = SequenceFocus 0 Nothing

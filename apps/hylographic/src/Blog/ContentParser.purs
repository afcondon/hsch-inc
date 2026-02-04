module Hylographic.Blog.ContentParser where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.String.Regex (Regex, regex, split)
import Data.String.Regex.Flags (global)

-- | Content segment - either HTML text or a viz component reference
data ContentSegment
  = HtmlContent String
  | VizComponent String  -- Component name

derive instance eqContentSegment :: Eq ContentSegment

instance showContentSegment :: Show ContentSegment where
  show (HtmlContent s) = "HtmlContent(" <> show (String.take 50 s) <> "...)"
  show (VizComponent name) = "VizComponent(" <> name <> ")"

-- | Parse markdown content into segments, identifying {{viz:ComponentName}} tags
-- | Returns array of content segments to render
parseContent :: String -> Array ContentSegment
parseContent content =
  case vizRegex of
    Left _ -> [ HtmlContent content ]  -- If regex fails, return as-is
    Right re ->
      let
        parts = split re content
        -- Interleave HTML and viz components
        -- split returns: [before, match1, between, match2, after, ...]
        -- But we need to extract component names from matches
        segments = extractSegments content
      in
        segments

-- | Extract segments by finding all {{viz:...}} patterns
extractSegments :: String -> Array ContentSegment
extractSegments content =
  let
    -- Find all {{viz:...}} patterns and their positions
    -- For simplicity, use a manual approach
    go :: String -> Array ContentSegment -> Array ContentSegment
    go remaining acc =
      case findVizTag remaining of
        Nothing ->
          -- No more viz tags, add remaining content
          if String.null remaining
            then acc
            else acc <> [ HtmlContent remaining ]
        Just { before, componentName, after } ->
          let
            newAcc = if String.null before
              then acc <> [ VizComponent componentName ]
              else acc <> [ HtmlContent before, VizComponent componentName ]
          in
            go after newAcc
  in
    go content []

-- | Find the first {{viz:ComponentName}} tag in a string
findVizTag :: String -> Maybe { before :: String, componentName :: String, after :: String }
findVizTag content =
  case String.indexOf (String.Pattern "{{viz:") content of
    Nothing -> Nothing
    Just startIdx ->
      let
        afterStart = String.drop (startIdx + 6) content  -- Skip "{{viz:"
      in
        case String.indexOf (String.Pattern "}}") afterStart of
          Nothing -> Nothing  -- Malformed tag
          Just endIdx ->
            let
              componentName = String.take endIdx afterStart
              before = String.take startIdx content
              after = String.drop (endIdx + 2) afterStart  -- Skip "}}"
            in
              Just { before, componentName: String.trim componentName, after }

-- | Regex for matching viz tags (used for reference)
vizRegex :: Either String Regex
vizRegex = regex "\\{\\{viz:([^}]+)\\}\\}" global

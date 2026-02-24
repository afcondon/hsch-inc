module Hylographic.RoutingDSL where

import Prelude hiding ((/))

import Hylographic.Types (Route(..))
import Routing.Match (Match, lit, str, end)
import Routing.Match (root) as Match
import Control.Alt ((<|>))

-- | Routing DSL for matching URL paths to Routes
-- |
-- | Routes:
-- |   /        -> Home (force layout index)
-- |   /home    -> Home (alias)
-- |   /post/:slug -> Post slug (article viewer)
routing :: Match Route
routing =
  Match.root *> routes

routes :: Match Route
routes =
  postRoute
  <|> homeRoute
  <|> homeAlias
  <|> rootRedirect
  <|> notFoundRoute

-- | Match: / (redirect to home)
rootRedirect :: Match Route
rootRedirect = Home <$ end

-- | Match: /home
homeAlias :: Match Route
homeAlias = Home <$ lit "home" <* end

-- | Match: / (landing page with force layout)
homeRoute :: Match Route
homeRoute = Home <$ end

-- | Match: /post/:slug
postRoute :: Match Route
postRoute = Post <$> (lit "post" *> str) <* end

-- | Fallback: everything else is NotFound
notFoundRoute :: Match Route
notFoundRoute = pure NotFound

-- | Convert a Route back to a URL path (for links and navigation)
routeToPath :: Route -> String
routeToPath Home = "/"
routeToPath (Post slug) = "/post/" <> slug
routeToPath NotFound = "/not-found"

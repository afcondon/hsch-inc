module Hylographic.Types where

import Prelude

-- | Blog post slug (URL-safe identifier)
type Slug = String

-- | Route in the Hylographic blog
data Route
  = Home          -- Force layout index of all posts
  | Post Slug     -- Individual article view
  | NotFound      -- 404 page

derive instance eqRoute :: Eq Route

instance showRoute :: Show Route where
  show Home = "Home"
  show (Post slug) = "Post: " <> slug
  show NotFound = "Not Found"

-- | Article metadata (from YAML frontmatter)
type ArticleMetadata =
  { slug :: Slug
  , title :: String
  , date :: String
  , tags :: Array String
  }

-- | Graph data for force layout index
type ArticleNode =
  { slug :: Slug
  , title :: String
  , tags :: Array String
  }

type ArticleEdge =
  { source :: Slug
  , target :: Slug
  }

type GraphData =
  { nodes :: Array ArticleNode
  , edges :: Array ArticleEdge
  }

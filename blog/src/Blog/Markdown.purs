module Hylographic.Blog.Markdown where

import Prelude
import Effect (Effect)

-- | Parse markdown to HTML using marked.js
foreign import parseMarkdown :: String -> String

-- | Highlight all code blocks on the page using Prism.js
foreign import highlightAll :: Effect Unit

-- | Highlight a specific code element
foreign import highlightElement :: String -> Effect Unit

-- | Shared utility functions
module Hylograph.Shared.Utilities
  ( highlightAllLineNumbers
  ) where

import Prelude
import Effect (Effect)

-- | Trigger Prism.js syntax highlighting on all code blocks
foreign import highlightAllLineNumbers :: Effect Unit

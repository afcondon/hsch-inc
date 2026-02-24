module Main where

import Prelude
import Effect (Effect)

-- Foreign import for Python's print()
foreign import printLine :: String -> Effect Unit

main :: Effect Unit
main = printLine "Hello from PureScript on Python!"

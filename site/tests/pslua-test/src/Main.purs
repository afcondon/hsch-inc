-- PureScript Lua Test (Minimal)
-- Pure computation - no FFI dependencies
-- Demonstrates pslua compilation without Effect
module Main where

-- Simple algebraic data type
data Color = Red | Green | Blue

-- Pattern matching on ADT
colorToNumber :: Color -> Int
colorToNumber Red = 1
colorToNumber Green = 2
colorToNumber Blue = 3

-- Record type
type Person = { name :: String, age :: Int }

-- Record access
getName :: Person -> String
getName p = p.name

-- Main entry point (exports a value)
main :: Int
main = colorToNumber Green

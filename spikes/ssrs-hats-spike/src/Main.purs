-- | SSRS + HATS Spike
-- |
-- | Goal: Explore whether ssrs can handle heterogeneous transformations:
-- |   - Rose tree in → flat SVG circles out
-- |   - Rose tree in → nested DOM structure out
-- |   - Arbitrary input structure → arbitrary output structure
module Main where

import Prelude

import Data.Array as Array
import Data.Bifunctor (class Bifunctor)
import Data.Functor.Mu (Mu(..), roll)
import Data.Maybe (Maybe(..))
import Data.Traversable (traverse)
import Data.Tuple (Tuple(..))
import Dissect.Class (class Dissect, yield, return) as Dissect
import Effect (Effect)
import Effect.Console (log, logShow)
import SSRS (Algebra, Coalgebra, cata, ana, hylo)

-- ============================================================================
-- Part 1: Input Structure (Rose Tree)
-- ============================================================================

-- | Pattern functor for rose trees.
-- | A node has a label and an array of children.
data RoseF a = RoseF String (Array a)

derive instance Functor RoseF

-- | For Dissect, we need a bifunctor representing "partially processed" state.
-- | This is the "clown/joker" structure from McBride's paper.
-- |
-- | RoseQ c j represents: we're partway through processing children
-- |   - c: "clowns" - already processed children (to our left)
-- |   - j: "jokers" - not yet processed children (to our right)
data RoseQ c j = RoseQ String (Array c) (Array j)

derive instance Bifunctor RoseQ

-- | Dissect instance for RoseF.
-- | This enables stack-safe recursion.
instance Dissect.Dissect RoseF RoseQ where
  -- init: Start processing a RoseF node
  -- We yield the first child (if any) with the rest as jokers
  init (RoseF label children) = case Array.uncons children of
    Nothing ->
      -- No children, return the completed structure
      Dissect.return (RoseF label [])
    Just { head, tail } ->
      -- Yield first child, store rest as jokers
      Dissect.yield head (RoseQ label [] tail)

  -- next: Process the next child after receiving a processed value
  next (RoseQ label clowns jokers) val = case Array.uncons jokers of
    Nothing ->
      -- All children processed, return completed structure
      Dissect.return (RoseF label (Array.snoc clowns val))
    Just { head, tail } ->
      -- More to process, yield next joker
      Dissect.yield head (RoseQ label (Array.snoc clowns val) tail)

-- | The recursive rose tree type
type RoseTree = Mu RoseF

-- | Smart constructor for rose tree nodes
rose :: String -> Array RoseTree -> RoseTree
rose label children = roll (RoseF label children)

-- | Leaf node (no children)
leaf :: String -> RoseTree
leaf label = rose label []


-- ============================================================================
-- Part 2: Output Structures
-- ============================================================================

-- | A flat circle representation (what we'd send to SVG)
type Circle = { label :: String, depth :: Int }

-- | A nested DOM-like structure
data DOMNode
  = Element String (Array DOMNode)  -- <g>...</g>
  | Circle String                   -- <circle data-label="..."/>

instance Show DOMNode where
  show (Circle label) = "<circle:" <> label <> "/>"
  show (Element tag children) =
    "<" <> tag <> ">" <> Array.intercalate "" (map show children) <> "</" <> tag <> ">"


-- ============================================================================
-- Part 3: Algebras (Different Output Shapes)
-- ============================================================================

-- | Algebra 1: Flatten tree to array of circles
-- |
-- | Rose tree → Array Circle (flat!)
-- |
-- | The key insight: the result type `Array Circle` is FLAT even though
-- | the input functor `RoseF` is TREE-shaped. The algebra decides output shape.
flattenAlgebra :: Algebra RoseF (Array Circle)
flattenAlgebra (RoseF label children) =
  -- This node becomes a circle, then concat all children's circles
  [ { label, depth: 0 } ] <> Array.concat children

-- | Algebra 1b: Flatten with depth tracking
-- |
-- | Uses a function to thread depth through
flattenWithDepth :: Int -> Algebra RoseF (Array Circle)
flattenWithDepth depth (RoseF label children) =
  [ { label, depth } ] <> Array.concat (map (map (addDepth 1)) children)
  where
  addDepth d c = c { depth = c.depth + d }

-- | Algebra 2: Preserve structure as nested DOM
-- |
-- | Rose tree → DOMNode (nested!)
-- |
-- | Same input, different algebra, different output structure.
nestAlgebra :: Algebra RoseF DOMNode
nestAlgebra (RoseF label children) =
  case children of
    [] -> Circle label
    _  -> Element "g" (Array.cons (Circle label) children)


-- ============================================================================
-- Part 4: Coalgebras (Building Trees)
-- ============================================================================

-- | Coalgebra: Build a rose tree from a seed
-- |
-- | This shows how ana (unfold) works with ssrs.
numberedTreeCoalg :: Coalgebra RoseF { prefix :: String, depth :: Int, width :: Int }
numberedTreeCoalg { prefix, depth, width } =
  if depth <= 0
  then RoseF prefix []
  else RoseF prefix (Array.mapWithIndex mkChild (Array.replicate width unit))
  where
  mkChild i _ = { prefix: prefix <> "." <> show i, depth: depth - 1, width }


-- ============================================================================
-- Part 5: Hylomorphism (Unfold + Fold, Same Functor)
-- ============================================================================

-- | Hylo: Generate a tree AND flatten it in one fused pass
-- |
-- | The intermediate tree is NEVER materialized! The coalgebra produces
-- | one layer, the algebra immediately consumes it.
generateAndFlatten
  :: { prefix :: String, depth :: Int, width :: Int }
  -> Array Circle
generateAndFlatten = hylo flattenAlgebra numberedTreeCoalg


-- ============================================================================
-- Part 6: The Hard Case - Different Input/Output Functors
-- ============================================================================

-- | What if our INPUT is one recursive type and OUTPUT is another?
-- |
-- | Example: External rose tree → HATS tree (different functor)
-- |
-- | Standard hylo can't do this directly because it uses same functor.
-- | Options:
-- |   1. Natural transformation: RoseF ~> HATSF (if structures are compatible)
-- |   2. Two-phase: cata input -> intermediate value -> ana output
-- |   3. Custom fused combinator

-- | A different output functor (simplified HATS - for natural transformation demo)
data SimpleHATSF a
  = SimpleElemF String (Array a)
  | SimpleTextF String

derive instance Functor SimpleHATSF

-- We'd need Dissect SimpleHATSF for this to work with ssrs...
-- For now, let's just show the natural transformation approach

-- | Natural transformation: RoseF → SimpleHATSF
-- |
-- | This works when the structures are "compatible enough"
roseToHATS :: RoseF ~> SimpleHATSF
roseToHATS (RoseF label children) =
  case children of
    [] -> SimpleTextF label  -- Leaf becomes text
    _  -> SimpleElemF "g" children  -- Branch becomes group

-- ============================================================================
-- Part 6b: Heterogeneous via Coproduct Functor
-- ============================================================================

-- | What if we use a COPRODUCT of functors as the intermediate?
-- |
-- | This is the "Data Types à la Carte" approach from the Catana paper.
-- | The pattern functor is (InputF :+: OutputF), allowing both shapes.

-- For simplicity, let's just show the "embed then interpret" pattern:

-- | Universal intermediate: just carry the data through
data CarrierF a = CarrierF
  { label :: String
  , depth :: Int
  , children :: Array a
  , isLeaf :: Boolean
  }

derive instance Functor CarrierF

-- | Coalgebra: Rose tree → Carrier (adds depth info)
roseToCarrier :: Int -> RoseTree -> CarrierF RoseTree
roseToCarrier depth (In (RoseF label children)) = CarrierF
  { label
  , depth
  , children
  , isLeaf: Array.null children
  }

-- | Algebra: Carrier → flat circles (uses depth!)
carrierToCircles :: CarrierF (Array Circle) -> Array Circle
carrierToCircles (CarrierF { label, depth, children }) =
  [ { label, depth } ] <> Array.concat children

-- Unfortunately we can't use hylo directly here because we'd need:
-- hylo :: Algebra CarrierF v -> Coalgebra CarrierF w -> w -> v
-- But our coalgebra produces CarrierF from RoseTree, not from CarrierF.
--
-- The issue: coalgebra type is `w -> p w` meaning the OUTPUT of coalgebra
-- feeds back as input. But we want RoseTree -> CarrierF RoseTree where
-- RoseTree ≠ CarrierF.

-- ============================================================================
-- Part 6c: The Key Insight - Accumulating Algebra
-- ============================================================================

-- | THE SOLUTION: Thread extra state through the algebra!
-- |
-- | Instead of trying to use different functors, we use the SAME functor
-- | but the algebra accumulates/transforms as it folds.
-- |
-- | Rose tree with depth tracking via paramorphism-style accumulator:
flattenWithDepthAlgebra :: Algebra RoseF (Int -> Array Circle)
flattenWithDepthAlgebra (RoseF label childFns) = \depth ->
  let
    thisCircle = { label, depth }
    childCircles = Array.concat $ map (\f -> f (depth + 1)) childFns
  in
    [ thisCircle ] <> childCircles

-- | Now we can track depth WITHOUT changing the functor!
flattenWithRealDepth :: RoseTree -> Array Circle
flattenWithRealDepth tree = cata flattenWithDepthAlgebra tree 0


-- ============================================================================
-- Part 7: Extracting Structure Without Flattening
-- ============================================================================

-- | Paramorphism: Access both the folded result AND original substructure
-- |
-- | This lets us "see" the original tree while folding.
-- | Useful for: context-aware rendering, parent-child relationships
-- |
-- | para :: GAlgebra (Tuple (Mu p)) p v -> Mu p -> v
-- | where GAlgebra w p v = p (w v) -> v
-- |
-- | Each child is a Tuple (original subtree, folded result)

-- Import would be: import SSRS (para)
-- paraAlgebra :: RoseF (Tuple RoseTree DOMNode) -> DOMNode
-- paraAlgebra (RoseF label children) =
--   let
--     -- We can inspect original subtrees!
--     originals = map fst children
--     folded = map snd children
--   in
--     Element "g" (Array.cons (Circle label) folded)


-- ============================================================================
-- Part 8: HATS-like Pattern Functor
-- ============================================================================

-- | Element types (simplified from HATS)
data ElemType = SVG | Group | Circle_ | Rect | Text_

derive instance Eq ElemType

instance Show ElemType where
  show SVG = "svg"
  show Group = "g"
  show Circle_ = "circle"
  show Rect = "rect"
  show Text_ = "text"

-- | Static attributes (simplified)
type Attr = { name :: String, value :: String }

-- | HATS-like pattern functor (named TreeF to match HATS naming)
-- |
-- | This mirrors the actual HATS Tree structure, but as a functor.
-- | The key insight: children are the recursive positions.
data TreeF a
  = TreeElemF
      { elemType :: ElemType
      , attrs :: Array Attr
      , children :: Array a
      }
  | TreeEmptyF

derive instance Functor TreeF

-- | Dissect bifunctor for TreeF
-- |
-- | Tracks clowns (processed) and jokers (unprocessed) children.
data TreeQ c j
  = TreeElemQ
      { elemType :: ElemType
      , attrs :: Array Attr
      , clowns :: Array c
      , jokers :: Array j
      }

derive instance Bifunctor TreeQ

-- | Dissect instance for TreeF
instance Dissect.Dissect TreeF TreeQ where
  init = case _ of
    TreeEmptyF -> Dissect.return TreeEmptyF
    TreeElemF spec -> case Array.uncons spec.children of
      Nothing -> Dissect.return (TreeElemF spec { children = [] })
      Just { head, tail } -> Dissect.yield head
        (TreeElemQ { elemType: spec.elemType, attrs: spec.attrs, clowns: [], jokers: tail })

  next (TreeElemQ spec) val = case Array.uncons spec.jokers of
    Nothing -> Dissect.return
      (TreeElemF { elemType: spec.elemType, attrs: spec.attrs, children: Array.snoc spec.clowns val })
    Just { head, tail } -> Dissect.yield head
      (TreeElemQ spec { clowns = Array.snoc spec.clowns val, jokers = tail })

-- | The recursive HATS tree type
type HATSTree = Mu TreeF

-- | Smart constructor
elem_ :: ElemType -> Array Attr -> Array HATSTree -> HATSTree
elem_ et attrs children = roll (TreeElemF { elemType: et, attrs, children })

-- | Empty tree
empty :: HATSTree
empty = roll TreeEmptyF

-- | Group element
group :: Array Attr -> Array HATSTree -> HATSTree
group = elem_ Group

-- | Circle element
circle :: Array Attr -> HATSTree
circle attrs = elem_ Circle_ attrs []

-- ============================================================================
-- Part 9: HATS Algebras - Effect-producing interpretation
-- ============================================================================

-- | Mock DOM representation
data MockDOM
  = MockElement ElemType (Array Attr) (Array MockDOM)
  | MockEmpty

instance Show MockDOM where
  show MockEmpty = "(empty)"
  show (MockElement et attrs children) =
    "<" <> show et <> attrsStr <> ">" <>
    Array.intercalate "" (map show children) <>
    "</" <> show et <> ">"
    where
    attrsStr = if Array.null attrs
      then ""
      else " " <> Array.intercalate " " (map (\a -> a.name <> "=" <> show a.value) attrs)

-- | Pure algebra: HATS → MockDOM
-- |
-- | This demonstrates that cata works for tree → nested DOM structure.
hatsToMockDOM :: Algebra TreeF MockDOM
hatsToMockDOM = case _ of
  TreeEmptyF -> MockEmpty
  TreeElemF spec ->
    MockElement spec.elemType spec.attrs spec.children

-- | Effect-producing algebra: HATS → Effect Unit
-- |
-- | In the real interpreter, this would manipulate the actual DOM.
-- | For demonstration, we log what would happen.
hatsToEffectAlgebra :: Algebra TreeF (Effect Unit)
hatsToEffectAlgebra = case _ of
  TreeEmptyF -> pure unit
  TreeElemF spec -> do
    log $ "CREATE <" <> show spec.elemType <> ">"
    _ <- traverse (\attr -> log $ "  SET " <> attr.name <> "=" <> attr.value) spec.attrs
    -- Children are already Effect Unit - run them
    _ <- traverse identity spec.children
    log $ "CLOSE </" <> show spec.elemType <> ">"

-- | Accumulating algebra: HATS → (parent → Effect Element)
-- |
-- | Thread parent context through the fold.
-- | Result type is a function that takes parent and creates child elements.
hatsToParentedAlgebra :: Algebra TreeF (MockDOM -> Array MockDOM)
hatsToParentedAlgebra = case _ of
  TreeEmptyF -> \_ -> []
  TreeElemF spec -> \_parent ->
    let
      -- Build children into this element
      thisElem = MockElement spec.elemType spec.attrs []
      childFns = spec.children
      builtChildren = Array.concatMap (\f -> f thisElem) childFns
      final = MockElement spec.elemType spec.attrs builtChildren
    in [final]


-- ============================================================================
-- Main: Run the experiments
-- ============================================================================

main :: Effect Unit
main = do
  log "=== SSRS + HATS Spike ==="
  log ""

  -- Build a sample tree
  let sampleTree =
        rose "root"
          [ rose "a"
              [ leaf "a1"
              , leaf "a2"
              ]
          , rose "b"
              [ leaf "b1" ]
          , leaf "c"
          ]

  log "Input tree: root -> [a -> [a1, a2], b -> [b1], c]"
  log ""

  -- Experiment 1: Flatten to array
  log "--- Experiment 1: cata flattenAlgebra ---"
  log "Rose tree → Array Circle (FLAT output)"
  let flattened = cata flattenAlgebra sampleTree
  log $ "Result: " <> show (map _.label flattened)
  log $ "Count: " <> show (Array.length flattened)
  log ""

  -- Experiment 2: Preserve as nested DOM
  log "--- Experiment 2: cata nestAlgebra ---"
  log "Rose tree → DOMNode (NESTED output)"
  let nested = cata nestAlgebra sampleTree
  log $ "Result: " <> show nested
  log ""

  -- Experiment 3: Hylo - generate AND flatten in one pass
  log "--- Experiment 3: hylo (fused unfold+fold) ---"
  log "Seed → [virtual tree] → Array Circle"
  let hyloResult = generateAndFlatten { prefix: "n", depth: 2, width: 2 }
  log $ "Result: " <> show (map _.label hyloResult)
  log $ "Count: " <> show (Array.length hyloResult)
  log "(Intermediate tree was NEVER materialized!)"
  log ""

  -- Experiment 4: Ana - build tree from seed
  log "--- Experiment 4: ana (unfold) ---"
  log "Seed → Rose tree"
  let generated = ana numberedTreeCoalg { prefix: "x", depth: 2, width: 2 }
  let genFlat = cata flattenAlgebra generated
  log $ "Generated then flattened: " <> show (map _.label genFlat)
  log ""

  -- Experiment 5: Accumulating algebra (threading extra state)
  log "--- Experiment 5: Accumulating Algebra (depth tracking) ---"
  log "Rose tree → Array Circle with REAL depth values"
  let withDepth = flattenWithRealDepth sampleTree
  log $ "Result: " <> show (map (\c -> c.label <> "@" <> show c.depth) withDepth)
  log "(Depth tracked WITHOUT changing functor!)"
  log ""

  log "=== Findings ==="
  log ""
  log "WORKS GREAT:"
  log "1. cata: tree → flat array (algebra decides output shape)"
  log "2. cata: tree → nested DOM (same mechanism, different algebra)"
  log "3. hylo: fused unfold+fold, intermediate is VIRTUAL"
  log "4. Accumulating algebra: thread extra state (depth, context) via function type"
  log ""
  log "LIMITATION:"
  log "5. hylo requires SAME pattern functor on both sides"
  log "   - Coalgebra: seed → P seed (unfolds using P)"
  log "   - Algebra: P result → result (folds using P)"
  log "   - Can't do: InputF input → OutputF output directly"
  log ""
  log "SOLUTIONS FOR HETEROGENEOUS:"
  log "6. Accumulating algebra: Algebra p (Ctx → Result) threads context"
  log "7. Natural transformation: If InputF ≅ OutputF, use transMu"
  log "8. Two-phase: cata input → intermediate → ana output (materializes)"
  log "9. À la carte: Coproduct functor (InputF :+: OutputF) encompasses both"
  log ""
  log "FOR HATS:"
  log "- Use cata for HATS → DOM (interpreter is an algebra)"
  log "- Building HATS from data can be regular functions OR coalgebra+ana"
  log "- If HATS IS the pattern functor, hylo works: data → HATS → DOM"
  log "- Key: make HATSF flexible enough to represent the intermediate!"
  log ""

  -- =========================================================================
  -- HATS-specific experiments
  -- =========================================================================

  log "=== HATS-Specific Experiments ==="
  log ""

  -- Build a sample HATS tree
  let hatsTree =
        group [ { name: "class", value: "container" } ]
          [ group [ { name: "class", value: "nodes" } ]
              [ circle [ { name: "cx", value: "100" }, { name: "cy", value: "50" }, { name: "r", value: "10" } ]
              , circle [ { name: "cx", value: "200" }, { name: "cy", value: "50" }, { name: "r", value: "15" } ]
              ]
          , group [ { name: "class", value: "links" } ]
              [ elem_ Rect [ { name: "x", value: "100" }, { name: "width", value: "100" } ] []
              ]
          ]

  log "Input HATS tree:"
  log "  <g class='container'>"
  log "    <g class='nodes'>"
  log "      <circle cx=100 cy=50 r=10/>"
  log "      <circle cx=200 cy=50 r=15/>"
  log "    </g>"
  log "    <g class='links'>"
  log "      <rect x=100 width=100/>"
  log "    </g>"
  log "  </g>"
  log ""

  -- Experiment 6: HATS → MockDOM (preserves structure)
  log "--- Experiment 6: HATS → MockDOM via cata ---"
  let mockDOM = cata hatsToMockDOM hatsTree
  log $ "Result: " <> show mockDOM
  log ""

  -- Experiment 7: HATS → Effect (logs DOM operations)
  log "--- Experiment 7: HATS → Effect via cata ---"
  log "Simulating DOM creation:"
  cata hatsToEffectAlgebra hatsTree
  log ""

  log "=== HATS Adoption Path ==="
  log ""
  log "1. HATSF pattern functor works for static tree structure (Elem/Empty)"
  log "2. Effect-producing algebras work: Algebra HATSF (Effect Unit)"
  log "3. Accumulating algebras thread context: Algebra HATSF (Parent → Result)"
  log ""
  log "4. MkFold/SomeFold challenge:"
  log "   - Folds contain template :: a -> Tree which creates DYNAMIC structure"
  log "   - This isn't a fixed recursive position - it's runtime generation"
  log ""
  log "5. Recommended approach:"
  log "   - Handle Fold SEPARATELY: expand folds, THEN cata the result"
  log "   - Or: pre-process folds into expanded Elem trees before interpretation"
  log "   - The GUP (enter/update/exit) logic remains imperative with Effect"

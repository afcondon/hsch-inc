---
title: "SSRS Integration for HATS"
category: research
status: active
date: 2026-01-31
tags: [recursion-schemes, ssrs, hats, hylograph, stack-safety]
---

# SSRS Integration for HATS

## Summary

Spike exploring whether [purescript-ssrs](https://github.com/purefunctor/purescript-ssrs) can be adopted for HATS (Hylomorphic Abstract Tree Syntax). The library provides stack-safe recursion schemes via Conor McBride's dissection technique.

**Verdict**: Partially adopt. Use ssrs for the *interpretation* side (HATS → DOM is a cata). Keep input side (data → HATS) as regular functions for now.

## What SSRS Provides

```
purescript-fixed-points     Mu (least fixpoint)
         ↓
purescript-dissect          Dissect typeclass (stack-safe traversal)
         ↓
purescript-ssrs             cata, ana, hylo, para, histo, zygo, apo, futu...
```

Key types:
```purescript
newtype Mu f = In (f (Mu f))           -- Recursive type
type Algebra p v = p v -> v             -- Fold
type Coalgebra p v = v -> p v           -- Unfold
cata :: Dissect p q => Algebra p v -> Mu p -> v
hylo :: Dissect p q => Algebra p v -> Coalgebra p w -> w -> v
```

## Spike Results

See `spikes/ssrs-hats-spike/` for working code.

### What Works Perfectly

1. **Cata with flattening**: Tree structure → flat array
   ```purescript
   flattenAlgebra :: Algebra RoseF (Array Circle)
   flattenAlgebra (RoseF label children) =
     [ { label, depth: 0 } ] <> concat children

   cata flattenAlgebra tree  -- Tree → [circle, circle, ...]
   ```

2. **Cata with nesting**: Same tree → nested DOM
   ```purescript
   nestAlgebra :: Algebra RoseF DOMNode
   nestAlgebra (RoseF label children) =
     case children of
       [] -> Circle label
       _  -> Element "g" (cons (Circle label) children)
   ```

3. **Hylo with fusion**: Unfold + fold with NO intermediate materialization
   ```purescript
   generateAndFlatten = hylo flattenAlgebra seedCoalgebra
   -- Intermediate tree is VIRTUAL
   ```

4. **Accumulating algebra**: Thread context (depth, parent, etc.)
   ```purescript
   -- Result type is a FUNCTION that receives context
   withDepth :: Algebra RoseF (Int -> Array Circle)
   withDepth (RoseF label childFns) = \depth ->
     [ { label, depth } ] <> concat (map (\f -> f (depth+1)) childFns)
   ```

### The Limitation

**Hylo requires the SAME pattern functor on both sides.**

```purescript
hylo :: Algebra p v -> Coalgebra p w -> w -> v
--               ^                ^
--               Same p!
```

Can't directly do `InputF input → OutputF output` if InputF ≠ OutputF.

### Solutions for Heterogeneous Transformations

1. **Accumulating algebra** - Thread extra state via function type
2. **Natural transformation** - If `InputF ≅ OutputF`, use `transMu`
3. **Two-phase** - `cata input → value → ana output` (materializes intermediate)
4. **À la carte** - Coproduct functor `(InputF :+: OutputF)` encompasses both
5. **Make intermediate flexible** - If HATS IS the functor, it must represent all shapes

## Implications for HATS

### Current HATS Structure
```purescript
data Tree
  = Elem { elemType, attrs, children :: Array Tree, behaviors }
  | MkFold SomeFold  -- Existentially-wrapped iteration
  | Empty
```

### With SSRS (Pattern Functor)
```purescript
data TreeF a
  = ElemF ElementType (Array Attr) (Array a) (Array ThunkedBehavior)
  | FoldF SomeFold
  | EmptyF

type Tree = Mu TreeF

-- Interpreter becomes an algebra
interpretToD3 :: Algebra TreeF (Effect Unit)
```

### The Awkwardness: MkFold / FoldF

The existential `SomeFold` inside the functor is awkward because:
- It's not itself a recursive position
- It contains its own enumeration (coalgebra-like)
- It breaks the clean functor structure

Options:
1. **Remove FoldF** - Always expand folds before creating Tree
2. **Two-level** - Outer Tree, inner Fold, interpret separately
3. **Accept hybrid** - Use ssrs for Elem nodes, handle Fold specially

### Recommendation

**Phase 1: Adopt ssrs for interpretation**
- Make `TreeF` a proper pattern functor (without FoldF initially)
- `cata interpretToD3 :: Mu TreeF -> Effect Unit`
- Stack-safe, principled, matches the "Hylograph" name

**Phase 2: Handle Fold separately**
- `forEach` builds `Mu TreeF` directly (expand during construction)
- Or: interpret Fold as a separate pass before main cata

**Defer: Full hylo**
- Requires making "build HATS from data" a proper coalgebra
- May be overkill for most use cases
- Keep as regular functions unless bottleneck appears

## Dissect Instance for HATSF

Will need a `Dissect TreeF TreeQ` instance. The dissect library supports generic deriving for simple cases, but HATSF's array children may need manual implementation.

Example from spike:
```purescript
data RoseQ c j = RoseQ String (Array c) (Array j)

instance Dissect RoseF RoseQ where
  init (RoseF label children) = case uncons children of
    Nothing -> return (RoseF label [])
    Just { head, tail } -> yield head (RoseQ label [] tail)

  next (RoseQ label clowns jokers) val = case uncons jokers of
    Nothing -> return (RoseF label (snoc clowns val))
    Just { head, tail } -> yield head (RoseQ label (snoc clowns val) tail)
```

## Practical HATS-Specific Findings

The spike extended to test HATS-like structures directly. Key validated patterns:

### TreeF Pattern Functor (Working)

```purescript
data TreeF a
  = TreeElemF
      { elemType :: ElemType
      , attrs :: Array Attr
      , children :: Array a       -- Recursive positions!
      }
  | TreeEmptyF

type HATSTree = Mu TreeF
```

### Dissect Instance (Working)

```purescript
data TreeQ c j = TreeElemQ
  { elemType :: ElemType
  , attrs :: Array Attr
  , clowns :: Array c        -- Processed children
  , jokers :: Array j        -- Unprocessed children
  }

instance Dissect TreeF TreeQ where
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
```

### Effect-Producing Algebra (Working)

```purescript
-- Produces nested DOM structure via Effect
hatsToEffectAlgebra :: Algebra TreeF (Effect Unit)
hatsToEffectAlgebra = case _ of
  TreeEmptyF -> pure unit
  TreeElemF spec -> do
    log $ "CREATE <" <> show spec.elemType <> ">"
    traverse_ (\attr -> log $ "  SET " <> attr.name <> "=" <> attr.value) spec.attrs
    -- Children are Effect Unit - run them in order
    traverse_ identity spec.children
    log $ "CLOSE </" <> show spec.elemType <> ">"
```

Output demonstrates correct nesting:
```
CREATE <g>
  SET class=container
CREATE <g>
  SET class=nodes
CREATE <circle>
  ...
CLOSE </circle>
...
```

### The MkFold Challenge (Unsolved)

The current HATS `MkFold SomeFold` is problematic for ssrs because:

1. **Dynamic structure**: `template :: a -> Tree` creates NEW trees at runtime based on data
2. **Not a recursive position**: The fold's enumeration happens at interpretation time
3. **GUP complexity**: Enter/update/exit logic requires Effect and imperative diffing

This is fundamentally different from static recursive structure that ssrs is designed for.

### Practical Adoption Path

**Phase 1 (Now)**: Use ssrs for the "static" subtrees
- After folds are expanded, children are static recursive positions
- `cata hatsToD3Algebra :: Mu TreeF -> Effect Unit`
- Keep fold handling in imperative code

**Phase 2 (Later)**: Fold expansion as pre-pass
- `expandFolds :: Tree -> Tree` removes all MkFolds by expansion
- Then entire tree can use cata
- Trade-off: Loses deferred evaluation benefits

**Hybrid (Recommended)**: The interpreter already does this naturally
- Pattern match on Tree constructors
- For `Elem`: process with ssrs-style algebra logic
- For `MkFold`: handle GUP imperatively with Effect
- The "algebra" is conceptual, but code structure is the same

## References

- [purescript-ssrs](https://github.com/purefunctor/purescript-ssrs) - Stack-safe recursion schemes
- [purescript-dissect](https://github.com/PureFunctor/purescript-dissect) - Dissection typeclass
- [Clowns to the Left of me, Jokers to the Right](https://dl.acm.org/doi/abs/10.1145/1328438.1328474) - McBride's paper
- [Tim Williams's recursion-schemes slides](https://github.com/willtim/recursion-schemes/) - Derivations of schemes
- Spike: `spikes/ssrs-hats-spike/`

module Main where

import Prelude

import Effect (Effect)
import Effect.Aff (Aff)
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.VDom.Driver (runUI)
import Hylograph.LibShell as Shell

-- | Library configuration
config :: Shell.LibConfig
config =
  { name: "psd3-music"
  , title: "Music"
  , tagline: "Audio interpreter for PSD3 - Data Sonification and Accessibility"
  , version: "0.1.0"
  , github: "afcondon/purescript-psd3-music"
  , docsPath: "/docs/music"
  , polyglotUrl: "/"
  }

-- | Main entry point
main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  runUI component unit body

-- | Page component (stateless)
component :: forall q i o. H.Component q i o Aff
component = H.mkComponent
  { initialState: \_ -> unit
  , render
  , eval: H.mkEval H.defaultEval
  }

render :: forall m. Unit -> H.ComponentHTML Unit () m
render _ =
  Shell.shell config
    [ Shell.heroWithViz config heroText heroViz
    , Shell.elaboration
        [ { heading: "Vision"
          , content:
              [ Shell.para "This package explores data sonification by implementing an audio interpreter for the PSD3 tagless DSL. The same PSD3 code that creates visual charts can be interpreted as sound, making data accessible through hearing rather than sight."
              ]
          }
        , { heading: "1. Accessibility"
          , content:
              [ Shell.para "Data visualization is inherently visual, excluding:"
              , Shell.para "Unsighted or visually impaired users"
              , Shell.para "Users with visual attention occupied (pilots, drivers, surgeons)"
              , Shell.para "Situations where visual displays are impractical"
              , Shell.para "Audio provides an alternative modality for data comprehension. Just as a scatter plot reveals patterns spatially, a sonification can reveal patterns temporally and spectrally."
              ]
          }
        , { heading: "2. Demonstrating Finally Tagless"
          , content:
              [ Shell.para "This package proves that PSD3's tagless architecture truly separates description from interpretation:"
              , Shell.para "Same PSD3 program"
              , Shell.para "Multiple interpreters: D3 (visual), English (text), WebAudio (sound)"
              , Shell.para "No changes to user code"
              ]
          }
        , { heading: "3. Foundation for Music DSL"
          , content:
              [ Shell.para "While focused on sonification, this work explores patterns that could inform a future music composition DSL inspired by:"
              , Shell.para "Tidal Cycles' mini-notation"
              , Shell.para "Modular synthesis patching philosophy"
              , Shell.para "The data join pattern for separating temporal structure from musical content"
              ]
          }
        , { heading: "Conceptual Mapping"
          , content:
              [ Shell.para "| D3/Visual Domain | Audio/Music Domain |"
              , Shell.para "|------------------|-------------------|"
              , Shell.para "| select \"svg\" | Create audio context |"
              , Shell.para "| selectAll \"circle\" | Create array of sound events |"
              , Shell.para "| Data join | Bind data to sonic parameters |"
              , Shell.para "| attr \"cx\" (x position) | Time offset (when to play) |"
              , Shell.para "| attr \"cy\" (y position) | Pitch (frequency in Hz) |"
              , Shell.para "| attr \"r\" (radius) | Duration or volume |"
              , Shell.para "| attr \"fill\" (color) | Timbre (waveform shape) |"
              , Shell.para "| Parent/child hierarchy | Sequential/parallel composition |"
              , Shell.para "| Enter/Update/Exit | Sound onset/sustain/release |"
              ]
          }
        , { heading: "Anscombe's Quartet"
          , content:
              [ Shell.para "Anscombe's Quartet demonstrates why this matters. Four datasets with identical statistics:"
              , Shell.para "Same mean"
              , Shell.para "Same variance"
              , Shell.para "Same correlation"
              , Shell.para "But when visualized, they look completely different. And when sonified, they would sound completely different:"
              , Shell.para "Dataset 1: Linear progression (smooth ascending/descending melody)"
              , Shell.para "Dataset 2: Quadratic (curved melodic contour)"
              , Shell.para "Dataset 3: Linear with outlier (melody interrupted by jarring note)"
              , Shell.para "Dataset 4: Vertical line with outlier (repeated note with one exception)"
              , Shell.para "The patterns that vision reveals spatially, hearing reveals temporally and spectrally."
              ]
          }
        , { heading: "Use Cases"
          , content:
              [ Shell.para "1. Data Exploration - Listen to data distributions, outliers, trends"
              , Shell.para "2. Accessibility - Make charts and visualizations available to blind users"
              , Shell.para "3. Monitoring - Audio dashboards for system metrics (like Geiger counters for data)"
              , Shell.para "4. Multimodal Analysis - Use both vision and hearing simultaneously for richer understanding"
              , Shell.para "5. Education - Teach data literacy through multiple sensory modes"
              ]
          }
        , { heading: "Architecture"
          , content:
              [ Shell.para "The MusicSelection_ type represents scheduled audio events rather than DOM elements, but the operations are the same: select, join data, set attributes, handle enter/update/exit."
              ]
          }
        , { heading: "Relationship to Music Composition DSL (Future)"
          , content:
              [ Shell.para "This sonification work is distinct from but related to a potential music composition DSL. Key differences:"
              , Shell.para "psd3-music (this package):"
              , Shell.para "Data → Sound (sonification)"
              , Shell.para "Input: Arbitrary data arrays"
              , Shell.para "Output: Audio representation of data patterns"
              , Shell.para "Goal: Accessibility and data comprehension"
              , Shell.para "Future Music DSL:"
              , Shell.para "Musical ideas → Sound (composition)"
              , Shell.para "Input: Musical structures (mini-notation, chord progressions, melodies)"
              , Shell.para "Output: Music"
              , Shell.para "Goal: Creative music making and generative composition"
              , Shell.para "Shared patterns:"
              , Shell.para "Typed data joins (structure + content)"
              , Shell.para "Multiple interpreters (audio, notation, visualization, English)"
              , Shell.para "Finally tagless architecture"
              , Shell.para "Separation of \"what/when\" (temporal structure) from \"how\" (sonic content)"
              , Shell.para "Both benefit from exploring how the join pattern works in the temporal/auditory domain."
              ]
          }
        ]
    , Shell.codeExample "Example" codeSnippet
    ]

heroText :: forall w i. Array (HH.HTML w i)
heroText =
  [ HH.p_
      [ HH.text "Audio interpreter for PSD3 - Data Sonification and Accessibility" ]
  ]

heroViz :: forall w i. HH.HTML w i
heroViz = Shell.screenshotLink "demo.jpeg" "/anscombe/" "Anscombe's Quartet Demo"

codeSnippet :: String
codeSnippet = """-- This code works with both D3 and Music interpreters!
sonifyData :: forall m sel. SelectionM sel m => Array Number -> m Unit
sonifyData dataset = do
  context <- select "audio"

  tones <- context
    # renderData Tone dataset "tone"
        (Just \d ->
          [ time (\i _ -> i * 0.5)        -- Evenly spaced in time
          , pitch (\_ d -> 200.0 + d * 10.0)  -- Map data to frequency
          , duration (\_ _ -> 0.3)        -- 300ms notes
          , volume (\_ d -> d / 100.0)    -- Map data to volume
          , timbre (\_ _ -> "sine")       -- Pure sine wave
          ])
        Nothing
        Nothing

  pure unit

-- Interpret as visualization
main = do
  runD3M $ sonifyData anscombeQuartet1

-- Interpret as sonification
main = do
  runMusicM $ sonifyData anscombeQuartet1"""

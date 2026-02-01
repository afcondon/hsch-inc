-- | Scene Coordinator Component (Streamlined)
-- |
-- | Streamlined coordinator for "YouTube teaser" navigation path.
-- | Clean linear navigation: Treemap → Beeswarm → SolarSwarm → Neighborhood → PkgTreemap
-- |
-- | Key features:
-- | - 6 scenes (down from 12)
-- | - Animated transitions between scenes
-- | - Linear navigation with instant back jumps
-- | - Scope filtering (GUP) for beeswarm views
module CE2.Component.SceneCoordinator
  ( component
  , Input
  , Output(..)
  , Slot
  , Query(..)
  , V2Data
  , TransitionState
  ) where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldl)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Set (Set)
import Data.Set as Set
import Data.Tuple (Tuple(..))
import Effect (Effect)
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (liftEffect)
import Effect.Class.Console (log)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Type.Proxy (Proxy(..))

-- PSD3 Imports
import Hylograph.Render (runD3, clear)

-- Child visualization components (streamlined)
import CE2.Component.BubblePackBeeswarmViz as BubblePackBeeswarmViz
import CE2.Component.GalaxyBeeswarmViz as GalaxyBeeswarmViz
import CE2.Component.ModuleTreemapViz as ModuleTreemapViz
import CE2.Component.SlideOutPanel as SlideOutPanel

import CE2.Containers as C
import CE2.Data.Loader as Loader
import CE2.Scene (Scene(..), parentScene, sceneLabel)
import CE2.Viz.PackageSetTreemap as PackageSetTreemap
import CE2.Viz.ModuleTreemap as ModuleTreemap
import CE2.Viz.ScaleTransition as ScaleTransition
import CE2.Viz.ModuleBeeswarm as ModuleBeeswarm
import CE2.Viz.ModuleBubblePack as ModuleBubblePack
import CE2.Viz.DependencyMatrix as DependencyMatrix
import CE2.Viz.DependencyChord as DependencyChord
import CE2.Viz.DependencyAdjacency as DependencyAdjacency
import CE2.Types (projectPackages, CellContents(..), ViewTheme(..), ColorMode(..), BeeswarmScope(..), themeColors)

-- =============================================================================
-- Types
-- =============================================================================

-- | V2 data for specialized visualizations
type V2Data =
  { packages :: Array Loader.V2Package
  , modules :: Array Loader.V2ModuleListItem
  , imports :: Array Loader.V2ModuleImports
  }

-- | Transition state for animated scene changes
-- | Captures positions from source scene to initialize target scene
type TransitionState =
  { from :: Scene
  , to :: Scene
  , positions :: Map String { x :: Number, y :: Number, r :: Number }
  , progress :: Number  -- 0.0 to 1.0
  }

-- | Input from parent (AppShell)
type Input =
  { modelData :: Maybe Loader.LoadedModel
  , v2Data :: Maybe V2Data
  , packageSetData :: Maybe Loader.PackageSetData
  , initialScene :: Scene
  }

-- | Output to parent
data Output
  = RequestPackageSetData
  | SceneChanged Scene

-- | Slot type for parent component
type Slot = H.Slot Query Output

-- | Queries from parent
data Query a
  = SetScene Scene a

-- | Child component slots (streamlined - removed debug components)
type Slots =
  ( bubblePackBeeswarmViz :: BubblePackBeeswarmViz.Slot Unit
  , galaxyBeeswarmViz :: GalaxyBeeswarmViz.Slot Unit
  , moduleTreemapViz :: ModuleTreemapViz.Slot Unit
  , slideOutPanel :: SlideOutPanel.Slot Unit
  )

_bubblePackBeeswarmViz :: Proxy "bubblePackBeeswarmViz"
_bubblePackBeeswarmViz = Proxy

_galaxyBeeswarmViz :: Proxy "galaxyBeeswarmViz"
_galaxyBeeswarmViz = Proxy

_moduleTreemapViz :: Proxy "moduleTreemapViz"
_moduleTreemapViz = Proxy

_slideOutPanel :: Proxy "slideOutPanel"
_slideOutPanel = Proxy

-- | Captured position for transitions (from treemap cells or beeswarm)
type CapturedPosition = { name :: String, x :: Number, y :: Number, r :: Number }

-- | Module count threshold for skipping treemap overview
-- | Packages with fewer modules go directly to module flow view
-- | Larger packages show treemap first for orientation
smallPackageThreshold :: Int
smallPackageThreshold = 200

-- | Unified view mode for visualizations
-- | Replaces separate ModuleViewMode and PackageViewMode
-- | Resets to PrimaryView on scene change
data ViewMode
  = PrimaryView    -- Default: BubblePack for packages, Treemap for modules
  | MatrixView     -- Adjacency matrix
  | ChordView      -- Chord diagram

derive instance eqViewMode :: Eq ViewMode

instance showViewMode :: Show ViewMode where
  show PrimaryView = "PrimaryView"
  show MatrixView = "MatrixView"
  show ChordView = "ChordView"

-- | Component state - streamlined for teaser navigation
type State =
  { -- Current scene
    scene :: Scene
  , previousScene :: Maybe Scene      -- For edge cases, replaces navStack

    -- Data from parent (immutable)
  , modelData :: Maybe Loader.LoadedModel
  , v2Data :: Maybe V2Data
  , packageSetData :: Maybe Loader.PackageSetData

    -- Scope (for GUP in beeswarm)
  , scope :: BeeswarmScope

    -- Focal package (for neighborhood filtering in SolarSwarm)
    -- When set, SolarSwarm filters to show only this package + its deps/dependents
  , focalPackage :: Maybe String

    -- Color mode (persists through transitions)
  , colorMode :: ColorMode

    -- View mode (resets to PrimaryView on scene change)
  , viewMode :: ViewMode

    -- Transition (during animated transitions)
  , transition :: Maybe TransitionState
  , capturedPositions :: Maybe (Array CapturedPosition)  -- For animated transitions

    -- Declaration stats for module bubblepack view (lazy loaded)
  , declarationStats :: Maybe (Map.Map Int Loader.V2ModuleDeclarationStats)

    -- Panel state (tracked by coordinator for visibility)
  , panelOpen :: Boolean
  , panelContent :: SlideOutPanel.PanelContent

    -- Coordinated hover state
  , hoveredPackage :: Maybe String    -- Package name currently being hovered
  , hoveredModule :: Maybe { packageName :: String, moduleName :: String }  -- Module being hovered
  }

-- | Actions - streamlined
data Action
  = Initialize
  | Receive Input
  | NavigateTo Scene
  | NavigateBack
  | NavigateForward                   -- "+" button for next level of detail
  | HandleBubblePackBeeswarmOutput BubblePackBeeswarmViz.Output
  | HandleGalaxyBeeswarmOutput GalaxyBeeswarmViz.Output
  | HandleModuleTreemapOutput ModuleTreemapViz.Output
  | SetScope BeeswarmScope
  | SetFocalPackage (Maybe String)        -- Set/clear focal package for neighborhood view
  | SetViewMode ViewMode                  -- Switch between primary/matrix/chord
  | HandleSlideOutPanelOutput SlideOutPanel.Output
  | OpenModulePanel String String         -- packageName, moduleName
  | OpenPackagePanel String               -- packageName - opens panel with first module
  | TreemapCellClicked String             -- Package name clicked in treemap

-- =============================================================================
-- Component
-- =============================================================================

component :: forall m. MonadAff m => H.Component Query Input Output m
component =
  H.mkComponent
    { initialState
    , render
    , eval: H.mkEval $ H.defaultEval
        { handleAction = handleAction
        , handleQuery = handleQuery
        , receive = Just <<< Receive
        , initialize = Just Initialize
        }
    }

initialState :: Input -> State
initialState input =
  { scene: input.initialScene
  , previousScene: Nothing
  , modelData: input.modelData
  , v2Data: input.v2Data
  , packageSetData: input.packageSetData
  , scope: AllPackages
  , focalPackage: Nothing        -- No focal package initially
  , colorMode: FullRegistryTopo  -- Topo coloring persists through transitions
  , viewMode: PrimaryView        -- Resets to PrimaryView on scene change
  , transition: Nothing
  , capturedPositions: Nothing
  , declarationStats: Nothing    -- Lazy loaded when needed for module bubblepack
  , panelOpen: false
  , panelContent: SlideOutPanel.NoContent
  , hoveredPackage: Nothing
  , hoveredModule: Nothing
  }

-- =============================================================================
-- Render
-- =============================================================================

render :: forall m. MonadAff m => State -> H.ComponentHTML Action Slots m
render state =
  let theme = themeForScene state.scene
      colors = themeColors theme
  in HH.div
    [ HP.class_ (HH.ClassName "scene-coordinator")
    , HP.style $ "display: flex; min-height: 100vh;"
    ]
    [ -- Powers of Ten depth strip (left side)
      renderDepthStrip state

      -- Main content area
    , HH.div
        [ HP.class_ (HH.ClassName "scene-main-content")
        , HP.style $ "flex: 1; background: " <> colors.background <> "; transition: background 0.5s ease; position: relative;"
        ]
        [ -- Navigation header (streamlined)
          renderNavigationHeader state

          -- Scene-specific visualization
        , HH.div
            [ HP.id "viz"
            , HP.class_ (HH.ClassName "scene-viz-container")
            ]
            [ renderScene state ]
        ]

      -- Slide-out panel (for source/documentation)
    , HH.slot _slideOutPanel unit SlideOutPanel.component
        { initiallyOpen: false }
        HandleSlideOutPanelOutput
    ]

-- =============================================================================
-- Powers of Ten Depth Strip
-- =============================================================================

-- | Determine which depth level the current scene is at
-- | 0 = Galaxy (registry overview), 1 = Solar System (package details), 2 = Module (code level)
sceneDepthLevel :: Scene -> Int
sceneDepthLevel = case _ of
  GalaxyTreemap -> 0
  GalaxyBeeswarm -> 0
  SolarSwarm -> 1
  PkgTreemap _ -> 2
  PkgModuleBeeswarm _ -> 2
  OverlayChordMatrix -> 1

-- | Render the "Powers of Ten" depth indicator strip
-- | A thin vertical strip on the left showing the three zoom levels
-- | with the current level highlighted via text opacity
renderDepthStrip :: forall m. State -> H.ComponentHTML Action Slots m
renderDepthStrip state =
  let
    currentLevel = sceneDepthLevel state.scene

    -- Colors for each level (from Types.purs themeColors)
    galaxyBg = "#0E4C8A"      -- Blueprint blue
    solarBg = "#F5F0E6"       -- Beige
    moduleBg = "#FAFAFA"      -- Paperwhite

    -- Text opacity: 1.0 for current level, 0.3 for inactive
    textOpacity level = if level == currentLevel then "1.0" else "0.3"

    -- Style for each segment
    segmentStyle level bgColor textColor =
      "flex: 1; display: flex; align-items: center; justify-content: center; "
      <> "background: " <> bgColor <> "; "
      <> "color: " <> textColor <> "; "
      <> "font-size: 10px; font-weight: 500; letter-spacing: 0.5px; "
      <> "writing-mode: vertical-rl; text-orientation: mixed; "
      <> "transform: rotate(180deg); "  -- Rotate text to read bottom-to-top
      <> "opacity: " <> textOpacity level <> "; "
      <> "transition: opacity 0.3s ease;"

  in HH.div
    [ HP.class_ (HH.ClassName "depth-strip")
    , HP.style $ "width: 2rem; display: flex; flex-direction: column; "
        <> "box-shadow: 2px 0 8px rgba(0,0,0,0.1);"
    ]
    [ -- Level 0: Galaxy (top) - white text on blue
      HH.div
        [ HP.class_ (HH.ClassName "depth-level depth-galaxy")
        , HP.style $ segmentStyle 0 galaxyBg "white"
        ]
        [ HH.text "GALAXY" ]

    -- Level 1: Solar System (middle) - black text on beige
    , HH.div
        [ HP.class_ (HH.ClassName "depth-level depth-solar")
        , HP.style $ segmentStyle 1 solarBg "black"
        ]
        [ HH.text "SOLAR" ]

    -- Level 2: Module (bottom) - black text on paperwhite
    , HH.div
        [ HP.class_ (HH.ClassName "depth-level depth-module")
        , HP.style $ segmentStyle 2 moduleBg "black"
        ]
        [ HH.text "MODULE" ]
    ]

-- | Navigation header - streamlined for teaser path
-- | Shows canonical state code prominently for precise communication
renderNavigationHeader :: forall m. State -> H.ComponentHTML Action Slots m
renderNavigationHeader state =
  let stateCode = canonicalStateCode state
      panelSuffix = if state.panelOpen then "+P" else ""
  in HH.div
    [ HP.class_ (HH.ClassName "scene-nav-header floating-panel floating-panel--top-left")
    , HP.style "top: 140px;"
    ]
    [ -- State code badge (prominent, for debugging/communication)
      HH.div
        [ HP.class_ (HH.ClassName "state-code-badge")
        , HP.style "background: #333; color: #0f0; font-family: monospace; font-size: 14px; font-weight: bold; padding: 4px 8px; border-radius: 4px; margin-bottom: 8px; display: inline-block;"
        ]
        [ HH.text $ stateCode <> panelSuffix ]

      -- Top row: Back button + Scene label + Forward button
    , HH.div
        [ HP.class_ (HH.ClassName "nav-top-row")
        , HP.style "display: flex; align-items: center; gap: 8px;"
        ]
        [ -- Back button (visible when not at root)
          if canGoBack state.scene
            then HH.button
              [ HE.onClick \_ -> NavigateBack
              , HP.class_ (HH.ClassName "nav-back-button")
              , HP.style "padding: 4px 8px; font-size: 12px; cursor: pointer;"
              ]
              [ HH.text "← Back" ]
            else HH.text ""

          -- Scene label
        , HH.span
            [ HP.class_ (HH.ClassName "scene-label")
            , HP.style "font-weight: bold;"
            ]
            [ HH.text $ sceneLabel state.scene ]

          -- Scene info (package count, etc.)
        , renderSceneInfo state

          -- Forward/"+" button (for next level of detail)
        , if canGoForward state.scene
            then HH.button
              [ HE.onClick \_ -> NavigateForward
              , HP.class_ (HH.ClassName "nav-forward-button")
              , HP.style "padding: 4px 8px; font-size: 12px; cursor: pointer; background: #28a745; color: white; border: none; border-radius: 4px;"
              ]
              [ HH.text $ forwardLabel state.scene ]
            else HH.text ""
        ]

    -- Scope buttons (for GalaxyBeeswarm and SolarSwarm)
    , if state.scene == GalaxyBeeswarm || state.scene == SolarSwarm
        then HH.div
          [ HP.class_ (HH.ClassName "scope-controls")
          , HP.style "margin-top: 8px; border-top: 1px solid #ddd; padding-top: 8px;"
          ]
          [ HH.div
              [ HP.style "font-size: 10px; color: #666; margin-bottom: 4px;" ]
              [ HH.text "Scope (GUP):" ]
          , HH.div
              [ HP.style "display: flex; flex-wrap: wrap; gap: 4px;" ]
              (renderScopeButtons state)
          ]
        else HH.text ""

    -- Focal package indicator (for SolarSwarm with focal set)
    , case state.focalPackage of
        Just focalName | state.scene == SolarSwarm ->
          HH.div
            [ HP.class_ (HH.ClassName "focal-controls")
            , HP.style "margin-top: 8px; border-top: 1px solid #ddd; padding-top: 8px; display: flex; align-items: center; gap: 8px;"
            ]
            [ HH.span
                [ HP.style "font-size: 11px; color: #666;" ]
                [ HH.text "Focal:" ]
            , HH.span
                [ HP.style "font-size: 12px; font-weight: 500; color: #0E4C8A;" ]
                [ HH.text focalName ]
            , HH.button
                [ HE.onClick \_ -> SetFocalPackage Nothing
                , HP.style "padding: 2px 6px; font-size: 10px; cursor: pointer; background: #f0f0f0; border: 1px solid #ccc; border-radius: 3px; color: #666;"
                ]
                [ HH.text "× Clear" ]
            ]
        _ -> HH.text ""

    -- View mode buttons (for SolarSwarm and PkgTreemap)
    , if state.scene == SolarSwarm || isPackageTreemap state.scene
        then HH.div
          [ HP.class_ (HH.ClassName "view-mode-controls")
          , HP.style "margin-top: 8px; border-top: 1px solid #ddd; padding-top: 8px;"
          ]
          [ HH.div
              [ HP.style "font-size: 10px; color: #666; margin-bottom: 4px;" ]
              [ HH.text "View:" ]
          , HH.div
              [ HP.style "display: flex; flex-wrap: wrap; gap: 4px;" ]
              (renderViewModeButtons state)
          ]
        else HH.text ""

    -- Navigation hint
    , HH.div
        [ HP.class_ (HH.ClassName "nav-hint")
        , HP.style "margin-top: 8px; font-size: 11px; color: #666; font-style: italic;"
        ]
        [ HH.text $ navigationHint state.scene ]
    ]

-- | Check if we can navigate back (not at root)
canGoBack :: Scene -> Boolean
canGoBack GalaxyTreemap = false
canGoBack scene = parentScene scene /= scene

-- | Check if we can navigate forward (deeper detail available)
canGoForward :: Scene -> Boolean
canGoForward GalaxyTreemap = true      -- → Beeswarm
canGoForward GalaxyBeeswarm = true     -- → SolarSwarm
canGoForward SolarSwarm = true         -- → PkgTreemap (if focal set)
canGoForward (PkgTreemap _) = true     -- → PkgModuleBeeswarm
canGoForward (PkgModuleBeeswarm _) = false  -- End of path
canGoForward OverlayChordMatrix = false

-- | Label for forward button based on current scene
forwardLabel :: Scene -> String
forwardLabel GalaxyTreemap = "→ Beeswarm"
forwardLabel GalaxyBeeswarm = "+ Details"
forwardLabel SolarSwarm = "+ Modules"       -- Navigate to focal package treemap
forwardLabel (PkgTreemap _) = "+ Beeswarm"
forwardLabel _ = "+"

-- | Navigation hint for current scene
navigationHint :: Scene -> String
navigationHint GalaxyTreemap = "Click \"→ Beeswarm\" for animated transition to package swarm"
navigationHint GalaxyBeeswarm = "Scope buttons filter in place (GUP), \"+\" navigates to module details"
navigationHint SolarSwarm = "Click a package to set focal, \"+\" navigates to focal package modules"
navigationHint (PkgTreemap pkg) = "Modules in " <> pkg <> " sized by LOC"
navigationHint (PkgModuleBeeswarm pkg) = "Module dependencies in " <> pkg <> " (topo order)"
navigationHint OverlayChordMatrix = "Module dependency matrix overlay"

-- | Check if scene is a package treemap
isPackageTreemap :: Scene -> Boolean
isPackageTreemap (PkgTreemap _) = true
isPackageTreemap _ = false

-- | Render scope buttons for beeswarm views (GUP filtering)
renderScopeButtons :: forall m. State -> Array (H.ComponentHTML Action Slots m)
renderScopeButtons state =
  [ scopeButton AllPackages "All (568)" "Full package registry"
  , scopeButton ProjectOnly "Project (~25)" "Just project packages"
  , scopeButton ProjectWithDeps "Project+Deps" "Project + direct deps"
  , scopeButton ProjectWithTransitive "Transitive" "Full transitive closure"
  ]
  where
  scopeButton targetScope label tooltip =
    HH.button
      [ HE.onClick \_ -> SetScope targetScope
      , HP.class_ (HH.ClassName $ "scope-btn" <> if state.scope == targetScope then " active" else "")
      , HP.style $ "padding: 2px 6px; font-size: 10px; border-radius: 3px; cursor: pointer; "
          <> "border: 1px solid " <> (if state.scope == targetScope then "#28a745" else "#ccc") <> "; "
          <> "background: " <> (if state.scope == targetScope then "#28a745" else "#fff") <> "; "
          <> "color: " <> (if state.scope == targetScope then "#fff" else "#333") <> ";"
      , HP.title tooltip
      ]
      [ HH.text label ]

-- | Render view mode buttons for scenes that support multiple views
renderViewModeButtons :: forall m. State -> Array (H.ComponentHTML Action Slots m)
renderViewModeButtons state =
  let
    -- Labels depend on scene
    primaryLabel = case state.scene of
      SolarSwarm -> "Swarm"
      PkgTreemap _ -> "Treemap"
      _ -> "Primary"
    primaryTooltip = case state.scene of
      SolarSwarm -> "Packages with modules inside"
      PkgTreemap _ -> "Modules sized by LOC"
      _ -> "Default view"
  in
    [ viewModeButton PrimaryView primaryLabel primaryTooltip
    , viewModeButton ChordView "Chord" "Dependencies as chord diagram"
    , viewModeButton MatrixView "Matrix" "Dependencies as adjacency matrix"
    ]
  where
  viewModeButton targetMode label tooltip =
    let isActive = state.viewMode == targetMode
    in HH.button
      [ HE.onClick \_ -> SetViewMode targetMode
      , HP.class_ (HH.ClassName $ "view-mode-btn" <> if isActive then " active" else "")
      , HP.style $ "padding: 2px 6px; font-size: 10px; border-radius: 3px; cursor: pointer; "
          <> "border: 1px solid " <> (if isActive then "#0E4C8A" else "#ccc") <> "; "
          <> "background: " <> (if isActive then "#0E4C8A" else "#fff") <> "; "
          <> "color: " <> (if isActive then "#fff" else "#333") <> ";"
      , HP.title tooltip
      ]
      [ HH.text label ]

-- | Scene info display (streamlined)
renderSceneInfo :: forall m. State -> H.ComponentHTML Action Slots m
renderSceneInfo state = case state.scene of
  GalaxyTreemap ->
    case state.packageSetData of
      Just psData -> HH.span
        [ HP.class_ (HH.ClassName "scene-info")
        , HP.style "font-size: 11px; color: #666;"
        ]
        [ HH.text $ " | " <> show (Array.length psData.packages) <> " packages" ]
      Nothing -> HH.text ""

  GalaxyBeeswarm ->
    case state.packageSetData of
      Just psData ->
        let visibleCount = countVisiblePackages state.scope psData.packages
        in HH.span
          [ HP.class_ (HH.ClassName "scene-info")
          , HP.style "font-size: 11px; color: #666;"
          ]
          [ HH.text $ " | " <> show visibleCount <> " visible"
              <> (if visibleCount < Array.length psData.packages
                  then " (of " <> show (Array.length psData.packages) <> ")"
                  else "")
          ]
      Nothing -> HH.text ""

  SolarSwarm ->
    case state.modelData of
      Just model -> HH.span
        [ HP.class_ (HH.ClassName "scene-info")
        , HP.style "font-size: 11px; color: #666;"
        ]
        [ HH.text $ " | " <> show model.packageCount <> " packages, "
            <> show model.moduleCount <> " modules" ]
      Nothing -> HH.text ""

  PkgTreemap pkg ->
    case state.v2Data of
      Just v2 ->
        let moduleCount = Array.length $ Array.filter (\m -> m.package.name == pkg) v2.modules
        in HH.span
          [ HP.class_ (HH.ClassName "scene-info")
          , HP.style "font-size: 11px; color: #666;"
          ]
          [ HH.text $ " | " <> show moduleCount <> " modules" ]
      Nothing -> HH.text ""

  PkgModuleBeeswarm pkg ->
    case state.v2Data of
      Just v2 ->
        let moduleCount = Array.length $ Array.filter (\m -> m.package.name == pkg) v2.modules
        in HH.span
          [ HP.class_ (HH.ClassName "scene-info")
          , HP.style "font-size: 11px; color: #666;"
          ]
          [ HH.text $ " | " <> show moduleCount <> " modules (flow)" ]
      Nothing -> HH.text ""

  OverlayChordMatrix ->
    HH.span
      [ HP.class_ (HH.ClassName "scene-info")
      , HP.style "font-size: 11px; color: #666;"
      ]
      [ HH.text " | overlay" ]

-- | Render the current scene using child component slots
-- | Streamlined to 6 scenes for teaser navigation
renderScene :: forall m. MonadAff m => State -> H.ComponentHTML Action Slots m
renderScene state =
  let theme = themeForScene state.scene
  in case state.scene of
  GalaxyTreemap ->
    -- Empty container - PackageSetTreemap.render fills it via Effect
    HH.div
      [ HP.id C.galaxyTreemapContainerId
      , HP.class_ (HH.ClassName "galaxy-treemap")
      , HP.style "position: absolute; top: 0; left: 0; width: 100%; height: 100%;"
      ]
      []

  GalaxyBeeswarm ->
    -- Use GalaxyBeeswarmViz component (beeswarm with scope filtering)
    -- Pass captured positions for Treemap -> Beeswarm hero transition
    case state.packageSetData of
      Just psData ->
        HH.slot _galaxyBeeswarmViz unit GalaxyBeeswarmViz.component
          { packages: psData.packages
          , scope: state.scope
          , theme: theme
          , colorMode: state.colorMode  -- Persists through transitions
          , initialPositions: state.capturedPositions
          }
          HandleGalaxyBeeswarmOutput
      Nothing ->
        HH.div
          [ HP.class_ (HH.ClassName "loading") ]
          [ HH.text "Loading package set data..." ]

  SolarSwarm ->
    -- Project packages view with switchable visualization
    -- Options: BubblePack (default), Chord diagram, Adjacency matrix
    -- View mode toggle moved to LHS navigation header
    HH.div
      [ HP.class_ (HH.ClassName "solar-swarm-viz")
      , HP.style "position: relative; width: 100%; height: 100%;"
      ]
      [ case state.viewMode of
          PrimaryView ->
            case state.modelData of
              Just model ->
                let
                  -- Compute import maps for coordinated hover highlighting
                  importMaps = case state.v2Data of
                    Just v2 ->
                      { imports: buildModuleImportMap v2.imports
                      , importedBy: buildModuleImportedByMap v2.imports
                      }
                    Nothing ->
                      { imports: Map.empty, importedBy: Map.empty }
                in
                  HH.slot _bubblePackBeeswarmViz unit BubblePackBeeswarmViz.component
                    { nodes: model.nodes
                    , packages: model.packages
                    , scope: state.scope
                    , focalPackage: state.focalPackage
                    , theme: theme
                    , colorMode: state.colorMode
                    , initialPositions: state.capturedPositions
                    , moduleImports: importMaps.imports
                    , moduleImportedBy: importMaps.importedBy
                    }
                    HandleBubblePackBeeswarmOutput
              Nothing ->
                HH.div
                  [ HP.class_ (HH.ClassName "loading") ]
                  [ HH.text "Loading project data..." ]

          ChordView ->
            HH.div
              [ HP.id C.packageChordContainerId
              , HP.class_ (HH.ClassName "package-chord")
              , HP.style "position: absolute; top: 0; left: 0; width: 100%; height: 100%;"
              ]
              []

          MatrixView ->
            HH.div
              [ HP.id C.packageAdjacencyContainerId
              , HP.class_ (HH.ClassName "package-adjacency")
              , HP.style "position: absolute; top: 0; left: 0; width: 100%; height: 100%;"
              ]
              []
      ]

  PkgTreemap _pkg ->
    -- Package modules view with switchable visualization
    -- Options: Treemap (default), Chord diagram, Adjacency matrix
    -- View mode toggle moved to LHS navigation header
    HH.div
      [ HP.class_ (HH.ClassName "pkg-module-viz")
      , HP.style "position: absolute; top: 0; left: 0; width: 100%; height: 100%;"
      ]
      [ case state.viewMode of
          PrimaryView ->
            -- Use Halogen slot for treemap (enables click-to-panel)
            case state.v2Data of
              Just v2 ->
                HH.slot _moduleTreemapViz unit ModuleTreemapViz.component
                  { packageName: _pkg
                  , modules: v2.modules
                  , imports: v2.imports
                  }
                  HandleModuleTreemapOutput
              Nothing ->
                HH.div
                  [ HP.class_ (HH.ClassName "loading") ]
                  [ HH.text "Loading module data..." ]
          ChordView ->
            HH.div
              [ HP.id C.moduleChordContainerId
              , HP.class_ (HH.ClassName "module-chord")
              , HP.style "position: absolute; top: 0; left: 0; width: 100%; height: 100%;"
              ]
              []
          MatrixView ->
            HH.div
              [ HP.id C.moduleAdjacencyContainerId
              , HP.class_ (HH.ClassName "module-adjacency")
              , HP.style "position: absolute; top: 0; left: 0; width: 100%; height: 100%;"
              ]
              []
      ]

  PkgModuleBeeswarm _pkg ->
    -- Module beeswarm overlay on treemap (both layers)
    HH.div
      [ HP.class_ (HH.ClassName "pkg-module-beeswarm-viz")
      , HP.style "position: relative; width: 100%; height: 100%;"
      ]
      [ -- Treemap layer (below)
        HH.div
          [ HP.id C.pkgModuleBeeswarmTreemapContainerId
          , HP.class_ (HH.ClassName "pkg-treemap")
          , HP.style "position: absolute; top: 0; left: 0; width: 100%; height: 100%; z-index: 1;"
          ]
          []
      -- Beeswarm layer (above)
      , HH.div
          [ HP.id C.pkgModuleBeeswarmContainerId
          , HP.class_ (HH.ClassName "pkg-module-beeswarm")
          , HP.style "position: absolute; top: 0; left: 0; width: 100%; height: 100%; z-index: 2;"
          ]
          []
      ]

  OverlayChordMatrix ->
    -- Chord/Matrix overlay (toggle during SolarSwarm)
    HH.div
      [ HP.class_ (HH.ClassName "overlay-placeholder") ]
      [ HH.text "Dependency matrix overlay - Coming soon" ]

-- =============================================================================
-- Action Handlers
-- =============================================================================

handleAction :: forall m. MonadAff m => Action -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Initialize -> do
    log "[SceneCoordinator] Initializing..."
    state <- H.get
    prepareSceneData state

  Receive input -> do
    state <- H.get
    let modelDataChanged = case input.modelData, state.modelData of
          Just new, Just old -> new.moduleCount /= old.moduleCount
          Just _, Nothing -> true
          Nothing, Just _ -> true
          Nothing, Nothing -> false

        packageSetDataChanged = case input.packageSetData, state.packageSetData of
          Just _, Nothing -> true
          Nothing, Just _ -> true
          _, _ -> false

        dataChanged = modelDataChanged || packageSetDataChanged

    H.modify_ _
      { modelData = input.modelData
      , v2Data = input.v2Data
      , packageSetData = input.packageSetData
      }

    when dataChanged do
      log "[SceneCoordinator] Data changed, re-rendering"
      newState <- H.get
      prepareSceneData newState

  NavigateTo targetScene -> do
    state <- H.get
    log $ "[SceneCoordinator] Navigating to: " <> show targetScene

    -- Clear existing viz containers
    liftEffect clearAllVizContainers

    H.modify_ _
      { scene = targetScene
      , previousScene = Just state.scene
      , viewMode = PrimaryView  -- Reset view mode on scene change
      }

    H.raise (SceneChanged targetScene)
    newState <- H.get
    prepareSceneData newState

  NavigateBack -> do
    state <- H.get
    let parent = parentScene state.scene

    when (parent /= state.scene) do
      log $ "[SceneCoordinator] Navigating back to: " <> show parent

      liftEffect clearAllVizContainers

      -- Clear transition state and focal package when going back
      -- This prevents stale positions from affecting the re-render
      H.modify_ _
        { scene = parent
        , previousScene = Just state.scene
        , viewMode = PrimaryView  -- Reset view mode on scene change
        , capturedPositions = Nothing  -- Clear stale positions
        , focalPackage = Nothing  -- Clear focal when leaving SolarSwarm
        }

      H.raise (SceneChanged parent)
      newState <- H.get
      prepareSceneData newState

  NavigateForward -> do
    state <- H.get
    case state.scene of
      GalaxyTreemap -> do
        -- Capture treemap cell positions for hero transition
        log "[SceneCoordinator] Capturing treemap positions for transition"
        positions <- liftEffect $ PackageSetTreemap.getCellPositions C.galaxyTreemapContainer
        log $ "[SceneCoordinator] Captured " <> show (Array.length positions) <> " positions"
        H.modify_ _ { capturedPositions = Just positions }
        handleAction (NavigateTo GalaxyBeeswarm)

      GalaxyBeeswarm -> do
        -- Capture beeswarm positions for SolarSwarm transition
        log "[SceneCoordinator] Capturing beeswarm positions for SolarSwarm transition"
        positions <- liftEffect $ ScaleTransition.getCurrentPositionsByName "#galaxy-beeswarm-container"
        log $ "[SceneCoordinator] Captured " <> show (Array.length positions) <> " positions from beeswarm"
        H.modify_ _ { capturedPositions = Just positions }
        handleAction (NavigateTo SolarSwarm)

      SolarSwarm -> do
        -- Navigate to package module detail for focal package (if set)
        -- Small packages (<200 modules): bubblepack view (force-directed circles)
        -- Large packages (≥200 modules): treemap + beeswarm overlay
        -- Both skip the standalone treemap (E) - go straight to the combined view
        case state.focalPackage of
          Just pkg -> do
            let moduleCount = case state.v2Data of
                  Just v2 -> Array.length $ Array.filter (\m -> m.package.name == pkg) v2.modules
                  Nothing -> 0
            H.modify_ _ { capturedPositions = Nothing }
            if moduleCount < smallPackageThreshold
              then do
                log $ "[SceneCoordinator] Small package (" <> show moduleCount <> " modules) → bubblepack"
                -- TODO: Navigate to module bubblepack view
                -- For now, use PkgModuleBeeswarm which will need to adapt
                handleAction (NavigateTo (PkgModuleBeeswarm pkg))
              else do
                log $ "[SceneCoordinator] Large package (" <> show moduleCount <> " modules) → treemap+beeswarm"
                handleAction (NavigateTo (PkgModuleBeeswarm pkg))
          Nothing -> do
            log "[SceneCoordinator] No focal package set, cannot navigate forward"
            pure unit

      PkgTreemap pkg -> do
        -- E is now mostly skipped, but if reached, go to F
        H.modify_ _ { capturedPositions = Nothing }
        handleAction (NavigateTo (PkgModuleBeeswarm pkg))

      _ -> pure unit

  HandleBubblePackBeeswarmOutput output -> case output of
    BubblePackBeeswarmViz.PackageClicked pkgName -> do
      log $ "[SceneCoordinator] BubblePack package clicked: " <> pkgName
      -- Open panel with package info, set focal to filter to neighborhood
      handleAction (OpenPackagePanel pkgName)
      handleAction (SetFocalPackage (Just pkgName))
    BubblePackBeeswarmViz.PackageHovered mPkgName ->
      H.modify_ _ { hoveredPackage = mPkgName }
    BubblePackBeeswarmViz.ModuleClicked pkgName modName -> do
      log $ "[SceneCoordinator] BubblePack module clicked: " <> pkgName <> "/" <> modName
      -- Open the slide-out panel with module info (but don't navigate)
      handleAction (OpenModulePanel pkgName modName)
    BubblePackBeeswarmViz.ModuleHovered pkgName mModName ->
      -- Track hovered module for coordinated highlighting
      case mModName of
        Just modName ->
          H.modify_ _ { hoveredModule = Just { packageName: pkgName, moduleName: modName } }
        Nothing ->
          H.modify_ _ { hoveredModule = Nothing }

  HandleGalaxyBeeswarmOutput output -> case output of
    GalaxyBeeswarmViz.PackageClicked pkgName -> do
      log $ "[SceneCoordinator] Galaxy package clicked: " <> pkgName
      -- Open panel with package info, then navigate to package treemap
      handleAction (OpenPackagePanel pkgName)
      handleAction (NavigateTo (PkgTreemap pkgName))
    GalaxyBeeswarmViz.PackageHovered mPkgName ->
      H.modify_ _ { hoveredPackage = mPkgName }

  HandleModuleTreemapOutput output -> case output of
    ModuleTreemapViz.ModuleClicked pkgName modName -> do
      log $ "[SceneCoordinator] Module treemap clicked: " <> pkgName <> "/" <> modName
      -- Open the slide-out panel with module info
      handleAction (OpenModulePanel pkgName modName)
    ModuleTreemapViz.ModuleHovered _mModName ->
      pure unit  -- Future: coordinated hover

  SetScope targetScope -> do
    log $ "[SceneCoordinator] Setting scope: " <> show targetScope
    -- Phase 3: Explicit scope transitions - no auto-escalation
    -- Scope changes just filter in place via GUP
    -- Navigation to SolarSwarm requires explicit "+" button click
    H.modify_ _ { scope = targetScope }

  SetFocalPackage mPkg -> do
    log $ "[SceneCoordinator] Setting focal package: " <> show mPkg
    -- Set focal package for neighborhood filtering in SolarSwarm
    -- When focal is set, the visualization filters to show the focal package
    -- and its dependencies/dependents within the current scope
    H.modify_ _ { focalPackage = mPkg }

  SetViewMode targetMode -> do
    log $ "[SceneCoordinator] Setting view mode: " <> show targetMode
    H.modify_ _ { viewMode = targetMode }
    -- Re-render the visualization with new mode
    newState <- H.get
    prepareSceneData newState

  TreemapCellClicked pkgName -> do
    log $ "[SceneCoordinator] Treemap cell clicked: " <> pkgName
    -- In GalaxyTreemap, clicking a package navigates to beeswarm
    handleAction (NavigateTo GalaxyBeeswarm)

  HandleSlideOutPanelOutput output -> case output of
    SlideOutPanel.PanelClosed -> do
      log "[SceneCoordinator] Panel closed"
      H.modify_ _ { panelOpen = false }
    SlideOutPanel.NavigateToModule pkgName modName -> do
      log $ "[SceneCoordinator] Panel navigation to module: " <> pkgName <> "/" <> modName
      -- Load the module's declarations in the panel
      handleAction (OpenModulePanel pkgName modName)
    SlideOutPanel.NavigateToPackage pkgName -> do
      log $ "[SceneCoordinator] Panel navigation to package: " <> pkgName
      -- Future: navigate to package

  OpenModulePanel pkgName modName -> do
    log $ "[SceneCoordinator] Opening panel for module: " <> pkgName <> "/" <> modName
    -- Open the panel with loading state first
    let loadingContent = SlideOutPanel.ModuleLoading
          { moduleName: modName
          , packageName: pkgName
          }
    -- Track panel state in coordinator
    H.modify_ _ { panelOpen = true, panelContent = loadingContent }
    void $ H.tell _slideOutPanel unit (SlideOutPanel.Open loadingContent)
    -- Look up module info from v2Data
    state <- H.get
    let mModuleInfo = do
          v2 <- state.v2Data
          mod <- Array.find (\m -> m.name == modName && m.package.name == pkgName) v2.modules
          pure { id: mod.id, version: mod.package.version, source: mod.package.source }
    case mModuleInfo of
      Nothing -> do
        log $ "[SceneCoordinator] Module not found in v2Data: " <> pkgName <> "/" <> modName
        -- Show empty declarations
        let emptyContent = SlideOutPanel.ModuleDeclarations
              { moduleName: modName
              , packageName: pkgName
              , packageVersion: Nothing
              , pursuitUrl: Nothing
              , declarations: []
              }
        H.modify_ _ { panelContent = emptyContent }
        void $ H.tell _slideOutPanel unit (SlideOutPanel.SetContent emptyContent)
      Just { id: moduleId, version, source } -> do
        -- Construct Pursuit URL for registry packages
        let pursuitUrl = if source == "registry"
              then Just $ "https://pursuit.purescript.org/packages/purescript-"
                       <> pkgName <> "/" <> version <> "/docs/" <> modName
              else Nothing
        -- Fetch declarations from API
        result <- liftAff $ Loader.fetchV2ModuleDeclarations moduleId
        case result of
          Left err -> do
            log $ "[SceneCoordinator] Failed to fetch declarations: " <> err
            -- Show empty declarations on failure
            let emptyContent = SlideOutPanel.ModuleDeclarations
                  { moduleName: modName
                  , packageName: pkgName
                  , packageVersion: Just version
                  , pursuitUrl
                  , declarations: []
                  }
            H.modify_ _ { panelContent = emptyContent }
            void $ H.tell _slideOutPanel unit (SlideOutPanel.SetContent emptyContent)
          Right decls -> do
            log $ "[SceneCoordinator] Loaded " <> show (Array.length decls) <> " declarations for " <> modName
            -- Convert V2Declaration to SlideOutPanel.Declaration
            let panelDecls = map (\d ->
                  { name: d.name
                  , kind: d.kind
                  , typeSignature: d.typeSignature
                  , comments: d.comments
                  }) decls
            let content = SlideOutPanel.ModuleDeclarations
                  { moduleName: modName
                  , packageName: pkgName
                  , packageVersion: Just version
                  , pursuitUrl
                  , declarations: panelDecls
                  }
            H.modify_ _ { panelContent = content }
            void $ H.tell _slideOutPanel unit (SlideOutPanel.SetContent content)

  OpenPackagePanel pkgName -> do
    log $ "[SceneCoordinator] Opening panel for package: " <> pkgName
    -- Find first module in this package and open panel for it
    state <- H.get
    case state.v2Data of
      Nothing -> do
        log "[SceneCoordinator] No v2Data for package panel"
      Just v2 -> do
        let pkgModules = Array.filter (\m -> m.package.name == pkgName) v2.modules
        case Array.head pkgModules of
          Nothing -> do
            log $ "[SceneCoordinator] No modules found in package: " <> pkgName
          Just firstMod -> do
            log $ "[SceneCoordinator] Opening first module: " <> firstMod.name
            handleAction (OpenModulePanel pkgName firstMod.name)

-- | Prepare data for the current scene
prepareSceneData :: forall m. MonadAff m => State -> H.HalogenM State Action Slots Output m Unit
prepareSceneData state = case state.scene of
  GalaxyTreemap -> do
    case state.packageSetData of
      Just psData -> do
        log "[SceneCoordinator] Rendering GalaxyTreemap"
        liftEffect $ renderGalaxyTreemapWithConfig state psData
      Nothing -> do
        log "[SceneCoordinator] Requesting package set data"
        H.raise RequestPackageSetData

  GalaxyBeeswarm -> do
    case state.packageSetData of
      Just _ ->
        log "[SceneCoordinator] GalaxyBeeswarm: data available, slot will render"
      Nothing -> do
        log "[SceneCoordinator] Requesting package set data"
        H.raise RequestPackageSetData

  SolarSwarm -> do
    case state.viewMode of
      PrimaryView ->
        -- BubblePack is handled by the Halogen slot
        case state.modelData of
          Just model ->
            log $ "[SceneCoordinator] SolarSwarm (BubblePack): "
                <> show model.packageCount <> " packages, "
                <> show model.moduleCount <> " modules"
          Nothing ->
            log "[SceneCoordinator] No modelData for SolarSwarm"

      ChordView -> do
        log "[SceneCoordinator] SolarSwarm: Rendering package chord diagram"
        case state.v2Data of
          Just v2 -> do
            -- Build package-level dependency matrix
            -- Filter to project packages (those in scope)
            let projectPkgNames = Set.fromFoldable projectPackages
                scopedPackages = Array.filter (\p -> Set.member p.name projectPkgNames) v2.packages
                depData = DependencyMatrix.buildFromPackageDependencies scopedPackages v2.modules v2.imports
            log $ "[SceneCoordinator] Package Chord: " <> show (Array.length depData.names)
                <> " packages, " <> show depData.totalConnections <> " connections"
            result <- liftEffect $ DependencyChord.render
              { containerSelector: C.packageChordContainer
              , width: 800.0
              , height: 800.0
              , innerRadius: 280.0
              , outerRadius: 320.0
              }
              depData
            case result of
              DependencyChord.Success _ ->
                log "[SceneCoordinator] Package chord diagram rendered successfully"
              DependencyChord.Overloaded n ->
                log $ "[SceneCoordinator] Package chord overloaded: " <> show n <> " packages"
          Nothing ->
            log "[SceneCoordinator] No v2Data for SolarSwarm chord"

      MatrixView -> do
        log "[SceneCoordinator] SolarSwarm: Rendering package adjacency matrix"
        case state.v2Data of
          Just v2 -> do
            -- Build package-level dependency matrix
            let projectPkgNames = Set.fromFoldable projectPackages
                scopedPackages = Array.filter (\p -> Set.member p.name projectPkgNames) v2.packages
                depData = DependencyMatrix.buildFromPackageDependencies scopedPackages v2.modules v2.imports
            log $ "[SceneCoordinator] Package Adjacency: " <> show (Array.length depData.names)
                <> " packages, " <> show depData.totalConnections <> " connections"
            result <- liftEffect $ DependencyAdjacency.render
              { containerSelector: C.packageAdjacencyContainer
              , width: 1200.0
              , height: 900.0
              , cellSize: 20.0  -- Larger cells for fewer packages
              , labelWidth: 250.0
              , labelHeight: 250.0
              , matrixMode: false
              }
              depData
            case result of
              DependencyAdjacency.Success _ ->
                log "[SceneCoordinator] Package adjacency matrix rendered successfully"
              DependencyAdjacency.Overloaded n ->
                log $ "[SceneCoordinator] Package adjacency overloaded: " <> show n <> " packages"
          Nothing ->
            log "[SceneCoordinator] No v2Data for SolarSwarm adjacency"

  PkgTreemap pkgName -> do
    case state.v2Data of
      Just v2 -> do
        -- Filter modules and imports to this package
        let pkgModules = Array.filter (\m -> m.package.name == pkgName) v2.modules
            pkgModuleNames = Set.fromFoldable $ map _.name pkgModules
            pkgModuleIds = Set.fromFoldable $ map _.id pkgModules
            pkgImports = Array.filter (\imp -> Set.member imp.moduleId pkgModuleIds) v2.imports

        log $ "[SceneCoordinator] PkgTreemap (" <> show state.viewMode <> "): "
            <> pkgName <> " - " <> show (Array.length pkgModules) <> " modules"

        case state.viewMode of
          PrimaryView ->
            -- Treemap is now rendered by ModuleTreemapViz Halogen component
            log "[SceneCoordinator] PrimaryView (Treemap): rendering handled by slot"

          ChordView -> do
            log "[SceneCoordinator] Rendering module chord diagram"
            -- Build dependency matrix from module imports
            let depData = DependencyMatrix.buildFromModuleImports pkgImports
                -- Filter to only show modules in this package
                filteredData = DependencyMatrix.filterToNames pkgModuleNames depData
            log $ "[SceneCoordinator] Chord: " <> show (Array.length filteredData.names)
                <> " entities, " <> show filteredData.totalConnections <> " connections"
            result <- liftEffect $ DependencyChord.render
              { containerSelector: C.moduleChordContainer
              , width: 800.0
              , height: 800.0
              , innerRadius: 280.0
              , outerRadius: 320.0
              }
              filteredData
            case result of
              DependencyChord.Success _ ->
                log "[SceneCoordinator] Chord diagram rendered successfully"
              DependencyChord.Overloaded n ->
                log $ "[SceneCoordinator] Chord overloaded: " <> show n <> " entities"

          MatrixView -> do
            log "[SceneCoordinator] Rendering module adjacency matrix"
            -- Build dependency matrix from module imports
            let depData = DependencyMatrix.buildFromModuleImports pkgImports
                -- Filter to only show modules in this package
                filteredData = DependencyMatrix.filterToNames pkgModuleNames depData
            log $ "[SceneCoordinator] Adjacency: " <> show (Array.length filteredData.names)
                <> " entities, " <> show filteredData.totalConnections <> " connections"
            result <- liftEffect $ DependencyAdjacency.render
              { containerSelector: C.moduleAdjacencyContainer
              , width: 1200.0
              , height: 900.0
              , cellSize: 12.0
              , labelWidth: 200.0
              , labelHeight: 200.0
              , matrixMode: false  -- Use blue theme, not green Matrix theme
              }
              filteredData
            case result of
              DependencyAdjacency.Success _ ->
                log "[SceneCoordinator] Adjacency matrix rendered successfully"
              DependencyAdjacency.Overloaded n ->
                log $ "[SceneCoordinator] Adjacency overloaded: " <> show n <> " entities"

      Nothing ->
        log "[SceneCoordinator] No v2Data for PkgTreemap"

  PkgModuleBeeswarm pkgName -> do
    case state.v2Data of
      Just v2 -> do
        -- Filter modules and imports to this package
        let pkgModules = Array.filter (\m -> m.package.name == pkgName) v2.modules
            pkgModuleIds = Set.fromFoldable $ map _.id pkgModules
            pkgImports = Array.filter (\imp -> Set.member imp.moduleId pkgModuleIds) v2.imports
            moduleCount = Array.length pkgModules
            isSmallPackage = moduleCount < smallPackageThreshold

        log $ "[SceneCoordinator] Rendering PkgModuleBeeswarm: " <> pkgName
            <> " (" <> show moduleCount <> " modules, "
            <> (if isSmallPackage then "small → bubblepack" else "large → treemap+beeswarm") <> ")"

        -- Both cases: render treemap as background layer (paperwhite theme)
        liftEffect $ ModuleTreemap.render
          { containerSelector: C.pkgModuleBeeswarmTreemapContainer
          , width: 1650.0
          , height: 900.0
          , packageName: pkgName
          , onModuleClick: Nothing  -- Background layer, no click handling
          }
          pkgModules

        if isSmallPackage
          then do
            -- Small packages: bubblepack view showing module contents
            -- Fetch declaration stats if not cached
            statsMap <- case state.declarationStats of
              Just stats -> pure stats
              Nothing -> do
                log "[SceneCoordinator] Fetching declaration stats for bubblepack view"
                result <- liftAff Loader.fetchV2ModuleDeclarationStats
                case result of
                  Right statsArray -> do
                    let stats = Map.fromFoldable $ statsArray <#> \s -> Tuple s.moduleId s
                    H.modify_ _ { declarationStats = Just stats }
                    pure stats
                  Left err -> do
                    log $ "[SceneCoordinator] Failed to fetch declaration stats: " <> err
                    pure Map.empty

            -- Render module bubblepack
            _ <- liftEffect $ ModuleBubblePack.render
              { containerSelector: C.pkgModuleBeeswarmContainer
              , width: 1650.0
              , height: 900.0
              , packages: v2.packages
              }
              pkgModules
              statsMap
            log "[SceneCoordinator] Module bubblepack rendered"

          else do
            -- Large packages: simple beeswarm circles with topo ordering
            _ <- liftEffect $ ModuleBeeswarm.renderSinglePackage
              { containerSelector: C.pkgModuleBeeswarmContainer
              , width: 1650.0
              , height: 900.0
              , packageName: pkgName
              }
              pkgModules
              pkgImports
            log "[SceneCoordinator] Module beeswarm rendered"

      Nothing ->
        log "[SceneCoordinator] No v2Data for PkgModuleBeeswarm"

  OverlayChordMatrix ->
    log "[SceneCoordinator] OverlayChordMatrix"

-- =============================================================================
-- Query Handlers
-- =============================================================================

handleQuery :: forall m a. MonadAff m => Query a -> H.HalogenM State Action Slots Output m (Maybe a)
handleQuery = case _ of
  SetScene targetScene a -> do
    handleAction (NavigateTo targetScene)
    pure (Just a)

-- =============================================================================
-- Rendering Helpers
-- =============================================================================

-- | Clear all visualization containers (prevents stale SVGs when switching scenes)
clearAllVizContainers :: Effect Unit
clearAllVizContainers = void $ runD3 do
  clear (C.galaxyTreemapContainer <> " *")
  clear "#galaxy-beeswarm-container *"
  clear (C.bubblePackBeeswarmContainer <> " *")
  clear "#pkg-treemap-container *"
  clear (C.pkgModuleBeeswarmTreemapContainer <> " *")
  clear (C.pkgModuleBeeswarmContainer <> " *")
  clear "#circlepack-container *"

-- | Render the full registry treemap with config from state
-- | Uses renderWithHighlighting for hover-based dependency highlighting
renderGalaxyTreemapWithConfig :: State -> Loader.PackageSetData -> Effect Unit
renderGalaxyTreemapWithConfig state psData = do
  let theme = themeForScene state.scene
      config :: PackageSetTreemap.Config
      config =
        { containerSelector: C.galaxyTreemapContainer
        , width: 1650.0
        , height: 900.0
        , projectPackages: Set.fromFoldable projectPackages
        , transitivePackages: computeTransitivePackages psData.packages
        , theme: theme
        , cellContents: CellCircle  -- Always use circles in treemap
        }

  PackageSetTreemap.renderWithHighlighting config psData.packages

-- | Compute transitive packages from project dependencies
computeTransitivePackages :: Array Loader.PackageSetPackage -> Set String
computeTransitivePackages packages =
  let
    depMap :: Map String (Array String)
    depMap = Map.fromFoldable $ packages <#> \p -> Tuple p.name p.depends

    projectPkgNames :: Set String
    projectPkgNames = Set.fromFoldable projectPackages

    go :: Set String -> Set String -> Set String
    go frontier visited
      | Set.isEmpty frontier = visited
      | otherwise =
          let
            newDeps = foldl (\acc name ->
              case Map.lookup name depMap of
                Nothing -> acc
                Just deps -> Set.union acc (Set.fromFoldable deps)
              ) Set.empty frontier
            unvisited = Set.difference newDeps visited
            newVisited = Set.union visited frontier
          in go unvisited newVisited
  in
    Set.difference (go projectPkgNames Set.empty) projectPkgNames

-- | Get appropriate theme for a scene
-- | Three "Powers of Ten" levels:
-- |   Galaxy (registry) → Blueprint blue
-- |   Solar System (packages) → Beige
-- |   Module (code) → Paperwhite
themeForScene :: Scene -> ViewTheme
themeForScene = case _ of
  GalaxyTreemap -> BlueprintTheme
  GalaxyBeeswarm -> BlueprintTheme
  SolarSwarm -> BeigeTheme              -- Solar system level = warm beige
  PkgTreemap _ -> PaperwhiteTheme       -- Module level = paperwhite
  PkgModuleBeeswarm _ -> PaperwhiteTheme -- Module level with flow overlay
  OverlayChordMatrix -> BeigeTheme

-- | Canonical state code for precise communication
-- | See docs/kb/reference/ce2-state-machine-analysis.md for full naming system
-- |
-- | Galaxy level:  A (Treemap), B (Beeswarm)
-- | Solar level:   C + scope digit + optional focal + view suffix
-- |   Scopes: 0=All, 1=Trans, 2=Deps, 3=Proj
-- |   Focal: (pkgName) when focal package set
-- |   Views: (none)=Primary, M=Matrix, C=Chord
-- | Module level:  E(pkg) + view suffix, F(pkg)=Beeswarm
-- | Panel: +P suffix when open
-- | Note: D (PkgNeighborhood) was merged into C with focalPackage
canonicalStateCode :: State -> String
canonicalStateCode state = case state.scene of
  GalaxyTreemap -> "A"

  GalaxyBeeswarm -> "B" <> scopeDigit state.scope

  SolarSwarm -> "C" <> scopeDigit state.scope <> focalSuffix <> viewSuffix state.viewMode
    where focalSuffix = case state.focalPackage of
            Just pkg -> "(" <> pkg <> ")"
            Nothing -> ""

  PkgTreemap pkg -> "E(" <> pkg <> ")" <> viewSuffix state.viewMode

  PkgModuleBeeswarm pkg -> "F(" <> pkg <> ")"

  OverlayChordMatrix -> "O"  -- Overlay state

  where
  scopeDigit :: BeeswarmScope -> String
  scopeDigit = case _ of
    AllPackages -> "0"
    ProjectWithTransitive -> "1"
    ProjectWithDeps -> "2"
    ProjectOnly -> "3"

  viewSuffix :: ViewMode -> String
  viewSuffix = case _ of
    PrimaryView -> ""
    MatrixView -> "M"
    ChordView -> "C"

-- | Count visible packages based on scope
countVisiblePackages :: BeeswarmScope -> Array Loader.PackageSetPackage -> Int
countVisiblePackages scope packages = case scope of
  AllPackages -> Array.length packages
  ProjectOnly -> Array.length $ Array.filter (\p -> Set.member p.name projectSet) packages
  ProjectWithDeps -> Array.length $ Array.filter (\p ->
    Set.member p.name projectSet || isDirectDep p.name) packages
  ProjectWithTransitive -> Array.length $ Array.filter (\p ->
    Set.member p.name projectSet || Set.member p.name transitiveSet) packages
  where
  projectSet = Set.fromFoldable projectPackages
  transitiveSet = computeTransitivePackages packages
  -- Check if package is a direct dependency of any project package
  isDirectDep name = Array.any (\p ->
    Set.member p.name projectSet && Array.elem name p.depends) packages

-- =============================================================================
-- Package Neighborhood
-- =============================================================================

-- | Result of computing a package's neighborhood
type PackageNeighborhoodInfo =
  { depsCount :: Int
  , dependentsCount :: Int
  }

-- | Compute package neighborhood info for display
computePackageNeighborhood :: String -> V2Data -> PackageNeighborhoodInfo
computePackageNeighborhood pkgName v2 =
  let
    -- Build module name -> package name mapping
    moduleToPackage :: Map String String
    moduleToPackage = Map.fromFoldable $
      v2.modules <#> \m -> Tuple m.name m.package.name

    -- Build imports map: moduleId -> imported module names
    importsMap :: Map Int (Array String)
    importsMap = Map.fromFoldable $
      v2.imports <#> \mi -> Tuple mi.moduleId mi.imports

    -- Build package -> modules mapping
    packageToModules :: Map String (Array Loader.V2ModuleListItem)
    packageToModules = foldl addModule Map.empty v2.modules
      where
      addModule acc mod =
        Map.alter (Just <<< Array.cons mod <<< fromMaybe []) mod.package.name acc

    -- Find packages this package depends on
    depPkgNames :: Set String
    depPkgNames =
      let
        pkgModules = fromMaybe [] $ Map.lookup pkgName packageToModules
      in
        foldl findDeps Set.empty pkgModules
      where
      findDeps acc mod =
        let
          moduleImports = fromMaybe [] $ Map.lookup mod.id importsMap
          importedPkgs = Array.mapMaybe (\impName -> Map.lookup impName moduleToPackage) moduleImports
          externalDeps = Array.filter (_ /= pkgName) importedPkgs
        in
          Set.union acc (Set.fromFoldable externalDeps)

    -- Find packages that depend on this package (dependents)
    dependentPkgNames :: Set String
    dependentPkgNames = foldl findDependents Set.empty v2.modules
      where
      findDependents acc mod
        | mod.package.name == pkgName = acc
        | otherwise =
            let
              moduleImports = fromMaybe [] $ Map.lookup mod.id importsMap
              importedPkgs = Set.fromFoldable $ Array.mapMaybe (\impName -> Map.lookup impName moduleToPackage) moduleImports
            in
              if Set.member pkgName importedPkgs
                then Set.insert mod.package.name acc
                else acc
  in
    { depsCount: Set.size depPkgNames
    , dependentsCount: Set.size dependentPkgNames
    }

-- | Filter V2 data to a package and its neighborhood (deps + dependents)
filterToPackageNeighborhood :: V2Data -> String -> V2Data
filterToPackageNeighborhood v2 pkgName =
  let
    moduleToPackage :: Map String String
    moduleToPackage = Map.fromFoldable $
      v2.modules <#> \m -> Tuple m.name m.package.name

    importsMap :: Map Int (Array String)
    importsMap = Map.fromFoldable $
      v2.imports <#> \mi -> Tuple mi.moduleId mi.imports

    packageToModules :: Map String (Array Loader.V2ModuleListItem)
    packageToModules = foldl addModule Map.empty v2.modules
      where
      addModule acc mod =
        Map.alter (Just <<< Array.cons mod <<< fromMaybe []) mod.package.name acc

    depPkgNames :: Set String
    depPkgNames =
      let
        pkgModules = fromMaybe [] $ Map.lookup pkgName packageToModules
      in
        foldl findDeps Set.empty pkgModules
      where
      findDeps acc mod =
        let
          moduleImports = fromMaybe [] $ Map.lookup mod.id importsMap
          importedPkgs = Array.mapMaybe (\impName -> Map.lookup impName moduleToPackage) moduleImports
          externalDeps = Array.filter (_ /= pkgName) importedPkgs
        in
          Set.union acc (Set.fromFoldable externalDeps)

    dependentPkgNames :: Set String
    dependentPkgNames = foldl findDependents Set.empty v2.modules
      where
      findDependents acc mod
        | mod.package.name == pkgName = acc
        | otherwise =
            let
              moduleImports = fromMaybe [] $ Map.lookup mod.id importsMap
              importedPkgs = Set.fromFoldable $ Array.mapMaybe (\impName -> Map.lookup impName moduleToPackage) moduleImports
            in
              if Set.member pkgName importedPkgs
                then Set.insert mod.package.name acc
                else acc

    allRelevantNames = Set.insert pkgName (Set.union depPkgNames dependentPkgNames)
    filteredPkgs = Array.filter (\p -> Set.member p.name allRelevantNames) v2.packages
    pkgIds = Set.fromFoldable $ map _.id filteredPkgs
    filteredMods = Array.filter (\m -> Set.member m.package.id pkgIds) v2.modules
    filteredModIds = Set.fromFoldable $ map _.id filteredMods
    filteredImps = Array.filter (\imp -> Set.member imp.moduleId filteredModIds) v2.imports
  in
    { packages: filteredPkgs, modules: filteredMods, imports: filteredImps }

-- =============================================================================
-- Module Import Maps (for coordinated hover highlighting)
-- =============================================================================

-- | Build a map from module name to the modules it imports
buildModuleImportMap :: Array Loader.V2ModuleImports -> Map String (Array String)
buildModuleImportMap imports =
  Map.fromFoldable $ imports <#> \imp -> Tuple imp.moduleName imp.imports

-- | Build a reverse map: module name to modules that import it
buildModuleImportedByMap :: Array Loader.V2ModuleImports -> Map String (Array String)
buildModuleImportedByMap imports =
  let
    -- For each import relationship, record the reverse
    pairs :: Array (Tuple String String)
    pairs = Array.concatMap (\imp ->
        imp.imports <#> \imported -> Tuple imported imp.moduleName
      ) imports
  in
    -- Group by imported module
    foldl (\acc (Tuple imported importer) ->
      Map.alter (Just <<< Array.cons importer <<< fromMaybe []) imported acc
    ) Map.empty pairs

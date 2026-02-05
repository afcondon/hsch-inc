-- | Main application component for Type Explorer
module TypeExplorer.App where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (liftEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Subscription as HS
import TypeExplorer.Types (State, TypeInfo, TypeKind(..), TypeFilter(..), ViewMode(..), ClusterStrategy(..),
                           colors, initialState, InterpreterMatrix, TypeClassGridData)
import TypeExplorer.Data.Loader as Loader
import TypeExplorer.Views.ForceGraph as ForceGraph
import TypeExplorer.Views.Matrix as Matrix
import TypeExplorer.Views.TypeClassGrid as TypeClassGrid
import Hylograph.HATS.InterpreterTick (clearContainer)

-- | Actions for the app
data Action
  = Initialize
  | SelectType Int
  | ClearSelection
  | SetFilter TypeFilter
  | SetClusterStrategy ClusterStrategy
  | SetViewMode ViewMode
  | DataLoaded (Either String Loader.TypeData)
  | MatrixDataLoaded (Either String InterpreterMatrix)
  | TypeClassDataLoaded (Either String TypeClassGridData)

-- | The main app component
component :: forall q i o m. MonadAff m => H.Component q i o m
component = H.mkComponent
  { initialState: const initialState
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      }
  }

render :: forall m. State -> H.ComponentHTML Action () m
render state =
  HH.div
    [ HP.class_ $ HH.ClassName "app-container" ]
    [ -- Header
      HH.header
        [ HP.class_ $ HH.ClassName "app-header" ]
        [ HH.h1_ [ HH.text "Type Explorer" ]
        , HH.div
            [ HP.class_ $ HH.ClassName "view-controls" ]
            [ renderViewToggle state.viewMode ]
        ]
    , -- Main content
      HH.main
        [ HP.class_ $ HH.ClassName "app-main" ]
        [ -- Visualization area - both containers always present, visibility toggled
          HH.div
            [ HP.class_ $ HH.ClassName $ "viz-container viz-graph" <> if state.viewMode == ForceGraphView then "" else " hidden"
            , HP.id "viz-graph"
            ]
            [ if state.loading
                then HH.div [ HP.class_ $ HH.ClassName "loading" ] [ HH.text "Loading type data..." ]
                else case state.error of
                  Just err -> HH.div [ HP.class_ $ HH.ClassName "error" ] [ HH.text err ]
                  Nothing -> HH.text ""  -- Force graph renders via HATS
            ]
        , HH.div
            [ HP.class_ $ HH.ClassName $ "viz-container viz-split" <> if state.viewMode == TypeClassesView then "" else " hidden" ]
            [ -- Left pane: Matrix
              HH.div
                [ HP.class_ $ HH.ClassName "split-pane split-left"
                , HP.id "viz-matrix"
                ]
                [ if state.loading
                    then HH.div [ HP.class_ $ HH.ClassName "loading" ] [ HH.text "Loading..." ]
                    else HH.text ""
                ]
            , -- Divider
              HH.div [ HP.class_ $ HH.ClassName "split-divider" ] []
            , -- Right pane: TypeClass grid
              HH.div
                [ HP.class_ $ HH.ClassName "split-pane split-right"
                , HP.id "viz-typeclass"
                ]
                [ if state.loading
                    then HH.div [ HP.class_ $ HH.ClassName "loading" ] [ HH.text "Loading..." ]
                    else HH.text ""
                ]
            ]
        , -- Right: Sidebar
          HH.aside
            [ HP.class_ $ HH.ClassName "sidebar" ]
            [ renderSummary state
            , renderLegend
            , renderFilters state
            , renderDetails state
            ]
        ]
    ]

renderViewToggle :: forall m. ViewMode -> H.ComponentHTML Action () m
renderViewToggle current =
  HH.div
    [ HP.class_ $ HH.ClassName "view-toggle" ]
    [ HH.button
        [ HP.class_ $ HH.ClassName $ if current == ForceGraphView then "active" else ""
        , HE.onClick \_ -> SetViewMode ForceGraphView
        ]
        [ HH.text "Type Graph" ]
    , HH.button
        [ HP.class_ $ HH.ClassName $ if current == TypeClassesView then "active" else ""
        , HE.onClick \_ -> SetViewMode TypeClassesView
        ]
        [ HH.text "Type Classes" ]
    ]

renderSummary :: forall m. State -> H.ComponentHTML Action () m
renderSummary state =
  let
    dataTypes = Array.length $ Array.filter (\t -> t.kind == DataType) state.types
    newtypes = Array.length $ Array.filter (\t -> t.kind == NewtypeDecl) state.types
    classes = Array.length $ Array.filter (\t -> t.kind == TypeClassDecl) state.types
    total = Array.length state.types
    linkCount = Array.length state.links
  in
  HH.section
    [ HP.class_ $ HH.ClassName "summary" ]
    [ HH.h2_ [ HH.text "Summary" ]
    , renderStat "Total types" (show total)
    , renderStat "Data types" (show dataTypes)
    , renderStat "Newtypes" (show newtypes)
    , renderStat "Type classes" (show classes)
    , renderStat "Relationships" (show linkCount)
    ]

renderStat :: forall m. String -> String -> H.ComponentHTML Action () m
renderStat label value =
  HH.div
    [ HP.class_ $ HH.ClassName "stat" ]
    [ HH.span [ HP.class_ $ HH.ClassName "stat-label" ] [ HH.text label ]
    , HH.span [ HP.class_ $ HH.ClassName "stat-value" ] [ HH.text value ]
    ]

renderLegend :: forall m. H.ComponentHTML Action () m
renderLegend =
  HH.section
    [ HP.class_ $ HH.ClassName "legend" ]
    [ HH.h2_ [ HH.text "Legend" ]
    , HH.h3_ [ HH.text "Node Role" ]
    , renderLegendItem colors.typeClass "Type class"
    , renderLegendItem colors.superclass "Superclass"
    , renderLegendItem colors.instanceProvider "Has instances"
    , renderLegendItem colors.referenced "Referenced"
    , renderLegendItem colors.isolated "Isolated"
    , HH.h3_ [ HH.text "Relationships" ]
    , renderLegendItem colors.linkInstance "Instance of"
    , renderLegendItem colors.linkSuperclass "Superclass"
    , renderLegendItem colors.linkUsage "Type usage"
    ]

renderLegendItem :: forall m. String -> String -> H.ComponentHTML Action () m
renderLegendItem color label =
  HH.div
    [ HP.class_ $ HH.ClassName "legend-item" ]
    [ HH.div
        [ HP.class_ $ HH.ClassName "legend-dot"
        , HP.style $ "background: " <> color
        ]
        []
    , HH.text label
    ]

renderFilters :: forall m. State -> H.ComponentHTML Action () m
renderFilters state =
  HH.section
    [ HP.class_ $ HH.ClassName "filters" ]
    [ HH.h2_ [ HH.text "Filters" ]
    , HH.div
        [ HP.class_ $ HH.ClassName "filter-group" ]
        [ HH.label_ [ HH.text "Show:" ]
        , HH.select
            [ HE.onValueChange \v -> SetFilter (parseFilter v) ]
            [ HH.option [ HP.value "all", HP.selected (state.filter == ShowAllTypes) ] [ HH.text "All types" ]
            , HH.option [ HP.value "data", HP.selected (state.filter == ShowDataTypes) ] [ HH.text "Data types" ]
            , HH.option [ HP.value "newtype", HP.selected (state.filter == ShowNewtypes) ] [ HH.text "Newtypes" ]
            , HH.option [ HP.value "class", HP.selected (state.filter == ShowTypeClasses) ] [ HH.text "Type classes" ]
            , HH.option [ HP.value "low", HP.selected (state.filter == ShowLowMaturity) ] [ HH.text "Low maturity" ]
            ]
        ]
    , HH.div
        [ HP.class_ $ HH.ClassName "filter-group" ]
        [ HH.label_ [ HH.text "Cluster by:" ]
        , HH.select
            [ HE.onValueChange \v -> SetClusterStrategy (parseCluster v) ]
            [ HH.option [ HP.value "package", HP.selected (state.clusterStrategy == ByPackage) ] [ HH.text "Package" ]
            , HH.option [ HP.value "maturity", HP.selected (state.clusterStrategy == ByMaturity) ] [ HH.text "Maturity" ]
            , HH.option [ HP.value "kind", HP.selected (state.clusterStrategy == ByTypeKind) ] [ HH.text "Type kind" ]
            , HH.option [ HP.value "module", HP.selected (state.clusterStrategy == ByModule) ] [ HH.text "Module" ]
            ]
        ]
    ]

parseFilter :: String -> TypeFilter
parseFilter = case _ of
  "data" -> ShowDataTypes
  "newtype" -> ShowNewtypes
  "class" -> ShowTypeClasses
  "low" -> ShowLowMaturity
  _ -> ShowAllTypes

parseCluster :: String -> ClusterStrategy
parseCluster = case _ of
  "maturity" -> ByMaturity
  "kind" -> ByTypeKind
  "module" -> ByModule
  _ -> ByPackage

renderDetails :: forall m. State -> H.ComponentHTML Action () m
renderDetails state =
  HH.section
    [ HP.class_ $ HH.ClassName "details" ]
    [ HH.h2_ [ HH.text "Details" ]
    , case state.selectedType of
        Nothing ->
          HH.p
            [ HP.class_ $ HH.ClassName "hint" ]
            [ HH.text "Click a node to see type details" ]
        Just typeId ->
          case Array.find (\t -> t.id == typeId) state.types of
            Nothing -> HH.text "Type not found"
            Just typeInfo -> renderTypeDetail typeInfo state
    ]

renderTypeDetail :: forall m. TypeInfo -> State -> H.ComponentHTML Action () m
renderTypeDetail typeInfo state =
  let
    instancesForType = Array.filter (\i -> i.typeId == typeInfo.id) state.instances
  in
  HH.div
    [ HP.class_ $ HH.ClassName "type-detail" ]
    [ renderField "Name" (HH.text typeInfo.name)
    , renderField "Kind" (HH.text $ show typeInfo.kind)
    , renderField "Module" (HH.text typeInfo.moduleName)
    , renderField "Package" (HH.text typeInfo.packageName)
    , renderField "Type parameters" (HH.text $ show typeInfo.typeParameters)
    , renderField "Instance count" (HH.text $ show typeInfo.instanceCount)
    , renderField "Maturity level" (HH.text $ show typeInfo.maturityLevel <> "/8")
    , HH.div
        [ HP.class_ $ HH.ClassName "instances-list" ]
        [ HH.h4_ [ HH.text "Instances:" ]
        , if Array.null instancesForType
            then HH.text "None"
            else HH.ul_ $ map (\i -> HH.li_ [ HH.text $ i.className <> " (" <> i.classModule <> ")" ]) instancesForType
        ]
    ]

renderField :: forall m. String -> H.ComponentHTML Action () m -> H.ComponentHTML Action () m
renderField label value =
  HH.div
    [ HP.class_ $ HH.ClassName "field" ]
    [ HH.div [ HP.class_ $ HH.ClassName "field-label" ] [ HH.text label ]
    , HH.div [ HP.class_ $ HH.ClassName "field-value" ] [ value ]
    ]

-- | Handle actions
handleAction :: forall o m. MonadAff m => Action -> H.HalogenM State Action () o m Unit
handleAction = case _ of
  Initialize -> do
    -- Load data from API
    result <- liftAff Loader.loadTypeData
    handleAction (DataLoaded result)

  DataLoaded (Left err) -> do
    H.modify_ _ { loading = false, error = Just err }

  DataLoaded (Right typeData) -> do
    H.modify_ _
      { loading = false
      , error = Nothing
      , types = typeData.types
      , links = typeData.links
      , instances = typeData.instances
      }
    state <- H.get

    -- Create subscription for HATS -> Halogen communication
    { emitter, listener } <- liftEffect HS.create

    -- Initialize force graph (default view)
    handle <- liftEffect $ ForceGraph.initForceGraph "#viz-graph" state.types state.links

    -- Wire up node clicks
    liftEffect $ handle.onNodeClick \typeId ->
      HS.notify listener (SelectType typeId)

    void $ H.subscribe emitter

  SelectType typeId ->
    H.modify_ _ { selectedType = Just typeId }

  ClearSelection ->
    H.modify_ _ { selectedType = Nothing }

  SetFilter filter ->
    H.modify_ _ { filter = filter }

  SetClusterStrategy strategy ->
    H.modify_ _ { clusterStrategy = strategy }

  SetViewMode mode -> do
    H.modify_ _ { viewMode = mode }
    state <- H.get

    case mode of
      ForceGraphView -> do
        -- Force graph already initialized on data load, just show it
        pure unit

      TypeClassesView -> do
        -- Load both datasets if needed, then initialize split panes
        case state.matrixData, state.typeClassData of
          Just matrix, Just tcData -> do
            -- Both loaded, initialize both panes (clear first)
            liftEffect $ clearContainer "#viz-matrix"
            liftEffect $ clearContainer "#viz-typeclass"
            _ <- liftEffect $ Matrix.initMatrixView "#viz-matrix" matrix
            _ <- liftEffect $ TypeClassGrid.initTypeClassGrid "#viz-typeclass" tcData
            pure unit
          Nothing, _ -> do
            -- Load matrix data first
            result <- liftAff Loader.loadMatrixData
            handleAction (MatrixDataLoaded result)
          _, Nothing -> do
            -- Load typeclass data
            result <- liftAff Loader.loadTypeClassGridData
            handleAction (TypeClassDataLoaded result)

  MatrixDataLoaded (Left err) ->
    H.modify_ _ { error = Just err }

  MatrixDataLoaded (Right matrixData) -> do
    H.modify_ _ { matrixData = Just matrixData }
    state <- H.get
    case state.viewMode of
      TypeClassesView -> case state.typeClassData of
        Just tcData -> do
          liftEffect $ clearContainer "#viz-matrix"
          liftEffect $ clearContainer "#viz-typeclass"
          _ <- liftEffect $ Matrix.initMatrixView "#viz-matrix" matrixData
          _ <- liftEffect $ TypeClassGrid.initTypeClassGrid "#viz-typeclass" tcData
          pure unit
        Nothing -> do
          result <- liftAff Loader.loadTypeClassGridData
          handleAction (TypeClassDataLoaded result)
      _ -> pure unit

  TypeClassDataLoaded (Left err) ->
    H.modify_ _ { error = Just err }

  TypeClassDataLoaded (Right tcData) -> do
    H.modify_ _ { typeClassData = Just tcData }
    state <- H.get
    case state.viewMode of
      TypeClassesView -> case state.matrixData of
        Just matrixData -> do
          liftEffect $ clearContainer "#viz-matrix"
          liftEffect $ clearContainer "#viz-typeclass"
          _ <- liftEffect $ Matrix.initMatrixView "#viz-matrix" matrixData
          _ <- liftEffect $ TypeClassGrid.initTypeClassGrid "#viz-typeclass" tcData
          pure unit
        Nothing -> do
          result <- liftAff Loader.loadMatrixData
          handleAction (MatrixDataLoaded result)
      _ -> pure unit

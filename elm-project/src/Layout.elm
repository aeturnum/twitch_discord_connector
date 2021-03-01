module Layout exposing (..)

-- import Dict exposing (Dict)
-- import Bootstrap.Grid as Grid
-- import Bootstrap.Grid.Col as Col
-- import Bootstrap.Grid.Row as Row

import Dict exposing (Dict)
import Dropdown
import Helpers.JsonValue as JV
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http
import Json.Decode as JD exposing (Decoder, field, map4, string)
import Json.Encode exposing (encode)
import MainUI exposing (..)
import String exposing (String)


type alias Src =
    { name : String
    , path : String
    , sample : JV.JsonValue
    , description : String
    }


type Arg
    = Literal JV.JsonValue
    | Call SrcCall


type alias SrcCall =
    { path : String
    , args : List Arg
    , keys : List String
    }


type Template
    = Node Arg
    | Tree (Dict String Template)


type Msg
    = Navigate String
    | Sources (Result Http.Error (List Src))
    | SourceSelected (Maybe Src)
    | DropDownChange String (Maybe String)


type alias Model =
    { page : String, sources : List Src, srcDropDown : Dict String String, srcSelected : Maybe Src }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { page = "Home", sources = [], srcDropDown = Dict.fromList [ ( "info", "" ) ], srcSelected = Nothing }, listSources )


srcDecoder : Decoder Src
srcDecoder =
    map4 Src
        (field "name" string)
        (field "path" string)
        (field "sample" JV.decoder)
        (field "description" string)


srcListDecoder : Decoder (List Src)
srcListDecoder =
    JD.list srcDecoder


listSources : Cmd Msg
listSources =
    Http.get
        { url = "/templ/sources"
        , expect = Http.expectJson Sources srcListDecoder
        }


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- let
--     states =
--         Dict.toList model.srcDropDown
-- in
-- Sub.batch
--     (List.map
--         (\( key, state ) -> Dropdown.subscriptions state (SrcDropDownChange key))
--         states
--     )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Navigate newPage ->
            ( { model | page = newPage }, Cmd.none )

        Sources result ->
            case result of
                Ok srcs ->
                    ( { model | sources = srcs }, Cmd.none )

                Err _ ->
                    ( { model | sources = [] }, Cmd.none )

        DropDownChange key state ->
            case state of
                Nothing ->
                    ( model, Cmd.none )

                Just path ->
                    let
                        m =
                            { model | srcDropDown = Dict.insert key path model.srcDropDown }

                        src =
                            List.head <| List.filter (\s -> s.path == path) model.sources
                    in
                    ( { m | srcSelected = src }, Cmd.none )

        -- let
        --     ddDict =  (Maybe.withDefault "" state) model.srcDropDown
        --      = List.filter (\s -> s.path == src)
        -- in
        --     ( { model | srcDropDown = ddDict }, Cmd.none )
        SourceSelected src ->
            ( { model | srcSelected = src }, Cmd.none )


navButton : Model -> String -> Html Msg
navButton model name =
    let
        dis =
            name == model.page
    in
    div []
        [ button [ onClick (Navigate name), class "pure-button", disabled dis ] [ text name ] ]


header : Model -> Html Msg
header _ =
    div [ class "header" ] [ h1 [] [ text "Twitch Discord Connector" ] ]


grid : String -> List (Html msg) -> Html msg
grid cls children =
    div [ class cls ] children


col : List (Html msg) -> Html msg
col children =
    grid "" children


left : List (Html msg) -> Html msg
left children =
    grid "left" children


right : List (Html msg) -> Html msg
right children =
    grid "right" children


row : List (Html msg) -> Html msg
row children =
    grid "row" children


makeDropDown : Model -> String -> String -> Html Msg
makeDropDown model key txt =
    let
        names =
            List.map (\src -> { text = src.path, value = src.path, enabled = True }) model.sources
    in
    div []
        [ label [] [ text txt ]
        , div [ class "select" ]
            [ Dropdown.dropdown
                { items = names, emptyItem = Nothing, onChange = DropDownChange key }
                []
                (Dict.get key model.srcDropDown)
            ]
        ]


selectedSourceInfo : Model -> Html Msg
selectedSourceInfo model =
    case model.srcSelected of
        Nothing ->
            row []

        Just src ->
            grid "pure-g"
                [ grid "pure-u-1-4 left" [ strong [] [ text "Name" ] ]
                , grid "pure-u-3-4 right" [ p [] [ text src.path ] ]
                , grid "pure-u-1-4 left" [ strong [] [ text "Description" ] ]
                , grid "pure-u-3-4 right" [ p [] [ text src.description ] ]
                , grid "pure-u-1-4 left" [ strong [] [ text "Sample" ] ]
                , grid "pure-u-3-4 right" [ p [] [ text (encode 2 (JV.encoder src.sample)) ] ]
                ]


templateSrcs : Model -> Html Msg
templateSrcs model =
    grid "template-srcs wireframe"
        [ row [ makeDropDown model "info" "Available Functions" ]
        , selectedSourceInfo model
        ]


templateJson : Model -> Html Msg
templateJson _ =
    div [ class "template-json wireframe" ] [ text "template json" ]


templateControls : Model -> Html Msg
templateControls _ =
    div [ class "template-controls wireframe" ] [ text "template controls" ]


templateEditor : Model -> List (Html Msg)
templateEditor model =
    [ templateJson model
    , templateSrcs model
    , templateControls model
    ]


sidebar : Model -> Html Msg
sidebar page =
    div [ class "sidebar" ]
        (List.map
            (\name -> navButton page name)
            [ "Home", "Account" ]
        )


mainPage : Model -> List (Html Msg)
mainPage model =
    case model.page of
        "Account" ->
            MainUI.account

        "Home" ->
            templateEditor model

        _ ->
            templateEditor model


layout : Model -> Html Msg
layout model =
    grid "container"
        (List.append [ sidebar model, header model ] (mainPage model))

module Template.View exposing (..)

import Dropdowns.View as DD
import Helpers.JsonValue as JV
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as JD exposing (Decoder, field, string)
import Json.Encode exposing (encode)
import Maybe exposing (..)
import Msg as Main
import String.Format
import Template.Model exposing (..)
import Template.Msg exposing (..)
import Template.Src exposing (..)


grid : String -> List (Html Main.Msg) -> Html Main.Msg
grid cls children =
    div [ class cls ] children


left : List (Html Main.Msg) -> Html Main.Msg
left children =
    grid "left" children


right : List (Html Main.Msg) -> Html Main.Msg
right children =
    grid "right" children


infoLine : String -> String -> Html Main.Msg
infoLine label data =
    grid "columns"
        [ grid "column" [ strong [] [ text label ] ]
        , grid "column" [ strong [] [ text data ] ]
        ]


selectedSourceInfo : Template -> Html Main.Msg
selectedSourceInfo tem =
    case tem.selectedSrc of
        Nothing ->
            grid "" []

        Just src ->
            grid ""
                [ infoLine "Name" src.path
                , infoLine "Description" src.description
                , infoLine "Sample" (encode 2 (JV.encoder src.sample))
                ]


templateSrcs : Template -> Html Main.Msg
templateSrcs tem =
    let
        items =
            List.map (\s -> s.path) tem.sources
    in
    grid "template-srcs"
        [ grid "columns"
            [ div [ class "column" ]
                [ label [] [ text "Available Functions" ]
                , DD.myDropDown tem.ddState "info" items (Main.TemplateMessage << DropDownMessage "info")
                ]
            ]
        , selectedSourceInfo tem
        ]


jsonDepth : Arg -> Int
jsonDepth a =
    case a of
        Call _ ->
            0

        Literal j ->
            JV.objectDepth j


keyCount : Arg -> Int
keyCount a =
    case a of
        Call _ ->
            1

        Literal j ->
            JV.keyCount j


jsonCell : Int -> List (Html Main.Msg) -> Html Main.Msg
jsonCell columns =
    grid ("column is-{{ section }} json-item" |> String.Format.namedValue "section" (String.fromInt columns))


jsonItem : Template -> Int -> Int -> List (Html Main.Msg)
jsonItem tem row column =
    [ p []
        [ text
            ("( {{ row }}, {{ col }} )"
                |> String.Format.namedValue "row" (String.fromInt row)
                |> String.Format.namedValue "col" (String.fromInt column)
            )
        ]
    ]


jsonLine : Template -> ( Int, Int ) -> Int -> Int -> List (Html Main.Msg)
jsonLine tem dims row column =
    let
        _ =
            Debug.log "line" ( dims, row, column )

        ji =
            jsonItem tem row column

        col_count =
            Tuple.second dims
    in
    if Tuple.first dims <= row + 1 then
        jsonCell col_count ji :: jsonLine tem dims (row + 1) column

    else
        let
            _ =
                Debug.log "row end" ""
        in
        [ jsonCell col_count ji ]


jsonFields : Template -> ( Int, Int ) -> Int -> List (Html Main.Msg)
jsonFields tem dims column =
    let
        _ =
            Debug.log "fields" ( dims, column )

        col_count =
            Tuple.second dims
    in
    if col_count == column then
        [ grid "columns" (jsonLine tem dims 0 column) ]

    else
        grid "columns" (jsonLine tem dims 0 column) :: jsonFields tem dims (column + 1)


templateJson : Template -> Html Main.Msg
templateJson tem =
    let
        rows =
            keyCount tem.root

        cols =
            jsonDepth tem.root
    in
    div [ class "template-json column" ]
        (jsonFields tem ( rows, cols ) 0)


templateControls : Template -> Html Main.Msg
templateControls _ =
    div [ class "template-controls" ] [ text "template controls" ]


templateEditor : Template -> Html Main.Msg
templateEditor tem =
    grid "columns"
        [ templateJson tem
        , grid
            "column is-4"
            [ templateSrcs tem
            , templateControls tem
            ]
        ]



-- Get Sources


srcDecoder : Decoder Src
srcDecoder =
    JD.map4 Src
        (field "name" string)
        (field "path" string)
        (field "sample" JV.decoder)
        (field "description" string)


srcListDecoder : Decoder (List Src)
srcListDecoder =
    JD.list srcDecoder


listSources : Cmd Main.Msg
listSources =
    Http.get
        { url = "/templ/sources"
        , expect = Http.expectJson (Main.TemplateMessage << Sources) srcListDecoder
        }

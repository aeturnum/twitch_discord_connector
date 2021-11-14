module View exposing (..)

-- import Dict exposing (Dict)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Model exposing (Model)
import Msg as Main
import String exposing (String)
import Template.View exposing (templateEditor)


grid : String -> List (Html Main.Msg) -> Html Main.Msg
grid cls children =
    div [ class cls ] children


navButton : Main.Page -> String -> Html Main.Msg
navButton page name =
    let
        dis =
            name == page
    in
    div []
        [ button [ onClick (Main.LayoutMsg page), class "button", disabled dis ] [ text name ] ]


header : Html Main.Msg
header =
    grid "columns" [ grid "column" [ h1 [ class "title" ] [ text "Twitch Discord Connector" ] ] ]


home : Html Main.Msg
home =
    div [ class "content block" ]
        [ h1 [] [ text "Welcome to the Twitch Discord Connector" ]
        , p []
            [ text <|
                """ 
                This is a server that will send out information about your channel and stream when you go
                online and features a variety of convience features over what IFTT and other more general
                services offer.
                """
            ]
        ]


sidebar : Main.Page -> Html Main.Msg
sidebar page =
    div [ class "sidebar column is-1" ]
        (List.map
            (\name -> navButton page name)
            [ "Home", "Account" ]
        )


mainPage : Model -> Html Main.Msg
mainPage model =
    case model.page of
        "Home" ->
            templateEditor model.tem

        _ ->
            templateEditor model.tem


layout : Model -> Html Main.Msg
layout model =
    grid "columns"
        [ sidebar model.page
        , grid "column"
            [ header, mainPage model ]
        ]

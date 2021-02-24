module Layout exposing (..)

import Browser
import Header exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import MainUI exposing (..)
import Sidebar exposing (..)
import State exposing (..)


layout : Model -> Html Msg
layout model =
    div [ class "container" ]
        [ Header.header
        , sidebar model
        , mainPage model
        ]

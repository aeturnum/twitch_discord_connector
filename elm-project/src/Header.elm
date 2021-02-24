module Header exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import State exposing (..)


header : Html Msg
header =
    div [ class "jumbotron", class "header" ] [ h1 [] [ text "Twitch Discord Connector" ] ]

module MainUI exposing (..)

-- import Html.Events exposing (onClick, onInput)

import Html exposing (..)
import Html.Attributes exposing (..)
import State exposing (..)


home : Model -> Html Msg
home _ =
    div [ class "jumbotron", class "main" ]
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


account : Model -> Html Msg
account _ =
    div [ class "jumbotron", class "main" ]
        [ h1 [] [ text "Setup Account" ]
        , p [] [ text "Test Area" ]
        ]


mainPage : Model -> Html Msg
mainPage model =
    case model.page of
        "Other" ->
            account model

        "Home" ->
            home model

        _ ->
            home model

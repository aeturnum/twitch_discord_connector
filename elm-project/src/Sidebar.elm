module Sidebar exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import State exposing (..)


makeButton : Model -> String -> Html Msg
makeButton model name =
    let
        cls =
            if model.page == name then
                "btn btn-primary"

            else
                "btn btn-secondary"
    in
    button [ onClick (Navigate name), class cls ] [ text name ]


sidebar : Model -> Html Msg
sidebar model =
    div [ class "sidebar" ]
        (List.map
            (\n -> makeButton model n)
            [ "Home", "Other" ]
        )



-- [ makeButton model "Home", makeButton model "Other" ]

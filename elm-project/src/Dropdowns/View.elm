module Dropdowns.View exposing (..)

import Dict
import Dropdown
import Dropdowns.Model exposing (State)
import Dropdowns.Msg exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Msg as Main

myDropDown : State -> String -> List String -> (Maybe String -> Main.Msg) -> Html Main.Msg
myDropDown ddstate key item_keys msg_maker =
    let
        itms =
            List.map (\s -> { text = s, value = s, enabled = True }) item_keys
    in
    div [ class "select" ]
        [ Dropdown.dropdown
            { items = itms, emptyItem = Nothing, onChange = msg_maker }
            []
            (Dict.get key ddstate)
        ]

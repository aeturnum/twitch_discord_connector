module Dropdowns.Update exposing (..)

import Dict exposing (..)
import Dropdowns.Model exposing (..)
import Dropdowns.Msg exposing (..)


update : State -> String -> Maybe String -> State
update state key val =
        if Dict.member key state then
            Dict.insert key (Maybe.withDefault "" val) state

        else
            state

module Dropdowns.Model exposing (..)

import Dict exposing (..)


type alias State =
    Dict String String


makeDropDownState : List ( String, String ) -> State
makeDropDownState entries =
    Dict.fromList entries

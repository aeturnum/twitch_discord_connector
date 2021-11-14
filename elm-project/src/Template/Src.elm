module Template.Src exposing (..)

import Helpers.JsonValue as JV


type alias Src =
    { name : String
    , path : String
    , sample : JV.JsonValue
    , description : String
    }

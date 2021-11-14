module Template.Model exposing (..)

import Dict exposing (..)
import Helpers.JsonValue as JV
import Template.Src exposing (..)
import Dropdowns.Model as DD


-- import Dropdowns.Model as DD


makeTemplate : Template
makeTemplate =
    { selectedPath = []
    , root = Literal (JV.JsonObject <| Dict.empty)
    , sources = []
    , selectedSrc = Nothing
    , ddState = DD.makeDropDownState [ ( "info", "" ) ]
    }


type Arg
    = Literal JV.JsonValue
    | Call SrcCall


type alias SrcCall =
    { path : String
    , args : List Arg
    , keys : List String
    }

type alias Template =
    { selectedPath : List String
    , root : Arg
    , sources : List Src
    , selectedSrc : Maybe Src
    , ddState : DD.State
    }

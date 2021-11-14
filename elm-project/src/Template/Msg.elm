module Template.Msg exposing (..)

import Http
import Template.Src exposing (..)


type Msg
    = SourceSelected (Maybe String)
    | Sources (Result Http.Error (List Src))
    | DropDownMessage String (Maybe String)

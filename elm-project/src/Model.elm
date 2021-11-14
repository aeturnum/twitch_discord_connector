module Model exposing (..)

import Msg
import Template.Model as Tem


init : () -> ( Model, Cmd msg )
init _ =
    ( { tem = Tem.makeTemplate, page = "Home" }, Cmd.none )


type alias Model =
    { tem : Tem.Template
    , page : Msg.Page
    }

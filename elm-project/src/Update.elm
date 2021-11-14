module Update exposing (..)

-- import Dropdowns.Update as Dropdowns

import Model exposing (..)
import Msg exposing (..)
import Template.Update as Template


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LayoutMsg p ->
            ( { model | page = p }, Cmd.none )

        TemplateMessage m ->
            ( { model | tem = Template.update m model.tem }, Cmd.none )

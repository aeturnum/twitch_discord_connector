module Main exposing (..)

import Browser
import Html exposing (..)
import Model
import Msg
import Update
import View


view : Model.Model -> Html Msg.Msg
view model =
    View.layout model


main : Program () Model.Model Msg.Msg
main =
    Browser.element { init = Model.init, update = Update.update, subscriptions = \_ -> Sub.none, view = view }

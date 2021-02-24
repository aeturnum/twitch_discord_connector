module Main exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Layout exposing (layout)
import State exposing (init, update)


main =
    Browser.sandbox { init = init, update = update, view = layout }

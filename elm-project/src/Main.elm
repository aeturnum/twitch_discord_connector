module Main exposing (..)

import Browser
import Layout exposing (init, layout, subscriptions, update)


main =
    Browser.element { init = init, update = update, subscriptions = subscriptions, view = layout }

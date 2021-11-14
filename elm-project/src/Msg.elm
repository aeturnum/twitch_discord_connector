module Msg exposing (..)

-- import Dropdowns.Msg as Dropdowns
-- import Layout.Msg as Layout

import Template.Msg as Template


type alias Page =
    String


type Msg
    = LayoutMsg Page
    | TemplateMessage Template.Msg

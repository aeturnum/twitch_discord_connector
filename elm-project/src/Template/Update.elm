module Template.Update exposing (..)

import Template.Model exposing (..)
import Template.Msg exposing (..)
import Template.Src exposing (..)
import Dropdowns.Update as DD


findSource : List Src -> String -> Maybe Src
findSource srcs name =
    List.head (List.filter (\s -> s.path == name) srcs)


update : Msg -> Template -> Template
update msg tem =
    case msg of
        SourceSelected src ->
            case src of
                Nothing ->
                    tem

                Just name ->
                    { tem | selectedSrc = findSource tem.sources name }

        Sources result ->
            case result of
                Ok srcs ->
                    { tem | sources = srcs }

                Err _ ->
                    { tem | sources = [] }

        DropDownMessage key selection ->
            {tem | ddState = DD.update tem.ddState key selection }
            
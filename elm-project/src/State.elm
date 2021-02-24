module State exposing (..)


type alias Model =
    { content : String
    , page : String
    }


type Msg
    = Change String
    | Navigate String


init : Model
init =
    { content = ""
    , page = "Home"
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        Change newContent ->
            { model | content = newContent }

        Navigate newPage ->
            { model | page = newPage }

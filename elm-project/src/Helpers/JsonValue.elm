module Helpers.JsonValue exposing (JsonValue(..), decoder, encoder)

import Dict exposing (Dict)
import Json.Decode
    exposing
        ( Decoder
        , bool
        , dict
        , float
        , int
        , lazy
        , list
        , map
        , null
        , oneOf
        , string
        )
import Json.Encode as En


type JsonValue
    = JsonString String
    | JsonInt Int
    | JsonFloat Float
    | JsonBoolean Bool
    | JsonArray (List JsonValue)
    | JsonObject (Dict String JsonValue)
    | JsonNull


decoder : Decoder JsonValue
decoder =
    oneOf
        [ map JsonString string
        , map JsonInt int
        , map JsonFloat float
        , map JsonBoolean bool
        , list (lazy (\_ -> decoder)) |> map JsonArray
        , dict (lazy (\_ -> decoder)) |> map JsonObject
        , null JsonNull
        ]


encoder : JsonValue -> En.Value
encoder jv =
    case jv of
        JsonString s ->
            En.string s

        JsonInt i ->
            En.int i

        JsonFloat f ->
            En.float f

        JsonBoolean b ->
            En.bool b

        JsonArray arr ->
            En.list encoder arr

        JsonObject obj ->
            En.dict identity encoder obj

        JsonNull ->
            En.null

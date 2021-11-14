module Helpers.JsonValue exposing (JsonValue(..), decoder, encoder, keyCount, objectDepth)

import Array exposing (Array)
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


objectDepth : JsonValue -> Int
objectDepth j =
    case j of
        JsonObject d ->
            1 + Maybe.withDefault 0 (List.maximum <| List.map (\v -> objectDepth v) (Dict.values d))

        _ ->
            0


keyCount : JsonValue -> Int
keyCount j =
    case j of
        JsonArray ja ->
            2 + List.sum (List.map (\ele -> keyCount ele) ja)

        JsonObject jo ->
            2 + List.sum (List.map (\ele -> keyCount ele) (Dict.values jo))

        _ ->
            1


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

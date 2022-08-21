#!/usr/bin/env escript
-module(toml).
-export([main/1]).

toml_to_json_(A) ->
    parsers@toml@printer:toml_to_json(A).

read_stdin(A) ->
    case io:get_line("") of
        eof ->
            {ok, It} = toml_to_json_(string:join(A, "")),
            io:format("~ts", [It]),
            init:stop();
        Line ->
            read_stdin(A ++ [Line])
    end.

main([]) ->
    io:setopts([{encoding, unicode}]),
    true = code:add_pathz("/workspaces/parser_gleam/build/dev/erlang/parser_gleam/ebin"),
    true = code:add_pathz("/workspaces/parser_gleam/build/dev/erlang/gleam_stdlib/ebin"),
    true = code:add_pathz("/workspaces/parser_gleam/build/dev/erlang/fp_gl/ebin"),
    true = code:add_pathz("/workspaces/parser_gleam/build/dev/erlang/gleam_json/ebin"),
    true = code:add_pathz("/workspaces/parser_gleam/build/dev/erlang/thoas/ebin"),
    read_stdin([]).

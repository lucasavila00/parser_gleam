#!/usr/bin/env escript
-module(toml).
-export([main/1]).

to_json_(A) ->
    It = parsers@toml@printer:parse_json(A),
    parsers@toml@printer:print(It).

read_stdin(A) ->
    case io:get_line("") of
        eof ->
            It = to_json_(string:join(A, "")),
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

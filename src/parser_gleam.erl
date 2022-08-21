-module(parser_gleam).

-export([to_unicode_str/1]).

to_unicode_str(X) ->
    unicode:characters_to_list(list_to_binary(X)).

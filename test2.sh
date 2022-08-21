gleam build --target erlang && \
clear &&\
toml-test scripts/print_toml.erl -encoder -run valid/bool/* && \
toml-test scripts/print_toml.erl -encoder -run valid/float/* && \
toml-test scripts/print_toml.erl -encoder -run valid/integer/* && \
toml-test scripts/print_toml.erl -encoder -run valid/datetime/* && \
toml-test scripts/print_toml.erl -encoder -run valid/table/* -skip valid/table/names && \
toml-test scripts/print_toml.erl -encoder -run valid/array/* && \
toml-test scripts/print_toml.erl -encoder -run valid/inline-table/* && \
toml-test scripts/print_toml.erl -encoder -run valid/key/* -skip valid/key/escapes -skip valid/key/case-sensitive && \
toml-test scripts/print_toml.erl -encoder -run valid/comment/* && \
toml-test scripts/print_toml.erl -encoder -run valid/* && \
toml-test scripts/print_toml.erl -encoder -run valid/string/* -skip valid/string/unicode-literal \
-skip valid/string/unicode-escape -skip valid/string/escape-tricky && \
echo "ok"
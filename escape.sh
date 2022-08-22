
gleam build --target erlang && \
clear &&\
toml-test scripts/print_toml.erl -encoder -run valid/key/escapes
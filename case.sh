gleam build --target erlang && \
clear &&\
toml-test scripts/toml.erl -run invalid/table/duplicate-key-dotted-table
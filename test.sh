gleam build --target erlang && \
clear &&\
toml-test scripts/toml.erl -run valid/integer/* && \
toml-test scripts/toml.erl -run valid/bool/* && \
toml-test scripts/toml.erl -run valid/table/* && \
toml-test scripts/toml.erl -run valid/datetime/* && \
toml-test scripts/toml.erl -run valid/string/* && \
toml-test scripts/toml.erl -run valid/inline-table/* && \
# toml-test scripts/toml.erl -run valid/array/* && \
# toml-test scripts/toml.erl -run valid/key/* && \
# toml-test scripts/toml.erl -run valid/comment/* && \
echo "ok"
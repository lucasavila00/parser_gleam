gleam build --target erlang && \
clear &&\
toml-test scripts/print_toml.erl -encoder -run valid/bool/* && \
toml-test scripts/print_toml.erl -encoder -run valid/float/* && \
toml-test scripts/print_toml.erl -encoder -run valid/integer/* && \
toml-test scripts/print_toml.erl -encoder -run valid/datetime/* && \
toml-test scripts/print_toml.erl -encoder -run valid/table/* && \
# toml-test scripts/print_toml.erl -encoder -run valid/string/* && \
# toml-test scripts/print_toml.erl -encoder -run valid/array/* && \
# toml-test scripts/print_toml.erl -encoder -run valid/comment/* && \
# toml-test scripts/print_toml.erl -encoder -run valid/inline-table/* && \
# toml-test scripts/print_toml.erl -encoder -run valid/key/* && \
# toml-test scripts/print_toml.erl -encoder -run valid/* && \
echo "ok"
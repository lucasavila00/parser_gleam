gleam build --target erlang && \
clear &&\
toml-test scripts/toml.erl -run valid/array/* && \
toml-test scripts/toml.erl -run valid/bool/* && \
toml-test scripts/toml.erl -run valid/comment/* && \
toml-test scripts/toml.erl -run valid/datetime/* && \
toml-test scripts/toml.erl -run valid/float/* && \
toml-test scripts/toml.erl -run valid/inline-table/* && \
toml-test scripts/toml.erl -run valid/integer/* && \
toml-test scripts/toml.erl -run valid/key/* && \
toml-test scripts/toml.erl -run valid/string/* && \
toml-test scripts/toml.erl -run valid/table/* && \
toml-test scripts/toml.erl -run valid/* && \
toml-test scripts/toml.erl -run invalid/array/* && \
toml-test scripts/toml.erl -run invalid/bool/* && \
toml-test scripts/toml.erl -run invalid/datetime/* && \
toml-test scripts/toml.erl -run invalid/float/* && \
toml-test scripts/toml.erl -run invalid/integer/* && \
# toml-test scripts/toml.erl -run invalid/table/* && \
# toml-test scripts/toml.erl -run invalid/inline-table/* && \
# toml-test scripts/toml.erl -run invalid/key/* && \
# toml-test scripts/toml.erl -run invalid/string/* && \
# toml-test scripts/toml.erl -run invalid/encoding /* && \
# toml-test scripts/toml.erl -run invalid/control/* && \
echo "ok"
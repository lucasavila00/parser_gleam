gleam build --target javascript && \
clear &&\
# toml-test scripts/toml.erl -run valid/integer/* && \
# toml-test scripts/toml.erl -run valid/bool/* && \
# toml-test scripts/toml.erl -run valid/table/* && \
# toml-test scripts/toml.erl -run valid/datetime/* && \
toml-test scripts/toml.erl -run valid/string/* && \
# toml-test scripts/toml.erl -run valid/comment/* && \
echo "ok"
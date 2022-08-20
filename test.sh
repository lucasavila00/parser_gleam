gleam build --target javascript && \
toml-test scripts/toml.erl -run valid/integer/* && \
toml-test scripts/toml.erl -run valid/bool/* && \
toml-test scripts/toml.erl -run valid/comment/* && \
echo "ok"
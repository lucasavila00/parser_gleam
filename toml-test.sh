gleam build --target erlang && \
clear &&\
toml-test scripts/toml.erl -skip valid/string/escapes -skip valid/string/multiline-quotes \
-skip invalid/table/duplicate-key-dotted-table -skip invalid/table/duplicate-key-dotted-table2 \
-skip invalid/control/* -skip invalid/inline-table/add -skip invalid/inline-table/overwrite
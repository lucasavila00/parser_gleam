FROM mcr.microsoft.com/vscode/devcontainers/javascript-node:0-18-bullseye

RUN wget https://github.com/gleam-lang/gleam/releases/download/nightly/gleam-nightly-linux-amd64.tar.gz
RUN mkdir -p /usr/local/gleam && tar -C /usr/local/gleam -xzf gleam-nightly-linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/gleam
RUN rm -rf gleam-nightly-linux-amd64.tar.gz

RUN wget https://s3.amazonaws.com/rebar3/rebar3
RUN mkdir -p /usr/local/rebar3 && cp ./rebar3 /usr/local/rebar3/rebar3
ENV PATH=$PATH:/usr/local/rebar3
RUN chmod +x /usr/local/rebar3/rebar3

RUN wget https://github.com/BurntSushi/toml-test/releases/download/v1.2.0/toml-test-v1.2.0-linux-amd64.gz
RUN mkdir -p /usr/local/toml-test && gunzip -c toml-test-v1.2.0-linux-amd64.gz > /usr/local/toml-test/toml-test 
RUN chmod +x /usr/local/toml-test/toml-test
ENV PATH=$PATH:/usr/local/toml-test
RUN rm -rf toml-test-v1.2.0-linux-amd64.gz

RUN wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
RUN dpkg -i erlang-solutions_2.0_all.deb
RUN apt-get update
RUN apt-get -y install --no-install-recommends esl-erlang inotify-tools

RUN gleam new rad_install
WORKDIR /rad_install
RUN gleam add rad
RUN cp /rad_install/build/packages/rad/priv/rad /usr/local/bin/
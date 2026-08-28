# Base image for the Cursor Cloud Agent environment.
#
# Same pinned toolchain the repo's other three routes use — Elixir 1.20.2 on
# Erlang/OTP 27 — because `bin/evalcode` refuses to run on anything else, and
# the whole of task 02 is scored on a warning class that only exists in 1.20's
# type checker. This mirrors the root ./Dockerfile (exercised by the `container`
# CI job); it lives under .cursor/ so Cloud Agents pick it up as their base.
#
# Cursor checks the repository out into /workspace separately, so this image
# deliberately does not COPY the repo in.
FROM hexpm/elixir:1.20.2-erlang-27.3.4.16-debian-trixie-20260713-slim

# build-essential   exqlite compiles SQLite from source during `mix deps.get`
# git               `bin/evalcode start` makes every workspace its own repo,
#                   and Cursor needs it to check the repository out
# rsync, diffutils  bin/evalcode shells out to both
# curl, ca-certs    fetching hex packages and asset binaries over TLS
# inotify-tools     Phoenix live-reload watches the filesystem in dev
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl diffutils git inotify-tools rsync \
 && rm -rf /var/lib/apt/lists/*

# Install hex and rebar into shared locations that stay readable and writable
# whatever uid the agent runs as. Baking them in also stops the first
# `mix deps.get` from pausing to prompt on a container with no tty on stdin.
ENV MIX_HOME=/opt/mix \
    HEX_HOME=/opt/hex \
    LANG=C.UTF-8
RUN mkdir -p /opt/mix /opt/hex \
 && mix local.hex --force \
 && mix local.rebar --force \
 && chmod -R a+rwX /opt/mix /opt/hex

# The checkout is owned by the agent's uid, which may not match the image's;
# git otherwise refuses to operate on a repository it treats as dubiously owned.
RUN git config --system --add safe.directory '*'

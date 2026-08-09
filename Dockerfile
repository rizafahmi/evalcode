# The same toolchain the Nix devshell pins — Elixir 1.20.2 on Erlang/OTP 27 —
# for anyone who would rather not install Nix to run a benchmark.
#
# `bin/evalcode` only ever asks the toolchain one question: does
# `elixir --version` say 1.20.x. Nix, this image, and a plain mise install are
# all equally valid answers, and the refusal in require_elixir_120 is identical
# in all three.
#
# Named Dockerfile rather than Containerfile because both docker and podman
# find that name by default; only podman looks for the other one.
#
#   docker build -t evalcode .
#   docker run --rm -it -v "$PWD:/work" -w /work --user "$(id -u):$(id -g)" evalcode
#
#   podman build -t evalcode .
#   podman run  --rm -it -v "$PWD:/work:Z" -w /work evalcode
#
# The bind mount is the point: runs/ and RESULTS.md land in your checkout
# instead of disappearing with the container. `--user` keeps docker from
# leaving root-owned files behind in it; rootless podman already maps your uid,
# which is why its line does not need the flag.
FROM hexpm/elixir:1.20.2-erlang-27.3.4.16-debian-trixie-20260713-slim

# build-essential   exqlite compiles SQLite from source during `mix deps.get`
# git               `start` makes every workspace its own repository
# rsync, diffutils  bin/evalcode shells out to both
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential ca-certificates diffutils git rsync \
 && rm -rf /var/lib/apt/lists/*

# Set before installing, so hex and rebar land somewhere a non-root uid can
# still read and write. Installing them into the image also stops the first
# `mix deps.get` from pausing to ask, which it cannot do when the container has
# no terminal on stdin.
# HOME matters as much as MIX_HOME here. Run with `--user $(id -u)`, the uid has
# no passwd entry, so HOME falls back to `/` — and exqlite builds through
# elixir_make, which caches under $HOME/.cache. That failed the documented
# invocation with `could not make directory "/.cache/elixir_make": permission
# denied` before `mix deps.get` had finished.
ENV HOME=/home/evalcode \
    MIX_HOME=/opt/mix \
    HEX_HOME=/opt/hex \
    LANG=C.UTF-8
# HEX_HOME is created lazily by the first `mix deps.get`, not by local.hex, so
# it has to be made here — otherwise chmod fails the build on a path that does
# not exist yet, and a container running as your host uid has nowhere to cache.
RUN mkdir -p /opt/mix /opt/hex /home/evalcode \
 && chmod -R a+rwX /home/evalcode \
 && mix local.hex --force \
 && mix local.rebar --force \
 && chmod -R a+rwX /opt/mix /opt/hex

# With `--user`, the bind-mounted checkout is owned by a uid that does not exist
# in this image, and git refuses to operate on a repository it considers to have
# dubious ownership. Inside a throwaway container there is no boundary left for
# that check to protect.
RUN git config --system --add safe.directory '*'

WORKDIR /work
CMD ["bash"]

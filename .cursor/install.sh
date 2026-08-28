#!/usr/bin/env bash
# Idempotent repository bootstrap for the Cursor Cloud Agent environment.
#
# Runs from /workspace after Cursor checks the repository out. It prepares the
# Phoenix skeleton so `bin/evalcode start` is fast and works offline: that
# command copies skeleton/deps and the downloaded esbuild/tailwind binaries
# from skeleton/_build into each new run workspace.
set -euo pipefail

cd "$(dirname "$0")/../skeleton"

# Fetch and compile dependencies (exqlite builds SQLite from C source here).
mix deps.get
mix compile

# Create, migrate and seed the skeleton's own dev database so the dashboard is
# runnable directly with `mix phx.server`. Safe to re-run: create is a no-op if
# the file exists, migrate only applies what is pending, and the seeds look up
# each product by sku before inserting.
mix ecto.setup

# Download the pinned esbuild/tailwind binaries and build the assets. Without
# the binaries under skeleton/_build, a run's dev server tries to download them
# on first boot and, offline, never writes app.js.
mix assets.setup
mix assets.build

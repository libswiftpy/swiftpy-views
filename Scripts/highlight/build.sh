#!/bin/sh
#
# Regenerates Sources/SyntaxHighlight/Resources/highlight.min.js.
#
# The version is pinned: the emitter protocol RangeEmitter implements is not
# highlight.js public API, so an upgrade needs the emitter tests re-run.

set -e
cd "$(dirname "$0")"

npm install --no-save --no-fund --no-audit highlight.js@11.9.0 esbuild@0.25.10

npx esbuild entry.mjs \
    --bundle \
    --minify \
    --format=iife \
    --outfile=../../Sources/SyntaxHighlight/Resources/highlight.min.js

ls -l ../../Sources/SyntaxHighlight/Resources/highlight.min.js

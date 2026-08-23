#!/usr/bin/env bash
quarto render
git add -A
git commit -m "Update site"
git push

echo ">>> Site updated — wait for the GitHub Action that syncs, then refresh to see the result."

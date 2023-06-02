#!/usr/bin/env bash

# This script clones all repos in a GitHub org
# It requires the GH CLI: https://cli.github.com
# It can be re-run to collect new repos and pull the latest changes

set -euo pipefail

USAGE="Usage: gh-clone-org <user|org>"

[[ $# -eq 0 ]] && echo >&2 "missing arguments: ${USAGE}" && exit 1

org=$1
limit=9999

repos="$(gh repo list "$org" -L $limit)"

repo_total="$(echo "$repos" | wc -l)"
repos_complete=0

echo

echo "$repos" | while read -r repo; do
        repo_name="$(echo "$repo" | cut -f1)"
        echo -ne "\r\e[0K[ $repos_complete / $repo_total ] Cloning $repo_name"
        gh repo clone "$repo_name" "$repo_name" -- -q 2>/dev/null || (
                cd "$repo_name"
                git pull -q
        )
        repos_complete=$((repos_complete + 1))
done

echo "Finished cloning all repos in $org."

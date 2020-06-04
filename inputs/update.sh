#!/usr/bin/env bash
# A simple replacement for 'niv', until it adds "datetime of commit" to the
# generated JSON file.

set -euo pipefail

### options

# array of "name url ref" tuples
sources=(
    "nixpkgs https://github.com/nixos/nixpkgs refs/heads/nixos-20.03"
)

### implementation

compare_and_rename()
{
    local f=$1
    if cmp --quiet "$f.tmp" "$f"; then
        echo "### $f didn't change"
        rm "$f.tmp"
    else
        mv "$f.tmp" "$f"
        echo "### $f was updated"
    fi
}

# Because nix-prefetch-git doesn't output branch/ref info, and adding it isn't
# trivial (due to its interface).
insert_ref()
{
    local f=$1
    local ref=$2
    # to make sed insert leading whitespace, escape with '\'
    sed -e "3i\ \ \"ref\": \"$ref\"," -i "$f"
}

update_source()
{
    local arr
    read -r -a arr <<< "$1"
    local name=${arr[0]}
    local url=${arr[1]}
    local ref=${arr[2]}
    echo "### Updating $name..."
    local json="$selfdir/$name.json"
    nix-prefetch-git "$url" --rev "$ref" >"$json.tmp"
    insert_ref "$json.tmp" "$ref"
    compare_and_rename "$json"
}

cleanup()
{
    rm -f "$selfdir"/*.json.tmp
}

main()
{
    selfdir=$(readlink -f "$(dirname "$0")")
    trap "echo error: something went wrong >&2; cleanup" EXIT
    trap "echo Got signalled, exiting...; cleanup; trap - EXIT" INT TERM
    for s in "${sources[@]}"; do
        update_source "$s"
    done
    trap - EXIT
}

main "$@"

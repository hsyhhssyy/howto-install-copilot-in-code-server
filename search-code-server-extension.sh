#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  search-code-server-extension.sh [--limit N] <query>

Examples:
  search-code-server-extension.sh python
  search-code-server-extension.sh --limit 15 git graph

Notes:
  - Searches the Visual Studio Code Marketplace.
  - Prints extension IDs in publisher.extension format.
EOF
}

check_dependencies() {
    local missing_deps=()

    for cmd in curl jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    if [ "${#missing_deps[@]}" -gt 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

parse_args() {
    LIMIT=10
    QUERY_PARTS=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -n|--limit)
                shift
                if [ "$#" -eq 0 ]; then
                    echo "Error: --limit requires a value"
                    usage
                    exit 1
                fi
                LIMIT="$1"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                while [ "$#" -gt 0 ]; do
                    QUERY_PARTS+=("$1")
                    shift
                done
                break
                ;;
            -*)
                echo "Error: Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                QUERY_PARTS+=("$1")
                ;;
        esac
        shift
    done

    if ! echo "$LIMIT" | grep -Eq '^[0-9]+$'; then
        echo "Error: --limit must be a positive integer"
        exit 1
    fi

    if [ "$LIMIT" -le 0 ]; then
        echo "Error: --limit must be greater than 0"
        exit 1
    fi

    QUERY="${QUERY_PARTS[*]:-}"
    if [ -z "$QUERY" ]; then
        echo "Error: query is required"
        usage
        exit 1
    fi
}

search_extensions() {
    local query_json
    query_json=$(printf '%s' "$QUERY" | jq -Rs .)

    curl -fsSL --max-time 30 "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json;api-version=3.0-preview.1" \
        -d "{
            \"filters\": [{
                \"criteria\": [
                    {\"filterType\": 8, \"value\": \"Microsoft.VisualStudio.Code\"},
                    {\"filterType\": 10, \"value\": $query_json},
                    {\"filterType\": 12, \"value\": \"4096\"}
                ],
                \"pageNumber\": 1,
                \"pageSize\": $LIMIT,
                \"sortBy\": 0,
                \"sortOrder\": 0
            }],
            \"flags\": 914
        }"
}

print_results() {
    jq -r '
        .results[0].extensions[]? |
        [
            (.publisher.publisherName + "." + .extensionName),
            .displayName,
            (.shortDescription // "")
        ] | @tsv
    '
}

check_dependencies
parse_args "$@"

echo "Search query: $QUERY"
echo ""
printf '%s\n' "ID	Display Name	Description"

RESULTS="$(search_extensions)"

if [ "$(echo "$RESULTS" | jq '.results[0].extensions | length')" -eq 0 ]; then
    echo "No extensions found"
    exit 0
fi

echo "$RESULTS" | print_results
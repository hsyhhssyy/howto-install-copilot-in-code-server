#!/usr/bin/env bash

# Extract VS Code version from code-server
get_vscode_version() {
    # code-server --version may output either:
    # 1) head line is the version
    # 2) multiple sections including "with Code 1.a.b" such as "4.109.2 9184b645cc7aa41b750e2f2ef956f2896512dd84 with Code 1.109.2"
    local raw
    raw="$(code-server --version)"

    # New format: "... with Code X.Y.Z"
    local code_ver
    code_ver="$(echo "$raw" | tr '\n' ' ' | sed -nE 's/.*with Code ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')"
    if [ -n "$code_ver" ]; then
        echo "$code_ver"
        return 0
    fi

    # Old format: first line is the VS Code version
    echo "$raw" | head -n1 | awk '{print $1}'
}

# Get user-data-dir from running code-server process
get_user_data_dir() {
    # Use ps with POSIX-compliant options
    local process_info
    if command -v ps >/dev/null 2>&1; then
        # Try BSD-style first (macOS), fallback to POSIX
        process_info=$(ps aux 2>/dev/null | grep -v grep | grep "code-server" | head -n 1) ||
        process_info=$(ps -ef 2>/dev/null | grep -v grep | grep "code-server" | head -n 1)
    fi

    if [ -n "$process_info" ]; then
        echo "$process_info" | grep -o -- '--user-data-dir=[^ ]*' | sed 's/--user-data-dir=//'
    fi
}

normalize_semver() {
    echo "$1" | sed -E 's/^[^0-9]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/'
}

version_lte() {
    local left
    local right
    local left_major left_minor left_patch
    local right_major right_minor right_patch

    left="$(normalize_semver "$1")"
    right="$(normalize_semver "$2")"

    IFS=. read -r left_major left_minor left_patch <<EOF
$left
EOF
    IFS=. read -r right_major right_minor right_patch <<EOF
$right
EOF

    left_major=${left_major:-0}
    left_minor=${left_minor:-0}
    left_patch=${left_patch:-0}
    right_major=${right_major:-0}
    right_minor=${right_minor:-0}
    right_patch=${right_patch:-0}

    if [ "$left_major" -lt "$right_major" ]; then
        return 0
    fi
    if [ "$left_major" -gt "$right_major" ]; then
        return 1
    fi
    if [ "$left_minor" -lt "$right_minor" ]; then
        return 0
    fi
    if [ "$left_minor" -gt "$right_minor" ]; then
        return 1
    fi
    if [ "$left_patch" -le "$right_patch" ]; then
        return 0
    fi

    return 1
}

extract_vsix_engine() {
    local vsix_path="$1"

    unzip -p "$vsix_path" extension/package.json 2>/dev/null | jq -r '.engines.vscode // .engines.code // empty'
}

is_marketplace_prerelease() {
    local prerelease_flag="$1"

    case "${prerelease_flag:-}" in
        true|1|yes)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_vsix_prerelease() {
    local vsix_path="$1"
    local manifest_prerelease
    local package_preview

    manifest_prerelease="$({
        unzip -p "$vsix_path" extension.vsixmanifest 2>/dev/null || true
    } | grep -o 'Microsoft.VisualStudio.Code.PreRelease" Value="[^"]*' | sed 's/.*Value="//' | head -n1)"

    if [ "$manifest_prerelease" = "true" ]; then
        return 0
    fi

    package_preview="$(unzip -p "$vsix_path" extension/package.json 2>/dev/null | jq -r '.preview // false')"
    if [ "$package_preview" = "true" ]; then
        return 0
    fi

    return 1
}

is_engine_compatible() {
    local engine_requirement="$1"
    local vscode_version="$2"
    local minimum_version

    minimum_version="$(normalize_semver "$engine_requirement")"
    [ -n "$minimum_version" ] || return 0

    version_lte "$minimum_version" "$vscode_version"
}

# List candidate extension versions.
# Marketplace metadata is reliable enough to pre-filter known pre-release builds
# and VS Code engine requirements before downloading VSIX packages.
# We still keep VSIX inspection as a safety net during installation.
list_candidate_versions() {
    local extension_id="$1"

    local response
    response=$(curl -s -X POST "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json;api-version=3.0-preview.1" \
        -d "{
            \"filters\": [{
                \"criteria\": [
                    {\"filterType\": 7, \"value\": \"$extension_id\"},
                    {\"filterType\": 12, \"value\": \"4096\"}
                ],
                \"pageSize\": 50
            }],
            \"flags\": 119
        }")

    echo "$response" | jq -r '
        .results[0].extensions[0].versions[]?
        | [
            (.version // empty),
            (
                any(
                    (.properties // [])[]?;
                    (.key // "") == "Microsoft.VisualStudio.Code.PreRelease"
                    and ((.value // "") | ascii_downcase) == "true"
                )
                | if . then "true" else "false" end
            ),
            (
                first(
                    (.properties // [])[]?
                    | select((.key // "") == "Microsoft.VisualStudio.Code.Engine")
                    | (.value // "")
                ) // ""
            )
        ]
        | @tsv
    ' | awk -F '\t' 'NF && !seen[$1]++ { print $1 "\t" $2 "\t" $3 }'
}

# Install extension
install_extension() {
    local extension_id="$1"
    local version="$2"
    local user_data_dir="$3"
    local extension_name
    extension_name=$(echo "$extension_id" | cut -d'.' -f2)
    local temp_dir="/tmp/code-extensions"
    local version_safe
    local archive_path
    local vsix_path
    local engine_requirement

    version_safe=$(echo "$version" | tr -c 'A-Za-z0-9._-' '_')
    archive_path="$temp_dir/$extension_name-$version_safe.vsix.gz"
    vsix_path="$temp_dir/$extension_name-$version_safe.vsix"

    echo "Installing $extension_id v$version..."

    # Create temp directory
    mkdir -p "$temp_dir"

    # Download
    echo "  Downloading..."
    # Use curl with portable options (--progress-bar not available everywhere)
    if ! curl -fLsS "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/$extension_name/$version/vspackage" \
        -o "$archive_path"; then
        echo "  ✗ Download failed for $extension_id v$version"
        rm -f "$archive_path" "$vsix_path"
        return 1
    fi

    if [ ! -s "$archive_path" ]; then
        echo "  ✗ Download failed for $extension_id"
        rm -f "$archive_path" "$vsix_path"
        return 1
    fi

    # Decompress (handle both gunzip and gzip -d)
    if command -v gunzip >/dev/null 2>&1; then
        if ! gunzip -f "$archive_path"; then
            echo "  ✗ Failed to unpack $extension_id v$version"
            rm -f "$archive_path" "$vsix_path"
            return 1
        fi
    else
        if ! gzip -df "$archive_path"; then
            echo "  ✗ Failed to unpack $extension_id v$version"
            rm -f "$archive_path" "$vsix_path"
            return 1
        fi
    fi

    if is_vsix_prerelease "$vsix_path"; then
        echo "  - Skipping $extension_id v$version: pre-release extension"
        rm -f "$vsix_path"
        return 1
    fi

    engine_requirement="$(extract_vsix_engine "$vsix_path")"
    if [ -n "$engine_requirement" ] && ! is_engine_compatible "$engine_requirement" "$VSCODE_VERSION"; then
        echo "  - Skipping $extension_id v$version: requires VS Code $engine_requirement"
        rm -f "$vsix_path"
        return 1
    fi

    # Install with user-data-dir if provided
    if [ -n "$user_data_dir" ]; then
        if ! code-server --user-data-dir="$user_data_dir" --force --install-extension "$vsix_path"; then
            echo "  ✗ code-server rejected $extension_id v$version"
            rm -f "$vsix_path"
            return 1
        fi
    else
        if ! code-server --force --install-extension "$vsix_path"; then
            echo "  ✗ code-server rejected $extension_id v$version"
            rm -f "$vsix_path"
            return 1
        fi
    fi

    # Clean up
    rm -f "$vsix_path"

    echo "  ✓ $extension_id installed successfully!"
    return 0
}

install_latest_compatible_extension() {
    local extension_id="$1"
    local user_data_dir="$2"
    local tried=0
    local version
    local prerelease_flag
    local marketplace_engine

    while IFS=$'\t' read -r version prerelease_flag marketplace_engine; do
        [ -n "$version" ] || continue

        if is_marketplace_prerelease "$prerelease_flag"; then
            echo "  - Skipping $extension_id v$version: marketplace marks it as pre-release"
            continue
        fi

        if [ -n "$marketplace_engine" ] && ! is_engine_compatible "$marketplace_engine" "$VSCODE_VERSION"; then
            echo "  - Skipping $extension_id v$version: marketplace requires VS Code $marketplace_engine"
            continue
        fi

        tried=$((tried + 1))
        echo "  Trying version: $version"
        if install_extension "$extension_id" "$version" "$user_data_dir"; then
            return 0
        fi
    done <<EOF
$(list_candidate_versions "$extension_id")
EOF

    if [ "$tried" -eq 0 ]; then
        echo "  ✗ No versions returned by Marketplace for $extension_id"
    else
        echo "  ✗ No installable version found for $extension_id after trying $tried version(s)"
    fi

    return 1
}

# Check for required dependencies
check_dependencies() {
    local missing_deps=()

    # Check for required commands
    for cmd in curl jq code-server; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    # Check for either gunzip or gzip
    if ! command -v gunzip >/dev/null 2>&1 && ! command -v gzip >/dev/null 2>&1; then
        missing_deps+=("gunzip/gzip")
    fi

    if [ "${#missing_deps[@]}" -gt 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}"
        echo "Please install the missing dependencies and try again."
        exit 1
    fi
}

# Main script
echo "GitHub Copilot Extensions Installer"
echo "===================================="
echo ""

# Check dependencies
check_dependencies

# Get VS Code version
VSCODE_VERSION="$(get_vscode_version)"

if [ -z "$VSCODE_VERSION" ]; then
    echo "Error: Could not extract VS Code version from code-server"
    exit 1
fi

echo "Detected VS Code version: $VSCODE_VERSION"

# Check for user-data-dir in running code-server
USER_DATA_DIR="$(get_user_data_dir)"
if [ -n "$USER_DATA_DIR" ]; then
    echo "Detected user-data-dir: $USER_DATA_DIR"
fi
echo ""

# Extensions to install
# Use portable array declaration
EXTENSIONS="GitHub.copilot GitHub.copilot-chat"
FAILED=0

# Iterate through space-separated list for portability
for ext in $EXTENSIONS; do
    echo "Processing $ext..."

        if ! install_latest_compatible_extension "$ext" "$USER_DATA_DIR"; then
            FAILED="$((FAILED + 1))"
        fi
    echo ""
done

# Summary
echo "===================================="
if [ $FAILED -eq 0 ]; then
    echo "✓ All extensions installed successfully!"
    # Clean up temp directory on success
    rm -rf /tmp/code-extensions
else
    echo "⚠ Completed with $FAILED error(s)"
    exit 1
fi

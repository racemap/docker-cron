#!/usr/bin/env bash
set -euo pipefail

# Semantic version bump script for docker-cron project

# Get script directory to find VERSION file relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/VERSION"
CURRENT_VERSION=""

usage() {
    echo "Usage: $0 [major|minor|patch|set VERSION|show]"
    echo ""
    echo "Commands:"
    echo "  major    Bump major version (X.y.z -> (X+1).0.0)"
    echo "  minor    Bump minor version (x.Y.z -> x.(Y+1).0)"
    echo "  patch    Bump patch version (x.y.Z -> x.y.(Z+1))"
    echo "  set      Set specific version (e.g., ./version.sh set 2.1.0)"
    echo "  show     Show current version"
    echo ""
    echo "Current version: $(cat "$VERSION_FILE" 2>/dev/null || echo "not found")"
    exit 1
}

validate_semver() {
    local version="$1"
    if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid semantic version format. Expected: X.Y.Z (e.g., 1.0.0)"
        exit 1
    fi
}

get_current_version() {
    if [[ ! -f "$VERSION_FILE" ]]; then
        echo "Error: $VERSION_FILE not found"
        exit 1
    fi
    CURRENT_VERSION=$(cat "$VERSION_FILE")
    validate_semver "$CURRENT_VERSION"
}

bump_version() {
    local bump_type="$1"
    get_current_version
    
    # Parse version components
    IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
    
    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo "Error: Invalid bump type: $bump_type"
            usage
            ;;
    esac
    
    echo "${major}.${minor}.${patch}"
}

set_version() {
    local new_version="$1"
    validate_semver "$new_version"
    echo "$new_version" > "$VERSION_FILE"
    echo "Version set to: $new_version"
}

update_version() {
    local bump_type="$1"
    local new_version
    new_version=$(bump_version "$bump_type")
    
    echo "Bumping version from $CURRENT_VERSION to $new_version"
    echo "$new_version" > "$VERSION_FILE"
    echo "Version updated to: $new_version"
}

main() {
    if [[ $# -eq 0 ]]; then
        usage
    fi
    
    case "$1" in
        major|minor|patch)
            update_version "$1"
            ;;
        set)
            if [[ $# -ne 2 ]]; then
                echo "Error: 'set' command requires a version argument"
                usage
            fi
            set_version "$2"
            ;;
        show)
            get_current_version
            echo "$CURRENT_VERSION"
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            echo "Error: Unknown command: $1"
            usage
            ;;
    esac
}

main "$@"

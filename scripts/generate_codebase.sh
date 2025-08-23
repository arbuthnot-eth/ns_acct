#!/bin/bash

# scripts/generate_codebase.sh
# Generates codebase.md with file structure and contents in Markdown format, excluding specified paths

set -e

# Configuration
OUTPUT_FILE="${OUTPUT_FILE:-codebase.md}"
EXCLUDE_PATHS=(
    '*/.git/*'
    '*/node_modules/*'
    '*/build/*'
    '*/locks/*'
)
EXCLUDE_FILES=(
    'codebase.txt'
    'codebase.md'
    'package-lock.json'
)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper Functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Determine language for Markdown code fence based on file extension
get_language() {
    local file="$1"
    case "${file##*.}" in
        sh) echo "bash" ;;
        move) echo "move" ;;
        ts) echo "typescript" ;;
        json) echo "json" ;;
        md) echo "markdown" ;;
        toml) echo "toml" ;;
        *) echo "" ;; # No language identifier for unknown extensions
    esac
}

# Check if file should be excluded
is_excluded_file() {
    local file="$1"
    local base_file
    base_file=$(basename "$file")
    for excluded in "${EXCLUDE_FILES[@]}"; do
        if [ "$base_file" = "$excluded" ]; then
            return 0 # Excluded
        fi
    done
    return 1 # Not excluded
}

# Generate codebase.md
generate_codebase() {
    local output_file="$1"
    
    # Create temporary file
    local temp_file
    temp_file=$(mktemp)
    
    # Write Markdown header
    {
        echo "# NS Account Registry Codebase"
        echo ""
        echo "Generated documentation of the NS Account Registry project, including file structure and contents."
        echo "Generated on: $(date -Iseconds)"
        echo ""
        echo "## File Structure"
        echo ""
        echo '```'
        echo "."
        
        FIND_PRUNE_ARGS=()
        for p in "${EXCLUDE_PATHS[@]}"; do
            FIND_PRUNE_ARGS+=(-path "$p" -prune -o)
        done
        # Remove the last -o
        if [ ${#FIND_PRUNE_ARGS[@]} -gt 0 ]; then
            unset 'FIND_PRUNE_ARGS[${#FIND_PRUNE_ARGS[@]}-1]'
        fi

        find . \( "${FIND_PRUNE_ARGS[@]}" \) -o -print | sort | awk -F'/' '{ if ($0 != ".") { indent = ""; for (i=2; i<NF; i++) indent = indent " "; printf "%s|-- %s\n", indent, $NF } }'
        echo '```'
        echo ""
        echo "## Codebase Contents"
        echo ""
    } > "$temp_file"
    
    # Append file contents with Markdown code fences
    while IFS= read -r file; do
        if ! is_excluded_file "$file"; then
            local lang
            lang=$(get_language "$file")
            {
                echo "### File: $file"
                echo ""
                echo '```'"$lang"
                cat "$file"
                echo '```'
                echo ""
            } >> "$temp_file"
        fi
    done < <(find . \( "${FIND_PRUNE_ARGS[@]}" \) -o -type f -not -name "$(basename "$output_file")" -not -name "package-lock.json" -print)
    
    # Move temp file to final output
    mv "$temp_file" "$output_file"
    
    print_success "Generated $output_file successfully"
}

# Main Execution
if [ ! -d "scripts" ]; then
    print_error "Script must be run from the project root directory"
    exit 1
fi

# Check dependencies
if ! command -v find &> /dev/null || ! command -v awk &> /dev/null; then
    print_error "Required commands (find, awk) not found"
    exit 1
fi

# Allow output file override via command-line argument
if [ $# -gt 0 ]; then
    OUTPUT_FILE="$1"
fi

generate_codebase "$OUTPUT_FILE"

print_success "Done! Check $OUTPUT_FILE for results"

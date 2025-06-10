#!/bin/bash

# LFG MatchMaker Continued Addon Packaging Script
# Creates a distribution zip file for the World of Warcraft addon

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

echo -e "${YELLOW}LFG MatchMaker Continued Addon Packaging Script${NC}"
echo "================================================="

# Change to project root
cd "$PROJECT_ROOT"

# Validate required files exist
REQUIRED_FILES=("LFG_MatchMaker_Continued.toc" "LFGMM_Core.lua" "LFGMM_Variables.lua")
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: Required file '$file' not found${NC}"
        exit 1
    fi
done

# Extract version from TOC file
VERSION=$(grep "^## Version:" LFG_MatchMaker_Continued.toc | cut -d: -f2 | xargs)
if [[ -z "$VERSION" ]]; then
    echo -e "${RED}Error: Could not extract version from LFG_MatchMaker_Continued.toc${NC}"
    exit 1
fi

echo "Version: $VERSION"

# Create dist directory if it doesn't exist
mkdir -p dist

# Define output filename and temp directory
OUTPUT_FILE="dist/LFG_MatchMaker_Continued-$VERSION.zip"
TEMP_DIR="dist/temp_LFG_MatchMaker_Continued"

# Remove existing package and temp directory if they exist
if [[ -f "$OUTPUT_FILE" ]]; then
    echo "Removing existing package: $OUTPUT_FILE"
    rm "$OUTPUT_FILE"
fi

if [[ -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
fi

# Create the temp addon directory structure
mkdir -p "$TEMP_DIR/LFG_MatchMaker_Continued"

# Copy all addon files to the proper directory
echo "Copying addon files..."
cp -r *.lua *.xml *.toc LICENSE Libs/ "$TEMP_DIR/LFG_MatchMaker_Continued/"

# Create the zip package with proper directory structure
echo "Creating package..."
cd "$TEMP_DIR"
zip -r "../$(basename "$OUTPUT_FILE")" LFG_MatchMaker_Continued/ \
    -x "*.DS_Store" \
       "*.git*" \
       "*.vscode/*"

# Go back to project root
cd "$PROJECT_ROOT"

# Clean up the temporary directory
rm -rf "$TEMP_DIR"

# Verify the package was created
if [[ -f "$OUTPUT_FILE" ]]; then
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo -e "${GREEN}✓ Package created successfully: $OUTPUT_FILE ($FILE_SIZE)${NC}"
    
    # Show contents
    echo ""
    echo "Package contents:"
    unzip -l "$OUTPUT_FILE" | head -20
else
    echo -e "${RED}Error: Package creation failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Packaging complete!${NC}"
echo "The zip file will extract to: LFG_MatchMaker_Continued/"
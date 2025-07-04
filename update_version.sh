#!/bin/bash

# Update Version Script for LFG MatchMaker Continued
# Usage: ./update_version.sh 1.2.4

if [ $# -eq 0 ]; then
    CURRENT_VERSION=$(grep '^## Version:' LFG_MatchMaker_Continued.toc | sed 's/## Version: //')
    echo "Current version: $CURRENT_VERSION"
    # Find latest version tag
    LATEST_TAG=$(git tag --list 'v*' --sort=-v:refname | head -n 1)
    if [ -n "$LATEST_TAG" ]; then
        echo "Latest tag: $LATEST_TAG"
        echo "\nCommits after $LATEST_TAG:"
        git log --oneline $LATEST_TAG..HEAD
    else
        echo "No tags found."
    fi
    exit 0
fi

NEW_VERSION=$1

# Validate version format (x.y.z)
if ! [[ $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format x.y.z (e.g., 1.2.4)"
    exit 1
fi

echo "Updating to version $NEW_VERSION..."

# Update .toc file
sed -i '' "s/## Version: .*/## Version: $NEW_VERSION/" LFG_MatchMaker_Continued.toc

# Update centralized version in Variables.lua  
sed -i '' "s/LFGMM_ADDON_VERSION = \".*\"/LFGMM_ADDON_VERSION = \"$NEW_VERSION\"/" LFGMM_Variables.lua

echo "Version updated to $NEW_VERSION in:"
echo "- LFG_MatchMaker_Continued.toc"
echo "- LFGMM_Variables.lua (centralized version)"
echo ""
echo "The startup message will automatically use the new version."

git add LFG_MatchMaker_Continued.toc LFGMM_Variables.lua

git commit -m "Bump version to $NEW_VERSION"

git tag -a v$NEW_VERSION -m "Version $NEW_VERSION"

git push

git push origin v$NEW_VERSION
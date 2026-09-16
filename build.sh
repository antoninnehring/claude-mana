#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building ClaudeMana..."
swift build -c release 2>&1

APP="ClaudeMana.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/release/ClaudeMana "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"

echo ""
echo "Built $APP"
echo "Run:  open $APP"
echo ""
echo "To configure, create ~/.config/claude-mana/config.json"
echo "(see config.example.json for format)"

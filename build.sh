#!/bin/sh
set -eu
cd "$(dirname "$0")"
xcodebuild -project SonosKeys.xcodeproj -scheme SonosKeys -configuration Release -derivedDataPath build/DerivedData build
ditto "build/DerivedData/Build/Products/Release/Sonos Keys.app" "build/Sonos Keys.app"

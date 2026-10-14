#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodebuild -project GlowRim.xcodeproj -scheme GlowRim -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build
print "App: $PWD/build/Build/Products/Release/GlowRim.app"

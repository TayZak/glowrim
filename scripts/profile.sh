#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
profile_dir=$(mktemp -d /tmp/glowrim-profile.XXXXXX)
trap 'rm -rf "$profile_dir"' EXIT
swiftc -O GlowRim/Models/{LightSettings,LightMode,ColorPreset,BreathingAnimation,RenderBudget}.swift GlowRim/Overlay/{HDRRingLayer,RingLightView,RingLightWindow,ScreenGlowOverlay}.swift GlowRim/Services/BatteryMonitor.swift GlowRim/Utilities/Constants.swift Tests/performance/main.swift -o "$profile_dir/glowrim-profile"
"$profile_dir/glowrim-profile" "$@"

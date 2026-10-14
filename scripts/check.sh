#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
check_dir=$(mktemp -d /tmp/glowrim-checks.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
swiftc GlowRim/Models/{LightSettings,LightMode,ColorPreset,BreathingAnimation,RenderBudget}.swift GlowRim/Overlay/{HDRRingLayer,RingLightView,RingLightWindow,ScreenGlowOverlay}.swift GlowRim/AppDelegate.swift GlowRim/Views/ControlPanelView.swift GlowRim/Utilities/{Extensions,Constants}.swift GlowRim/Services/{BatteryMonitor,HotKeyManager}.swift Tests/RimRenderingChecks.swift Tests/main.swift -o "$check_dir/glowrim-checks"
"$check_dir/glowrim-checks"

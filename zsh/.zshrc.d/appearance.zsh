# Export env vars driven by current macOS appearance.
# Re-evaluated on every shell startup; existing shells stay on the value they
# had when they were launched. Open a new shell after toggling appearance.

if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -q Dark; then
    export K9S_SKIN=catppuccin-mocha
else
    export K9S_SKIN=catppuccin-latte
fi

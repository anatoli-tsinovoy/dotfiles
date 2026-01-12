#!/usr/bin/env bash
#
# macOS defaults configuration
# Run with: ./macos-defaults.sh
#
# Based on actual preferences extracted from the system.
# Only includes persistent settings, not ephemeral state.
#
set -euo pipefail

# Close System Preferences to prevent conflicts
osascript -e 'tell application "System Preferences" to quit' 2>/dev/null || true
osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true

echo "Configuring macOS defaults..."

###############################################################################
# Keyboard & Input                                                            #
###############################################################################

# Disable press-and-hold for accents, enable key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Fast key repeat rate (lower = faster)
defaults write NSGlobalDomain KeyRepeat -int 2

# Short delay before key repeat starts (lower = shorter)
defaults write NSGlobalDomain InitialKeyRepeat -int 35

# Full keyboard access for all controls (Tab through all UI elements)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 1

# Use F1, F2, etc. as standard function keys
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true

# Disable all auto-correction nonsense
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain WebAutomaticSpellingCorrectionEnabled -bool false

###############################################################################
# Trackpad & Mouse                                                            #
###############################################################################

# Disable "natural" (reverse) scrolling
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# Disable force click
defaults write NSGlobalDomain com.apple.trackpad.forceClick -bool false

# Three-finger tap for look up
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture -int 2

# Disable multi-finger gestures (using Aerospace for window management)
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerPinchGesture -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadFiveFingerPinchGesture -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture -int 0

defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerPinchGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFiveFingerPinchGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture -int 0

###############################################################################
# UI & Windows                                                                #
###############################################################################

# Hide menu bar (using Sketchybar instead)
defaults write NSGlobalDomain _HIHideMenuBar -bool true
defaults write NSGlobalDomain AppleMenuBarVisibleInFullscreen -bool false

# Disable window animations (faster UI)
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false

# Enable dragging windows from anywhere with Cmd+Ctrl+click
defaults write NSGlobalDomain NSWindowShouldDragOnGesture -bool true

# Manual window tab management
defaults write NSGlobalDomain AppleWindowTabbingMode -string "manual"

# Double-click title bar to maximize (not minimize)
defaults write NSGlobalDomain AppleActionOnDoubleClick -string "Maximize"
defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool false

# Disable cursor shake-to-locate
defaults write NSGlobalDomain CGDisableCursorLocationMagnification -bool true

###############################################################################
# Dock                                                                        #
###############################################################################

# Auto-hide dock
defaults write com.apple.dock autohide -bool true

# Delay before dock shows (1 second)
defaults write com.apple.dock autohide-delay -float 1.0

# Dock on the left side
defaults write com.apple.dock orientation -string "left"

# Icon size
defaults write com.apple.dock tilesize -int 124
defaults write com.apple.dock largesize -int 128

# Disable magnification
defaults write com.apple.dock magnification -bool false

# Minimize windows into their application icon
defaults write com.apple.dock minimize-to-application -bool true

# Don't automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Don't show recent applications
defaults write com.apple.dock show-recents -bool false

# Group windows by application in Mission Control
defaults write com.apple.dock expose-group-apps -bool true

# Disable all dock gestures (using Aerospace)
defaults write com.apple.dock showAppExposeGestureEnabled -bool false
defaults write com.apple.dock showDesktopGestureEnabled -bool false
defaults write com.apple.dock showLaunchpadGestureEnabled -bool false
defaults write com.apple.dock showMissionControlGestureEnabled -bool false
defaults write com.apple.dock enterMissionControlByTopWindowDrag -bool false

# Hot corners
# Possible values:
#  0: no-op
#  2: Mission Control
#  3: Show application windows
#  4: Desktop
#  5: Start screen saver
#  6: Disable screen saver
#  7: Dashboard
# 10: Put display to sleep
# 11: Launchpad
# 12: Notification Center
# 13: Lock Screen
# 14: Quick Note

# Top-right: Mission Control
defaults write com.apple.dock wvous-tr-corner -int 2
defaults write com.apple.dock wvous-tr-modifier -int 0

# Other corners: disabled
defaults write com.apple.dock wvous-tl-corner -int 1
defaults write com.apple.dock wvous-tl-modifier -int 0
defaults write com.apple.dock wvous-bl-corner -int 1
defaults write com.apple.dock wvous-bl-modifier -int 0
defaults write com.apple.dock wvous-br-corner -int 1
defaults write com.apple.dock wvous-br-modifier -int 0

###############################################################################
# Window Manager (Stage Manager / Tiling)                                     #
###############################################################################

# Disable Stage Manager
defaults write com.apple.WindowManager GloballyEnabled -bool false

# Disable click-to-show-desktop
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

# Disable all native tiling (using Aerospace)
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false
defaults write com.apple.WindowManager EnableTilingByEdgeDrag -bool false
defaults write com.apple.WindowManager EnableTilingOptionAccelerator -bool false
defaults write com.apple.WindowManager EnableTopTilingByEdgeDrag -bool false

# Hide desktop icons when windows are open
defaults write com.apple.WindowManager HideDesktop -bool true

###############################################################################
# Finder                                                                      #
###############################################################################

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable warning when changing file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Show full POSIX path in Finder title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

###############################################################################
# Menu Bar Clock                                                              #
###############################################################################

# 24-hour clock
defaults write com.apple.menuextra.clock Show24Hour -bool true

# Hide date, show day of week
defaults write com.apple.menuextra.clock ShowDate -int 0
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true

# No flashing separators
defaults write com.apple.menuextra.clock FlashDateSeparators -bool false

# Digital clock
defaults write com.apple.menuextra.clock IsAnalog -bool false

###############################################################################
# Screenshots                                                                 #
###############################################################################

# Save screenshots to file (not clipboard)
defaults write com.apple.screencapture target -string "file"

###############################################################################
# Keyboard Shortcuts (Symbolic Hot Keys)                                      #
###############################################################################

# Disable Mission Control space switching shortcuts (Ctrl+1, Ctrl+2, etc.)
# These interfere with Aerospace and terminal shortcuts
# 118 = Ctrl+1, 119 = Ctrl+2, 120 = Ctrl+3
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 118 '{ enabled = 0; }'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 119 '{ enabled = 0; }'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 120 '{ enabled = 0; }'

# Disable Spotlight shortcuts (using Raycast/Alfred instead)
# 64 = Cmd+Space (Spotlight)
# 65 = Cmd+Option+Space (Finder search)
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 '{ enabled = 0; }'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 '{ enabled = 0; }'

###############################################################################
# Text Input                                                                  #
###############################################################################

# Show input menu in menu bar
defaults write com.apple.TextInputMenu visible -bool true

###############################################################################
# Accessibility                                                               #
###############################################################################

# Disable reduce motion
defaults write com.apple.universalaccess reduceMotion -bool false

# Disable reduce transparency
defaults write com.apple.universalaccess reduceTransparency -bool false

###############################################################################
# Kill affected applications                                                  #
###############################################################################

echo "Restarting affected applications..."

for app in "Dock" "Finder" "SystemUIServer" "cfprefsd"; do
  killall "${app}" 2>/dev/null || true
done

echo "Done. Some changes may require a logout/restart to take effect."

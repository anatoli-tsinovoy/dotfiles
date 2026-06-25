#!/usr/bin/env bash
set -euo pipefail

# Open in Neovim - Installation Script
# Builds the AppleScript app, configures Info.plist, and sets file associations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Open in Neovim"
APP_PATH="/Applications/${APP_NAME}.app"
BUNDLE_ID="com.local.open-in-neovim"

# Logging helpers
log_info() { echo "ℹ️  $*"; }
log_ok() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

# ------------------------------------------------------------------------------
# Step 1: Build the AppleScript application
# ------------------------------------------------------------------------------
build_app() {
    log_info "Building ${APP_NAME}.app..."
    
    # Replace the generated app in-place; backups in /Applications confuse Launch Services
    if [[ -d "$APP_PATH" ]]; then
        log_info "Replacing existing $APP_PATH"
        rm -rf "$APP_PATH"
    fi
    
    # Compile AppleScript to application bundle
    osacompile -o "$APP_PATH" "${SCRIPT_DIR}/open-in-neovim.applescript"
    
    log_ok "Built $APP_PATH"
}

# ------------------------------------------------------------------------------
# Step 2: Patch Info.plist with document type handlers
# ------------------------------------------------------------------------------
patch_plist() {
    log_info "Patching Info.plist with document handlers..."
    
    local plist_path="${APP_PATH}/Contents/Info.plist"
    
    # Set custom bundle identifier (not the generic ScriptEditor one)
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "$plist_path" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string ${BUNDLE_ID}" "$plist_path"
    
    # Remove existing CFBundleDocumentTypes if present
    /usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes" "$plist_path" 2>/dev/null || true
    
    # Add document types array
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array" "$plist_path"
    
    # Add document type for text and source code
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict" "$plist_path"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string 'Text and Source Code'" "$plist_path"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string 'Editor'" "$plist_path"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string 'Owner'" "$plist_path"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$plist_path"
    
    # Add UTIs for all text/source types
    local utis=(
        # Core text types
        "public.text"
        "public.plain-text"
        "public.source-code"
        "public.script"
        "public.shell-script"
        "public.bash-script"
        "public.zsh-script"
        # C family
        "public.c-source"
        "public.c-header"
        "public.c-plus-plus-source"
        "public.c-plus-plus-header"
        "public.objective-c-source"
        "public.objective-c-plus-plus-source"
        # Apple languages
        "public.swift-source"
        "com.apple.property-list"
        # Scripting languages
        "public.python-script"
        "public.ruby-script"
        "public.perl-script"
        "public.php-script"
        # Web/JS
        "com.netscape.javascript-source"
        "com.microsoft.typescript"
        # Data formats
        "public.json"
        "public.xml"
        "public.yaml"
        # Other
        "com.sun.java-source"
        "net.daringfireball.markdown"
        "com.apple.log"
    )
    
    local idx=0
    for uti in "${utis[@]}"; do
        /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:${idx} string '${uti}'" "$plist_path"
        idx=$((idx + 1))
    done
    
    log_ok "Patched Info.plist with ${idx} UTIs"
}

# ------------------------------------------------------------------------------
# Step 3: Handle security (quarantine + code signing)
# ------------------------------------------------------------------------------
handle_security() {
    log_info "Handling security attributes..."
    
    # Remove quarantine flag if present
    if xattr -l "$APP_PATH" 2>/dev/null | grep -q "com.apple.quarantine"; then
        log_info "Removing quarantine flag..."
        xattr -dr com.apple.quarantine "$APP_PATH"
        log_ok "Removed quarantine"
    else
        log_info "No quarantine flag present"
    fi
    
    # Ad-hoc code sign (required for Gatekeeper on modern macOS)
    log_info "Ad-hoc signing the app..."
    codesign --force --deep --sign - "$APP_PATH"
    log_ok "App signed"
}

# ------------------------------------------------------------------------------
# Step 4: Register with Launch Services
# ------------------------------------------------------------------------------
register_app() {
    log_info "Registering with Launch Services..."
    
    # Force Launch Services to re-read the app
    /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_PATH"
    
    log_ok "Registered with Launch Services"
}

# ------------------------------------------------------------------------------
# Step 5: Set file associations with duti
# ------------------------------------------------------------------------------
set_associations() {
    log_info "Setting file associations with duti..."
    
    if ! command -v duti &>/dev/null; then
        log_error "duti not installed. Run: brew install duti"
        return 1
    fi
    
    # UTI associations (cover broad categories)
    local utis=(
        "public.text"
        "public.plain-text"
        "public.source-code"
        "public.script"
        "public.shell-script"
        "public.bash-script"
        "public.zsh-script"
        "public.c-source"
        "public.c-header"
        "public.c-plus-plus-source"
        "public.c-plus-plus-header"
        "public.objective-c-source"
        "public.objective-c-plus-plus-source"
        "public.swift-source"
        "public.python-script"
        "public.ruby-script"
        "public.perl-script"
        "public.php-script"
        "com.netscape.javascript-source"
        "com.microsoft.typescript"
        "public.json"
        "public.xml"
        "public.yaml"
        "com.sun.java-source"
        "net.daringfireball.markdown"
        "com.apple.property-list"
        "com.apple.log"
    )
    
    for uti in "${utis[@]}"; do
        duti -s "$BUNDLE_ID" "$uti" all 2>/dev/null || log_warn "Failed to set UTI: $uti"
    done
    log_ok "Set UTI associations"
    
    # Extension associations (for types without proper UTIs or dynamic UTIs)
    # These cover languages/files that macOS doesn't have built-in UTIs for
    local extensions=(
        # TypeScript/JavaScript variants
        ".ts"       # Note: macOS thinks this is MPEG-2 transport stream!
        ".tsx"
        ".jsx"
        ".mjs"
        ".cjs"
        # Systems languages
        ".go"
        ".rs"
        ".zig"
        # JVM languages  
        ".kt"
        ".kts"
        ".scala"
        ".groovy"
        ".gradle"
        # Scripting
        ".lua"
        ".vim"
        ".el"       # Emacs Lisp
        # Config files
        ".toml"
        ".json"
        ".jsonc"
        ".yaml"
        ".yml"
        ".ini"
        ".cfg"
        ".conf"
        ".env"
        ".env.local"
        ".env.development"
        ".env.production"
        # Web
        ".css"
        ".scss"
        ".sass"
        ".less"
        ".vue"
        ".svelte"
        ".astro"
        # Shell
        ".sh"
        ".bash"
        ".zsh"
        ".fish"
        # Data/Query
        ".sql"
        ".graphql"
        ".gql"
        # Documentation
        ".md"
        ".markdown"
        ".mdx"
        ".rst"
        ".txt"
        ".log"
        # DevOps/Infra
        ".dockerfile"
        ".containerfile"
        ".tf"       # Terraform
        ".hcl"      # HashiCorp
        ".nix"
        # Build/Project files
        ".makefile"
        ".cmake"
        ".bazel"
        ".BUILD"
        # Git/Editor configs
        ".gitignore"
        ".gitattributes"
        ".gitmodules"
        ".editorconfig"
        ".prettierrc"
        ".eslintrc"
        ".stylelintrc"
        ".babelrc"
        # C/C++ related
        ".c"
        ".h"
        ".cpp"
        ".cc"
        ".cxx"
        ".hpp"
        ".hxx"
        ".m"
        ".mm"
        # Other languages
        ".swift"
        ".java"
        ".rb"
        ".py"
        ".pl"
        ".pm"
        ".php"
        ".r"
        ".R"
        ".jl"       # Julia
        ".ex"       # Elixir
        ".exs"
        ".erl"      # Erlang
        ".hrl"
        ".hs"       # Haskell
        ".clj"      # Clojure
        ".cljs"
        ".lisp"
        ".scm"      # Scheme
        ".ml"       # OCaml
        ".mli"
        ".fs"       # F#
        ".fsx"
        ".d"        # D
        ".dart"
        ".cr"       # Crystal
        ".nim"
        ".v"        # V / Coq
        ".asm"
        ".s"
        ".S"
    )
    
    for ext in "${extensions[@]}"; do
        duti -s "$BUNDLE_ID" "$ext" all 2>/dev/null || log_warn "Failed to set extension: $ext"
    done
    log_ok "Set extension associations"
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
main() {
    echo "========================================"
    echo "  Open in Neovim - Installer"
    echo "========================================"
    echo
    
    build_app
    patch_plist
    handle_security
    register_app
    set_associations
    
    echo
    log_ok "Installation complete!"
    echo
    echo "To verify, run:"
    echo "  duti -x .py"
    echo "  duti -x public.source-code"
    echo
    echo "You may need to log out and back in for all associations to take effect."
}

main "$@"

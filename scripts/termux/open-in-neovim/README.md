# Android file actions for Termux

This directory contains one bundled APK providing **Open in Neovim** and **Show location in Termux**, plus its manifest, Java source, and build script. These are Stow-ignored repository assets.

## Install on Termux

Run `./install.sh` from the repository root. It configures the Termux helper and opens Android's installer for the bundled APK. No SDK, JDK, SSH, or build machine is needed on the device. Approve storage access and installation when prompted, then tap **Open** to approve the shared Termux command permission for both actions.

Storage setup never rebuilds an existing `~/storage` tree. The installer preserves Termux settings in a regular properties file because native Termux ignores symlinked properties files, then reloads settings with Termux in the foreground.

## Rebuild the bundled APK

Requirements:

- Bash, a complete JDK (verified with JDK 21), and standard command-line utilities.
- Android SDK platform `android-35`.
- Android SDK build-tools containing `aapt2`, `d8`, `zipalign`, and `apksigner` (verified with `35.0.0`).

From the repository root:

```sh
JAVA_HOME=/path/to/jdk \
ANDROID_HOME=/path/to/android-sdk \
  scripts/termux/open-in-neovim/build.sh
```

The build signs and verifies the APK, then refreshes `scripts/termux/open-in-neovim/open-in-neovim.apk`. Include that APK with source changes. An output copy, signing keystore, and matching `.keystore.pass` file are kept under `${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/open-in-neovim/`.

Keep both signing files private and preserve them for upgrades. On another build machine, restore them to that cache directory before rebuilding. Never commit signing files. The public signing certificate is included in the APK; the private key is not.

## File access

Choose either action from **Open with** or **Share**:

- **Open in Neovim** opens accessible shared-storage originals without copying them into Downloads. Saving edits the original; quitting leaves a shell in its parent directory.
- **Show location in Termux** prints the resolved original path and opens an interactive shell in its parent directory. Neovim is not started or required.

Private/cloud providers that expose only an opaque content URI produce a diagnostic shell instead; no copy is imported.

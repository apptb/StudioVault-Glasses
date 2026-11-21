#!/bin/sh
# Xcode Cloud post-clone script for the glasses app.
#
# Install as samples/CameraAccess/ci_scripts/ci_post_clone.sh, mode 755.
# Xcode Cloud looks for ci_scripts beside the .xcodeproj, not at the repository root.
#
# The app compiles a Secrets.swift that is deliberately not committed. This script
# puts the committed example in its place and injects nothing: the build needs no
# secret, because the gateway address and the device token are entered on the app's
# pairing screen. It prints fixed strings only and never echoes a variable's value.
set -eu

REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../../.." && pwd)}"
APP_DIR="$REPO/samples/CameraAccess/CameraAccess"

if [ ! -d "$APP_DIR" ]; then
  # Some Xcode Cloud phases run scripts without the source tree.
  echo "ci_post_clone: source tree not present for this phase; nothing to do"
  exit 0
fi

if [ ! -f "$APP_DIR/Secrets.swift.example" ]; then
  echo "ci_post_clone: Secrets.swift.example is missing; cannot continue"
  exit 1
fi

# Refuse to ship a build that defaults to somebody else's server.
if grep -q "visionagents.app" "$APP_DIR/Secrets.swift.example"; then
  echo "ci_post_clone: Secrets.swift.example still names the upstream pilot gateway; clear it first"
  exit 1
fi

cp "$APP_DIR/Secrets.swift.example" "$APP_DIR/Secrets.swift"
echo "ci_post_clone: wrote Secrets.swift from the committed example (no secrets injected)"

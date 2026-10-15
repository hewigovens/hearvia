#!/bin/sh
# Release builds don't expose Documents in the Files app: the file-sharing keys only serve the Debug developer tools.
[ "${CONFIGURATION:-Debug}" = "Release" ] || exit 0
plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
for key in UIFileSharingEnabled LSSupportsOpeningDocumentsInPlace; do
  /usr/libexec/PlistBuddy -c "Delete :$key" "$plist" 2>/dev/null || true
done

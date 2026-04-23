# Build the app
swift build

# Define paths
APP_NAME="OpenWith.app"
EXECUTABLE_NAME="OpenWith"
BUILD_PATH=".build/debug/$EXECUTABLE_NAME"
CONTENTS_DIR="$APP_NAME/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Create bundle structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable and Info.plist
cp "$BUILD_PATH" "$MACOS_DIR/"
cp "OpenWith/Resources/Info.plist" "$CONTENTS_DIR/"

echo "Successfully bundled $APP_NAME."

# Quit the old app if it's running
echo "Stopping old version of OpenWith..."
osascript -e 'quit app "OpenWith"' 2>/dev/null || true
sleep 1

# Move to Applications
echo "Installing to /Applications..."
cp -R "$APP_NAME" /Applications/

# Register with Launch Services
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f /Applications/OpenWith.app

# Open the app
echo "Opening OpenWith.app..."
open /Applications/OpenWith.app

echo "Finished: OpenWith.app is now running from /Applications."

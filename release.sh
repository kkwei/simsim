#!/bin/sh

NEW_VERSION_STRING=$1

PLIST="./SimSim/Info.plist"

# Increment Build number and update version
PLB=/usr/libexec/PlistBuddy
LAST_NUMBER=$($PLB -c "Print CFBundleVersion" "$PLIST")
NEW_VERSION=$(($LAST_NUMBER + 1))
$PLB -c "Set :CFBundleVersion $NEW_VERSION" "$PLIST"
$PLB -c "Set :CFBundleShortVersionString $NEW_VERSION_STRING" $PLIST

# Build
# Helper first: SimSim copies SimSimHelper.app into LoginItems but doesn't build it.
# Clean up front, since cleaning SimSim also removes the helper's product.
rm -rf ./build
xcodebuild -target SimSimHelper build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
xcodebuild -target SimSim build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# DMG
./Release/dmg/build.sh 

# ZIP
cd ./build/Release/
zip -r ../../Release/SimSim_${NEW_VERSION_STRING}.zip ./SimSim.app
cd ../../

# Create latest ZIP
yes | cp ./Release/SimSim_${NEW_VERSION_STRING}.zip ./Release/SimSim_latest.zip

echo "Done"
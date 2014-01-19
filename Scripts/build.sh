#! /bin/ksh

#
#  build.sh
#  sequel-pro
#
#  Created by Stuart Connolly (stuconnolly.com).
#  Copyright (c) 2009 Stuart Connolly. All rights reserved.
#
#  Permission is hereby granted, free of charge, to any person
#  obtaining a copy of this software and associated documentation
#  files (the "Software"), to deal in the Software without
#  restriction, including without limitation the rights to use,
#  copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the
#  Software is furnished to do so, subject to the following
#  conditions:
#
#  The above copyright notice and this permission notice shall be
#  included in all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
#  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#  OTHER DEALINGS IN THE SOFTWARE.
#
#  More info at <http://code.google.com/p/sequel-pro/>

#  Generic Sequel Pro build script. This script is intended to replace entering lots of code
#  into Xcode's 'Run Scripts' build phase to make it easier to work with. As such this script
#  can only be run by Xcode.

if [ "${BUILT_PRODUCTS_DIR}x" == 'x' ]
then
	echo 'This script should only be run by Xcode. Exiting...'
	exit 1
fi

BUILD_PRODUCT="${BUILT_PRODUCTS_DIR}/${TARGET_NAME}${WRAPPER_SUFFIX}"
FRAMEWORKS_PATH="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"

dev_sign_resource()
{
	codesign -s 'Sequel Pro Development' "$1" 2> /dev/null
}

dist_sign_resource()
{
	codesign -s 'Developer ID Application: MJ Media' -r "${SRCROOT}/Resources/sprequirement.bin" "$1" 2> /dev/null
}

verify_signing()
{
	codesign --verify "$1" 2>&1
}

dev_code_sign()
{
	while read FRAMEWORK
	do
		dev_sign_resource "${FRAMEWORKS_PATH}/${FRAMEWORK}"
	done < "$1"

	dev_sign_resource "${BUILD_PRODUCT}/Contents/Resources/SequelProTunnelAssistant"
	dev_sign_resource "${BUILD_PRODUCT}"
}

dist_code_sign()
{
	ERRORS=''

	while read FRAMEWORK
	do
		dist_sign_resource "${FRAMEWORKS_PATH}/${FRAMEWORK}"

		ERRORS+=$(verify_signing "${FRAMEWORKS_PATH}/${FRAMEWORK}")
	done < "$1"

	dist_sign_resource "${BUILD_PRODUCT}/Contents/Resources/SequelProTunnelAssistant"
	dist_sign_resource "${BUILD_PRODUCT}"

	ERRORS+=$(verify_signing "${BUILD_PRODUCT}/Contents/Resources/SequelProTunnelAssistant")
	ERRORS+=$(verify_signing "${BUILD_PRODUCT}")

	echo $ERRORS
}

echo 'Updating build version...'

# Add the build/bundle version
"${SRCROOT}/Scripts/build-version.pl"

# Remove the .ibplugin from within frameworks
rm -rf "${BUILD_PRODUCT}/Contents/Frameworks/ShortcutRecorder.framework/Versions/A/Resources/ShortcutRecorder.ibplugin"

# Perform 'Release' or 'Distribution' build specific actions
if [[ "$CONFIGURATION" == 'Release' || "$CONFIGURATION" == 'Distribution' ]]
then
	"${SRCROOT}/Scripts/localize.sh"

	printf "Running trim-application.sh to strip application resources for distribution...\n\n"

	"${SRCROOT}/Scripts/trim-application.sh" -p "$BUILD_PRODUCT" -a
fi

SHARED_SUPPORT_DIR="${BUILD_PRODUCT}/Contents/SharedSupport"

# Copy all Default Bundles to build product
rm -rf "${SHARED_SUPPORT_DIR}/Default Bundles"

mkdir -p "${SHARED_SUPPORT_DIR}/Default Bundles"

cp -R "${SRCROOT}/SharedSupport/Default Bundles" "${SHARED_SUPPORT_DIR}"

# Copy all Default Themes to build product
rm -rf "${SHARED_SUPPORT_DIR}/Default Themes"

mkdir -p "${SHARED_SUPPORT_DIR}/Default Themes"

cp -R "${SRCROOT}/SharedSupport/Default Themes" "${SHARED_SUPPORT_DIR}"

# Add a SpotLight comment (can't use applescript from a continuous integration server, so we manually set the binaryplist with xattr)
# osascript -e "tell application \"Finder\" to set comment of (alias (POSIX file \"${BUILD_PRODUCT}\")) to \"MySQL database pancakes with syrup\""
xattr -wx com.apple.metadata:kMDItemFinderComment "62 70 6C 69 73 74 30 30 5F 10 22 4D 79 53 51 4C 20 64 61 74 61 62 61 73 65 20 70 61 6E 63 61 6B 65 73 20 77 69 74 68 20 73 79 72 75 70 08 00 00 00 00 00 00 01 01 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 2D" "${BUILD_PRODUCT}"

FRAMEWORKS="/tmp/sp.frameworks.$$"

ls "$FRAMEWORKS_PATH" > "$FRAMEWORKS"

# Perform distribution specific tasks if this is a 'Distribution' build
if [ "$CONFIGURATION" == 'Distribution' ]
then
	echo 'Checking for localizations to copy in, using the "ResourcesToCopy" directory...'

	if [ -e "${SRCROOT}/ResourcesToCopy" ]
	then
		find "${SRCROOT}/ResourcesToCopy" \( -name "*.lproj" \) | while read FILE; do; printf "\tCopying localization: ${FILE}\n"; cp -R "$FILE" "${BUILD_PRODUCT}/Contents/Resources/"; done;
	else
		echo 'No localizations to copy.'
	fi

	echo 'Performing distribution build code signing...'

	VERIFY_ERRORS=$(dist_code_sign "$FRAMEWORKS")
	
	if [ "$VERIFY_ERRORS" != '' ]
	then
		echo "error: Signing verification threw an error: $VERIFY_ERRORS"
		echo "error: All distribution builds must be signed with the key used for all previous distribution signing!"
		
		exit 1
	fi
	
	echo 'Running package-application.sh to package application for distribution...'

	"${SRCROOT}/Scripts/package-application.sh" -p "$BUILD_PRODUCT"
fi

# Development build code signing
if [ "$CONFIGURATION" == 'Debug' ]
then
	echo 'Performing development build code signing...'

	dev_code_sign "$FRAMEWORKS"

	# Run a fake command to silence errors
	touch "$BUILD_PRODUCT"
fi

rm "$FRAMEWORKS"

exit 0

#! /bin/ksh

#
#  $Id$
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

echo 'Updating build version...'

# Add the build/bundle version
"${SRCROOT}/Scripts/build-version.pl"

# Remove the .ibplugin from within frameworks
rm -rf "${BUILD_PRODUCT}/Contents/Frameworks/ShortcutRecorder.framework/Versions/A/Resources/ShortcutRecorder.ibplugin"

# Perform localisation updates for 'Release' or 'Distribution' builds
if [[ "$CONFIGURATION" == 'Release' || "$CONFIGURATION" == 'Distribution' ]]
then
	"${SRCROOT}/Scripts/localize.sh"
fi

# Trim the application if this is a 'Release' or 'Distribution' build
if [[ "$CONFIGURATION" == 'Release' || "$CONFIGURATION" == 'Distribution' ]]
then
	echo 'Running trim-application.sh to strip application resources for distribution...'

	"${SRCROOT}/Scripts/trim-application.sh" -p "$BUILD_PRODUCT" -a
fi

# Copy all Default Bundles to build product
rm -rf "${BUILD_PRODUCT}/Contents/SharedSupport/Default Bundles"

mkdir -p "${BUILD_PRODUCT}/Contents/SharedSupport/Default Bundles"

cp -R "${SRCROOT}/SharedSupport/Default Bundles" "${BUILD_PRODUCT}/Contents/SharedSupport"

# Copy all Default Themes to build product
rm -rf "${BUILD_PRODUCT}/Contents/SharedSupport/Default Themes"

mkdir -p "${BUILD_PRODUCT}/Contents/SharedSupport/Default Themes"

cp -R "${SRCROOT}/SharedSupport/Default Themes" "${BUILD_PRODUCT}/Contents/SharedSupport"


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

	codesign -s 'Developer ID Application: MJ Media' -r "${SRCROOT}/Resources/sprequirement.bin" "${BUILD_PRODUCT}/Contents/Resources/SequelProTunnelAssistant"
	codesign -s 'Developer ID Application: MJ Media' -r "${SRCROOT}/Resources/sprequirement.bin" "${BUILD_PRODUCT}"
	
	# Verify that code signing has worked - all distribution builds must be signed with the same key.
	VERIFYERRORS=`codesign --verify "$BUILD_PRODUCT" 2>&1`
	VERIFYERRORS+=`codesign --verify "${BUILD_PRODUCT}/Contents/Resources/SequelProTunnelAssistant" 2>&1`
	
	if [ "$VERIFYERRORS" != '' ]
	then
		echo "error: Signing verification threw an error: $VERIFYERRORS"
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

	codesign -s 'Sequel Pro Development' "${BUILD_PRODUCT}/Contents/Resources/SequelProTunnelAssistant" 2> /dev/null
	codesign -s 'Sequel Pro Development' "$BUILD_PRODUCT" 2> /dev/null
	
	# Run a fake command to silence errors
	touch "$BUILD_PRODUCT"
fi

exit 0

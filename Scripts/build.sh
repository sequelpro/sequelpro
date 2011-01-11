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
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
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
rm -rf "${BUILD_PRODUCT}/Contents/Frameworks/BWToolkitFramework.framework/Versions/A/Resources/BWToolkit.ibplugin"
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

# Perform distribution specific tasks if this is a 'Distribution' build
if [ "$CONFIGURATION" == 'Distribution' ]
then
	echo 'Performing distribution build code signing...'

	codesign -s 'Sequel Pro Distribution' "${BUILD_PRODUCT}/Contents/Resources/SequelProTunnelAssistant" 2> /dev/null
	codesign -s 'Sequel Pro Distribution' "${BUILD_PRODUCT}" 2> /dev/null
	
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

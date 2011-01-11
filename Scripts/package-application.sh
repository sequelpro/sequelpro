#!/bin/sh

#
#  $Id$  
#
#  package-application.sh
#  sequel-pro
#
#  Created by Rowan Beentje on March 25, 2009.
#  Copyright (c) 2009 Sequel Pro Team. All rights reserved.
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

#  A very basic script to build and sign a disk image for Sequel Pro; based on better work by Stuart Connolly.
#
#  Ensure the path to the application has been supplied - should have occurred when the
#  script was run by selecting 'Distribution' target and building.

if [ $# -eq 0 ]
then
    echo 'The path to the application must be supplied when running this script.'
    exit
fi

# Grab the version number from the info.plist file
VERSION_NUMBER=`cat "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}${WRAPPER_SUFFIX}/Contents/Info.plist" | tr -d "\n\t" | sed -e 's/.*<key>CFBundleShortVersionString<\/key><string>\([^<]*\)<\/string>.*/\1/'`

# Define target disk image name and temporary names
DMG_VOLUME_NAME="Sequel Pro ${VERSION_NUMBER}"
DMG_NAME="sequel-pro-${VERSION_NUMBER}"
DMG_BUILD_PATH="${BUILT_PRODUCTS_DIR}"
DISTTEMP="${DMG_BUILD_PATH}/disttemp"

# Remove any existing disk images and files with this name
if [ -e "${DMG_BUILD_PATH}/${DMG_NAME}.dmg" ]
then
	rm -f "${DMG_BUILD_PATH}/${DMG_NAME}.dmg"
fi
if [ -e "${DMG_BUILD_PATH}/${DMG_NAME}.dmg.signature" ]
then
	rm -f "${DMG_BUILD_PATH}/${DMG_NAME}.dmg.signature"
fi

# Create a temporary folder to house the disk image contents
mkdir "${DISTTEMP}"

# Copy in the required distribution files
cp -R "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}${WRAPPER_SUFFIX}" "${DMG_BUILD_PATH}/disttemp"

# Create a disk image
hdiutil create -srcfolder "${DISTTEMP}" -volname "$DMG_VOLUME_NAME" -fs HFS+ -fsargs '-c c=64,a=16,e=16' -format UDRW "${DMG_BUILD_PATH}/${DMG_NAME}.temp.dmg" > /dev/null

# Compress the disk image
hdiutil convert "${DMG_BUILD_PATH}/${DMG_NAME}.temp.dmg" -format UDBZ -o "${DMG_BUILD_PATH}/${DMG_NAME}.dmg" > /dev/null

# Remove temporary files and copies
rm -rf "${DISTTEMP}"
rm "${DMG_BUILD_PATH}/${DMG_NAME}.temp.dmg"

# Ask for the location of the private key to use when signing the disk image
PRIVATE_KEY_LOCATION=`osascript <<-eof
	tell application "Xcode"
	set theKey to POSIX path of ((choose file with prompt "Please locate the private key (sequelpro-sparkle-private-key.pem) for signing:" ) as string) 
	end tell
	theKey
	eof`
if [ -e "$PRIVATE_KEY_LOCATION" ]
then
	SIGNATURE=`openssl dgst -sha1 -binary < "${DMG_BUILD_PATH}/${DMG_NAME}.dmg" | openssl dgst -dss1 -sign "$PRIVATE_KEY_LOCATION" | openssl enc -base64`
	echo "$SIGNATURE" > "${DMG_BUILD_PATH}/${DMG_NAME}.dmg.signature"
fi

exit 0

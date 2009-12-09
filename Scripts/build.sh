#! /bin/ksh

## $Id$
##
## Author:      Stuart Connolly (stuconnolly.com)
##              Copyright (c) 2009 Stuart Connolly. All rights reserved.
##
## Paramters:   <none>
##
## Description: Generic Sequel Pro build script. This script is intended to replace entering lots of code
##              into Xcode's 'Run Scripts' build phase to make it easier to work with. As such this script
##              can only be run by Xcode.

# Add the build/bundle version
"${SRCROOT}/Scripts/build-version.pl"

# Trim the application if this is a 'Release' or 'Distribution' build
if [[ "$CONFIGURATION" == 'Release' || "$CONFIGURATION" == 'Distribution' ]]
then
	"${SRCROOT}/Scripts/trim-application.sh" -p "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}${WRAPPER_SUFFIX}" -a
fi

# Perform distribution specific tasks if this is a 'Distribution' build
if [ "$CONFIGURATION" == 'Distribution' ]
then
	codesign -s 'Sequel Pro Distribution' "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}${WRAPPER_SUFFIX}/Contents/Resources/SequelProTunnelAssistant" 2> /dev/null
	codesign -s 'Sequel Pro Distribution' "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}${WRAPPER_SUFFIX}" 2> /dev/null
	
	# Verify that code signing has worked - all distribution builds must be signed with the same key.
	VERIFYERRORS=`codesign --verify "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}${WRAPPER_SUFFIX}" 2>&1`
	VERIFYERRORS+=`codesign --verify "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}${WRAPPER_SUFFIX}/Contents/Resources/SequelProTunnelAssistant" 2>&1`
	if [ "$VERIFYERRORS" != '' ]
	then
		echo "error: Signing verification threw an error: $VERIFYERRORS"
		echo "error: All distribution builds must be signed with the key used for all previous distribution signing!"
		exit 1
	fi

	"${SRCROOT}/Scripts/package-application.sh" -p "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}${WRAPPER_SUFFIX}"
fi

# Development build code signing
if [ "$CONFIGURATION" == 'Debug' ]
then
	codesign -s 'Sequel Pro Development' "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}${WRAPPER_SUFFIX}/Contents/Resources/SequelProTunnelAssistant" 2> /dev/null
	codesign -s 'Sequel Pro Development' "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}${WRAPPER_SUFFIX}" 2> /dev/null
	
	# Run a fake command to silence errors
	touch "${BUILT_PRODUCTS_DIR}/${TARGET_NAME}${WRAPPER_SUFFIX}"
fi

exit 0

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

BUILD_PRODUCT="${BUILT_PRODUCTS_DIR}/${TARGET_NAME}${WRAPPER_SUFFIX}"


echo 'Updating build version...'

# Add the build/bundle version
"${SRCROOT}/Scripts/build-version.pl"

# Remove the .ibplugin from within BWToolkit
rm -rf "${BUILD_PRODUCT}/Contents/Frameworks/BWToolkitFramework.framework/Versions/A/Resources/BWToolkit.ibplugin"

# Perform localisation updates for 'Release' or 'Distribution' builds
if [[ "$CONFIGURATION" == 'Release' || "$CONFIGURATION" == 'Distribution' ]]
then

	echo "Running genstrings to update 'Localizable.strings'..."

	# Update 'Localizable.strings' by running genstrings(1)
	GENSTRINGS_ERRORS=$(genstrings -o "${SRCROOT}/Resources/English.lproj" "${SRCROOT}/Source/"*.m)

	# Check for genstrings errors
	if [[ ${GENSTRINGS_ERRORS} -ne 0 ]]
	then
		echo "error: genstrings exited with error: ${GENSTRINGS_ERRORS}"
	fi

	echo "Updating nib and xib localisations..."

	# Generate up-to-date nib .strings files for localisation
	find "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"/**/*.nib | while read nibFile
	do
		stringsFilePath="${SOURCE_ROOT}/Resources/English.lproj/`basename "${nibFile}" .nib`.strings"
		xibFile=`basename "${nibFile}" .nib`.xib
		xibFilePath=`echo "${SOURCE_ROOT}"/Interfaces/**/"${xibFile}"`
		if [[ -e ${xibFilePath} ]]
		then
			xibfileModDate=`stat -f "%m" "${xibFilePath}"`
			if [[ -e ${stringsFilePath} ]]
			then
				stringsFileModDate=`stat -f "%m" "${stringsFilePath}"`
			else
				stringsFileModDate=0
			fi
			if [[ ${xibfileModDate} -gt ${stringsFileModDate} ]]
			then
				printf "\tLocalising ${xibFile}...\n";
				ibtool --generate-stringsfile "${stringsFilePath}~" "${xibFilePath}"
				"${BUILT_PRODUCTS_DIR}"/xibLocalizationPostprocessor "${stringsFilePath}~" "${stringsFilePath}"
				rm "${stringsFilePath}~"
			fi
		fi
	done
fi

# Trim the application if this is a 'Release' or 'Distribution' build
if [[ "$CONFIGURATION" == 'Release' || "$CONFIGURATION" == 'Distribution' ]]
then
	echo 'Running trim-application.sh to strip application resources for distribution...'

	"${SRCROOT}/Scripts/trim-application.sh" -p "$BUILD_PRODUCT" -a
fi

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

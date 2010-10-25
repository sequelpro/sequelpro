#! /bin/ksh

## $Id$
##
## Author:      Created by Rowan Beentje.
##              Copyright (c) 2010 Sequel Pro Team. All rights reserved.
##
## Paramters:   <none>
##
## Description: Localizes all of the application's NIB files. This script should only be run by Xcode.

if [ "${BUILT_PRODUCTS_DIR}x" == 'x' ]
then
	echo 'This script should only be run by Xcode. Exiting...'
	exit 1
fi

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

exit 0

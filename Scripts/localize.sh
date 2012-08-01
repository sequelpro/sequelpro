#! /bin/ksh 

#
#  $Id$
#
#  localize.sh
#  sequel-pro
#
#  Created by Rowan Beentje.
#  Copyright (c) 2010 Sequel Pro Team. All rights reserved.
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

#  Localizes all of the application's NIB files. This script should only be run by Xcode.

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

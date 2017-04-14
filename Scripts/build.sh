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
#  More info at <https://github.com/sequelpro/sequelpro>

#  Generic Sequel Pro build script. This script is intended to replace entering lots of code
#  into Xcode's 'Run Scripts' build phase to make it easier to work with. As such this script
#  can only be run by Xcode.

if [ "${BUILT_PRODUCTS_DIR}x" == 'x' ]
then
	echo 'This script should only be run by Xcode. Exiting...'
	exit 1
fi

FRAMEWORKS_LIST="/tmp/sp.frameworks.$$"
FILES_TO_SIGN_LIST="/tmp/sp.filelist.$$"
BUILD_PRODUCT="${BUILT_PRODUCTS_DIR}/${TARGET_NAME}${WRAPPER_SUFFIX}"
FRAMEWORKS_PATH="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
SHARED_SUPPORT_DIR="${BUILD_PRODUCT}/Contents/SharedSupport"

dev_sign_resource()
{
	log "Signing resource: $1"

	codesign -f -s 'Sequel Pro Development' "$1" 2> /dev/null
}

dist_sign_framework()
{
	codesign -f -s 'Developer ID Application: MJ Media' -r "${SRCROOT}/Resources/spframeworkrequirement.bin" "$1" 2> /dev/null
}

dist_sign_resource()
{
	codesign -f -s 'Developer ID Application: MJ Media' -r "${SRCROOT}/Resources/sprequirement.bin" "$1" 2> /dev/null
}

verify_signing()
{
	codesign --verify --deep "$1" 2>&1
}

dev_code_sign()
{
	while read FILE_TO_SIGN
	do
		dev_sign_resource "${FILE_TO_SIGN}"
	done < "$1"
}

dist_code_sign()
{
	ERRORS=''

	while read FRAMEWORK_TO_SIGN
	do
		dist_sign_framework "${FRAMEWORK_TO_SIGN}"

		ERRORS+=$(verify_signing "${FRAMEWORK_TO_SIGN}")
	done < "$1"

	while read FILE_TO_SIGN
	do
		dist_sign_resource "${FILE_TO_SIGN}"

		ERRORS+=$(verify_signing "${FILE_TO_SIGN}")
	done < "$2"

	echo $ERRORS
}

copy_default_bundles()
{
	log "Copying default bundles from '${SRCROOT}/SharedSupport/Default Bundles' to '${SHARED_SUPPORT_DIR}'"

	# Copy all Default Bundles to build product
	rm -rf "${SHARED_SUPPORT_DIR}/Default Bundles"

	mkdir -p "${SHARED_SUPPORT_DIR}/Default Bundles"

	cp -R "${SRCROOT}/SharedSupport/Default Bundles" "${SHARED_SUPPORT_DIR}"
}

copy_default_themes()
{
	log "Copying default bundles from '${SRCROOT}/SharedSupport/Default Themes' to '${SHARED_SUPPORT_DIR}'"

	# Copy all Default Themes to build product
	rm -rf "${SHARED_SUPPORT_DIR}/Default Themes"

	mkdir -p "${SHARED_SUPPORT_DIR}/Default Themes"

	cp -R "${SRCROOT}/SharedSupport/Default Themes" "${SHARED_SUPPORT_DIR}"
}

set_spotlight_comment()
{
	log "Setting Spotlight comment to 'MySQL database pancakes with syrup'"

	# Add a SpotLight comment (can't use applescript from a continuous integration server, so we manually set the binaryplist with xattr - but if this fails fall back to applescript)
	xattr -wx com.apple.metadata:kMDItemFinderComment "62 70 6C 69 73 74 30 30 5F 10 22 4D 79 53 51 4C 20 64 61 74 61 62 61 73 65 20 70 61 6E 63 61 6B 65 73 20 77 69 74 68 20 73 79 72 75 70 08 00 00 00 00 00 00 01 01 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 2D" "${BUILD_PRODUCT}"

	if [ $? -ne 0 ] ; then
		osascript -e "tell application \"Finder\" to set comment of (alias (POSIX file \"${BUILD_PRODUCT}\")) to \"MySQL database pancakes with syrup\""
	fi
}

remove_temp_files()
{
	rm "$FRAMEWORKS_LIST"
	rm "$FILES_TO_SIGN_LIST"
}

log()
{
	echo $1
}

log 'Updating build number (build-version.pl)...'

# Add the build/bundle version
"${SRCROOT}/Scripts/build-version.pl"

copy_default_bundles
copy_default_themes

# Perform 'Release' or 'Distribution' build specific actions
if [[ "$CONFIGURATION" == 'Release' || "$CONFIGURATION" == 'Distribution' ]]
then
	log 'Updating localizations (localize.sh)...'

	"${SRCROOT}/Scripts/localize.sh"

	log "Stripping application resources for distribution (trim-application.sh)..."

	"${SRCROOT}/Scripts/trim-application.sh" -p "$BUILD_PRODUCT" -a

	# Remove the .ibplugin from within frameworks
	rm -rf "${BUILD_PRODUCT}/Contents/Frameworks/ShortcutRecorder.framework/Versions/A/Resources/ShortcutRecorder.ibplugin"

	set_spotlight_comment
fi

ls -d -1 "$FRAMEWORKS_PATH"/** > "$FRAMEWORKS_LIST"

echo "${BUILD_PRODUCT}/Contents/Library/QuickLook/Sequel Pro.qlgenerator" >> "$FILES_TO_SIGN_LIST"
echo "${BUILD_PRODUCT}/Contents/Resources/SequelProTunnelAssistant" >> "$FILES_TO_SIGN_LIST"
echo "${BUILD_PRODUCT}" >> "$FILES_TO_SIGN_LIST"

# Perform distribution specific tasks if this is a 'Distribution' build
if [ "$CONFIGURATION" == 'Distribution' ]
then
	log 'Checking for localizations to copy in, using the "ResourcesToCopy" directory...'

	if [ -e "${SRCROOT}/ResourcesToCopy" ]
	then
		TRANSLATIONS_BASE="${SRCROOT}/languagetranslations"
		IBSTRINGSDIR="${SRCROOT}/ibstrings"
		XIB_BASE="${SRCROOT}/Interfaces/English.lproj"

		rm -rf "${IBSTRINGSDIR}" &> /dev/null
		rm -rf "${TRANSLATIONS_BASE}" &> /dev/null

		log "Creating IB strings files for rekeying..."
		
		cp -R "${SRCROOT}/ResourcesToCopy" "${TRANSLATIONS_BASE}"
		
		mkdir -p "$IBSTRINGSDIR/English.lproj"
		
		find "${XIB_BASE}" \( -name "*.xib" \) | while read FILE; do
			ibtool "$FILE" --export-strings-file "$IBSTRINGSDIR/English.lproj/`basename "$FILE" .xib`.strings"
		done

		log "Rekeying localization files, translating xibs, merging localizations..."
		
		find "${TRANSLATIONS_BASE}" \( -name "*.lproj" \) | while read FILE; do
			loc=`basename "$FILE"`

			mkdir "$IBSTRINGSDIR/$loc"
			
			printf "\tProcessing: $loc\n"
			
			find "$FILE" \( -name "*.strings" \) | while read STRFILE; do
				
				file=`basename "$STRFILE" .strings`
				ibkeyfile="$IBSTRINGSDIR/English.lproj/$file.strings"
				xibfile="$XIB_BASE/$file.xib"
				transfile="$IBSTRINGSDIR/$loc/$file.strings"
				
				if [ -e "$ibkeyfile" ] && [ -e "$xibfile" ]; then
					"${BUILT_PRODUCTS_DIR}/xibLocalizationPostprocessor" "$STRFILE" "$ibkeyfile" "$transfile"

					# we no longer need the original file and don't want to copy it
					rm -f "$STRFILE"

					ibtool "$xibfile" --import-strings-file "$transfile" --compile "${TRANSLATIONS_BASE}/$loc/$file.nib"
				fi
			done
			cp -R "$FILE" "${BUILD_PRODUCT}/Contents/Resources/"
		done

		rm -rf "${IBSTRINGSDIR}" &> /dev/null
		rm -rf "${TRANSLATIONS_BASE}" &> /dev/null
	else
		log 'No localizations to copy.'
	fi

	log 'Performing distribution build code signing...'

	VERIFY_ERRORS=$(dist_code_sign "$FRAMEWORKS_LIST" "$FILES_TO_SIGN_LIST")
	
	if [ "$VERIFY_ERRORS" != '' ]
	then
		log "error: Signing verification threw an error: $VERIFY_ERRORS"
		log "error: All distribution builds must be signed with the key used for all previous distribution signing!"
		
		remove_temp_files
		
		exit 1
	fi
	
	log 'Running package-application.sh to package application for distribution...'

	"${SRCROOT}/Scripts/package-application.sh" -p "$BUILD_PRODUCT"
fi

# Development build code signing
if [ "$CONFIGURATION" == 'Debug' ]
then
	log 'Performing development build code signing...'

	dev_code_sign "$FRAMEWORKS_LIST"
	dev_code_sign "$FILES_TO_SIGN_LIST"

	# Run a fake command to silence errors
	touch "$BUILD_PRODUCT"
fi

remove_temp_files

exit 0

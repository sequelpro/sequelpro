#!/bin/bash
# A script to update the Sequel Pro trunk located at a specified location, compile it, build onto a disk image, and upload to the nightlies server.
# This will be called by buildbot with the first parameter being the VCS revision.

# Note that changes to this script will NOT update the nightly builder without manual deployment;
# this script is compiled to an encrypted binary on a builder VM.

# Compiling this script with shc is quite straightforward - /usr/local/bin/shc -T -f <filename> , then move.

# Hacky constants
GIT_DIR=/Users/spbuildbot/buildbot/sequel-pro-10_7/build/
BUILD_DIR=/Users/spbuildbot/buildbot/sequel-pro-10_7/build/build/Release
PRIVATE_KEY_LOC='LOCATION NOT COMMITTED'
NIGHTLY_ICON_LOC=/Users/spbuildbot/Documents/nightly-icon.icns
NIGHTLY_KEYCHAIN_LOC=/Users/spbuildbot/Library/Keychains/spnightly.keychain
NIGHTLY_KEYCHAIN_PASSWORD='PASSWORD NOT COMMITTED'

# Ensure a revision hash was passed in
REVISION_HASH=`echo "$1" | grep "\([0-9a-f]*\)"`
if [ "$REVISION_HASH" == "" ]
then
	echo "Unable to extract revision hash from first argument; cancelling nightly build (git rev-parse HEAD)." >&2
	exit 1
fi	
SHORT_HASH=${REVISION_HASH:0:10}

# Build a numeric revision for bundle version etc
svn2git_migration_compensation=480
cd "$GIT_DIR"
NUMERIC_REVISION=$((`git log --oneline | wc -l` + $svn2git_migration_compensation))

echo "Starting nightly build for hash $SHORT_HASH ($REVISION_HASH), bundle version $NUMERIC_REVISION... "

# Abort if the required paths do not exist
if [ ! -e "$PRIVATE_KEY_LOC" ]
then
	echo "Unable to locate private key; cancelling nightly build." >&2
	exit 1
fi
cd "$BUILD_DIR"
if [ `pwd` != "$BUILD_DIR" ]
then
	echo "Unable to change to nightly build directory; cancelling build." >&2
	exit 1
fi

IBSTRINGSDIR=ibstrings
XIB_BASE="$GIT_DIR/Interfaces/English.lproj"

echo "Cleaning remains of any previous nightly builds..."

# Delete any previous disk images and translation files
rm -f *.dmg &> /dev/null
rm -rf disttemp &> /dev/null
rm -f languagetranslations.zip &> /dev/null
rm -rf languagetranslations &> /dev/null
rm -rf $IBSTRINGSDIR &> /dev/null

echo "Creating IB strings files for rekeying..."
mkdir -p $IBSTRINGSDIR/English.lproj
find "$XIB_BASE" \( -name "*.xib" \) | while read FILE; do
    printf "\t$(basename ${FILE})\n"
    ibtool "$FILE" --export-strings-file "$IBSTRINGSDIR/English.lproj/`basename "$FILE" .xib`.strings"
done

echo "Downloading localizations to merge in..."
# Download the latest language translations, and copy them into the Resources directory
curl http://dev.sequelpro.com/translate/download/sequelpro > languagetranslations.zip
unzip -q languagetranslations.zip -d languagetranslations

echo "Rekeying localization files, translating xibs, merging localizations..."
find languagetranslations/Resources \( -name "*.lproj" \) | while read FILE; do
    loc=`basename "$FILE"`
    mkdir "$IBSTRINGSDIR/$loc"
	printf "\tRekeying localization: $loc\n"
	find "$FILE" \( -name "*.strings" \) | while read STRFILE; do
        file=`basename "$STRFILE" .strings`
        printf "\t\tFile: $file\n"
        ibkeyfile="$IBSTRINGSDIR/English.lproj/$file.strings"
        xibfile="$XIB_BASE/$file.xib"
        transfile="$IBSTRINGSDIR/$loc/$file.strings"
        if [ -e "$ibkeyfile" ] && [ -e "$xibfile" ]; then
            $BUILD_DIR/xibLocalizationPostprocessor "$STRFILE" "$ibkeyfile" "$transfile"
            #we no longer need the original file and don't want to copy it
            rm -f "$STRFILE"
            ibtool "$xibfile" --import-strings-file "$transfile" --compile "languagetranslations/Resources/$loc/$file.nib"
        fi
    done
    printf "\tCopying localization: $loc\n"
    cp -R "$FILE" "Sequel Pro.app/Contents/Resources/"
done

#echo "Copying nightly icon"

# Copy in the nightly icon
#cp -f "$NIGHTLY_ICON_LOC" Sequel\ Pro.app/Contents/Resources/appicon.icns

echo "Updating version strings"

# Update some version strings and info, rather messily
php -r '$infoplistloc = "'$BUILD_DIR'/Sequel Pro.app/Contents/Info.plist";
	$infoplist = file_get_contents($infoplistloc);
	$infoplist = preg_replace("/(\<key\>CFBundleShortVersionString\<\/key\>\s*\n?\r?\s*\<string\>)[^<]*(\<\/string\>)/i", "\\1Nightly build for revision '$SHORT_HASH'\\2", $infoplist);
	$infoplist = preg_replace("/(\<key\>CFBundleVersion\<\/key\>\s*\n?\r?\s*)\<string\>[^<]*(\<\/string\>)/i", "\\1<string>'$NUMERIC_REVISION'\\2", $infoplist);
	$infoplist = preg_replace("/(\<key\>NSHumanReadableCopyright\<\/key\>\s*\n?\r?\s*\<string\>)[^<]*(\<\/string\>)/i", "\\1Nightly build for revision '$SHORT_HASH'\\2", $infoplist);
	$infoplist = preg_replace("/(\<key\>SUFeedURL\<\/key\>\s*\n?\r?\s*\<string\>)[^<]*(\<\/string\>)/i", "\\1https://sequelpro.com/nightly/nightly-app-releases.php\\2", $infoplist);
	file_put_contents($infoplistloc, $infoplist);'

# Update versions in localised string files
php -r '$englishstringsloc = "/'$BUILD_DIR'/Sequel Pro.app/Contents/Resources/English.lproj/InfoPlist.strings";
	$englishstrings = file_get_contents($englishstringsloc);
	$englishstrings = mb_convert_encoding($englishstrings, "UTF-8", "UTF-16");
	$englishstrings = preg_replace("/version [^\,\"]+/iu", "nightly build for r'$SHORT_HASH'", $englishstrings);
        $englishstrings = mb_convert_encoding($englishstrings, "UTF-16", "UTF-8");
	file_put_contents($englishstringsloc, $englishstrings);'

echo "Signing build..."

# Code sign and verify the nightly
#security unlock-keychain -p "$NIGHTLY_KEYCHAIN_PASSWORD" "$NIGHTLY_KEYCHAIN_LOC"
codesign -f --keychain "$NIGHTLY_KEYCHAIN_LOC" -s 'Developer ID Application: MJ Media' -r $GIT_DIR"/Resources/spframeworkrequirement.bin" "Sequel Pro.app/Contents/Resources/SequelProTunnelAssistant"
codesign -f --keychain "$NIGHTLY_KEYCHAIN_LOC" -s 'Developer ID Application: MJ Media' -r $GIT_DIR"/Resources/sprequirement.bin" "Sequel Pro.app"
#security lock-keychain "$NIGHTLY_KEYCHAIN_LOC"
VERIFYERRORS=`codesign --verify "Sequel Pro.app" 2>&1`
VERIFYERRORS+=`codesign --verify "Sequel Pro.app/Contents/Resources/SequelProTunnelAssistant" 2>&1`
if [ "$VERIFYERRORS" != '' ]
then
	echo "Signing verification threw an error: $VERIFYERRORS" >&2
	exit 1
fi

echo "Build signed and verified successfully"
echo "Building disk image..."

# Build the disk image
mkdir disttemp
cp -R -p Sequel\ Pro.app disttemp
SetFile -a B disttemp/Sequel\ Pro.app
hdiutil create -fs HFS+ -volname "Sequel Pro Nightly (r"$SHORT_HASH")" -srcfolder disttemp disttemp.dmg
hdiutil convert disttemp.dmg -format UDBZ -o Sequel_Pro_r"$SHORT_HASH".dmg
rm -rf disttemp*

# Make sure it was created
if [ ! -e "Sequel_Pro_r${SHORT_HASH}.dmg" ]
then
	echo "Disk image was not built successfully!" >&2
	exit 1
fi

echo "Signing disk image"

# Sign the disk image
SIGNATURE=`openssl dgst -sha1 -binary < "Sequel_Pro_r${SHORT_HASH}.dmg" | openssl dgst -dss1 -sign "$PRIVATE_KEY_LOC" | openssl enc -base64 | tr -d "\n"`

echo "Disk image ready (hashed as $SIGNATURE)"
echo "Uploading disk image..."

# Upload the disk image
scp -P 32100 Sequel_Pro_r"$SHORT_HASH".dmg spnightlyuploader@sequelpro.com:nightlybuilds
RETURNVALUE=$?
if [ $RETURNVALUE -eq 0 ]
then
	echo "Successfully uploaded disk image"
	ssh spnightlyuploader@sequelpro.com -p 32100 chmod 666 nightlybuilds/Sequel_Pro_r"$SHORT_HASH".dmg
fi

# Clean up
echo "Cleaning up"
rm -f languagetranslations.zip &> /dev/null
rm -rf languagetranslations &> /dev/null

# Check the upload status
if [ $RETURNVALUE -ne 0 ]
then
	echo "Nightly upload failed"
	exit 1
fi

# Use curl to post the signature to the server
echo "Informing nightly server about new build..."
BUILD_ACTIVATE_OUTPUT=`curl --silent -F "filename=Sequel_Pro_r${SHORT_HASH}.dmg" -F "build_hash=$SIGNATURE" -F "build_id=$NUMERIC_REVISION" -F "full_revision=$REVISION_HASH" http://sequelpro.com/nightly/build.php?action=hash-submit`
if [ "$BUILD_ACTIVATE_OUTPUT" != 'Successfully updated.' ]
then
	echo "Unexpected status when informing nightly server about new build: "
	echo "$BUILD_ACTIVATE_OUTPUT"
	exit 1
fi

echo "Done!"
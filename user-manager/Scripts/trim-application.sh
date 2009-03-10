#! /bin/ksh

## Author:      Stuart Connolly (stuconnolly.com)
##              Copyright (c) 2009 Stuart Connolly. All rights reserved.
##
##              Largely based on 'trim-app' by Ankur Kothari ( http://lipidity.com/downloads/trim-app/ )
##
## Paramters:   -p -- The path to the application that is to be trimmed 
##              -d -- Remove unnecessary files (i.e. .DS_Store files, etc) (optional).
##              -n -- Trim nib files (i.e. remove .info.nib, classes.nib, data.dependency and designable.nib) (optional).
##              -s -- Strip debug symbols from application binary (optional).
##              -t -- Compress tiff images using LZW compression (optional).
##              -f -- Remove framework headers (optional).
##              -r -- Remove resource forks (optional).
##              -a -- All of above optional options. Equivalent to '-d -n -s -t -f -r'.
##
## Description: Trims an application bundle of unnecessary files and resources that are generally not required and otherwise
##              waste disk space.

usage() 
{
	echo "Usage: `basename $0` -p application_path [-d -n -s -t -f -r]"	
	exit 1
}

while getopts ":p:dnstra" OPTION
do
	case $OPTION in 
	    p) APP_PATH="$OPTARG";;
		d) REMOVE_FILES=1;;
		n) TRIM_NIBS=1;;
		s) STRIP_DEBUG=1;;
	   	t) COMPRESS_TIFF=1;;
	   	f) REMOVE_F_HEADERS=1;;
	   	r) REMOVE_RSRC=1;;
	   	a) REMOVE_FILES=1;
	   	   TRIM_NIBS=1;
	   	   STRIP_DEBUG=1;
	   	   COMPRESS_TIFF=1;
	   	   REMOVE_F_HEADERS=1;
	   	   REMOVE_RSRC=1;;
		*) echo 'Unrecognised argument'; usage;;
	esac
done

if [ $# -eq 0 ]
then
    echo 'Illegal number of arguments. I need the path to an application.'
    usage
fi

if [ ! -d "$APP_PATH" ]
then
    echo "Invalid application path. Application at path '${APP_PATH}' doesn't seem to exist."
    usage
fi

if [ ! -w "$APP_PATH" ]
then
    echo "Error: Application at path '${APP_PATH}' is not writeable."
    usage
fi

if [ $# -lt 2 ]
then
    echo 'Illegal number of arguments. I need at least one trim option.'
	usage
fi

printf "Trimming application bundle '`basename $APP_PATH`' at '${APP_PATH}'...\n\n"

# Remove unnecessary files
if [ $REMOVE_FILES ]
then
    printf 'Removing unnecessary files...\n'

    find "$APP_PATH" \( -name '.DS_Store' -or -name 'pbdevelopment.plist' -type f \) | while read FILE; do; printf "\tRemoving file: ${FILE}\n"; rm "$FILE"; done;
fi

# Trim nibs
if [ $TRIM_NIBS ]
then
    printf '\nTrimming nibs...\n'

    find "$APP_PATH" \( -name 'info.nib' -or -name 'classes.nib' -or -name 'data.dependency' -or -name 'designable.nib' -type f \) | while read FILE; do; printf "\tRemoving nib file: ${FILE}\n"; rm "$FILE"; done;
fi

# Strip debug symbols
if [ $STRIP_DEBUG ]
then
    printf '\nStripping debug symbols...\n'

    find "${APP_PATH}/Contents/MacOS" -type f | while read FILE; do; printf "\tStripping binary: ${FILE}\n"; /Developer/Library/PrivateFrameworks/DevToolsCore.framework/Versions/A/Resources/pbxcp -resolve-src-symlinks -strip-debug-symbols "$FILE" '/tmp'; mv "/tmp/$(basename "$FILE")" "$FILE"; done;
fi

# Compress tiff images
if [ $COMPRESS_TIFF ]
then
    printf '\nCompressing tiff images...\n'

    find "$APP_PATH" \( -name "*.tif" -or -name "*.tiff" \) | while read FILE; do; printf "\tCompressing tiff: ${FILE}\n"; tiffutil -lzw "$FILE" -out "${FILE}.out" 2> /dev/null; mv "${FILE}.out" "$FILE"; done;
fi

# Remove framework headers
if [ $REMOVE_F_HEADERS ]
then
    printf '\nRemoving framework headers...\n'
    
    FRAMEWORK_PATH="${APP_PATH}/Contents/Frameworks"
    
    if [ -d "$FRAMEWORK_PATH" ]
    then
        find "$FRAMEWORK_PATH" \( -name "*.h" -type f \) | while read FILE; do; printf "\tRemoving header: ${FILE}\n"; rm "$FILE"; done;
    fi
fi

# Remove resource forks
if [ $REMOVE_RSRC ]
then
    printf '\nRemoving resource forks...\n'
    
    find "$APP_PATH" -type f | while read FILE; do if [ -s "${FILE}/rsrc" ]; then; printf "\tRemoving reource: ${FILE}/rsrc\n"; cp /dev/null "${FILE}/rsrc"; fi; done;
fi

printf "\nTrimming application bundle '`basename $APP_PATH`' complete\n"

exit 0
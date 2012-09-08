#! /bin/ksh

#
#  $Id$
#
#  build-libpq.sh
#  sequel-pro
#
#  Created by Stuart Connolly (stuconnolly.com) on August 1, 2012.
#  Copyright (c) 2012 Stuart Connolly. All rights reserved.
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

#  Builds the PostgreSQL client library for distrubution in Sequel Pro's PostgresKit framework.
#
#  Parameters: -s -- The path to the PostgreSQL source directory.
#              -q -- Quiet. Don't output any compiler messages.
#              -c -- Clean the source instead of building it.
#              -o -- Output path. Defaults to the PostgreSQL source directory.

QUIET='NO'
CLEAN='NO'

MIN_OS_X_VERSION='10.5'

# C/C++ compiler flags
export CFLAGS="-isysroot /Developer3/SDKs/MacOSX${MIN_OS_X_VERSION}.sdk -arch ppc -arch i386 -arch x86_64 -O3 -fno-omit-frame-pointer -fno-exceptions -mmacosx-version-min=${MIN_OS_X_VERSION}"
export CXXFLAGS="-isysroot /Developer3/SDKs/MacOSX${MIN_OS_X_VERSION}.sdk -arch ppc -arch i386 -arch x86_64 -O3 -fno-omit-frame-pointer -felide-constructors -fno-exceptions -fno-rtti -mmacosx-version-min=${MIN_OS_X_VERSION}"

ESC=$(printf '\033')
CONFIGURE_OPTIONS='--enable-thread-safety --with-openssl'

set -A INCLUDE_HEADERS 'src/interfaces/libpq/libpq-fe.h' 'src/include/postgres_ext.h'

usage() 
{	
	cat <<!EOF
Usage: $(basename $0): -s <postgresql_source_path> [-q -c -d -o <output_path>]

Where: -s -- Path to the PostgreSQL source directory.
       -q -- Be quiet during the build. Suppress all compiler messages.
       -c -- Clean the source directory instead of building.
       -o -- Output path. Defaults to the PostgreSQL source directory.
!EOF
}

if [ $# -eq 0 ]
then
	echo "$ESC[1;31mInvalid number of arguments. I need the path to the PostgreSQL source directory.$ESC[0m"
	echo ''
	usage
	exit 1
fi


while getopts ':s:o:qcd' OPTION
do
    case "$OPTION" in
        s) POSTGRESQL_SOURCE_DIR="$OPTARG";;
		o) OUTPUT_PATH="$OPTARG";;
		q) QUIET='YES';;
		c) CLEAN='YES';;
        *) echo "$ESC[1;31mUnrecognised option$ESC[0m"; usage; exit 1;;
    esac
done

if [ ! -d "$POSTGRESQL_SOURCE_DIR" ]
then
	echo "$ESC[1;31mPostgreSQL source directory does not exist at path '${POSTGRESQL_SOURCE_DIR}'.$ESC[0m"
	echo "$ESC[1;31mExiting...$ESC[0m"
	exit 1
fi

if [ "x${OUTPUT_PATH}" != 'x' ]
then
	if [ ! -d "$OUTPUT_PATH" ]
	then
		echo "$ESC[1;31mOutput path does not exist at '${OUTPUT_PATH}'.$ESC[0m"
		echo "$ESC[1;31mExiting...$ESC[0m"
		exit 1
	fi
else
	OUTPUT_PATH="$POSTGRESQL_SOURCE_DIR"
fi

OUTPUT_PATH="${OUTPUT_PATH}/SPPostgreSQLFiles.build"

cd "$POSTGRESQL_SOURCE_DIR"

# Perform a clean if requested
if [ "x${CLEAN}" == 'xYES' ]
then
	echo "$ESC[1mCleaning PostgreSQL source and builds...$ESC[0m"
	
	if [ "x${QUIET}" == 'xYES' ]
	then
		make clean > /dev/null

		if [ -d "$OUTPUT_PATH" ]; then rm -rf "$OUTPUT_PATH" > /dev/null; fi
	else
		make clean
		
		if [ -d "$OUTPUT_PATH" ]; then rm -rf "$OUTPUT_PATH" > /dev/null; fi
	fi

	echo "$ESC[1mCleaning PostgreSQL completed.$ESC[0m"

	exit 0
fi 

echo ''
echo "This script builds the PostgreSQL client library for distribution in Sequel Pro's PostgreSQL framework."
echo 'They are all built as 3-way binaries (32 bit PPC, 32/64 bit i386).'
echo ''
echo -n "$ESC[1mThis may take a while, are you sure you want to continue [y | n]: $ESC[0m"

read CONTINUE

if [ "x${CONTINUE}" == 'xn' ]
then
	echo "$ESC[31mAborting...$ESC[0m"
	exit 0
fi

echo "$ESC[1mConfiguring PostgreSQL source...$ESC[0m"

if [ "x${QUIET}" == 'xYES' ]
then
	./configure $CONFIGURE_OPTIONS > /dev/null
else
	./configure $CONFIGURE_OPTIONS
fi

if [ $? -eq 0 ]
then
	echo "$ESC[1mConfigure successfully completed$ESC[0m"
else
	echo "$ESC[1;31mConfigure failed. Exiting...$ESC[0m"
	exit 1
fi

echo "$ESC[1mBuilding client library...$ESC[0m"

cd "${POSTGRESQL_SOURCE_DIR}/src/interfaces/libpq"

if [ "x${QUIET}" == 'xYES' ]
then
	make > /dev/null
else
	make
fi

cd "${POSTGRESQL_SOURCE_DIR}"

if [ $? -eq 0 ]
then
	echo "$ESC[1mBuilding library successfully completed$ESC[0m"
else
	echo "$ESC[1;31mBuilding library failed. Exiting...$ESC[0m"
	exit 1
fi

echo "$ESC[1mPutting together files for distribution...$ESC[0m"

# Create the appropriate directories
if [ ! -d "$OUTPUT_PATH" ]
then
	mkdir "$OUTPUT_PATH"

	if [ ! $? -eq 0 ]
	then
		echo "$ESC[1;31mCould not create output directory at path '${OUTPUT_PATH}'.$ESC[0m"
		exit 1
	fi
fi

if [ ! -d "${OUTPUT_PATH}/lib" ]
then
	mkdir "${OUTPUT_PATH}/lib"

	if [ ! $? -eq 0 ]
	then
		echo "$ESC[1;31mCould not create lib output directory at path '${OUTPUT_PATH}/lib'.$ESC[0m"
		exit 1
	fi
fi

if [ ! -d "${OUTPUT_PATH}/include" ]
then
	mkdir "${OUTPUT_PATH}/include"

	if [ ! $? -eq 0 ]
	then
		echo "$ESC[1;31mCould not create include output directory at path '${OUTPUT_PATH}/include'.$ESC[0m"
		exit 1
	fi
fi

# Copy the library
cp 'src/interfaces/libpq/libpq.a' "${OUTPUT_PATH}/lib"

if [ ! $? -eq 0 ]
then
	echo "$ESC[1;31mCould not copy libpq.a to output directory (${OUTPUT_PATH}/lib).$ESC[0m"
	exit 1
fi

# Copy in the required headers
for HEADER in ${INCLUDE_HEADERS[@]}
do
	cp "$HEADER" "${OUTPUT_PATH}/include/"
	
	if [ ! $? -eq 0 ]
	then
		echo "$ESC[1;31mCould not copy '${HEADER}' to output directory (${OUTPUT_PATH}/include).$ESC[0m"
		exit 1
	fi
done
	

echo "$ESC[1mBuilding PostgreSQL client library successfully completed.$ESC[0m"
echo "$ESC[1mSee ${OUTPUT_PATH} for the product.$ESC[0m"

exit 0

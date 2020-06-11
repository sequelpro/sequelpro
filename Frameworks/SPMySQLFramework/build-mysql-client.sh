#! /bin/ksh

#
#  $Id$
#
#  build-mysql-client.sh
#  sequel-pro
#
#  Created by Stuart Connolly (stuconnolly.com)
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

#  Builds the MySQL client libraries for distrubution in Sequel Pro's MySQL framework.
#
#  Parameters: -s -- The path to the MySQL source directory.
#              -q -- Quiet. Don't output any compiler messages.
#              -c -- Clean the source instead of building it.
#              -d -- Debug. Output the build statements.

QUIET='NO'
DEBUG='NO'
CLEAN='NO'

# Configuration
MIN_OS_X_VERSION='10.6'
ARCHITECTURES='-arch i386 -arch x86_64'

CONFIGURE_OPTIONS='-DBUILD_CONFIG=mysql_release -DENABLED_LOCAL_INFILE=1 -DWITH_SSL=bundled -DWITH_MYSQLD_LDFLAGS="-all-static --disable-shared" -DWITHOUT_SERVER=1 -DWITH_ZLIB=system -DWITH_UNIT_TESTS=0'
OUTPUT_DIR='SPMySQLFiles.build'

ESC=`printf '\033'`
set -A INCLUDE_HEADERS 'my_alloc.h' 'my_command.h' 'my_list.h' 'mysql_com.h' 'mysql_time.h' 'mysql_version.h' 'mysql.h' 'typelib.h' 'mysql/client_plugin.h' 'mysql/plugin_auth_common.h' 'mysql/psi/psi_base.h' 'mysql/psi/psi_memory.h'

usage() 
{	
	cat <<!EOF
Usage: $(basename $0): -s <mysql_source_path> [-b <boost-1.59.0 source path>] [-q -c -d]

Where: -s -- Path to the MySQL source directory
       -b -- Path to Boost 1.59.0 source directory
       -q -- Be quiet during the build. Suppress all compiler messages
       -c -- Clean the source directory instead of building
       -d -- Debug. Output all the build commands
!EOF
}

# Test for cmake
cmake --version > /dev/null 2>&1

if [ ! $? -eq 0 ]
then
	echo "$ESC[1;31mIn addition to the standard OS X build tools, '$ESC[0;1mcmake$ESC[1;31m' is required to compile the MySQL source.   $ESC[0;1mcmake$ESC[1;31m is found at $ESC[0mcmake.org$ESC[1;31m, and a binary distribution is available from $ESC[0mhttp://www.cmake.org/cmake/resources/software.mhtml$ESC[1;31m ."
	echo "Exiting...$ESC[0m"
	exit 1
fi

if [ $# -eq 0 ]
then
	echo "$ESC[1;31mInvalid number of arguments. I need the path to the MySQL source directory.$ESC[0m"
	echo ''
	usage
	exit 1
fi

BOOST_SOURCE_DIR=
while getopts ':s:b:qcd' OPTION
do
    case "$OPTION" in
        s) MYSQL_SOURCE_DIR="$OPTARG";;
		b) BOOST_SOURCE_DIR="$OPTARG";;
		q) QUIET='YES';;
		c) CLEAN='YES';;
        d) DEBUG='YES';;
        *) echo "$ESC[1;31mUnrecognised option$ESC[0m"; usage; exit 1;;
    esac
done

if [ ! -d "$MYSQL_SOURCE_DIR" ]
then
	echo "$ESC[1;31mMySQL source directory does not exist at path '${MYSQL_SOURCE_DIR}'.$ESC[0m"
	echo "$ESC[1;31mExiting...$ESC[0m"
	exit 1
fi

if [ -d "$BOOST_SOURCE_DIR" ]; then
	CONFIGURE_OPTIONS="${CONFIGURE_OPTIONS} -DWITH_BOOST=${BOOST_SOURCE_DIR}"
fi

# Change to source directory
if [ "x${DEBUG}" == 'xYES' ]
then
	echo "cd ${MYSQL_SOURCE_DIR}"
fi

cd "$MYSQL_SOURCE_DIR"

# Perform a clean if requested
if [ "x${CLEAN}" == 'xYES' ]
then
	echo "$ESC[1mCleaning MySQL source and builds...$ESC[0m"
	
	if [ "x${QUIET}" == 'xYES' ]
	then
		make clean > /dev/null

		if [ -f 'CMakeCache.txt' ]; then rm 'CMakeCache.txt' > /dev/null; fi
		if [ -d "$OUTPUT_DIR" ]; then rm -rf "$OUTPUT_DIR" > /dev/null; fi
	else
		make clean
		
		if [ -f 'CMakeCache.txt' ]; then rm 'CMakeCache.txt'; fi
		if [ -d "$OUTPUT_DIR" ]; then rm -rf "$OUTPUT_DIR" > /dev/null; fi
	fi

	echo "$ESC[1mCleaning MySQL completed.$ESC[0m"

	exit 0
fi 

echo ''
echo "This script builds the MySQL client libraries for distribution in Sequel Pro's MySQL framework."
echo 'They are all built as 2-way binaries (32 and 64 bit i386).'
echo ''
echo -n "$ESC[1mThis may take a while, are you sure you want to continue [y | n]: $ESC[0m"

read CONTINUE

if [ "x${CONTINUE}" == 'xn' ]
then
	echo "$ESC[31mAborting...$ESC[0m"
	exit 0
fi

# Find the SDK path
SDK_PATH=$(xcodebuild -version -sdk 2>/dev/null | grep "^Path: [a-zA-Z0-9\/\.]*$" | awk -F' ' '{ print $2 }' | grep "$MIN_OS_X_VERSION")

if [ "x${SDK_PATH}" == 'x' ]
then
	echo "$ESC[1;31mNo SDK found matching OS X version ${MIN_OS_X_VERSION}.$ESC[0m"
	echo "$ESC[1;31mExiting...$ESC[0m"
	exit 1
fi

# For CMake 3.0+ use CMAKE_OSX_SYSROOT and CMAKE_OSX_DEPLOYMENT_TARGET to set SDK path and minimum version
CONFIGURE_OPTIONS="${CONFIGURE_OPTIONS} -DCMAKE_OSX_SYSROOT='${SDK_PATH}' -DCMAKE_OSX_DEPLOYMENT_TARGET=${MIN_OS_X_VERSION}"

# For CMake 2 add these parameters to the CFLAGS/CXXFLAGS:
# -isysroot ${SDK_PATH} -mmacosx-version-min=${MIN_OS_X_VERSION}

# C/C++ compiler flags
export CFLAGS="${ARCHITECTURES} -O3 -fno-omit-frame-pointer -fno-exceptions"
export CXXFLAGS="${ARCHITECTURES} -O3 -fno-omit-frame-pointer -felide-constructors -fno-exceptions -fno-rtti"

echo "$ESC[1mConfiguring MySQL source...$ESC[0m"

if [ "x${DEBUG}" == 'xYES' ]
then
	echo "cmake ${CONFIGURE_OPTIONS} ."
fi

if [ "x${QUIET}" == 'xYES' ]
then
	cmake $CONFIGURE_OPTIONS . > /dev/null
else
	cmake $CONFIGURE_OPTIONS .
fi

if [ $? -eq 0 ]
then
	echo "$ESC[1mConfigure successfully completed$ESC[0m"
else
	echo "$ESC[1;31mConfigure failed. Exiting...$ESC[0m"
	exit 1
fi

if [ "x${DEBUG}" == 'xYES' ]
then
	echo "make mysqlclient"
fi

echo "$ESC[1mBuilding client libraries...$ESC[0m"

if [ "x${QUIET}" == 'xYES' ]
then
	make mysqlclient > /dev/null
else
	make mysqlclient
fi

if [ $? -eq 0 ]
then
	echo "$ESC[1mBuilding libraries successfully completed$ESC[0m"
else
	echo "$ESC[1;31mBuilding libraries failed. Exiting...$ESC[0m"
	exit 1
fi

echo "$ESC[1mPutting together files for distribution...$ESC[0m"

# Create the appropriate directories
if [ ! -d "$OUTPUT_DIR" ]
then
	mkdir "$OUTPUT_DIR"
	if [ ! $? -eq 0 ]
	then
		echo "$ESC[1;31mCould not create $OUTPUT_DIR output directory!$ESC[0m"
		exit 1
	fi
fi

if [ ! -d "${OUTPUT_DIR}/lib" ]
then
	mkdir "${OUTPUT_DIR}/lib"
	if [ ! $? -eq 0 ]
	then
		echo "$ESC[1;31mCould not create ${OUTPUT_DIR}/lib output directory!$ESC[0m"
		exit 1
	fi
fi

if [ ! -d "${OUTPUT_DIR}/include" ]
then
	mkdir "${OUTPUT_DIR}/include"
	if [ ! $? -eq 0 ]
	then
		echo "$ESC[1;31mCould not create ${OUTPUT_DIR}/include output directory!$ESC[0m"
		exit 1
	fi
fi

# Copy the library
cp 'archive_output_directory/libmysqlclient.a' "${OUTPUT_DIR}/lib/"

if [ ! $? -eq 0 ]
then
	echo "$ESC[1;31mCould not copy libmysqlclient.a to output directory! (${MYSQL_SOURCE_DIR}/${OUTPUT_DIR}/lib)$ESC[0m"
	exit 1
fi

# Copy in the required headers
for eachheader in ${INCLUDE_HEADERS[@]}
do
	INC_DIR="$(dirname ${eachheader})"
	mkdir -p "${OUTPUT_DIR}/include/${INC_DIR}"
	cp "include/${eachheader}" "${OUTPUT_DIR}/include/${eachheader}"
	if [ ! $? -eq 0 ]
	then
		echo "$ESC[1;31mCould not copy ${eachheader} to output directory! (${MYSQL_SOURCE_DIR}/${OUTPUT_DIR}/include)$ESC[0m"
		exit 1
	fi
done
cp libbinlogevents/export/binary_log_types.h "${OUTPUT_DIR}/include/"

echo "$ESC[1mBuilding MySQL client libraries successfully completed.$ESC[0m"
echo "$ESC[1mSee ${MYSQL_SOURCE_DIR}/${OUTPUT_DIR}/ for the product.$ESC[0m"

exit 0

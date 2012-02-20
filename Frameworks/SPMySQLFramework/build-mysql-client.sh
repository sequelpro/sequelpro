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

#  Builds the MySQL client libraries for distrubution in Sequel Pro's MySQL framework.
#
#  Paramters: -s -- The path to the MySQL source directory.
#             -q -- Quiet. Don't output any compiler messages.
#             -c -- Clean the source after build completes.
#             -d -- Debug. Output the build statements.

QUIET='NO'
DEBUG='NO'
CLEAN='NO'

# C/C++ compiler flags
export CFLAGS='-isysroot /Developer/SDKs/MacOSX10.5.sdk -arch ppc -arch i386 -arch x86_64 -O3 -fno-omit-frame-pointer -fno-exceptions -mmacosx-version-min=10.5'
export CXXFLAGS='-isysroot /Developer/SDKs/MacOSX10.5.sdk -arch ppc -arch i386 -arch x86_64 -O3 -fno-omit-frame-pointer -felide-constructors -fno-exceptions -fno-rtti -mmacosx-version-min=10.5'

CONFIGURE_OPTIONS='--without-server --enable-thread-safe-client --disable-dependency-tracking --enable-local-infile --with-ssl --enable-assembler --with-mysqld-ldflags=-all-static'
BINARY_DISTRIBUTION_SCRIPT='scripts/make_binary_distribution'

usage() 
{	
	cat <<!EOF
Usage: $(basename $0): -s <mysql_source_path> [-q -c -d]

Where: -s -- Path to the MySQL source directory
       -q -- Be quiet during the build. Suppress all compiler messages
       -c -- Clean the source directory after the build completes
       -d -- Debug. Output all the build commands
!EOF
}

if [ $# -eq 0 ]
then
	echo "Invalid number of arguments. I need the path to the MySQL source directory."
	echo ''
	usage
	exit 1
fi

echo ''
echo "This script builds the MySQL client libraries for distribution in Sequel Pro's MySQL framework."
echo 'They are all built as 3-way binaries (32 bit PPC, 32/64 bit i386).'
echo ''
echo -n 'This may take a while, are you sure you want to continue [y | n]: '

read CONTINUE

if [ "x${CONTINUE}" == 'xn' ]
then
	echo 'Aborting...'
	exit 0
fi

while getopts ':s:qcd' OPTION
do
    case "$OPTION" in
        s) MYSQL_SOURCE_DIR="$OPTARG";;
		q) QUIET='YES';;
		c) CLEAN='YES';;
        d) DEBUG='YES';;
        *) echo 'Unrecognised option'; usage; exit 1;;
    esac
done

if [ ! -d "$MYSQL_SOURCE_DIR" ]
then
	echo "MySQL source directory does not exist at path '${MYSQL_SOURCE_DIR}'."
	echo 'Exiting...'
	exit 1
fi

# Change to source directory
cd "$MYSQL_SOURCE_DIR"

echo 'Configuring MySQL source...'

if [ "x${DEBUG}" == 'xYES' ]
then
	echo "${MYSQL_SOURCE_DIR}/configure" "$CONFIGURE_OPTIONS"
fi

if [ "x${QUIET}" == 'xYES' ]
then
	./configure $CONFIGURE_OPTIONS > /dev/null
else
	./configure $CONFIGURE_OPTIONS
fi

if [ $? -eq 0 ]
then
	echo 'Configure successfully completed'
else
	echo 'Configure failed. Exiting...'
	exit 1
fi

echo 'Building client libraries...'

if [ "x${QUIET}" == 'xYES' ]
then
	make > /dev/null
else
	make
fi

if [ $? -eq 0 ]
then
	echo 'Building libraries successfully completed'
else
	echo 'Building libraries failed. Exiting...'
	exit 1
fi

echo 'Building binary distribution...'

if [ "x${QUIET}" == 'xYES' ]
then
	$BINARY_DISTRIBUTION_SCRIPT > /dev/null
else
	$BINARY_DISTRIBUTION_SCRIPT
fi

if [ $? -eq 0 ]
then
	echo 'Building binary distribution successfully completed'
else
	echo 'Building binary distribution failed. Exiting...'
	exit 1
fi

if [ "x${CLEAN}" == 'xYES' ]
then
	echo 'Cleaning build...'
	
	if [ "x${QUIET}" == 'xYES' ]
	then
		make clean > /dev/null
	else
		make clean
	fi
fi 

echo 'Building MySQL client libraries successfully completed.'

exit 0

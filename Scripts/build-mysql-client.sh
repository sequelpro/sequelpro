#! /bin/ksh

## Author:      Stuart Connolly (stuconnolly.com)
##              Copyright (c) 2009 Stuart Connolly. All rights reserved.
##
## Paramters:   -s -- The path to the MySQL source directory.
##              -q -- Quiet. Don't output any compiler messages.
##              -c -- Clean the source after build completes.
##              -d -- Debug. Output the build statements.
##
## Description: Builds the MySQL client libraries for distrubution in Sequel Pro's MCPKit MySQL framework.

QUIET='NO'
DEBUG='NO'
CLEAN='NO'

# C/C++ compiler flags
export CFLAGS='-arch ppc -arch i386 -arch ppc64 -arch x86_64 -O3 -fno-omit-frame-pointer'
export CXXFLAGS='-arch ppc -arch i386 -arch ppc64 -arch x86_64 -O3 -fno-omit-frame-pointer -felide-constructors -fno-exceptions -fno-rtti'

CONFIGURE_OPTIONS='--without-server --enable-thread-safe-client --disable-dependency-tracking'
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
echo "This script builds the MySQL client libraries for distrubution in Sequel Pro's MCPKit MySQL framework."
echo 'The are all built as 4-way (32/64 bit, i386/PPC arch) binaries.'
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
	echo 'Bulding libraries successfully completed'
else
	echo 'Bulding libraries failed. Exiting...'
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
	echo 'Bulding binary distribution successfully completed'
else
	echo 'Bulding binary distribution failed. Exiting...'
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

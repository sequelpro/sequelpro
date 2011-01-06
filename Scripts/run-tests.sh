#! /bin/ksh

## $Id$
##
## Author:      Stuart Connolly (stuconnolly.com)
##              Copyright (c) 2011 Stuart Connolly. All rights reserved.
##
## Paramters:   <none>
##
## Description: Runs Sequel Pro's unit tests. This script should only be run by Xcode.

# Add the unit test bundle's Frameworks/ path to the search paths for dynamic libraries
export DYLD_FRAMEWORK_PATH="${CONFIGURATION_BUILD_DIR}/${FULL_PRODUCT_NAME}/Contents/Frameworks"

# Run the unit tests in this test bundle
"${SYSTEM_DEVELOPER_DIR}/Tools/RunUnitTests"

exit 0

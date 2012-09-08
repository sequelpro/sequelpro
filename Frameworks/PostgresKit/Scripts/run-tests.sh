#! /bin/ksh

#
#  $Id$
#
#  run-tests.sh
#  sequel-pro
#
#  Created by Stuart Connolly (stuconnolly.com) on September 9, 2012.
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

export PGPASSWORD=pgkit

if [ ! -f /Library/PostgreSQL/bin/psql ]
then
	echo "error: can't find Postgres CLI at path '/Library/PostgreSQL/bin/psql'. No tests will be run."
	exit 1
fi

TEST_DATA_FILE="${SRCROOT}/Resources/TestData.sql"

if [ ! -f "$TEST_DATA_FILE" ]
then
	echo "error: Test data file does not exist at path '${TEST_DATA_FILE}'. No tests will be run."
	exit 1
fi

echo 'Loading integration data...'

/Library/PostgreSQL/bin/psql -U pgkit_test -d pgkit_test -q < "$TEST_DATA_FILE" > /dev/null 2>&1

if [ $? -eq 0 ]
then
	echo 'Integration test data successfully loaded. Running tests..'
else
	echo 'error: Failed to load integration data. No tests will be run.'
	exit 1
fi

"${SYSTEM_DEVELOPER_DIR}/Tools/RunUnitTests"

exit 0

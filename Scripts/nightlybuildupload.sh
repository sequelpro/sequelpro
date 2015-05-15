#!/usr/bin/expect

# Note that changes to this script will NOT update the nightly builder without manual deployment

# Quiet this script
log_user 0

# A script to upload the specified Sequel Pro build to the nightlies server, as another minor security hurdle.
# This will be called by the build script with the first parameter being the VCS revision, second passphrase

# Ensure a revision number was passed in
set REVISION_NUMBER [lindex $argv 0]
set PASSPHRASE [lindex $argv 1]

# Perform the upload
spawn scp -q -P 32100 /Users/spbuildbot/buildbot/sequel-pro/build/build/Release/Sequel_Pro_r${REVISION_NUMBER}.dmg sequelpro@sequelpro.com:public_html/nightly
expect "Enter passphrase for key '/Users/spbuildbot/.ssh/id_rsa': "
send "${PASSPHRASE}\r"
expect eof
catch wait result
exit [lindex $result 3]

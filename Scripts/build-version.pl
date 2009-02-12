#! /usr/bin/perl -w

## Author:      Stuart Connolly (stuconnolly.com)
##              Copyright (c) 2009 Stuart Connolly. All rights reserved.
##
## Paramters:   <none> 
##
## Description: Updates the application/bundle's Info.plist CFBundleVersion to match that of the current
##              Subversion revision.

use strict;

die "$0: Must be run from within Xcode. Exiting..." unless $ENV{"BUILT_PRODUCTS_DIR"};

my $revision = `svnversion -n ./`;
my $info_plist = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{INFOPLIST_PATH}";

my $version = $revision;

($version =~ m/(\d+)[MS]*$/) && ($version = $1);

die "$0: No Subversion revision found. Exiting..." unless $version;

open(INFO_FH, "$info_plist") or die "$0: $info_plist: $!";
my $info = join("", <INFO_FH>);
close(INFO_FH);

$info =~ s/([\t ]+<key>CFBundleVersion<\/key>\n[\t ]+<string>).*?(<\/string>)/$1$version$2/;

open(INFO_FH, ">$info_plist") or die "$0: $info_plist: $!";
print INFO_FH $info;
close(INFO_FH);

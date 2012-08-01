#! /usr/bin/perl

#
#  $Id$
#
#  build-version.pl
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
#  More info at <http://code.google.com/p/sequel-pro/>

#  Updates the application/bundle's Info.plist CFBundleVersion to match that of the current
#  Subversion revision.

use strict;
use warnings;

use Carp;

die "$0: Must be run from within Xcode. Exiting..." unless $ENV{"BUILT_PRODUCTS_DIR"};

my $revision = `svnversion -n ./`;
my $plist_path = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{INFOPLIST_PATH}";

my $version = $revision;

($version =~ m/(\d+)[MS]*$/) && ($version = $1);

die "$0: No Subversion revision found. Exiting..." unless $version;

open(my $plist, $plist_path) || croak "Unable to open plist file for reading: $!";

my $info = join('', <$plist>);

close($plist);

$info =~ s/([\t ]+<key>CFBundleVersion<\/key>\n[\t ]+<string>).*?(<\/string>)/$1$version$2/;

open($plist, '>', $plist_path) || croak "Unable to open plist file for writing: $!";

print $plist $info;

close($plist);

exit 0

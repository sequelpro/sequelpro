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

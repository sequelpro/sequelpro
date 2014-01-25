#! /usr/bin/perl

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

#  Updates the application/bundle's Info.plist CFBundleVersion to
#  match that of the current Git revision.

use strict;
use warnings;

use Carp;

croak "$0: Must be run from within Xcode. Exiting..." unless $ENV{"BUILT_PRODUCTS_DIR"};

my $plist_path = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{INFOPLIST_PATH}";

#
# Get the revision from Git.
#
sub _get_revision_number
{
	my $svn2git_migration_compensation = 480;

	return `git log --oneline | wc -l` + $svn2git_migration_compensation;
}

#
# Get the rveision long hash from Git.
#
sub _get_revision_long_hash
{
	return `git log -n 1 --pretty=format:%H`;
}

#
# Get the revision short hash from Git.
#
sub _get_revision_short_hash
{
	return `git log -n 1 --pretty=format:%h`;
}

#
# Get the content of the app's Info.plist file.
#
sub _get_plist_content
{
	open(my $plist, shift) || croak "Unable to open plist file for reading: $!";

	my $content = join('', <$plist>);

	close($plist);

	return $content;
}

#
# Save the supplied plist content to the supplied path.
#
sub _save_plist
{
	my ($plist_content, $plist_path) = @_;

	open(my $plist, '>', $plist_path) || croak "Unable to open plist file for writing: $!";

	print $plist $plist_content;

	close($plist);
}

printf("Updating Info.plist file at path $plist_path\n");

my $version = _get_revision_number();
my $version_long_hash = _get_revision_long_hash();
my $version_short_hash = _get_revision_short_hash();

$version_long_hash =~ s/\n//;
$version_short_hash =~ s/\n//;

croak "$0: Unable to determine Git revision. Exiting..." unless $version;
croak "$0: Unable to determine Git revision hash. Exiting..." unless $version_long_hash;
croak "$0: Unable to determine Git revision short hash. Exiting..." unless $version_short_hash;

my $info = _get_plist_content($plist_path);

$info =~ s/([\t ]+<key>CFBundleVersion<\/key>\n[\t ]+<string>).*?(<\/string>)/$1$version$2/;
$info =~ s/([\t ]+<key>SPVersionLongHash<\/key>\n[\t ]+<string>).*?(<\/string>)/$1$version_long_hash$2/;
$info =~ s/([\t ]+<key>SPVersionShortHash<\/key>\n[\t ]+<string>).*?(<\/string>)/$1$version_short_hash$2/;

_save_plist($info, $plist_path);

printf("CFBunderVersion set to $version\n");
printf("SPVersionLongHash set to $version_long_hash\n");
printf("SPVersionShortHash set to $version_short_hash\n");

exit 0

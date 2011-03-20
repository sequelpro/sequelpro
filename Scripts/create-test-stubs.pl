#! /usr/bin/perl

#
#  $Id$  
#
#  create-test-stubs.sh
#  sequel-pro
#
#  Created by Stuart Connolly (stuconnolly.com) on January 8, 2011
#  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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

use strict;
use warnings;

use Carp;
use Getopt::Long;

use constant PROJECT_NAME => 'sequel-pro';
use constant PROJECT_URL  => 'http://code.google.com/p/sequel-pro/';

#
# Print this script's usage.
#
sub usage 
{
	print << "EOF";
Usage: perl $0 [options]

Possible options are:
  
  --header  (-s)      Source header file path (required)
  --output  (-o)      The output path (required)
  --author  (-a)      The author of the eventual test cases (required)
  --help    (-h)      Print this help message

EOF

	exit 0;
}

#
# Writes the standard license/copyright header to the supplied file handle;
#
sub write_header_to_file
{	
	my ($handle, $filename, $author, $is_header) = @_;
	
	my @date = localtime(time);
	
	my @months = qw(January February March April May June July August September October November December);
	
	my $year = ($date[5] + 1900);
	my $month = $months[$date[4]];
	
	my $project = PROJECT_NAME;
	my $project_url = PROJECT_URL;
	
	$filename = ($is_header) ? "${filename}.h" : "${filename}.m";
	
	my $content = << "EOF";
//
//  \$Id\$  
//
//  $filename
//  $project
//
//  Created by $author on $month $date[3], $year
//  Copyright (c) $year ${author}. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <${project_url}>

EOF

	print $handle $content;
}

my ($header, $output, $author, $comments, $help);

# Get options
GetOptions('header|s=s' => \$header,
		   'output|o=s' => \$output,
		   'author|a=s' => \$author,
		   'comments|c' => \$comments,
		   'help|h'     => \$help);
		
usage if $help;
usage if ((!$header) && (!$output) && (!$author));

open(my $header_handle, $header) || croak "Unable to open source header file: $!";

my @methods;
my $class_name;
my $category_name;

# Extract all the methods (both instance and class) from the source header
while (<$header_handle>)
{
	($_ =~ /^\s*\@interface\s*([a-zA-z0-9_-]+)\s*\(([a-zA-z0-9_-]+)\)\s*$/) && ($class_name = $1, $category_name = $2);
	($_ =~ /^\s*[-|+]\s*\([a-zA-Z\s*\*_-]+\)(.*)$/) && (my $method_sig = $1);
	
	$class_name =~ s/^\s+// if $class_name;
	$class_name =~ s/\s+$// if $class_name;
	
	$category_name =~ s/^\s+// if $category_name;
	$category_name =~ s/\s+$// if $category_name;
		
	push(@methods, $method_sig) if $method_sig;
}

close($header_handle);

my $filename = ($category_name) ? $category_name : $class_name;
my $new_filename = "${filename}Tests";

my $header_file = "${output}/${new_filename}.h";
my $imp_file =  "${output}/${new_filename}.m";

# Create the new header and implementation files
open(my $output_header_handle, '>', $header_file) || croak "Unable to open output file: $!";
open(my $output_imp_handle, '>', $imp_file) ||  croak "Unable to open output file: $!";

print "Creating file '${header_file}'...\n";
print "Creating file '${imp_file}'...\n";

# Write the license header to the new files
write_header_to_file($output_header_handle, $new_filename, $author, 1);
write_header_to_file($output_imp_handle, $new_filename, $author, 0);

print $output_header_handle "#import <SenTestingKit/SenTestingKit.h>\n\n\@interface $new_filename : SenTestCase\n{\n\n}\n\n\@end\n";
print $output_imp_handle "#import \"${new_filename}.h\"\n#import \"${filename}.h\"\n\n\@implementation $new_filename\n\n";

# Write the setup and tear down methods
print $output_imp_handle "/**\n * Test case setup.\n */\n" if $comments;
print $output_imp_handle "- (void)setUp\n{\n\n}\n\n";
print $output_imp_handle "/**\n * Test case tear down.\n */\n" if $comments;
print $output_imp_handle "- (void)tearDown\n{\n\n}\n\n";

# For each of the extracted methods write a test case stub to the new test implementation file
foreach (@methods)
{
	$_ =~ s/\([a-zA-Z\s*\*_-]*\)\s*[a-zA-z0-9_-]+//gi;
	$_ =~ s/:\s*([a-zA-z0-9_-]+)\s*/\u$1/gi;
	$_ =~ s/://;
	$_ =~ s/;//;
	
	my $method = "test\u$_";
	
	print "Writing test case stub: $method\n";
	
	print $output_imp_handle "/**\n * $_ test case.\n */\n" if $comments;
	print $output_imp_handle "- (void)${method}\n{\n\n}\n\n";
}

print $output_imp_handle "\@end\n\n";

close($output_header_handle);
close($output_imp_handle);

print "Test case stub generation complete for class '${filename}'\n";

exit 0

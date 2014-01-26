#! /usr/bin/perl

#
#  create-test-stubs.pl
#  sequel-pro
#
#  Created by Stuart Connolly (stuconnolly.com) on January 8, 2011.
#  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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
#  More info at <https://github.com/sequelpro/sequelpro>

use strict;
use warnings;

use Carp;
use Getopt::Long;

use constant PROJECT_NAME => 'sequel-pro';
use constant PROJECT_URL  => 'https://github.com/sequelpro/sequelpro';

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
//  $filename
//  $project
//
//  Created by $author on $month $date[3], $year
//  Copyright (c) $year ${author}. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
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

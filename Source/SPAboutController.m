//
//  $Id$
//
//  SPAboutController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 18, 2009.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPAboutController.h"

static NSString *SPCreditsFilename = @"Credits";
static NSString *SPLicenseFilename = @"License";

@implementation SPAboutController

/**
 * Initialisation
 */
- (id)init
{
	return [super initWithWindowNibName:@"AboutPanel"];
}

/**
 * Initialize interface controls.
 */
- (void)awakeFromNib
{
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	
	// If the version string has a prefix of 'Nightly' then this is obviously a nighly build.
	BOOL isNightly = [version hasPrefix:@"Nightly"];
	
	// Set the application name, but only include the major version if this is not a nightly build.
	[appNameVersionTextField setStringValue:(isNightly) ? @"Sequel Pro" : [NSString stringWithFormat:@"Sequel Pro %@", version]];
	
	// Set the bundle/build version
	[appBuildVersionTextField setStringValue:[NSString stringWithFormat:@"%@ %@", (isNightly) ? NSLocalizedString(@"Nightly Build", @"nightly build label") : NSLocalizedString(@"Build", @"build label") , [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]];

	// Get the credits file contents
	NSAttributedString *credits = [[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:SPCreditsFilename ofType:@"rtf"] documentAttributes:nil] autorelease];

	// Get the license file contents
	NSAttributedString *license = [[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:SPLicenseFilename ofType:@"rtf"] documentAttributes:nil] autorelease];
	
	// Set the credits
	[[appCreditsTextView textStorage] appendAttributedString:credits];
	
	// Set the license
	[[appLicenseTextView textStorage] appendAttributedString:license];
}

/**
 * Display the license sheet.
 */
- (IBAction)openApplicationLicenseSheet:(id)sender
{
	[NSApp beginSheet:appLicensePanel modalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
}

/**
 * Close the license sheet.
 */
- (IBAction)closeApplicationLicenseSheet:(id)sender;
{
	[NSApp endSheet:appLicensePanel returnCode:0];
	[appLicensePanel orderOut:self];
}

@end

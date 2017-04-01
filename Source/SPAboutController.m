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
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPAboutController.h"

static NSString *SPSnapshotBuildIndicator = @"Snapshot";

static NSString *SPCreditsFilename = @"Credits";
static NSString *SPLicenseFilename = @"License";

static NSString *SPAboutPanelNibName = @"AboutPanel";
static NSString *SPShortVersionHashKey = @"SPVersionShortHash";

@interface SPAboutController ()

- (void)_setVersionLabel:(BOOL)isNightly;

@end

@implementation SPAboutController

#pragma mark -

- (id)init
{
	return [super initWithWindowNibName:SPAboutPanelNibName];
}

- (void)awakeFromNib
{
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	
	// If the version string has a prefix of 'Nightly' then this is obviously a nighly build.
	NSRange matchRange = [version rangeOfString:SPSnapshotBuildIndicator];
	BOOL isSnapshotBuild = (matchRange.location != NSNotFound);
	
	// Set the application name, but only include the major version if this is not a nightly build.
	[appNameVersionTextField setStringValue:isSnapshotBuild ? @"Sequel Pro" : [NSString stringWithFormat:@"Sequel Pro %@", version]];

	[self _setVersionLabel:isSnapshotBuild];

	// Get the credits file contents
	NSAttributedString *credits = [[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:SPCreditsFilename ofType:@"rtf"] documentAttributes:nil] autorelease];

	// Get the license file contents
	NSAttributedString *license = [[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:SPLicenseFilename ofType:@"rtf"] documentAttributes:nil] autorelease];
	
	// Set the credits
	[[appCreditsTextView textStorage] appendAttributedString:credits];
	
	// Set the license
	[[appLicenseTextView textStorage] appendAttributedString:license];
}

#pragma mark -
#pragma mark IB action methods

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

#pragma mark -
#pragma mark Private API

/**
 * Set the UI version labels.
 *
 * @param isSnapshot Indicates whether or not this is a snapshot build.
 */
- (void)_setVersionLabel:(BOOL)isSnapshotBuild
{
	NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];

	// Get version numbers
	NSString *bundleVersion = [infoDictionary objectForKey:(NSString *)kCFBundleVersionKey];
	NSString *versionHash = [infoDictionary objectForKey:SPShortVersionHashKey];

	BOOL hashIsEmpty = !versionHash && ![versionHash length];

	NSString *textFieldString;

	if (!bundleVersion && ![bundleVersion length] && hashIsEmpty) {
		textFieldString = @"";
	}
	else {
		textFieldString =
		 [NSString stringWithFormat:@"%@ %@%@",
		  isSnapshotBuild ? NSLocalizedString(@"Snapshot Build", @"snapshot build label") : NSLocalizedString(@"Build", @"build label"),
		  bundleVersion,
		  hashIsEmpty ? @"" : [NSString stringWithFormat:@" (%@)", versionHash]];
	}

	[appBuildVersionTextField setStringValue:textFieldString];
}

@end

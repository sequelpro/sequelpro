//
//  $Id$
//
//  SPAboutController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 18, 2009
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPAboutController.h"

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
	BOOL isNightly = NO;
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	
	// If the version string has a prefix of 'Nightly' then this is obviously a nighly build.
	if ([version hasPrefix:@"Nightly"]) isNightly = YES;
	
	// Set the application name, but only include the major version if this is not a nightly build.
	[appNameVersionTextField setStringValue:(isNightly) ? @"Sequel Pro" : [NSString stringWithFormat:@"Sequel Pro %@", version]];
	
	// Set the bundle/build version
	[appBuildVersionTextField setStringValue:[NSString stringWithFormat:@"%@ %@", (isNightly) ? NSLocalizedString(@"Nightly Build", @"nightly build label") : NSLocalizedString(@"Build", @"build label") , [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]];

	// Get the credits file contents
	NSAttributedString *credits = [[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"] documentAttributes:nil] autorelease];

	// Get the license file contents
	NSAttributedString *license = [[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"License" ofType:@"rtf"] documentAttributes:nil] autorelease];
	
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

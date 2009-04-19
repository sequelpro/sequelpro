//
//  MainController.m
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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
//  Or mail to <lorenz@textor.ch>

#import "MainController.h"
#import "KeyChain.h"
#import "TableDocument.h"
#import "SPPreferenceController.h"

#define SEQUEL_PRO_HOME_PAGE_URL @"http://www.sequelpro.com/"
#define SEQUEL_PRO_DONATIONS_URL @"http://www.sequelpro.com/donate.html"
#define SEQUEL_PRO_FAQ_URL       @"http://www.sequelpro.com/frequently-asked-questions.html"

@implementation MainController

/**
 * Called even before init so we can register our preference defaults
 */
+ (void)initialize
{
	// Register application defaults
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"PreferenceDefaults" ofType:@"plist"]]];
}

/**
 * Initialisation stuff upon nib awakening
 */
- (void)awakeFromNib
{
	prefsController = [[SPPreferenceController alloc] init];
	
	// Register MainController as services provider
	[NSApp setServicesProvider:self];
	
	// Register MainController for AppleScript events
	[[NSScriptExecutionContext sharedScriptExecutionContext] setTopLevelObject:self];
	
	isNewFavorite = NO;

	// Ensure we're not being run on Leopard
	int systemPrefix = 10, systemMajor = 0, systemMinor = 0;
	NSString *systemVersion = [[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"] objectForKey:@"ProductVersion"];    
    NSArray *systemVersionArray = [systemVersion componentsSeparatedByString:@"."];
	if ([systemVersionArray count]) systemPrefix = [[systemVersionArray objectAtIndex:0] intValue];
	if ([systemVersionArray count] > 1) systemMajor = [[systemVersionArray objectAtIndex:1] intValue];
	if ([systemVersionArray count] > 2) systemMinor = [[systemVersionArray objectAtIndex:2] intValue];
	if (systemPrefix == 10 && systemMajor > 4) {
		NSAlert *alert = [NSAlert alertWithMessageText:@"This is the Tiger (10.4) version of Sequel Pro" defaultButton:@"Quit and open website" alternateButton:@"Run anyway" otherButton:@"Quit" informativeTextWithFormat:@"This version of Sequel Pro is only intended for use with Mac OS X Tiger (10.4.x).  When run on your system, the interface will show incorrectly and buttons will be out of place.  We recommend you visit the website to download a current version of Sequel Pro."];
		int returncode = [alert runModal];
		
		// Quit and open website button selected
		if (returncode == NSAlertDefaultReturn) {
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.sequelpro.com/"]];
			[NSApp terminate:self];

		// Quit
		} else if (returncode == NSAlertOtherReturn) {
			[[NSApplication sharedApplication] terminate:self];

		// Run normally, opening a window manually
		} else {
			TableDocument *tableDocument;

			if (tableDocument = [[NSDocumentController sharedDocumentController] makeUntitledDocumentOfType:@"DocumentType" error:nil]) {
				if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AutoConnectToDefault"]) {
					[tableDocument setShouldAutomaticallyConnect:YES];
				}
				[[NSDocumentController sharedDocumentController] addDocument:tableDocument];
				[tableDocument makeWindowControllers];
				[tableDocument showWindows];
			}
		}
	}
}

#pragma mark -
#pragma mark IBAction methods

/**
 * Opens the preferences window
 */
- (IBAction)openPreferences:(id)sender
{
	[prefsController showWindow:self];
}

#pragma mark -
#pragma mark Getters

/**
 * Provide a method to retrieve the prefs controller
 */
- (SPPreferenceController *)preferenceController
{
	return prefsController;
}


#pragma mark -
#pragma mark Services menu methods

/**
 * Passes the query to the last created document
 */
- (void)doPerformQueryService:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error
{
	NSString *pboardString;
	
	NSArray *types = [pboard types];
	
	if ((![types containsObject:NSStringPboardType]) || (!(pboardString = [pboard stringForType:NSStringPboardType]))) {
		*error = @"Pasteboard couldn't give string.";
		
		return;
	}
	
	// Check if at least one document exists
	if (![[[NSDocumentController sharedDocumentController] documents] count]) {
		*error = @"No Documents open!";
		
		return;
	}
	
	// Pass query to last created document
	[[[[NSDocumentController sharedDocumentController] documents] objectAtIndex:([[[NSDocumentController sharedDocumentController] documents] count] - 1)] doPerformQueryService:pboardString];
	
	return;
}

#pragma mark -
#pragma mark Sequel Pro menu methods

/**
 * Opens donate link in default browser
 */
- (IBAction)donate:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SEQUEL_PRO_DONATIONS_URL]];
}

/**
 * Opens website link in default browser
 */
- (IBAction)visitWebsite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SEQUEL_PRO_HOME_PAGE_URL]];
}

/**
 * Opens help link in default browser
 */
- (IBAction)visitHelpWebsite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SEQUEL_PRO_FAQ_URL]];
}

#pragma mark -
#pragma mark Other methods

/**
 * Override the default open-blank-document methods to automatically connect
 * automatically opened windows.
 */
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	TableDocument *firstTableDocument;
	
	// Manually open a new document, setting MainController as sender to trigger autoconnection
	if (firstTableDocument = [[NSDocumentController sharedDocumentController] makeUntitledDocumentOfType:@"DocumentType" error:nil]) {
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AutoConnectToDefault"]) {
			[firstTableDocument setShouldAutomaticallyConnect:YES];
		}
		[[NSDocumentController sharedDocumentController] addDocument:firstTableDocument];
		[firstTableDocument makeWindowControllers];
		[firstTableDocument showWindows];
	}

	// Return NO to the automatic opening
	return NO;
}

/**
 * What exactly is this for? 
 */
- (id)handleQuitScriptCommand:(NSScriptCommand *)command
{
	[NSApp terminate:self];
	
	// Suppress warning
	return nil;
}

@end

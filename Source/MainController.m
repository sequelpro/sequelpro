//
//  $Id$
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

#import "KeyChain.h"
#import "MainController.h"
#import "TableDocument.h"
#import "SPPreferenceController.h"

#import <Sparkle/Sparkle.h>

#define SEQUEL_PRO_HOME_PAGE_URL @"http://www.sequelpro.com/"
#define SEQUEL_PRO_DONATIONS_URL @"http://www.sequelpro.com/donate.html"
#define SEQUEL_PRO_FAQ_URL       @"http://www.sequelpro.com/frequently-asked-questions.html"
#define SEQUEL_PRO_DOCS_URL      @"http://www.sequelpro.com/docs"

@implementation MainController


- (id) init
{
	if ((self = [super init])) {
		[NSApp setDelegate: self];
	}

	return self;
}

/**
 * Called if user drag and drops files on Sequel Pro's dock item or double-clicked
 * at files *.spf or *.sql
 */
- (void)application:(NSApplication *)app openFiles:(NSArray *)filenames
{

	for( NSString* filename in filenames ) {
		
		// Opens a sql file and insert its content to the Custom Query editor
		if([[[filename pathExtension] lowercaseString] isEqualToString:@"sql"]) {

			// Check if at least one document exists
			if (![[[NSDocumentController sharedDocumentController] documents] count]) {
				// TODO : maybe open a connection first
				return;
			}
	
			// Pass query to last created document
			[[[[NSDocumentController sharedDocumentController] documents] objectAtIndex:([[[NSDocumentController sharedDocumentController] documents] count] - 1)] doPerformQueryService:[self contentOfFile:filename]];

		}
		else if([[[filename pathExtension] lowercaseString] isEqualToString:@"spf"]) {
			NSLog(@"open connection %@", filename);
		}
		else {
			NSLog(@"Only files with the extensions ‘spf’ or ‘sql’ are allowed.");
		}
	}

}

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
	// Set Sparkle delegate
	[[SUUpdater sharedUpdater] setDelegate:self];
	
	prefsController = [[SPPreferenceController alloc] init];
	
	// Register MainController as services provider
	[NSApp setServicesProvider:self];
	
	// Register MainController for AppleScript events
	[[NSScriptExecutionContext sharedScriptExecutionContext] setTopLevelObject:self];
	
	isNewFavorite = NO;
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
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SEQUEL_PRO_DOCS_URL]];
}

/**
 * Opens FAQ help link in default browser
 */
- (IBAction)visitFAQWebsite:(id)sender
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

/*
 * Insert content of a plain text file for a given path.
 * In addition it tries to figure out the file's text encoding heuristically.
 */
- (NSString *)contentOfFile:(NSString *)aPath
{
	
	NSError *err = nil;
	NSStringEncoding enc;
	NSString *content = nil;

	// Make usage of the UNIX command "file" to get an info
	// about file type and encoding.
	NSTask *task=[[NSTask alloc] init];
	NSPipe *pipe=[[NSPipe alloc] init];
	NSFileHandle *handle;
	NSString *result;
	[task setLaunchPath:@"/usr/bin/file"];
	[task setArguments:[NSArray arrayWithObjects:aPath, @"-Ib", nil]];
	[task setStandardOutput:pipe];
	handle=[pipe fileHandleForReading];
	[task launch];
	result=[[NSString alloc] initWithData:[handle readDataToEndOfFile]
		encoding:NSASCIIStringEncoding];

	[pipe release];
	[task release];

	// UTF16/32 files are detected as application/octet-stream resp. audio/mpeg
	if( [result hasPrefix:@"text/plain"] 
		|| [[[aPath pathExtension] lowercaseString] isEqualToString:@"sql"] 
		|| [[[aPath pathExtension] lowercaseString] isEqualToString:@"txt"]
		|| [result hasPrefix:@"audio/mpeg"] 
		|| [result hasPrefix:@"application/octet-stream"]
	)
	{
		// if UTF16/32 cocoa will try to find the correct encoding
		if([result hasPrefix:@"application/octet-stream"] || [result hasPrefix:@"audio/mpeg"] || [result rangeOfString:@"utf-16"].length)
			enc = 0;
		else if([result rangeOfString:@"utf-8"].length)
			enc = NSUTF8StringEncoding;
		else if([result rangeOfString:@"iso-8859-1"].length)
			enc = NSISOLatin1StringEncoding;
		else if([result rangeOfString:@"us-ascii"].length)
			enc = NSASCIIStringEncoding;
		else 
			enc = 0;

		if(enc == 0) // cocoa tries to detect the encoding
			content = [NSString stringWithContentsOfFile:aPath usedEncoding:&enc error:&err];
		else
			content = [NSString stringWithContentsOfFile:aPath encoding:enc error:&err];

		if(content)
		{
			[result release];
			return content;
		}
		// If UNIX "file" failed try cocoa's encoding detection
		content = [NSString stringWithContentsOfFile:aPath encoding:enc error:&err];
		if(content)
		{
			[result release];
			return content;
		}
	}
	
	[result release];

	NSLog(@"%@ ‘%@’.", NSLocalizedString(@"Couldn't read the file content of", @"Couldn't read the file content of"), aPath);
	
	return @"";
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

/**
 * Sparkle updater delegate method. Called just before the updater relaunches Sequel Pro and we need to make
 * sure that no sheets are currently open, which will prevent the app from being quit. 
 */
- (void)updaterWillRelaunchApplication:(SUUpdater *)updater
{	
	// Get all the currently open windows and their attached sheets if any
	NSArray *windows = [NSApp windows];
	
	for (NSWindow *window in windows)
	{
		NSWindow *attachedSheet = [window attachedSheet];
		
		if (attachedSheet) {
			[NSApp endSheet:attachedSheet returnCode:0];
			[attachedSheet orderOut:nil];
		}
	}
}

/**
 * Deallocate prefs controller
 */
- (void)dealloc
{
	[prefsController release], prefsController = nil;
	
	[super dealloc];
}

@end

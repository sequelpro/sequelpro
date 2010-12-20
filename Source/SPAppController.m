//
//  $Id$
//
//  SPAppController.m
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

#import "SPKeychain.h"
#import "SPAppController.h"
#import "SPDatabaseDocument.h"
#import "SPPreferenceController.h"
#import "SPAboutController.h"
#import "SPDataImport.h"
#import "SPEncodingPopupAccessory.h"
#import "SPWindowController.h"
#import "SPPreferencesUpgrade.h"
#import "SPBundleEditorController.h"
#import "SPTooltip.h"
#import "SPBundleHTMLOutputController.h"
#import "SPAlertSheets.h"
#import "SPChooseMenuItemDialog.h"
#import "SPCustomQuery.h"

#import <PSMTabBar/PSMTabBarControl.h>
#import <Sparkle/Sparkle.h>

@implementation SPAppController

@synthesize lastBundleBlobFilesDirectory;

/**
 * Initialise the application's main controller, setting itself as the app delegate.
 */
- (id)init
{
	if ((self = [super init])) {
		_sessionURL = nil;
		aboutController = nil;
		lastBundleBlobFilesDirectory = nil;
		_spfSessionDocData = [[NSMutableDictionary alloc] init];

		bundleItems = [[NSMutableDictionary alloc] initWithCapacity:1];
		bundleCategories = [[NSMutableDictionary alloc] initWithCapacity:1];
		bundleTriggers = [[NSMutableDictionary alloc] initWithCapacity:1];
		bundleUsedScopes = [[NSMutableArray alloc] initWithCapacity:1];
		bundleHTMLOutputController = [[NSMutableArray alloc] initWithCapacity:1];
		bundleKeyEquivalents = [[NSMutableDictionary alloc] initWithCapacity:1];
		installedBundleUUIDs = [[NSMutableDictionary alloc] initWithCapacity:1];
		runningActivitiesArray = [[NSMutableArray alloc] init];

		[NSApp setDelegate:self];
	}

	return self;
}

/**
 * Called even before init so we can register our preference defaults
 */
+ (void)initialize
{
	// Register application defaults
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"PreferenceDefaults" ofType:@"plist"]]];

	// Migrate old connection favorites to the app's support directory (only uncomment when ready)
	//SPMigrateConnectionFavoritesData();
}

/**
 * Initialisation stuff upon nib awakening
 */
- (void)awakeFromNib
{
	// Register url scheme handle
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];

	// Set up the prefs controller
	prefsController = [[SPPreferenceController alloc] init];

	// Set Sparkle delegate
	[[SUUpdater sharedUpdater] setDelegate:self];

	// Register SPAppController as services provider
	[NSApp setServicesProvider:self];
	
	// Register SPAppController for AppleScript events
	[[NSScriptExecutionContext sharedScriptExecutionContext] setTopLevelObject:self];

	// Register for drag start notifications - used to bring all windows to front
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tabDragStarted:) name:PSMTabDragDidBeginNotification object:nil];

	isNewFavorite = NO;
}

/**
 * Initialisation stuff after launch is complete
 */
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	// Set ourselves as the crash reporter delegate
	[[FRFeedbackReporter sharedReporter] setDelegate:self];

	// Report any crashes
	[[FRFeedbackReporter sharedReporter] reportIfCrash];

	[self reloadBundles:self];

}

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{

	if ([menuItem action] == @selector(openCurrentConnectionInNewWindow:))
	{
		[menuItem setTitle:NSLocalizedString(@"Open in New Window", @"menu item open in new window")];
		
		return NO;
	}
	if ([menuItem action] == @selector(newTab:))
	{
		return ([[self frontDocumentWindow] attachedSheet] == nil);
	}
	if ([menuItem action] == @selector(duplicateTab:))
	{
		return ([[self frontDocument] getConnection] != nil);
	}

	return YES;
}

#pragma mark -
#pragma mark Open methods

/**
 * NSOpenPanel delegate to control encoding popup and allowMultipleSelection
 */
- (void)panelSelectionDidChange:(id)sender
{
	if ([sender isKindOfClass:[NSOpenPanel class]]) {
		if([[[[sender filename] pathExtension] lowercaseString] isEqualToString:SPFileExtensionSQL]) {
			[encodingPopUp setEnabled:YES];
		} else {
			[encodingPopUp setEnabled:NO];
		}
	}
}

/**
 * NSOpenPanel for selecting sql or spf file
 */
- (IBAction)openConnectionSheet:(id)sender
{
	// Avoid opening more than NSOpenPanel
	if(encodingPopUp){
		NSBeep();
		return;
	}
	
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setDelegate:self];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:NO];
	[panel setResolvesAliases:YES];

	// If no lastSqlFileEncoding in prefs set it to UTF-8
	if(![[NSUserDefaults standardUserDefaults] integerForKey:SPLastSQLFileEncoding]) {
		[[NSUserDefaults standardUserDefaults] setInteger:4 forKey:SPLastSQLFileEncoding];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}

	[panel setAccessoryView:[SPEncodingPopupAccessory encodingAccessory:[[NSUserDefaults standardUserDefaults] integerForKey:SPLastSQLFileEncoding] 
			includeDefaultEntry:NO encodingPopUp:&encodingPopUp]];

	// it will enabled if user selects a *.sql file
	[encodingPopUp setEnabled:NO];

	// Check if at least one document exists, if so show a sheet
	if ([self frontDocumentWindow]) {
		[panel beginSheetForDirectory:nil 
								 file:@"" 
								types:[NSArray arrayWithObjects:SPFileExtensionDefault, SPFileExtensionSQL, SPBundleFileExtension, nil] 
					   modalForWindow:[self frontDocumentWindow]
						modalDelegate:self 
					   didEndSelector:@selector(openConnectionPanelDidEnd:returnCode:contextInfo:) 
						  contextInfo:NULL];
	} 
	else {
		NSInteger returnCode = [panel runModalForDirectory:nil file:nil types:[NSArray arrayWithObjects:SPFileExtensionDefault, SPFileExtensionSQL, SPBundleFileExtension, nil]];

		if (returnCode) [self application:nil openFiles:[panel filenames]];

		encodingPopUp = nil;
	}
}

/**
 * Invoked when the open connection panel is dismissed.
 */
- (void)openConnectionPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode) {
		[panel orderOut:self];
		[self application:nil openFiles:[panel filenames]];
	}

	encodingPopUp = nil;
}

/**
 * Called if user drag and drops files on Sequel Pro's dock item or double-clicked
 * at files *.spf or *.sql
 */
- (void)application:(NSApplication *)app openFiles:(NSArray *)filenames
{

	for (NSString *filename in filenames) 
	{
		// Opens a sql file and insert its content into the Custom Query editor
		if([[[filename pathExtension] lowercaseString] isEqualToString:[SPFileExtensionSQL lowercaseString]]) {

			// Check size and NSFileType
			NSDictionary *attr = [[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:YES];
			if(attr)
			{
				NSNumber *filesize = [attr objectForKey:NSFileSize];
				NSString *filetype = [attr objectForKey:NSFileType];
				if(filetype == NSFileTypeRegular && filesize)
				{
					// Ask for confirmation if file content is larger than 1MB
					if([filesize unsignedLongValue] > 1000000)
					{
						NSAlert *alert = [[NSAlert alloc] init];
						[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
						[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];

						// Show 'Import' button only if there's a connection available
						if ([self frontDocument])
							[alert addButtonWithTitle:NSLocalizedString(@"Import", @"import button")];


						[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Do you really want to load a SQL file with %@ of data into the Query Editor?", @"message of panel asking for confirmation for loading large text into the query editor"),
							 [NSString stringForByteSize:[filesize longLongValue]]]];
						[alert setHelpAnchor:filename];
						[alert setMessageText:NSLocalizedString(@"Warning",@"warning")];
						[alert setAlertStyle:NSWarningAlertStyle];

						NSUInteger returnCode = [alert runModal];

						[alert release];

						if(returnCode == NSAlertSecondButtonReturn) return; // Cancel
						else if(returnCode == NSAlertThirdButtonReturn) {   // Import
							// begin import process
							[[[self frontDocument] valueForKeyPath:@"tableDumpInstance"] startSQLImportProcessWithFile:filename];
							return;
						}
					}
				}
			}

			// Attempt to open the file into a string.
			NSString *sqlString = nil;
			
			// If the user came from an openPanel use the chosen encoding
			if (encodingPopUp) {
				NSError *error = nil;
				sqlString = [NSString stringWithContentsOfFile:filename encoding:[[encodingPopUp selectedItem] tag] error:&error];
				if(error != nil) {
					NSAlert *errorAlert = [NSAlert alertWithError:error];
					[errorAlert runModal];
					return;
				}
			
			// Otherwise, read while attempting to autodetect the encoding
			} else {
				sqlString = [self contentOfFile:filename];
			}

			// if encodingPopUp is defined the filename comes from an openPanel and
			// the encodingPopUp contains the chosen encoding; otherwise autodetect encoding
			if(encodingPopUp)
				[[NSUserDefaults standardUserDefaults] setInteger:[[encodingPopUp selectedItem] tag] forKey:SPLastSQLFileEncoding];

			// Check if at least one document exists.  If not, open one.
			if (![self frontDocument]) {
				[self newWindow:self];
				[[self frontDocument] initQueryEditorWithString:sqlString];
			} else {

				// Pass query to the Query editor of the current document
				[[self frontDocument] doPerformLoadQueryService:[self contentOfFile:filename]];
			}

			break; // open only the first SQL file

		}
		else if([[[filename pathExtension] lowercaseString] isEqualToString:[SPFileExtensionDefault lowercaseString]]) {

			SPWindowController *frontController = nil;

			for (NSWindow *aWindow in [self orderedWindows]) {
				if ([[aWindow windowController] isMemberOfClass:[SPWindowController class]]) {
					frontController = [aWindow windowController];
					break;
				}
			}

			// If no window was found or the front most window has no tabs, create a new one
			if (!frontController || [[frontController valueForKeyPath:@"tabView"] numberOfTabViewItems] == 1) {
				[self newWindow:self];
			// Open the spf file in a new tab if the tab bar is visible
			} else if ([[frontController valueForKeyPath:@"tabView"] numberOfTabViewItems] != 1) {
				if ([[frontController window] isMiniaturized]) [[frontController window] deminiaturize:self];
				[frontController addNewConnection:self];
			}

			[[self frontDocument] setStateFromConnectionFile:filename];
		}
		else if([[[filename pathExtension] lowercaseString] isEqualToString:[SPBundleFileExtension lowercaseString]]) {

			NSError *readError = nil;
			NSString *convError = nil;
			NSPropertyListFormat format;
			NSDictionary *spfs = nil;
			NSData *pData = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/info.plist", filename] options:NSUncachedRead error:&readError];

			spfs = [[NSPropertyListSerialization propertyListFromData:pData 
					mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

			if(!spfs || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
				NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading connection data file", @"error while reading connection data file")]
												 defaultButton:NSLocalizedString(@"OK", @"OK button") 
											   alternateButton:nil 
												  otherButton:nil 
									informativeTextWithFormat:NSLocalizedString(@"Connection data file couldn't be read.", @"error while reading connection data file")];

				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert runModal];
				if (spfs) [spfs release];
				return;
			}


			if([spfs objectForKey:@"windows"] && [[spfs objectForKey:@"windows"] isKindOfClass:[NSArray class]]) {

				NSFileManager *fileManager = [NSFileManager defaultManager];

				// Retrieve Save Panel accessory view data for remembering them globally
				NSMutableDictionary *spfsDocData = [NSMutableDictionary dictionary];
				[spfsDocData setObject:[NSNumber numberWithBool:[[spfs objectForKey:@"encrypted"] boolValue]] forKey:@"encrypted"];
				[spfsDocData setObject:[NSNumber numberWithBool:[[spfs objectForKey:@"auto_connect"] boolValue]] forKey:@"auto_connect"];
				[spfsDocData setObject:[NSNumber numberWithBool:[[spfs objectForKey:@"save_password"] boolValue]] forKey:@"save_password"];
				[spfsDocData setObject:[NSNumber numberWithBool:[[spfs objectForKey:@"include_session"] boolValue]] forKey:@"include_session"];
				[spfsDocData setObject:[NSNumber numberWithBool:[[spfs objectForKey:@"save_editor_content"] boolValue]] forKey:@"save_editor_content"];

				// Set global session properties
				[[NSApp delegate] setSpfSessionDocData:spfsDocData];
				[[NSApp delegate] setSessionURL:filename];

				// Loop through each defined window in reversed order to reconstruct the last active window
				for(NSDictionary *window in [[[spfs objectForKey:@"windows"] reverseObjectEnumerator] allObjects]) {

					// Create a new window controller, and set up a new connection view within it.
					SPWindowController *newWindowController = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
					NSWindow *newWindow = [newWindowController window];

					// If window has more than 1 tab then set setHideForSingleTab to NO
					// in order to avoid animation problems while opening tabs
					if([[window objectForKey:@"tabs"] count] > 1)
						[newWindowController setHideForSingleTab:NO];

					// The first window should use autosaving; subsequent windows should cascade.
					// So attempt to set the frame autosave name; this will succeed for the very
					// first window, and fail for others.
					BOOL usedAutosave = [newWindow setFrameAutosaveName:@"DBView"];
					if (!usedAutosave) {
						[newWindow setFrameUsingName:@"DBView"];
					}

					if([window objectForKey:@"frame"])
						[newWindow setFrame:NSRectFromString([window objectForKey:@"frame"]) display:NO];

					// Set the window controller as the window's delegate
					[newWindow setDelegate:newWindowController];

					usleep(1000);

					// Show the window
					[newWindowController showWindow:self];

					// Loop through all defined tabs for each window
					for(NSDictionary *tab in [window objectForKey:@"tabs"]) {

						NSString *fileName = nil;
						BOOL isBundleFile = NO;

						// If isAbsolutePath then take this path directly
						// otherwise construct the releative path for the passed spfs file
						if([[tab objectForKey:@"isAbsolutePath"] boolValue])
							fileName = [tab objectForKey:@"path"];
						else {
							fileName = [NSString stringWithFormat:@"%@/Contents/%@", filename, [tab objectForKey:@"path"]];
							isBundleFile = YES;
						}

						// Security check if file really exists
						if([fileManager fileExistsAtPath:fileName]) {

							// Add new the tab
							if(newWindowController) {

								if ([[newWindowController window] isMiniaturized]) [[newWindowController window] deminiaturize:self];
								[newWindowController addNewConnection:self];

								[[self frontDocument] setIsSavedInBundle:isBundleFile];
								[[self frontDocument] setStateFromConnectionFile:fileName];
							}

						} else {
							NSLog(@"Bundle file “%@” does not exists", fileName);
							NSBeep();
						}
					}

					// Select active tab
					[newWindowController selectTabAtIndex:[[window objectForKey:@"selectedTabIndex"] intValue]];

					// Reset setHideForSingleTab
					if([[NSUserDefaults standardUserDefaults] objectForKey:SPAlwaysShowWindowTabBar])
						[newWindowController setHideForSingleTab:[[NSUserDefaults standardUserDefaults] boolForKey:SPAlwaysShowWindowTabBar]];
					else
						[newWindowController setHideForSingleTab:YES];

				}

			}

			[spfs release];
		}
		else if([[[filename pathExtension] lowercaseString] isEqualToString:[SPColorThemeFileExtension lowercaseString]]) {

			NSFileManager *fm = [NSFileManager defaultManager];

			NSString *themePath = [[NSFileManager defaultManager] applicationSupportDirectoryForSubDirectory:SPThemesSupportFolder error:nil];

			if(!themePath) return;

			if(![fm fileExistsAtPath:themePath isDirectory:nil]) {
				if(![fm createDirectoryAtPath:themePath withIntermediateDirectories:YES attributes:nil error:nil]) {
					NSBeep();
					return;
				}
			}

			NSString *newPath = [NSString stringWithFormat:@"%@/%@", themePath, [filename lastPathComponent]];
			if(![fm fileExistsAtPath:newPath isDirectory:nil]) {
				if(![fm moveItemAtPath:filename toPath:newPath error:nil]) {
					NSBeep();
					return;
				}
			} else {
				NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while installing color theme file", @"error while installing color theme file")]
												 defaultButton:NSLocalizedString(@"OK", @"OK button") 
											   alternateButton:nil 
												  otherButton:nil 
									informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"The color theme ‘%@’ already exists.", @"the color theme ‘%@’ already exists."), [filename lastPathComponent]]];

				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert runModal];
				return;
			}
		}
		else if([[[filename pathExtension] lowercaseString] isEqualToString:[SPUserBundleFileExtension lowercaseString]]) {

			NSFileManager *fm = [NSFileManager defaultManager];

			NSString *bundlePath = [[NSFileManager defaultManager] applicationSupportDirectoryForSubDirectory:SPBundleSupportFolder error:nil];

			if(!bundlePath) return;

			if(![fm fileExistsAtPath:bundlePath isDirectory:nil]) {
				if(![fm createDirectoryAtPath:bundlePath withIntermediateDirectories:YES attributes:nil error:nil]) {
					NSBeep();
					NSLog(@"Couldn't create folder “%@”", bundlePath);
					return;
				}
			}

			NSString *newPath = [NSString stringWithFormat:@"%@/%@", bundlePath, [filename lastPathComponent]];

			NSError *readError = nil;
			NSString *convError = nil;
			NSPropertyListFormat format;
			NSDictionary *cmdData = nil;
			NSString *infoPath = [NSString stringWithFormat:@"%@/%@", filename, SPBundleFileName];
			NSData *pData = [NSData dataWithContentsOfFile:infoPath options:NSUncachedRead error:&readError];

			cmdData = [[NSPropertyListSerialization propertyListFromData:pData 
					mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

			if(!cmdData || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
				NSLog(@"“%@/%@” file couldn't be read.", filename, SPBundleFileName);
				NSBeep();
				if (cmdData) [cmdData release];
				return;
			} else {
				// Check for installed UUIDs
				if(![cmdData objectForKey:SPBundleFileUUIDKey]) {
					NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while installing bundle file", @"error while installing bundle file")]
													 defaultButton:NSLocalizedString(@"OK", @"OK button") 
												   alternateButton:nil 
													  otherButton:nil 
										informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"The bundle ‘%@’ has no UUID which is necessary to identify installed bundles.", @"the bundle ‘%@’ has no UUID which is necessary to identify installed bundles."), [filename lastPathComponent]]];

					[alert setAlertStyle:NSCriticalAlertStyle];
					[alert runModal];
					if (cmdData) [cmdData release];
					return;
				}
				if([[installedBundleUUIDs allKeys] containsObject:[cmdData objectForKey:SPBundleFileUUIDKey]]) {
					NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Installing bundle file", @"installing bundle file")]
													 defaultButton:NSLocalizedString(@"Update", @"Update button") 
												   alternateButton:NSLocalizedString(@"Cancel", @"Cancel button")
													  otherButton:nil 
										informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"A bundle ‘%@’ is already installed. Do you want to update it?", @"a bundle ‘%@’ is already installed. do you want to update it?"), [[installedBundleUUIDs objectForKey:[cmdData objectForKey:SPBundleFileUUIDKey]] objectForKey:@"name"]]];

					[alert setAlertStyle:NSCriticalAlertStyle];
					NSInteger answer = [alert runModal];
					if(answer == NSAlertDefaultReturn) {
						NSError *error = nil;
						NSString *moveToTrashCommand = [NSString stringWithFormat:@"osascript -e 'tell application \"Finder\" to move (POSIX file \"%@\") to the trash'", infoPath];
						[moveToTrashCommand runBashCommandWithEnvironment:nil atCurrentDirectoryPath:nil error:&error];
						if(error != nil) {
							NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while moving “%@” to Trash.", @"error while moving “%@” to trash"), [[installedBundleUUIDs objectForKey:[cmdData objectForKey:SPBundleFileUUIDKey]] objectForKey:@"path"]]
															 defaultButton:NSLocalizedString(@"OK", @"OK button") 
														   alternateButton:nil 
															  otherButton:nil 
												informativeTextWithFormat:[error localizedDescription]];

							[alert setAlertStyle:NSCriticalAlertStyle];
							[alert runModal];
							if (cmdData) [cmdData release];
							return;
						}
					} else {
						if (cmdData) [cmdData release];
						return;
					}
				}
			}

			if (cmdData) [cmdData release];

			if(![fm fileExistsAtPath:newPath isDirectory:nil]) {
				if(![fm moveItemAtPath:filename toPath:newPath error:nil]) {
					NSBeep();
					NSLog(@"Couldn't move “%@” to “%@”", filename, newPath);
					return;
				}
				// Update Bundle Editor if it was already initialized
				for(id win in [NSApp windows]) {
					if([[[[win delegate] class] description] isEqualToString:@"SPBundleEditorController"]) {
						[[win delegate] reloadBundles:nil];
						break;
					}
				}
				// Update Bundels' menu
				[self reloadBundles:self];

			} else {
				NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while installing bundle file", @"error while installing bundle file")]
												 defaultButton:NSLocalizedString(@"OK", @"OK button") 
											   alternateButton:nil 
												  otherButton:nil 
									informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"The bundle ‘%@’ already exists.", @"the bundle ‘%@’ already exists."), [filename lastPathComponent]]];

				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert runModal];
				return;
			}
		}
		else {
			NSLog(@"Only files with the extensions ‘%@’, ‘%@’, ‘%@’ or ‘%@’ are allowed.", SPFileExtensionDefault, SPBundleFileExtension, SPColorThemeFileExtension, SPFileExtensionSQL);
		}
	}
}

#pragma mark -
#pragma mark URL scheme handler

/**
 * “sequelpro://” url dispatcher
 *
 * sequelpro://PROCESS_ID@command/parameter1/parameter2/...
 *    parameters has to be escaped according to RFC 1808  eg %3F for a '?'
 *
 */
- (void)handleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{

	NSURL *url = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
	[self handleEventWithURL:url];
}

- (void)handleEventWithURL:(NSURL*)url
{
	NSString *command = [url host];
	NSString *passedProcessID = [url user];
	NSArray *parameter;
	NSArray *pathComponents = [url pathComponents];
	if([pathComponents count] > 1)
		parameter = [pathComponents subarrayWithRange:NSMakeRange(1,[[url pathComponents] count]-1)];
	else
		parameter = [NSArray array];

	NSString *activeProcessID = [[[[self frontDocumentWindow] delegate] selectedTableDocument] processID];

	SPDatabaseDocument *processDocument = nil;

	// Try to find the SPDatabaseDocument which sent the the url scheme command
	// For speed check the front most first otherwise iterate through all
	if(passedProcessID && [passedProcessID length]) {
		if([activeProcessID isEqualToString:passedProcessID]) {
			processDocument = [[[self frontDocumentWindow] delegate] selectedTableDocument];
		} else {
			for (NSWindow *aWindow in [NSApp orderedWindows]) {
				if([[aWindow windowController] isMemberOfClass:[SPWindowController class]]) {
					for(SPDatabaseDocument *doc in [[aWindow windowController] documents]) {
						if([doc processID] && [[doc processID] isEqualToString:passedProcessID]) {
							processDocument = doc;
							break;
						}
					}
				}
				if(processDocument) break;
			}
		}
	}

	// if no processDoc found and no passedProcessID was passed execute
	// command at front most doc
	if(!processDocument && !passedProcessID)
		processDocument = [[[self frontDocumentWindow] delegate] selectedTableDocument];

	if(processDocument && command) {
		if([command isEqualToString:@"passToDoc"]) {
			NSMutableDictionary *cmdDict = [NSMutableDictionary dictionary];
			[cmdDict setObject:parameter forKey:@"parameter"];
			[cmdDict setObject:(passedProcessID)?:@"" forKey:@"id"];
			[processDocument handleSchemeCommand:cmdDict];
			return;
		}
		else {
			SPBeginAlertSheet(NSLocalizedString(@"sequelpro URL Scheme Error", @"sequelpro url Scheme Error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [NSApp mainWindow], self, nil, nil,
							  [NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [command description], NSLocalizedString(@"sequelpro URL scheme command not supported.", @"sequelpro URL scheme command not supported.")]);
			
			return;
		}
	}

	if(passedProcessID && [passedProcessID length]) {
		// If command failed notify the file handle hand shake mechanism
		NSString *out = @"1";
		[out writeToFile:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultStatusPathHeader, passedProcessID]
			atomically:YES
			encoding:NSUTF8StringEncoding
			   error:nil];
		out = NSLocalizedString(@"An error for sequelpro URL scheme command occurred. Probably no corresponding connection window found.", @"An error for sequelpro URL scheme command occurred. Probably no corresponding connection window found.");
		[out writeToFile:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultPathHeader, passedProcessID]
			atomically:YES
			encoding:NSUTF8StringEncoding
			   error:nil];
		
		SPBeginAlertSheet(NSLocalizedString(@"sequelpro URL Scheme Error", @"sequelpro url Scheme Error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [NSApp mainWindow], self, nil, nil,
						  [NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [command description], NSLocalizedString(@"An error for sequelpro URL scheme command occurred. Probably no corresponding connection window found.", @"An error for sequelpro URL scheme command occurred. Probably no corresponding connection window found.")]);


		usleep(5000);
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultStatusPathHeader, passedProcessID] error:nil];
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultPathHeader, passedProcessID] error:nil];
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultMetaPathHeader, passedProcessID] error:nil];
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryInputPathHeader, passedProcessID] error:nil];



	} else {
		SPBeginAlertSheet(NSLocalizedString(@"sequelpro URL Scheme Error", @"sequelpro url Scheme Error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [NSApp mainWindow], self, nil, nil,
						  [NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [command description], NSLocalizedString(@"An error occur while executing a scheme command. If the scheme command was invoked by a Bundle command, it could be that the command still runs. You can try to terminate it by pressing ⌘+. or via the Activities pane.", @"an error occur while executing a scheme command. if the scheme command was invoked by a bundle command, it could be that the command still runs. you can try to terminate it by pressing ⌘+. or via the activities pane.")]);
	}

	if(processDocument)
		NSLog(@"process doc ID: %@\n%@", [processDocument processID], [processDocument tabTitleForTooltip]);
	else
		NSLog(@"No corresponding doc found");
	NSLog(@"param: %@", parameter);
	NSLog(@"command: %@", command);
	NSLog(@"command id: %@", passedProcessID);

}

- (IBAction)executeBundleItemForApp:(id)sender
{
	
	NSInteger idx = [sender tag] - 1000000;
	NSString *infoPath = nil;
	NSArray *bundleItems = [[NSApp delegate] bundleItemsForScope:SPBundleScopeGeneral];
	if(idx >=0 && idx < [bundleItems count]) {
		infoPath = [[bundleItems objectAtIndex:idx] objectForKey:SPBundleInternPathToFileKey];
	} else {
		if([sender tag] == 0 && [[sender toolTip] length]) {
			infoPath = [sender toolTip];
		}
	}

	if(!infoPath) {
		NSBeep();
		return;
	}

	NSError *readError = nil;
	NSString *convError = nil;
	NSPropertyListFormat format;
	NSDictionary *cmdData = nil;
	NSData *pData = [NSData dataWithContentsOfFile:infoPath options:NSUncachedRead error:&readError];

	cmdData = [[NSPropertyListSerialization propertyListFromData:pData 
			mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

	if(!cmdData || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
		NSLog(@"“%@” file couldn't be read.", infoPath);
		NSBeep();
		if (cmdData) [cmdData release];
		return;
	} else {
		if([cmdData objectForKey:SPBundleFileCommandKey] && [[cmdData objectForKey:SPBundleFileCommandKey] length]) {

			NSString *cmd = [cmdData objectForKey:SPBundleFileCommandKey];
			NSString *inputAction = @"";
			NSString *inputFallBackAction = @"";
			NSError *err = nil;
			NSString *uuid = [NSString stringWithNewUUID];
			NSString *bundleInputFilePath = [NSString stringWithFormat:@"%@_%@", SPBundleTaskInputFilePath, uuid];

			[[NSFileManager defaultManager] removeItemAtPath:bundleInputFilePath error:nil];

			NSMutableDictionary *env = [NSMutableDictionary dictionary];
			[env setObject:[infoPath stringByDeletingLastPathComponent] forKey:SPBundleShellVariableBundlePath];
			[env setObject:bundleInputFilePath forKey:SPBundleShellVariableInputFilePath];
			[env setObject:SPBundleScopeGeneral forKey:SPBundleShellVariableBundleScope];

			NSString *input = @"";
			NSError *inputFileError = nil;
			if(input == nil) input = @"";
			[input writeToFile:bundleInputFilePath
					  atomically:YES
						encoding:NSUTF8StringEncoding
						   error:&inputFileError];
			
			if(inputFileError != nil) {
				NSString *errorMessage  = [inputFileError localizedDescription];
				SPBeginAlertSheet(NSLocalizedString(@"Bundle Error", @"bundle error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self window], self, nil, nil,
								  [NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [cmdData objectForKey:@"name"], errorMessage]);
				if (cmdData) [cmdData release];
				return;
			}

			NSString *output = [cmd runBashCommandWithEnvironment:env 
											atCurrentDirectoryPath:nil 
											callerInstance:self 
											contextInfo:[NSDictionary dictionaryWithObjectsAndKeys:
													([cmdData objectForKey:SPBundleFileNameKey])?:@"-", @"name",
													NSLocalizedString(@"General", @"general menu item label"), @"scope",
													uuid, SPBundleFileInternalexecutionUUID,
													nil]
											error:&err];

			[[NSFileManager defaultManager] removeItemAtPath:bundleInputFilePath error:nil];

			NSString *action = [[cmdData objectForKey:SPBundleFileOutputActionKey] lowercaseString];

			// Redirect due exit code
			if(err != nil) {
				if([err code] == SPBundleRedirectActionNone) {
					action = SPBundleOutputActionNone;
					err = nil;
				}
				else if([err code] == SPBundleRedirectActionReplaceSection) {
					action = SPBundleOutputActionReplaceSelection;
					err = nil;
				}
				else if([err code] == SPBundleRedirectActionReplaceContent) {
					action = SPBundleOutputActionReplaceContent;
					err = nil;
				}
				else if([err code] == SPBundleRedirectActionInsertAsText) {
					action = SPBundleOutputActionInsertAsText;
					err = nil;
				}
				else if([err code] == SPBundleRedirectActionInsertAsSnippet) {
					action = SPBundleOutputActionInsertAsSnippet;
					err = nil;
				}
				else if([err code] == SPBundleRedirectActionShowAsHTML) {
					action = SPBundleOutputActionShowAsHTML;
					err = nil;
				}
				else if([err code] == SPBundleRedirectActionShowAsTextTooltip) {
					action = SPBundleOutputActionShowAsTextTooltip;
					err = nil;
				}
				else if([err code] == SPBundleRedirectActionShowAsHTMLTooltip) {
					action = SPBundleOutputActionShowAsHTMLTooltip;
					err = nil;
				}
			}

			if(err == nil && output) {
				if([cmdData objectForKey:SPBundleFileOutputActionKey] && [[cmdData objectForKey:SPBundleFileOutputActionKey] length] 
						&& ![[cmdData objectForKey:SPBundleFileOutputActionKey] isEqualToString:SPBundleOutputActionNone]) {
					NSPoint pos = [NSEvent mouseLocation];
					pos.y -= 16;

					if([action isEqualToString:SPBundleOutputActionShowAsTextTooltip]) {
						[SPTooltip showWithObject:output atLocation:pos];
					}

					else if([action isEqualToString:SPBundleOutputActionShowAsHTMLTooltip]) {
						[SPTooltip showWithObject:output atLocation:pos ofType:@"html"];
					}

					else if([action isEqualToString:SPBundleOutputActionShowAsHTML]) {
						BOOL correspondingWindowFound = NO;
						for(id win in [NSApp windows]) {
							if([[win delegate] isKindOfClass:[SPBundleHTMLOutputController class]]) {
								if([[[win delegate] windowUUID] isEqualToString:[cmdData objectForKey:SPBundleFileUUIDKey]]) {
									correspondingWindowFound = YES;
									[[win delegate] setDocUUID:uuid];
									[[win delegate] displayHTMLContent:output withOptions:nil];
									break;
								}
							}
						}
						if(!correspondingWindowFound) {
							SPBundleHTMLOutputController *c = [[SPBundleHTMLOutputController alloc] init];
							[c setWindowUUID:[cmdData objectForKey:SPBundleFileUUIDKey]];
							[c setDocUUID:uuid];
							[c displayHTMLContent:output withOptions:nil];
							[[NSApp delegate] addHTMLOutputController:c];
						}
					}
				}
			} else if([err code] != 9) { // Suppress an error message if command was killed
				NSString *errorMessage  = [err localizedDescription];
				SPBeginAlertSheet(NSLocalizedString(@"BASH Error", @"bash error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [NSApp mainWindow], self, nil, nil,
								  [NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [cmdData objectForKey:@"name"], errorMessage]);
			}

		}

		if (cmdData) [cmdData release];

	}

}

/**
 * Return of certain shell variables mainly for usage in JavaScript support inside the 
 * HTML output window to allow to ask on run-time 
 */
- (NSDictionary*)shellEnvironmentForDocument:(NSString*)docUUID
{
	NSMutableDictionary *env = [NSMutableDictionary dictionary];
	SPDatabaseDocument *doc;
	if(docUUID == nil)
		doc = [self frontDocument];
	else {
		BOOL found = NO;
		for (NSWindow *aWindow in [NSApp orderedWindows]) {
			if([[aWindow windowController] isMemberOfClass:[SPWindowController class]]) {
				for(SPDatabaseDocument *d in [[aWindow windowController] documents]) {
					if([d processID] && [[d processID] isEqualToString:docUUID]) {
						[env addEntriesFromDictionary:[d shellVariables]];
						found = YES;
						break;
					}
				}
			}
			if(found) break;
		}
	}

	// if(doc && [doc shellVariables]) [env addEntriesFromDictionary:[doc shellVariables]];
	// if(doc) [doc release];
	id firstResponder = [[NSApp keyWindow] firstResponder];
	if([firstResponder respondsToSelector:@selector(executeBundleItemForInputField:)]) {
		BOOL selfIsQueryEditor = ([[[firstResponder class] description] isEqualToString:@"SPTextView"]) ;
		NSRange currentWordRange, currentSelectionRange, currentLineRange, currentQueryRange;
		currentSelectionRange = [firstResponder selectedRange];
		currentWordRange = [firstResponder getRangeForCurrentWord];
		currentLineRange = [[firstResponder string] lineRangeForRange:NSMakeRange([firstResponder selectedRange].location, 0)];

		if(selfIsQueryEditor) {
			currentQueryRange = [[firstResponder delegate] currentQueryRange];
		} else {
			currentQueryRange = currentLineRange;
		}
		if(!currentQueryRange.length)
			currentQueryRange = currentSelectionRange;

		[env setObject:SPBundleScopeInputField forKey:SPBundleShellVariableBundleScope];

		if(selfIsQueryEditor && [[firstResponder delegate] currentQueryRange].length)
			[env setObject:[[firstResponder string] substringWithRange:[[firstResponder delegate] currentQueryRange]] forKey:SPBundleShellVariableCurrentQuery];

		if(currentSelectionRange.length)
			[env setObject:[[firstResponder string] substringWithRange:currentSelectionRange] forKey:SPBundleShellVariableSelectedText];

		if(currentWordRange.length)
			[env setObject:[[firstResponder string] substringWithRange:currentWordRange] forKey:SPBundleShellVariableCurrentWord];

		if(currentLineRange.length)
			[env setObject:[[firstResponder string] substringWithRange:currentLineRange] forKey:SPBundleShellVariableCurrentLine];
	}
	else if([firstResponder respondsToSelector:@selector(executeBundleItemForDataTable:)]) {

		if([[firstResponder delegate] respondsToSelector:@selector(usedQuery)] && [[firstResponder delegate] usedQuery])
			[env setObject:[[firstResponder delegate] usedQuery] forKey:SPBundleShellVariableUsedQueryForTable];

		if([firstResponder numberOfSelectedRows]) {
			NSMutableArray *sel = [NSMutableArray array];
			NSIndexSet *selectedRows = [firstResponder selectedRowIndexes];
			NSUInteger rowIndex = [selectedRows firstIndex];
			while ( rowIndex != NSNotFound ) {
				[sel addObject:[NSString stringWithFormat:@"%ld", rowIndex]];
				rowIndex = [selectedRows indexGreaterThanIndex:rowIndex];
			}
			[env setObject:[sel componentsJoinedByString:@"\t"] forKey:SPBundleShellVariableSelectedRowIndices];
		}

		[env setObject:SPBundleScopeDataTable forKey:SPBundleShellVariableBundleScope];

	} else {
		[env setObject:SPBundleScopeGeneral forKey:SPBundleShellVariableBundleScope];
	}
	return env;
}

- (void)registerActivity:(NSDictionary*)commandDict
{
	[runningActivitiesArray addObject:commandDict];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:SPActivitiesUpdateNotification object:nil];
}

- (void)removeRegisteredActivity:(NSInteger)pid
{
	for(id cmd in runningActivitiesArray) {
		if([[cmd objectForKey:@"pid"] integerValue] == pid) {
			[runningActivitiesArray removeObject:cmd];
			break;
		}
	}
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:SPActivitiesUpdateNotification object:nil];
}

- (NSArray*)runningActivities
{
	return (NSArray*)runningActivitiesArray;
}

#pragma mark -
#pragma mark Window management

/**
 * Create a new window, containing a single tab.
 */
- (IBAction)newWindow:(id)sender
{
	static NSPoint cascadeLocation = {.x = 0, .y = 0};

	// Create a new window controller, and set up a new connection view within it.
	SPWindowController *newWindowController = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
	[newWindowController addNewConnection:self];
	NSWindow *newWindow = [newWindowController window];

	// Cascading defaults to on - retrieve the window origin automatically assigned by cascading,
	// and convert to a top left point.
	NSPoint topLeftPoint = [newWindow frame].origin;
	topLeftPoint.y += [newWindow frame].size.height;

	// The first window should use autosaving; subsequent windows should cascade.
	// So attempt to set the frame autosave name; this will succeed for the very
	// first window, and fail for others.
	BOOL usedAutosave = [newWindow setFrameAutosaveName:@"DBView"];
	if (!usedAutosave) {
		[newWindow setFrameUsingName:@"DBView"];
	}

	// Cascade according to the statically stored cascade location.
	cascadeLocation = [newWindow cascadeTopLeftFromPoint:cascadeLocation];

	// Set the window controller as the window's delegate
	[newWindow setDelegate:newWindowController];

	// Show the window, and perform frontmost tasks again once the window has drawn
	[newWindowController showWindow:self];
	[[newWindowController selectedTableDocument] didBecomeActiveTabInWindow];
}

/**
 * Create a new tab in the frontmost window.
 */
- (IBAction)newTab:(id)sender
{
	SPWindowController *frontController = nil;

	for (NSWindow *aWindow in [self orderedWindows]) {
		if ([[aWindow windowController] isMemberOfClass:[SPWindowController class]]) {
			frontController = [aWindow windowController];
			break;
		}
	}

	// If no window was found, create a new one
	if (!frontController) {
		[self newWindow:self];
	} else {
		if ([[frontController window] isMiniaturized]) [[frontController window] deminiaturize:self];
		[frontController addNewConnection:self];
	}
}

/**
 * Duplicate the current connection tab
 */
- (IBAction)duplicateTab:(id)sender
{
	SPDatabaseDocument *theFrontDocument = [self frontDocument];
	if (!theFrontDocument) return [self newTab:sender];

	// Add a new tab to the window
	if ([[self frontDocumentWindow] isMiniaturized]) [[self frontDocumentWindow] deminiaturize:self];
	[[[self frontDocumentWindow] windowController] addNewConnection:self];

	// Get the state of the previously-frontmost document
	NSDictionary *allStateDetails = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithBool:YES], @"connection",
										[NSNumber numberWithBool:YES], @"history",
										[NSNumber numberWithBool:YES], @"session",
										[NSNumber numberWithBool:YES], @"query",
										[NSNumber numberWithBool:YES], @"password",
										nil];
	NSMutableDictionary *theFrontState = [NSMutableDictionary dictionaryWithDictionary:[theFrontDocument stateIncludingDetails:allStateDetails]];

	// Ensure it's set to autoconnect
	[theFrontState setObject:[NSNumber numberWithBool:YES] forKey:@"auto_connect"];

	// Set the connection on the new tab
	[[self frontDocument] setState:theFrontState];
}

/**
 * Retrieve the frontmost document window; returns nil if not found.
 */
- (NSWindow *) frontDocumentWindow
{
	for (NSWindow *aWindow in [self orderedWindows]) {
		if ([[aWindow windowController] isMemberOfClass:[SPWindowController class]]) {
			return aWindow;
		}
	}

	return nil;
}

/**
 * When tab drags start, bring all the windows in front of other applications.
 */
- (void)tabDragStarted:(id)sender
{
	[NSApp arrangeInFront:self];
}

#pragma mark -
#pragma mark IBAction methods

/**
 * Opens the about panel.
 */
- (IBAction)openAboutPanel:(id)sender
{
	if (!aboutController) aboutController = [[SPAboutController alloc] init];
	
	[aboutController showWindow:self];
}

/**
 * Opens the preferences window.
 */
- (IBAction)openPreferences:(id)sender
{
	[prefsController showWindow:self];	
}

#pragma mark -
#pragma mark Accessors

/**
 * Provide a method to retrieve the prefs controller
 */
- (SPPreferenceController *)preferenceController
{
	return prefsController;
}

/**
 * Provide a method to retrieve an ordered list of the database
 * connection windows currently open in the application.
 */
- (NSArray *) orderedDatabaseConnectionWindows
{
	NSMutableArray *orderedDatabaseConnectionWindows = [NSMutableArray array];
	for (NSWindow *aWindow in [NSApp orderedWindows]) {
		if ([[aWindow windowController] isMemberOfClass:[SPWindowController class]]) [orderedDatabaseConnectionWindows addObject:aWindow];
	}
	return orderedDatabaseConnectionWindows;
}

/**
 * Retrieve the frontmost document; returns nil if not found.
 */
- (SPDatabaseDocument *) frontDocument
{
	for (NSWindow *aWindow in [self orderedWindows]) {
		if ([[aWindow windowController] isMemberOfClass:[SPWindowController class]]) {
			return [[aWindow windowController] selectedTableDocument];
		}
	}

	return nil;
}

/**
 * Retrieve the session URL. Return nil if no session is opened
 */
- (NSURL *)sessionURL
{
	return _sessionURL;
}

/**
 * Set the global session URL used for Save (As) Session.
 */
- (void)setSessionURL:(NSString *)urlString
{
	if(_sessionURL) [_sessionURL release], _sessionURL = nil;
	if(urlString)
		_sessionURL = [[NSURL fileURLWithPath:urlString] retain];
}

- (NSDictionary *)spfSessionDocData
{
	return _spfSessionDocData;
}

- (void)setSpfSessionDocData:(NSDictionary *)data
{
	[_spfSessionDocData removeAllObjects];
	if(data)
		[_spfSessionDocData addEntriesFromDictionary:data];
}

#pragma mark -
#pragma mark Services menu methods

/**
 * Passes the query to the frontmost document
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
	if (![self frontDocument]) {
		*error = @"No Documents open!";
		
		return;
	}
	
	// Pass query to front document
	[[self frontDocument] doPerformQueryService:pboardString];
	
	return;
}

#pragma mark -
#pragma mark Sequel Pro menu methods

/**
 * Opens donate link in default browser
 */
- (IBAction)donate:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SPDonationsURL]];
}

/**
 * Opens website link in default browser
 */
- (IBAction)visitWebsite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SPLOCALIZEDURL_HOMEPAGE]];
}

/**
 * Opens help link in default browser
 */
- (IBAction)visitHelpWebsite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SPLOCALIZEDURL_DOCUMENTATION]];
}

/**
 * Opens FAQ help link in default browser
 */
- (IBAction)visitFAQWebsite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SPLOCALIZEDURL_FAQ]];
}

/**
 * Opens the 'Contact the developers' page in the default browser
 */
- (IBAction)provideFeedback:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SPLOCALIZEDURL_CONTACT]];
}

/**
 * Opens the 'Translation Feedback' page in the default browser.
 */
- (IBAction)provideTranslationFeedback:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SPLOCALIZEDURL_TRANSLATIONFEEDBACK]];
}

/**
 * Opens the 'Keyboard Shortcuts' page in the default browser.
 */
- (IBAction)viewKeyboardShortcuts:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SPLOCALIZEDURL_KEYBOARDSHORTCUTS]];
}

- (IBAction)openBundleEditor:(id)sender
{
	if (!bundleEditorController) bundleEditorController = [[SPBundleEditorController alloc] init];

	[bundleEditorController showWindow:self];
}

- (void)addHTMLOutputController:(id)controller
{
	[bundleHTMLOutputController addObject:controller];
}

- (IBAction)reloadBundles:(id)sender
{

	for(id c in bundleHTMLOutputController) {
		if(![[c window] isVisible]) {
			[c release];
		}
	}

	BOOL foundInstalledBundles = NO;

	[bundleItems removeAllObjects];
	[bundleUsedScopes removeAllObjects];
	[bundleHTMLOutputController removeAllObjects];
	[bundleCategories removeAllObjects];
	[bundleTriggers removeAllObjects];
	[bundleKeyEquivalents removeAllObjects];
	[installedBundleUUIDs removeAllObjects];

	// Get main menu "Bundles"'s submenu
	NSMenu *menu = [[[NSApp mainMenu] itemWithTag:SPMainMenuBundles] submenu];

	// Clean menu
	[menu compatibleRemoveAllItems];

	NSArray *bundlePaths = [NSArray arrayWithObjects:
		([[NSFileManager defaultManager] applicationSupportDirectoryForSubDirectory:SPBundleSupportFolder createIfNotExists:NO error:nil])?:@"",
		[NSString stringWithFormat:@"%@/Contents/Resources/Default Bundles", [[NSBundle mainBundle] bundlePath]],
		nil];

	BOOL processDefaultBundles = NO;
	NSFileManager *fm = [NSFileManager defaultManager];
	
	NSArray *deletedDefaultBundles;
	NSMutableArray *updatedDefaultBundles = [NSMutableArray array];
	if([[NSUserDefaults standardUserDefaults] objectForKey:@"deletedDefaultBundles"]) {
		deletedDefaultBundles = [[[NSUserDefaults standardUserDefaults] objectForKey:@"deletedDefaultBundles"] retain];
	} else {
		deletedDefaultBundles = [[NSArray array] retain];
	}
	if([[NSUserDefaults standardUserDefaults] objectForKey:@"updatedDefaultBundles"]) {
		[updatedDefaultBundles setArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"updatedDefaultBundles"]];
	}

	for(NSString* bundlePath in bundlePaths) {
		if([bundlePath length]) {

			NSError *error = nil;
			NSArray *foundBundles = [fm contentsOfDirectoryAtPath:bundlePath error:&error];
			if (foundBundles && [foundBundles count] && error == nil) {

				for(NSString* bundle in foundBundles) {
					if(![[[bundle pathExtension] lowercaseString] isEqualToString:[SPUserBundleFileExtension lowercaseString]]) continue;

					foundInstalledBundles = YES;

					NSError *readError = nil;
					NSString *convError = nil;
					NSPropertyListFormat format;
					NSDictionary *cmdData = nil;
					NSString *infoPath = [NSString stringWithFormat:@"%@/%@/%@", bundlePath, bundle, SPBundleFileName];
					NSData *pData = [NSData dataWithContentsOfFile:infoPath options:NSUncachedRead error:&readError];

					cmdData = [[NSPropertyListSerialization propertyListFromData:pData 
							mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

					if(!cmdData || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {

						NSLog(@"“%@” file couldn't be read.", infoPath);
						NSBeep();

					} else {
						if((![cmdData objectForKey:SPBundleFileDisabledKey] || ![[cmdData objectForKey:SPBundleFileDisabledKey] intValue]) 
							&& [cmdData objectForKey:SPBundleFileNameKey] 
							&& [[cmdData objectForKey:SPBundleFileNameKey] length] 
							&& [cmdData objectForKey:SPBundleFileScopeKey])
						{

							if([cmdData objectForKey:SPBundleFileUUIDKey] && [[cmdData objectForKey:SPBundleFileUUIDKey] length]) {

								if(processDefaultBundles) {

									// Skip deleted default Bundles
									if([deletedDefaultBundles containsObject:[cmdData objectForKey:SPBundleFileUUIDKey]])
										continue;

									// If default Bundle is already install check for possible update,
									// if so duplicate the 'old one' by renaming it and change the UUID
									if([installedBundleUUIDs objectForKey:[cmdData objectForKey:SPBundleFileUUIDKey]]) {
										if([updatedDefaultBundles containsObject:[cmdData objectForKey:SPBundleFileUUIDKey]]) {
											NSString *oldPath = [NSString stringWithFormat:@"%@/%@/%@", [bundlePaths objectAtIndex:0], bundle, SPBundleFileName];
											NSError *readError = nil;
											NSString *convError = nil;
											NSPropertyListFormat format;
											NSDictionary *cmdData = nil;
											NSData *pData = [NSData dataWithContentsOfFile:oldPath options:NSUncachedRead error:&readError];
											cmdData = [[NSPropertyListSerialization propertyListFromData:pData 
													mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];
											if(!cmdData || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
												NSLog(@"“%@” file couldn't be read.", oldPath);
												NSBeep();
												continue;
											} else {
												// Check for modifications
												if([cmdData objectForKey:SPBundleFileDefaultBundleWasModifiedKey]) {
													
												} else {
													[fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@", [bundlePaths objectAtIndex:0], bundle]];
													[updatedDefaultBundles removeObject:[cmdData objectForKey:SPBundleFileUUIDKey]];
												}
											}
										} else {
											continue;
										}
									}

									BOOL isDir;
									NSString *newInfoPath = [NSString stringWithFormat:@"%@/%@/%@", [bundlePaths objectAtIndex:0], bundle, SPBundleFileName];
									if([fm fileExistsAtPath:newInfoPath isDirectory:&isDir] && isDir)
										newInfoPath = [NSString stringWithFormat:@"%@_%ld", newInfoPath, (NSUInteger)(random() % 35000)];
									NSError *error = nil;
									[fm moveItemAtPath:infoPath toPath:newInfoPath error:&error];
									if(error != nil) {
										NSBeep();
										NSLog(@"Default Bundle “%@” couldn't be moved to '%@'", bundle, newInfoPath);
										continue;
									}
									infoPath = [NSString stringWithString:newInfoPath];

								}

								[installedBundleUUIDs setObject:[NSDictionary dictionaryWithObjectsAndKeys:
										[NSString stringWithFormat:@"%@ (%@)", bundle, [cmdData objectForKey:SPBundleFileNameKey]], @"name",
										infoPath, @"path", nil] forKey:[cmdData objectForKey:SPBundleFileUUIDKey]];

							} else {
								NSLog(@"No UUID for %@", bundle);
								NSBeep();
								continue;
							}

							NSArray *scopes = [[cmdData objectForKey:SPBundleFileScopeKey] componentsSeparatedByString:@" "];
							for(NSString *scope in scopes) {

								if(![bundleUsedScopes containsObject:scope]) {
									[bundleUsedScopes addObject:scope];
									[bundleItems setObject:[NSMutableArray array] forKey:scope];
									[bundleCategories setObject:[NSMutableArray array] forKey:scope];
									[bundleKeyEquivalents setObject:[NSMutableDictionary dictionary] forKey:scope];
								}

								if([cmdData objectForKey:SPBundleFileCategoryKey] && [[cmdData objectForKey:SPBundleFileCategoryKey] length] && ![[bundleCategories objectForKey:scope] containsObject:[cmdData objectForKey:SPBundleFileCategoryKey]])
									[[bundleCategories objectForKey:scope] addObject:[cmdData objectForKey:SPBundleFileCategoryKey]];
							}

							NSMutableDictionary *aDict = [NSMutableDictionary dictionary];
							[aDict setObject:[cmdData objectForKey:SPBundleFileNameKey] forKey:SPBundleInternLabelKey];
							[aDict setObject:infoPath forKey:SPBundleInternPathToFileKey];

							// Register trigger
							if([cmdData objectForKey:SPBundleFileTriggerKey]) {
								if(![bundleTriggers objectForKey:[cmdData objectForKey:SPBundleFileTriggerKey]])
									[bundleTriggers setObject:[NSMutableArray array] forKey:[cmdData objectForKey:SPBundleFileTriggerKey]];
								[[bundleTriggers objectForKey:[cmdData objectForKey:SPBundleFileTriggerKey]] addObject:
									[NSString stringWithFormat:@"%@|%@|%@", 
										infoPath, 
										[cmdData objectForKey:SPBundleFileScopeKey], 
										([[cmdData objectForKey:SPBundleFileOutputActionKey] isEqualToString:SPBundleOutputActionShowAsHTML])?[cmdData objectForKey:SPBundleFileUUIDKey]:@""]];
							}

							if([cmdData objectForKey:SPBundleFileKeyEquivalentKey] && [[cmdData objectForKey:SPBundleFileKeyEquivalentKey] length]) {

								NSString *theKey = [cmdData objectForKey:SPBundleFileKeyEquivalentKey];
								NSString *theChar = [theKey substringFromIndex:[theKey length]-1];
								NSString *theMods = [theKey substringToIndex:[theKey length]-1];
								NSUInteger mask = 0;
								if([theMods rangeOfString:@"^"].length)
									mask = mask | NSControlKeyMask;
								if([theMods rangeOfString:@"@"].length)
									mask = mask | NSCommandKeyMask;
								if([theMods rangeOfString:@"~"].length)
									mask = mask | NSAlternateKeyMask;
								if([theMods rangeOfString:@"$"].length)
									mask = mask | NSShiftKeyMask;
								for(NSString* scope in scopes) {
									if(![[bundleKeyEquivalents objectForKey:scope] objectForKey:[cmdData objectForKey:SPBundleFileKeyEquivalentKey]])
										[[bundleKeyEquivalents objectForKey:scope] setObject:[NSMutableArray array] forKey:[cmdData objectForKey:SPBundleFileKeyEquivalentKey]];

									[[[bundleKeyEquivalents objectForKey:scope] objectForKey:[cmdData objectForKey:SPBundleFileKeyEquivalentKey]] addObject:
													[NSDictionary dictionaryWithObjectsAndKeys:
															infoPath, @"path",
															[cmdData objectForKey:SPBundleFileNameKey], @"title",
															([cmdData objectForKey:SPBundleFileTooltipKey]) ?: @"", @"tooltip",
													nil]];

								}

								[aDict setObject:[NSArray arrayWithObjects:theChar, [NSNumber numberWithInteger:mask], nil] forKey:SPBundleInternKeyEquivalentKey];
							}

							if([cmdData objectForKey:SPBundleFileTooltipKey] && [[cmdData objectForKey:SPBundleFileTooltipKey] length])
								[aDict setObject:[cmdData objectForKey:SPBundleFileTooltipKey] forKey:SPBundleFileTooltipKey];

							if([cmdData objectForKey:SPBundleFileCategoryKey] && [[cmdData objectForKey:SPBundleFileCategoryKey] length])
								[aDict setObject:[cmdData objectForKey:SPBundleFileCategoryKey] forKey:SPBundleFileCategoryKey];

							if([cmdData objectForKey:SPBundleFileKeyEquivalentKey] && [[cmdData objectForKey:SPBundleFileKeyEquivalentKey] length])
								[aDict setObject:[cmdData objectForKey:SPBundleFileKeyEquivalentKey] forKey:@"key"];

							for(NSString* scope in scopes)
								[[bundleItems objectForKey:scope] addObject:aDict];

						}

						if (cmdData) [cmdData release];

					}
				}

				NSSortDescriptor *sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:SPBundleInternLabelKey ascending:YES] autorelease];
				for(NSString* scope in [bundleItems allKeys]) {
					[[bundleItems objectForKey:scope] sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
					[[bundleCategories objectForKey:scope] sortUsingSelector:@selector(compare:)];
				}
			}
		}
		processDefaultBundles = YES;
	}

	[deletedDefaultBundles release];
	
	[[NSUserDefaults standardUserDefaults] setObject:updatedDefaultBundles forKey:@"updatedDefaultBundles"];

	// Rebuild Bundles main menu item

	// Add default menu items
	NSMenuItem *anItem;
	anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Bundle Editor", @"bundle editor menu item label") action:@selector(openBundleEditor:) keyEquivalent:@"b"];
	[anItem setKeyEquivalentModifierMask:(NSCommandKeyMask|NSAlternateKeyMask|NSControlKeyMask)];
	[menu addItem:anItem];
	[anItem release];
	anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Reload Bundles", @"reload bundles menu item label") action:@selector(reloadBundles:) keyEquivalent:@""];
	[menu addItem:anItem];
	[anItem release];

	// Bail out if no Bundle was installed
	if(!foundInstalledBundles) return;

	// Add installed Bundles
	// For each scope add a submenu but not for the last one (should be General always)
	[menu addItem:[NSMenuItem separatorItem]];
	[menu setAutoenablesItems:YES];
	NSArray *scopes = [NSArray arrayWithObjects:SPBundleScopeInputField, SPBundleScopeDataTable, SPBundleScopeGeneral, nil];
	NSArray *scopeTitles = [NSArray arrayWithObjects:NSLocalizedString(@"Input Field", @"input field menu item label"), 
													 NSLocalizedString(@"Data Table", @"data table menu item label"),
													 NSLocalizedString(@"General", @"general menu item label"),nil];

	NSArray *scopeSelector = [NSArray arrayWithObjects:@"executeBundleItemForInputField:", 
													   @"executeBundleItemForDataTable:", 
													   @"executeBundleItemForApp:", nil];

	NSInteger k = 0;
	BOOL bundleOtherThanGeneralFound = NO;
	for(NSString* scope in scopes) {

		NSArray *bundleCategories = [[NSApp delegate] bundleCategoriesForScope:scope];
		NSArray *bundleItems = [[NSApp delegate] bundleItemsForScope:scope];

		if(![bundleItems count]) {
			k++;
			continue;
		}

		NSMenu *bundleMenu = nil;
		NSMenuItem *bundleSubMenuItem = nil;

		// Add last scope (General) not as submenu
		if(k < [scopes count]-1) {
			bundleMenu = [[[NSMenu alloc] init] autorelease];
			[bundleMenu setAutoenablesItems:YES];
			bundleSubMenuItem = [[NSMenuItem alloc] initWithTitle:[scopeTitles objectAtIndex:k] action:nil keyEquivalent:@""];
			[bundleSubMenuItem setTag:10000000];

			[menu addItem:bundleSubMenuItem];
			[menu setSubmenu:bundleMenu forItem:bundleSubMenuItem];

		} else {
			bundleMenu = menu;
			if(bundleOtherThanGeneralFound)
				[menu addItem:[NSMenuItem separatorItem]];
		}

		// Add found Category submenus
		NSMutableArray *categorySubMenus = [NSMutableArray array];
		NSMutableArray *categoryMenus = [NSMutableArray array];
		if([bundleCategories count]) {
			for(NSString* title in bundleCategories) {
				[categorySubMenus addObject:[[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""] autorelease]];
				[categoryMenus addObject:[[[NSMenu alloc] init] autorelease]];
				[bundleMenu addItem:[categorySubMenus lastObject]];
				[bundleMenu setSubmenu:[categoryMenus lastObject] forItem:[categorySubMenus lastObject]];
			}
		}

		NSInteger i = 0;
		for(NSDictionary *item in bundleItems) {

			NSString *keyEq;
			if([item objectForKey:SPBundleFileKeyEquivalentKey])
				keyEq = [[item objectForKey:SPBundleFileKeyEquivalentKey] objectAtIndex:0];
			else
				keyEq = @"";

			NSMenuItem *mItem = [[[NSMenuItem alloc] initWithTitle:[item objectForKey:SPBundleInternLabelKey] action:@selector(bundleCommandDispatcher:) keyEquivalent:keyEq] autorelease];
			bundleOtherThanGeneralFound = YES;
			if([keyEq length])
				[mItem setKeyEquivalentModifierMask:[[[item objectForKey:SPBundleFileKeyEquivalentKey] objectAtIndex:1] intValue]];

			if([item objectForKey:SPBundleFileTooltipKey])
				[mItem setToolTip:[item objectForKey:SPBundleFileTooltipKey]];

			[mItem setTag:1000000 + i++];
			[mItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:
				scope, @"scope",
				([item objectForKey:@"key"])?:@"", @"key", nil]];

			if([item objectForKey:SPBundleFileCategoryKey]) {
				[[categoryMenus objectAtIndex:[bundleCategories indexOfObject:[item objectForKey:SPBundleFileCategoryKey]]] addItem:mItem];
			} else {
				[bundleMenu addItem:mItem];
			}
		}

		if(bundleSubMenuItem) [bundleSubMenuItem release];
		k++;
	}

}

/**
 * Action for any Bundle menu menuItem; show menuItem dialog if user pressed key equivalent
 * which is assigned to more than one bundle command inside the same scope
 */
- (IBAction)bundleCommandDispatcher:(id)sender
{

	NSEvent *event = [NSApp currentEvent];
	BOOL checkForKeyEquivalents = ([event type] == NSKeyDown) ? YES : NO;

	id firstResponder = [[NSApp mainWindow] firstResponder];

	NSString *scope = [[sender representedObject] objectForKey:@"scope"];
	NSString *keyEqKey = nil;
	NSMutableArray *assignedKeyEquivalents = nil;

	if(checkForKeyEquivalents) {

		// Get the current scope in order to find out which command with a specific key
		// should run
		if([firstResponder respondsToSelector:@selector(executeBundleItemForInputField:)])
			scope = SPBundleScopeInputField;
		else if([firstResponder respondsToSelector:@selector(executeBundleItemForDataTable:)])
			scope = SPBundleScopeDataTable;
		else
			scope = SPBundleScopeGeneral;

		keyEqKey = [[sender representedObject] objectForKey:@"key"];

		assignedKeyEquivalents = [NSMutableArray array];
		[assignedKeyEquivalents setArray:[[bundleKeyEquivalents objectForKey:scope] objectForKey:keyEqKey]];
		// Fall back to general scope and check for key
		if(![assignedKeyEquivalents count]) {
			scope = SPBundleScopeGeneral;
			[assignedKeyEquivalents setArray:[[bundleKeyEquivalents objectForKey:scope] objectForKey:keyEqKey]];
		}
		// Nothing found thus bail
		if(![assignedKeyEquivalents count]) {
			NSBeep();
			return;
		}

		// Sort if more than one found
		if([assignedKeyEquivalents count] > 1) {
			NSSortDescriptor *aSortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
			NSArray *sorted = [assignedKeyEquivalents sortedArrayUsingDescriptors:[NSArray arrayWithObject:aSortDescriptor]];
			[assignedKeyEquivalents setArray:sorted];
		}
	}

	if([scope isEqualToString:SPBundleScopeInputField] && [firstResponder respondsToSelector:@selector(executeBundleItemForInputField:)]) {
		if(checkForKeyEquivalents && [assignedKeyEquivalents count]) {
			NSInteger idx = 0;
			if([assignedKeyEquivalents count] > 1)
				idx = [SPChooseMenuItemDialog withItems:assignedKeyEquivalents atPosition:[NSEvent mouseLocation]];

			if(idx > -1) {
				NSArray *eq = [assignedKeyEquivalents objectAtIndex:idx];
				if(eq && [eq count]) {
					NSMenuItem *aMenuItem = [[[NSMenuItem alloc] init] autorelease];
					[aMenuItem setTag:0];
					[aMenuItem setToolTip:[eq objectForKey:@"path"]];
					[[[NSApp mainWindow] firstResponder] executeBundleItemForInputField:aMenuItem];
				}
			}
		} else {
			[firstResponder executeBundleItemForInputField:sender];
		}
	}
	else if([scope isEqualToString:SPBundleScopeDataTable] && [firstResponder respondsToSelector:@selector(executeBundleItemForDataTable:)]) {
		if(checkForKeyEquivalents && [assignedKeyEquivalents count]) {
			NSInteger idx = 0;
			if([assignedKeyEquivalents count] > 1)
				idx = [SPChooseMenuItemDialog withItems:assignedKeyEquivalents atPosition:[NSEvent mouseLocation]];

			if(idx > -1) {
				NSArray *eq = [assignedKeyEquivalents objectAtIndex:idx];
				if(eq && [eq count]) {
					NSMenuItem *aMenuItem = [[[NSMenuItem alloc] init] autorelease];
					[aMenuItem setTag:0];
					[aMenuItem setToolTip:[eq objectForKey:@"path"]];
					[[[NSApp mainWindow] firstResponder] executeBundleItemForDataTable:aMenuItem];
				}
			}
		} else {
			[firstResponder executeBundleItemForDataTable:sender];
		}
	}
	else if([scope isEqualToString:SPBundleScopeGeneral]) {
		if(checkForKeyEquivalents && [assignedKeyEquivalents count]) {
			NSInteger idx = 0;
			if([assignedKeyEquivalents count] > 1)
				idx = [SPChooseMenuItemDialog withItems:assignedKeyEquivalents atPosition:[NSEvent mouseLocation]];

			if(idx > -1) {
				NSArray *eq = [assignedKeyEquivalents objectAtIndex:idx];
				if(eq && [eq count]) {
					NSMenuItem *aMenuItem = [[[NSMenuItem alloc] init] autorelease];
					[aMenuItem setTag:0];
					[aMenuItem setToolTip:[eq objectForKey:@"path"]];
					[self executeBundleItemForApp:aMenuItem];
				}
			}
		} else {
			[self executeBundleItemForApp:sender];
		}
	} else {
		NSBeep();
	}
}

#pragma mark -
#pragma mark Feedback reporter delegate methods

/**
 * Anonymises the preferences dictionary before feedback submission
 */
- (NSMutableDictionary*)anonymizePreferencesForFeedbackReport:(NSMutableDictionary *)preferences
{
	[preferences removeObjectsForKeys:[NSArray arrayWithObjects:@"ContentFilters",
																@"favorites",
																@"lastSqlFileName",
																@"NSNavLastRootDirectory",
																@"openPath",
																@"queryFavorites",
																@"queryHistory",
																@"tableColumnWidths",
																@"savePath",
																@"NSRecentDocumentRecords",
																nil]];

	return preferences;
}

#pragma mark -
#pragma mark Other methods

/**
 * Override the default open-blank-document methods to automatically connect automatically opened windows
 * if the preference is set
 */
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{

	// Manually open a table document
	[self newWindow:self];

	// Set autoconnection if appropriate
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SPAutoConnectToDefault]) {
		[[self frontDocument] connect];
	}

	// Return NO to the automatic opening
	return NO;
}

/**
 * Implement this method to prevent the above being called in the case of a reopen (for example, clicking 
 * the dock icon) where we don't want the auto-connect to kick in. 
 */
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
	// Only create a new document (without auto-connect) when there are already no documents open.
	if (![self frontDocument]) {
		[self newWindow:self];
		return NO;
	}
	
	// Return YES to the automatic opening
	return YES;
}

/**
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
		|| [[[aPath pathExtension] lowercaseString] isEqualToString:SPFileExtensionSQL] 
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

- (NSArray *)bundleCategoriesForScope:(NSString*)scope
{
	return [bundleCategories objectForKey:scope];
}

- (NSArray *)bundleCommandsForTrigger:(NSString*)trigger
{
	return [bundleTriggers objectForKey:trigger];
}

- (NSArray *)bundleItemsForScope:(NSString*)scope
{
	return [bundleItems objectForKey:scope];
}

- (NSDictionary *)bundleKeyEquivalentsForScope:(NSString*)scope
{
	return [bundleKeyEquivalents objectForKey:scope];
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
 * If Sequel Pro is terminating kill all running BASH scripts and release all HTML output controller
 */
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{

	if(lastBundleBlobFilesDirectory != nil)
		[[NSFileManager defaultManager] removeItemAtPath:lastBundleBlobFilesDirectory error:nil];

	// Kill all registered BASH commands
	for (NSWindow *aWindow in [NSApp orderedWindows]) {
		if([[aWindow windowController] isMemberOfClass:[SPWindowController class]]) {
			for(SPDatabaseDocument *doc in [[aWindow windowController] documents]) {
				for(NSDictionary* cmd in [doc runningActivities]) {
					NSInteger pid = [[cmd objectForKey:@"pid"] intValue];
					NSTask *killTask = [[NSTask alloc] init];
					[killTask setLaunchPath:@"/bin/sh"];
					[killTask setArguments:[NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"kill -9 -%ld", pid], nil]];
					[killTask launch];
					[killTask waitUntilExit];
					[killTask release];
				}
			}
		}
	}
	for(NSDictionary* cmd in [self runningActivities]) {
		NSInteger pid = [[cmd objectForKey:@"pid"] intValue];
		NSTask *killTask = [[NSTask alloc] init];
		[killTask setLaunchPath:@"/bin/sh"];
		[killTask setArguments:[NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"kill -9 -%ld", pid], nil]];
		[killTask launch];
		[killTask waitUntilExit];
		[killTask release];
	}

	for(id c in bundleHTMLOutputController) {
		[c release];
	}

	return YES;

}

#pragma mark -

/**
 * Deallocate
 */
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if(bundleItems) [bundleItems release];
	if(bundleUsedScopes) [bundleUsedScopes release];
	if(bundleHTMLOutputController) [bundleHTMLOutputController release];
	if(bundleCategories) [bundleCategories release];
	if(bundleTriggers) [bundleTriggers release];
	if(bundleKeyEquivalents) [bundleKeyEquivalents release];
	if(installedBundleUUIDs) [installedBundleUUIDs release];
	if (runningActivitiesArray) [runningActivitiesArray release];

	[prefsController release], prefsController = nil;

	if (aboutController) [aboutController release], aboutController = nil;
	if (bundleEditorController) [bundleEditorController release], bundleEditorController = nil;

	if (_sessionURL) [_sessionURL release], _sessionURL = nil;
	if (_spfSessionDocData) [_spfSessionDocData release], _spfSessionDocData = nil;

	[super dealloc];
}

@end

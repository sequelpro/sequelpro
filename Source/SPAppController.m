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
#import "SPConstants.h"
#import "SPWindowController.h"

#import <PSMTabBar/PSMTabBarControl.h>
#import <Sparkle/Sparkle.h>

@implementation SPAppController

/**
 * Initialise the application's main controller, setting itself as the app delegate.
 */
- (id)init
{
	if ((self = [super init])) {
		_sessionURL = nil;
		_spfSessionDocData = [[NSMutableDictionary alloc] init];
		
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
}

/**
 * Initialisation stuff upon nib awakening
 */
- (void)awakeFromNib
{

	// Set up the prefs controller
	prefsController = [[SPPreferenceController alloc] init];
	aboutController = nil;

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

			[[self frontDocument] initWithConnectionFile:filename];
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
								[[self frontDocument] initWithConnectionFile:fileName];
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
			NSString *themePath = [[NSString stringWithString:@"~/Library/Application Support/Sequel Pro/Themes"] stringByExpandingTildeInPath];
			if(![fm fileExistsAtPath:themePath isDirectory:nil]) {
				if(![fm createDirectoryAtPath:themePath withIntermediateDirectories:YES attributes:nil error:nil]) {
					NSBeep();
					return;
				}
			}
			NSString *newPath = [NSString stringWithFormat:@"%@/%@", themePath, [filename lastPathComponent]];
			if(![fm fileExistsAtPath:newPath isDirectory:nil]) {
				if(![fm copyItemAtPath:filename toPath:newPath error:nil]) {
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
		else {
			NSLog(@"Only files with the extensions ‘%@’, ‘%@’, ‘%@’ or ‘%@’ are allowed.", SPFileExtensionDefault, SPBundleFileExtension, SPColorThemeFileExtension, SPFileExtensionSQL);
		}
	}
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

#pragma mark -
#pragma mark AppleScript support

//////////////// Examples to catch AS core events - maybe for further stuff
// - (void)handleQuitEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
// {
// 	[NSApp terminate:self];
// }
// - (void)handleOpenEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
// {
// 	NSLog(@"OPEN %@", [event description]);
// }
// 
// - (void)applicationWillFinishLaunching:(NSNotification *)aNotification
// {
// 	NSAppleEventManager *aeManager = [NSAppleEventManager sharedAppleEventManager];
// 	[aeManager setEventHandler:self andSelector:@selector(handleQuitEvent:withReplyEvent:) forEventClass:kCoreEventClass andEventID:kAEQuitApplication];
// 	[aeManager setEventHandler:self andSelector:@selector(handleOpenEvent:withReplyEvent:) forEventClass:kCoreEventClass andEventID:kAEOpenApplication];
// }
// 

/**
 * Is needed to interact with AppleScript for set/get internal SP variables
 */
- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key
{
	NSLog(@"Not yet implemented.");
	
	return NO;
}

/**
 * AppleScript calls that method to get the available documents
 */
- (NSArray *)orderedDocuments
{
	NSMutableArray *orderedDocuments = [NSMutableArray array];

	for (NSWindow *aWindow in [self orderedWindows]) {
		if ([[aWindow windowController] isMemberOfClass:[SPWindowController class]]) {
			[orderedDocuments addObjectsFromArray:[[aWindow windowController] documents]];
		}
	}

	return orderedDocuments;
}

/** 
 * Support for 'make new document'.
 * TODO: following tab support this has been disabled - need to discuss reimplmenting vs syntax.
 */
- (void)insertInOrderedDocuments:(SPDatabaseDocument *)doc 
{
	[self newWindow:self];
/*	if ([[NSUserDefaults standardUserDefaults] boolForKey:SPAutoConnectToDefault])
		[doc setShouldAutomaticallyConnect:YES];
	
	[[NSDocumentController sharedDocumentController] addDocument:doc];
	[doc makeWindowControllers];
	[doc showWindows];*/
}

/**
 * AppleScript calls that method to get the available windows.
 */
- (NSArray *)orderedWindows
{
	return [NSApp orderedWindows];
}

/**
 * AppleScript handler to quit Sequel Pro
 * This handler is needed to allow to quit SP via the Dock or AppleScript after activating it by using AppleScript
 */
- (id)handleQuitScriptCommand:(NSScriptCommand *)command
{
	[NSApp terminate:self];
	return nil;
}

#pragma mark -

/**
 * Deallocate
 */
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if(_spfSessionDocData) [_spfSessionDocData release], _spfSessionDocData = nil;
	[prefsController release], prefsController = nil;
	[aboutController release], aboutController = nil;
	if(_sessionURL) [_sessionURL release], _sessionURL = nil;
	[super dealloc];
}

@end

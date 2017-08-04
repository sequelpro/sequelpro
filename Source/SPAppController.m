//
//  SPAppController.m
//  sequel-pro
//
//  Created by Lorenz Textor (lorenz@textor.ch) on May 1, 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  Copyright (c) 2012 Sequel Pro Team. All rights reserved.
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
#import "SPFavoritesController.h"
#import "SPEditorTokens.h"
#import "SPBundleCommandRunner.h"
#import "SPWindowManagement.h"
#import "SPCopyTable.h"
#import "SPSyntaxParser.h"
#import "SPOSInfo.h"

#import <PSMTabBar/PSMTabBarControl.h>
#import <Sparkle/Sparkle.h>

@interface SPAppController ()

- (void)_copyDefaultThemes;

- (void)openConnectionFileAtPath:(NSString *)filePath;
- (void)openSQLFileAtPath:(NSString *)filePath;
- (void)openSessionBundleAtPath:(NSString *)filePath;
- (void)openColorThemeFileAtPath:(NSString *)filePath;
- (void)openUserBundleAtPath:(NSString *)filePath;

@end

@implementation SPAppController

@synthesize lastBundleBlobFilesDirectory;

#pragma mark -
#pragma mark Initialisation

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
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	NSMutableDictionary *preferenceDefaults = [NSMutableDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:SPPreferenceDefaultsFile ofType:@"plist"]];

	if (![prefs objectForKey:SPGlobalResultTableFont]) {
		[preferenceDefaults setObject:[NSArchiver archivedDataWithRootObject:[NSFont systemFontOfSize:11]] forKey:SPGlobalResultTableFont];
	}

	// Register application defaults
	[prefs registerDefaults:preferenceDefaults];
						
	// Upgrade prefs before any other parts of the app pick up on the values
	SPApplyRevisionChanges();
}

/**
 * Initialisation stuff upon nib awakening
 */
- (void)awakeFromNib
{
	// Register url scheme handle
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self
													   andSelector:@selector(handleEvent:withReplyEvent:)
													 forEventClass:kInternetEventClass
														andEventID:kAEGetURL];

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

}

/**
 * Initialisation stuff after launch is complete
 */
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	NSDictionary *spfDict = nil;
	NSArray *args = [[NSProcessInfo processInfo] arguments];
	if (args.count == 5) {
		if (([[args objectAtIndex:1] isEqualToString:@"--spfData"] && [[args objectAtIndex:3] isEqualToString:@"--dataVersion"] && [[args objectAtIndex:4] isEqualToString:@"1"]) || ([[args objectAtIndex:3] isEqualToString:@"--spfData"] && [[args objectAtIndex:1] isEqualToString:@"--dataVersion"] && [[args objectAtIndex:2] isEqualToString:@"1"])) {
			NSData* data = [[args objectAtIndex:2] dataUsingEncoding:NSUTF8StringEncoding];
			NSError *error = nil;
			spfDict = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:&error];
			if (error) {
				spfDict = nil;
			}
		}
	}
	
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(externalApplicationWantsToOpenADatabaseConnection:) name:@"ExternalApplicationWantsToOpenADatabaseConnection" object:nil];
	
	// Set ourselves as the crash reporter delegate
	[[FRFeedbackReporter sharedReporter] setDelegate:self];

	// Report any crashes
	[[FRFeedbackReporter sharedReporter] reportIfCrash];

	[self reloadBundles:self];
    [self _copyDefaultThemes];

	// If no documents are open, open one
	if (![self frontDocument]) {
		SPDatabaseDocument *newConnection = [self makeNewConnectionTabOrWindow];
		
		if (spfDict) {
			[newConnection setState:spfDict];
		}
		
		// Set autoconnection if appropriate
		if ([[NSUserDefaults standardUserDefaults] boolForKey:SPAutoConnectToDefault]) {
			[newConnection connect];
		}
	}
}


- (void)externalApplicationWantsToOpenADatabaseConnection:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];
	NSString *MAMP_SPFVersion = [userInfo objectForKey:@"dataVersion"];
	if ([MAMP_SPFVersion isEqualToString:@"1"]) {
		NSDictionary *spfStructure = [userInfo objectForKey:@"spfData"];
		if (spfStructure) {
			SPDatabaseDocument *frontDoc = [self makeNewConnectionTabOrWindow];
			[frontDoc setState:spfStructure];
		}
	}
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
		if([[[[[sender URL] path] pathExtension] lowercaseString] isEqualToString:SPFileExtensionSQL]) {
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
	if (encodingPopUp) {
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
	if (![[NSUserDefaults standardUserDefaults] integerForKey:SPLastSQLFileEncoding]) {
		[[NSUserDefaults standardUserDefaults] setInteger:4 forKey:SPLastSQLFileEncoding];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}

	[panel setAccessoryView:[SPEncodingPopupAccessory encodingAccessory:[[NSUserDefaults standardUserDefaults] integerForKey:SPLastSQLFileEncoding] 
			includeDefaultEntry:NO encodingPopUp:&encodingPopUp]];

	// it will enabled if user selects a *.sql file
	[encodingPopUp setEnabled:NO];

	[panel setAllowedFileTypes:@[SPFileExtensionDefault, SPFileExtensionSQL, SPBundleFileExtension]];

	// Check if at least one document exists, if so show a sheet
	if ([self frontDocumentWindow]) {

		[panel beginSheetModalForWindow:[self frontDocumentWindow] completionHandler:^(NSInteger returnCode) {
			if (returnCode) {
				[panel orderOut:self];

				NSMutableArray *filePaths = [NSMutableArray arrayWithCapacity:[[panel URLs] count]];

				[[panel URLs] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
				{
					[filePaths addObject:[obj path]];
				}];

				[self application:NSApp openFiles:filePaths];
			}
		}];
	} 
	else {
		NSInteger returnCode = [panel runModal];

		if (returnCode) {
			NSMutableArray *filePaths = [NSMutableArray arrayWithCapacity:[[panel URLs] count]];

			[[panel URLs] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
			{
				 [filePaths addObject:[obj path]];
			}];

			[self application:NSApp openFiles:filePaths];
		}
	}

	encodingPopUp = nil;
}

/**
 * Called if user drag and drops files on Sequel Pro's dock item or double-clicked
 * at files *.spf or *.sql
 */
- (void)application:(NSApplication *)app openFiles:(NSArray *)filenames
{
	for (NSString *filePath in filenames)
	{
		NSString *fileExt = [[filePath pathExtension] lowercaseString];
		// Opens a sql file and insert its content into the Custom Query editor
		if ([fileExt isEqualToString:[SPFileExtensionSQL lowercaseString]]) {
			[self openSQLFileAtPath:filePath];
			break; // open only the first SQL file
		}
		else if ([fileExt isEqualToString:[SPFileExtensionDefault lowercaseString]]) {
			[self openConnectionFileAtPath:filePath];
		}
		else if ([fileExt isEqualToString:[SPBundleFileExtension lowercaseString]]) {
			[self openSessionBundleAtPath:filePath];
		}
		else if ([fileExt isEqualToString:[SPColorThemeFileExtension lowercaseString]]) {
			[self openColorThemeFileAtPath:filePath];
		}
		else if ([fileExt isEqualToString:[SPUserBundleFileExtension lowercaseString]]) {
			[self openUserBundleAtPath:filePath];
		}
		else {
			NSBeep();
			NSLog(@"Only files with the extensions ‘%@’, ‘%@’, ‘%@’ or ‘%@’ are allowed.", SPFileExtensionDefault, SPBundleFileExtension, SPColorThemeFileExtension, SPFileExtensionSQL);
		}
	}
}

- (void)openConnectionFileAtPath:(NSString *)filePath
{
	SPDatabaseDocument *frontDocument = [self makeNewConnectionTabOrWindow];
	
	[frontDocument setStateFromConnectionFile:filePath];
	
	[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:filePath]];
}

- (void)openSQLFileAtPath:(NSString *)filePath
{
	// Check size and NSFileType
	NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
	
	SPDatabaseDocument *frontDocument = [self frontDocument];
	
	if (attr)
	{
		NSNumber *filesize = [attr objectForKey:NSFileSize];
		NSString *filetype = [attr objectForKey:NSFileType];
		if(filetype == NSFileTypeRegular && filesize)
		{
			// Ask for confirmation if file content is larger than 1MB
			if ([filesize unsignedLongValue] > 1000000)
			{
				NSAlert *alert = [[NSAlert alloc] init];
				[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
				[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
				
				// Show 'Import' button only if there's a connection available
				if ([self frontDocument])
					[alert addButtonWithTitle:NSLocalizedString(@"Import", @"import button")];
				
				
				[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Do you really want to load a SQL file with %@ of data into the Query Editor?", @"message of panel asking for confirmation for loading large text into the query editor"),
										   [NSString stringForByteSize:[filesize longLongValue]]]];
				
				[alert setHelpAnchor:filePath];
				[alert setMessageText:NSLocalizedString(@"Warning",@"warning")];
				[alert setAlertStyle:NSWarningAlertStyle];
				
				NSUInteger returnCode = [alert runModal];
				
				[alert release];
				
				if(returnCode == NSAlertSecondButtonReturn) return; // Cancel
				else if(returnCode == NSAlertThirdButtonReturn) {   // Import
					// begin import process
					[[frontDocument valueForKeyPath:@"tableDumpInstance"] startSQLImportProcessWithFile:filePath];
					return;
				}
			}
		}
	}
	
	// Attempt to open the file into a string.
	NSStringEncoding sqlEncoding;
	NSString *sqlString = nil;
	
	// If the user came from an openPanel use the chosen encoding
	if (encodingPopUp) {
		sqlEncoding = [[encodingPopUp selectedItem] tag];
		
		// Otherwise, attempt to autodetect the encoding
	}
	else {
		sqlEncoding = [[NSFileManager defaultManager] detectEncodingforFileAtPath:filePath];
	}
	
	NSError *error = nil;
	
	sqlString = [NSString stringWithContentsOfFile:filePath encoding:sqlEncoding error:&error];
	
	if (error != nil) {
		NSAlert *errorAlert = [NSAlert alertWithError:error];
		[errorAlert runModal];
		
		return;
	}
	
	// if encodingPopUp is defined the filename comes from an openPanel and
	// the encodingPopUp contains the chosen encoding; otherwise autodetect encoding
	if (encodingPopUp) {
		[[NSUserDefaults standardUserDefaults] setInteger:[[encodingPopUp selectedItem] tag] forKey:SPLastSQLFileEncoding];
	}
	
	// Check if at least one document exists.  If not, open one.
	if (!frontDocument) {
		frontDocument = [self makeNewConnectionTabOrWindow];
		[frontDocument initQueryEditorWithString:sqlString];
	}
	else {
		// Pass query to the Query editor of the current document
		[frontDocument doPerformLoadQueryService:sqlString];
	}
	
	[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:filePath]];
	
	[frontDocument setSqlFileURL:[NSURL fileURLWithPath:filePath]];
	[frontDocument setSqlFileEncoding:sqlEncoding];
}

- (void)openSessionBundleAtPath:(NSString *)filePath
{
	NSError *readError = nil;
	NSString *convError = nil;
	NSPropertyListFormat format;
	NSDictionary *spfs = nil;
	NSData *pData = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/info.plist", filePath] options:NSUncachedRead error:&readError];
	
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
		[SPAppDelegate setSpfSessionDocData:spfsDocData];
		[SPAppDelegate setSessionURL:filePath];
		
		// Loop through each defined window in reversed order to reconstruct the last active window
		for (NSDictionary *window in [[[spfs objectForKey:@"windows"] reverseObjectEnumerator] allObjects])
		{
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
			
			if ([window objectForKey:@"frame"])
			{
				[newWindow setFrame:NSRectFromString([window objectForKey:@"frame"]) display:NO];
			}
			
			// Set the window controller as the window's delegate
			[newWindow setDelegate:newWindowController];
			
			usleep(1000);
			
			// Show the window
			[newWindowController showWindow:self];
			
			// Loop through all defined tabs for each window
			for (NSDictionary *tab in [window objectForKey:@"tabs"])
			{
				NSString *fileName = nil;
				BOOL isBundleFile = NO;
				
				// If isAbsolutePath then take this path directly
				// otherwise construct the releative path for the passed spfs file
				if ([[tab objectForKey:@"isAbsolutePath"] boolValue]) {
					fileName = [tab objectForKey:@"path"];
				}
				else {
					fileName = [NSString stringWithFormat:@"%@/Contents/%@", filePath, [tab objectForKey:@"path"]];
					isBundleFile = YES;
				}
				
				// Security check if file really exists
				if ([fileManager fileExistsAtPath:fileName]) {
					
					// Add new the tab
					if(newWindowController) {
						
						if ([[newWindowController window] isMiniaturized]) [[newWindowController window] deminiaturize:self];
						SPDatabaseDocument *newConnection = [newWindowController addNewConnection];
						
						[newConnection setIsSavedInBundle:isBundleFile];
						if (![newConnection setStateFromConnectionFile:fileName]) {
							break;
						}
					}
					
				}
				else {
					NSLog(@"Bundle file “%@” does not exists", fileName);
					NSBeep();
				}
			}
			
			// Select active tab
			[newWindowController selectTabAtIndex:[[window objectForKey:@"selectedTabIndex"] intValue]];
			
			// Reset setHideForSingleTab
			if ([[NSUserDefaults standardUserDefaults] objectForKey:SPAlwaysShowWindowTabBar]) {
				[newWindowController setHideForSingleTab:[[NSUserDefaults standardUserDefaults] boolForKey:SPAlwaysShowWindowTabBar]];
			}
			else {
				[newWindowController setHideForSingleTab:YES];
			}
		}
	}
	
	[spfs release];
	
	[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:filePath]];
}

- (void)openColorThemeFileAtPath:(NSString *)filePath
{
	NSFileManager *fm = [NSFileManager defaultManager];
	
	NSString *themePath = [[NSFileManager defaultManager] applicationSupportDirectoryForSubDirectory:SPThemesSupportFolder error:nil];
	
	if (!themePath) return;
	
	if (![fm fileExistsAtPath:themePath isDirectory:nil]) {
		if (![fm createDirectoryAtPath:themePath withIntermediateDirectories:YES attributes:nil error:nil]) {
			NSBeep();
			return;
		}
	}
	
	NSString *newPath = [NSString stringWithFormat:@"%@/%@", themePath, [filePath lastPathComponent]];
	
	if (![fm fileExistsAtPath:newPath isDirectory:nil]) {
		if (![fm moveItemAtPath:filePath toPath:newPath error:nil]) {
			NSBeep();
			return;
		}
	}
	else {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while installing color theme file", @"error while installing color theme file")]
										 defaultButton:NSLocalizedString(@"OK", @"OK button")
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"The color theme ‘%@’ already exists.", @"the color theme ‘%@’ already exists."), [filePath lastPathComponent]];
		
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		
		return;
	}
}

- (void)openUserBundleAtPath:(NSString *)filePath
{
	NSFileManager *fm = [NSFileManager defaultManager];
	
	NSString *bundlePath = [fm applicationSupportDirectoryForSubDirectory:SPBundleSupportFolder error:nil];
	
	if (!bundlePath) return;
	
	if (![fm fileExistsAtPath:bundlePath isDirectory:nil]) {
		if (![fm createDirectoryAtPath:bundlePath withIntermediateDirectories:YES attributes:nil error:nil]) {
			NSBeep();
			NSLog(@"Couldn't create folder “%@”", bundlePath);
			return;
		}
	}
	
	NSString *newPath = [NSString stringWithFormat:@"%@/%@", bundlePath, [filePath lastPathComponent]];
	
	NSError *readError = nil;
	NSString *convError = nil;
	NSPropertyListFormat format;
	NSDictionary *cmdData = nil;
	NSString *infoPath = [NSString stringWithFormat:@"%@/%@", filePath, SPBundleFileName];
	NSData *pData = [NSData dataWithContentsOfFile:infoPath options:NSUncachedRead error:&readError];
	
	cmdData = [[NSPropertyListSerialization propertyListFromData:pData
												mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];
	
	if (!cmdData || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
		NSLog(@"“%@/%@” file couldn't be read.", filePath, SPBundleFileName);
		NSBeep();
		if (cmdData) [cmdData release];
		return;
	}
	else {
		// Check for installed UUIDs
		if (![cmdData objectForKey:SPBundleFileUUIDKey]) {
			NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while installing Bundle", @"Open Files : Bundle : UUID : Error dialog title")]
											 defaultButton:NSLocalizedString(@"OK", @"Open Files : Bundle : UUID : OK button")
										   alternateButton:nil
											   otherButton:nil
								 informativeTextWithFormat:NSLocalizedString(@"The Bundle ‘%@’ has no UUID which is necessary to identify installed Bundles.", @"Open Files : Bundle: UUID : UUID-Attribute is missing in bundle's command.plist file"), [filePath lastPathComponent]];
			
			[alert setAlertStyle:NSCriticalAlertStyle];
			[alert runModal];
			if (cmdData) [cmdData release];
			return;
		}
		
		// Reload Bundles if Sequel Pro didn't run
		if (![installedBundleUUIDs count]) {
			[self reloadBundles:self];
		}
		
		if ([[installedBundleUUIDs allKeys] containsObject:[cmdData objectForKey:SPBundleFileUUIDKey]]) {
			NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Installing Bundle", @"Open Files : Bundle : Already-Installed : 'Update Bundle' question dialog title")]
											 defaultButton:NSLocalizedString(@"Update", @"Open Files : Bundle : Already-Installed : Update button")
										   alternateButton:NSLocalizedString(@"Cancel", @"Open Files : Bundle : Already-Installed : Cancel button")
											   otherButton:nil
								 informativeTextWithFormat:NSLocalizedString(@"A Bundle ‘%@’ is already installed. Do you want to update it?", @"Open Files : Bundle : Already-Installed : 'Update Bundle' question dialog message"), [[installedBundleUUIDs objectForKey:[cmdData objectForKey:SPBundleFileUUIDKey]] objectForKey:@"name"]];
			
			[alert setAlertStyle:NSCriticalAlertStyle];
			NSInteger answer = [alert runModal];
			
			if (answer == NSAlertDefaultReturn) {
				NSError *error = nil;
				NSString *removePath = [[[installedBundleUUIDs objectForKey:[cmdData objectForKey:SPBundleFileUUIDKey]] objectForKey:@"path"] substringToIndex:([(NSString *)[[installedBundleUUIDs objectForKey:[cmdData objectForKey:SPBundleFileUUIDKey]] objectForKey:@"path"] length]-[SPBundleFileName length]-1)];
				NSString *moveToTrashCommand = [NSString stringWithFormat:@"osascript -e 'tell application \"Finder\" to move (POSIX file \"%@\") to the trash'", removePath];
				
				[SPBundleCommandRunner runBashCommand:moveToTrashCommand withEnvironment:nil atCurrentDirectoryPath:nil error:&error];
				
				if (error != nil) {
					alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while moving “%@” to Trash.", @"Open Files : Bundle : Already-Installed : Delete-Old-Error : Could not delete old bundle before installing new version."), removePath]
											defaultButton:NSLocalizedString(@"OK", @"Open Files : Bundle : Already-Installed : Delete-Old-Error : OK button")
										  alternateButton:nil
											  otherButton:nil
								informativeTextWithFormat:@"%@", [error localizedDescription]];
					
					[alert setAlertStyle:NSCriticalAlertStyle];
					[alert runModal];
					if (cmdData) [cmdData release];
					return;
				}
			}
			else {
				if (cmdData) [cmdData release];
				
				return;
			}
		}
	}
	
	if (cmdData) [cmdData release];
	
	if (![fm fileExistsAtPath:newPath isDirectory:nil]) {
		if (![fm moveItemAtPath:filePath toPath:newPath error:nil]) {
			NSBeep();
			NSLog(@"Couldn't move “%@” to “%@”", filePath, newPath);
			return;
		}
		
		// Update Bundle Editor if it was already initialized
		for (NSWindow *win in [NSApp windows])
		{
			if ([[win delegate] class] == [SPBundleEditorController class]) {
				[((SPBundleEditorController *)[win delegate]) reloadBundles:nil];
				break;
			}
		}
		
		// Update Bundels' menu
		[self reloadBundles:self];
		
	}
	else {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while installing Bundle", @"Open Files : Bundle : Install-Error : error dialog title")]
										 defaultButton:NSLocalizedString(@"OK", @"Open Files : Bundle : Install-Error : OK button")
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"The Bundle ‘%@’ already exists.", @"Open Files : Bundle : Install-Error : Destination path already exists error dialog message"), [filePath lastPathComponent]];
		
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
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

	if ([[url scheme] isEqualToString:@"sequelpro"]) {
		[self handleEventWithURL:url];
	}
	else if([[url scheme] isEqualToString:@"mysql"]) {
		[self handleMySQLConnectWithURL:url];
	}
	else {
		NSBeep();
		NSLog(@"Error in sequelpro URL scheme for URL <%@>",url);
	}
}

- (void)handleMySQLConnectWithURL:(NSURL *)url
{
	if(![[url scheme] isEqualToString:@"mysql"]) {
		SPLog(@"unsupported url scheme: %@",url);
		return;
	}
	
	// make connection window
	SPDatabaseDocument *doc = [self makeNewConnectionTabOrWindow];

	NSMutableDictionary *details = [NSMutableDictionary dictionary];
	
	NSValue *connect = @NO;
	
	[details setObject:@"SPTCPIPConnection" forKey:@"type"];
	if([url port])
		[details setObject:[url port] forKey:@"port"];
	
	if([url user])
		[details setObject:[url user] forKey:@"user"];
	
	if([url password]) {
		[details setObject:[url password] forKey:@"password"];
		connect = @YES;
	}
	
	if([[url host] length] && ![[url host] isEqualToString:@"localhost"])
		[details setObject:[url host] forKey:@"host"];
	else
		[details setObject:@"127.0.0.1" forKey:@"host"];
	
	NSArray *pc = [url pathComponents];
	if([pc count] > 1) // first object is "/"
		[details setObject:[pc objectAtIndex:1] forKey:@"database"];
	
	[doc setState:@{@"connection":details,@"auto_connect": connect} fromFile:NO];
}

- (void)handleEventWithURL:(NSURL*)url
{
	NSString *command = [url host];
	NSString *passedProcessID = [url user];
	NSArray *parameter;
	NSArray *pathComponents;
	if([[url absoluteString] hasSuffix:@"/"])
		pathComponents = [[[url absoluteString] substringToIndex:[[url absoluteString] length]-1] pathComponents];
	else
		pathComponents = [[url absoluteString] pathComponents];
	
	// remove percent encoding
	NSMutableArray *decodedPathComponents = [NSMutableArray arrayWithCapacity:pathComponents.count];
	for (NSString *component in pathComponents) {
		NSString *decoded;
		if([SPOSInfo isOSVersionAtLeastMajor:10 minor:9 patch:0]) {
			decoded = [component stringByRemovingPercentEncoding];
		}
		else {
			decoded = [component stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		}
		[decodedPathComponents addObject:decoded];
	}
	pathComponents = decodedPathComponents.copy;
	
	if([pathComponents count] > 2)
		parameter = [pathComponents subarrayWithRange:NSMakeRange(2, [pathComponents count]-2)];
	else
		parameter = @[];


	NSFileManager *fm = [NSFileManager defaultManager];

	// Handle commands which don't need a connection window
	if([command isEqualToString:@"chooseItemFromList"]) {
		NSString *statusFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultStatusPathHeader, (passedProcessID && [passedProcessID length]) ? passedProcessID : @""];
		NSString *resultFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultPathHeader, (passedProcessID && [passedProcessID length]) ? passedProcessID : @""];
		[fm removeItemAtPath:statusFileName error:nil];
		[fm removeItemAtPath:resultFileName error:nil];
		NSString *result = @"";
		NSString *status = @"0";
		if([parameter count]) {
			NSInteger idx = [SPChooseMenuItemDialog withItems:parameter atPosition:[NSEvent mouseLocation]];
			if(idx > -1) {
				result = [parameter objectAtIndex:idx];
			}
		}
		if(![status writeToFile:statusFileName atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
			NSBeep();
			SPOnewayAlertSheet(NSLocalizedString(@"BASH Error", @"bash error"), [self frontDocumentWindow], NSLocalizedString(@"Status file for sequelpro url scheme command couldn't be written!", @"status file for sequelpro url scheme command couldn't be written error message"));
		}
		[result writeToFile:resultFileName atomically:YES encoding:NSUTF8StringEncoding error:nil];
		return;
	}

	if([command isEqualToString:@"SyntaxHighlighting"]) {

		BOOL isDir;

		NSString *anUUID = (passedProcessID && [passedProcessID length]) ? passedProcessID : @"";
		NSString *queryFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryInputPathHeader, anUUID];
		NSString *resultFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultPathHeader, anUUID];
		NSString *metaFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultMetaPathHeader, anUUID];
		NSString *statusFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultStatusPathHeader, anUUID];

		NSError *inError = nil;
		NSString *query = [NSString stringWithContentsOfFile:queryFileName encoding:NSUTF8StringEncoding error:&inError];
		NSString *result = @"";
		NSString *status = @"0";

		if([fm fileExistsAtPath:queryFileName isDirectory:&isDir] && !isDir) {

			if(inError == nil && query && [query length]) {
				if([parameter count] > 0) {
					if([[parameter lastObject] isEqualToString:@"html"])
						result = [NSString stringWithString:[self doSQLSyntaxHighlightForString:query cssLike:NO]];
					else if([[parameter lastObject] isEqualToString:@"htmlcss"])
						result = [NSString stringWithString:[self doSQLSyntaxHighlightForString:query cssLike:YES]];
				}
			}
		}

		[fm removeItemAtPath:queryFileName error:nil];
		[fm removeItemAtPath:resultFileName error:nil];
		[fm removeItemAtPath:metaFileName error:nil];
		[fm removeItemAtPath:statusFileName error:nil];

		if(![result writeToFile:resultFileName atomically:YES encoding:NSUTF8StringEncoding error:nil])
			status = @"1";

		// write status file as notification that query was finished
		BOOL succeed = [status writeToFile:statusFileName atomically:YES encoding:NSUTF8StringEncoding error:nil];
		if(!succeed) {
			NSBeep();
			SPOnewayAlertSheet(
				NSLocalizedString(@"BASH Error", @"bash error"),
				[self frontDocumentWindow],
				NSLocalizedString(@"Status file for sequelpro url scheme command couldn't be written!", @"status file for sequelpro url scheme command couldn't be written error message")
			);
		}
		return;
	}

	NSString *activeProcessID = [[self frontDocument] processID];

	SPDatabaseDocument *processDocument = nil;

	// Try to find the SPDatabaseDocument which sent the the url scheme command
	// For speed check the front most first otherwise iterate through all
	if(passedProcessID && [passedProcessID length]) {
		if([activeProcessID isEqualToString:passedProcessID]) {
			processDocument = [self frontDocument];
		} else {
			for (NSWindow *aWindow in [self orderedDatabaseConnectionWindows]) {
				for(SPDatabaseDocument *doc in [[aWindow windowController] documents]) {
					if([doc processID] && [[doc processID] isEqualToString:passedProcessID]) {
						processDocument = doc;
						goto break_loop;
					}
				}
			}
			break_loop: /* breaking two levels of foreach */;
		}
	}

	// if no processDoc found and no passedProcessID was passed execute
	// command at front most doc
	if(!processDocument && !passedProcessID)
		processDocument = [self frontDocument];

	if(processDocument && command) {
		if([command isEqualToString:@"passToDoc"]) {
			NSMutableDictionary *cmdDict = [NSMutableDictionary dictionary];
			[cmdDict setObject:parameter forKey:@"parameter"];
			[cmdDict setObject:(passedProcessID)?:@"" forKey:@"id"];
			[processDocument handleSchemeCommand:cmdDict];
		} else {
			SPOnewayAlertSheet(
				NSLocalizedString(@"sequelpro URL Scheme Error", @"sequelpro url Scheme Error"),
				[NSApp mainWindow],
				[NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [command description], NSLocalizedString(@"sequelpro URL scheme command not supported.", @"sequelpro URL scheme command not supported.")]
			);

			// If command failed notify the file handle hand shake mechanism
			NSString *out = @"1";
			NSString *anUUID = @"";
			if(command && passedProcessID && [passedProcessID length])
				anUUID = passedProcessID;
			else
				anUUID = command;
			
			[out writeToFile:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultStatusPathHeader, anUUID]
				atomically:YES
				encoding:NSUTF8StringEncoding
				   error:nil];

			out = @"Error";
			[out writeToFile:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultPathHeader, anUUID]
				atomically:YES
				encoding:NSUTF8StringEncoding
				   error:nil];

		}

		return;

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
		
		SPOnewayAlertSheet(
			NSLocalizedString(@"sequelpro URL Scheme Error", @"sequelpro url Scheme Error"),
			[NSApp mainWindow],
			[NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [command description], NSLocalizedString(@"An error for sequelpro URL scheme command occurred. Probably no corresponding connection window found.", @"An error for sequelpro URL scheme command occurred. Probably no corresponding connection window found.")]
		);

		usleep(5000);
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultStatusPathHeader, passedProcessID] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultPathHeader, passedProcessID] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultMetaPathHeader, passedProcessID] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryInputPathHeader, passedProcessID] error:nil];



	} else {
		SPOnewayAlertSheet(
			NSLocalizedString(@"sequelpro URL Scheme Error", @"sequelpro url Scheme Error"),
			[NSApp mainWindow],
			[NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [command description], NSLocalizedString(@"An error occur while executing a scheme command. If the scheme command was invoked by a Bundle command, it could be that the command still runs. You can try to terminate it by pressing ⌘+. or via the Activities pane.", @"an error occur while executing a scheme command. if the scheme command was invoked by a bundle command, it could be that the command still runs. you can try to terminate it by pressing ⌘+. or via the activities pane.")]
		);
	}

	if(processDocument)
		NSLog(@"process doc ID: %@\n%@", [processDocument processID], [processDocument tabTitleForTooltip]);
	else
		NSLog(@"No corresponding doc found");
	NSLog(@"param: %@", parameter);
	NSLog(@"command: %@", command);
	NSLog(@"command id: %@", passedProcessID);

}

/** 
 * Return an HTML formatted string representing the passed SQL string syntax highlighted
 */
- (NSString*)doSQLSyntaxHighlightForString:(NSString*)sqlText cssLike:(BOOL)cssLike
{
	NSMutableString *sqlHTML = [[[NSMutableString alloc] initWithCapacity:[sqlText length]] autorelease];

	NSString *tokenColor;
	NSString *cssId;
	size_t token;
	NSRange tokenRange;

	// initialise flex
	yyuoffset = 0; yyuleng = 0;
	yy_switch_to_buffer(yy_scan_string([sqlText UTF8String]));
	BOOL skipFontTag;

	while ((token=yylex())) {
		skipFontTag = NO;
		switch (token) {
			case SPT_SINGLE_QUOTED_TEXT:
			case SPT_DOUBLE_QUOTED_TEXT:
				tokenColor = @"#A7221C";
				cssId = @"sp_sql_quoted";
				break;
			case SPT_BACKTICK_QUOTED_TEXT:
				tokenColor = @"#001892";
				cssId = @"sp_sql_backtick";
				break;
			case SPT_RESERVED_WORD:
				tokenColor = @"#0041F6";
				cssId = @"sp_sql_keyword";
				break;
			case SPT_NUMERIC:
				tokenColor = @"#67350F";
				cssId = @"sp_sql_numeric";
				break;
			case SPT_COMMENT:
				tokenColor = @"#265C10";
				cssId = @"sp_sql_comment";
				break;
			case SPT_VARIABLE:
				tokenColor = @"#6C6C6C";
				cssId = @"sp_sql_variable";
				break;
			case SPT_WHITESPACE:
				skipFontTag = YES;
				cssId = @"";
				break;
			default:
				skipFontTag = YES;
				cssId = @"";
		}

		tokenRange = NSMakeRange(yyuoffset, yyuleng);

		if(skipFontTag)
			[sqlHTML appendString:[[sqlText substringWithRange:tokenRange] HTMLEscapeString]];
		else {
			if(cssLike)
				[sqlHTML appendFormat:@"<span class=\"%@\">%@</span>", cssId, [[sqlText substringWithRange:tokenRange] HTMLEscapeString]];
			else
				[sqlHTML appendFormat:@"<font color=%@>%@</font>", tokenColor, [[sqlText substringWithRange:tokenRange] HTMLEscapeString]];
		}

	}

	// Wrap lines, and replace tabs with spaces
	[sqlHTML replaceOccurrencesOfString:@"\n" withString:@"<br>" options:NSLiteralSearch range:NSMakeRange(0, [sqlHTML length])];
	[sqlHTML replaceOccurrencesOfString:@"\t" withString:@"&nbsp;&nbsp;&nbsp;&nbsp;" options:NSLiteralSearch range:NSMakeRange(0, [sqlHTML length])];

	return (sqlHTML) ? sqlHTML : @"";
}

- (IBAction)executeBundleItemForApp:(id)sender
{
	NSInteger idx = [sender tag] - 1000000;
	NSString *infoPath = nil;
	NSArray *scopeBundleItems = [SPAppDelegate bundleItemsForScope:SPBundleScopeGeneral];
	if(idx >=0 && idx < (NSInteger)[scopeBundleItems count]) {
		infoPath = [[scopeBundleItems objectAtIndex:idx] objectForKey:SPBundleInternPathToFileKey];
	} else {
		if([sender tag] == 0 && [[sender toolTip] length]) {
			infoPath = [sender toolTip];
		}
	}

	if(!infoPath) {
		NSLog(@"No path to Bundle command passed");
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
		if([cmdData objectForKey:SPBundleFileCommandKey] && [(NSString *)[cmdData objectForKey:SPBundleFileCommandKey] length]) {

			NSString *cmd = [cmdData objectForKey:SPBundleFileCommandKey];
			NSError *err = nil;
			NSString *uuid = [NSString stringWithNewUUID];
			NSString *bundleInputFilePath = [NSString stringWithFormat:@"%@_%@", SPBundleTaskInputFilePath, uuid];

			[[NSFileManager defaultManager] removeItemAtPath:bundleInputFilePath error:nil];

			NSMutableDictionary *env = [NSMutableDictionary dictionary];
			[env setObject:[infoPath stringByDeletingLastPathComponent] forKey:SPBundleShellVariableBundlePath];
			[env setObject:bundleInputFilePath forKey:SPBundleShellVariableInputFilePath];
			[env setObject:SPBundleScopeGeneral forKey:SPBundleShellVariableBundleScope];
			[env setObject:SPURLSchemeQueryResultPathHeader forKey:SPBundleShellVariableQueryResultFile];
			[env setObject:SPURLSchemeQueryResultStatusPathHeader forKey:SPBundleShellVariableQueryResultStatusFile];

			NSString *input = @"";
			NSError *inputFileError = nil;
			if(input == nil) input = @"";
			[input writeToFile:bundleInputFilePath
					  atomically:YES
						encoding:NSUTF8StringEncoding
						   error:&inputFileError];
			
			if(inputFileError != nil) {
				NSString *errorMessage  = [inputFileError localizedDescription];
				SPOnewayAlertSheet(
					NSLocalizedString(@"Bundle Error", @"bundle error"),
					[self frontDocumentWindow],
					[NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [cmdData objectForKey:@"name"], errorMessage]
				);
				if (cmdData) [cmdData release];
				return;
			}

			NSString *output = [SPBundleCommandRunner runBashCommand:cmd 
													 withEnvironment:env 
											  atCurrentDirectoryPath:nil 
													  callerInstance:self 
														 contextInfo:[NSDictionary dictionaryWithObjectsAndKeys:
																	  ([cmdData objectForKey:SPBundleFileNameKey])?:@"-", @"name",
																	  NSLocalizedString(@"General", @"general menu item label"), @"scope",
																	  uuid, SPBundleFileInternalexecutionUUID, nil]
															   error:&err];

			[[NSFileManager defaultManager] removeItemAtPath:bundleInputFilePath error:nil];

			NSString *action = SPBundleOutputActionNone;
			if([cmdData objectForKey:SPBundleFileOutputActionKey] && [(NSString *)[cmdData objectForKey:SPBundleFileOutputActionKey] length])
				action = [[cmdData objectForKey:SPBundleFileOutputActionKey] lowercaseString];

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
				if(![action isEqualToString:SPBundleOutputActionNone]) {
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
							[SPAppDelegate addHTMLOutputController:c];
						}
					}
				}
			} else if([err code] != 9) { // Suppress an error message if command was killed
				NSString *errorMessage  = [err localizedDescription];
				SPOnewayAlertSheet(
					NSLocalizedString(@"BASH Error", @"bash error"),
					[NSApp mainWindow],
					[NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [cmdData objectForKey:@"name"], errorMessage]
				);
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
		for (NSWindow *aWindow in [self orderedDatabaseConnectionWindows]) {
			for(SPDatabaseDocument *d in [[aWindow windowController] documents]) {
				if([d processID] && [[d processID] isEqualToString:docUUID]) {
					[env addEntriesFromDictionary:[d shellVariables]];
					goto break_loop;
				}
			}
		}
		break_loop: /* breaking two levels of foreach */;
	}

	id firstResponder = [[NSApp keyWindow] firstResponder];
	if([firstResponder respondsToSelector:@selector(executeBundleItemForInputField:)]) {
		BOOL selfIsQueryEditor = ([[[firstResponder class] description] isEqualToString:@"SPTextView"] && [[firstResponder delegate] respondsToSelector:@selector(currentQueryRange)]);
		NSRange currentWordRange, currentSelectionRange, currentLineRange, currentQueryRange;
		currentSelectionRange = [firstResponder selectedRange];
		currentWordRange = [firstResponder getRangeForCurrentWord];
		currentLineRange = [[firstResponder string] lineRangeForRange:NSMakeRange([firstResponder selectedRange].location, 0)];

		if(selfIsQueryEditor) {
			currentQueryRange = [(SPCustomQuery *)[firstResponder delegate] currentQueryRange];
		} else {
			currentQueryRange = currentLineRange;
		}
		if(!currentQueryRange.length)
			currentQueryRange = currentSelectionRange;

		[env setObject:SPBundleScopeInputField forKey:SPBundleShellVariableBundleScope];

		if(selfIsQueryEditor && [(SPCustomQuery *)[firstResponder delegate] currentQueryRange].length)
			[env setObject:[[firstResponder string] substringWithRange:[(SPCustomQuery *)[firstResponder delegate] currentQueryRange]] forKey:SPBundleShellVariableCurrentQuery];

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
			[selectedRows enumerateIndexesUsingBlock:^(NSUInteger rowIndex, BOOL * _Nonnull stop) {
				[sel addObject:[NSString stringWithFormat:@"%ld", (long)rowIndex]];
			}];
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

	SPDatabaseDocument* frontMostDoc = [self frontDocument];
	if(frontMostDoc) {
		if([runningActivitiesArray count] || [[frontMostDoc runningActivities] count])
			[frontMostDoc performSelector:@selector(setActivityPaneHidden:) withObject:@0 afterDelay:1.0];
		else {
			[NSObject cancelPreviousPerformRequestsWithTarget:frontMostDoc 
									selector:@selector(setActivityPaneHidden:) 
									object:@0];
			[frontMostDoc setActivityPaneHidden:@1];
		}
	}

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

	SPDatabaseDocument* frontMostDoc = [self frontDocument];
	if(frontMostDoc) {
		if([runningActivitiesArray count] || [[frontMostDoc runningActivities] count])
			[frontMostDoc performSelector:@selector(setActivityPaneHidden:) withObject:@0 afterDelay:1.0];
		else {
			[NSObject cancelPreviousPerformRequestsWithTarget:frontMostDoc 
									selector:@selector(setActivityPaneHidden:) 
									object:@0];
			[frontMostDoc setActivityPaneHidden:@1];
		}
	}
}

- (NSArray*)runningActivities
{
	return (NSArray*)runningActivitiesArray;
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
	return [[self frontController] selectedTableDocument];
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
	if(_sessionURL) SPClear(_sessionURL);
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

- (void)removeHTMLOutputController:(id)controller
{
	[bundleHTMLOutputController removeObject:controller];
}

- (IBAction)reloadBundles:(id)sender
{

	// Force releasing of any hidden HTML output windows, which will automatically remove them from the array.
	// Keep the visible windows.
	for (id c in bundleHTMLOutputController) {
		if (![[c window] isVisible]) {
			[[c window] performClose:self];
		}
	}

	BOOL foundInstalledBundles = NO;

	[bundleItems removeAllObjects];
	[bundleUsedScopes removeAllObjects];
	[bundleCategories removeAllObjects];
	[bundleTriggers removeAllObjects];
	[bundleKeyEquivalents removeAllObjects];
	[installedBundleUUIDs removeAllObjects];

	// Get main menu "Bundles"'s submenu
	NSMenu *menu = [[[NSApp mainMenu] itemWithTag:SPMainMenuBundles] submenu];

	// Clean menu
	[menu removeAllItems];

	// Set up the bundle search paths
	// First process all in Application Support folder installed ones then Default ones
	NSFileManager *fm = [NSFileManager defaultManager];
	NSError *appPathError = nil;
	NSArray *bundlePaths = [NSArray arrayWithObjects:
		[fm applicationSupportDirectoryForSubDirectory:SPBundleSupportFolder createIfNotExists:YES error:&appPathError],
		[NSString stringWithFormat:@"%@/Contents/SharedSupport/Default Bundles", [[NSBundle mainBundle] bundlePath]],
		nil];

	// If ~/Library/Application Path/Sequel Pro/Bundles couldn't be created bail
	if(appPathError != nil) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Bundles Installation Error", @"bundles installation error")
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										  otherButton:nil 
							informativeTextWithFormat:NSLocalizedString(@"Couldn't create Application Support Bundle folder!\nError: %@", @"Couldn't create Application Support Bundle folder!\nError: %@"), [appPathError localizedDescription]];

		[alert runModal];
		return;
	}

	BOOL processDefaultBundles = NO;

	NSArray *deletedDefaultBundles;

	if([[NSUserDefaults standardUserDefaults] objectForKey:SPBundleDeletedDefaultBundlesKey])
		deletedDefaultBundles = [[[NSUserDefaults standardUserDefaults] objectForKey:SPBundleDeletedDefaultBundlesKey] retain];
	else
		deletedDefaultBundles = [@[] retain];

	NSMutableString *infoAboutUpdatedDefaultBundles = [NSMutableString string];
	BOOL doBundleUpdate = ([[NSUserDefaults standardUserDefaults] objectForKey:@"doBundleUpdate"]) ? YES : NO;

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

					cmdData = [NSPropertyListSerialization propertyListFromData:pData 
							mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError];

					if(!cmdData || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
						NSLog(@"“%@” file couldn't be read.", infoPath);
						NSBeep();
						continue;
					}

					if((![cmdData objectForKey:SPBundleFileDisabledKey] || ![[cmdData objectForKey:SPBundleFileDisabledKey] intValue]) 
						&& [cmdData objectForKey:SPBundleFileNameKey] 
						&& [(NSString *)[cmdData objectForKey:SPBundleFileNameKey] length] 
						&& [cmdData objectForKey:SPBundleFileScopeKey])
					{

						BOOL defaultBundleWasUpdated = NO;

						if([cmdData objectForKey:SPBundleFileUUIDKey] && [(NSString *)[cmdData objectForKey:SPBundleFileUUIDKey] length]) {

							if(processDefaultBundles) {

								// Skip deleted default Bundles
								BOOL bundleWasDeleted = NO;
								if([deletedDefaultBundles count]) {
									for(NSArray* item in deletedDefaultBundles) {
										if([[item objectAtIndex:0] isEqualToString:[cmdData objectForKey:SPBundleFileUUIDKey]]) {
											bundleWasDeleted = YES;
											break;
										}
									}
								}
								if(bundleWasDeleted) continue;

								// If default Bundle is already installed check for possible update,
								// if so duplicate the modified one by appending (user) and updated it
								if(doBundleUpdate || [installedBundleUUIDs objectForKey:[cmdData objectForKey:SPBundleFileUUIDKey]] == nil) {

									if([installedBundleUUIDs objectForKey:[cmdData objectForKey:SPBundleFileUUIDKey]]) {

										NSString *oldPath = [NSString stringWithFormat:@"%@/%@/%@", [bundlePaths objectAtIndex:0], bundle, SPBundleFileName];
										readError = nil;
										convError = nil;
										NSDictionary *cmdDataOld = nil;

										NSData *pDataOld = [NSData dataWithContentsOfFile:oldPath options:NSUncachedRead error:&readError];
										cmdDataOld = [NSPropertyListSerialization propertyListFromData:pDataOld 
												mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError];
										if(!cmdDataOld || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
											NSLog(@"“%@” file couldn't be read.", oldPath);
											NSBeep();
											continue;
										} else {
											NSString *oldBundle = [NSString stringWithFormat:@"%@/%@", [bundlePaths objectAtIndex:0], bundle];
											// Check for modifications
											if([cmdDataOld objectForKey:SPBundleFileDefaultBundleWasModifiedKey]) {

												// Duplicate Bundle, change the UUID and rename the menu label
												NSString *duplicatedBundle = [NSString stringWithFormat:@"%@/%@_%ld.%@", [bundlePaths objectAtIndex:0], [bundle substringToIndex:([bundle length] - [SPUserBundleFileExtension length] - 1)], (long)(random() % 35000), SPUserBundleFileExtension];
												if(![[NSFileManager defaultManager] copyItemAtPath:oldBundle toPath:duplicatedBundle error:nil]) {
													NSLog(@"Couldn't copy “%@” to update it", bundle);
													NSBeep();
													continue;
												}
												NSError *readError1 = nil;
												NSString *convError1 = nil;
												NSMutableDictionary *dupData = [NSMutableDictionary dictionary];
												NSString *duplicatedBundleCommand = [NSString stringWithFormat:@"%@/%@", duplicatedBundle, SPBundleFileName];
												NSData *dData = [NSData dataWithContentsOfFile:duplicatedBundleCommand options:NSUncachedRead error:&readError1];
												[dupData setDictionary:[NSPropertyListSerialization propertyListFromData:dData 
														mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError1]];
												
												if ((!dupData && ![dupData count]) || (readError1 != nil || [convError1 length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0))) {
													NSLog(@"“%@” file couldn't be read.", duplicatedBundleCommand);
													NSBeep();
													continue;
												}
												
												[dupData setObject:[NSString stringWithNewUUID] forKey:SPBundleFileUUIDKey];
												NSString *orgName = [dupData objectForKey:SPBundleFileNameKey];
												[dupData setObject:[NSString stringWithFormat:@"%@ (user)", orgName] forKey:SPBundleFileNameKey];
												[dupData removeObjectForKey:SPBundleFileIsDefaultBundleKey];
												[dupData writeToFile:duplicatedBundleCommand atomically:YES];

												error = nil;
												NSString *moveToTrashCommand = [NSString stringWithFormat:@"osascript -e 'tell application \"Finder\" to move (POSIX file \"%@\") to the trash'", oldBundle];
												
												[SPBundleCommandRunner runBashCommand:moveToTrashCommand withEnvironment:nil atCurrentDirectoryPath:nil error:&error];

												if(error != nil) {
													NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while moving “%@” to Trash.", @"error while moving “%@” to trash"), [[installedBundleUUIDs objectForKey:[cmdDataOld objectForKey:SPBundleFileUUIDKey]] objectForKey:@"path"]]
																					 defaultButton:NSLocalizedString(@"OK", @"OK button") 
																				   alternateButton:nil 
																					  otherButton:nil 
																		informativeTextWithFormat:@"%@", [error localizedDescription]];

													[alert setAlertStyle:NSCriticalAlertStyle];
													[alert runModal];
													continue;
												}
												[infoAboutUpdatedDefaultBundles appendFormat:@"• %@\n", orgName];
											} else {

												// If no modifications are done simply remove the old one
												if(![fm removeItemAtPath:oldBundle error:nil]) {
													NSLog(@"Couldn't remove “%@” to update it", bundle);
													NSBeep();
													continue;
												}

											}

										}
									}

									BOOL isDir;
									NSString *newInfoPath = [NSString stringWithFormat:@"%@/%@/%@", [bundlePaths objectAtIndex:0], bundle, SPBundleFileName];
									NSString *orgPath = [NSString stringWithFormat:@"%@/%@", [bundlePaths objectAtIndex:1], bundle];
									NSString *newPath = [NSString stringWithFormat:@"%@/%@", [bundlePaths objectAtIndex:0], bundle];
									if([fm fileExistsAtPath:newPath isDirectory:&isDir] && isDir)
										newPath = [NSString stringWithFormat:@"%@_%ld", newPath, (long)(random() % 35000)];
									error = nil;
									[fm copyItemAtPath:orgPath toPath:newPath error:&error];
									if(error != nil) {
										NSBeep();
										NSLog(@"Default Bundle “%@” couldn't be copied to '%@'", bundle, newInfoPath);
										continue;
									}
									infoPath = [NSString stringWithString:newInfoPath];

									defaultBundleWasUpdated = YES;

								}

								if(!defaultBundleWasUpdated) continue;

							}

							[installedBundleUUIDs setObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[NSString stringWithFormat:@"%@ (%@)", bundle, [cmdData objectForKey:SPBundleFileNameKey]], @"name",
									infoPath, @"path", nil] forKey:[cmdData objectForKey:SPBundleFileUUIDKey]];

						} else {
							NSLog(@"No UUID for %@", bundle);
							NSBeep();
							continue;
						}

						// Register Bundle
						NSString *scope = [cmdData objectForKey:SPBundleFileScopeKey];

						// Register scope/category menu structure
						if(![bundleUsedScopes containsObject:scope]) {
							[bundleUsedScopes addObject:scope];
							[bundleItems setObject:[NSMutableArray array] forKey:scope];
							[bundleCategories setObject:[NSMutableArray array] forKey:scope];
							[bundleKeyEquivalents setObject:[NSMutableDictionary dictionary] forKey:scope];
						}
						if([cmdData objectForKey:SPBundleFileCategoryKey] && [(NSString *)[cmdData objectForKey:SPBundleFileCategoryKey] length] && ![[bundleCategories objectForKey:scope] containsObject:[cmdData objectForKey:SPBundleFileCategoryKey]])
							[[bundleCategories objectForKey:scope] addObject:[cmdData objectForKey:SPBundleFileCategoryKey]];

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

						// Register key equivalent
						if([cmdData objectForKey:SPBundleFileKeyEquivalentKey] && [(NSString *)[cmdData objectForKey:SPBundleFileKeyEquivalentKey] length]) {

							NSString *theKey = [cmdData objectForKey:SPBundleFileKeyEquivalentKey];
							NSString *theChar = [theKey substringFromIndex:[theKey length]-1];
							NSString *theMods = [theKey substringToIndex:[theKey length]-1];
							NSUInteger mask = 0;
							if([theMods rangeOfString:@"^"].length) mask = mask | NSControlKeyMask;
							if([theMods rangeOfString:@"@"].length) mask = mask | NSCommandKeyMask;
							if([theMods rangeOfString:@"~"].length) mask = mask | NSAlternateKeyMask;
							if([theMods rangeOfString:@"$"].length) mask = mask | NSShiftKeyMask;

							if(![[bundleKeyEquivalents objectForKey:scope] objectForKey:[cmdData objectForKey:SPBundleFileKeyEquivalentKey]])
								[[bundleKeyEquivalents objectForKey:scope] setObject:[NSMutableArray array] forKey:[cmdData objectForKey:SPBundleFileKeyEquivalentKey]];

							if(!doBundleUpdate || (doBundleUpdate && (![[cmdData objectForKey:SPBundleFileIsDefaultBundleKey] boolValue] || processDefaultBundles)))
								[[[bundleKeyEquivalents objectForKey:scope] objectForKey:[cmdData objectForKey:SPBundleFileKeyEquivalentKey]] addObject:
											[NSDictionary dictionaryWithObjectsAndKeys:
													infoPath, @"path",
													[cmdData objectForKey:SPBundleFileNameKey], @"title",
													([cmdData objectForKey:SPBundleFileTooltipKey]) ?: @"", @"tooltip",
											nil]];

							[aDict setObject:[NSArray arrayWithObjects:theChar, [NSNumber numberWithInteger:mask], nil] forKey:SPBundleInternKeyEquivalentKey];
						}

						if([cmdData objectForKey:SPBundleFileTooltipKey] && [(NSString *)[cmdData objectForKey:SPBundleFileTooltipKey] length])
							[aDict setObject:[cmdData objectForKey:SPBundleFileTooltipKey] forKey:SPBundleFileTooltipKey];

						if([cmdData objectForKey:SPBundleFileCategoryKey] && [(NSString *)[cmdData objectForKey:SPBundleFileCategoryKey] length])
							[aDict setObject:[cmdData objectForKey:SPBundleFileCategoryKey] forKey:SPBundleFileCategoryKey];

						if([cmdData objectForKey:SPBundleFileKeyEquivalentKey] && [(NSString *)[cmdData objectForKey:SPBundleFileKeyEquivalentKey] length])
							[aDict setObject:[cmdData objectForKey:SPBundleFileKeyEquivalentKey] forKey:@"key"];

						[[bundleItems objectForKey:scope] addObject:aDict];

					}
				}

				// Sort items for menus
				NSSortDescriptor *sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:SPBundleInternLabelKey ascending:YES] autorelease];
				for(NSString* scope in [bundleItems allKeys]) {
					[[bundleItems objectForKey:scope] sortUsingDescriptors:@[sortDescriptor]];
					[[bundleCategories objectForKey:scope] sortUsingSelector:@selector(compare:)];
				}
			}
		}
		processDefaultBundles = YES;
	}

	[deletedDefaultBundles release];
	if(doBundleUpdate) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"doBundleUpdate"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}

	// Inform user about default Bundle updates which were modified by the user and re-run Reload Bundles
	if([infoAboutUpdatedDefaultBundles length]) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Default Bundles Update", @"default bundles update")
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										  otherButton:nil 
							informativeTextWithFormat:NSLocalizedString(@"The following default Bundles were updated:\n%@\nYour modifications were stored as “(user)”.", @"the following default bundles were updated:\n%@\nyour modifications were stored as “(user)”."), infoAboutUpdatedDefaultBundles];

		[alert runModal];
		[self reloadBundles:nil];
		return;
	}

	// === Rebuild Bundles main menu item ===

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
	NSArray *scopes = @[SPBundleScopeInputField, SPBundleScopeDataTable, SPBundleScopeGeneral];
	NSArray *scopeTitles = @[
			NSLocalizedString(@"Input Field", @"input field menu item label"),
			NSLocalizedString(@"Data Table", @"data table menu item label"),
			NSLocalizedString(@"General", @"general menu item label")
	];

	NSUInteger k = 0;
	BOOL bundleOtherThanGeneralFound = NO;
	for(NSString* scope in scopes) {

		NSArray *scopeBundleCategories = [SPAppDelegate bundleCategoriesForScope:scope];
		NSArray *scopeBundleItems = [SPAppDelegate bundleItemsForScope:scope];

		if(![scopeBundleItems count]) {
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
		if([scopeBundleCategories count]) {
			for(NSString* title in scopeBundleCategories) {
				[categorySubMenus addObject:[[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""] autorelease]];
				[categoryMenus addObject:[[[NSMenu alloc] init] autorelease]];
				[bundleMenu addItem:[categorySubMenus lastObject]];
				[bundleMenu setSubmenu:[categoryMenus lastObject] forItem:[categorySubMenus lastObject]];
			}
		}

		NSInteger i = 0;
		for(NSDictionary *item in scopeBundleItems) {

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
				[[categoryMenus objectAtIndex:[scopeBundleCategories indexOfObject:[item objectForKey:SPBundleFileCategoryKey]]] addItem:mItem];
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

	id firstResponder = [[NSApp keyWindow] firstResponder];

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
			NSArray *sorted = [assignedKeyEquivalents sortedArrayUsingDescriptors:@[aSortDescriptor]];
			[assignedKeyEquivalents setArray:sorted];
		}
	}

	if([scope isEqualToString:SPBundleScopeInputField] && [firstResponder respondsToSelector:@selector(executeBundleItemForInputField:)]) {
		if(checkForKeyEquivalents && [assignedKeyEquivalents count]) {
			NSInteger idx = 0;
			if([assignedKeyEquivalents count] > 1)
				idx = [SPChooseMenuItemDialog withItems:assignedKeyEquivalents atPosition:[NSEvent mouseLocation]];

			if(idx > -1) {
				NSDictionary *eq = [assignedKeyEquivalents objectAtIndex:idx];
				if(eq && [eq count]) {
					NSMenuItem *aMenuItem = [[[NSMenuItem alloc] init] autorelease];
					[aMenuItem setTag:0];
					[aMenuItem setToolTip:[eq objectForKey:@"path"]];
					[(SPTextView *)firstResponder executeBundleItemForInputField:aMenuItem];
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
				NSDictionary *eq = [assignedKeyEquivalents objectAtIndex:idx];
				if(eq && [eq count]) {
					NSMenuItem *aMenuItem = [[[NSMenuItem alloc] init] autorelease];
					[aMenuItem setTag:0];
					[aMenuItem setToolTip:[eq objectForKey:@"path"]];
					[(SPCopyTable *)firstResponder executeBundleItemForDataTable:aMenuItem];
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
				NSDictionary *eq = [assignedKeyEquivalents objectAtIndex:idx];
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
	[preferences removeObjectsForKeys:@[
			@"ContentFilters",
			@"favorites",
			@"lastSqlFileName",
			@"NSNavLastRootDirectory",
			@"openPath",
			@"queryFavorites",
			@"queryHistory",
			@"tableColumnWidths",
			@"savePath",
			@"NSRecentDocumentRecords"
	]];
	
	return preferences;
}

#pragma mark -
#pragma mark Other methods

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
	// Sparkle might call this on a background thread, but calling endSheet: from a bg thread is unhealthy
	if(![NSThread isMainThread]) return [[self onMainThread] updaterWillRelaunchApplication:updater];

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
 * If Sequel Pro is terminating kill all running BASH scripts and release all HTML output controller.
 *
 * TODO: Remove a lot of this duplicate code.
 */
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	BOOL shouldSaveFavorites = NO;

	if (lastBundleBlobFilesDirectory != nil) {
		[[NSFileManager defaultManager] removeItemAtPath:lastBundleBlobFilesDirectory error:nil];
	}

	// Iterate through each open window
	for (NSWindow *aWindow in [self orderedDatabaseConnectionWindows])
	{
		// Iterate through each document in the window
		for (SPDatabaseDocument *doc in [[aWindow windowController] documents]) 
		{
			// Kill any BASH commands which are currently active
			for (NSDictionary* cmd in [doc runningActivities]) 
			{
				NSInteger pid = [[cmd objectForKey:@"pid"] integerValue];
				NSTask *killTask = [[NSTask alloc] init];
				
				[killTask setLaunchPath:@"/bin/sh"];
				[killTask setArguments:[NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"kill -9 -%ld", (long)pid], nil]];
				[killTask launch];
				[killTask waitUntilExit];
				[killTask release];
			}

			// If the connection view is active, mark the favourites for saving
			if (![doc getConnection]) {
				shouldSaveFavorites = YES;
			}
		}
	}
	
	for (NSDictionary* cmd in [self runningActivities]) 
	{
		NSInteger pid = [[cmd objectForKey:@"pid"] integerValue];
		NSTask *killTask = [[NSTask alloc] init];
		
		[killTask setLaunchPath:@"/bin/sh"];
		[killTask setArguments:[NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"kill -9 -%ld", (long)pid], nil]];
		[killTask launch];
		[killTask waitUntilExit];
		[killTask release];
	}

	for (id c in bundleHTMLOutputController) 
	{
		[c release];
	}
	
	// If required, make sure we save any changes made to the connection outline view's state
	if (shouldSaveFavorites) {
		[[SPFavoritesController sharedFavoritesController] saveFavoritesSynchronously];
	}

	return YES;
}

#pragma mark -
#pragma mark Private API

/**
 * Copy default themes, when we start the app.
 */
- (void)_copyDefaultThemes
{
	NSError *appPathError = nil;
	NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *defaultThemesPath = [NSString stringWithFormat:@"%@/Contents/SharedSupport/Default Themes", [[NSBundle mainBundle] bundlePath]];
    NSString *appSupportThemesPath = [fm applicationSupportDirectoryForSubDirectory:SPThemesSupportFolder createIfNotExists:YES error:&appPathError];
	
	// If ~/Library/Application Path/Sequel Pro/Themes couldn't be created bail
	if (appPathError != nil) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Themes Installation Error", @"themes installation error")
										 defaultButton:NSLocalizedString(@"OK", @"OK button")
									   alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"Couldn't create Application Support Theme folder!\nError: %@", @"Couldn't create Application Support Theme folder!\nError: %@"), [appPathError localizedDescription]];
        
		[alert runModal];
		return;
	}
    
    NSError *error = nil;
    NSError *copyError = nil;
    NSArray *defaultThemes = [fm contentsOfDirectoryAtPath:defaultThemesPath error:&error];
	
    if (defaultThemes && [defaultThemes count] && error == nil) {
        for (NSString *defaultTheme in defaultThemes) 
		{
            if (![[[defaultTheme pathExtension] lowercaseString] isEqualToString:[SPColorThemeFileExtension lowercaseString]]) continue;
            
            NSString *defaultThemeFullPath = [NSString stringWithFormat:@"%@/%@", defaultThemesPath, defaultTheme];
            NSString *appSupportThemeFullPath = [NSString stringWithFormat:@"%@/%@", appSupportThemesPath, defaultTheme];
            
            if ([fm fileExistsAtPath:appSupportThemeFullPath]) continue;
            
			[fm copyItemAtPath:defaultThemeFullPath toPath:appSupportThemeFullPath error:&copyError];
        }
    }
    
    // If Themes could not be copied, show error message
	if (copyError != nil) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Themes Installation Error", @"themes installation error")
										 defaultButton:NSLocalizedString(@"OK", @"OK button")
									   alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"Couldn't copy default themes to Application Support Theme folder!\nError: %@", @"Couldn't copy default themes to Application Support Theme folder!\nError: %@"), [copyError localizedDescription]];
        
		[alert runModal];
		
		return;
	}
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if (bundleItems)                SPClear(bundleItems);
	if (bundleUsedScopes)           SPClear(bundleUsedScopes);
	if (bundleHTMLOutputController) SPClear(bundleHTMLOutputController);
	if (bundleCategories)           SPClear(bundleCategories);
	if (bundleTriggers)             SPClear(bundleTriggers);
	if (bundleKeyEquivalents)       SPClear(bundleKeyEquivalents);
	if (installedBundleUUIDs)       SPClear(installedBundleUUIDs);
	if (runningActivitiesArray)     SPClear(runningActivitiesArray);

	SPClear(prefsController);

	if (aboutController) SPClear(aboutController);
	if (bundleEditorController) SPClear(bundleEditorController);

	if (_sessionURL) SPClear(_sessionURL);
	if (_spfSessionDocData) SPClear(_spfSessionDocData);

	[super dealloc];
}

@end

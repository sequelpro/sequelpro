//
//  SPExportController.m
//  sequel-pro
//
//  Created by Ben Perry (benperry.com.au) on February 12, 2009.
//  Copyright (c) 2010 Ben Perry. All rights reserved.
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

#import "SPExportController.h"
#import "SPExportInitializer.h"
#import "SPTablesList.h"
#import "SPTableContent.h"
#import "SPGrowlController.h"
#import "SPExportFile.h"
#import "SPAlertSheets.h"
#import "SPExportFilenameUtilities.h"
#import "SPDatabaseDocument.h"
#import "SPCustomQuery.h"
#import "SPExportController+SharedPrivateAPI.h"
#import "SPExportSettingsPersistence.h"
#import "SPExportHandlerInstance.h"
#import "SPExporterRegistry.h"
#import "SPExportHandlerFactory.h"
#import "SPExportInterfaceController.h"
#import "SPDatabaseViewController.h"

NSString *SPExportHandlerSchemaObjectTypeSupportChangedNotification = @"SPExportHandlerSchemaObjectTypeSupportChanged";
NSString *SPExportControllerSchemaObjectsChangedNotification        = @"SPExportControllerSchemaObjectsChanged";

// Constants
static const NSUInteger SPExportUIPadding = 20;

static NSString * const SPTableViewStructureColumnID = @"structure";
static NSString * const SPTableViewContentColumnID   = @"content";
static NSString * const SPTableViewDropColumnID      = @"drop";

static const NSString *SPSQLExportStructureEnabled  = @"SQLExportStructureEnabled";
static const NSString *SPSQLExportContentEnabled    = @"SQLExportContentEnabled";
static const NSString *SPSQLExportDropEnabled       = @"SQLExportDropEnabled";

static void *_KVOContext; // we only need this to get a unique number ( = the address of this variable)

@interface SPExportController ()

@property(readwrite, retain, nonatomic) id<SPExportHandlerInstance> currentExportHandler;
@property(readwrite, assign, nonatomic) SPExportSource exportSource;

- (IBAction)closeSheet:(id)sender;
- (IBAction)switchInput:(id)sender;
- (IBAction)cancelExport:(id)sender;
- (IBAction)changeExportOutputPath:(id)sender;
- (IBAction)refreshTableList:(id)sender;
- (IBAction)selectDeselectAllTables:(id)sender;
- (IBAction)changeExportCompressionFormat:(id)sender;
- (IBAction)toggleCustomFilenameFormatView:(id)sender;
- (IBAction)toggleAdvancedExportOptionsView:(id)sender;
- (IBAction)exportFromMenuItem:(id)sender;

- (void)_refreshTableListKeepingState:(BOOL)keepState fromServer:(BOOL)fromServer;
- (void)_checkForDatabaseChanges;
- (void)_displayExportTypeOptions:(BOOL)display;

- (void)_toggleExportButton:(id)uiStateDict;
- (void)_toggleExportButtonOnBackgroundThread;
- (void)_toggleExportButtonWithBool:(NSNumber *)enable;

- (void)_waitUntilQueueIsEmptyAfterCancelling:(id)sender;
- (void)_queueIsEmptyAfterCancelling:(id)sender;

@end

#pragma mark -

@implementation SPExportController

@synthesize connection;
@synthesize serverSupport = serverSupport;
@synthesize exportToMultipleFiles;
@synthesize exportCancelled;
@synthesize currentExportHandler = currentExportHandler;
@synthesize exportSource = exportSource;

#pragma mark -
#pragma mark Initialisation

/**
 * Initializes an instance of SPExportController.
 */
- (id)init
{
	if ((self = [super initWithWindowNibName:@"ExportDialog"])) {
		
		[self setExportCancelled:NO];
		[self setExportToMultipleFiles:YES];

		mainNibLoaded = 0;

		exportSource = SPTableExport;
		
		exportTypeLabel = [@"" retain];
		
		createCustomFilename = NO;
		previousConnectionEncodingViaLatin1 = NO;
		
		exportObjectList = [[NSMutableArray alloc] init];
		exporters = [[NSMutableArray alloc] init];
		exportFiles = [[NSMutableArray alloc] init];
		operationQueue = [[NSOperationQueue alloc] init];
		
		showAdvancedView = NO;
		showCustomFilenameView = NO;

		heightOffset1 = 0;
		heightOffset2 = 0;
		
		prefs = [NSUserDefaults standardUserDefaults];
		
		localizedTokenNames = [@{
			SPFileNameHostTokenName:     NSLocalizedString(@"Host", @"export filename host token"),
			SPFileNameDatabaseTokenName: NSLocalizedString(@"Database", @"export filename database token"),
			SPFileNameTableTokenName:    NSLocalizedString(@"Table", @"table"),
			SPFileNameDateTokenName:     NSLocalizedString(@"Date", @"export filename date token"),
			SPFileNameYearTokenName:     NSLocalizedString(@"Year", @"export filename date token"),
			SPFileNameMonthTokenName:    NSLocalizedString(@"Month", @"export filename date token"),
			SPFileNameDayTokenName:      NSLocalizedString(@"Day", @"export filename date token"),
			SPFileNameTimeTokenName:     NSLocalizedString(@"Time", @"export filename time token"),
			SPFileNameFavoriteTokenName: NSLocalizedString(@"Favorite", @"export filename favorite name token")
		} retain];
		
		exportHandlers = [[NSMutableDictionary alloc] init];
		hiddenTabViewStorage = [[NSMutableArray alloc] init];
	}
	
	return self;
}

/**
 * Upon awakening select the first toolbar item
 */
- (void)awakeFromNib
{
	// This method is first called when DBView is loaded and later again, when we load our own view.
	// We MUST NOT do our init stuff when called from DBView as none of our owned outlets are connected at that time.
	if(!exportTypeTabBar) return;
	
	// As this controller also loads its own nib, it may call awakeFromNib multiple times; perform setup only once.
	dispatch_once(&mainNibLoaded, ^{
		while([exportTypeTabBar numberOfTabViewItems])
			[exportTypeTabBar removeTabViewItem:[exportTypeTabBar tabViewItemAtIndex:0]];

		[exportHandlers removeAllObjects];
		for(id<SPExportHandlerFactory> handler in [[SPExporterRegistry sharedRegistry] registeredHandlers]) {
			id<SPExportHandlerInstance> instance = [handler makeInstanceWithController:self];
			NSTabViewItem *tvi = [[NSTabViewItem alloc] init];
			[tvi setLabel:[handler localizedShortName]];
			[tvi setIdentifier:[handler uniqueName]];
			[tvi setView:exporterView];
			[exportTypeTabBar addTabViewItem:[tvi autorelease]];
			[exportHandlers setObject:instance forKey:[handler uniqueName]];
		}

		windowMinWidth = [[self window] minSize].width;
		windowMinHeigth = [[self window] minSize].height;

		// Select the 'selected tables' option
		[exportInputPopUpButton selectItemWithTag:SPTableExport];

		// Select the SQL tab
		[[exportTypeTabBar tabViewItemAtIndex:0] setView:exporterView];
		[exportTypeTabBar selectTabViewItemAtIndex:0];

		// Prevents the background colour from changing when clicked
		[[exportCustomFilenameViewLabelButton cell] setHighlightsBy:NSNoCellMask];

		// Set the progress indicator's max value
		[exportProgressIndicator setMaxValue:(NSInteger)[exportProgressIndicator bounds].size.width];

		// Empty the tokenizing character set for the filename field
		[exportCustomFilenameTokenField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@""]];

		// Accept Core Animation
		[accessoryViewContainer wantsLayer];
		[exportTablelistScrollView wantsLayer];
		[exportTableListButtonBar wantsLayer];

		[self addObserver:self forKeyPath:@"exportToMultipleFiles" options:0 context:&_KVOContext];
	});
}

#pragma mark -
#pragma mark Export methods

/**
 * Displays the export window with the supplied tables and export type/format selected.
 *
 * @param exportTables The array of table names to be exported
 * @param format       The export format to be used. Must be the uniqueName of a registered SPExportHandlerFactory.
 *                     Pass nil if you have no preference.
 * @param source       The source of the export. See SPExportSource constants.
 */
- (void)exportTables:(NSArray *)exportTables asFormat:(NSString *)format usingSource:(SPExportSource)source
{
	[self window]; // the window is lazy loaded

	// set some defaults
	if(![[exportPathField stringValue] length]) {
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSAllDomainsMask, YES);
		// If found the set the default path to the user's desktop, otherwise use their home directory
		[exportPathField setStringValue:([paths count] > 0) ? [paths objectAtIndex:0] : NSHomeDirectory()];
	}
	
	// initially popuplate the tables list from the main view
	[self _refreshTableListKeepingState:NO fromServer:NO];

	// overwrite defaults with user settings from last export
	[self applySettingsFromDictionary:[prefs objectForKey:SPLastExportSettings] error:NULL];
	
	// overwrite those with settings for the current export
	
	[exporters removeAllObjects];
	[exportFiles removeAllObjects];

	[self _updateVisibleTabsForValidHandlers];
	// Select the correct tab.
	if(format) {
		NSAssert(([exportHandlers objectForKey:format] != nil),@"<%@> is not a known export handler!",format);
		[self setExportHandlerIfPossible:format];
	}
	else {
		// this will pick the previous choice or anything else that is valid.
		[self setExportHandlerIfPossible:nil];
	}

	// Ensure interface validation
	[self _switchTab];
	[self _updateExportAdvancedOptionsLabel];
	[self setExportSourceIfPossible:source]; // will also update the tokens and filename preview

	// If tables were supplied, select them
	if(exportTables && source == SPTableExport && [[self currentExportHandler] respondsToSelector:@selector(setIncludedSchemaObjects:)]) {
		[[self currentExportHandler] setIncludedSchemaObjects:exportTables];
		[exportTableList reloadData];
	}

	[self _reopenExportSheet];
}

- (NSString *)setExportHandlerIfPossible:(NSString *)handler
{
	NSString *actualHandler = handler;
	// setting an unknown identifier would throw (an export handler without data is not visible and can't be selected)
	if(!handler || [exportTypeTabBar indexOfTabViewItemWithIdentifier:handler] == NSNotFound) {
		// we couldn't pick the preferred item. So let's pick something else then...
		actualHandler = [[exportTypeTabBar selectedTabViewItem] identifier];
	}
	[exportTypeTabBar selectTabViewItemWithIdentifier:actualHandler];
	return actualHandler;
}

- (void)_updateVisibleTabsForValidHandlers
{
	// this is a bit retarted, but for some reason NSTabView does not support hiding items.
	// we'll have to remove all items and then re-add those that are valid.

	// add visible items to the backup list
	[hiddenTabViewStorage addObjectsFromArray:[exportTypeTabBar tabViewItems]];
	
	// for the moment, prevent the delegate methods from firing as that would end up exactly
	// where we don't want (namely in setExportSourceIfPossible:)!
	id delegate = [exportTypeTabBar delegate];
	[exportTypeTabBar setDelegate:nil];
	NSTabViewItem *selected = [exportTypeTabBar selectedTabViewItem];
	
	// remove all from view
	while([exportTypeTabBar numberOfTabViewItems]) [exportTypeTabBar removeTabViewItem:[exportTypeTabBar tabViewItemAtIndex:0]];

	NSMutableArray *readdItems = [NSMutableArray array];

	SPExportSource es[] = {SPTableExport,SPQueryExport,SPFilteredExport,SPDatabaseExport};
	// go through all tab views
	for(NSTabViewItem *item in hiddenTabViewStorage) {
		id<SPExportHandlerInstance> handler = [exportHandlers objectForKey:[item identifier]];
		// handler is valid if there is any data it can be used with
		for (unsigned int i = 0; i < COUNT_OF(es); i++) {
			if([self _hasDataForSource:es[i] handler:handler]) {
				[readdItems addObject:item];
				break;
			}
		}
	}

	// remove the readd items from the hidden item array
	[hiddenTabViewStorage removeObjectsInArray:readdItems];

	// sort the readd items for display
	[readdItems sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(id obj1, id obj2) {
		return [[(NSTabViewItem *) obj1 label] localizedCompare:[(NSTabViewItem *)obj2 label]];
	}];

	NSAssert([readdItems count] > 0, @"Did not find any valid export handler for current state!?");

	// and re-add them
	for(NSTabViewItem *tvi in readdItems) {
		[exportTypeTabBar addTabViewItem:tvi];
	}
	
	// finally try to re-select the previous choice and re-enable the delegate
	if([exportTypeTabBar indexOfTabViewItem:selected] != NSNotFound) [exportTypeTabBar selectTabViewItem:selected];
	[exportTypeTabBar setDelegate:delegate];
}

/**
 * Re-open the export sheet without resetting the interface - for use on error.
 */
- (void)_reopenExportSheet
{
	[NSApp beginSheet:[self window]
	   modalForWindow:[tableDocumentInstance parentWindow]
	    modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
	      contextInfo:nil];
}

/**
 * Opens the errors sheet and displays the supplied errors string.
 *
 * @param errors The errors string to be displayed
 */
- (void)openExportErrorsSheetWithString:(NSString *)errors
{
	[errorsTextView setString:@""];
	[errorsTextView setString:errors];
	
	[NSApp beginSheet:errorsWindow 
	   modalForWindow:[tableDocumentInstance parentWindow] 
		modalDelegate:self 
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:nil];
}

/**
 * Displays the export finished Growl notification.
 */
- (void)displayExportFinishedGrowlNotification:(NSString *)exportFilename
{
	// Export finished Growl notification
	[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Export Finished" 
												   description:[NSString stringWithFormat:NSLocalizedString(@"Finished exporting to %@", @"description for finished exporting growl notification"), exportFilename] 
													  document:tableDocumentInstance
											  notificationName:@"Export Finished"];
}

- (NSArray *)schemaObjectsForType:(SPTableType)type
{
	NSMutableArray *out = [[NSMutableArray alloc] init];

	for(_SPExportListItem *item in exportObjectList) {
		if([item type] == type)
			[out addObject:item];
	}

	return [out autorelease];
}

- (id <SPExportSchemaObject>)schemaObjectNamed:(NSString *)name
{
	for(_SPExportListItem *item in exportObjectList) {
		if([[item name] isEqualToString:name])
			return item;
	}

	return nil;
}

- (NSArray *)allSchemaObjects
{
	NSMutableArray *obj = [exportObjectList mutableCopy];
	
	for(NSUInteger i=0;i<[obj count];i++) {
		_SPExportListItem *item = [obj objectAtIndex:i];
		if([item isGroupRow]) {
			[obj removeObjectAtIndex:(i--)];
		}
	}
	
	return [obj autorelease];
}

- (SPExportFile *)exportFileForTableName:(NSString *)tableName
{
	//for filtered export we can guess the table name - there can only be one
	if(!tableName && [self exportSource] == SPFilteredExport) tableName = [tableDocumentInstance table];
	
	NSMutableString *exportFilename = [NSMutableString string];
	// Create custom filename if required
	BOOL needsTableName;
	if (createCustomFilename) {
		[exportFilename setString:[self expandCustomFilenameFormatUsingTableName:tableName]];
		needsTableName = (![self isTableTokenIncludedForCustomFilename]);
		
		// the logic for finding the extension is a bit more difficult because the pattern can include e.g. dates with "."
		NSString *extension = [self currentDefaultExportFileExtension];
		if (![[self customFilenamePathExtension] length] && [extension length] > 0) [exportFilename setString:[exportFilename stringByAppendingPathExtension:extension]];
	}
	else {
		[exportFilename setString:[self generateDefaultExportFilename]];
		needsTableName = ([self exportSource] != SPFilteredExport); // only filtered export has the table name in the default pattern
	}
	
	// If we're exporting to multiple files, make sure the table name is included to ensure the output files are unique.
	if ([self exportToMultipleFiles] && (currentExportFileCountEstimate > 1) && needsTableName) {
		NSString *ext = [exportFilename pathExtension];
		[exportFilename setString:[exportFilename stringByDeletingPathExtension]];
		[exportFilename appendFormat:@"_%@", tableName];
		[exportFilename setString:[exportFilename stringByAppendingPathExtension:ext]];
	}

	SPExportFile *file = [SPExportFile exportFileAtPath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];

	return file;
}

- (SPDatabaseDocument *)tableDocumentInstance
{
	return tableDocumentInstance;
}

- (SPTableData *)tableDataInstance
{
	return tableDataInstance;
}

- (SPTableContent *)tableContentInstance
{
	return tableContentInstance;
}

- (SPCustomQuery *)customQueryInstance
{
	return customQueryInstance;
}

- (void)setExportProgressTitle:(NSString *)title
{
	[exportProgressTitle setStringValue:title];
	[exportProgressTitle displayIfNeeded];
}

- (void)setExportProgressDetail:(NSString *)detail
{
	[exportProgressText setStringValue:detail];
	[exportProgressText displayIfNeeded];
}

- (void)setExportProgress:(double)value
{
	[exportProgressIndicator setDoubleValue:value];
}

- (void)setExportProgressIndeterminate:(BOOL)indeterminate
{
	if(indeterminate) {
		[exportProgressIndicator setIndeterminate:YES];
		[exportProgressIndicator setUsesThreadedAnimation:YES];
		[exportProgressIndicator startAnimation:self];
	}
	else {
		[exportProgressIndicator stopAnimation:self];
		[exportProgressIndicator setIndeterminate:NO];
	}
}

- (NSArray *)waitingExporters
{
	return [NSArray arrayWithArray:exporters];
}

#pragma mark -
#pragma mark IB action methods

/**
 * Closes the export dialog.
 */
- (IBAction)closeSheet:(id)sender
{
	if ([sender window] == [self window]) {

		// Close the advanced options view if it's open
		[exportAdvancedOptionsView setHidden:YES];
		[exportAdvancedOptionsViewButton setState:NSOffState];
		showAdvancedView = NO;

		// Close the customize filename view if it's open
		[exportCustomFilenameView setHidden:YES];
		[exportCustomFilenameViewButton setState:NSOffState];
		showCustomFilenameView = NO;

		// If open close the advanced options view and custom filename view
		[self _resizeWindowForAdvancedOptionsViewByHeightDelta:0];
		[self _resizeWindowForCustomFilenameViewByHeightDelta:0];
	}

	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

- (BOOL)setExportSourceIfPossible:(SPExportSource)input
{
	SPExportSource actualInput = input;
	//check if the type actually is valid
	if(![[[exportInputPopUpButton menu] itemWithTag:actualInput] isEnabled]) {
		//...no, pick a valid one instead
		for (NSMenuItem *item in [exportInputPopUpButton itemArray]) {
			if([item isEnabled]) {
				actualInput = (SPExportSource)[item tag];
				goto set_input;
			}
		}
		// nothing found (should not happen)
		NSAssert(0,@"did not find any valid export input!?");
		return NO;
	}
set_input:
	[self setExportSource:actualInput];

	[exportInputPopUpButton selectItemWithTag:exportSource];

	BOOL isSelectedTables = (exportSource == SPTableExport);

	[exportFilePerTableCheck setHidden:(!isSelectedTables) || (![[[self currentExportHandler] factory] supportsExportToMultipleFiles])];


	[self _rebuildTableGeometry];
	[self _evaluateShownObjectTypes];

	[self updateAvailableExportFilenameTokens]; // will also update the filename itself

	return (actualInput == input);
}

/**
 * Enables/disables and shows/hides various interface controls depending on the selected item.
 */
- (IBAction)switchInput:(id)sender
{
	SPExportSource newSrc = (SPExportSource) [exportInputPopUpButton selectedTag];
	if(newSrc != [self exportSource]) [self setExportSourceIfPossible:newSrc];
}

/**
 * Cancel's the export operation by stopping the current table export loop and marking any current SPExporter
 * NSOperation subclasses as cancelled.
 */
- (IBAction)cancelExport:(id)sender
{
	[self setExportCancelled:YES];

	[exportProgressIndicator setIndeterminate:YES];
	[exportProgressIndicator setUsesThreadedAnimation:YES];
	[exportProgressIndicator startAnimation:self];

	[exportProgressTitle setStringValue:NSLocalizedString(@"Cancelling...", @"cancelling task status message")];
	[exportProgressText setStringValue:NSLocalizedString(@"Cleaning up...", @"cancelling export cleaning up message")];

	// Disable the cancel button
	[sender setEnabled:NO];

	// Cancel all of the currently running operations
	[operationQueue cancelAllOperations]; // async call
	[NSThread detachNewThreadWithName:SPCtxt(@"SPExportController cancelExport: waiting for empty queue", tableDocumentInstance) target:self selector:@selector(_waitUntilQueueIsEmptyAfterCancelling:) object:sender];
}

- (void)_waitUntilQueueIsEmptyAfterCancelling:(id)sender
{
	[sender retain];
	[operationQueue waitUntilAllOperationsAreFinished];
	[self performSelectorOnMainThread:@selector(_queueIsEmptyAfterCancelling:) withObject:sender waitUntilDone:NO];
	[sender release];
}

- (void)_queueIsEmptyAfterCancelling:(id)sender
{
	// Loop the cached export file paths and remove them from disk if they exist
	for (SPExportFile *file in exportFiles)
	{
		[file delete];
	}

	[self _hideExportProgress];

	// Restore the connection encoding to it's pre-export value
	[tableDocumentInstance setConnectionEncoding:[NSString stringWithFormat:@"%@%@", previousConnectionEncoding, (previousConnectionEncodingViaLatin1) ? @"-" : @""] reloadingViews:NO];

	// Re-enable the cancel button for future exports
	[sender setEnabled:YES];

	// Finally get rid of all the exporters and files
	[exportFiles removeAllObjects];
	[exporters removeAllObjects];
}

- (void)_hideExportProgress
{
	// Close the progress sheet
	[NSApp endSheet:exportProgressWindow returnCode:0];
	[exportProgressWindow orderOut:self];

	// Stop the progress indicator
	[exportProgressIndicator stopAnimation:self];
	[exportProgressIndicator setUsesThreadedAnimation:NO];
}

/**
 * Opens the open panel when user selects to change the output path.
 */
- (IBAction)changeExportOutputPath:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];

	[panel setCanChooseFiles:NO];
	[panel setCanChooseDirectories:YES];
	[panel setCanCreateDirectories:YES];

    [panel setDirectoryURL:[NSURL URLWithString:[exportPathField stringValue]]];
    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger returnCode) {
        if (returnCode == NSFileHandlingPanelOKButton) {
			NSString *path = [[panel directoryURL] path];
			if(!path) {
				@throw [NSException exceptionWithName:NSInternalInconsistencyException
											   reason:[NSString stringWithFormat:@"File panel ended with OK, but returned nil for path!? directoryURL=%@,isFileURL=%d",[panel directoryURL],[[panel directoryURL] isFileURL]]
											 userInfo:nil];
			}
            [exportPathField setStringValue:path];
        }
    }];
}

/**
 * Refreshes the table list.
 */
- (IBAction)refreshTableList:(id)sender
{
	[self _refreshTableListKeepingState:YES fromServer:YES];
}

- (void)_refreshTableListKeepingState:(BOOL)keepState fromServer:(BOOL)fromServer
{
	NSMutableArray *objectStateBackupArray = [[NSMutableArray alloc] initWithCapacity:[exportObjectList count]];

	// Before refreshing the list, preserve the user's table selection, but only if it was triggered by the UI.
	if (keepState) {
		for(_SPExportListItem *item in exportObjectList) {
			// skip those
			if([item isGroupRow]) continue;
			// get a saved state from the exporthandler
			id savedState = [[self currentExportHandler] specificSettingsForSchemaObject:item];
			if(savedState) {
				[objectStateBackupArray addObject:@{
						@"name" :       [item name],
						@"type" :       @([item type]),
						@"savedState" : savedState
				}];
			}
		}
	}

	//refresh the list and rebuild the basic table
	if(fromServer) [tablesListInstance updateTables:self];
	[self _evaluateShownObjectTypes];

	if (keepState) {
		// Restore the user's table selection
		for(NSDictionary *backup in objectStateBackupArray) {
			NSString *name = [backup objectForKey:@"name"];
			_SPExportListItem *item = [self schemaObjectNamed:name]; //find the new list item for the old name

			if(item) {
				id savedState = [backup objectForKey:@"savedState"];
				[[self currentExportHandler] applySpecificSettings:savedState forSchemaObject:item];
			}
		}
	}

	// reload again after restoring state from backup
	[exportTableList reloadData];

	[objectStateBackupArray release];
}

/**
 * Selects or de-selects all tables.
 */
- (IBAction)selectDeselectAllTables:(id)sender
{/*
	// Determine whether the structure and drop items should also be toggled
	if (exportType == SPSQLExport) {
		if ([exportSQLIncludeStructureCheck state]) toggleStructure = YES;
		if ([exportSQLIncludeDropSyntaxCheck state]) toggleDropTable = YES;
	}

	for (NSMutableArray *table in tables)
	{
		if (toggleStructure) [table replaceObjectAtIndex:1 withObject:[NSNumber numberWithBool:[sender tag]]];

		[table replaceObjectAtIndex:2 withObject:[NSNumber numberWithBool:[sender tag]]];

		if (toggleDropTable) [table replaceObjectAtIndex:3 withObject:[NSNumber numberWithBool:[sender tag]]];
	}
	*/
	
	// if there currently is a selection of more than one item let's assume the user wants to
	// toggle the selected items instead of all items.
	id<SPExportHandlerInstance> handler = [self currentExportHandler];
	NSIndexSet *selection = [exportTableList selectedRowIndexes];
	if([selection count] > 1 && [handler respondsToSelector:@selector(updateIncludeState:forSchemaObject:)]) {
		[selection enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
			[handler updateIncludeState:([sender tag] == 1) forSchemaObject:[exportObjectList objectAtIndex:idx]];
		}];
	}
	else {
		[handler updateIncludeStateForAllSchemaObjects:([sender tag] == 1)];
	}

	[exportTableList reloadData];

//	[self _toggleExportButtonOnBackgroundThread];
}

/**
 * Updates the default filename extenstion based on the selected output compression format.
 */
- (IBAction)changeExportCompressionFormat:(id)sender
{
	[self updateDisplayedExportFilename];
}

/**
 * Toggles the state of the custom filename format token fields.
 */
- (IBAction)toggleCustomFilenameFormatView:(id)sender
{
	showCustomFilenameView = (!showCustomFilenameView);

	[exportCustomFilenameViewButton setState:showCustomFilenameView];
	[exportFilenameDividerBox setHidden:showCustomFilenameView];
	[exportCustomFilenameView setHidden:(!showCustomFilenameView)];

	[self _resizeWindowForCustomFilenameViewByHeightDelta:(showCustomFilenameView) ? [exportCustomFilenameView frame].size.height : 0];
}

/**
 * Toggles the display of the advanced options box.
 */
- (IBAction)toggleAdvancedExportOptionsView:(id)sender
{
	showAdvancedView = (!showAdvancedView);

	[exportAdvancedOptionsViewButton setState:showAdvancedView];
	[exportAdvancedOptionsView setHidden:(!showAdvancedView)];

	[self _updateExportAdvancedOptionsLabel];
	[self _resizeWindowForAdvancedOptionsViewByHeightDelta:(showAdvancedView) ? ([exportAdvancedOptionsView frame].size.height + 10) : 0];
}

/**
 * Opens the export sheet, selecting [sender tag] as the export source.
 */
- (IBAction)exportFromMenuItem:(id)sender
{
	SPExportSource source = (SPExportSource)[sender tag];
	NSArray *tables = nil;

	if(source == SPTableExport) {
		// since this method would most likely be called from the tables list context or gear menu
		// we can assume that what the user wants is to export the current selected item.
		tables = [tablesListInstance selectedTableItems];
	}

	[self exportTables:tables asFormat:[sender representedObject] usingSource:source];
}

- (void)addExportHandlersToMenu:(NSMenu *)parent forSource:(SPExportSource)source
{
	[self window]; //export handlers is populated in awakeFromNib when our window is loaded

	for(NSString *name in [exportHandlers allKeys]) {
		id<SPExportHandlerInstance> instance = [exportHandlers objectForKey:name];

		// don't add them if they can't handle that mode
		if(![[instance factory] supportsExportSource:source]) continue;

		NSString *title = [NSString stringWithFormat:NSLocalizedString(@"%@…", @"export handler menu item"), [[instance factory] localizedShortName]];

		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(exportFromMenuItem:) keyEquivalent:@""];
		[item setTag:source];
		[item setRepresentedObject:name];
		[item setTarget:self];

		[parent addItem:[item autorelease]];
	}
}
#pragma mark -

#pragma mark Other

/**
 * Invoked when the user dismisses the export dialog. Starts the export process if required.
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	// Perform the export
	if (returnCode == NSOKButton) {

		[prefs setObject:[self currentSettingsAsDictionary] forKey:SPLastExportSettings];

		// If we are about to perform a table export, cache the current number of tables within the list,
		// refresh the list and then compare the numbers to accommodate situations where new tables are
		// added by external applications.
		if (exportSource == SPTableExport) {

			// Give the export sheet a chance to close
			[self performSelector:@selector(_checkForDatabaseChanges) withObject:nil afterDelay:0.5];
		}
		else {
			// Initialize the export after a short delay to give the alert a chance to close
			[self performSelector:@selector(initializeExportUsingSelectedOptions) withObject:nil afterDelay:0.5];
		}
	}
}

- (void)tableListChangedAlertDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	// Perform the export ignoring the new tables
	if (returnCode == NSOKButton) {

		// Initialize the export after a short delay to give the alert a chance to close
		[self performSelector:@selector(initializeExportUsingSelectedOptions) withObject:nil afterDelay:0.5];
	}
	else {
		// Cancel the export and redisplay the export dialog after a short delay
		[self performSelector:@selector(_reopenAndUpdateTables) withObject:nil afterDelay:0.5];
	}
}

- (void)_reopenAndUpdateTables
{
	[self _reopenExportSheet];
	// we just fetched everything to display the warning. No need to do it right again
	[self _refreshTableListKeepingState:YES fromServer:NO];
}

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(exportFromMenuItem:)) {
		SPExportSource source = (SPExportSource)[menuItem tag];
		id<SPExportHandlerInstance> handler = [exportHandlers objectForKey:[menuItem representedObject]];

		if([tableDocumentInstance isProcessing] || !handler) return NO;

		if(source == SPTableExport) {
			// special case for table export:
			// Normally table export is valid as soon as a DB is selected (doesn't matter if it has items or not).
			// However this particular method is usually called for the tables list context or gear menus which
			// suggest there has to be a selection for export.
			NSArray *selectedTypes = [tablesListInstance selectedTableTypes];

			for (NSNumber *type in selectedTypes) {
				if ([handler canExportSchemaObjectsOfType:(SPTableType) [type integerValue]]) return YES;
			}

			return NO;
		}

		return ([self _hasDataForSource:source handler:handler]);
	}

	return YES;
}

- (NSString *)exportPath
{
	return [exportPathField stringValue];
}
#pragma mark -

#pragma mark Private API

/**
 * Changes the selected export format and updates the UI accordingly.
 */
- (void)_switchTab
{
	// NSObject because KVO methods are not defined for id
	NSObject<SPExportHandlerInstance> *oldHandler = [self currentExportHandler];
	NSString *handlerName = [[exportTypeTabBar selectedTabViewItem] identifier];
	NSObject<SPExportHandlerInstance> *newHandler = [exportHandlers objectForKey:handlerName];

	if(oldHandler != newHandler) {
		//remove old KVO listeners
		if(oldHandler) {

			[oldHandler removeObserver:self forKeyPath:@"fileExtension" context:&_KVOContext];
			[oldHandler removeObserver:self forKeyPath:@"tableColumns"  context:&_KVOContext];

			[[NSNotificationCenter defaultCenter] removeObserver:self
			                                                name:SPExportHandlerSchemaObjectTypeSupportChangedNotification
			                                              object:oldHandler];

		}

		[self setCurrentExportHandler:newHandler];

		if(newHandler) {
			if([newHandler respondsToSelector:@selector(willBecomeActive)]) {
				[newHandler willBecomeActive];
			}

			[accessoryViewContainer setContentView:[[newHandler accessoryViewController] view]];

			// update the list of supported exportSources for this handler
			SPExportSource sources[] = {SPFilteredExport, SPQueryExport, SPTableExport, SPDatabaseExport};
			for (unsigned int i = 0; i < COUNT_OF(sources); ++i) {
				SPExportSource src = sources[i];
				// Hide items which are not supported and disable supported items if there is no data for them.
				// Note that _hasDataForSource:handler: will also return NO if the handler does not support src.
				// This is required by some other validation logic which checks if an item is enabled.
				[[[exportInputPopUpButton menu] itemWithTag:src] setHidden:(![[newHandler factory] supportsExportSource:src])];
				[[[exportInputPopUpButton menu] itemWithTag:src] setEnabled:([self _hasDataForSource:src handler:newHandler])];
			}

			//update the selected source to actually fit the new handler
			[self setExportSourceIfPossible:[self exportSource]]; //try to keep the prev. source if possible

			// the call above will have updated the table layout and contents already

			//we have to subscribe to some KVO notifications for the export handler, to act on changes
			[newHandler addObserver:self forKeyPath:@"fileExtension" options:0 context:&_KVOContext];
			[newHandler addObserver:self forKeyPath:@"tableColumns"  options:0 context:&_KVOContext];

			[[NSNotificationCenter defaultCenter] addObserver:self
			                                         selector:@selector(_supportedExportTypesChangedNotification:)
			                                             name:SPExportHandlerSchemaObjectTypeSupportChangedNotification
			                                           object:newHandler];

			[self _displayExportTypeOptions:([accessoryViewContainer contentView] != nil)];
		}
	}


//	return; //TODO
//
//	// Selected export format
//	NSString *type = [[[exportTypeTabBar selectedTabViewItem] identifier] lowercaseString];
//
//	// Determine the export type
//	exportType = [exportTypeTabBar indexOfTabViewItemWithIdentifier:type];
//
//	// Determine what data to use (filtered result, custom query result or selected table(s)) for the export operation
//	[self setExportSource:((exportType == SPDotExport) ? SPTableExport : [exportInputPopUpButton selectedTag])];
//
//
//	BOOL isSQL  = (exportType == SPSQLExport);
//	BOOL isCSV  = (exportType == SPCSVExport);
//	BOOL isXML  = (exportType == SPXMLExport);
//	//BOOL isHTML = (exportType == SPHTMLExport);
//	//BOOL isPDF  = (exportType == SPPDFExport);
//	BOOL isDot  = (exportType == SPDotExport);
//
//	BOOL enable = (isCSV || isXML /* || isHTML || isPDF  */ || isDot);
//

//
//	[[exportTableList tableColumnWithIdentifier:SPTableViewStructureColumnID] setHidden:(isSQL) ? (![exportSQLIncludeStructureCheck state]) : YES];
//	[[exportTableList tableColumnWithIdentifier:SPTableViewDropColumnID] setHidden:(isSQL) ? (![exportSQLIncludeDropSyntaxCheck state]) : YES];
//
//
//
//	[self updateAvailableExportFilenameTokens];
//
//	[self updateDisplayedExportFilename];
}

- (void)_supportedExportTypesChangedNotification:(NSNotification *)notification
{
	[self _evaluateShownObjectTypes];
	[self updateAvailableExportFilenameTokens]; // can have effects on whether the table token is allowed or not
}

- (void)_evaluateShownObjectTypes
{
	//remove all previous objects
	[exportObjectList removeAllObjects];

	// This list is only valid for table export mode
	// Also any exportHandler that does not support table exports might not have the methods called below.
	if([self exportSource] != SPTableExport) goto after_update;

	//add tables and views if supported
	BOOL supportsTables = [[self currentExportHandler] canExportSchemaObjectsOfType:SPTableTypeTable];
	BOOL supportsViews  = [[self currentExportHandler] canExportSchemaObjectsOfType:SPTableTypeView];
	if(supportsTables || supportsViews) {
		// mix tables and views together in an array so we can sort them
		NSMutableArray *tablesAndViews = [NSMutableArray array];
		if(supportsTables) {
			for(NSString *table in [tablesListInstance allTableNames]) {
				[tablesAndViews addObject:MakeExportListItem(SPTableTypeTable,table)];
			}
		}
		if(supportsViews) {
			for(NSString *view in [tablesListInstance allViewNames]) {
				[tablesAndViews addObject:MakeExportListItem(SPTableTypeView,view)];
			}
		}
		[tablesAndViews sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(id obj1, id obj2) {
			return [[(_SPExportListItem *)obj1 name] localizedCaseInsensitiveCompare:[(_SPExportListItem *)obj2 name]];
		}];
		//copy it over
		if([tablesAndViews count]) {
			NSString *title;
			if(supportsTables && supportsViews) title = NSLocalizedString(@"Tables & Views",@"export : items : group header");
			else if(supportsTables)             title = NSLocalizedString(@"Tables",@"export : items : group header");
			else                                title = NSLocalizedString(@"Views",@"export : items : group header");
			//header
			_SPExportListItem *header = MakeExportListItem(SPTableTypeNone,title);
			[header setIsGroupRow:YES];
			[exportObjectList addObject:header];
			[exportObjectList addObjectsFromArray:tablesAndViews];
		}
	}

	//add funcs and procs if supported
	BOOL supportsFuncs = [[self currentExportHandler] canExportSchemaObjectsOfType:SPTableTypeFunc];
	BOOL supportsProcs = [[self currentExportHandler] canExportSchemaObjectsOfType:SPTableTypeProc];
	if(supportsFuncs || supportsProcs) {
		// mix Funcs and Procs together in an array so we can sort them
		NSMutableArray *funcsAndProcs = [NSMutableArray array];
		if(supportsFuncs) {
			for(NSString *func in [tablesListInstance allFunctionNames]) {
				[funcsAndProcs addObject:MakeExportListItem(SPTableTypeFunc,func)];
			}
		}
		if(supportsProcs) {
			for(NSString *proc in [tablesListInstance allProcedureNames]) {
				[funcsAndProcs addObject:MakeExportListItem(SPTableTypeProc,proc)];
			}
		}
		[funcsAndProcs sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(id obj1, id obj2) {
			return [[(_SPExportListItem *)obj1 name] localizedCaseInsensitiveCompare:[(_SPExportListItem *)obj2 name]];
		}];
		//copy it over
		if([funcsAndProcs count]) {
			NSString *title;
			if(supportsFuncs && supportsProcs) title = NSLocalizedString(@"Funcs & Procs",@"export : items : group header");
			else if(supportsFuncs)             title = NSLocalizedString(@"Funcs",@"export : items : group header");
			else                               title = NSLocalizedString(@"Procs",@"export : items : group header");
			//header
			_SPExportListItem *header = MakeExportListItem(SPTableTypeNone,title);
			[header setIsGroupRow:YES];
			[exportObjectList addObject:header];
			[exportObjectList addObjectsFromArray:funcsAndProcs];
		}
	}

	//add events if supported
	if([[self currentExportHandler] canExportSchemaObjectsOfType:SPTableTypeEvent]) {
		NSMutableArray *events = [NSMutableArray array];
		for(NSString *event in [tablesListInstance allEventNames]) {
			[events addObject:MakeExportListItem(SPTableTypeEvent,event)];
		}
		[events sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(id obj1, id obj2) {
			return [[(_SPExportListItem *)obj1 name] localizedCaseInsensitiveCompare:[(_SPExportListItem *)obj2 name]];
		}];
		if([events count]) {
			_SPExportListItem *header = MakeExportListItem(SPTableTypeNone,NSLocalizedString(@"Events",@"export : items : group header"));
			[header setIsGroupRow:YES];
			[exportObjectList addObject:header];
			[exportObjectList addObjectsFromArray:events];
		}
	}

after_update:
	[[NSNotificationCenter defaultCenter] postNotificationName:SPExportControllerSchemaObjectsChangedNotification object:self];
	//tell the table view to reload
	[exportTableList reloadData];
}

//rebuild the table to fit the current export handler
- (void)_rebuildTableGeometry
{
	[exportObjectList removeAllObjects]; //can't use that anymore
	[exportTableList reloadData]; // otherwise the table view will think it still has rows during the calls below

	//remove all columns (copy or we'd get a concurrent modification exception)
	for(NSTableColumn *col in [[[exportTableList tableColumns] copy] autorelease]) {
		// keep the name column, but hide it for now, so the table looks empty on early return below
		if([[col identifier] isEqualToString:@"name"]) {
			[col setHidden:YES];
			continue;
		}
		[exportTableList removeTableColumn:col];
	}

	BOOL isTableExport = ([self exportSource] == SPTableExport);
	BOOL handlerSupportCheckAll = [[self currentExportHandler] respondsToSelector:@selector(updateIncludeStateForAllSchemaObjects:)];
	[exportTableList setEnabled:isTableExport];
	[exportSelectAllTablesButton setEnabled:(isTableExport && handlerSupportCheckAll)];
	[exportDeselectAllTablesButton setEnabled:(isTableExport && handlerSupportCheckAll)];
	[exportRefreshTablesButton setEnabled:isTableExport];
	//it's easy if our current export source is not based on the table list
	if(!isTableExport) return;

	//unhide the name column
	[[exportTableList tableColumnWithIdentifier:@"name"] setHidden:NO];

	//all the others can be configured by the export handler
	for(NSString *colId in [[self currentExportHandler] tableColumns]) {
		NSAssert(([colId length]) && ([exportTableList tableColumnWithIdentifier:colId] == nil),@"The column id <%@> is either empty/nil or a duplicate!",colId);
		NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:colId];
		[[self currentExportHandler] configureTableColumn:col];
		[exportTableList addTableColumn:[col autorelease]];
	}

}

/**
 * Checks for changes in the current database, by refreshing the table list and warning the user if required.
 */
- (void)_checkForDatabaseChanges
{
	NSUInteger i = 0;
	// count everything that is not a group row
	for(_SPExportListItem *item in exportObjectList) {
		if(![item isGroupRow]) i++;
	}

	[tablesListInstance updateTables:self];

	struct _addIfListItem {
		SPTableType type;
		NSUInteger count;
	};

	struct _addIfListItem addIfList[] = {
		{SPTableTypeTable, [[tablesListInstance allTableNames] count]},
		{SPTableTypeView,  [[tablesListInstance allViewNames] count]},
		{SPTableTypeFunc,  [[tablesListInstance allFunctionNames] count]},
		{SPTableTypeProc,  [[tablesListInstance allProcedureNames] count]},
		{SPTableTypeEvent, [[tablesListInstance allEventNames] count]},
	};

	NSUInteger j = 0;
	for (unsigned int k = 0; k < COUNT_OF(addIfList); ++k) {
		struct _addIfListItem *item = &addIfList[k];
		if([[self currentExportHandler] canExportSchemaObjectsOfType:item->type]) j += item->count;
	}

	if (j > i) {
		NSUInteger diff = j - i;

		SPBeginAlertSheet(NSLocalizedString(@"The list of tables has changed", @"table list change alert message"),
						  NSLocalizedString(@"Continue", @"continue button"),
						  NSLocalizedString(@"Cancel", @"cancel button"), nil, [tableDocumentInstance parentWindow], self,
						  @selector(tableListChangedAlertDidEnd:returnCode:contextInfo:), NULL,
						  [NSString stringWithFormat:NSLocalizedString(@"The number of tables in this database has changed since the export dialog was opened. There are now %d additional table(s), most likely added by an external application.\n\nHow would you like to proceed?", @"table list change alert informative message"), diff]);
	}
	else {
		[self initializeExportUsingSelectedOptions];
	}
}

/**
 * Toggles the display of the export type options view.
 *
 * @param display A BOOL indicating whether or not the view should be visible
 */
- (void)_displayExportTypeOptions:(BOOL)display
{
	NSRect windowFrame = [[exportTablelistScrollView window] frame];
	NSRect viewFrame   = [exportTablelistScrollView frame];
	NSRect barFrame    = [exportTableListButtonBar frame];

	NSUInteger padding = (2 * SPExportUIPadding);

	CGFloat width  = (!display) ? (windowFrame.size.width - (padding + 2)) : (windowFrame.size.width - ([accessoryViewContainer frame].size.width + (padding + 4)));

	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:0.3];

	[[accessoryViewContainer animator] setHidden:(!display)];
	[[exportTablelistScrollView animator] setFrame:NSMakeRect(viewFrame.origin.x, viewFrame.origin.y, width, viewFrame.size.height)];
	[[exportTableListButtonBar animator] setFrame:NSMakeRect(barFrame.origin.x, barFrame.origin.y, width, barFrame.size.height)];

	[NSAnimationContext endGrouping];
}

/**
 * Update the export advanced options label to show a summary if the options are hidden.
 */
- (void)_updateExportAdvancedOptionsLabel
{
	if (showAdvancedView) {
		[exportAdvancedOptionsViewLabelButton setTitle:NSLocalizedString(@"Advanced", @"Advanced options short title")];
		return;
	}

	NSMutableArray *optionsSummary = [NSMutableArray array];

	if ([exportProcessLowMemoryButton state]) {
		[optionsSummary addObject:NSLocalizedString(@"Low memory", @"Low memory export summary")];
	}
	else {
		[optionsSummary addObject:NSLocalizedString(@"Standard memory", @"Standard memory export summary")];
	}

	if ([exportOutputCompressionFormatPopupButton indexOfSelectedItem] == SPNoCompression) {
		[optionsSummary addObject:NSLocalizedString(@"no compression", @"No compression export summary - within a sentence")];
	}
	else if ([exportOutputCompressionFormatPopupButton indexOfSelectedItem] == SPGzipCompression) {
		[optionsSummary addObject:NSLocalizedString(@"Gzip compression", @"Gzip compression export summary - within a sentence")];
	}
	else if ([exportOutputCompressionFormatPopupButton indexOfSelectedItem] == SPBzip2Compression) {
		[optionsSummary addObject:NSLocalizedString(@"bzip2 compression", @"bzip2 compression export summary - within a sentence")];
	}

	[exportAdvancedOptionsViewLabelButton setTitle:[NSString stringWithFormat:@"%@ (%@)", NSLocalizedString(@"Advanced", @"Advanced options short title"), [optionsSummary componentsJoinedByString:@", "]]];
}

/**
 * Enables or disables the export button based on the state of various interface controls.
 *
 * @param uiStateDict A dictionary containing the state of various UI controls.
 */
- (void)_toggleExportButton:(id)uiStateDict
{
	/*
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	BOOL enable = NO;

	BOOL isSQL  = (exportType == SPSQLExport);
	BOOL isCSV  = (exportType == SPCSVExport);
	BOOL isHTML = (exportType == SPHTMLExport);
	BOOL isPDF  = (exportType == SPPDFExport);

	BOOL structureEnabled = [[uiStateDict objectForKey:SPSQLExportStructureEnabled] boolValue];
	BOOL contentEnabled   = [[uiStateDict objectForKey:SPSQLExportContentEnabled] boolValue];
	BOOL dropEnabled      = [[uiStateDict objectForKey:SPSQLExportDropEnabled] boolValue];

	if (isCSV || isHTML || isPDF || (isSQL && ((!structureEnabled) || (!dropEnabled)))) {
		enable = NO;

		// Only enable the button if at least one table is selected
		for (NSArray *table in tables)
		{
			if ([NSArrayObjectAtIndex(table, 2) boolValue]) {
				enable = YES;
				break;
			}
		}
	}
	else if (isSQL) {

		// Disable if all are unchecked
		if ((!contentEnabled) && (!structureEnabled) && (!dropEnabled)) {
			enable = NO;
		}
		// If they are all checked, check to see if any of the tables are checked
		else if (contentEnabled && structureEnabled && dropEnabled) {

			// Only enable the button if at least one table is selected
			for (NSArray *table in tables)
			{
				if ([NSArrayObjectAtIndex(table, 1) boolValue] ||
					[NSArrayObjectAtIndex(table, 2) boolValue] ||
					[NSArrayObjectAtIndex(table, 3) boolValue])
				{
					enable = YES;
					break;
				}
			}
		}
		// Disable if structure is unchecked, but content and drop are as dropping a
		// table then trying to insert into it is obviously an error.
		else if (contentEnabled && (!structureEnabled) && (dropEnabled)) {
			enable = NO;
		}
		else {
			enable = (contentEnabled || (structureEnabled || dropEnabled));
		}
	}

	[self performSelectorOnMainThread:@selector(_toggleExportButtonWithBool:) withObject:[NSNumber numberWithBool:enable] waitUntilDone:NO];

	[pool release];
	 */
}

/**
 * Calls the above method on a background thread to determine whether or not the export button should be enabled.
 */
- (void)_toggleExportButtonOnBackgroundThread
{
	/*
	NSMutableDictionary *uiStateDict = [[NSMutableDictionary alloc] init];

	[uiStateDict setObject:[NSNumber numberWithInteger:[exportSQLIncludeStructureCheck state]] forKey:SPSQLExportStructureEnabled];
	[uiStateDict setObject:[NSNumber numberWithInteger:[exportSQLIncludeContentCheck state]] forKey:SPSQLExportContentEnabled];
	[uiStateDict setObject:[NSNumber numberWithInteger:[exportSQLIncludeDropSyntaxCheck state]] forKey:SPSQLExportDropEnabled];

	[NSThread detachNewThreadWithName:SPCtxt(@"SPExportController export button updater",tableDocumentInstance) target:self selector:@selector(_toggleExportButton:) object:uiStateDict];

	[uiStateDict release];
	 */
}

/**
 * Enables or disables the export button based on the supplied number (boolean).
 *
 * @param enable A boolean indicating the state.
 */
- (void)_toggleExportButtonWithBool:(NSNumber *)enable
{
	/*
	[exportButton setEnabled:[enable boolValue]];
	 */
}

/**
 * Will check if there currently is any data which can be used with this export type
 */
- (BOOL)_hasDataForSource:(SPExportSource)src
{
	return [self _hasDataForSource:src handler:[self currentExportHandler]];
}

- (BOOL)_hasDataForSource:(SPExportSource)src handler:(id<SPExportHandlerInstance>)handler
{
	//if the handler can't use this source there is never data available
	if(![[handler factory] supportsExportSource:src]) return NO;

	switch(src) {
		// requires a db to be selected
		case SPDatabaseExport:
		case SPTableExport:
			return ([[tableDocumentInstance database] length] > 0);

		// requires a custom query result
		// Note that the result count check is always greater than one as the first row is always the field names
		case SPQueryExport:
			return ([[customQueryInstance currentResult] count] > 1);

		// requires a loaded table
		case SPFilteredExport:
			return ([[tableContentInstance currentResult] count] > 1);

	}
	return NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	//messages without our context don't go to us, but maybe a superclass wants them
	if(context != &_KVOContext) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}

	//if the file extension changed we need to update the preview
	if([keyPath isEqualToString:@"fileExtension"]) {
		[self updateDisplayedExportFilename];
	}

	// the "table" token is not allowed in "export to multiple files" mode
	if([keyPath isEqualToString:@"exportToMultipleFiles"]) {
		[self updateAvailableExportFilenameTokens];
	}

	// this basically means the layout of the table view needs to be rebuilt
	if([keyPath isEqualToString:@"tableColumns"]) {
		[self _rebuildTableGeometry];
		[self _evaluateShownObjectTypes]; // as a consequence
	}
}

#pragma mark -

- (void)dealloc
{
    SPClear(exportObjectList);
	SPClear(exporters);
	SPClear(exportFiles);
	SPClear(operationQueue);
	SPClear(localizedTokenNames);
	SPClear(previousConnectionEncoding);
	[self setServerSupport:nil];
	SPClear(exportHandlers);
	SPClear(hiddenTabViewStorage);
	SPClear(exportTypeLabel);

	[super dealloc];
}
@end

#pragma mark -

@implementation _SPExportListItem

@synthesize isGroupRow;
@synthesize type;
@synthesize name;
@synthesize addonData;

@end

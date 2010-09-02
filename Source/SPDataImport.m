//
//  $Id$
//
//  SPDataImport.m
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

#import "SPDataImport.h"
#import "SPDatabaseDocument.h"
#import "SPTablesList.h"
#import "SPTableStructure.h"
#import "SPTableContent.h"
#import "SPCustomQuery.h"
#import "SPGrowlController.h"
#import "SPSQLParser.h"
#import "SPCSVParser.h"
#import "SPTableData.h"
#import "SPStringAdditions.h"
#import "SPArrayAdditions.h"
#import "RegexKitLite.h"
#import "SPConstants.h"
#import "SPAlertSheets.h"
#import "SPFieldMapperController.h"
#import "SPMainThreadTrampoline.h"
#import "SPNotLoaded.h"
#import "SPFileHandle.h"
#import "SPEncodingPopupAccessory.h"
#import <UniversalDetector/UniversalDetector.h>

@interface SPDataImport (PrivateAPI)

- (void) _importBackgroundProcess:(NSString *)filename;
- (void) _resetFieldMappingGlobals;

@end

@implementation SPDataImport

#pragma mark -
#pragma mark Initialisation

/**
 * Init.
 */
- (id)init
{
	if ((self = [super init])) {
		
		nibObjectsToRelease = [[NSMutableArray alloc] init];
		fieldMappingArray = nil;
		fieldMappingGlobalValueArray = nil;
		fieldMappingTableColumnNames = nil;
		fieldMappingTableDefaultValues = nil;
		fieldMappingImportArray = nil;
		csvImportTailString = nil;
		csvImportHeaderString = nil;
		csvImportMethodHasTail = NO;
		fieldMappingImportArrayIsPreview = NO;
		fieldMappingArrayHasGlobalVariables = NO;
		importMethodIsUpdate = NO;
		insertRemainingRowsAfterUpdate = NO;
		numberOfImportDataColumns = 0;
		
		prefs = nil;
		lastFilename = nil;
		_mainNibLoaded = NO;
	}
	
	return self;
}

/**
 * UI setup.
 */
- (void)awakeFromNib
{
	if (_mainNibLoaded) return;
	_mainNibLoaded = YES;
	
	// Load the import accessory view, retaining a reference to the top-level objects that need releasing.
	NSArray *importAccessoryTopLevelObjects = nil;
	NSNib *nibLoader = [[NSNib alloc] initWithNibNamed:@"ImportAccessory" bundle:[NSBundle mainBundle]];
	[nibLoader instantiateNibWithOwner:self topLevelObjects:&importAccessoryTopLevelObjects];
	[nibObjectsToRelease addObjectsFromArray:importAccessoryTopLevelObjects];
	[nibLoader release];

	// Set up the encodings menu
	NSMutableArray *encodings = [NSMutableArray arrayWithArray:[SPEncodingPopupAccessory enabledEncodings]];
	[importEncodingPopup removeAllItems];
	[importEncodingPopup addItemWithTitle:NSLocalizedString(@"Autodetect", @"Encoding autodetect menu item")];
	[[importEncodingPopup menu] addItem:[NSMenuItem separatorItem]];
	for (NSNumber *encodingNumber in encodings) {
		[importEncodingPopup addItemWithTitle:[NSString localizedNameOfStringEncoding:[encodingNumber unsignedIntegerValue]]];
		[[importEncodingPopup lastItem] setTag:[encodingNumber unsignedIntegerValue]];
	}
}

#pragma mark -
#pragma mark IBAction methods

/**
 * Shows/hides the CSV options accessory view based on the selected format.
 */
- (IBAction)changeFormat:(id)sender
{
	[importCSVBox setHidden:![[[importFormatPopup selectedItem] title] isEqualToString:@"CSV"]];
}

/**
 * Cancels the current operation.
 */
- (IBAction)cancelProgressBar:(id)sender
{
	progressCancelled = YES;
}

/**
 * Common method for ending modal sessions
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

/**
 * Convenience method for closing and restoring the progress sheet to default state.
 */
- (void)closeAndStopProgressSheet
{
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(closeAndStopProgressSheet) withObject:nil waitUntilDone:YES];
		return;
	}

	[NSApp endSheet:singleProgressSheet];
	[singleProgressSheet orderOut:nil];
	[[singleProgressBar onMainThread] stopAnimation:self];
	[[singleProgressBar onMainThread] setMaxValue:100];
}

#pragma mark -
#pragma mark Import construction methods

/**
 * Invoked when user clicks on an ImportFromClipboard menuitem.
 */
- (void)importFromClipboard
{

	// clipboard textview with no wrapping
	const CGFloat LargeNumberForText = 1.0e7;
	[[importFromClipboardTextView textContainer] setContainerSize:NSMakeSize(LargeNumberForText, LargeNumberForText)];
	[[importFromClipboardTextView textContainer] setWidthTracksTextView:NO];
	[[importFromClipboardTextView textContainer] setHeightTracksTextView:NO];
	[importFromClipboardTextView setAutoresizingMask:NSViewNotSizable];
	[importFromClipboardTextView setMaxSize:NSMakeSize(LargeNumberForText, LargeNumberForText)];
	[importFromClipboardTextView setHorizontallyResizable:YES];
	[importFromClipboardTextView setVerticallyResizable:YES];
	[importFromClipboardTextView setFont:[NSFont fontWithName:@"Monaco" size:11.0f]];
	
	if([[[NSPasteboard generalPasteboard] stringForType:NSStringPboardType] length] > 4000)
		[importFromClipboardTextView setString:[[[[NSPasteboard generalPasteboard] stringForType:NSStringPboardType] substringToIndex:4000] stringByAppendingString:@"\n…"]];
	else
		[importFromClipboardTextView setString:[[NSPasteboard generalPasteboard] stringForType:NSStringPboardType]];

	// Preset the accessory view with prefs defaults
	[importFieldsTerminatedField setStringValue:[prefs objectForKey:SPCSVImportFieldTerminator]];
	[importLinesTerminatedField setStringValue:[prefs objectForKey:SPCSVImportLineTerminator]];
	[importFieldsEscapedField setStringValue:[prefs objectForKey:SPCSVImportFieldEscapeCharacter]];
	[importFieldsEnclosedField setStringValue:[prefs objectForKey:SPCSVImportFieldEnclosedBy]];
	[importFieldNamesSwitch setState:[[prefs objectForKey:SPCSVImportFirstLineIsHeader] boolValue]];

	// Reset and disable the encoding menu
	[importEncodingPopup selectItemWithTag:NSUTF8StringEncoding];
	[importEncodingPopup setEnabled:NO];

	// Add the view, and resize it to fit the accessory view size
	[importFromClipboardAccessoryView addSubview:importCSVView];
	NSRect accessoryViewRect = [importFromClipboardAccessoryView frame];
	[importCSVView setFrame:NSMakeRect(0, 0, accessoryViewRect.size.width, accessoryViewRect.size.height)];

	[NSApp beginSheet:importFromClipboardSheet
	   modalForWindow:[tableDocumentInstance parentWindow]
		modalDelegate:self
	   didEndSelector:@selector(importFromClipboardSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

/**
 * Callback when the import from clipback sheet is closed
 */
- (void)importFromClipboardSheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{

	// Reset the interface and store prefs
	[importFromClipboardTextView setString:@""];
	[prefs setObject:[[importFormatPopup selectedItem] title] forKey:@"importFormatPopupValue"];

	// Check if the user canceled
	if (returnCode != NSOKButton)
		return;

	// Reset progress cancelled from any previous runs
	progressCancelled = NO;

	NSString *importFileName = [NSString stringWithFormat:@"%@%@",
									SPImportClipboardTempFileNamePrefix, 
									[[NSDate  date] descriptionWithCalendarFormat:@"%H%M%S" 
											timeZone:nil 
											locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]]];

	// Write clipboard content to temp file using the connection encoding
	NSStringEncoding encoding;
	if ([[[importFormatPopup selectedItem] title] isEqualToString:@"SQL"])
		encoding = NSUTF8StringEncoding;
	else
		encoding = [mySQLConnection stringEncoding];

	if(![[[NSPasteboard generalPasteboard] stringForType:NSStringPboardType] writeToFile:importFileName atomically:NO encoding:encoding error:nil]) {
		NSBeep();
		NSLog(@"Couldn't write clipboard content to temporary file.");
		return;
	}

	if (importFileName == nil) return;

	// begin import process
	[NSThread detachNewThreadSelector:@selector(_importBackgroundProcess:) toTarget:self withObject:importFileName];
}


/**
 * Invoked when user clicks on an import menuitem.
 */
- (void)importFile
{
	// prepare open panel and accessory view
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];

	// Preset the accessory view with prefs defaults
	[importFieldsTerminatedField setStringValue:[prefs objectForKey:SPCSVImportFieldTerminator]];
	[importLinesTerminatedField setStringValue:[prefs objectForKey:SPCSVImportLineTerminator]];
	[importFieldsEscapedField setStringValue:[prefs objectForKey:SPCSVImportFieldEscapeCharacter]];
	[importFieldsEnclosedField setStringValue:[prefs objectForKey:SPCSVImportFieldEnclosedBy]];
	[importFieldNamesSwitch setState:[[prefs objectForKey:SPCSVImportFirstLineIsHeader] boolValue]];

	[openPanel setAccessoryView:importCSVView];
	[openPanel setDelegate:self];
	if ([prefs valueForKey:@"importFormatPopupValue"]) {
		[importFormatPopup selectItemWithTitle:[prefs valueForKey:@"importFormatPopupValue"]];
		[self changeFormat:self];
	}
	
	// Show openPanel
	[openPanel beginSheetForDirectory:[prefs objectForKey:@"openPath"]
								 file:[lastFilename lastPathComponent]
					   modalForWindow:[tableDocumentInstance parentWindow]
						modalDelegate:self
					   didEndSelector:@selector(importFileSheetDidEnd:returnCode:contextInfo:)
						  contextInfo:nil];
}

/**
 * Callback for when the import sheet is closed
 */
- (void)importFileSheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{

	// Save values to preferences
	[prefs setObject:[(NSOpenPanel*)sheet directory] forKey:@"openPath"];
	[prefs setObject:[[importFormatPopup selectedItem] title] forKey:@"importFormatPopupValue"];
	
	// Close NSOpenPanel sheet
	[sheet orderOut:self];

	// Check if the user canceled
	if (returnCode != NSOKButton)
		return;

	// Reset progress cancelled from any previous runs
	progressCancelled = NO;

	if(lastFilename) [lastFilename release]; lastFilename = nil;
	lastFilename = [[NSString stringWithString:[(NSOpenPanel*)sheet filename]] retain];

	NSString *importFileName = [NSString stringWithString:lastFilename];
	if (lastFilename == nil || ![lastFilename length]) {
		NSBeep();
		return;
	}

	if (importFileName == nil) return;

	// Begin the import process
	[NSThread detachNewThreadSelector:@selector(_importBackgroundProcess:) toTarget:self withObject:importFileName];
}

/**
 * Invoked when the user opens a large file, and when warned, chooses "Import".
 */
- (void)startSQLImportProcessWithFile:(NSString *)filename
{
	[importFormatPopup selectItemWithTitle:@"SQL"];
	[NSThread detachNewThreadSelector:@selector(_importBackgroundProcess:) toTarget:self withObject:filename];
}

#pragma mark -
#pragma mark SQL import

/**
 * Streaming data processing method to import a supplied SQL file.
 *
 * The file is read in chunk by chunk; each chunk is then checked
 * for line endings, which are used to split the data into parts
 * which can be parsed to NSStrings in the appropriate encoding.
 *
 * The NSStrings are then fed to a SQL parser, which splits them
 * into statements ready to be executed.
 */
- (void)importSQLFile:(NSString *)filename
{
	NSAutoreleasePool *importPool;
	SPFileHandle *sqlFileHandle;
	NSMutableData *sqlDataBuffer;
	const unsigned char *sqlDataBufferBytes;
	NSData *fileChunk;
	NSString *sqlString;
	SPSQLParser *sqlParser;
	NSString *query;
	NSMutableString *errors = [NSMutableString string];
	NSInteger fileChunkMaxLength = 1024 * 1024;
	NSUInteger fileTotalLength = 0;
	NSUInteger fileProcessedLength = 0;
	NSInteger queriesPerformed = 0;
	NSInteger dataBufferLength = 0;
	NSInteger dataBufferPosition = 0;
	NSInteger dataBufferLastQueryEndPosition = 0;
	BOOL fileIsCompressed;
	BOOL importSQLAsUTF8 = YES;
	BOOL allDataRead = NO;
	NSStringEncoding sqlEncoding = NSUTF8StringEncoding;
	NSString *connectionEncodingToRestore = nil;
	NSCharacterSet *whitespaceAndNewlineCharset = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	// Start the notification timer to allow notifications to be shown, even if frontmost, for long queries
	[[SPGrowlController sharedGrowlController] setVisibilityForNotificationName:@"Import Finished"];

	// Open a filehandle for the SQL file
	sqlFileHandle = [SPFileHandle fileHandleForReadingAtPath:filename];
	if (!sqlFileHandle) {
		SPBeginAlertSheet(NSLocalizedString(@"Import Error", @"Import Error title"),
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
						  NSLocalizedString(@"The SQL file you selected could not be found or read.", @"SQL file open error"));
		if([filename hasPrefix:SPImportClipboardTempFileNamePrefix])
			[[NSFileManager defaultManager] removeItemAtPath:filename error:nil];
		return;
	}
	fileIsCompressed = [sqlFileHandle isCompressed];

	// Grab the file length
	fileTotalLength = [[[[NSFileManager defaultManager] attributesOfItemAtPath:filename error:NULL] objectForKey:NSFileSize] longLongValue];
	if (!fileTotalLength) fileTotalLength = 1;

	// Reset progress interface
	[errorsView setString:@""];
	[[singleProgressTitle onMainThread] setStringValue:NSLocalizedString(@"Importing SQL", @"text showing that the application is importing SQL")];
	[[singleProgressText onMainThread] setStringValue:NSLocalizedString(@"Reading...", @"text showing that app is reading dump")];
	[[singleProgressBar onMainThread] setIndeterminate:NO];
	[[singleProgressBar onMainThread] setMaxValue:fileTotalLength];
	[[singleProgressBar onMainThread] setUsesThreadedAnimation:YES];
	[[singleProgressBar onMainThread] startAnimation:self];
				
	// Open the progress sheet
	[[NSApp onMainThread] beginSheet:singleProgressSheet modalForWindow:[tableDocumentInstance parentWindow] modalDelegate:self didEndSelector:nil contextInfo:nil];
	[[singleProgressSheet onMainThread] makeKeyWindow];

	[tableDocumentInstance setQueryMode:SPImportExportQueryMode];

	// Determine the file encoding.  The first item in the encoding menu is "Autodetect"; if
	// this is selected, attempt to detect the encoding of the file (using first 2.5MB).
	if (![importEncodingPopup indexOfSelectedItem]) {
		SPFileHandle *detectorFileHandle = [SPFileHandle fileHandleForReadingAtPath:filename];
		if (detectorFileHandle) {
			UniversalDetector *fileEncodingDetector = [[UniversalDetector alloc] init];
			[fileEncodingDetector analyzeData:[detectorFileHandle readDataOfLength:2500000]];
			sqlEncoding = [fileEncodingDetector encoding];
			[fileEncodingDetector release];
			if ([MCPConnection mySQLEncodingForStringEncoding:sqlEncoding]) {
				connectionEncodingToRestore = [mySQLConnection encoding];
				[mySQLConnection queryString:[NSString stringWithFormat:@"SET NAMES '%@'", [MCPConnection mySQLEncodingForStringEncoding:sqlEncoding]]];
			}
		}

	// Otherwise, get the encoding to use from the menu
	} else {
		sqlEncoding = [importEncodingPopup selectedTag];
	}

	// Read in the file in a loop
	sqlParser = [[SPSQLParser alloc] init];
	[sqlParser setDelimiterSupport:YES];
	sqlDataBuffer = [[NSMutableData alloc] init];
	importPool = [[NSAutoreleasePool alloc] init];
	while (1) {
		if (progressCancelled) break;

		@try {
			fileChunk = [sqlFileHandle readDataOfLength:fileChunkMaxLength];
		}

		// Report file read errors, and bail
		@catch (NSException *exception) {
			if (connectionEncodingToRestore) {
				[mySQLConnection queryString:[NSString stringWithFormat:@"SET NAMES '%@'", connectionEncodingToRestore]];
			}
			[self closeAndStopProgressSheet];
			SPBeginAlertSheet(NSLocalizedString(@"File read error", @"SQL read error title"),
							  NSLocalizedString(@"OK", @"OK button"),
							  nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when reading the file.\n\nOnly %ld queries were executed.\n\n(%@)", @"SQL read error, including detail from system"), (long)queriesPerformed, [exception reason]]);
			[sqlParser release];
			[sqlDataBuffer release];
			[importPool drain];
			[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
			if([filename hasPrefix:SPImportClipboardTempFileNamePrefix])
				[[NSFileManager defaultManager] removeItemAtPath:filename error:nil];
			return;
		}

		// If no data returned, end of file - set a marker to ensure full processing
		if (!fileChunk || ![fileChunk length]) {
			allDataRead = YES;

		// Otherwise add the data to the read/parse buffer
		} else {
			[sqlDataBuffer appendData:fileChunk];
		}

		// Step through the data buffer, identifying line endings to parse the data with
		sqlDataBufferBytes = [sqlDataBuffer bytes];
		dataBufferLength = [sqlDataBuffer length];
		for ( ; dataBufferPosition < dataBufferLength || allDataRead; dataBufferPosition++) {
			if (sqlDataBufferBytes[dataBufferPosition] == 0x0A || sqlDataBufferBytes[dataBufferPosition] == 0x0D || allDataRead) {

				// Keep reading through any other line endings
				while (dataBufferPosition + 1 < dataBufferLength
						&& (sqlDataBufferBytes[dataBufferPosition+1] == 0x0A
							|| sqlDataBufferBytes[dataBufferPosition+1] == 0x0D))
				{
					dataBufferPosition++;
				}

				// Try to generate a NSString with the resulting data
				sqlString = [[NSString alloc] initWithData:[sqlDataBuffer subdataWithRange:NSMakeRange(dataBufferLastQueryEndPosition, dataBufferPosition - dataBufferLastQueryEndPosition)]
												  encoding:sqlEncoding];
				if (!sqlString) {
					if (connectionEncodingToRestore) {
						[mySQLConnection queryString:[NSString stringWithFormat:@"SET NAMES '%@'", connectionEncodingToRestore]];
					}
					[self closeAndStopProgressSheet];
					NSString *displayEncoding;
					if (![importEncodingPopup indexOfSelectedItem]) {
						displayEncoding = [NSString stringWithFormat:@"%@ - %@", [importEncodingPopup titleOfSelectedItem], [NSString localizedNameOfStringEncoding:sqlEncoding]];
					} else {
						displayEncoding = [NSString localizedNameOfStringEncoding:sqlEncoding];
					}
					SPBeginAlertSheet(NSLocalizedString(@"File read error", @"SQL read error title"),
									  NSLocalizedString(@"OK", @"OK button"),
									  nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
									  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when reading the file, as it could not be read in the encoding you selected (%@).\n\nOnly %ld queries were executed.", @"SQL encoding read error"), displayEncoding, (long)queriesPerformed]);
					[sqlParser release];
					[sqlDataBuffer release];
					[importPool drain];
					[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
					if([filename hasPrefix:SPImportClipboardTempFileNamePrefix])
						[[NSFileManager defaultManager] removeItemAtPath:filename error:nil];
					return;
				}

				// Add the NSString segment to the SQL parser and release it
				[sqlParser appendString:sqlString];
				[sqlString release];

				if (allDataRead) break;

				// Increment the query end position marker
				dataBufferLastQueryEndPosition = dataBufferPosition;
			}
		}

		// Trim the data buffer if part of it was used
		if (dataBufferLastQueryEndPosition) {
			[sqlDataBuffer setData:[sqlDataBuffer subdataWithRange:NSMakeRange(dataBufferLastQueryEndPosition, dataBufferLength - dataBufferLastQueryEndPosition)]];
			dataBufferPosition -= dataBufferLastQueryEndPosition;
			dataBufferLastQueryEndPosition = 0;
		}
		
		// Before entering the following loop, check that we actually have a connection.
		// If not, check the connection if appropriate and then clean up and exit if appropriate.
		if (![mySQLConnection isConnected] && ([mySQLConnection userTriggeredDisconnect] || ![mySQLConnection checkConnection])) {
			if ([filename hasPrefix:SPImportClipboardTempFileNamePrefix])
				[[NSFileManager defaultManager] removeItemAtPath:filename error:nil];
			[self closeAndStopProgressSheet];
			[errors appendString:NSLocalizedString(@"The connection to the server was lost during the import.  The import is only partially complete.", @"Connection lost during import error message")];
			[self showErrorSheetWithMessage:errors];
			[sqlParser release];
			[sqlDataBuffer release];
			[importPool drain];
			return;
		}

		// Extract and process any complete SQL queries that can be found in the strings parsed so far
		while (query = [sqlParser trimAndReturnStringToCharacter:';' trimmingInclusively:YES returningInclusively:NO]) {
			if (progressCancelled) break;
			fileProcessedLength += [query lengthOfBytesUsingEncoding:sqlEncoding] + 1;

			// Ensure whitespace is removed from both ends, and normalise if necessary.
			if ([sqlParser containsCarriageReturns]) {
				query = [SPSQLParser normaliseQueryForExecution:query];
			} else {
				query = [query stringByTrimmingCharactersInSet:whitespaceAndNewlineCharset];
			}

			// Skip blank or whitespace-only queries to avoid errors
			if (![query length]) continue;
			
			// Run the query
			[mySQLConnection queryString:query usingEncoding:sqlEncoding streamingResult:NO];

			// Check for any errors
			if ([mySQLConnection queryErrored] && ![[mySQLConnection getLastErrorMessage] isEqualToString:@"Query was empty"]) {
				[errors appendFormat:NSLocalizedString(@"[ERROR in query %ld] %@\n", @"error text when multiple custom query failed"), (long)(queriesPerformed+1), [mySQLConnection getLastErrorMessage]];
			}

			// Increment the processed queries count
			queriesPerformed++;

			// Update the progress bar
			if (fileIsCompressed) {
				[singleProgressBar setDoubleValue:[sqlFileHandle realDataReadLength]];
				[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Imported %@ of SQL", @"SQL import progress text where total size is unknown"),
					[NSString stringForByteSize:fileProcessedLength]]];			
			} else {
				[singleProgressBar setDoubleValue:fileProcessedLength];
				[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Imported %@ of %@", @"SQL import progress text"),
					[NSString stringForByteSize:fileProcessedLength], [NSString stringForByteSize:fileTotalLength]]];
			}
		}
		
		// If all the data has been read, break out of the processing loop
		if (allDataRead) break;

		// Reset the autorelease pool
		[importPool drain];
		importPool = [[NSAutoreleasePool alloc] init];
	}

	// If any text remains in the SQL parser, it's an unterminated query - execute it.
	query = [sqlParser stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([query length] && !progressCancelled) {

		// Run the query
		[mySQLConnection queryString:query usingEncoding:sqlEncoding streamingResult:NO];

		// Check for any errors
		if ([mySQLConnection queryErrored] && ![[mySQLConnection getLastErrorMessage] isEqualToString:@"Query was empty"]) {
			[errors appendFormat:NSLocalizedString(@"[ERROR in query %ld] %@\n", @"error text when multiple custom query failed"), (long)(queriesPerformed+1), [mySQLConnection getLastErrorMessage]];
		}

		// Increment the processed queries count
		queriesPerformed++;
	}

	// Clean up
	if (connectionEncodingToRestore) {
		[mySQLConnection queryString:[NSString stringWithFormat:@"SET NAMES '%@'", connectionEncodingToRestore]];
	}
	[sqlParser release];
	[sqlDataBuffer release];
	[importPool drain];
	[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
	if([filename hasPrefix:SPImportClipboardTempFileNamePrefix])
		[[NSFileManager defaultManager] removeItemAtPath:filename error:nil];

	// Close progress sheet
	[self closeAndStopProgressSheet];

	// Display any errors
	if ([errors length]) {
		[self showErrorSheetWithMessage:errors];
	}

	// Update available databases
	[tableDocumentInstance setDatabases:self];

	// Update current selected database
	[[tableDocumentInstance onMainThread] refreshCurrentDatabase];

	// Update current database tables 
	[tablesListInstance updateTables:self];
	
	// Re-query the structure of all databases in the background
	[NSThread detachNewThreadSelector:@selector(queryDbStructureWithUserInfo:) toTarget:mySQLConnection withObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"forceUpdate", nil]];
	
    // Import finished Growl notification
    [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Import Finished" 
                                                   description:[NSString stringWithFormat:NSLocalizedString(@"Finished importing %@",@"description for finished importing growl notification"), [filename lastPathComponent]] 
													  document:tableDocumentInstance
                                              notificationName:@"Import Finished"];
}

#pragma mark -
#pragma mark CSV import

/**
 * Streaming data processing method to import a supplied CSV file.
 *
 * The file is read in chunk by chunk; each chunk is then checked
 * for line endings, which are used to split the data into parts
 * which can be parsed to NSStrings in the appropriate encoding.
 *
 * The NSStrings are then fed to a CSV parser, which splits them
 * into arrays of rows/cells.  Once 100 have been read in, a field
 * mapping sheet is displayed to allow columns to be mapped to
 * fields in a table; the queries are then constructed for each of
 * the rows, and the rest of the file is processed.
 */
- (void)importCSVFile:(NSString *)filename
{
	NSAutoreleasePool *importPool;
	SPFileHandle *csvFileHandle;
	NSMutableData *csvDataBuffer;
	const unsigned char *csvDataBufferBytes;
	NSData *fileChunk;
	NSString *csvString;
	SPCSVParser *csvParser;
	NSMutableString *query;
	NSMutableString *errors = [NSMutableString string];
	NSMutableString *insertBaseString = [NSMutableString string];
	NSMutableString *insertRemainingBaseString = [NSMutableString string];
	NSMutableArray *parsedRows = [[NSMutableArray alloc] init];
	NSMutableArray *parsePositions = [[NSMutableArray alloc] init];
	NSArray *csvRowArray;
	NSInteger fileChunkMaxLength = 256 * 1024;
	NSInteger csvRowsPerQuery = 50;
	NSUInteger csvRowsThisQuery;
	NSUInteger fileTotalLength = 0;
	NSInteger rowsImported = 0;
	NSInteger dataBufferLength = 0;
	NSInteger dataBufferPosition = 0;
	NSInteger dataBufferLastQueryEndPosition = 0;
	NSInteger i;
	BOOL allDataRead = NO;
	BOOL insertBaseStringHasEntries;
	
	NSStringEncoding csvEncoding = [mySQLConnection stringEncoding];

	fieldMappingArray = nil;
	fieldMappingGlobalValueArray = nil;

	// Start the notification timer to allow notifications to be shown even if frontmost for long queries
	[[SPGrowlController sharedGrowlController] setVisibilityForNotificationName:@"Import Finished"];

	// Open a filehandle for the CSV file
	csvFileHandle = [SPFileHandle fileHandleForReadingAtPath:filename];
	
	if (!csvFileHandle) {
		SPBeginAlertSheet(NSLocalizedString(@"Import Error", @"Import Error title"),
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
						  NSLocalizedString(@"The CSV file you selected could not be found or read.", @"CSV file open error"));
		if([filename hasPrefix:SPImportClipboardTempFileNamePrefix])
			[[NSFileManager defaultManager] removeItemAtPath:filename error:nil];
		return;
	}

	// Grab the file length
	fileTotalLength = [[[[NSFileManager defaultManager] attributesOfItemAtPath:filename error:NULL] objectForKey:NSFileSize] longLongValue];
	if (!fileTotalLength) fileTotalLength = 1;

	// Reset progress interface
	[errorsView setString:@""];
	[[singleProgressTitle onMainThread] setStringValue:NSLocalizedString(@"Importing CSV", @"text showing that the application is importing CSV")];
	[[singleProgressText onMainThread] setStringValue:NSLocalizedString(@"Reading...", @"text showing that app is reading dump")];
	[[singleProgressBar onMainThread] setIndeterminate:YES];
	[[singleProgressBar onMainThread] setUsesThreadedAnimation:YES];
	[[singleProgressBar onMainThread] startAnimation:self];
				
	// Open the progress sheet
	[[NSApp onMainThread] beginSheet:singleProgressSheet modalForWindow:[tableDocumentInstance parentWindow] modalDelegate:self didEndSelector:nil contextInfo:nil];
	[[singleProgressSheet onMainThread] makeKeyWindow];

	[tableDocumentInstance setQueryMode:SPImportExportQueryMode];

	// Determine the file encoding.  The first item in the encoding menu is "Autodetect"; if
	// this is selected, attempt to detect the encoding of the file (using first 2.5MB).
	if (![importEncodingPopup indexOfSelectedItem]) {
		SPFileHandle *detectorFileHandle = [SPFileHandle fileHandleForReadingAtPath:filename];
		if (detectorFileHandle) {
			UniversalDetector *fileEncodingDetector = [[UniversalDetector alloc] init];
			[fileEncodingDetector analyzeData:[detectorFileHandle readDataOfLength:2500000]];
			csvEncoding = [fileEncodingDetector encoding];
			[fileEncodingDetector release];
		}

	// Otherwise, get the encoding to use from the menu
	} else {
		csvEncoding = [importEncodingPopup selectedTag];
	}

	// Read in the file in a loop.  The loop actually needs to perform three tasks: read in
	// CSV data and parse them into row arrays; present the field mapping interface once it
	// has some data to show within the interface; and use the field mapping data to construct
	// and send queries to the server.  The loop is mainly to perform the first of these; the
	// other two must therefore be performed where possible.
	csvParser = [[SPCSVParser alloc] init];

	// Store settings in prefs
	[prefs setObject:[importFieldsEnclosedField stringValue] forKey:SPCSVImportFieldEnclosedBy];
	[prefs setObject:[importFieldsEscapedField stringValue] forKey:SPCSVImportFieldEscapeCharacter];
	[prefs setObject:[importLinesTerminatedField stringValue] forKey:SPCSVImportLineTerminator];
	[prefs setObject:[importFieldsTerminatedField stringValue] forKey:SPCSVImportFieldTerminator];
	[prefs setBool:[importFieldNamesSwitch state] forKey:SPCSVImportFirstLineIsHeader];

	// Take CSV import setting from accessory view
	[csvParser setFieldTerminatorString:[importFieldsTerminatedField stringValue] convertDisplayStrings:YES];
	[csvParser setLineTerminatorString:[importLinesTerminatedField stringValue] convertDisplayStrings:YES];
	[csvParser setFieldQuoteString:[importFieldsEnclosedField stringValue] convertDisplayStrings:YES];
	[csvParser setEscapeString:[importFieldsEscapedField stringValue] convertDisplayStrings:YES];
	[csvParser setNullReplacementString:[prefs objectForKey:SPNullValue]];

	csvDataBuffer = [[NSMutableData alloc] init];
	importPool = [[NSAutoreleasePool alloc] init];
	while (1) {
		if (progressCancelled) break;

		@try {
			fileChunk = [csvFileHandle readDataOfLength:fileChunkMaxLength];
		}

		// Report file read errors, and bail
		@catch (NSException *exception) {
			[self closeAndStopProgressSheet];
			SPBeginAlertSheet(NSLocalizedString(@"File read error", @"CSV read error title"),
							  NSLocalizedString(@"OK", @"OK button"),
							  nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when reading the file.\n\nOnly %ld rows were imported.\n\n(%@)", @"CSV read error, including detail string from system"), (long)rowsImported, [exception reason]]);
			[csvParser release];
			[csvDataBuffer release];
			[parsedRows release];
			[parsePositions release];
			[self _resetFieldMappingGlobals];
			[importPool drain];
			[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
			if([filename hasPrefix:SPImportClipboardTempFileNamePrefix])
				[[NSFileManager defaultManager] removeItemAtPath:filename error:nil];
			return;
		}

		// If no data returned, end of file - set a marker to ensure full processing
		if (!fileChunk || ![fileChunk length]) {
			allDataRead = YES;

		// Otherwise add the data to the read/parse buffer
		} else {
			[csvDataBuffer appendData:fileChunk];
		}

		// Step through the data buffer, identifying line endings to parse the data with
		csvDataBufferBytes = [csvDataBuffer bytes];
		dataBufferLength = [csvDataBuffer length];
		for ( ; dataBufferPosition < dataBufferLength || allDataRead; dataBufferPosition++) {
			if (csvDataBufferBytes[dataBufferPosition] == 0x0A || csvDataBufferBytes[dataBufferPosition] == 0x0D || allDataRead) {

				// Keep reading through any other line endings
				while (dataBufferPosition + 1 < dataBufferLength
						&& (csvDataBufferBytes[dataBufferPosition+1] == 0x0A
							|| csvDataBufferBytes[dataBufferPosition+1] == 0x0D))
				{
					dataBufferPosition++;
				}

				// Try to generate a NSString with the resulting data
				csvString = [[NSString alloc] initWithData:[csvDataBuffer subdataWithRange:NSMakeRange(dataBufferLastQueryEndPosition, dataBufferPosition - dataBufferLastQueryEndPosition)] encoding:csvEncoding];
				if (!csvString) {
					[self closeAndStopProgressSheet];
					NSString *displayEncoding;
					if (![importEncodingPopup indexOfSelectedItem]) {
						displayEncoding = [NSString stringWithFormat:@"%@ - %@", [importEncodingPopup titleOfSelectedItem], [NSString localizedNameOfStringEncoding:csvEncoding]];
					} else {
						displayEncoding = [NSString localizedNameOfStringEncoding:csvEncoding];
					}
					SPBeginAlertSheet(NSLocalizedString(@"File read error", @"CSV read error title"),
									  NSLocalizedString(@"OK", @"OK button"),
									  nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
									  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when reading the file, as it could not be read using the encoding you selected (%@).\n\nOnly %ld rows were imported.", @"CSV encoding read error"), displayEncoding, (long)rowsImported]);
					[csvParser release];
					[csvDataBuffer release];
					[parsedRows release];
					[parsePositions release];
					[self _resetFieldMappingGlobals];
					[importPool drain];
					[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
					if([filename hasPrefix:SPImportClipboardTempFileNamePrefix])
						[[NSFileManager defaultManager] removeItemAtPath:filename error:nil];
					return;
				}

				// Add the NSString segment to the CSV parser and release it
				[csvParser appendString:csvString];
				[csvString release];

				if (allDataRead) break;

				// Increment the buffer end position marker
				dataBufferLastQueryEndPosition = dataBufferPosition;
			}
		}

		// Trim the data buffer if part of it was used
		if (dataBufferLastQueryEndPosition) {
			[csvDataBuffer setData:[csvDataBuffer subdataWithRange:NSMakeRange(dataBufferLastQueryEndPosition, dataBufferLength - dataBufferLastQueryEndPosition)]];
			dataBufferPosition -= dataBufferLastQueryEndPosition;
			dataBufferLastQueryEndPosition = 0;
		}

		// Extract and process any full CSV rows found so far.  Also trigger processing if all
		// rows have been read, in order to ensure short files are still processed.
		while ((csvRowArray = [csvParser getRowAsArrayAndTrimString:YES stringIsComplete:allDataRead]) || (allDataRead && [parsedRows count])) {

			// If valid, add the row array and length to local storage
			if (csvRowArray) {
				[parsedRows addObject:csvRowArray];
				[parsePositions addObject:[NSNumber numberWithUnsignedInteger:[csvParser totalLengthParsed]]];
			}

			// If we have no field mapping array, and either the first hundred rows or all
			// the rows, request the field mapping from the user.
			if (!fieldMappingArray
				&& ([parsedRows count] >= 100 || (!csvRowArray && allDataRead)))
			{
				[self closeAndStopProgressSheet];
				if (![self buildFieldMappingArrayWithData:parsedRows isPreview:!allDataRead ofSoureFile:filename]) {
					[csvParser release];
					[csvDataBuffer release];
					[parsedRows release];
					[parsePositions release];
					[self _resetFieldMappingGlobals];
					[importPool drain];
					[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
					if([filename hasPrefix:SPImportClipboardTempFileNamePrefix])
						[[NSFileManager defaultManager] removeItemAtPath:filename error:nil];
					return;
				}

				// Reset progress interface and open the progress sheet
				[[singleProgressBar onMainThread] setIndeterminate:NO];
				[[singleProgressBar onMainThread] setMaxValue:fileTotalLength];
				[[singleProgressBar onMainThread] startAnimation:self];
				[[NSApp onMainThread] beginSheet:singleProgressSheet modalForWindow:[tableDocumentInstance parentWindow] modalDelegate:self didEndSelector:nil contextInfo:nil];
				[[singleProgressSheet onMainThread] makeKeyWindow];

				// Set up the field names import string for INSERT or REPLACE INTO
				[insertBaseString appendString:csvImportHeaderString];
				if(!importMethodIsUpdate) {
					[insertBaseString appendString:[selectedTableTarget backtickQuotedString]];
					[insertBaseString appendString:@" ("];
					insertBaseStringHasEntries = NO;
					for (i = 0; i < [fieldMappingArray count]; i++) {
						if ([NSArrayObjectAtIndex(fieldMapperOperator, i) integerValue] == 0) {
							if (insertBaseStringHasEntries) [insertBaseString appendString:@","];
							else insertBaseStringHasEntries = YES;
							[insertBaseString appendString:[NSArrayObjectAtIndex(fieldMappingTableColumnNames, i) backtickQuotedString]];
						}
					}
					[insertBaseString appendString:@") VALUES\n"];
				}

				// Remove the header row from the data set if appropriate
				if ([importFieldNamesSwitch state] == NSOnState) {
					[parsedRows removeObjectAtIndex:0];
					[parsePositions removeObjectAtIndex:0];
				}
			}
			if (!fieldMappingArray) continue;
			
			// Before entering the following loop, check that we actually have a connection.
			// If not, check the connection if appropriate and then clean up and exit if appropriate.
			if (![mySQLConnection isConnected] && ([mySQLConnection userTriggeredDisconnect] || ![mySQLConnection checkConnection])) {
				[self closeAndStopProgressSheet];
				[csvParser release];
				[csvDataBuffer release];
				[parsedRows release];
				[parsePositions release];
				[self _resetFieldMappingGlobals];
				[importPool drain];
				[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
				if([filename hasPrefix:SPImportClipboardTempFileNamePrefix])
					[[NSFileManager defaultManager] removeItemAtPath:filename error:nil];
				return;
			}

			// If we have more than the csvRowsPerQuery amount, or if we're at the end of the
			// available data, construct and run a query.
			while ([parsedRows count] >= csvRowsPerQuery
					|| (!csvRowArray && allDataRead && [parsedRows count]))
			{
				if (progressCancelled) break;
				csvRowsThisQuery = 0;
				if(!importMethodIsUpdate) {
					query = [[NSMutableString alloc] initWithString:insertBaseString];
					for (i = 0; i < csvRowsPerQuery && i < [parsedRows count]; i++) {
						if (i > 0) [query appendString:@",\n"];
						[query appendString:[[self mappedValueStringForRowArray:[parsedRows objectAtIndex:i]] description]];
						csvRowsThisQuery++;
						if ([query length] > 250000) break;
					}

					// Perform the query
					if(csvImportMethodHasTail)
						[mySQLConnection queryString:[NSString stringWithFormat:@"%@ %@", query, csvImportTailString]];
					else
						[mySQLConnection queryString:query];
					[query release];
				} else {
					if(insertRemainingRowsAfterUpdate) {
						[insertRemainingBaseString setString:@"INSERT INTO "];
						[insertRemainingBaseString appendString:[selectedTableTarget backtickQuotedString]];
						[insertRemainingBaseString appendString:@" ("];
						insertBaseStringHasEntries = NO;
						for (i = 0; i < [fieldMappingArray count]; i++) {
							if ([NSArrayObjectAtIndex(fieldMapperOperator, i) integerValue] == 0) {
								if (insertBaseStringHasEntries) [insertBaseString appendString:@","];
								else insertBaseStringHasEntries = YES;
								[insertRemainingBaseString appendString:[NSArrayObjectAtIndex(fieldMappingTableColumnNames, i) backtickQuotedString]];
							}
						}
						[insertRemainingBaseString appendString:@") VALUES\n"];
					}
					for (i = 0; i < [parsedRows count]; i++) {
						if (progressCancelled) break;

						query = [[NSMutableString alloc] initWithString:insertBaseString];
						[query appendString:[self mappedUpdateSetStatementStringForRowArray:[parsedRows objectAtIndex:i]]];

						// Perform the query
						if(csvImportMethodHasTail)
							[mySQLConnection queryString:[NSString stringWithFormat:@"%@ %@", query, csvImportTailString]];
						else
							[mySQLConnection queryString:query];
						[query release];

						if ([mySQLConnection queryErrored]) {
							[tableDocumentInstance showConsole:nil];
							[errors appendFormat:
								NSLocalizedString(@"[ERROR in row %ld] %@\n", @"error text when reading of csv file gave errors"),
								(long)(rowsImported+1),[mySQLConnection getLastErrorMessage]];
						}

						if ( insertRemainingRowsAfterUpdate && ![mySQLConnection affectedRows]) {
							query = [[NSMutableString alloc] initWithString:insertRemainingBaseString];
							[query appendString:[self mappedValueStringForRowArray:[parsedRows objectAtIndex:i]]];

							// Perform the query
							if(csvImportMethodHasTail)
								[mySQLConnection queryString:[NSString stringWithFormat:@"%@ %@", query, csvImportTailString]];
							else
								[mySQLConnection queryString:query];
							[query release];

							if ([mySQLConnection queryErrored]) {
								[errors appendFormat:
									NSLocalizedString(@"[ERROR in row %ld] %@\n", @"error text when reading of csv file gave errors"),
									(long)(rowsImported+1),[mySQLConnection getLastErrorMessage]];
							}
						}

						rowsImported++;
						csvRowsThisQuery++;
						[singleProgressBar setDoubleValue:[[parsePositions objectAtIndex:i] doubleValue]];
						[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Imported %@ of %@", @"SQL import progress text"),
							[NSString stringForByteSize:[[parsePositions objectAtIndex:i] longValue]], [NSString stringForByteSize:fileTotalLength]]];
					}
				}

				// If an error occurred, run the queries individually to get exact line errors
				if (!importMethodIsUpdate && [mySQLConnection queryErrored]) {
					[tableDocumentInstance showConsole:nil];
					for (i = 0; i < csvRowsThisQuery; i++) {
						if (progressCancelled) break;
						query = [[NSMutableString alloc] initWithString:insertBaseString];
						[query appendString:[self mappedValueStringForRowArray:[parsedRows objectAtIndex:i]]];

						// Perform the query
						if(csvImportMethodHasTail)
							[mySQLConnection queryString:[NSString stringWithFormat:@"%@ %@", query, csvImportTailString]];
						else
							[mySQLConnection queryString:query];
						[query release];

						if ([mySQLConnection queryErrored]) {
							[errors appendFormat:
								NSLocalizedString(@"[ERROR in row %ld] %@\n", @"error text when reading of csv file gave errors"),
								(long)(rowsImported+1),[mySQLConnection getLastErrorMessage]];
						}
						rowsImported++;
						[singleProgressBar setDoubleValue:[[parsePositions objectAtIndex:i] doubleValue]];
						[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Imported %@ of %@", @"SQL import progress text"),
							[NSString stringForByteSize:[[parsePositions objectAtIndex:i] longValue]], [NSString stringForByteSize:fileTotalLength]]];
					}
				} else {
					rowsImported += csvRowsThisQuery;
					[singleProgressBar setDoubleValue:[[parsePositions objectAtIndex:csvRowsThisQuery-1] doubleValue]];
					[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Imported %@ of %@", @"SQL import progress text"),
						[NSString stringForByteSize:[[parsePositions objectAtIndex:csvRowsThisQuery-1] longValue]], [NSString stringForByteSize:fileTotalLength]]];
				}

				// Update the arrays
				[parsedRows removeObjectsInRange:NSMakeRange(0, csvRowsThisQuery)];
				[parsePositions removeObjectsInRange:NSMakeRange(0, csvRowsThisQuery)];
			}
		}
		
		// If all the data has been read, break out of the processing loop
		if (allDataRead) break;

		// Reset the autorelease pool
		[importPool drain];
		importPool = [[NSAutoreleasePool alloc] init];
	}

	// Clean up
	[csvParser release];
	[csvDataBuffer release];
	[parsedRows release];
	[parsePositions release];
	[self _resetFieldMappingGlobals];
	[importPool drain];
	[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
	if([filename hasPrefix:SPImportClipboardTempFileNamePrefix])
		[[NSFileManager defaultManager] removeItemAtPath:filename error:nil];

	// Close progress sheet
	[self closeAndStopProgressSheet];

	// Display any errors
	if ([errors length]) {
		[self showErrorSheetWithMessage:errors];
	}
	
	// Import finished Growl notification
	[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Import Finished" 
                                                   description:[NSString stringWithFormat:NSLocalizedString(@"Finished importing %@",@"description for finished importing growl notification"), [filename lastPathComponent]] 
													  document:tableDocumentInstance
                                              notificationName:@"Import Finished"];

	// If the table selected for import is also selected in the content view,
	// update the content view - on the main thread to avoid crashes.
	if ([tablesListInstance tableName] && [selectedTableTarget isEqualToString:[tablesListInstance tableName]]) {
		if ([[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableContent]) {
			[tableContentInstance performSelectorOnMainThread:@selector(reloadTable:) withObject:nil waitUntilDone:YES];
		} else {
			[tablesListInstance setContentRequiresReload:YES];
		}
	}
}

/**
 * Sets up the field mapping array, and asks the user to provide a field mapping to an
 * appropriate table; on success, constructs the field mapping array into the global variable,
 * and returns true.  On failure, displays error messages itself, and returns false.
 * Takes an array of data to show when selecting the field mapping, and an indicator of whether
 * that dataset is complete or a preview of the full data set.
 */
- (BOOL) buildFieldMappingArrayWithData:(NSArray *)importData isPreview:(BOOL)dataIsPreviewData ofSoureFile:(NSString*)filename
{

	// Ensure data was provided, or alert than an import error occurred and return false.
	if (![importData count]) {
		[self closeAndStopProgressSheet];
		SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"),
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil,
						  [tableDocumentInstance parentWindow], self,
						  nil, nil,
						  NSLocalizedString(@"Could not parse file as CSV", @"Error when we can't parse/split file as CSV")
						  );
		return FALSE;
	}

	// Sanity check the first row of the CSV to prevent hang loops caused by wrong line ending entry
	if ([[importData objectAtIndex:0] count] > 512) {
		[self closeAndStopProgressSheet];
		SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"),
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil,
						  [tableDocumentInstance parentWindow], self,
						  nil, nil,
						  NSLocalizedString(@"The CSV was read as containing more than 512 columns, more than the maximum columns permitted for speed reasons by Sequel Pro.\n\nThis usually happens due to errors reading the CSV; please double-check the CSV to be imported and the line endings and escape characters at the bottom of the CSV selection dialog.", @"Error when CSV appears to have too many columns to import, probably due to line ending mismatch")
						  );
		return FALSE;
	}
	fieldMappingImportArrayIsPreview = dataIsPreviewData;

	// If there's no tables to select, error
	// if (![[tablesListInstance allTableNames] count]) {
	// 	[self closeAndStopProgressSheet];
	// 	SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"),
	// 					  NSLocalizedString(@"OK", @"OK button"),
	// 					  nil, nil,
	// 					  [tableDocumentInstance parentWindow], self,
	// 					  nil, nil,
	// 					  NSLocalizedString(@"Can't import CSV data into a database without any tables!", @"error text when trying to import csv data, but we have no tables in the db")
	// 					  );
	// 	return FALSE;
	// }

	// Set the import array
	if (fieldMappingImportArray) [fieldMappingImportArray release];
	fieldMappingImportArray = [[NSArray alloc] initWithArray:importData];
	numberOfImportDataColumns = [[importData objectAtIndex:0] count];

	fieldMapperSheetStatus = 1;
	fieldMappingArrayHasGlobalVariables = NO;

	// Init the field mapper controller
	fieldMapperController = [[SPFieldMapperController alloc] initWithDelegate:self];
	[fieldMapperController setConnection:mySQLConnection];
	[fieldMapperController setSourcePath:filename];
	[fieldMapperController setImportDataArray:fieldMappingImportArray hasHeader:[importFieldNamesSwitch state] isPreview:fieldMappingImportArrayIsPreview];

	// Show field mapper sheet and set the focus to it
	[[NSApp onMainThread] beginSheet:[fieldMapperController window]
	   modalForWindow:[tableDocumentInstance parentWindow]
		modalDelegate:self
	   didEndSelector:@selector(fieldMapperDidEndSheet:returnCode:contextInfo:)
		  contextInfo:nil];

	[[[fieldMapperController window] onMainThread] makeKeyWindow];

	// Wait for field mapper sheet
	while (fieldMapperSheetStatus == 1)
		usleep(100000);

	// Get mapping settings and preset some global variables
	fieldMapperOperator  = [[NSArray arrayWithArray:[fieldMapperController fieldMapperOperator]] retain];
	fieldMappingArray    = [[NSArray arrayWithArray:[fieldMapperController fieldMappingArray]] retain];
	selectedTableTarget  = [NSString stringWithString:[fieldMapperController selectedTableTarget]];
	selectedImportMethod = [NSString stringWithString:[fieldMapperController selectedImportMethod]];
	fieldMappingTableColumnNames = [[NSArray arrayWithArray:[fieldMapperController fieldMappingTableColumnNames]] retain];
	fieldMappingGlobalValueArray = [[NSArray arrayWithArray:[fieldMapperController fieldMappingGlobalValueArray]] retain];
	fieldMappingTableDefaultValues = [[NSArray arrayWithArray:[fieldMapperController fieldMappingTableDefaultValues]] retain];
	csvImportHeaderString = [[NSString stringWithString:[fieldMapperController importHeaderString]] retain];
	csvImportTailString = [[NSString stringWithString:[fieldMapperController onupdateString]] retain];
	fieldMappingArrayHasGlobalVariables = [fieldMapperController globalValuesInUsage];
	csvImportMethodHasTail = ([csvImportTailString length] == 0) ? NO : YES;
	insertRemainingRowsAfterUpdate = [fieldMapperController insertRemainingRowsAfterUpdate];
	importMethodIsUpdate = ([selectedImportMethod isEqualToString:@"UPDATE"]) ? YES : NO;

	// Error checking
	if(    ![fieldMapperOperator count] 
		|| ![fieldMappingArray count] 
		|| ![selectedImportMethod length] 
		|| ![selectedTableTarget length]
		|| ![csvImportHeaderString length])
	{
		if(fieldMapperController) [fieldMapperController release];
		NSBeep();
		return FALSE;
	}

	[importFieldNamesSwitch setState:[fieldMapperController importFieldNamesHeader]];
	[prefs setBool:[importFieldNamesSwitch state] forKey:SPCSVImportFirstLineIsHeader];

	if(fieldMapperController) [fieldMapperController release];

	if(fieldMapperSheetStatus == 2)
		return YES;
	else
		return NO;
}

/**
 *
 */
- (void)fieldMapperDidEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	fieldMapperSheetStatus = (returnCode) ? 2 : 3;
}

/**
 * Construct the SET and WHERE clause for a CSV row, based on the field mapping array 
 * for the import method "UPDATE".
 */
- (NSString *)mappedUpdateSetStatementStringForRowArray:(NSArray *)csvRowArray
{

	NSMutableString *setString = [NSMutableString stringWithString:@""];
	NSMutableString *whereString = [NSMutableString stringWithString:@"WHERE "];

	NSInteger i;
	NSInteger mapColumn;
	id cellData;
	NSInteger mappingArrayCount = [fieldMappingArray count];

	for (i = 0; i < mappingArrayCount; i++) {

		// Skip unmapped columns
		if ([NSArrayObjectAtIndex(fieldMapperOperator, i) integerValue] == 1 ) continue;

		mapColumn = [NSArrayObjectAtIndex(fieldMappingArray, i) integerValue];

		// SET clause
		if ([NSArrayObjectAtIndex(fieldMapperOperator, i) integerValue] == 0 ) {
			if ([setString length] > 1) [setString appendString:@","];
			[setString appendString:[NSArrayObjectAtIndex(fieldMappingTableColumnNames, i) backtickQuotedString]];
			[setString appendString:@"="];
			// Append the data
			// - check for global values
			if(fieldMappingArrayHasGlobalVariables && mapColumn >= numberOfImportDataColumns) {
				// Global variables are coming wrapped in ' ' if there're not marked as SQL 
				 [setString appendString:NSArrayObjectAtIndex(fieldMappingGlobalValueArray, mapColumn)];
			} else {
				cellData = NSArrayObjectAtIndex(csvRowArray, mapColumn);

				// If import column isn't specified import the table column default value
				if ([cellData isSPNotLoaded])
					cellData = NSArrayObjectAtIndex(fieldMappingTableDefaultValues, i);

				if (cellData == [NSNull null]) {
					[setString appendString:@"NULL"];
				} else {
					[setString appendString:@"'"];
					[setString appendString:[mySQLConnection prepareString:cellData]];
					[setString appendString:@"'"];
				}
			}
		}
		// WHERE clause
		else if ([NSArrayObjectAtIndex(fieldMapperOperator, i) integerValue] == 2 )
		{
			if ([whereString length] > 7) [whereString appendString:@" AND "];
			[whereString appendString:[NSArrayObjectAtIndex(fieldMappingTableColumnNames, i) backtickQuotedString]];
			// Append the data
			// - check for global values
			if(fieldMappingArrayHasGlobalVariables && mapColumn >= numberOfImportDataColumns) {
				// Global variables are coming wrapped in ' ' if there're not marked as SQL 
				[whereString appendString:@"="];
				[whereString appendString:NSArrayObjectAtIndex(fieldMappingGlobalValueArray, mapColumn)];
			} else {
				cellData = NSArrayObjectAtIndex(csvRowArray, mapColumn);

				// If import column isn't specified import the table column default value
				if ([cellData isSPNotLoaded])
					cellData = NSArrayObjectAtIndex(fieldMappingTableDefaultValues, i);

				if (cellData == [NSNull null]) {
					[whereString appendString:@" IS NULL"];
				} else {
					[whereString appendString:@"="];
					[whereString appendString:@"'"];
					[whereString appendString:[mySQLConnection prepareString:cellData]];
					[whereString appendString:@"'"];
				}
			}
		}
	}
	
	return [NSString stringWithFormat:@"%@ %@", setString, whereString];
}

/**
 * Construct the VALUES string for a CSV row, based on the field mapping array - including
 * surrounding brackets but not including the VALUES keyword.
 */
- (NSString *)mappedValueStringForRowArray:(NSArray *)csvRowArray
{
	NSMutableString *valueString = [NSMutableString stringWithString:@"("];
	NSInteger i;
	NSInteger mapColumn;
	id cellData;
	NSInteger mappingArrayCount = [fieldMappingArray count];

	for (i = 0; i < mappingArrayCount; i++) {

		// Skip unmapped columns
		if ([NSArrayObjectAtIndex(fieldMapperOperator, i) integerValue] > 0) continue;

		mapColumn = [NSArrayObjectAtIndex(fieldMappingArray, i) integerValue];

		if ([valueString length] > 1) [valueString appendString:@","];

		// Append the data
		// - check for global values
		if(fieldMappingArrayHasGlobalVariables && mapColumn >= numberOfImportDataColumns) {
			// Global variables are coming wrapped in ' ' if there're not marked as SQL 
			[valueString appendString:NSArrayObjectAtIndex(fieldMappingGlobalValueArray, mapColumn)];
		} else {
			cellData = NSArrayObjectAtIndex(csvRowArray, mapColumn);

			// If import column isn't specified import the table column default value
			if ([cellData isSPNotLoaded])
				cellData = NSArrayObjectAtIndex(fieldMappingTableDefaultValues, i);

			if (cellData == [NSNull null]) {
				[valueString appendString:@"NULL"];
			} else {
				[valueString appendString:@"'"];
				[valueString appendString:[mySQLConnection prepareString:cellData]];
				[valueString appendString:@"'"];
			}
		}
	}

	[valueString appendString:@")"];
	
	return valueString;
}

#pragma mark -
#pragma mark Import delegate notifications

/**
 * Called when the selection within an open/save panel changes.
 */
- (void)panelSelectionDidChange:(id)sender
{
	NSArray *selectedFilenames = [sender filenames];
	NSString *pathExtension;

	// If a single file is selected and the extension is recognised, change the format dropdown automatically
	if ( [selectedFilenames count] != 1 ) return;
	pathExtension = [[[selectedFilenames objectAtIndex:0] pathExtension] uppercaseString];

	// If the file has an extension '.gz' or '.bz2' indicating gzip or bzip2 compression, fetch the next extension
	if ([pathExtension isEqualToString:@"GZ"] || [pathExtension isEqualToString:@"BZ2"]) {
		NSMutableString *pathString = [NSMutableString stringWithString:[selectedFilenames objectAtIndex:0]];
		
		BOOL isGzip = [pathExtension isEqualToString:@"GZ"];
		
		[pathString deleteCharactersInRange:NSMakeRange([pathString length] - (isGzip ? 3 : 4), (isGzip ? 3 : 4))];
		
		pathExtension = [[pathString pathExtension] uppercaseString];		
	}
	
	if ([pathExtension isEqualToString:@"SQL"]) {
		[importFormatPopup selectItemWithTitle:@"SQL"];
		[self changeFormat:self];
	} else if ([pathExtension isEqualToString:@"CSV"]) {
		[importFormatPopup selectItemWithTitle:@"CSV"];
		[self changeFormat:self];

		// Try to detect the line endings using "file"
		NSTask *fileTask = [[NSTask alloc] init];
		NSPipe *filePipe = [[NSPipe alloc] init];

		[fileTask setLaunchPath:@"/usr/bin/file"];
		[fileTask setArguments:[NSArray arrayWithObjects:@"-L", @"-b", [selectedFilenames objectAtIndex:0], nil]];
		[fileTask setStandardOutput:filePipe];
		NSFileHandle *fileHandle = [filePipe fileHandleForReading];

		[fileTask launch];

		NSString *fileCheckOutput = [[NSString alloc] initWithData:[fileHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
		if (fileCheckOutput && [fileCheckOutput length]) {
			NSString *lineEndingString = [fileCheckOutput stringByMatching:@"with ([A-Z]{2,4}) line terminators" capture:1L];
			if (!lineEndingString && [fileCheckOutput isMatchedByRegex:@"text"]) lineEndingString = @"LF";
			if (lineEndingString) {
				if ([lineEndingString isEqualToString:@"LF"]) [importLinesTerminatedField setStringValue:@"\\n"];
				else if ([lineEndingString isEqualToString:@"CR"]) [importLinesTerminatedField setStringValue:@"\\r"];
				else if ([lineEndingString isEqualToString:@"CRLF"]) [importLinesTerminatedField setStringValue:@"\\r\\n"];
			}
		}
		if (fileCheckOutput) [fileCheckOutput release];

		[fileTask release];
		[filePipe release];
	}
}

#pragma mark -
#pragma mark Other

/**
 * Sets the connection (received from SPDatabaseDocument) and makes things that have to be done only once.
 */
- (void)setConnection:(MCPConnection *)theConnection
{
	NSButtonCell *switchButton = [[NSButtonCell alloc] init];
	
	prefs = [[NSUserDefaults standardUserDefaults] retain];
	
	mySQLConnection = theConnection;
	
	// Set up the interface
	[switchButton setButtonType:NSSwitchButton];
	[switchButton setControlSize:NSSmallControlSize];
	[switchButton release];
	
	if ([prefs boolForKey:SPUseMonospacedFonts]) {
		[errorsView setFont:[NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]]];
	} else {
		[errorsView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
}

/**
 * Selectable toolbar identifiers.
 */
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	NSArray *array = [toolbar items];
	NSMutableArray *items = [NSMutableArray arrayWithCapacity:6];
	
	for (NSToolbarItem *item in array)
	{
		[items addObject:[item itemIdentifier]];
	}
	
    return items;
}

/**
 * Displays the import error sheet with the supplied error message.
 */
- (void)showErrorSheetWithMessage:(NSString*)message
{
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(showErrorSheetWithMessage:) withObject:message waitUntilDone:YES];
		return;
	}
	
	[errorsView setString:message];
	[NSApp beginSheet:errorsSheet 
	   modalForWindow:[tableDocumentInstance parentWindow] 
		modalDelegate:self 
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:nil];
	[errorsSheet makeKeyWindow];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
}

#pragma mark -

/**
 * Dealloc.
 */
- (void)dealloc
{	
	if (fieldMappingImportArray) [fieldMappingImportArray release];
	if (lastFilename) [lastFilename release];
	if (prefs) [prefs release];
	
	for (id retainedObject in nibObjectsToRelease) [retainedObject release];
	
	[nibObjectsToRelease release];
	
	[super dealloc];
}

@end

@implementation  SPDataImport (PrivateAPI)

/**
 * Starts the import process on a background thread.
 */
- (void) _importBackgroundProcess:(NSString *)filename
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *fileType = [[importFormatPopup selectedItem] title];

	// Use the appropriate processing function for the file type
	if ([fileType isEqualToString:@"SQL"])
		[self importSQLFile:filename];
	else if ([fileType isEqualToString:@"CSV"])
		[self importCSVFile:filename];

	[pool release];
}

/**
 * Release and reset any field mapping global variables.
 */
- (void) _resetFieldMappingGlobals
{
	if (csvImportTailString) [csvImportTailString release], csvImportTailString = nil;
	if (csvImportHeaderString) [csvImportHeaderString release], csvImportHeaderString = nil;
	if (fieldMappingArray) [fieldMappingArray release], fieldMappingArray = nil;
	if (fieldMappingGlobalValueArray) [fieldMappingGlobalValueArray release], fieldMappingGlobalValueArray = nil;
	if (fieldMappingTableColumnNames) [fieldMappingTableColumnNames release], fieldMappingTableColumnNames = nil;
	if (fieldMappingTableDefaultValues) [fieldMappingTableDefaultValues release], fieldMappingTableDefaultValues = nil;
	if (fieldMapperOperator) [fieldMapperOperator release], fieldMapperOperator = nil;
}

@end

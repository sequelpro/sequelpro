//
//  $Id$
//
//  TableDump.m
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

#import "TableDump.h"
#import "TableDocument.h"
#import "TablesList.h"
#import "TableSource.h"
#import "TableContent.h"
#import "CustomQuery.h"
#import "SPGrowlController.h"
#import "SPSQLParser.h"
#import "SPTableData.h"
#import "SPStringAdditions.h"
#import "SPArrayAdditions.h"
#import "RegexKitLite.h"

@implementation TableDump

#pragma mark -
#pragma mark IBAction methods

/**
 * Get the tables in db
 */
- (IBAction)reloadTables:(id)sender
{
	MCPResult *queryResult;
	int i;
	
	//get tables
	[tables removeAllObjects];
	queryResult = (MCPResult *)[mySQLConnection listTables];
	
	if ([queryResult numOfRows]) [queryResult dataSeek:0];
	NSMutableArray *unsortedTables = [NSMutableArray array];
	for ( i = 0 ; i < [queryResult numOfRows] ; i++ ) {
		[unsortedTables addObject:[[queryResult fetchRowAsArray] objectAtIndex:0]];
	}
	
	NSSortDescriptor *desc = [[NSSortDescriptor alloc] initWithKey:nil ascending:YES selector:@selector(localizedCompare:)];
	NSArray *sortedTables = [unsortedTables sortedArrayUsingDescriptors:[NSArray arrayWithObject:desc]];
	[desc release];
	
	for ( i = 0 ; i < [sortedTables count]; i++ ) {
		[tables addObject:
			[NSMutableArray arrayWithObjects:
				[NSNumber numberWithBool:YES], 
				[sortedTables objectAtIndex:i], 
				nil]];
	}
		
	[exportDumpTableView reloadData];
	[exportMultipleCSVTableView reloadData];
	[exportMultipleXMLTableView reloadData];
}

/**
 * Selects or deselects all tables
 */
- (IBAction)selectTables:(id)sender
{
	NSEnumerator *enumerator;
	id theObject;
	
	[self reloadTables:self];
	
	enumerator = [tables objectEnumerator];
	while ( (theObject = [enumerator nextObject]) ) {
		if ( [sender tag] ) {
			[theObject replaceObjectAtIndex:0 withObject:[NSNumber numberWithBool:YES]];
		} else {
			[theObject replaceObjectAtIndex:0 withObject:[NSNumber numberWithBool:NO]];
		}
	}
	
	[exportDumpTableView reloadData];
	[exportMultipleCSVTableView reloadData];
	[exportMultipleXMLTableView reloadData];
}

/**
 * Common method for ending modal sessions
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}

#pragma mark -
#pragma mark Export methods

- (void)export
{
	[self reloadTables:self];
	[NSApp beginSheet:exportWindow modalForWindow:tableWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
}

- (void)exportFile:(int)tag
/*
 invoked when user clicks on an export menuItem
 */
{
	NSString *file;
	NSString *contextInfo;
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setAllowsOtherFileTypes:YES];
	[savePanel setExtensionHidden:NO];
	NSString *currentDate = [[NSDate date] descriptionWithCalendarFormat:@"%Y-%m-%d" timeZone:nil locale:nil];
	
	switch ( tag ) {
		case 5:
			// export dump
			[self reloadTables:self];
			file = [NSString stringWithFormat:@"%@_%@.sql", [tableDocumentInstance database], currentDate];
			[savePanel setRequiredFileType:@"sql"];
			[savePanel setAccessoryView:exportDumpView];
			contextInfo = @"exportDump";
			break;
			
			// Export the full resultset for the currently selected table to a file in CSV format
		case 6:
			file = [NSString stringWithFormat:@"%@.csv", [tableDocumentInstance table]];
			[savePanel setAccessoryView:exportCSVView];
			[csvFullStreamingSwitch setEnabled:YES];
			contextInfo = @"exportTableContentAsCSV";
			break;
			
			// Export the full resultset for the currently selected table to a file in XML format
		case 7:
			file = [NSString stringWithFormat:@"%@.xml", [tableDocumentInstance table]];
			contextInfo = @"exportTableContentAsXML";
			break;
			
			// Export the current "browse" view to a file in CSV format
		case 8:
			file = [NSString stringWithFormat:@"%@ view.csv", [tableDocumentInstance table]];
			[savePanel setAccessoryView:exportCSVView];
			[csvFullStreamingSwitch setEnabled:NO];
			contextInfo = @"exportBrowseViewAsCSV";
			break;
			
			// Export the current "browse" view to a file in XML format
		case 9:
			file = [NSString stringWithFormat:@"%@ view.xml", [tableDocumentInstance table]];
			contextInfo = @"exportBrowseViewAsXML";
			break;
			
			// Export the current custom query result set to a file in CSV format
		case 10:
			file = @"customresult.csv";
			[savePanel setAccessoryView:exportCSVView];
			[csvFullStreamingSwitch setEnabled:NO];
			contextInfo = @"exportCustomResultAsCSV";
			break;
			
			// Export the current custom query result set to a file in XML format
		case 11:
			file = @"customresult.xml";
			contextInfo = @"exportCustomResultAsXML";
			break;
			
			// Export multiple tables to a file in CSV format
		case 12:
			[self reloadTables:self];
			file = [NSString stringWithFormat:@"%@.csv", [tableDocumentInstance database]];
			[savePanel setAccessoryView:exportMultipleCSVView];
			contextInfo = @"exportMultipleTablesAsCSV";
			break;
			
			// Export multiple tables to a file in XML format
		case 13:
			[self reloadTables:self];
			file = [NSString stringWithFormat:@"%@.xml", [tableDocumentInstance database]];
			[savePanel setAccessoryView:exportMultipleXMLView];
			contextInfo = @"exportMultipleTablesAsXML";
			break;
			
			// graphviz dot file
		case 14:
			[self reloadTables:self];
			file = [NSString stringWithString:[tableDocumentInstance database]];
			[savePanel setRequiredFileType:@"dot"];
			contextInfo = @"exportDot";
			break;
			
		default:
			ALog(@"ERROR: unknown export item with tag %d", tag);
			return;
			break;
	}
	
	// Open the savePanel
	[savePanel beginSheetForDirectory:[prefs objectForKey:@"savePath"]
								 file:file modalForWindow:tableWindow modalDelegate:self
					   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:contextInfo];
}

/*
 Save the export file; open a file handle, pass it to the appropriate data-writing function for streaming the export, and close the handle.
 */
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{
	NSFileHandle *fileHandle = nil;
	BOOL success;
	
	[sheet orderOut:self];
	
	if ( returnCode != NSOKButton )
		return;
	
	// Save path to preferences
	[prefs setObject:[sheet directory] forKey:@"savePath"];
	
	// Error if the file already exists and is not writable, and get a fileHandle to it.
	if ( [[NSFileManager defaultManager] fileExistsAtPath:[sheet filename]] ) {
		if ( ![[NSFileManager defaultManager] isWritableFileAtPath:[sheet filename]]
			|| !(fileHandle = [NSFileHandle fileHandleForWritingAtPath:[sheet filename]]) ) {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  NSLocalizedString(@"Couldn't replace the file. Be sure that you have the necessary privileges.", @"message of panel when file cannot be replaced"));
			return;
		}
		
		// Truncate the file to zero bytes
		[fileHandle truncateFileAtOffset:0];
		
		// Otherwise attempt to create a file
	} else {
		if ( ![[NSFileManager defaultManager] createFileAtPath:[sheet filename] contents:[NSData data] attributes:nil] ) {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  NSLocalizedString(@"Couldn't write to file. Be sure that you have the necessary privileges.", @"message of panel when file cannot be written"));
			return;
		}
		
		// Retrieve a filehandle for the file, attempting to delete it on failure.
		fileHandle = [NSFileHandle fileHandleForWritingAtPath:[sheet filename]];
		if ( !fileHandle ) {
			[[NSFileManager defaultManager] removeFileAtPath:[sheet filename] handler:nil];
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  NSLocalizedString(@"Couldn't write to file. Be sure that you have the necessary privileges.", @"message of panel when file cannot be written"));
			return;
		}
	}
	
	// Export the tables selected in the MySQL export sheet to a file
	if ( [contextInfo isEqualToString:@"exportDump"] ) {
		success = [self dumpSelectedTablesAsSqlToFileHandle:fileHandle];
		
		// Export the full resultset for the currently selected table to a file in CSV format
	} else if ( [contextInfo isEqualToString:@"exportTableContentAsCSV"] ) {
		success = [self exportTables:[NSArray arrayWithObject:[tableDocumentInstance table]] toFileHandle:fileHandle usingFormat:@"csv" usingMulti:NO];
		
		// Export the full resultset for the currently selected table to a file in XML format
	} else if ( [contextInfo isEqualToString:@"exportTableContentAsXML"] ) {
		success = [self exportTables:[NSArray arrayWithObject:[tableDocumentInstance table]] toFileHandle:fileHandle usingFormat:@"xml" usingMulti:NO];
		
	// Export the current "browse" view to a file in CSV or XML format
	} else if ( [contextInfo isEqualToString:@"exportBrowseViewAsCSV"]
				|| [contextInfo isEqualToString:@"exportBrowseViewAsXML"] )
	{

		// Start an indeterminate progress sheet, as getting the current result set can take a significant period of time
		[singleProgressTitle setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Exporting content view to CSV", @"title showing that application is saving content view as CSV")]];
		[singleProgressText setStringValue:NSLocalizedString(@"Exporting data...", @"text showing that app is preparing data")];
		[singleProgressBar setUsesThreadedAnimation:YES];
		[singleProgressBar setIndeterminate:YES];
		[NSApp beginSheet:singleProgressSheet modalForWindow:tableWindow modalDelegate:self didEndSelector:nil contextInfo:nil];

		[singleProgressBar startAnimation:self];		
		NSArray *contentViewArray = [tableContentInstance currentResult];

		if ( [contextInfo isEqualToString:@"exportBrowseViewAsCSV"] ) {
			success = [self writeCsvForArray:contentViewArray orStreamingResult:nil
								toFileHandle:fileHandle
							outputFieldNames:[exportFieldNamesSwitch state]
								terminatedBy:[exportFieldsTerminatedField stringValue]
								  enclosedBy:[exportFieldsEnclosedField stringValue]
								   escapedBy:[exportFieldsEscapedField stringValue]
									lineEnds:[exportLinesTerminatedField stringValue]
						  withNumericColumns:nil
								   totalRows:[contentViewArray count]
									silently:YES];
		} else {		
			success = [self writeXmlForArray:contentViewArray orStreamingResult:nil
								toFileHandle:fileHandle
								   tableName:(NSString *)[tableDocumentInstance table]
								  withHeader:YES
								   totalRows:[contentViewArray count]
									silently:YES];
		}

		// Close the progress sheet
		[singleProgressBar stopAnimation:self];
		[NSApp endSheet:singleProgressSheet];
		[singleProgressSheet orderOut:nil];
		
	// Export the current custom query result set to a file in CSV or XML format
	} else if ( [contextInfo isEqualToString:@"exportCustomResultAsCSV"]
				|| [contextInfo isEqualToString:@"exportCustomResultAsXML"] )
	{

		// Start an indeterminate progress sheet, as getting the current result set can take a significant period of time
		[singleProgressTitle setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Exporting custom query view to CSV", @"title showing that application is saving custom query view as CSV")]];
		[singleProgressText setStringValue:NSLocalizedString(@"Exporting data...", @"text showing that app is preparing data")];
		[singleProgressBar setUsesThreadedAnimation:YES];
		[singleProgressBar setIndeterminate:YES];
		[NSApp beginSheet:singleProgressSheet modalForWindow:tableWindow modalDelegate:self didEndSelector:nil contextInfo:nil];

		[singleProgressBar startAnimation:self];
		NSArray *customQueryViewArray = [customQueryInstance currentResult];

		if ( [contextInfo isEqualToString:@"exportCustomResultAsCSV"] ) {
			success = [self writeCsvForArray:customQueryViewArray orStreamingResult:nil
								toFileHandle:fileHandle
							outputFieldNames:[exportFieldNamesSwitch state]
								terminatedBy:[exportFieldsTerminatedField stringValue]
								  enclosedBy:[exportFieldsEnclosedField stringValue]
								   escapedBy:[exportFieldsEscapedField stringValue]
									lineEnds:[exportLinesTerminatedField stringValue]
						  withNumericColumns:nil
								   totalRows:[customQueryViewArray count]
									silently:YES];
		} else {
			success = [self writeXmlForArray:customQueryViewArray orStreamingResult:nil
								toFileHandle:fileHandle
								   tableName:@"custom"
								  withHeader:YES
								   totalRows:[customQueryViewArray count]
									silently:YES];
		}

		// Close the progress sheet
		[singleProgressBar stopAnimation:self];
		[NSApp endSheet:singleProgressSheet];
		[singleProgressSheet orderOut:nil];

		// Export multiple tables to a file in CSV format
	} else if ( [contextInfo isEqualToString:@"exportMultipleTablesAsCSV"] ) {
		success = [self exportSelectedTablesToFileHandle:fileHandle usingFormat:@"csv"];
		
		// Export multiple tables to a file in XML format
	} else if ( [contextInfo isEqualToString:@"exportMultipleTablesAsXML"] ) {
		success = [self exportSelectedTablesToFileHandle:fileHandle usingFormat:@"xml"];
		
		// Export the tables selected in the MySQL export sheet to a file
	} else if ( [contextInfo isEqualToString:@"exportDot"] ) {
			success = [self dumpSchemaAsDotToFileHandle:fileHandle];
			
		// Unknown operation
	} else {
		ALog(@"Unknown export operation: %@", [contextInfo description]);
		return;
	}
	
	// Close the file handle
	[fileHandle closeFile];
	
	if ( !success ) {
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
						  NSLocalizedString(@"Couldn't write to file. Be sure that you have the necessary privileges.", @"message of panel when file cannot be written"));
	}
    if (progressCancelled)
	{
		progressCancelled = NO;
	}
    // Export finished Growl notification
    [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Export Finished" 
                                                   description:[NSString stringWithFormat:NSLocalizedString(@"Finished exporting to %@",@"description for finished exporting growl notification"), [[sheet filename] lastPathComponent]] 
                                              notificationName:@"Export Finished"];
}

#pragma mark -
#pragma mark Import methods

- (void)importFile
/*
 invoked when user clicks on an import menuItem
 */
{
	// prepare open panel and accessory view
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAccessoryView:importCSVView];
	[openPanel setDelegate:self];
	if ([prefs valueForKey:@"importFormatPopupValue"]) {
		[importFormatPopup selectItemWithTitle:[prefs valueForKey:@"importFormatPopupValue"]];
		[self changeFormat:self];
	}
	
	// Show openPanel
	[openPanel beginSheetForDirectory:[prefs objectForKey:@"openPath"]
								 file:nil
					   modalForWindow:tableWindow
						modalDelegate:self
					   didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:nil];
}

- (IBAction)changeFormat:(id)sender
{
	[importCSVBox setHidden:![[[importFormatPopup selectedItem] title] isEqualToString:@"CSV"]];
}

- (IBAction)changeTable:(id)sender
{
	[tablesListInstance selectTableOrViewWithName:[fieldMappingPopup titleOfSelectedItem]];
	
	//set up tableView
	currentRow = 0;
	if (fieldMappingArray) [fieldMappingArray release], fieldMappingArray = nil;
	[self setupFieldMappingArray];
	[rowDownButton setEnabled:NO];
	[rowUpButton setEnabled:([importArray count] > 1)];
	[recordCountLabel setStringValue:[NSString stringWithFormat:@"%i of %i records", currentRow+1, [importArray count]]];
	
	[self updateFieldMappingButtonCell];
	[fieldMappingTableView reloadData];
}

- (void)importBackgroundProcess:(NSString*)filename
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

- (void) importSQLFile:(NSString *)filename
{
	NSAutoreleasePool *importPool;
	NSFileHandle *sqlFileHandle;
	NSMutableData *sqlDataBuffer;
	const unsigned char *sqlDataBufferBytes;
	NSData *fileChunk;
	NSString *sqlString;
	SPSQLParser *sqlParser;
	NSString *query;
	NSMutableString *errors = [NSMutableString string];
	NSInteger fileChunkMaxLength = 1024 * 1024;
	NSInteger fileTotalLength = 0;
	NSInteger fileProcessedLength = 0;
	NSInteger queriesPerformed = 0;
	NSInteger dataBufferLength = 0;
	NSInteger dataBufferPosition = 0;
	NSInteger dataBufferLastQueryEndPosition = 0;
	BOOL importSQLAsUTF8 = YES;
	BOOL allDataRead = NO;
	NSStringEncoding sqlEncoding = NSUTF8StringEncoding;
	NSCharacterSet *whitespaceAndNewlineCharset = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	// Open a filehandle for the SQL file
	sqlFileHandle = [NSFileHandle fileHandleForReadingAtPath:filename];
	if (!sqlFileHandle) {
		NSBeginAlertSheet(NSLocalizedString(@"Import Error title", @"Import Error"),
						  NSLocalizedString(@"OK button label", @"OK button"),
						  nil, nil, tableWindow, self, nil, nil, nil,
						  NSLocalizedString(@"SQL file open error", @"The SQL file you selected could not be found or read."));
		return;
	}

	// Grab the file length
	fileTotalLength = [[[[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:YES] objectForKey:NSFileSize] integerValue];
	if (!fileTotalLength) fileTotalLength = 1;

	// Reset progress interface
	[errorsView setString:@""];
	[singleProgressTitle setStringValue:NSLocalizedString(@"Importing SQL", @"text showing that the application is importing SQL")];
	[singleProgressText setStringValue:NSLocalizedString(@"Reading...", @"text showing that app is reading dump")];
	[singleProgressBar setIndeterminate:NO];
	[singleProgressBar setMaxValue:fileTotalLength];
	[singleProgressBar setUsesThreadedAnimation:YES];
				
	// Open the progress sheet
	[NSApp beginSheet:singleProgressSheet modalForWindow:tableWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	[singleProgressSheet makeKeyWindow];

	[tableDocumentInstance setQueryMode:SP_QUERYMODE_IMPORTEXPORT];

	// Read in the file in a loop
	sqlParser = [[SPSQLParser alloc] init];
	sqlDataBuffer = [[NSMutableData alloc] init];
	importPool = [[NSAutoreleasePool alloc] init];
	while (1) {
		@try {
			fileChunk = [sqlFileHandle readDataOfLength:fileChunkMaxLength];
		}

		// Report file read errors, and bail
		@catch (NSException *exception) {
			NSBeginAlertSheet(NSLocalizedString(@"SQL read error title", @"File read error"),
							  NSLocalizedString(@"OK", @"OK button"),
							  nil, nil, tableWindow, self, nil, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"SQL read error", @"An error occurred when reading the file.\n\nOnly %i queries were executed.\n\n(%@)"), queriesPerformed, [exception reason]]);
			[sqlParser release];
			[sqlDataBuffer release];
			[importPool drain];
			[tableDocumentInstance setQueryMode:SP_QUERYMODE_INTERFACE];
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
				if (importSQLAsUTF8) {
					sqlString = [[NSString alloc] initWithData:[sqlDataBuffer subdataWithRange:NSMakeRange(dataBufferLastQueryEndPosition, dataBufferPosition - dataBufferLastQueryEndPosition)]
													  encoding:NSUTF8StringEncoding];
					if (!sqlString) {
						importSQLAsUTF8 = NO;
						sqlEncoding = [MCPConnection encodingForMySQLEncoding:[[tableDocumentInstance connectionEncoding] UTF8String]];
					}
				}
				if (!importSQLAsUTF8) {
					sqlString = [[NSString alloc] initWithData:[sqlDataBuffer subdataWithRange:NSMakeRange(dataBufferLastQueryEndPosition, dataBufferPosition - dataBufferLastQueryEndPosition)]
													  encoding:[MCPConnection encodingForMySQLEncoding:[[tableDocumentInstance connectionEncoding] UTF8String]]];
					if (!sqlString) {
						NSBeginAlertSheet(NSLocalizedString(@"SQL read error title", @"File read error"),
										  NSLocalizedString(@"OK", @"OK button"),
										  nil, nil, tableWindow, self, nil, nil, nil,
										  [NSString stringWithFormat:NSLocalizedString(@"SQL encoding read error", @"An error occurred when reading the file, as it could not be read in either UTF-8 or %@.\n\nOnly %i queries were executed."), [[tableDocumentInstance connectionEncoding] UTF8String], queriesPerformed]);
						[sqlParser release];
						[sqlDataBuffer release];
						[importPool drain];
						[tableDocumentInstance setQueryMode:SP_QUERYMODE_INTERFACE];
						return;
					}
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

		// Extract and process any complete SQL queries that can be found in the strings parsed so far
		while (query = [sqlParser trimAndReturnStringToCharacter:';' trimmingInclusively:YES returningInclusively:NO]) {
			fileProcessedLength += [query lengthOfBytesUsingEncoding:sqlEncoding] + 1;
		
			// Skip blank or whitespace-only queries to avoid errors
			query = [query stringByTrimmingCharactersInSet:whitespaceAndNewlineCharset];
			if (![query length]) continue;
			
			// Run the query
			[mySQLConnection queryString:query usingEncoding:sqlEncoding streamingResult:NO];

			// Check for any errors
			if ([[mySQLConnection getLastErrorMessage] length] && ![[mySQLConnection getLastErrorMessage] isEqualToString:@"Query was empty"]) {
				[errors appendString:[NSString stringWithFormat:NSLocalizedString(@"[ERROR in query %d] %@\n", @"error text when multiple custom query failed"), (queriesPerformed+1), [mySQLConnection getLastErrorMessage]]];
			}

			// Increment the processed queries count
			queriesPerformed++;

			// Update the progress bar
			[singleProgressBar setDoubleValue:fileProcessedLength];
			[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Imported %@ of %@", @"SQL import progress text"),
				[NSString stringForByteSize:fileProcessedLength], [NSString stringForByteSize:fileTotalLength]]];
		}
		
		// If all the data has been read, break out of the processing loop
		if (allDataRead) break;

		// Reset the autorelease pool
		[importPool drain];
		importPool = [[NSAutoreleasePool alloc] init];
	}

	// If any text remains in the SQL parser, it's an unterminated query - execute it.
	query = [sqlParser stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([query length]) {

		// Run the query
		[mySQLConnection queryString:query usingEncoding:sqlEncoding streamingResult:NO];

		// Check for any errors
		if ([[mySQLConnection getLastErrorMessage] length] && ![[mySQLConnection getLastErrorMessage] isEqualToString:@"Query was empty"]) {
			[errors appendString:[NSString stringWithFormat:NSLocalizedString(@"[ERROR in query %d] %@\n", @"error text when multiple custom query failed"), (queriesPerformed+1), [mySQLConnection getLastErrorMessage]]];
		}

		// Increment the processed queries count
		queriesPerformed++;
	}

	// Clean up
	[sqlParser release];
	[sqlDataBuffer release];
	[importPool drain];
	[tableDocumentInstance setQueryMode:SP_QUERYMODE_INTERFACE];

	// Close progress sheet
	[NSApp endSheet:singleProgressSheet];
	[singleProgressSheet orderOut:nil];
	[singleProgressBar setMaxValue:100];
	
	// Display any errors
	if ([errors length]) {
		[errorsView setString:errors];
		[NSApp beginSheet:errorsSheet modalForWindow:tableWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
		[NSApp runModalForWindow:errorsSheet];
		[NSApp endSheet:errorsSheet];
		[errorsSheet orderOut:nil];
	}

	// Update available databases
	[tableDocumentInstance setDatabases:self];

	// Update current selected database
	[tableDocumentInstance refreshCurrentDatabase];

	// Update current database tables 
	[tablesListInstance updateTables:self];
	
    // Import finished Growl notification
    [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Import Finished" 
                                                   description:[NSString stringWithFormat:NSLocalizedString(@"Finished importing %@",@"description for finished importing growl notification"), [filename lastPathComponent]] 
                                              notificationName:@"Import Finished"];
}

- (void) importCSVFile:(NSString *)filename
{
	NSString *dumpFile = nil;
	NSError *errorStr = nil;
	NSMutableString *errors = [NSMutableString string];

	// Reset progress interface
	[errorsView setString:@""];
	[errorsView displayIfNeeded];
	[singleProgressTitle setStringValue:NSLocalizedString(@"Importing CSV", @"text showing that the application is importing CSV")];
	[singleProgressTitle displayIfNeeded];
	[singleProgressText setStringValue:NSLocalizedString(@"Reading...", @"text showing that app is reading dump")];
	[singleProgressText displayIfNeeded];
	[singleProgressBar setIndeterminate:YES];
	[singleProgressBar setUsesThreadedAnimation:YES];
	[singleProgressBar startAnimation:self];
	
	int code;

	//open progress sheet
	[NSApp beginSheet:singleProgressSheet
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:nil 
		  contextInfo:nil];
	[singleProgressSheet makeKeyWindow];

	[tableDocumentInstance setQueryMode:SP_QUERYMODE_IMPORTEXPORT];
	
	// Read the file with the current connection encoding.
	dumpFile = [NSString stringWithContentsOfFile:filename
										 encoding:[MCPConnection encodingForMySQLEncoding:[[tableDocumentInstance connectionEncoding] UTF8String]]
											error:&errorStr];

	if (errorStr) {
		[NSApp endSheet:singleProgressSheet];
		[singleProgressSheet orderOut:nil];
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"Error"),
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil,
						  tableWindow, self,
						  nil, nil, nil,
						  [errorStr localizedDescription]
						  );
		[tableDocumentInstance setQueryMode:SP_QUERYMODE_INTERFACE];
		return;
	}
	
	
	//put file in array
	if (importArray)
		[importArray release];
	
	importArray = [[self arrayForCSV:dumpFile
						terminatedBy:[importFieldsTerminatedField stringValue]
						  enclosedBy:[importFieldsEnclosedField stringValue]
						   escapedBy:[importFieldsEscapedField stringValue]
							lineEnds:[importLinesTerminatedField stringValue]] retain];
	
	long importArrayCount = [importArray count];
	
	//close progress sheet
	[NSApp endSheet:singleProgressSheet];
	[singleProgressSheet orderOut:nil];
	[singleProgressBar stopAnimation:self];
	[singleProgressBar setUsesThreadedAnimation:NO];
	[singleProgressBar setIndeterminate:NO];
	
	if(importArrayCount == 0){
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"Error"),
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil,
						  tableWindow, self,
						  nil, nil, nil,
						  NSLocalizedString(@"Could not parse file as CSV", @"Error when we can't parse/split file as CSV")
						  );
		[importArray release], importArray = nil;
		[tableDocumentInstance setQueryMode:SP_QUERYMODE_INTERFACE];
		return;
	}		
	
	if (progressCancelled) {
		progressCancelled = NO;
		[importArray release], importArray = nil;
		[tableDocumentInstance setQueryMode:SP_QUERYMODE_INTERFACE];
		return;
	}
	MCPResult *theResult;
	int i;
	theResult = (MCPResult *) [mySQLConnection listTables];
	if ([theResult numOfRows]) [theResult dataSeek:0];
	[fieldMappingPopup removeAllItems];
	for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
		[fieldMappingPopup addItemWithTitle:NSArrayObjectAtIndex([theResult fetchRowAsArray], 0)];
	}
	
	if ([tableDocumentInstance table] != nil && ![(NSString *)[tableDocumentInstance table] isEqualToString:@""]) {
		[fieldMappingPopup selectItemWithTitle:[(TableDocument *)tableDocumentInstance table]];
	} else {
		[fieldMappingPopup selectItemAtIndex:0];
	}
	
	if( ![tablesListInstance selectTableOrViewWithName:[fieldMappingPopup titleOfSelectedItem]] ) {
		[errors appendString:[NSString stringWithFormat:NSLocalizedString(@"[ERROR] %@\n", @"error text when trying to import csv data, but we have no tables in the db"), @"Can't import CSV data into a database without any tables!"]];				
	} else {
		
		//set up tableView
		currentRow = 0;

		// Sanity check the first row of the CSV to prevent hang loops caused by wrong line ending entry
		if ([[importArray objectAtIndex:currentRow] count] > 512) {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"),
							  NSLocalizedString(@"OK", @"OK button"),
							  nil, nil,
							  tableWindow, self,
							  nil, nil, nil,
							  NSLocalizedString(@"The CSV was read as containing more than 512 columns, more than the maximum columns permitted for speed reasons by Sequel Pro.\n\nThis usually happens due to errors reading the CSV; please double-check the CSV to be imported and the line endings and escape characters at the bottom of the CSV selection dialog.", @"Error when CSV appears to have too many columns to import, probably due to line ending mismatch")
							  );
			[importArray release], importArray = nil;
			[tableDocumentInstance setQueryMode:SP_QUERYMODE_INTERFACE];
			return;
		}
		
		if (fieldMappingArray) [fieldMappingArray release], fieldMappingArray = nil;
		[self setupFieldMappingArray];
		[rowDownButton setEnabled:NO];
		[rowUpButton setEnabled:(importArrayCount > 1)];
		[recordCountLabel setStringValue:[NSString stringWithFormat:@"%i of %i records", currentRow+1, importArrayCount]];
		
		//set up tableView buttons
		NSPopUpButtonCell *buttonCell = [[NSPopUpButtonCell alloc] init];
		[buttonCell setControlSize:NSSmallControlSize];
		[buttonCell setFont:[NSFont labelFontOfSize:[NSFont smallSystemFontSize]]];
		[buttonCell setBordered:NO];
		[[fieldMappingTableView tableColumnWithIdentifier:@"value"] setDataCell:buttonCell];
		[self updateFieldMappingButtonCell];
		[fieldMappingTableView reloadData];
		[buttonCell release];
		
		// show fieldMapping sheet
		[NSApp beginSheet:fieldMappingSheet
		   modalForWindow:tableWindow
			modalDelegate:self
		   didEndSelector:nil
			  contextInfo:nil];
		
		code = [NSApp runModalForWindow:fieldMappingSheet];
		[NSApp endSheet:fieldMappingSheet];
		[fieldMappingSheet orderOut:nil];
		
		if ( code ) {
			//import array into db
			NSMutableString *fNames = [NSMutableString string];
			//NSMutableArray *fValuesIndexes = [NSMutableArray array];
			NSMutableString *fValues = [NSMutableString string];
			NSString *insertFormatString = nil;
			int i,j;
			
			//open progress sheet
			[NSApp beginSheet:singleProgressSheet
			   modalForWindow:tableWindow
				modalDelegate:self
			   didEndSelector:nil
				  contextInfo:nil];
			
			[singleProgressBar setUsesThreadedAnimation:NO];
			[singleProgressSheet makeKeyWindow];
			[singleProgressText setStringValue:NSLocalizedString(@"Creating rows...", @"text showing that app is importing rows from CSV")];
			[singleProgressText displayIfNeeded];
			
			// get fields to be imported
			for (i = 0; i < [fieldMappingArray count] ; i++ ) {		
				if ([NSArrayObjectAtIndex(fieldMappingArray, i) intValue] > 0) {
					if ( [fNames length] )
						[fNames appendString:@","];
					
					[fNames appendString:[NSArrayObjectAtIndex([tableSourceInstance fieldNames], i) backtickQuotedString]];
				}
			}
			
			// import array
			long fieldMappingArrayCount = [fieldMappingArray count];
			insertFormatString = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%%@)", 
										[[fieldMappingPopup titleOfSelectedItem] backtickQuotedString], fNames];
			int fieldMappingIntValue;
			Class nullClass = [NSNull class];

			for ( i = 0 ; i < importArrayCount ; i++ ) {
				//show progress bar
				[singleProgressBar setDoubleValue:((i+1)*100/importArrayCount)];

				if ( !([importFieldNamesSwitch state] && (i == 0)) ) {
					//put values in string
					[fValues setString:@""];

					for ( j = 0 ; j < fieldMappingArrayCount ; j++ ) {
						fieldMappingIntValue = [NSArrayObjectAtIndex(fieldMappingArray,j) intValue];
						if ( fieldMappingIntValue > 0 ) {
							
							if ( [fValues length] )
								[fValues appendString:@","];

							id c = NSArrayObjectAtIndex(NSArrayObjectAtIndex(importArray, i), (fieldMappingIntValue - 1));

							[fValues appendString: ([c isMemberOfClass:nullClass]) ? 
								@"NULL" : [NSString stringWithFormat:@"'%@'", [mySQLConnection prepareString:c]]];
						}
					}
					
					//perform query
					[mySQLConnection queryString:[NSString stringWithFormat:insertFormatString, fValues]];
					
					if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
						[errors appendString:[NSString stringWithFormat:
								NSLocalizedString(@"[ERROR in line %d] %@\n", @"error text when reading of csv file gave errors"),
								(i+1),[mySQLConnection getLastErrorMessage]]];
					}
				}
			}
			
			//close progress sheet
			[NSApp endSheet:singleProgressSheet];
			[singleProgressSheet orderOut:nil];
		}
		
		[tableContentInstance loadTableValues];
	}
	
	//display errors
	if ( [errors length] ) {
		[errorsView setString:errors];
		[NSApp beginSheet:errorsSheet
		   modalForWindow:tableWindow
			modalDelegate:self
		   didEndSelector:nil
			  contextInfo:nil];
		
		[NSApp runModalForWindow:errorsSheet];			
		[NSApp endSheet:errorsSheet];
		[errorsSheet orderOut:nil];
	}
	
	//free arrays
	if (fieldMappingArray) [fieldMappingArray release], fieldMappingArray = nil;
	[importArray release], importArray = nil;

	[tableDocumentInstance setQueryMode:SP_QUERYMODE_INTERFACE];
	
    // Import finished Growl notification
    [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Import Finished" 
                                                   description:[NSString stringWithFormat:NSLocalizedString(@"Finished importing %@",@"description for finished importing growl notification"), [filename lastPathComponent]] 
                                              notificationName:@"Import Finished"];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{
	// save values to preferences
	[prefs setObject:[sheet directory] forKey:@"openPath"];
	[prefs setObject:[[importFormatPopup selectedItem] title] forKey:@"importFormatPopupValue"];
	
	// close sheet, and check if user canceled
	[sheet orderOut:self];
	if (returnCode != NSOKButton)
		return;
		
	// begin import process
	[NSThread detachNewThreadSelector:@selector(importBackgroundProcess:) toTarget:self withObject:[sheet filename]];
}

/*
 * Sets up the fieldMapping array to be shown in the tableView
 */
- (void)setupFieldMappingArray
{
	int i, value;
	
    if (!fieldMappingArray) {
        fieldMappingArray = [[NSMutableArray alloc] init];
		
		for (i = 0; i < [[tableSourceInstance fieldNames] count]; i++) {
			if (i < [NSArrayObjectAtIndex(importArray, currentRow) count] && ![NSArrayObjectAtIndex(NSArrayObjectAtIndex(importArray, currentRow), i) isKindOfClass:[NSNull class]]) {
				value = i + 1;
			} else {
				value = 0;
			}
			
            [fieldMappingArray addObject:[NSNumber numberWithInt:value]];
        }
    }
	
    [fieldMappingTableView reloadData];
}

/*
 * Update the NSButtonCell items for use in the field mapping display
 */
- (void)updateFieldMappingButtonCell
{
	int i;
	
	[fieldMappingButtonOptions setArray:[importArray objectAtIndex:currentRow]];
	for (i = 0; i < [fieldMappingButtonOptions count]; i++) {
		if ([[fieldMappingButtonOptions objectAtIndex:i] isNSNull]) {
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%i. %@", i+1, [prefs objectForKey:@"NullValue"]]];
		} else {
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%i. %@", i+1, NSArrayObjectAtIndex(fieldMappingButtonOptions, i)]];
		}
	}
}

- (IBAction)stepRow:(id)sender
/*
 displays next/previous row in fieldMapping tableView
 */
{
	if ( [sender tag] == 0 ) {
		currentRow--;
	} else {
		currentRow++;
	}
	[self updateFieldMappingButtonCell];
	
	//-----------[self setupFieldMappingArray];
	[fieldMappingTableView reloadData];
	
	[recordCountLabel setStringValue:[NSString stringWithFormat:@"%i of %i records", currentRow+1, [importArray count]]];
	
	// enable/disable buttons
	[rowDownButton setEnabled:(currentRow != 0)];
	[rowUpButton setEnabled:(currentRow != ([importArray count]-1))];
}

#pragma mark -
#pragma mark Format methods

/*
 Dump the selected tables to a file handle in SQL format.
 */
- (BOOL)dumpSelectedTablesAsSqlToFileHandle:(NSFileHandle *)fileHandle
{
	int i,j,t,rowCount, colCount, lastProgressValue, queryLength;
	int progressBarWidth;
	int tableType = SP_TABLETYPE_TABLE; //real tableType will be setup later
	MCPResult *queryResult;
	MCPStreamingResult *streamingResult;
	NSAutoreleasePool *exportAutoReleasePool = nil;
	NSString *tableName, *tableColumnTypeGrouping, *previousConnectionEncoding;
	NSArray *fieldNames;
	NSArray *theRow;
	NSMutableArray *selectedTables = [NSMutableArray array];
	NSMutableDictionary *viewSyntaxes = [NSMutableDictionary dictionary];
	NSMutableString *metaString = [NSMutableString string];
	NSMutableString *cellValue = [NSMutableString string];
	NSMutableString *sqlString = [[NSMutableString alloc] init];
	NSMutableString *errors = [NSMutableString string];
	NSDictionary *tableDetails;
	NSMutableArray *tableColumnNumericStatus;
	NSEnumerator *viewSyntaxEnumerator;
	NSStringEncoding connectionEncoding = [mySQLConnection encoding];
	id createTableSyntax = nil;
	BOOL previousConnectionEncodingViaLatin1;
	
	// Reset the interface
	[errorsView setString:@""];
	[errorsView displayIfNeeded];
	[singleProgressTitle setStringValue:NSLocalizedString(@"Exporting SQL", @"text showing that the application is exporting SQL")];
	[singleProgressTitle displayIfNeeded];
	[singleProgressText setStringValue:NSLocalizedString(@"Dumping...", @"text showing that app is writing dump")];
	[singleProgressText displayIfNeeded];
	[singleProgressBar setDoubleValue:0];
	[singleProgressBar displayIfNeeded];
	progressBarWidth = (int)[singleProgressBar bounds].size.width;
	[singleProgressBar setMaxValue:progressBarWidth];
	
	// Open the progress sheet
	[NSApp beginSheet:singleProgressSheet
	   modalForWindow:tableWindow modalDelegate:self
	   didEndSelector:nil contextInfo:nil];

	[tableDocumentInstance setQueryMode:SP_QUERYMODE_IMPORTEXPORT];

	// Copy over the selected table names into a table in preparation for iteration
	for ( i = 0 ; i < [tables count] ; i++ ) {
		if ( [NSArrayObjectAtIndex(NSArrayObjectAtIndex(tables, i), 0) boolValue] ) {
			[selectedTables addObject:[NSString stringWithString:NSArrayObjectAtIndex(NSArrayObjectAtIndex(tables, i), 1)]];
		}
	}
	
	// Add the dump header to the dump file.
	[metaString setString:@"# Sequel Pro dump\n"];
	[metaString appendString:[NSString stringWithFormat:@"# Version %@\n",
							 [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
	[metaString appendString:@"# http://code.google.com/p/sequel-pro\n#\n"];
	[metaString appendString:[NSString stringWithFormat:@"# Host: %@ (MySQL %@)\n",
							 [tableDocumentInstance host], [tableDocumentInstance mySQLVersion]]];
	[metaString appendString:[NSString stringWithFormat:@"# Database: %@\n", [tableDocumentInstance database]]];
	[metaString appendString:[NSString stringWithFormat:@"# Generation Time: %@\n", [NSDate date]]];
	[metaString appendString:@"# ************************************************************\n\n"];

	// Add commands to store the client encodings used when importing and set to UTF8 to preserve data
	[metaString appendString:@"/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;\n"];
	[metaString appendString:@"/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;\n"];
	[metaString appendString:@"/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;\n"];
	[metaString appendString:@"/*!40101 SET NAMES utf8 */;\n"];
	
	// Add commands to store and disable unique checks, foreign key checks, mode and notes where supported.
	// Include trailing semicolons to ensure they're run individually.  Use mysql-version based comments.
	if ( [addDropTableSwitch state] == NSOnState )
		[metaString appendString:@"/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;\n"];
	[metaString appendString:@"/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;\n"];
	[metaString appendString:@"/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;\n"];
	[metaString appendString:@"/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;\n\n\n"];

	[fileHandle writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];

	// Store the current connection encoding so it can be restored after the dump.
	previousConnectionEncoding = [[NSString alloc] initWithString:[tableDocumentInstance connectionEncoding]];
	previousConnectionEncodingViaLatin1 = [tableDocumentInstance connectionEncodingViaLatin1:nil];
	
	// Set the connection to UTF8 to be able to export correctly.
	[tableDocumentInstance setConnectionEncoding:@"utf8" reloadingViews:NO];
	
	// Loop through the selected tables
	for ( i = 0 ; i < [selectedTables count] ; i++ ) {
		lastProgressValue = 0;
		
		// Update the progress text and reset the progress bar to indeterminate status while fetching data
		tableName = NSArrayObjectAtIndex(selectedTables, i);
		[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %i of %i (%@): Fetching data...", @"text showing that app is fetching data for table dump"), (i+1), [selectedTables count], tableName]];
		[singleProgressText displayIfNeeded];
		[singleProgressBar setIndeterminate:YES];
		[singleProgressBar setUsesThreadedAnimation:YES];
		[singleProgressBar startAnimation:self];
		
		// Add the name of table
		[fileHandle writeData:[[NSString stringWithFormat:@"# Dump of table %@\n# ------------------------------------------------------------\n\n", tableName]
							   dataUsingEncoding:NSUTF8StringEncoding]];
		
		
		// Determine whether this table is a table or a view via the create table command, and keep the create table syntax
		queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE %@", [tableName backtickQuotedString]]];
		if ( [queryResult numOfRows] ) {
			tableDetails = [[NSDictionary alloc] initWithDictionary:[queryResult fetchRowAsDictionary]];
			if ([tableDetails objectForKey:@"Create View"]) {
				[viewSyntaxes setValue:[[[[tableDetails objectForKey:@"Create View"] copy] autorelease] createViewSyntaxPrettifier] forKey:tableName];
				createTableSyntax = [self createViewPlaceholderSyntaxForView:tableName];
				tableType = SP_TABLETYPE_VIEW;
			} else {
				createTableSyntax = [[[tableDetails objectForKey:@"Create Table"] copy] autorelease];
				tableType = SP_TABLETYPE_TABLE;
			}
			[tableDetails release];
		}
		if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
			[errors appendString:[NSString stringWithFormat:@"%@\n", [mySQLConnection getLastErrorMessage]]];
			if ( [addErrorsSwitch state] == NSOnState ) {
				[fileHandle writeData:[[NSString stringWithFormat:@"# Error: %@\n", [mySQLConnection getLastErrorMessage]] dataUsingEncoding:NSUTF8StringEncoding]];
			}
		}


		// Add a "drop table" command if specified in the export dialog
		if ( [addDropTableSwitch state] == NSOnState )
			[fileHandle writeData:[[NSString stringWithFormat:@"DROP %@ IF EXISTS %@;\n\n", ((tableType == SP_TABLETYPE_TABLE)?@"TABLE":@"VIEW"), [tableName backtickQuotedString]]
								   dataUsingEncoding:NSUTF8StringEncoding]];
		

		// Add the create syntax for the table if specified in the export dialog
		if ( [addCreateTableSwitch state] == NSOnState && createTableSyntax) {
			if ( [createTableSyntax isKindOfClass:[NSData class]] ) {
				createTableSyntax = [[[NSString alloc] initWithData:createTableSyntax encoding:connectionEncoding] autorelease];
			}
			[fileHandle writeData:[createTableSyntax dataUsingEncoding:NSUTF8StringEncoding]];
			[fileHandle writeData:[[NSString stringWithString:@";\n\n"] dataUsingEncoding:NSUTF8StringEncoding]];
		}
		
		// Add the table content if required
		if ( [addTableContentSwitch state] == NSOnState && tableType == SP_TABLETYPE_TABLE ) {

			// Retrieve the table details via the data class, and use it to build an array containing column numeric status
			tableDetails = [NSDictionary dictionaryWithDictionary:[tableDataInstance informationForTable:tableName]];
			colCount = [[tableDetails objectForKey:@"columns"] count];
			tableColumnNumericStatus = [NSMutableArray arrayWithCapacity:colCount];
			for ( j = 0; j < colCount ; j++ ) {
				tableColumnTypeGrouping = [NSArrayObjectAtIndex([tableDetails objectForKey:@"columns"], j) objectForKey:@"typegrouping"];
				if ([tableColumnTypeGrouping isEqualToString:@"bit"] || [tableColumnTypeGrouping isEqualToString:@"integer"]
					|| [tableColumnTypeGrouping isEqualToString:@"float"]) {
					[tableColumnNumericStatus addObject:[NSNumber numberWithBool:YES]];
				} else {
					[tableColumnNumericStatus addObject:[NSNumber numberWithBool:NO]];
				}
			}

			// Retrieve the number of rows in the table for progress bar drawing
			rowCount = [[[[mySQLConnection queryString:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@", [tableName backtickQuotedString]]] fetchRowAsArray] objectAtIndex:0] integerValue];
			
			// Set up a result set in streaming mode
			streamingResult = [mySQLConnection streamingQueryString:[NSString stringWithFormat:@"SELECT * FROM %@", [tableName backtickQuotedString]] useLowMemoryBlockingStreaming:([sqlFullStreamingSwitch state] == NSOnState)];
			fieldNames = [streamingResult fetchFieldNames];			
			
			// Update the progress text and set the progress bar back to determinate
			[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %i of %i (%@): Dumping...", @"text showing that app is writing data for table dump"), (i+1), [selectedTables count], tableName]];
			[singleProgressText displayIfNeeded];
			[singleProgressBar stopAnimation:self];
			[singleProgressBar setIndeterminate:NO];
			[singleProgressBar setDoubleValue:0];
			[singleProgressBar displayIfNeeded];
			
			if (rowCount) {
				queryLength = 0;
				
				// Lock the table for writing and disable keys if supported
				[metaString setString:@""];
				[metaString appendString:[NSString stringWithFormat:@"LOCK TABLES %@ WRITE;\n", [tableName backtickQuotedString]]];
				[metaString appendString:[NSString stringWithFormat:@"/*!40000 ALTER TABLE %@ DISABLE KEYS */;\n", [tableName backtickQuotedString]]];
				[fileHandle writeData:[metaString dataUsingEncoding:connectionEncoding]];

				// Construct the start of the insertion command
				[fileHandle writeData:[[NSString stringWithFormat:@"INSERT INTO %@ (%@)\nVALUES\n\t(",
										[tableName backtickQuotedString], [fieldNames componentsJoinedAndBacktickQuoted]] dataUsingEncoding:NSUTF8StringEncoding]];
				
				// Iterate through the rows to construct a VALUES group for each
				j = 0;
				exportAutoReleasePool = [[NSAutoreleasePool alloc] init];
				while (theRow = [streamingResult fetchNextRowAsArray]) {
					j++;
					[sqlString setString:@""];
					
					// Update the progress bar
					[singleProgressBar setDoubleValue:(j*progressBarWidth/rowCount)];
					if ((int)[singleProgressBar doubleValue] > lastProgressValue) {
						lastProgressValue = (int)[singleProgressBar doubleValue];
						[singleProgressBar displayIfNeeded];
					}
					
					for ( t = 0 ; t < colCount ; t++ ) {
						
						// Add NULL values directly to the output row
						if ( [[theRow objectAtIndex:t] isMemberOfClass:[NSNull class]] ) {
							[sqlString appendString:@"NULL"];
							
						// Add data types directly as hex data
						} else if ( [[theRow objectAtIndex:t] isKindOfClass:[NSData class]] ) {
							[sqlString appendString:@"X'"];
							[sqlString appendString:[mySQLConnection prepareBinaryData:[theRow objectAtIndex:t]]];
							[sqlString appendString:@"'"];
							
						} else {
							[cellValue setString:[[theRow objectAtIndex:t] description]];
							
							// Add empty strings as a pair of quotes
							if ([cellValue length] == 0) {
								[sqlString appendString:@"''"];
								
							} else {
								
								// If this is a numeric column type, add the number directly.
								if ( [[tableColumnNumericStatus objectAtIndex:t] boolValue] ) {
									[sqlString appendString:cellValue];
									
								// Otherwise add a quoted string with special characters escaped
								} else {
									[sqlString appendString:@"'"];
									[sqlString appendString:[mySQLConnection prepareString:cellValue]];
									[sqlString appendString:@"'"];
								}
							}
						}
						
						// Add the field separator if this isn't the last cell in the row
						if (t != [theRow count] - 1) [sqlString appendString:@","];
					}
					
					queryLength += [sqlString length];
					
					// Close this VALUES group and set up the next one if appropriate
					if (j != rowCount) {
						
						// Add a new INSERT starter command every ~250k of data.
						if (queryLength > 250000) {
							[sqlString appendString:[NSString stringWithFormat:@");\n\nINSERT INTO %@ (%@)\nVALUES\n\t(",
													 [tableName backtickQuotedString], [fieldNames componentsJoinedAndBacktickQuoted]]];
							queryLength = 0;
							
							// Use the opportunity to drain and reset the autorelease pool
							[exportAutoReleasePool drain];
							exportAutoReleasePool = [[NSAutoreleasePool alloc] init];
						} else {
							[sqlString appendString:@"),\n\t("];
						}
					} else {
						[sqlString appendString:@")"];
					}
					
					// Write this row to the file
					[fileHandle writeData:[sqlString dataUsingEncoding:NSUTF8StringEncoding]];
				}
				
				// Complete the command
				[fileHandle writeData:[[NSString stringWithString:@";\n\n"] dataUsingEncoding:NSUTF8StringEncoding]];

				// Unlock the table and re-enable keys if supported
				[metaString setString:@""];
				[metaString appendString:[NSString stringWithFormat:@"/*!40000 ALTER TABLE %@ ENABLE KEYS */;\n", [tableName backtickQuotedString]]];
				[metaString appendString:@"UNLOCK TABLES;\n"];
				[fileHandle writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
				
				if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
					[errors appendString:[NSString stringWithFormat:@"%@\n", [mySQLConnection getLastErrorMessage]]];
					if ( [addErrorsSwitch state] == NSOnState ) {
						[fileHandle writeData:[[NSString stringWithFormat:@"# Error: %@\n", [mySQLConnection getLastErrorMessage]]
											   dataUsingEncoding:NSUTF8StringEncoding]];
					}
				}

				// Drain the autorelease pool
				[exportAutoReleasePool drain];
			}

			// Release the result set
			[streamingResult release];
		}
		
		// Add an additional separator between tables
		[fileHandle writeData:[[NSString stringWithString:@"\n\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	// Process any deferred views, adding commands to delete the placeholder tables and add the actual views
	viewSyntaxEnumerator = [viewSyntaxes keyEnumerator];
	while (tableName = [viewSyntaxEnumerator nextObject]) {
		[metaString setString:@"\n\n"];
		[metaString appendFormat:@"DROP TABLE %@;\n", [tableName backtickQuotedString]];
		[metaString appendFormat:@"%@;\n", [viewSyntaxes objectForKey:tableName]];
		[fileHandle writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
	}

	// Restore unique checks, foreign key checks, and other settings saved at the start
	[metaString setString:@"\n\n\n"];
	[metaString appendString:@"/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;\n"];
	[metaString appendString:@"/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;\n"];
	[metaString appendString:@"/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;\n"];
	if ( [addDropTableSwitch state] == NSOnState )
		[metaString appendString:@"/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;\n"];

	// Restore the client encoding to the original encoding before import
	[metaString appendString:@"/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;\n"];
	[metaString appendString:@"/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;\n"];
	[metaString appendString:@"/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;\n"];

	// Write footer-type information to the file
	[fileHandle writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];

	// Restore the connection character set to pre-export details
	[tableDocumentInstance
	 setConnectionEncoding:[NSString stringWithFormat:@"%@%@", previousConnectionEncoding, previousConnectionEncodingViaLatin1?@"-":@""]
	 reloadingViews:NO];
	[previousConnectionEncoding release];
	
	// Close the progress sheet
	[NSApp endSheet:singleProgressSheet];
	[singleProgressSheet orderOut:nil];

	// Restore the default maximum of the progress bar
	[singleProgressBar setMaxValue:100];

	// Show errors sheet if there have been errors
	if ( [errors length] ) {
		[errorsView setString:errors];
		[NSApp beginSheet:errorsSheet
		   modalForWindow:tableWindow modalDelegate:self
		   didEndSelector:nil contextInfo:nil];
		[NSApp runModalForWindow:errorsSheet];
		[NSApp endSheet:errorsSheet];
		[errorsSheet orderOut:nil];
	}

	[tableDocumentInstance setQueryMode:SP_QUERYMODE_INTERFACE];

	[sqlString release];
	return TRUE;
}

/*
 Dump the selected tables to a file handle in Graphviz dot format.
 */
- (BOOL)dumpSchemaAsDotToFileHandle:(NSFileHandle *)fileHandle
{
	NSMutableString *metaString = [NSMutableString string];
	int  progressBarWidth;
	NSString *previousConnectionEncoding;
	BOOL previousConnectionEncodingViaLatin1;
	
	[singleProgressTitle setStringValue:NSLocalizedString(@"Exporting Dot file", @"text showing that the application is exporting a Dot file")];
	[singleProgressTitle displayIfNeeded];
	[singleProgressText setStringValue:NSLocalizedString(@"Dumping...", @"text showing that app is writing dump")];
	[singleProgressText displayIfNeeded];
	progressBarWidth = (int)[singleProgressBar bounds].size.width;
	[singleProgressBar setDoubleValue:0];
	[singleProgressBar displayIfNeeded];
	
	// Open the progress sheet
	[NSApp beginSheet:singleProgressSheet
	   modalForWindow:tableWindow modalDelegate:self
	   didEndSelector:nil contextInfo:nil];
		
	[metaString setString:@"// Generated by: Sequel Pro\n"];
	[metaString appendString:[NSString stringWithFormat:@"// Version %@\n",
							  [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
	[metaString appendString:@"// http://code.google.com/p/sequel-pro\n//\n"];
	[metaString appendString:[NSString stringWithFormat:@"// Host: %@ (MySQL %@)\n",
							  [tableDocumentInstance host], [tableDocumentInstance mySQLVersion]]];
	[metaString appendString:[NSString stringWithFormat:@"// Database: %@\n", [tableDocumentInstance database]]];
	[metaString appendString:[NSString stringWithFormat:@"// Generation Time: %@\n", [NSDate date]]];
	[metaString appendString:@"// ************************************************************\n\n"];
	
	[metaString appendString:@"digraph \"Database Structure\" {\n"];
	[metaString appendString:[NSString stringWithFormat:@"\tlabel = \"ER Diagram: %@\";\n", [tableDocumentInstance database]]];
	[metaString appendString:@"\tlabelloc = t;\n"];
	[metaString appendString:@"\tcompound = true;\n"];
	[metaString appendString:@"\tnode [ shape = record ];\n"];
	[metaString appendString:@"\tfontname = \"Helvetica\";\n"];
	[metaString appendString:@"\tranksep = 1.25;\n"];
	[metaString appendString:@"\tratio = 0.7;\n"];
	[metaString appendString:@"\trankdir = LR;\n"];

	// Write information to the file
	[fileHandle writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
	
	// store connection encoding
	previousConnectionEncoding = [[NSString alloc] initWithString:[tableDocumentInstance connectionEncoding]];
	previousConnectionEncodingViaLatin1 = [tableDocumentInstance connectionEncodingViaLatin1:nil];
	
	NSMutableArray *fkInfo = [[NSMutableArray alloc] init];
	
	// tables here
	for ( int i = 0 ; i < [tables count] ; i++ ) {

		NSString *tableName = [[tables objectAtIndex:i] objectAtIndex:1];
		NSDictionary *tinfo = [tableDataInstance informationForTable:tableName];

		[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %i of %i (%@): Fetching data...", @"text showing that app is fetching data for table dump"), (i+1), [tables count], tableName]];
		[singleProgressText displayIfNeeded];
		[singleProgressBar setIndeterminate:YES];
		[singleProgressBar setUsesThreadedAnimation:YES];
		[singleProgressBar startAnimation:self];
		
		NSString *hdrColor = @"#DDDDDD";
		if( [[tinfo objectForKey:@"type"] isEqualToString:@"View"] ) {
			hdrColor = @"#DDDDFF";
		}
		
		[metaString setString:[NSString stringWithFormat:@"\tsubgraph \"table_%@\" {\n", tableName]];
		[metaString appendString:@"\t\tnode = [ shape = \"plaintext\" ];\n"];
		[metaString appendString:[NSString stringWithFormat:@"\t\t\"%@\" [ label=<\n", tableName]];
		[metaString appendString:@"\t\t\t<TABLE BORDER=\"0\" CELLSPACING=\"0\" CELLBORDER=\"1\">\n"];
		[metaString appendString:[NSString stringWithFormat:@"\t\t\t<TR><TD COLSPAN=\"3\" BGCOLOR=\"%@\">%@</TD></TR>\n", hdrColor, tableName]];
		
		// grab column info
		NSArray *cinfo = [tinfo objectForKey:@"columns"];
		for( int j = 0; j < [cinfo count]; j++ ) {
			[metaString appendString:[NSString stringWithFormat:@"\t\t\t<TR><TD COLSPAN=\"3\" PORT=\"%@\">%@:<FONT FACE=\"Helvetica-Oblique\" POINT-SIZE=\"10\">%@</FONT></TD></TR>\n", [[cinfo objectAtIndex:j] objectForKey:@"name"], [[cinfo objectAtIndex:j] objectForKey:@"name"], [[cinfo objectAtIndex:j] objectForKey:@"type"]]];
		}
		
		[metaString appendString:@"\t\t\t</TABLE>>\n"];
		[metaString appendString:@"\t\t];\n"];
		[metaString appendString:@"\t}\n"];
		[fileHandle writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
		
		// see about relations
		cinfo = [tinfo objectForKey:@"constraints"];
		for( int j = 0; j < [cinfo count]; j++ ) {
			// get the column refs. these can be comma separated.
			NSString *ccol = [NSArrayObjectAtIndex(cinfo, j) objectForKey:@"columns"];
			NSString *rcol = [NSArrayObjectAtIndex(cinfo, j) objectForKey:@"ref_columns"];
			NSString *extra = @"";
			NSArray *tc = [ccol componentsSeparatedByString:@","];
			if( [tc count] > 1 ) {
				extra = @" [ arrowhead=crow, arrowtail=odiamond ]";
				ccol = NSArrayObjectAtIndex(tc, 0);
				rcol = NSArrayObjectAtIndex([ccol componentsSeparatedByString:@","], 0);
			}
			[fkInfo addObject:[NSString stringWithFormat:@"%@:%@ -> %@:%@ %@",
							   tableName,
							   ccol,
							   [NSArrayObjectAtIndex(cinfo, j) objectForKey:@"ref_table"],
							   rcol,
							   extra
							   ]];
		}
		
	}

	[singleProgressText setStringValue:NSLocalizedString(@"Fetching relations...", @"text showing that app is fetching data")];
	[singleProgressText displayIfNeeded];
	[singleProgressBar setIndeterminate:YES];
	[singleProgressBar setUsesThreadedAnimation:YES];
	[singleProgressBar startAnimation:self];
	
	[metaString setString:@"edge [ arrowhead=inv, arrowtail=normal, style=dashed, color=\"#444444\" ];\n"];
	
	// grab the relations
	for( int i = 0; i < [fkInfo count]; i++ ) {
		[metaString appendString:[NSString stringWithFormat:@"%@;\n", [fkInfo objectAtIndex:i]]];
	}
	
	[fkInfo release];
	
	// done
	[metaString appendString:@"}\n"];
	
	// Write information to the file
	[fileHandle writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];

	// Restore the connection character set to pre-export details
	[tableDocumentInstance
	 setConnectionEncoding:[NSString stringWithFormat:@"%@%@", previousConnectionEncoding, previousConnectionEncodingViaLatin1?@"-":@""]
	 reloadingViews:NO];
	[previousConnectionEncoding release];

	
	// Close the progress sheet
	[NSApp endSheet:singleProgressSheet];
	[singleProgressSheet orderOut:nil];
	
	
	return TRUE;
}


/*
 * Takes an array, or a streaming result set, and writes the appropriate data
 * in CSV format to the supplied NSFileHandle.
 * The field terminators, quotes and escape characters should all be supplied
 * together with the line terminators; if an array of numeric column types is
 * supplied, processing of rows is significantly sped up as each field does not
 * need to be parsed.
 * Also takes a totalRows parameter, which is used for drawing progress bars -
 * for arrays, this must be accurate, but for streaming result sets it is only
 * used for drawing the progress bar.
 */
- (BOOL)writeCsvForArray:(NSArray *)array orStreamingResult:(MCPStreamingResult *)streamingResult toFileHandle:(NSFileHandle *)fileHandle
		outputFieldNames:(BOOL)outputFieldNames
		terminatedBy:(NSString *)fieldSeparatorString
		enclosedBy:(NSString *)enclosingString
		escapedBy:(NSString *)escapeString
		lineEnds:(NSString *)lineEndString
		withNumericColumns:(NSArray *)tableColumnNumericStatus
		totalRows:(NSInteger)totalRows
		silently:(BOOL)silently;
{
	NSAutoreleasePool *csvExportPool;
	NSStringEncoding tableEncoding = [MCPConnection encodingForMySQLEncoding:[[tableDocumentInstance connectionEncoding] UTF8String]];
	NSMutableString *csvCellString = [NSMutableString string];
	NSArray *csvRow;
	id csvCell;
	NSMutableString *csvString = [NSMutableString string];
	NSString *nullString = [NSString stringWithString:[prefs objectForKey:@"NullValue"]];
	NSString *escapedEscapeString, *escapedFieldSeparatorString, *escapedEnclosingString, *escapedLineEndString;
	NSString *dataConversionString;
	NSInteger currentRowIndex;
	NSScanner *csvNumericTester;
	BOOL quoteFieldSeparators = [enclosingString isEqualToString:@""];
	BOOL csvCellIsNumeric;
	int i, progressBarWidth, lastProgressValue, currentPoolDataLength;
	int csvCellCount = 0;

	// Detect and restore special characters being used as terminating or line end strings
	NSMutableString *tempSeparatorString = [NSMutableString stringWithString:fieldSeparatorString];
	[tempSeparatorString replaceOccurrencesOfString:@"\\t" withString:@"\t"
											options:NSLiteralSearch
											  range:NSMakeRange(0, [tempSeparatorString length])];
	[tempSeparatorString replaceOccurrencesOfString:@"\\n" withString:@"\n"
											options:NSLiteralSearch
											  range:NSMakeRange(0, [tempSeparatorString length])];
	[tempSeparatorString replaceOccurrencesOfString:@"\\r" withString:@"\r"
											options:NSLiteralSearch
											  range:NSMakeRange(0, [tempSeparatorString length])];
	fieldSeparatorString = [NSString stringWithString:tempSeparatorString];
	NSMutableString *tempLineEndString = [NSMutableString stringWithString:lineEndString];
	[tempLineEndString replaceOccurrencesOfString:@"\\t" withString:@"\t"
										  options:NSLiteralSearch
											range:NSMakeRange(0, [tempLineEndString length])];
	[tempLineEndString replaceOccurrencesOfString:@"\\n" withString:@"\n"
										  options:NSLiteralSearch
											range:NSMakeRange(0, [tempLineEndString length])];
	[tempLineEndString replaceOccurrencesOfString:@"\\r" withString:@"\r"
										  options:NSLiteralSearch
											range:NSMakeRange(0, [tempLineEndString length])];
	lineEndString = [NSString stringWithString:tempLineEndString];
	
	// Updating the progress bar can take >20% of processing time - store details to only update when required
	progressBarWidth = (int)[singleProgressBar bounds].size.width;
	lastProgressValue = 0;
	[singleProgressBar setMaxValue:progressBarWidth];
	[singleProgressBar setDoubleValue:0];
	[singleProgressBar setIndeterminate:NO];
	[singleProgressBar setUsesThreadedAnimation:YES];
	[singleProgressBar displayIfNeeded];
	
	if ( !silently ) {
		
		// Set the progress text
		[singleProgressTitle setStringValue:NSLocalizedString(@"Exporting CSV", @"text showing that the application is exporting a CSV")];
		[singleProgressText setStringValue:NSLocalizedString(@"Writing...", @"text showing that app is writing text file")];
		
		// Open progress sheet
		[NSApp beginSheet:singleProgressSheet
		   modalForWindow:tableWindow modalDelegate:self
		   didEndSelector:nil contextInfo:nil];
	}
	
	// Set up escaped versions of strings for substitution within the loop
	escapedEscapeString = [NSString stringWithFormat:@"%@%@", escapeString, escapeString];
	escapedFieldSeparatorString = [NSString stringWithFormat:@"%@%@", escapeString, fieldSeparatorString];
	escapedEnclosingString = [NSString stringWithFormat:@"%@%@", escapeString, enclosingString];
	escapedLineEndString = [NSString stringWithFormat:@"%@%@", escapeString, lineEndString];
	
	// Set up the starting row; for supplied arrays, which include the column
	// headers as the first row, decide whether to skip the first row.
	currentRowIndex = 0;
	if (array && !outputFieldNames) {
		currentRowIndex++;
	}

	// Drop into the processing loop
	csvExportPool = [[NSAutoreleasePool alloc] init];
	currentPoolDataLength = 0;
	while (1) {

		// Retrieve the next row from the supplied data, either directly from the array...
		if (array) {
			csvRow = NSArrayObjectAtIndex(array, currentRowIndex);

		// Or by reading an appropriate row from the streaming result
		} else {
			
			// If still requested to read the field names, get the field names
			if (outputFieldNames) {
				csvRow = [streamingResult fetchFieldNames];
				outputFieldNames = NO;
			} else {
				csvRow = [streamingResult fetchNextRowAsArray];
				if (!csvRow) break;
			}
		}
		
		// Get the cell count if we don't already have it stored
		if (!csvCellCount) csvCellCount = [csvRow count];
		
		[csvString setString:@""];
		for ( i = 0 ; i < csvCellCount ; i++ ) {
			csvCell = NSArrayObjectAtIndex(csvRow, i);

			// For NULL objects supplied from a queryResult, add an unenclosed null string as per prefs
			if ([csvCell isKindOfClass:[NSNull class]]) {
				[csvString appendString:nullString];
				if (i < csvCellCount - 1) [csvString appendString:fieldSeparatorString];
				continue;
			}
			
			// Retrieve the contents of this cell
			if ([csvCell isKindOfClass:[NSData class]]) {
				dataConversionString = [[NSString alloc] initWithData:csvCell encoding:tableEncoding];
				if (dataConversionString == nil)
					dataConversionString = [[NSString alloc] initWithData:csvCell encoding:NSASCIIStringEncoding];
				[csvCellString setString:[NSString stringWithString:dataConversionString]];
				[dataConversionString release];
			} else {
				[csvCellString setString:[csvCell description]];
			}
			
			// For NULL values supplied via an array add the unenclosed null string as set in preferences
			if ( [csvCellString isEqualToString:nullString] ) {
				[csvString appendString:nullString];

			// Add empty strings as a pair of enclosing characters.
			} else if ( [csvCellString length] == 0 ) {
				[csvString appendString:enclosingString];
				[csvString appendString:enclosingString];
				
			} else {
				
				// If an array of bools supplying information as to whether the column is numeric has been supplied, use it.
				if (tableColumnNumericStatus != nil) {
					csvCellIsNumeric = [NSArrayObjectAtIndex(tableColumnNumericStatus, i) boolValue];

				// Otherwise, first test whether this cell contains data
				} else if ([NSArrayObjectAtIndex(csvRow, i) isKindOfClass:[NSData class]]) {
					csvCellIsNumeric = FALSE;

				// Or fall back to testing numeric content via an NSScanner.
				} else {
					csvNumericTester = [NSScanner scannerWithString:csvCellString];
					csvCellIsNumeric = [csvNumericTester scanFloat:nil] && [csvNumericTester isAtEnd]
										&& ([csvCellString characterAtIndex:0] != '0'
											|| [csvCellString length] == 1
											|| ([csvCellString length] > 1 && [csvCellString characterAtIndex:1] == '.'));
				}
				
				// Escape any occurrences of the escaping character
				[csvCellString replaceOccurrencesOfString:escapeString
											   withString:escapedEscapeString
												  options:NSLiteralSearch
													range:NSMakeRange(0, [csvCellString length])];
				
				// Escape any occurrences of the enclosure string
				if ( ![escapeString isEqualToString:enclosingString] ) {
					[csvCellString replaceOccurrencesOfString:enclosingString
												   withString:escapedEnclosingString
													  options:NSLiteralSearch
														range:NSMakeRange(0, [csvCellString length])];
				}
				
				// Escape occurrences of the line end character
				[csvCellString replaceOccurrencesOfString:lineEndString
											   withString:escapedLineEndString
												  options:NSLiteralSearch
													range:NSMakeRange(0, [csvCellString length])];

				// If the string isn't quoted or otherwise enclosed, escape occurrences of the
				// field separators
				if ( quoteFieldSeparators || csvCellIsNumeric ) {
					[csvCellString replaceOccurrencesOfString:fieldSeparatorString
												   withString:escapedFieldSeparatorString
													  options:NSLiteralSearch
														range:NSMakeRange(0, [csvCellString length])];
				}
				
				// Write out the cell data by appending strings - this is significantly faster than stringWithFormat.
				if (csvCellIsNumeric) {
					[csvString appendString:csvCellString];
				} else {
					[csvString appendString:enclosingString];
					[csvString appendString:csvCellString];
					[csvString appendString:enclosingString];
				}
			}
			if (i < csvCellCount - 1) [csvString appendString:fieldSeparatorString];
		}
		
		// Append the line ending to the string for this row, and record the length processed for pool flushing
		[csvString appendString:lineEndString];
		currentPoolDataLength += [csvString length];
		
		// Write it to the fileHandle
		[fileHandle writeData:[csvString dataUsingEncoding:tableEncoding]];

		// Update the progress counter and progress bar
		currentRowIndex++;
		if (totalRows)
			[singleProgressBar setDoubleValue:(currentRowIndex*progressBarWidth/totalRows)];
		if ((int)[singleProgressBar doubleValue] > lastProgressValue) {
			lastProgressValue = (int)[singleProgressBar doubleValue];
			[singleProgressBar displayIfNeeded];
		}
		
		// If an array was supplied and we've processed all rows, break
		if (array && totalRows == currentRowIndex) break;

		// Drain the autorelease pool as required to keep memory usage low
		if (currentPoolDataLength > 250000) {
			[csvExportPool drain];
			csvExportPool = [[NSAutoreleasePool alloc] init];
		}
	}

	[csvExportPool drain];
	
	// Close the progress sheet if it's present
	if ( !silently ) {
		[NSApp endSheet:singleProgressSheet];
		[singleProgressSheet orderOut:nil];
	}
	
	// Restore the progress bar to a normal maximum
	[singleProgressBar setMaxValue:100];

	return TRUE;
}


- (NSArray *)arrayForCSV:(NSString *)csv terminatedBy:(NSString *)fieldEndString
			  enclosedBy:(NSString *)fieldQuoteString escapedBy:(NSString *)escapeString lineEnds:(NSString *)lineEndString
/*
 loads a csv string into an array
 */
{	
	NSMutableString *tempInputString = [NSMutableString string];
	NSMutableArray *tempArray = [NSMutableArray array];
	NSMutableArray *tempRowArray = [NSMutableArray array];
	NSMutableString *mutableField = [NSMutableString string];
	NSScanner *scanner;
	NSString *scanString, *stringToLineEnd, *stringToFieldEnd;
	NSString *escapedFieldEndString, *escapedFieldQuoteString, *escapedEscapeString, *escapedLineEndString;
	NSString *nullString = [prefs objectForKey:@"NullValue"];
	NSCharacterSet *whitespaceSet = nil;
	BOOL isEscaped, escapeStringIsFieldQuoteString, processingLine, processingField, fieldWasQuoted;
	int fieldCount = NSNotFound;
	int i,j,csvLength,fieldEndLength,fieldQuoteLength,escapeLength,lineEndLength,skipLength;

	// Fix tabs and line endings in the inputs
	for (i = 0; i < 4; i++) {
		switch (i) {
			case 0: [tempInputString setString:fieldEndString]; break;
			case 1: [tempInputString setString:fieldQuoteString]; break;
			case 2: [tempInputString setString:escapeString]; break;
			case 3: [tempInputString setString:lineEndString]; break;
		}
		[tempInputString replaceOccurrencesOfString:@"\\t" withString:@"\t"
											options:NSLiteralSearch
											  range:NSMakeRange(0, [tempInputString length])];
		[tempInputString replaceOccurrencesOfString:@"\\n" withString:@"\n"
											options:NSLiteralSearch
											  range:NSMakeRange(0, [tempInputString length])];
		[tempInputString replaceOccurrencesOfString:@"\\r" withString:@"\r"
											options:NSLiteralSearch
											  range:NSMakeRange(0, [tempInputString length])];
		switch (i) {
			case 0: fieldEndString = [NSString stringWithString:tempInputString]; break;
			case 1: fieldQuoteString = [NSString stringWithString:tempInputString]; break;
			case 2: escapeString = [NSString stringWithString:tempInputString]; break;
			case 3: lineEndString = [NSString stringWithString:tempInputString]; break;
		}
	}
	fieldEndLength = [fieldEndString length];
	fieldQuoteLength = [fieldQuoteString length];
	escapeLength = [escapeString length];
	lineEndLength = [lineEndString length];
	csvLength = [csv length];
	escapeStringIsFieldQuoteString = [fieldQuoteString isEqualToString:escapeString];
	escapedFieldEndString = [NSString stringWithFormat:@"%@%@", escapeString, fieldEndString];
	escapedFieldQuoteString = [NSString stringWithFormat:@"%@%@", escapeString, fieldQuoteString];
	escapedEscapeString = [NSString stringWithFormat:@"%@%@", escapeString, escapeString];
	escapedLineEndString = [NSString stringWithFormat:@"%@%@", escapeString, lineEndString];

	// Set up characters it should be possible to trim
	[tempInputString setString:@""];
	if (![fieldEndString isEqualToString:@" "] && ![fieldQuoteString isEqualToString:@" "] && ![escapeString isEqualToString:@" "] && ![lineEndString isEqualToString:@" "])
		[tempInputString appendString:@" "];
	if (![fieldEndString isEqualToString:@"\t"] && ![fieldQuoteString isEqualToString:@"\t"] && ![escapeString isEqualToString:@"\t"] && ![lineEndString isEqualToString:@"\t"])
		[tempInputString appendString:@"\t"];
	if ([tempInputString length]) whitespaceSet = [NSCharacterSet characterSetWithCharactersInString:tempInputString];
	
	// Set up the scanner to process the CSV 
	scanner = [[NSScanner alloc] initWithString:csv];
	[scanner setCharactersToBeSkipped:nil];
	
	while ( ![scanner isAtEnd] && !progressCancelled) {
		
		// Scan the string line by line into an array for each row.
		processingLine = YES;
		[tempRowArray removeAllObjects];
		while (![scanner isAtEnd] && processingLine) {
			[mutableField setString:@""];
			processingField = YES;
			fieldWasQuoted = NO;

			// Skip unescaped, unquoted whitespace where possible
			if (whitespaceSet) [scanner scanCharactersFromSet:whitespaceSet intoString:nil];

			i = [scanner scanLocation];

			// Look at the next section of the string, and determine whether it's enclosed in the field quote string
			if (fieldQuoteLength && i + fieldQuoteLength <= csvLength
				&& [[csv substringWithRange:NSMakeRange(i, fieldQuoteLength)] isEqualToString:fieldQuoteString])
			{
				[scanner setScanLocation:i+fieldQuoteLength];
				fieldWasQuoted = YES;

				while (![scanner isAtEnd] && processingField) {

					// Process the field until the next quote string
					if (![scanner scanUpToString:fieldQuoteString intoString:&scanString]) scanString = @"";
					[mutableField appendString:scanString];

					// Check to see if the quote string encountered was escaped... or an escaper
					if (escapeLength) {
						j = 1;
						isEscaped = NO;
						if (!escapeStringIsFieldQuoteString) {
							while (j * escapeLength <= [scanString length]
									&& ([[mutableField substringWithRange:NSMakeRange(([mutableField length] - (j*escapeLength)), escapeLength)] isEqualToString:escapeString]))
							{
								isEscaped = !isEscaped;
								j++;
							}
							skipLength = fieldQuoteLength;
						} else {
							if ([scanner scanLocation] + (2 * fieldQuoteLength) <= csvLength
								&& [[csv substringWithRange:NSMakeRange([scanner scanLocation] + fieldQuoteLength, fieldQuoteLength)] isEqualToString:fieldQuoteString])
							{
								isEscaped = YES;
								skipLength = 2 * fieldQuoteLength;
							}
						}
						
						// If it was escaped, keep processing the field
						if (isEscaped) {
							if (![scanner isAtEnd]) {
								[mutableField appendString:[csv substringWithRange:NSMakeRange([scanner scanLocation], skipLength)]];
								[scanner setScanLocation:[scanner scanLocation] + skipLength];
							}
							continue;
						}
					}

					// We should now be at the end of the field - but let the code below keep going until
					// the field end character is actually reached.
					if (![scanner isAtEnd]) {
						[scanner setScanLocation:[scanner scanLocation] + fieldQuoteLength];
						if (whitespaceSet) [scanner scanCharactersFromSet:whitespaceSet intoString:nil];
					}
					processingField = NO;
				}
			}

			// Process until the next field end string *or* line end string, ugh!
			processingField = YES;
			while (![scanner isAtEnd] && processingField) {
				i = [scanner scanLocation];
				if (![scanner scanUpToString:lineEndString intoString:&stringToLineEnd]) stringToLineEnd = @"";
				[scanner setScanLocation:i];
				if (![scanner scanUpToString:fieldEndString intoString:&stringToFieldEnd]) stringToFieldEnd = @"";
				if ([stringToFieldEnd length] < [stringToLineEnd length]) {
					scanString = stringToFieldEnd;
					skipLength = fieldEndLength;
				} else {
					[scanner setScanLocation:i + [stringToLineEnd length]];
					scanString = stringToLineEnd;
					processingLine = NO;
					skipLength = lineEndLength;
				}
				[mutableField appendString:scanString];
				
				// Check to see if the termination character was escaped
				if (escapeLength) {
					j = 1;
					isEscaped = NO;
					while (j * escapeLength <= [scanString length]
							&& ([[mutableField substringWithRange:NSMakeRange(([mutableField length] - (j*escapeLength)), escapeLength)] isEqualToString:escapeString]))
					{
						isEscaped = !isEscaped;
						j++;
					}
					
					// If it was, continue processing the field
					if (isEscaped) {
						if (![scanner isAtEnd]) {
							[mutableField appendString:[csv substringWithRange:NSMakeRange([scanner scanLocation], skipLength)]];
							[scanner setScanLocation:[scanner scanLocation] + skipLength];
						}
						continue;
					}
				}

				// We should be at the end of the field.
				if (![scanner isAtEnd]) [scanner setScanLocation:[scanner scanLocation] + skipLength];
				processingField = NO;
			}

			// We now have a field content string.
			// Insert a NSNull object if the cell contains an unescaped null character or an unescaped string
			// which matches the NULL string set in preferences.
			if ([mutableField isEqualToString:@"\\N"]
				|| (!fieldWasQuoted && [mutableField isEqualToString:nullString]))
			{
				[tempRowArray addObject:[NSNull null]];
			} else {
				
				// Clean up escaped characters
				if (escapeLength) {
					if (fieldEndLength)
						[mutableField replaceOccurrencesOfString:escapedFieldEndString withString:fieldEndString options:NSLiteralSearch range:NSMakeRange(0, [mutableField length])];
					if (fieldQuoteLength)
						[mutableField replaceOccurrencesOfString:escapedFieldQuoteString withString:fieldQuoteString options:NSLiteralSearch range:NSMakeRange(0, [mutableField length])];
					if (lineEndLength)
						[mutableField replaceOccurrencesOfString:escapedLineEndString withString:lineEndString options:NSLiteralSearch range:NSMakeRange(0, [mutableField length])];
					[mutableField replaceOccurrencesOfString:escapedEscapeString withString:escapeString options:NSLiteralSearch range:NSMakeRange(0, [mutableField length])];
				}
				
				// Add the field to the row array
				[tempRowArray addObject:[NSString stringWithString:mutableField]];
			}
		}

		// Capture the length of the first row and ensure all other rows contain that many items
		if (fieldCount == NSNotFound) {
			fieldCount = [tempRowArray count];
		} else if ([tempRowArray count] < fieldCount) {

			// Skip empty rows
			if ([tempRowArray count] == 0
				|| ([tempRowArray count] == 1 && ([[tempRowArray objectAtIndex:0] isNSNull] || ![[tempRowArray objectAtIndex:0] length])))
			{
				continue;
			}

			for (j = [tempRowArray count]; j < fieldCount; j++) [tempRowArray addObject:[NSNull null]];
		}

		// Add the row to the master output array
		[tempArray addObject:[NSArray arrayWithArray:tempRowArray]];
	}
	[scanner release];

	return [NSArray arrayWithArray:tempArray];
}


/*
 * Takes an array, or streaming result reference, and writes it in XML
 * format to the supplied NSFileHandle.  For output, also takes a table
 * name for tag construction, and a toggle to control whether the header
 * is output.
 * Also takes a totalRows parameter, which is used for drawing progress bars -
 * for arrays, this must be accurate, but for streaming result sets it is only
 * used for drawing the progress bar.
 */
- (BOOL)writeXmlForArray:(NSArray *)array orStreamingResult:(MCPStreamingResult *)streamingResult toFileHandle:(NSFileHandle *)fileHandle tableName:(NSString *)table withHeader:(BOOL)header totalRows:(NSInteger)totalRows silently:(BOOL)silently
{
	NSAutoreleasePool *xmlExportPool;
	NSStringEncoding tableEncoding = [MCPConnection encodingForMySQLEncoding:[[tableDocumentInstance connectionEncoding] UTF8String]];
	NSMutableArray *xmlTags = [NSMutableArray array];
	NSArray *xmlRow;
	NSMutableString *xmlString = [NSMutableString string];
	NSMutableString *xmlItem = [NSMutableString string];
	NSString *dataConversionString;
	int i, currentRowIndex, lastProgressValue, progressBarWidth, currentPoolDataLength;
	int xmlRowCount = 0;
	
	// Updating the progress bar can take >20% of processing time - store details to only update when required
	progressBarWidth = (int)[singleProgressBar bounds].size.width;
	lastProgressValue = 0;
	[singleProgressBar setMaxValue:progressBarWidth];
	[singleProgressBar setDoubleValue:0];
	[singleProgressBar displayIfNeeded];
	
	// Set up an array of encoded field names as opening and closing tags
	if (array) {
		xmlRow = [array objectAtIndex:0];
	} else {
		xmlRow = [streamingResult fetchFieldNames];
	}
	for ( i = 0; i < [xmlRow count]; i++ ) {
		[xmlTags addObject:[NSMutableArray array]];
		[[xmlTags objectAtIndex:i] addObject:[NSString stringWithFormat:@"\t\t<%@>",
											  [self htmlEscapeString:[[xmlRow objectAtIndex:i] description]]]];
		[[xmlTags objectAtIndex:i] addObject:[NSString stringWithFormat:@"</%@>\n",
											  [self htmlEscapeString:[[xmlRow objectAtIndex:i] description]]]];
	}
	
	if ( !silently ) {
		
		// Set the progress text
		[singleProgressTitle setStringValue:NSLocalizedString(@"Exporting XML", @"text showing that the application is exporting XML")];
		[singleProgressText setStringValue:NSLocalizedString(@"Writing...", @"text showing that app is writing text file")];
		
		// Open progress sheet
		[NSApp beginSheet:singleProgressSheet
		   modalForWindow:tableWindow modalDelegate:self
		   didEndSelector:nil contextInfo:nil];
	}
	
	// Output the XML header if required
	if ( header ) {
		[xmlString setString:@"<?xml version=\"1.0\"?>\n\n"];
		[xmlString appendString:@"<!--\n-\n"];
		[xmlString appendString:@"- Sequel Pro dump\n"];
		[xmlString appendString:[NSString stringWithFormat:@"- Version %@\n",
								 [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
		[xmlString appendString:@"- http://code.google.com/p/sequel-pro\n-\n"];
		[xmlString appendString:[NSString stringWithFormat:@"- Host: %@ (MySQL %@)\n",
								 [tableDocumentInstance host], [tableDocumentInstance mySQLVersion]]];
		[xmlString appendString:[NSString stringWithFormat:@"- Database: %@\n", [tableDocumentInstance database]]];
		[xmlString appendString:[NSString stringWithFormat:@"- Generation Time: %@\n", [NSDate date]]];
		[xmlString appendString:@"-\n-->\n\n"];
		[fileHandle writeData:[xmlString dataUsingEncoding:tableEncoding]];
	}
	
	// Write an opening tag in the form of the table name
	[fileHandle writeData:[[NSString stringWithFormat:@"\t<%@>\n",
							[self htmlEscapeString:table]]
						   dataUsingEncoding:tableEncoding]];
	
	// Set up the starting row, which is 0 for streaming result sets and
	// 1 for supplied arrays which include the column headers as the first row.
	currentRowIndex = 0;
	if (array) currentRowIndex++;

	// Drop into the processing loop
	xmlExportPool = [[NSAutoreleasePool alloc] init];
	currentPoolDataLength = 0;
	while (1) {

		// Retrieve the next row from the supplied data, either directly from the array...
		if (array) {
			xmlRow = NSArrayObjectAtIndex(array, currentRowIndex);

		// Or by reading an appropriate row from the streaming result
		} else {
			xmlRow = [streamingResult fetchNextRowAsArray];
			if (!xmlRow) break;
		}

		// Get the cell count if we don't already have it stored
		if (!xmlRowCount) xmlRowCount = [xmlRow count];
		
		// Construct the row
		[xmlString setString:@"\t<row>\n"];
		for ( i = 0 ; i < xmlRowCount ; i++ ) {
			
			// Retrieve the contents of this tag
			if ([NSArrayObjectAtIndex(xmlRow, i) isKindOfClass:[NSData class]]) {
				dataConversionString = [[NSString alloc] initWithData:NSArrayObjectAtIndex(xmlRow, i) encoding:tableEncoding];
				if (dataConversionString == nil)
					dataConversionString = [[NSString alloc] initWithData:NSArrayObjectAtIndex(xmlRow, i) encoding:NSASCIIStringEncoding];
				[xmlItem setString:[NSString stringWithString:dataConversionString]];
				[dataConversionString release];
			} else {
				[xmlItem setString:[NSArrayObjectAtIndex(xmlRow, i) description]];
			}
			
			// Add the opening and closing tag and the contents to the XML string
			[xmlString appendString:NSArrayObjectAtIndex(NSArrayObjectAtIndex(xmlTags, i), 0)];
			[xmlString appendString:[self htmlEscapeString:xmlItem]];
			[xmlString appendString:NSArrayObjectAtIndex(NSArrayObjectAtIndex(xmlTags, i), 1)];
		}
		[xmlString appendString:@"\t</row>\n"];
		
		// Record the total length for use with pool flushing
		currentPoolDataLength += [xmlString length];
		
		// Write the row to the filehandle
		[fileHandle writeData:[xmlString dataUsingEncoding:tableEncoding]];

		// Update the progress counter and progress bar
		currentRowIndex++;
		if (totalRows)
			[singleProgressBar setDoubleValue:(currentRowIndex*progressBarWidth/totalRows)];
		if ((int)[singleProgressBar doubleValue] > lastProgressValue) {
			lastProgressValue = (int)[singleProgressBar doubleValue];
			[singleProgressBar displayIfNeeded];
		}
		
		// If an array was supplied and we've processed all rows, break
		if (array && totalRows == currentRowIndex) break;

		// Drain the autorelease pool as required to keep memory usage low
		if (currentPoolDataLength > 250000) {
			[xmlExportPool drain];
			xmlExportPool = [[NSAutoreleasePool alloc] init];
		}
	}
	
	// Write the closing tag for the table
	[fileHandle writeData:[[NSString stringWithFormat:@"\t</%@>",
							[self htmlEscapeString:table]]
						   dataUsingEncoding:tableEncoding]];
	
	[xmlExportPool drain];

	// Close the progress sheet if appropriate
	if ( !silently ) {
		[NSApp endSheet:singleProgressSheet];
		[singleProgressSheet orderOut:nil];
	}

	// Restore the progress bar to a normal maximum
	[singleProgressBar setMaxValue:100];

	return TRUE;
}

/*
 Processes the selected tables within the multiple table export accessory view and passes them
 to be exported.
 */
- (BOOL)exportSelectedTablesToFileHandle:(NSFileHandle *)fileHandle usingFormat:(NSString *)type
{
	int i;
	NSMutableArray *selectedTables = [NSMutableArray array];
	
	// Extract the table names of the selected tables
	for ( i = 0 ; i < [tables count] ; i++ ) {
		if ( [[[tables objectAtIndex:i] objectAtIndex:0] boolValue] ) {
			[selectedTables addObject:[NSString stringWithString:[[tables objectAtIndex:i] objectAtIndex:1]]];
		}
	}
	
	return [self exportTables:selectedTables toFileHandle:fileHandle usingFormat:type usingMulti:YES];
}

/*
 Walks through the selected tables and exports them to a file handle.  The export type must be
 "csv" for CSV format, and "xml" for XML format.
 */
- (BOOL)exportTables:(NSArray *)selectedTables toFileHandle:(NSFileHandle *)fileHandle usingFormat:(NSString *)type usingMulti:(BOOL)multi
{
	int i, j;
	MCPResult *queryResult;
	MCPStreamingResult *streamingResult;
	NSInteger streamingResultCount;
	NSString *tableName, *tableColumnTypeGrouping;
	NSMutableString *infoString = [NSMutableString string];
	NSMutableString *errors = [NSMutableString string];
	NSStringEncoding connectionEncoding = [mySQLConnection encoding];
	NSMutableString *csvLineEnd;
	NSDictionary *tableDetails;
	NSMutableArray *tableColumnNumericStatus;
	
	// Reset the interface
	[errorsView setString:@""];
	[errorsView displayIfNeeded];
	[singleProgressTitle setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Exporting %@", @"text showing that the application is importing a supplied format"), [type uppercaseString]]];
	[singleProgressText setStringValue:NSLocalizedString(@"Writing...", @"text showing that app is writing text file")];
	[singleProgressText displayIfNeeded];
	[singleProgressBar setDoubleValue:0];
	[singleProgressBar displayIfNeeded];

	[tableDocumentInstance setQueryMode:SP_QUERYMODE_IMPORTEXPORT];
	
	// Open the progress sheet
	[NSApp beginSheet:singleProgressSheet
	   modalForWindow:tableWindow modalDelegate:self
	   didEndSelector:nil contextInfo:nil];
	
	
	// Add a dump header to the dump file, dependant on export type.
	if ( [type isEqualToString:@"csv"] ) {
		csvLineEnd = [NSMutableString stringWithString:[exportMultipleLinesTerminatedField stringValue]]; 
		[csvLineEnd replaceOccurrencesOfString:@"\\t" withString:@"\t"
									   options:NSLiteralSearch
										 range:NSMakeRange(0, [csvLineEnd length])];
		[csvLineEnd replaceOccurrencesOfString:@"\\n" withString:@"\n"
									   options:NSLiteralSearch
										 range:NSMakeRange(0, [csvLineEnd length])];
		[csvLineEnd replaceOccurrencesOfString:@"\\r" withString:@"\r"
									   options:NSLiteralSearch
										 range:NSMakeRange(0, [csvLineEnd length])];
		if ([selectedTables count] > 1) {
			[infoString setString:[NSString stringWithFormat:@"Host: %@   Database: %@   Generation Time: %@%@%@",
								   [tableDocumentInstance host], [tableDocumentInstance database], [NSDate date], csvLineEnd, csvLineEnd]];
		}
	} else if ( [type isEqualToString:@"xml"] ) {
		[infoString setString:@"<?xml version=\"1.0\"?>\n\n"];
		[infoString appendString:@"<!--\n-\n"];
		[infoString appendString:@"- Sequel Pro dump\n"];
		[infoString appendString:[NSString stringWithFormat:@"- Version %@\n",
								  [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
		[infoString appendString:@"- http://code.google.com/p/sequel-pro\n-\n"];
		[infoString appendString:[NSString stringWithFormat:@"- Host: %@ (MySQL %@)\n",
								  [tableDocumentInstance host], [tableDocumentInstance mySQLVersion]]];
		[infoString appendString:[NSString stringWithFormat:@"- Database: %@\n", [tableDocumentInstance database]]];
		[infoString appendString:[NSString stringWithFormat:@"- Generation Time: %@\n", [NSDate date]]];
		[infoString appendString:@"-\n-->\n\n\n"];
		[infoString appendString:[NSString stringWithFormat:@"<%@>\n\n\n",
								  [self htmlEscapeString:[tableDocumentInstance database]]]];
	}
	[fileHandle writeData:[infoString dataUsingEncoding:connectionEncoding]];
	
	// Loop through the selected tables
	for ( i = 0 ; i < [selectedTables count] && !progressCancelled; i++ ) {
		
		// Update the progress text and reset the progress bar to indeterminate status
		tableName = [selectedTables objectAtIndex:i];
		[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %i of %i (%@): fetching data...", @"text showing that app is fetching data for table dump"), (i+1), [selectedTables count], tableName]];
		[singleProgressText displayIfNeeded];
		[singleProgressBar setIndeterminate:YES];
		[singleProgressBar setUsesThreadedAnimation:YES];
		[singleProgressBar startAnimation:self];
		
		// For CSV exports of more than one table, output the name of the table
		if ( [type isEqualToString:@"csv"] && [selectedTables count] > 1) {
			[fileHandle writeData:[[NSString stringWithFormat:@"Table %@%@%@", tableName, csvLineEnd, csvLineEnd] dataUsingEncoding:connectionEncoding]];
		}

		// Determine whether this table is a table or a view via the create table command, and get the table details
		queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE %@", [tableName backtickQuotedString]]];
		if ( [queryResult numOfRows] ) {
			tableDetails = [NSDictionary dictionaryWithDictionary:[queryResult fetchRowAsDictionary]];
			if ([tableDetails objectForKey:@"Create View"]) {
				tableDetails = [NSDictionary dictionaryWithDictionary:[tableDataInstance informationForView:tableName]];
			} else {
				tableDetails = [NSDictionary dictionaryWithDictionary:[tableDataInstance informationForTable:tableName]];
			}
		}

		// Retrieve the table details via the data class, and use it to build an array containing column numeric status
		tableColumnNumericStatus = [NSMutableArray array];
		for ( j = 0; j < [[tableDetails objectForKey:@"columns"] count] ; j++ ) {
			tableColumnTypeGrouping = [[[tableDetails objectForKey:@"columns"] objectAtIndex:j] objectForKey:@"typegrouping"];
			if ([tableColumnTypeGrouping isEqualToString:@"bit"] || [tableColumnTypeGrouping isEqualToString:@"integer"]
				|| [tableColumnTypeGrouping isEqualToString:@"float"]) {
				[tableColumnNumericStatus addObject:[NSNumber numberWithBool:YES]];
			} else {
				[tableColumnNumericStatus addObject:[NSNumber numberWithBool:NO]];
			}
		}

		BOOL useLowMemoryBlockingStreaming;
		if ([type isEqualToString:@"csv"]) {
			if (multi)
				useLowMemoryBlockingStreaming = ([multiCSVFullStreamingSwitch state] == NSOnState);
			else
				useLowMemoryBlockingStreaming = ([csvFullStreamingSwitch state] == NSOnState);
		} else {
			useLowMemoryBlockingStreaming = ([multiXMLFullStreamingSwitch state] == NSOnState);
		}

		// Perform a COUNT for progress purposes and make a streaming request for the data
		streamingResultCount = [[[[mySQLConnection queryString:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@", [tableName backtickQuotedString]]] fetchRowAsArray] objectAtIndex:0] integerValue];
		streamingResult = [mySQLConnection streamingQueryString:[NSString stringWithFormat:@"SELECT * FROM %@", [tableName backtickQuotedString]] useLowMemoryBlockingStreaming:useLowMemoryBlockingStreaming];

		// Note any errors during initial query
		if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
			[errors appendString:[NSString stringWithFormat:@"%@\n", [mySQLConnection getLastErrorMessage]]];
		}

		// Update the progress text and set the progress bar back to determinate
		[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %i of %i (%@): Writing data...", @"text showing that app is writing data for table export"), (i+1), [selectedTables count], tableName]];
		[singleProgressText displayIfNeeded];
		[singleProgressBar stopAnimation:self];
		[singleProgressBar setUsesThreadedAnimation:NO];
		[singleProgressBar setIndeterminate:NO];
		[singleProgressBar setDoubleValue:0];
		[singleProgressBar displayIfNeeded];
		
		// Use the appropriate export method to write the data to file
		if ( [type isEqualToString:@"csv"] ) {
			if (multi) {
				[self writeCsvForArray:nil orStreamingResult:streamingResult
						  toFileHandle:fileHandle
					  outputFieldNames:[exportMultipleFieldNamesSwitch state]
						  terminatedBy:[exportMultipleFieldsTerminatedField stringValue]
							enclosedBy:[exportMultipleFieldsEnclosedField stringValue]
							 escapedBy:[exportMultipleFieldsEscapedField stringValue]
							  lineEnds:[exportMultipleLinesTerminatedField stringValue]
					withNumericColumns:tableColumnNumericStatus
							 totalRows:streamingResultCount
							  silently:YES];
			} else {
				[self writeCsvForArray:nil orStreamingResult:streamingResult
						  toFileHandle:fileHandle
					  outputFieldNames:[exportFieldNamesSwitch state]
						  terminatedBy:[exportFieldsTerminatedField stringValue]
							enclosedBy:[exportFieldsEnclosedField stringValue]
							 escapedBy:[exportFieldsEscapedField stringValue]
							  lineEnds:[exportLinesTerminatedField stringValue]
					withNumericColumns:tableColumnNumericStatus
							 totalRows:streamingResultCount
							  silently:YES];
			}

			// Add a spacer to the file
			[fileHandle writeData:[[NSString stringWithFormat:@"%@%@%@", csvLineEnd, csvLineEnd, csvLineEnd] dataUsingEncoding:connectionEncoding]];
		} else if ( [type isEqualToString:@"xml"] ) {
			[self writeXmlForArray:nil orStreamingResult:streamingResult
					  toFileHandle:fileHandle
						 tableName:tableName
						withHeader:NO
						 totalRows:streamingResultCount
						  silently:YES];
			
			// Add a spacer to the file
			[fileHandle writeData:[[NSString stringWithString:@"\n\n\n"] dataUsingEncoding:connectionEncoding]];
		}

		// Release the result set
		[streamingResult release];

		// Note any errors during data retrieval
		if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
			[errors appendString:[NSString stringWithFormat:@"%@\n", [mySQLConnection getLastErrorMessage]]];
		}		
	}
	
	// For XML output, close the database tag
	if ( [type isEqualToString:@"xml"] ) {
		[fileHandle writeData:[[NSString stringWithFormat:@"</%@>",
								[self htmlEscapeString:[tableDocumentInstance database]]]
							   dataUsingEncoding:connectionEncoding]];
	}
	
	// Close the progress sheet
	[NSApp endSheet:singleProgressSheet];
	[singleProgressSheet orderOut:nil];
	
	// Show the errors sheet if there have been errors
	if ( [errors length] ) {
		[errorsView setString:errors];
		[NSApp beginSheet:errorsSheet
		   modalForWindow:tableWindow modalDelegate:self
		   didEndSelector:nil contextInfo:nil];
		[NSApp runModalForWindow:errorsSheet];		
		[NSApp endSheet:errorsSheet];
		[errorsSheet orderOut:nil];
	}

	[tableDocumentInstance setQueryMode:SP_QUERYMODE_INTERFACE];
	
	return TRUE;
}

- (NSString *)htmlEscapeString:(NSString *)string
/*
 html escapes a string
 */
{
	NSMutableString *mutableString = [NSMutableString stringWithString:string];
	
	[mutableString replaceOccurrencesOfString:@"&" withString:@"&amp;"
									  options:NSLiteralSearch
										range:NSMakeRange(0, [mutableString length])];
	[mutableString replaceOccurrencesOfString:@"<" withString:@"&lt;"
									  options:NSLiteralSearch
										range:NSMakeRange(0, [mutableString length])];
	[mutableString replaceOccurrencesOfString:@">" withString:@"&gt;"
									  options:NSLiteralSearch
										range:NSMakeRange(0, [mutableString length])];
	[mutableString replaceOccurrencesOfString:@"\"" withString:@"&quot;"
									  options:NSLiteralSearch
										range:NSMakeRange(0, [mutableString length])];
	
	return [NSString stringWithString:mutableString];
}

/*
 * Retrieve information for a view and use that to construct a CREATE TABLE
 * string for an equivalent basic table.  Allows the construction of
 * placeholder tables to resolve view interdependencies in dumps.
 */
- (NSString *)createViewPlaceholderSyntaxForView:(NSString *)viewName
{
	NSDictionary *viewInformation;
	NSMutableString *placeholderSyntax, *fieldString;
	NSArray *viewColumns;
	NSDictionary *column;
	int i, j;

	// Get structured information for the view via the SPTableData parsers
	viewInformation = [tableDataInstance informationForView:viewName];
	if (!viewInformation) return nil;
	viewColumns = [viewInformation objectForKey:@"columns"];
	
	// Set up the start of the placeholder string and initialise an empty field string
	placeholderSyntax = [[NSMutableString alloc] initWithFormat:@"CREATE TABLE %@ (\n", [viewName backtickQuotedString]];
	fieldString = [[NSMutableString alloc] init];

	// Loop through the columns, creating an appropriate column definition for each and appending it to the syntax string
	for (i = 0; i < [viewColumns count]; i++) {
		column = [viewColumns objectAtIndex:i];
		[fieldString setString:[[column objectForKey:@"name"] backtickQuotedString]];

		// Add the type and length information as appropriate
		if ([column objectForKey:@"length"]) {
			[fieldString appendFormat:@" %@(%@)", [column objectForKey:@"type"], [column objectForKey:@"length"]];
		} else if ([column objectForKey:@"values"]) {
			[fieldString appendFormat:@" %@(", [column objectForKey:@"type"]];
			for (j = 0; j < [[column objectForKey:@"values"] count]; j++) {
				[fieldString appendFormat:@"'%@'%@", [mySQLConnection prepareString:[[column objectForKey:@"values"] objectAtIndex:j]], (j+1 == [[column objectForKey:@"values"] count])?@"":@","];
			}
			[fieldString appendString:@")"];
		} else {
			[fieldString appendFormat:@" %@", [column objectForKey:@"type"]];
		}
	
		// Field specification details
		if ([[column objectForKey:@"unsigned"] intValue] == 1) [fieldString appendString:@" UNSIGNED"];
		if ([[column objectForKey:@"zerofill"] intValue] == 1) [fieldString appendString:@" ZEROFILL"];
		if ([[column objectForKey:@"binary"] intValue] == 1) [fieldString appendString:@" BINARY"];
		if ([[column objectForKey:@"null"] intValue] == 0) [fieldString appendString:@" NOT NULL"];

		// Provide the field default if appropriate
		if ([column objectForKey:@"default"]) {

			// Some MySQL server versions show a default of NULL for NOT NULL columns - don't export those.
			if ([[column objectForKey:@"default"] isEqualToString:@"NULL"]) {
				if ([[column objectForKey:@"null"] intValue])
					[fieldString appendString:@" DEFAULT NULL"];

			} else if ([[column objectForKey:@"type"] isEqualToString:@"TIMESTAMP"]
						&& [[[column objectForKey:@"default"] uppercaseString] isEqualToString:@"CURRENT_TIMESTAMP"]) {
				[fieldString appendString:@" DEFAULT CURRENT_TIMESTAMP"];
			} else {
				[fieldString appendFormat:@" DEFAULT '%@'", [mySQLConnection prepareString:[column objectForKey:@"default"]]];
			}
		}
		
		// Extras aren't required for the temp table.
		// Add the field string to the syntax string
		[placeholderSyntax appendFormat:@"   %@%@\n", fieldString, (i == [viewColumns count]-1)?@"":@","];
	}

	// Append the remainder of the table string
	[placeholderSyntax appendString:@") ENGINE=MyISAM;"];

	// Clean up and return.
	[fieldString release];
	return [placeholderSyntax autorelease];
}
 
/*
 * Split a string by the terminated-character if this is not escaped
 * if enclosed-character is given, ignores characters inside enclosed-characters
 */
- (NSArray *)arrayForString:(NSString *)string enclosed:(NSString *)enclosed
					escaped:(NSString *)escaped terminated:(NSString *)terminated
{
	NSMutableArray *tempArray = [NSMutableArray array];
	BOOL inString = NO;
	BOOL isEscaped = NO;
	BOOL br = NO;
	unsigned i, j, start;
	unichar enc;
	unichar esc;
	unichar ter;
	
	//we take only first character by now (too complicated otherwise)
	if ( [enclosed length] ) {
		enc = [enclosed characterAtIndex:0];
	}
	if ( [escaped length] ) {
		esc = [escaped characterAtIndex:0];
	}
	if ( [terminated length] ) {
		ter = [terminated characterAtIndex:0];
	}
	
	start = 0;
	
	for ( i = 0 ; i < [string length] ; i++ ) {
		if ( inString ) {
			//we are in a string
			br = NO;
			while ( !br ) {
				if ( i >= [string length] ) {
					//end of string -> no second enclose character found
					br = YES;
				} else if ( [string characterAtIndex:i] == enc ) {
					//second enclose-character found
					//enclose-character escaped?
					isEscaped = NO;
					j = 1;
					while ( (i-j>0) && ([string characterAtIndex:(i-j)] == esc) ) {
						isEscaped = !isEscaped;
						j++;
					}
					if ( !isEscaped ) {
						inString = NO;
						br = YES;
					}
				}
				if ( !br )
					i++;
			}
		} else if ( [string characterAtIndex:i] == ter ) {
			//terminated-character found
			if ( [enclosed isEqualToString:@""] ) {
				//check if terminated character is escaped
				isEscaped = NO;
				j = 1;
				while ( (i-j>0) && ([string characterAtIndex:(i-j)] == esc) ) {
					isEscaped = !isEscaped;
					j++;
				}
				if ( !isEscaped ) {
					[tempArray addObject:[string substringWithRange:NSMakeRange(start,(i-start))]];
					start = i + 1;
				}
			} else {
				//add object to array
				[tempArray addObject:[string substringWithRange:NSMakeRange(start,(i-start))]];
				start = i + 1;
			}
		} else if ( [string characterAtIndex:i] == enc ) {
			//enclosed-character found
			inString = YES;
		}
	}
	
	//add rest of string to array
	[tempArray addObject:[string substringWithRange:NSMakeRange(start,([string length]-start))]];
	
	return [NSArray arrayWithArray:tempArray];
}

//additional methods
- (void)setConnection:(MCPConnection *)theConnection
/*
 sets the connection (received from TableDocument) and makes things that have to be done only once 
 */
{
	NSButtonCell *switchButton = [[NSButtonCell alloc] init];
	
	prefs = [[NSUserDefaults standardUserDefaults] retain];
	
	mySQLConnection = theConnection;
	
	//set up the interface
	[switchButton setButtonType:NSSwitchButton];
	[switchButton setControlSize:NSSmallControlSize];
	[[exportDumpTableView tableColumnWithIdentifier:@"switch"] setDataCell:switchButton];
	[[exportMultipleCSVTableView tableColumnWithIdentifier:@"switch"] setDataCell:switchButton];
	[[exportMultipleXMLTableView tableColumnWithIdentifier:@"switch"] setDataCell:switchButton];
	[switchButton release];
	if ( [prefs boolForKey:@"UseMonospacedFonts"] ) {
		[[[exportDumpTableView tableColumnWithIdentifier:@"tables"] dataCell]
		 setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
		[[[exportMultipleCSVTableView tableColumnWithIdentifier:@"tables"] dataCell]
		 setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
		[[[exportMultipleXMLTableView tableColumnWithIdentifier:@"tables"] dataCell]
		 setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
		[[[fieldMappingTableView tableColumnWithIdentifier:@"0"] dataCell]
		 setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
		[errorsView setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
	} else {
		[[[exportDumpTableView tableColumnWithIdentifier:@"tables"] dataCell]
		 setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		[[[exportMultipleCSVTableView tableColumnWithIdentifier:@"tables"] dataCell]
		 setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		[[[exportMultipleXMLTableView tableColumnWithIdentifier:@"tables"] dataCell]
		 setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		[[[fieldMappingTableView tableColumnWithIdentifier:@"0"] dataCell]
		 setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		[errorsView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
	//	[self reloadTables:self];
}

#pragma mark -
#pragma mark Table view datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
{
	if ( aTableView == fieldMappingTableView ) {
		return [[tableSourceInstance fieldNames] count];
	} else {
		return [tables count];
	}
}

- (void)tableView:(NSTableView *)aTableView 
  willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn 
			  row:(int)rowIndex
{
	if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"UseMonospacedFonts"] ) {
		[aCell setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
	}
	else
	{
		[aCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	id returnObject = nil;
	
	if ( aTableView == fieldMappingTableView ) {
		if ([[aTableColumn identifier] isEqualToString:@"field"]) {
			returnObject = [[tableSourceInstance fieldNames] objectAtIndex:rowIndex];
			
		} else if ([[aTableColumn identifier] isEqualToString:@"value"]) {
			if ([[[aTableColumn dataCell] class] isEqualTo:[NSPopUpButtonCell class]]) {
				[(NSPopUpButtonCell *)[aTableColumn dataCell] removeAllItems];
				[(NSPopUpButtonCell *)[aTableColumn dataCell] addItemWithTitle:NSLocalizedString(@"Do not import", @"text for csv import drop downs")];
				[(NSPopUpButtonCell *)[aTableColumn dataCell] addItemsWithTitles:fieldMappingButtonOptions];
			}
			
			returnObject = [fieldMappingArray objectAtIndex:rowIndex];
		} 
	} else {
		if ( [[aTableColumn identifier] isEqualToString:@"switch"] ) {
			returnObject = [[tables objectAtIndex:rowIndex] objectAtIndex:0];
		} else {
			returnObject = [[tables objectAtIndex:rowIndex] objectAtIndex:1];
		}
	}
	
	return returnObject;
}

- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)aTableColumn
			  row:(int)rowIndex
{
	if ( aTableView == fieldMappingTableView ) {		
		[fieldMappingArray replaceObjectAtIndex:rowIndex withObject:anObject];
		
	} else {
		[[tables objectAtIndex:rowIndex] replaceObjectAtIndex:0 withObject:anObject];
	}
}


#pragma mark -
#pragma mark Import/export delegate notifications

// Called when the selection within an open/save panel changes
- (void)panelSelectionDidChange:(id)sender
{
	NSArray *selectedFilenames = [sender filenames];
	NSString *pathExtension;

	// If a single file is selected and the extension is recognised, change the format dropdown automatically
	if ( [selectedFilenames count] != 1 ) return;
	pathExtension = [[[selectedFilenames objectAtIndex:0] pathExtension] uppercaseString];
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

		[fileTask release];
		[filePipe release];
	}
}


#pragma mark -
#pragma mark Other

- (void)awakeFromNib
{
	[self switchTab:[[exportToolbar items] objectAtIndex:0]];
	[exportToolbar setSelectedItemIdentifier:[[[exportToolbar items] objectAtIndex:0] itemIdentifier]];
}
	
//last but not least
- (id)init;
{
	self = [super init];
	
	tables = [[NSMutableArray alloc] init];
	fieldMappingButtonOptions = [[NSMutableArray alloc] init];
	fieldMappingArray = nil;
	importArray = nil;
	prefs = nil;
	
	return self;
}

- (void)dealloc
{	
	[tables release];
	[fieldMappingButtonOptions release];
	if (importArray) [importArray release];
	if (fieldMappingArray) [fieldMappingArray release];
	if (prefs) [prefs release];
	
	[super dealloc];
}

- (IBAction)cancelProgressBar:(id)sender
{
	progressCancelled = YES;	
}

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

#pragma mark -
#pragma mark New Export methods

- (IBAction)switchTab:(id)sender
{
	if ([sender isKindOfClass:[NSToolbarItem class]]) {
		[exportTabBar selectTabViewItemWithIdentifier:[[sender label] lowercaseString]];
	}
}

- (IBAction)switchInput:(id)sender
{
	if ([sender isKindOfClass:[NSMatrix class]]) {
		[exportTableList setEnabled:([[sender selectedCell] tag] == 3)];
	}
}


- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	return YES;
}

@end

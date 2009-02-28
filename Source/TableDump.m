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
//  Or mail to <lorenz@textor.ch>

#import "TableDump.h"
#import "TableDocument.h"
#import "TablesList.h"
#import "TableSource.h"
#import "TableContent.h"
#import "CustomQuery.h"
#import "SPGrowlController.h"
#import "SPSQLParser.h"
#import "SPTableData.h"

@implementation TableDump

//IBAction methods
- (IBAction)reloadTables:(id)sender
/*
 get the tables in db
 */
{
	CMMCPResult *queryResult;
	int i;
	
	//get tables
	[tables removeAllObjects];
	queryResult = (CMMCPResult *)[mySQLConnection listTables];
	
	if ([queryResult numOfRows]) [queryResult dataSeek:0];
	for ( i = 0 ; i < [queryResult numOfRows] ; i++ ) {
		[tables addObject:[NSMutableArray arrayWithObjects:
						   [NSNumber numberWithBool:YES], [[queryResult fetchRowAsArray] objectAtIndex:0], nil]];
	}
	
	[exportDumpTableView reloadData];
	[exportMultipleCSVTableView reloadData];
	[exportMultipleXMLTableView reloadData];
	
}

- (IBAction)selectTables:(id)sender
/*
 selects or deselects all tables
 */
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

- (IBAction)closeSheet:(id)sender
/*
 ends the modal session
 */
{
	[NSApp stopModalWithCode:[sender tag]];
}

#pragma mark -
#pragma mark export methods

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
	NSString *currentDate = [[NSDate date] descriptionWithCalendarFormat:@"%d.%m.%Y" timeZone:nil locale:nil];
	
	switch ( tag ) {
		case 5:
			// export dump
			[self reloadTables:self];
			file = [NSString stringWithFormat:@"%@_dump %@.sql", [tableDocumentInstance database], currentDate];
			[savePanel setRequiredFileType:@"sql"];
			[savePanel setAccessoryView:exportDumpView];
			contextInfo = @"exportDump";
			break;
			
			// Export the full resultset for the currently selected table to a file in CSV format
		case 6:
			file = [NSString stringWithString:(NSString *)[tableDocumentInstance table]];
			[savePanel setRequiredFileType:@"csv"];
			[savePanel setAccessoryView:exportCSVView];
			contextInfo = @"exportTableContentAsCSV";
			break;
			
			// Export the full resultset for the currently selected table to a file in XML format
		case 7:
			file = [NSString stringWithString:(NSString *)[tableDocumentInstance table]];
			[savePanel setRequiredFileType:@"xml"];
			contextInfo = @"exportTableContentAsXML";
			break;
			
			// Export the current "browse" view to a file in CSV format
		case 8:
			file = [NSString stringWithFormat:@"%@ view", [tableDocumentInstance table]];
			[savePanel setRequiredFileType:@"csv"];
			[savePanel setAccessoryView:exportCSVView];
			contextInfo = @"exportBrowseViewAsCSV";
			break;
			
			// Export the current "browse" view to a file in XML format
		case 9:
			file = [NSString stringWithFormat:@"%@ view", [tableDocumentInstance table]];
			[savePanel setRequiredFileType:@"xml"];
			contextInfo = @"exportBrowseViewAsXML";
			break;
			
			// Export the current custom query result set to a file in CSV format
		case 10:
			file = @"customresult";
			[savePanel setRequiredFileType:@"csv"];
			[savePanel setAccessoryView:exportCSVView];
			contextInfo = @"exportCustomResultAsCSV";
			break;
			
			// Export the current custom query result set to a file in XML format
		case 11:
			file = @"customresult";
			[savePanel setRequiredFileType:@"xml"];
			contextInfo = @"exportCustomResultAsXML";
			break;
			
			// Export multiple tables to a file in CSV format
		case 12:
			[self reloadTables:self];
			file = [NSString stringWithString:[tableDocumentInstance database]];
			[savePanel setRequiredFileType:@"csv"];
			[savePanel setAccessoryView:exportMultipleCSVView];
			contextInfo = @"exportMultipleTablesAsCSV";
			break;
			
			// Export multiple tables to a file in XML format
		case 13:
			[self reloadTables:self];
			file = [NSString stringWithString:[tableDocumentInstance database]];
			[savePanel setRequiredFileType:@"xml"];
			[savePanel setAccessoryView:exportMultipleXMLView];
			contextInfo = @"exportMultipleTablesAsXML";
			break;
		default:
			NSLog(@"ERROR: unknown export item with tag %d", tag);
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
		success = [self exportTables:[NSArray arrayWithObject:[tableDocumentInstance table]] toFileHandle:fileHandle usingFormat:@"csv"];
		
		// Export the full resultset for the currently selected table to a file in XML format
	} else if ( [contextInfo isEqualToString:@"exportTableContentAsXML"] ) {
		success = [self exportTables:[NSArray arrayWithObject:[tableDocumentInstance table]] toFileHandle:fileHandle usingFormat:@"xml"];
		
		// Export the current "browse" view to a file in CSV format
	} else if ( [contextInfo isEqualToString:@"exportBrowseViewAsCSV"] ) {
		success = [self writeCsvForArray:[tableContentInstance currentResult] orQueryResult:nil
							toFileHandle:fileHandle
						outputFieldNames:[exportFieldNamesSwitch state]
							terminatedBy:[exportFieldsTerminatedField stringValue]
							  enclosedBy:[exportFieldsEnclosedField stringValue]
							   escapedBy:[exportFieldsEscapedField stringValue]
								lineEnds:[exportLinesTerminatedField stringValue]
					  withNumericColumns:nil
								silently:NO];
		
		// Export the current "browse" view to a file in XML format
	} else if ( [contextInfo isEqualToString:@"exportBrowseViewAsXML"] ) {
		success = [self writeXmlForArray:[tableContentInstance currentResult] orQueryResult:nil
							toFileHandle:fileHandle
							   tableName:(NSString *)[tableDocumentInstance table]
							  withHeader:YES
								silently:NO];
		
		// Export the current custom query result set to a file in CSV format
	} else if ( [contextInfo isEqualToString:@"exportCustomResultAsCSV"] ) {
		success = [self writeCsvForArray:[customQueryInstance currentResult] orQueryResult:nil
							toFileHandle:fileHandle
						outputFieldNames:[exportFieldNamesSwitch state]
							terminatedBy:[exportFieldsTerminatedField stringValue]
							  enclosedBy:[exportFieldsEnclosedField stringValue]
							   escapedBy:[exportFieldsEscapedField stringValue]
								lineEnds:[exportLinesTerminatedField stringValue]
					  withNumericColumns:nil
								silently:NO];
		
		// Export the current custom query result set to a file in XML format
	} else if ( [contextInfo isEqualToString:@"exportCustomResultAsXML"] ) {
		success = [self writeXmlForArray:[customQueryInstance currentResult] orQueryResult:nil
							toFileHandle:fileHandle
							   tableName:@"custom"
							  withHeader:YES
								silently:NO];
		
		// Export multiple tables to a file in CSV format
	} else if ( [contextInfo isEqualToString:@"exportMultipleTablesAsCSV"] ) {
		success = [self exportSelectedTablesToFileHandle:fileHandle usingFormat:@"csv"];
		
		// Export multiple tables to a file in XML format
	} else if ( [contextInfo isEqualToString:@"exportMultipleTablesAsXML"] ) {
		success = [self exportSelectedTablesToFileHandle:fileHandle usingFormat:@"xml"];
		
		// Unknown operation
	} else {
		NSLog(@"Unknown export operation: %@", [contextInfo description]);
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
#pragma mark import methods

- (void)importFile
/*
 invoked when user clicks on an import menuItem
 */
{
	// prepare open panel and accessory view
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAccessoryView:importCSVView];
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
	[tableListView selectRowIndexes:[NSIndexSet indexSetWithIndex:[[tablesListInstance tables] indexOfObject:[fieldMappingPopup titleOfSelectedItem]]] byExtendingSelection:NO];
	
	//set up tableView
	currentRow = 0;
	fieldMappingArray = nil;
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
	SPSQLParser *dumpFile;
	NSError **errorStr; 
	NSMutableString *errors = [NSMutableString string];
	NSString *fileType = [[importFormatPopup selectedItem] title];
	//load file into string
	dumpFile = [SPSQLParser stringWithContentsOfFile:filename
										 encoding:[CMMCPConnection encodingForMySQLEncoding:[[tableDocumentInstance connectionEncoding] cString]]
											error:errorStr];
	
	if ( !dumpFile ) {
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"Title of error alert"),
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil,
						  tableWindow, self,
						  nil, nil, nil,
						  NSLocalizedString(@"Couldn't open file. Be sure that the path is correct and that you have the necessary privileges.", @"Message of panel when file cannot be opened"));
		return;
	}
	
	// reset interface
	[errorsView setString:@""];
	[errorsView displayIfNeeded];
	[singleProgressText setStringValue:NSLocalizedString(@"Reading...", @"text showing that app is reading dump")];
	[singleProgressText displayIfNeeded];
	[singleProgressBar setDoubleValue:0];
	[singleProgressBar displayIfNeeded];
	
	if ( [fileType isEqualToString:@"SQL"] ) {
		
		//import dump file
		NSArray *queries;
		int i;
		
		//open progress sheet
		[NSApp beginSheet:singleProgressSheet
		   modalForWindow:tableWindow
			modalDelegate:self
		   didEndSelector:nil
			  contextInfo:nil];
		
		[singleProgressBar setIndeterminate:YES];
		[singleProgressBar setUsesThreadedAnimation:YES];
		[singleProgressBar startAnimation:self];
		
		//get array with an object for each mysql-query
		queries = [dumpFile splitStringByCharacter:';'];
		
		[singleProgressBar stopAnimation:self];
		[singleProgressBar setUsesThreadedAnimation:NO];
		[singleProgressBar setIndeterminate:NO];
		
		//perform all mysql-queries
		for ( i = 0 ; i < [queries count] ; i++ ) {
			[singleProgressBar setDoubleValue:((i+1)*100/[queries count])];
			[singleProgressBar displayIfNeeded];
			[mySQLConnection queryString:[queries objectAtIndex:i]];
			
			if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""] && ![[mySQLConnection getLastErrorMessage] isEqualToString:@"Query was empty"]) {
				[errors appendString:[NSString stringWithFormat:NSLocalizedString(@"[ERROR in query %d] %@\n", @"error text when multiple custom query failed"), (i+1),[mySQLConnection getLastErrorMessage]]];
			}
		}
		
		//close progress sheet
		[NSApp endSheet:singleProgressSheet];
		[singleProgressSheet orderOut:nil];
		
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
		
		//update tables list
		[tablesListInstance updateTables:self];
		
		////////////////
		// IMPORT CSV //
		////////////////
		
	} else if ( [fileType isEqualToString:@"CSV"] ) {
		//NSLog(@"CSV Import...");
		//import csv file
		int code;
		NSPopUpButtonCell *buttonCell = [[NSPopUpButtonCell alloc] init];
		
		//open progress sheet
		[NSApp beginSheet:singleProgressSheet
		   modalForWindow:tableWindow
			modalDelegate:self
		   didEndSelector:nil 
			  contextInfo:nil];
		
		[singleProgressBar setIndeterminate:YES];
		[singleProgressBar setUsesThreadedAnimation:YES];
		[singleProgressBar startAnimation:self];
		
		//put file in array
		if ( importArray )
			[importArray release];
		
		importArray = [[self arrayForCSV:dumpFile
							terminatedBy:[importFieldsTerminatedField stringValue]
							  enclosedBy:[importFieldsEnclosedField stringValue]
							   escapedBy:[importFieldsEscapedField stringValue]
								lineEnds:[importLinesTerminatedField stringValue]] retain];
		
		//close progress sheet
		[NSApp endSheet:singleProgressSheet];
		[singleProgressSheet orderOut:nil];
		[singleProgressBar stopAnimation:self];
		[singleProgressBar setUsesThreadedAnimation:NO];
		[singleProgressBar setIndeterminate:NO];
		
		if (progressCancelled) {
			progressCancelled = NO;
			//NSLog(@"Progress Cancelled... cleaning up");
			[pool release];
			return;
		}
		CMMCPResult *theResult;
		int i;
		theResult = (CMMCPResult *) [mySQLConnection listTables];
		if ([theResult numOfRows]) [theResult dataSeek:0];
		for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
			[fieldMappingPopup addItemWithTitle:[[theResult fetchRowAsArray] objectAtIndex:0]];
		}
		
		if ([tableDocumentInstance table] != nil && ![(NSString *)[tableDocumentInstance table] isEqualToString:@""]) {
			[fieldMappingPopup selectItemWithTitle:[(TableDocument *)tableDocumentInstance table]];
		} else {
			[fieldMappingPopup selectItemAtIndex:0];
		}
		
		int indexOfFirstTable = [[tablesListInstance tables] indexOfObject:[fieldMappingPopup titleOfSelectedItem]];
		
		if( indexOfFirstTable == NSNotFound ){
			[errors appendString:[NSString stringWithFormat:NSLocalizedString(@"[ERROR] %@\n", @"error text when trying to import csv data, but we have no tables in the db"), @"Can't import CSV data into a database without any tables!"]];				
		} else {
			[tableListView selectRowIndexes:[NSIndexSet indexSetWithIndex:indexOfFirstTable] byExtendingSelection:NO];
			
			//set up tableView
			currentRow = 0;
			fieldMappingArray = nil;
			[self setupFieldMappingArray];
			[rowDownButton setEnabled:NO];
			[rowUpButton setEnabled:([importArray count] > 1)];
			[recordCountLabel setStringValue:[NSString stringWithFormat:@"%i of %i records", currentRow+1, [importArray count]]];
			
			//set up tableView buttons
			[buttonCell setControlSize:NSSmallControlSize];
			[buttonCell setFont:[NSFont labelFontOfSize:[NSFont smallSystemFontSize]]];
			[buttonCell setBordered:NO];
			[[fieldMappingTableView tableColumnWithIdentifier:@"value"] setDataCell:buttonCell];
			[self updateFieldMappingButtonCell];
			[fieldMappingTableView reloadData];
			
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
				int i,j;
				
				//open progress sheet
				[NSApp beginSheet:singleProgressSheet
				   modalForWindow:tableWindow
					modalDelegate:self
				   didEndSelector:nil
					  contextInfo:nil];
				
				// get fields to be imported
				for (i = 0; i < [fieldMappingArray count] ; i++ ) {		
					if ([[fieldMappingArray objectAtIndex:i] intValue] > 0) {
						if ( [fNames length] )
							[fNames appendString:@","];
						
						[fNames appendString:[NSString stringWithFormat:@"`%@`", [[tableSourceInstance fieldNames] objectAtIndex:i]]];
					}
				}
				
				//import array
				for ( i = 0 ; i < [importArray count] ; i++ ) {
					//show progress bar
					[singleProgressBar setDoubleValue:((i+1)*100/[importArray count])];
					[singleProgressBar displayIfNeeded];
					
					if ( !([importFieldNamesSwitch state] && (i == 0)) ) {
						//put values in string
						[fValues setString:@""];
						
						for ( j = 0 ; j < [fieldMappingArray count] ; j++ ) {
							
							if ([[fieldMappingArray objectAtIndex:j] intValue] > 0) {
								if ( [fValues length] )
									[fValues appendString:@","];
								
								if ([[[importArray objectAtIndex:i] objectAtIndex:([[fieldMappingArray objectAtIndex:j] intValue] - 1)] isMemberOfClass:[NSNull class]] ) {
									[fValues appendString:@"NULL"];
								} else {
									[fValues appendString:[NSString stringWithFormat:@"'%@'",[mySQLConnection prepareString:[[importArray objectAtIndex:i] objectAtIndex:([[fieldMappingArray objectAtIndex:j] intValue] - 1)]]]];
								}
							}
						}
						
						//perform query
						[mySQLConnection queryString:[NSString stringWithFormat:@"INSERT INTO `%@` (%@) VALUES (%@)",
													  [fieldMappingPopup titleOfSelectedItem],
													  fNames,
													  fValues]];
						
						if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
							[errors appendString:[NSString stringWithFormat:NSLocalizedString(@"[ERROR in line %d] %@\n", @"error text when reading of csv file gave errors"), (i+1),[mySQLConnection getLastErrorMessage]]];				
						}
					}
				}
				
				//close progress sheet
				[NSApp endSheet:singleProgressSheet];
				[singleProgressSheet orderOut:nil];
			}
			
			[tableContentInstance reloadTableValues:self];
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
		fieldMappingArray = nil;
		importArray = nil;
	}
	
    // Import finished Growl notification
    [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Import Finished" 
                                                   description:[NSString stringWithFormat:NSLocalizedString(@"Finished importing %@",@"description for finished importing growl notification"), [filename lastPathComponent]] 
                                              notificationName:@"Import Finished"];
	[pool release];
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

- (void)setupFieldMappingArray
/*
 sets up the fieldMapping array to be shown in the tableView
 */
{
	int i, value;
	
    if ( fieldMappingArray ) {
		
		//        for ( i = 0 ; i < [fieldMappingArray count] ; i++ ) {
		//			
		//			if ( [[[importArray objectAtIndex:currentRow] objectAtIndex:i] isKindOfClass:[NSNull class]] ) {
		//                [fieldMappingArray replaceObjectAtIndex:i withObject:0];
		//				
		//            } else {
		//                [fieldMappingArray replaceObjectAtIndex:i withObject:[[importArray objectAtIndex:currentRow] objectAtIndex:0]];
		//            }
		//        }
		
    } else {
        fieldMappingArray = [NSMutableArray array];
		
		for (i = 0; i < [[tableSourceInstance fieldNames] count]; i++) {
			if (i < [[importArray objectAtIndex:currentRow] count] && ![[[importArray objectAtIndex:currentRow] objectAtIndex:i] isKindOfClass:[NSNull class]]) {
				value = i + 1;
			} else {
				value = 0;
			}
			
            [fieldMappingArray addObject:[NSNumber numberWithInt:value]];
        }
		
        [fieldMappingArray retain];
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
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%i. %@", i+1, [prefs objectForKey:@"nullValue"]]];
		} else {
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%i. %@", i+1, [fieldMappingButtonOptions objectAtIndex:i]]];
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
#pragma mark format methods


/*
 Dump the selected tables to a file handle in SQL format.
 */
- (BOOL)dumpSelectedTablesAsSqlToFileHandle:(NSFileHandle *)fileHandle
{
	int i,j,t,rowCount, colCount, progressBarWidth, lastProgressValue, queryLength;
	CMMCPResult *queryResult;
	NSString *tableName, *tableColumnTypeGrouping;
	NSArray *fieldNames;
	NSArray *theRow;
	NSMutableArray *selectedTables = [NSMutableArray array];
	NSMutableString *headerString = [NSMutableString string];
	NSMutableString *cellValue = [NSMutableString string];
	NSMutableString *sqlString = [NSMutableString string];
	NSMutableString *errors = [NSMutableString string];
	NSDictionary *tableDetails;
	NSMutableArray *tableColumnNumericStatus;
	NSStringEncoding connectionEncoding = [mySQLConnection encoding];
	id createTableSyntax;
	
	// Reset the interface
	[errorsView setString:@""];
	[errorsView displayIfNeeded];
	[singleProgressText setStringValue:NSLocalizedString(@"Dumping...", @"text showing that app is writing dump")];
	[singleProgressText displayIfNeeded];
	progressBarWidth = (int)[singleProgressBar bounds].size.width;
	[singleProgressBar setDoubleValue:0];
	[singleProgressBar displayIfNeeded];
	
	// Open the progress sheet
	[NSApp beginSheet:singleProgressSheet
	   modalForWindow:tableWindow modalDelegate:self
	   didEndSelector:nil contextInfo:nil];
	
	// Copy over the selected table names into a table in preparation for iteration
	for ( i = 0 ; i < [tables count] ; i++ ) {
		if ( [[[tables objectAtIndex:i] objectAtIndex:0] boolValue] ) {
			[selectedTables addObject:[NSString stringWithString:[[tables objectAtIndex:i] objectAtIndex:1]]];
		}
	}
	
	// Add the dump header to the dump file.
	[headerString setString:@"# Sequel Pro dump\n"];
	[headerString appendString:[NSString stringWithFormat:@"# Version %@\n",
								[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
	[headerString appendString:@"# http://code.google.com/p/sequel-pro\n#\n"];
	[headerString appendString:[NSString stringWithFormat:@"# Host: %@ (MySQL %@)\n",
								[tableDocumentInstance host], [tableDocumentInstance mySQLVersion]]];
	[headerString appendString:[NSString stringWithFormat:@"# Database: %@\n", [tableDocumentInstance database]]];
	[headerString appendString:[NSString stringWithFormat:@"# Generation Time: %@\n", [NSDate date]]];
	[headerString appendString:@"# ************************************************************\n\n"];
	[fileHandle writeData:[headerString dataUsingEncoding:connectionEncoding]];
	
	// Loop through the selected tables
	for ( i = 0 ; i < [selectedTables count] ; i++ ) {
		lastProgressValue = 0;
		
		// Update the progress text and reset the progress bar to indeterminate status while fetching data
		tableName = [selectedTables objectAtIndex:i];
		[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %i of %i (%@): Fetching data...", @"text showing that app is fetching data for table dump"), (i+1), [selectedTables count], tableName]];
		[singleProgressText displayIfNeeded];
		[singleProgressBar setIndeterminate:YES];
		[singleProgressBar setUsesThreadedAnimation:YES];
		[singleProgressBar startAnimation:self];
		
		// Add the name of table
		[fileHandle writeData:[[NSString stringWithFormat:@"# Dump of table %@\n# ------------------------------------------------------------\n\n", tableName]
							   dataUsingEncoding:connectionEncoding]];
		
		
		// Add a "drop table" command if specified in the export dialog
		if ( [addDropTableSwitch state] == NSOnState )
			[fileHandle writeData:[[NSString stringWithFormat:@"DROP TABLE IF EXISTS `%@`;\n\n", tableName]
								   dataUsingEncoding:connectionEncoding]];
		
		// Add the create syntax for the table if specified in the export dialog
		if ( [addCreateTableSwitch state] == NSOnState ) {
			queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE `%@`", tableName]];
			if ( [queryResult numOfRows] ) {
				createTableSyntax = [[queryResult fetchRowAsDictionary] objectForKey:@"Create Table"];
				if ( [createTableSyntax isKindOfClass:[NSData class]] ) {
					createTableSyntax = [[[NSString alloc] initWithData:createTableSyntax encoding:connectionEncoding] autorelease];
				}
				[fileHandle writeData:[createTableSyntax dataUsingEncoding:connectionEncoding]];
				[fileHandle writeData:[[NSString stringWithString:@";\n\n"] dataUsingEncoding:connectionEncoding]];
			}
			if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
				[errors appendString:[NSString stringWithFormat:@"%@\n", [mySQLConnection getLastErrorMessage]]];
				if ( [addErrorsSwitch state] == NSOnState ) {
					[fileHandle writeData:[[NSString stringWithFormat:@"# Error: %@\n", [mySQLConnection getLastErrorMessage]] dataUsingEncoding:connectionEncoding]];
				}
			}
		}
		
		// Add the table content if required
		if ( [addTableContentSwitch state] == NSOnState ) {
			queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT * FROM `%@`", tableName]];
			fieldNames = [queryResult fetchFieldNames];
			rowCount = [queryResult numOfRows];
			
			// Retrieve the table details via the data class, and use it to build an array containing column numeric status
			tableDetails = [NSDictionary dictionaryWithDictionary:[tableDataInstance informationForTable:tableName]];
			colCount = [[tableDetails objectForKey:@"columns"] count];
			tableColumnNumericStatus = [NSMutableArray arrayWithCapacity:colCount];
			for ( j = 0; j < colCount ; j++ ) {
				tableColumnTypeGrouping = [[[tableDetails objectForKey:@"columns"] objectAtIndex:j] objectForKey:@"typegrouping"];
				if ([tableColumnTypeGrouping isEqualToString:@"bit"] || [tableColumnTypeGrouping isEqualToString:@"integer"]
					|| [tableColumnTypeGrouping isEqualToString:@"float"]) {
					[tableColumnNumericStatus addObject:[NSNumber numberWithBool:YES]];
				} else {
					[tableColumnNumericStatus addObject:[NSNumber numberWithBool:NO]];
				}
			}
			
			// Update the progress text and set the progress bar back to determinate
			[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %i of %i (%@): Dumping...", @"text showing that app is writing data for table dump"), (i+1), [selectedTables count], tableName]];
			[singleProgressText displayIfNeeded];
			[singleProgressBar stopAnimation:self];
			[singleProgressBar setUsesThreadedAnimation:NO];
			[singleProgressBar setIndeterminate:NO];
			[singleProgressBar setDoubleValue:0];
			[singleProgressBar displayIfNeeded];
			
			if (rowCount) {
				[queryResult dataSeek:0];
				queryLength = 0;
				
				// Construct the start of the insertion command
				[fileHandle writeData:[[NSString stringWithFormat:@"INSERT INTO `%@` (`%@`)\nVALUES\n\t(",
										tableName, [fieldNames componentsJoinedByString:@"`,`"]] dataUsingEncoding:connectionEncoding]];
				
				// Iterate through the rows to construct a VALUES group for each
				for ( j = 0 ; j < rowCount ; j++ ) {
					theRow = [queryResult fetchRowAsArray];
					[sqlString setString:@""];
					
					// Update the progress bar
					[singleProgressBar setDoubleValue:((j+1)*100/rowCount)];
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
					if (j != rowCount - 1) {
						
						// Add a new INSERT starter command every ~250k of data.
						if (queryLength > 250000) {
							[sqlString appendString:[NSString stringWithFormat:@");\n\nINSERT INTO `%@` (`%@`)\nVALUES\n\t(",
													 tableName, [fieldNames componentsJoinedByString:@"`,`"]]];
							queryLength = 0;
						} else {
							[sqlString appendString:@"),\n\t("];
						}
					} else {
						[sqlString appendString:@")"];
					}
					
					// Write this row to the file
					[fileHandle writeData:[sqlString dataUsingEncoding:connectionEncoding]];
				}
				
				// Complete the command
				[fileHandle writeData:[[NSString stringWithString:@";\n\n"] dataUsingEncoding:connectionEncoding]];
				
				if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
					[errors appendString:[NSString stringWithFormat:@"%@\n", [mySQLConnection getLastErrorMessage]]];
					if ( [addErrorsSwitch state] == NSOnState ) {
						[fileHandle writeData:[[NSString stringWithFormat:@"# Error: %@\n", [mySQLConnection getLastErrorMessage]]
											   dataUsingEncoding:connectionEncoding]];
					}
				}
			}
		}
		
		// Add an additional separator between tables
		[fileHandle writeData:[[NSString stringWithString:@"\n\n"] dataUsingEncoding:connectionEncoding]];
	}
	
	// Close the progress sheet
	[NSApp endSheet:singleProgressSheet];
	[singleProgressSheet orderOut:nil];
	
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
	
	return TRUE;
}

/*
 Takes an array and writes it in CSV format to the supplied NSFileHandle
 */
- (BOOL)writeCsvForArray:(NSArray *)array orQueryResult:(CMMCPResult *)queryResult toFileHandle:(NSFileHandle *)fileHandle
		outputFieldNames:(BOOL)outputFieldNames
		terminatedBy:(NSString *)fieldSeparatorString
		enclosedBy:(NSString *)enclosingString
		escapedBy:(NSString *)escapeString
		lineEnds:(NSString *)lineEndString
		withNumericColumns:(NSArray *)tableColumnNumericStatus
		silently:(BOOL)silently;
{
	NSStringEncoding tableEncoding = [CMMCPConnection encodingForMySQLEncoding:[[tableDocumentInstance connectionEncoding] cString]];
	NSMutableString *csvCell = [NSMutableString string];
	NSMutableArray *csvRow = [NSMutableArray array];
	NSMutableString *csvString = [NSMutableString string];
	NSString *nullString = [NSString stringWithString:[prefs objectForKey:@"nullValue"]];
	NSString *escapedEscapeString, *escapedFieldSeparatorString, *escapedEnclosingString, *escapedLineEndString;
	NSString *dataConversionString;
	NSScanner *csvNumericTester;
	BOOL quoteFieldSeparators = [enclosingString isEqualToString:@""];
	BOOL csvCellIsNumeric;
	int i, j, startingRow, totalRows, progressBarWidth, lastProgressValue;
	
	if (queryResult != nil && [queryResult numOfRows]) [queryResult dataSeek:0];
	
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
	[singleProgressBar setDoubleValue:0];
	[singleProgressBar displayIfNeeded];
	
	if ( !silently ) {
		
		// Set the progress text
		[singleProgressText setStringValue:NSLocalizedString(@"Exporting...", @"text showing that app is exporting to text file")];
		[singleProgressText displayIfNeeded];
		
		
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
	
	// Determine the total number of rows and starting row depending on supplied data format
	if (array == nil) {
		startingRow = outputFieldNames ? -1 : 0;
		totalRows = [queryResult numOfRows];
	} else {
		startingRow = outputFieldNames ? 0 : 1;
		totalRows = [array count];
	}
	
	// Walk through the supplied data constructing the CSV string
	for ( i = startingRow ; i < totalRows ; i++ ) {
		
		// Update the progress bar
		[singleProgressBar setDoubleValue:((i+1)*100/totalRows)];
		if ((int)[singleProgressBar doubleValue] > lastProgressValue) {
			lastProgressValue = (int)[singleProgressBar doubleValue];
			[singleProgressBar displayIfNeeded];
		}
		
		// Retrieve the row from the supplied data
		if (array == nil) {
			
			// Header row
			if (i == -1) {
				[csvRow setArray:[queryResult fetchFieldNames]];
			} else {
				[csvRow setArray:[queryResult fetchRowAsArray]];
			}
		} else {
			[csvRow setArray:[array objectAtIndex:i]];		
		}
		
		[csvString setString:@""];
		for ( j = 0 ; j < [csvRow count] ; j++ ) {
			
			// For NULL objects supplied from a queryResult, add an unenclosed null string as per prefs
			if ([[csvRow objectAtIndex:j] isKindOfClass:[NSNull class]]) {
				[csvString appendString:nullString];
				if (j < [csvRow count] - 1) [csvString appendString:fieldSeparatorString];
				continue;
			}
			
			// Retrieve the contents of this cell
			if ([[csvRow objectAtIndex:j] isKindOfClass:[NSData class]]) {
				dataConversionString = [[NSString alloc] initWithData:[csvRow objectAtIndex:j] encoding:tableEncoding];
				[csvCell setString:[NSString stringWithString:dataConversionString]];
				[dataConversionString release];
			} else {
				[csvCell setString:[[csvRow objectAtIndex:j] description]];
			}
			
			// For NULL values supplied via an array add the unenclosed null string as set in preferences
			if ( [csvCell isEqualToString:nullString] ) {
				[csvString appendString:nullString];

			// Add empty strings as a pair of enclosing characters.
			} else if ( [csvCell length] == 0 ) {
				[csvString appendString:enclosingString];
				[csvString appendString:enclosingString];
				
			} else {
				
				// Test whether this cell contains a number
				if ([[csvRow objectAtIndex:j] isKindOfClass:[NSData class]]) {
					csvCellIsNumeric = FALSE;

				// If an array of bools supplying information as to whether the column is numeric has been supplied, use it.
				} else if (tableColumnNumericStatus != nil) {
					csvCellIsNumeric = [[tableColumnNumericStatus objectAtIndex:j] boolValue];

				// Or fall back to testing numeric content via an NSScanner.
				} else {
					csvNumericTester = [NSScanner scannerWithString:csvCell];
					csvCellIsNumeric = [csvNumericTester scanFloat:nil] && [csvNumericTester isAtEnd]
										&& ([csvCell characterAtIndex:0] != '0'
											|| [csvCell length] == 1
											|| ([csvCell length] > 1 && [csvCell characterAtIndex:1] == '.'));
				}
				
				// Escape any occurrences of the escaping character
				[csvCell replaceOccurrencesOfString:escapeString
										 withString:escapedEscapeString
											options:NSLiteralSearch
											  range:NSMakeRange(0,[csvCell length])];
				
				// Escape any occurrences of the enclosure string
				if ( ![escapeString isEqualToString:enclosingString] ) {
					[csvCell replaceOccurrencesOfString:enclosingString
											 withString:escapedEnclosingString
												options:NSLiteralSearch
												  range:NSMakeRange(0,[csvCell length])];
				}
				
				// Escape occurrences of the line end character
				[csvCell replaceOccurrencesOfString:lineEndString
									 withString:escapedLineEndString
										options:NSLiteralSearch
										  range:NSMakeRange(0,[csvCell length])];

				// If the string isn't quoted or otherwise enclosed, escape occurrences of the
				// field separators
				if ( quoteFieldSeparators || csvCellIsNumeric ) {
					[csvCell replaceOccurrencesOfString:fieldSeparatorString
											 withString:escapedFieldSeparatorString
												options:NSLiteralSearch
												  range:NSMakeRange(0,[csvCell length])];
				}
				
				// Write out the cell data by appending strings - this is significantly faster than stringWithFormat.
				if (csvCellIsNumeric) {
					[csvString appendString:csvCell];
				} else {
					[csvString appendString:enclosingString];
					[csvString appendString:csvCell];
					[csvString appendString:enclosingString];
				}
			}
			if (j < [csvRow count] - 1) [csvString appendString:fieldSeparatorString];
		}
		
		// Append the line ending to the string for this row
		[csvString appendString:lineEndString];
		
		// Write it to the fileHandle
		[fileHandle writeData:[csvString dataUsingEncoding:tableEncoding]];
	}
	
	// Close the progress sheet if it's present
	if ( !silently ) {
		[NSApp endSheet:singleProgressSheet];
		[singleProgressSheet orderOut:nil];
	}
	
	return TRUE;
}


- (NSArray *)arrayForCSV:(NSString *)csv terminatedBy:(NSString *)terminated
			  enclosedBy:(NSString *)enclosed escapedBy:(NSString *)escaped lineEnds:(NSString *)lineEnds
/*
 loads a csv string into an array
 */
{

	//NSLog(@"In arrayForCSV...");
	
	NSMutableString *tempTerminated, *tempLineEnds;
	NSMutableArray *tempArray = [NSMutableArray array];
	NSMutableArray *tempRowArray = [NSMutableArray array];
	NSMutableString *mutableField;
	NSScanner *scanner;
	NSString *scanString;
	NSMutableString *tempString = [NSMutableString string];
	NSMutableArray *linesArray = [NSMutableArray array];
	BOOL isEscaped, br;
	int fieldCount = nil;
	int x,i,j;

	//repare tabs and line ends
	tempTerminated = [NSMutableString stringWithString:terminated];
	[tempTerminated replaceOccurrencesOfString:@"\\t" withString:@"\t"
									   options:NSLiteralSearch
										 range:NSMakeRange(0, [tempTerminated length])];
	[tempTerminated replaceOccurrencesOfString:@"\\n" withString:@"\n"
									   options:NSLiteralSearch
										 range:NSMakeRange(0, [tempTerminated length])];
	[tempTerminated replaceOccurrencesOfString:@"\\r" withString:@"\r"
									   options:NSLiteralSearch
										 range:NSMakeRange(0, [tempTerminated length])];
	terminated = [NSString stringWithString:tempTerminated];
	tempLineEnds = [NSMutableString stringWithString:lineEnds];
	[tempLineEnds replaceOccurrencesOfString:@"\\t" withString:@"\t"
									 options:NSLiteralSearch
									   range:NSMakeRange(0, [tempLineEnds length])];
	[tempLineEnds replaceOccurrencesOfString:@"\\n" withString:@"\n"
									 options:NSLiteralSearch
									   range:NSMakeRange(0, [tempLineEnds length])];
	[tempLineEnds replaceOccurrencesOfString:@"\\r" withString:@"\r"
									 options:NSLiteralSearch
									   range:NSMakeRange(0, [tempLineEnds length])];
	lineEnds = [NSString stringWithString:tempLineEnds];
	
	//array with one line per object
	scanner = [NSScanner scannerWithString:csv];
	[scanner setCharactersToBeSkipped:nil];
	
	while ( ![scanner isAtEnd] && !progressCancelled) {
		[tempString setString:@""];
		br = NO;
		
		while ( !br ) {
			scanString = @"";
			[scanner scanUpToString:lineEnds intoString:&scanString];
			[tempString appendString:scanString];
			[scanner scanString:lineEnds intoString:&scanString];
			
			//test if lineEnds-character is escaped
			isEscaped = NO;
			j = 1;
			if ( ![escaped isEqualToString:enclosed] && ![escaped isEqualToString:@""] ) {
				while ( ((j*[escaped length])<=[tempString length]) &&
					   ([[tempString substringWithRange:NSMakeRange(([tempString length]-(j*[escaped length])),[escaped length])] isEqualToString:escaped]) ) {
					isEscaped = !isEscaped;
					j++;
				}
			}
			if ( !isEscaped || [scanner isAtEnd] ) {
				//end of row
				br = YES;
			} else {
				//lineEnds-character was escaped
				[tempString appendString:scanString];
			}
		}
		
		// Skip blank lines
		if (![tempString length]) continue;
		// Add the line to the array
		[linesArray addObject:[NSString stringWithString:tempString]];
	}
	
	for ( x = 0 ; x < [linesArray count] && !progressCancelled; x++ ) {
		
		//separate fields
		[tempRowArray removeAllObjects];
		[tempRowArray addObjectsFromArray:[self arrayForString:[linesArray objectAtIndex:x] enclosed:enclosed escaped:escaped terminated:terminated]];
		if ( x == 0 ) {
			fieldCount = [tempRowArray count];
		} else {
			while ( [tempRowArray count] < fieldCount ) {
				[tempRowArray addObject:[NSString stringWithString:[prefs objectForKey:@"nullValue"]]];
			}
		}
		for ( i = 0 ; i < [tempRowArray count] ; i++ ) {
			
			// Insert a NSNull object if the cell contains an unescaped null character or an unescaped string
			// which matches the NULL string set in preferences.
			if ( [[tempRowArray objectAtIndex:i] isEqualToString:@"\\N"] || [[tempRowArray objectAtIndex:i] isEqualToString:[prefs objectForKey:@"nullValue"]] ) {
				[tempRowArray replaceObjectAtIndex:i withObject:[NSNull null]];
				
			} else {
				
				//strip enclosed and escaped characters
				mutableField = [NSMutableString stringWithString:[tempRowArray objectAtIndex:i]];
				
				//strip enclosed characters
				if ( [mutableField length] >= (2*[enclosed length]) ) {
					if ( [[mutableField substringToIndex:[enclosed length]] isEqualToString:enclosed] ) {
						[mutableField deleteCharactersInRange:NSMakeRange(0,[enclosed length])];
					}
					if ( [[mutableField substringFromIndex:([mutableField length]-[enclosed length])] isEqualToString:enclosed] ) {
						[mutableField deleteCharactersInRange:NSMakeRange(([mutableField length]-[enclosed length]),[enclosed length])];
					}
				}
				if ( [mutableField length] >= [enclosed length] ) {
					if ( [[mutableField substringFromIndex:([mutableField length]-[enclosed length])] isEqualToString:enclosed] ) {
						[mutableField deleteCharactersInRange:NSMakeRange(([mutableField length]-[enclosed length]),[enclosed length])];
					}
				}
				//strip escaped characters
				if ( ![enclosed isEqualToString:@""] ) {
					[mutableField replaceOccurrencesOfString:[NSString stringWithFormat:@"%@%@", escaped, enclosed] withString:enclosed options:NSLiteralSearch range:NSMakeRange(0, [mutableField length])];
				} else {
					[mutableField replaceOccurrencesOfString:[NSString stringWithFormat:@"%@%@", escaped, terminated] withString:terminated options:NSLiteralSearch range:NSMakeRange(0, [mutableField length])];
				}
				if ( ![lineEnds isEqualToString:@""] ) {
					[mutableField replaceOccurrencesOfString:[NSString stringWithFormat:@"%@%@", escaped, lineEnds] withString:lineEnds options:NSLiteralSearch range:NSMakeRange(0, [mutableField length])];
				}
				if ( ![escaped isEqualToString:@""] && ![escaped isEqualToString:enclosed] ) {
					[mutableField replaceOccurrencesOfString:[NSString stringWithFormat:@"%@%@", escaped, escaped] withString:escaped options:NSLiteralSearch range:NSMakeRange(0, [mutableField length])];
				}
				//add field to tempRowArray
				[tempRowArray replaceObjectAtIndex:i withObject:[NSString stringWithString:mutableField]];
			}
		}
		//add row to tempArray
		[tempArray addObject:[NSArray arrayWithArray:tempRowArray]];
		//NSLog(@"tempArray count: %d", [tempArray count]);
	}
	
	return [NSArray arrayWithArray:tempArray];
}


/*
 Takes an array and writes it in XML format to the supplied NSFileHandle
 */
- (BOOL)writeXmlForArray:(NSArray *)array orQueryResult:(CMMCPResult *)queryResult toFileHandle:(NSFileHandle *)fileHandle tableName:(NSString *)table withHeader:(BOOL)header silently:(BOOL)silently
{
	NSStringEncoding tableEncoding = [CMMCPConnection encodingForMySQLEncoding:[[tableDocumentInstance connectionEncoding] cString]];
	NSMutableArray *xmlTags = [NSMutableArray array];
	NSMutableArray *xmlRow = [NSMutableArray array];
	NSMutableString *xmlString = [NSMutableString string];
	NSMutableString *xmlItem = [NSMutableString string];
	NSString *dataConversionString;
	int i,j, startingRow, totalRows, progressBarWidth, lastProgressValue;
	
	if (queryResult != nil && [queryResult numOfRows]) [queryResult dataSeek:0];
	
	// Updating the progress bar can take >20% of processing time - store details to only update when required
	progressBarWidth = (int)[singleProgressBar bounds].size.width;
	lastProgressValue = 0;
	[singleProgressBar setDoubleValue:0];
	[singleProgressBar displayIfNeeded];
	
	// Set up an array of encoded field names as opening and closing tags
	if (array == nil) {
		[xmlRow setArray:[queryResult fetchFieldNames]];	
	} else {
		[xmlRow setArray:[array objectAtIndex:0]];
	}
	for ( j = 0; j < [xmlRow count]; j++ ) {
		[xmlTags addObject:[NSMutableArray array]];
		[[xmlTags objectAtIndex:j] addObject:[NSString stringWithFormat:@"\t\t<%@>",
											  [self htmlEscapeString:[[xmlRow objectAtIndex:j] description]]]];
		[[xmlTags objectAtIndex:j] addObject:[NSString stringWithFormat:@"</%@>\n",
											  [self htmlEscapeString:[[xmlRow objectAtIndex:j] description]]]];
	}
	
	if ( !silently ) {
		
		// Set the progress text
		[singleProgressText setStringValue:NSLocalizedString(@"Writing...", @"text showing that app is writing text file")];
		[singleProgressText displayIfNeeded];
		
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
	
	// Determine the total number of rows and starting row depending on supplied data format
	if (array == nil) {
		startingRow = 0;
		totalRows = [queryResult numOfRows];
	} else {
		startingRow = 1;
		totalRows = [array count];
	}
	
	// Walk through the array, contructing the XML string.
	for ( i = 1 ; i < totalRows ; i++ ) {
		
		// Update the progress bar
		[singleProgressBar setDoubleValue:((i+1)*100/totalRows)];
		if ((int)[singleProgressBar doubleValue] > lastProgressValue) {
			lastProgressValue = (int)[singleProgressBar doubleValue];
			[singleProgressBar displayIfNeeded];
		}
		
		// Retrieve the row from the supplied data
		if (array == nil) {
			[xmlRow setArray:[queryResult fetchRowAsArray]];
		} else {
			[xmlRow setArray:[array objectAtIndex:i]];		
		}
		
		// Construct the row
		[xmlString setString:@"\t<row>\n"];
		for ( j = 0 ; j < [xmlRow count] ; j++ ) {
			
			// Retrieve the contents of this tag
			if ([[xmlRow objectAtIndex:j] isKindOfClass:[NSData class]]) {
				dataConversionString = [[NSString alloc] initWithData:[xmlRow objectAtIndex:j] encoding:tableEncoding];
				[xmlItem setString:[NSString stringWithString:dataConversionString]];
				[dataConversionString release];
			} else {
				[xmlItem setString:[[xmlRow objectAtIndex:j] description]];
			}
			
			// Add the opening and closing tag and the contents to the XML string
			[xmlString appendString:[[xmlTags objectAtIndex:j] objectAtIndex:0]];
			[xmlString appendString:[self htmlEscapeString:xmlItem]];
			[xmlString appendString:[[xmlTags objectAtIndex:j] objectAtIndex:1]];
		}
		[xmlString appendString:@"\t</row>\n"];
		
		// Write the row to the filehandle
		[fileHandle writeData:[xmlString dataUsingEncoding:tableEncoding]];
	}
	
	// Write the closing tag for the table
	[fileHandle writeData:[[NSString stringWithFormat:@"\t</%@>",
							[self htmlEscapeString:table]]
						   dataUsingEncoding:tableEncoding]];
	
	// Close the progress sheet if appropriate
	if ( !silently ) {
		[NSApp endSheet:singleProgressSheet];
		[singleProgressSheet orderOut:nil];
	}
	
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
	
	return [self exportTables:selectedTables toFileHandle:fileHandle usingFormat:type];
}

/*
 Walks through the selected tables and exports them to a file handle.  The export type must be
 "csv" for CSV format, and "xml" for XML format.
 */
- (BOOL)exportTables:(NSArray *)selectedTables toFileHandle:(NSFileHandle *)fileHandle usingFormat:(NSString *)type
{
	int i, j;
	CMMCPResult *queryResult;
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
	[singleProgressText setStringValue:NSLocalizedString(@"Writing...", @"text showing that app is writing text file")];
	[singleProgressText displayIfNeeded];
	[singleProgressBar setDoubleValue:0];
	[singleProgressBar displayIfNeeded];
	
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

		// Retrieve the table details via the data class, and use it to build an array containing column numeric status
		tableDetails = [NSDictionary dictionaryWithDictionary:[tableDataInstance informationForTable:tableName]];
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

		// Retrieve all the content within this table
		queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT * FROM `%@`", tableName]];
		
		// Note any errors during retrieval
		if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
			[errors appendString:[NSString stringWithFormat:@"%@\n", [mySQLConnection getLastErrorMessage]]];
		}
		
		// Update the progress text and set the progress bar back to determinate
		[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %i of %i (%@): Writing...", @"text showing that app is writing data for table export"), (i+1), [selectedTables count], tableName]];
		[singleProgressText displayIfNeeded];
		[singleProgressBar stopAnimation:self];
		[singleProgressBar setUsesThreadedAnimation:NO];
		[singleProgressBar setIndeterminate:NO];
		[singleProgressBar setDoubleValue:0];
		[singleProgressBar displayIfNeeded];
		
		// Use the appropriate export method to write the data to file
		if ( [type isEqualToString:@"csv"] ) {
			[self writeCsvForArray:nil orQueryResult:queryResult
					  toFileHandle:fileHandle
				  outputFieldNames:[exportMultipleFieldNamesSwitch state]
					  terminatedBy:[exportMultipleFieldsTerminatedField stringValue]
						enclosedBy:[exportMultipleFieldsEnclosedField stringValue]
						 escapedBy:[exportMultipleFieldsEscapedField stringValue]
						  lineEnds:[exportMultipleLinesTerminatedField stringValue]
				withNumericColumns:tableColumnNumericStatus
						  silently:YES];

			// Add a spacer to the file
			[fileHandle writeData:[[NSString stringWithFormat:@"%@%@%@", csvLineEnd, csvLineEnd, csvLineEnd] dataUsingEncoding:connectionEncoding]];
		} else if ( [type isEqualToString:@"xml"] ) {
			[self writeXmlForArray:nil orQueryResult:queryResult
					  toFileHandle:fileHandle
						 tableName:tableName
						withHeader:NO
						  silently:YES];
			
			// Add a spacer to the file
			[fileHandle writeData:[[NSString stringWithString:@"\n\n\n"] dataUsingEncoding:connectionEncoding]];
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

- (NSArray *)arrayForString:(NSString *)string enclosed:(NSString *)enclosed
					escaped:(NSString *)escaped terminated:(NSString *)terminated
/*
 split a string by the terminated-character if this is not escaped
 if enclosed-character is given, ignores characters inside enclosed-characters
 */
{
	NSMutableArray *tempArray = [NSMutableArray array];
	BOOL inString = NO;
	BOOL isEscaped = NO;
	BOOL br = NO;
	unsigned i, j, start;
	char enc = nil;
	char esc = nil;
	char ter = nil;
	
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
				//NSLog([string substringWithRange:NSMakeRange(start,(i-start))]);
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
- (void)setConnection:(CMMCPConnection *)theConnection
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
	if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
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
#pragma mark tableView datasource methods

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
	if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"useMonospacedFonts"] ) {
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
#pragma mark other
//last but not least
- (id)init;
{
	self = [super init];
	
	tables = [[NSMutableArray alloc] init];
	fieldMappingButtonOptions = [[NSMutableArray alloc] init];
	
	return self;
}

- (void)dealloc
{
	//	NSLog(@"TableDump dealloc");
	
	[tables release];
	[importArray release];
	[fieldMappingButtonOptions release];
	[fieldMappingArray release];
	[savePath release];
	[openPath release];
	[prefs release];   
	
	[super dealloc];
}

- (IBAction)cancelProgressBar:(id)sender
{
	progressCancelled = YES;	
}

@end

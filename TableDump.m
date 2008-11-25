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
#import <Growl/Growl.h>


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
	
	for ( i = 0 ; i < [queryResult numOfRows] ; i++ ) {
		[queryResult dataSeek:i];
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

#pragma mark export methods

- (void)exportFile:(int)tag
/*
invoked when user clicks on an export menuItem
*/
{
	NSString *file;
	NSString *contextInfo;
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	NSString *currentDate = [[NSDate date] descriptionWithCalendarFormat:@"%d.%m.%Y" timeZone:nil locale:nil];

    switch ( tag ) {
        case 5:
			// export dump
            [self reloadTables:self];
            file = [NSString stringWithFormat:@"%@_dump %@.sql", [tableDocumentInstance database], currentDate];
            [savePanel setAccessoryView:exportDumpView];
            contextInfo = @"exportDump";
			break;
        case 6:
			// export table content as CSV
            file = [NSString stringWithFormat:@"%@.csv", [tableDocumentInstance table]];
            [savePanel setAccessoryView:exportCSVView];
            contextInfo = @"exportTableContentAsCSV";
			break;
        case 7:
			// export table content as XML
            file = [NSString stringWithFormat:@"%@.xml", [tableDocumentInstance table]];
            contextInfo = @"exportTableContentAsXML";
			break;
        case 8:
			// export custom result as CSV
            file = @"customresult.csv";
            [savePanel setAccessoryView:exportCSVView];
            contextInfo = @"exportCustomResultAsCSV";
			break;
        case 9:
			// export custom result as XML
            file = @"customresult.xml";
            contextInfo = @"exportCustomResultAsXML";
			break;
        case 10:
			// export multiple tables as CSV
            [self reloadTables:self];
            file = [NSString stringWithFormat:@"%@.csv", [tableDocumentInstance database]];
            [savePanel setAccessoryView:exportMultipleCSVView];
            contextInfo = @"exportMultipleTablesAsCSV";
			break;
        case 11:
			// export multiple tables as XML
            [self reloadTables:self];
            file = [NSString stringWithFormat:@"%@.xml", [tableDocumentInstance database]];
            [savePanel setAccessoryView:exportMultipleXMLView];
            contextInfo = @"exportMultipleTablesAsXML";
			break;
        default:
            NSLog(@"ERROR: unknown export item with tag %d", tag);
            return;
			break;
    }
	
    //open savePanel
    [savePanel beginSheetForDirectory:[prefs objectForKey:@"savePath"]
            file:file modalForWindow:tableWindow modalDelegate:self
            didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:contextInfo];
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
/*
saves the export file
*/
{
	NSString *testString = @"";
	NSError **errorStr; 
	id fileContent;
	BOOL success;
    
    [sheet orderOut:self];
    
	if ( returnCode != NSOKButton )
        return;
	
	//save path to preferences
    [prefs setObject:[sheet directory] forKey:@"savePath"];

//error if file exists and is not writable
	if ( [[NSFileManager defaultManager] fileExistsAtPath:[sheet filename]] ) {
		if ( ![[NSFileManager defaultManager] isWritableFileAtPath:[sheet filename]] ) {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
					NSLocalizedString(@"Couldn't replace the file. Be sure that you have the necessary privileges.", @"message of panel when file cannot be replaced"));
			return;
		}
	} else {
//error if file cannot be written
		// MLT: Need to use make use of NSError here
		if ( ![testString writeToFile:[sheet filename] atomically:YES encoding:NSUTF8StringEncoding error:nil] ) {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
					NSLocalizedString(@"Couldn't write to file. Be sure that you have the necessary privileges.", @"message of panel when file cannot be written"));
			return;
		}
	}

    if ( [contextInfo isEqualToString:@"exportDump"] ) {
		//export dump of selected database
        fileContent = [self dumpForSelectedTables];
		
    } else if ( [contextInfo isEqualToString:@"exportCustomResultAsCSV"] ) {
		//export custom query result as csv
        fileContent = [self csvForArray:[customQueryInstance currentResult] useFirstLine:[exportFieldNamesSwitch state]
                                terminatedBy:[exportFieldsTerminatedField stringValue]
                                enclosedBy:[exportFieldsEnclosedField stringValue]
                                escapedBy:[exportFieldsEscapedField stringValue]
                                lineEnds:[exportLinesTerminatedField stringValue]
                                silently:NO];
		
    } else if ( [contextInfo isEqualToString:@"exportTableContentAsCSV"] ) {
		//export table content as csv
        fileContent = [self csvForArray:[tableContentInstance currentResult] useFirstLine:[exportFieldNamesSwitch state]
                                terminatedBy:[exportFieldsTerminatedField stringValue]
                                enclosedBy:[exportFieldsEnclosedField stringValue]
                                escapedBy:[exportFieldsEscapedField stringValue]
                                lineEnds:[exportLinesTerminatedField stringValue]
                                silently:NO];
		
    } else if ( [contextInfo isEqualToString:@"exportMultipleTablesAsCSV"] ) {
		//export multiple tables as CSV
        fileContent = [self stringForSelectedTablesWithType:@"csv"];
		
    } else if ( [contextInfo isEqualToString:@"exportCustomResultAsXML"] ) {
		//export custom query result as XML
        fileContent = [self xmlForArray:[customQueryInstance currentResult]
                                tableName:@"custom"
                                withHeader:YES
                                silently:NO];
		
    } else if ( [contextInfo isEqualToString:@"exportTableContentAsXML"] ) {
		//export table content as XML
        fileContent = [self xmlForArray:[tableContentInstance currentResult]
                                tableName:[tableDocumentInstance table]
                                withHeader:YES
                                silently:NO];
		
    } else if ( [contextInfo isEqualToString:@"exportMultipleTablesAsXML"] ) {
		//export multiple tables as XML
        fileContent = [self stringForSelectedTablesWithType:@"xml"];
		
    } else {
		//unknown operation
        NSLog(@"unknown operation %@", [contextInfo description]);
        fileContent = @"";
    }

	if ( [fileContent respondsToSelector:@selector(writeToFile:atomically:encoding:error:)] ) {
		// mac os 10.4 or later
		success = [fileContent writeToFile:[sheet filename] atomically:YES encoding:[CMMCPConnection encodingForMySQLEncoding:[[tableDocumentInstance encoding] cString]]  error:errorStr];
	} else {
		// mac os pre 10.4
		success = [fileContent writeToFile:[sheet filename] atomically:YES];
	}
	
    if ( !success ) {
        NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
            NSLocalizedString(@"Couldn't write to file. Be sure that you have the necessary privileges.", @"message of panel when file cannot be written"));
    }
	
	// Export Finished Growl Notification
	[GrowlApplicationBridge notifyWithTitle:@"Export Finished"
								description:[NSString stringWithFormat:NSLocalizedString(@"Finished exporting to %@",@"description for finished exporting growl notification"), [[sheet filename] lastPathComponent]]
						   notificationName:@"Export Finished"
								   iconData:nil
								   priority:0
								   isSticky:NO
							   clickContext:nil
	 ];

}

#pragma mark import methods

- (void)importFile
/*
invoked when user clicks on an import menuItem
*/
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAccessoryView:importCSVView];

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
	NSPopUpButtonCell *buttonCell = [[NSPopUpButtonCell alloc] init];
	
	[tableSourceInstance loadTable:[fieldMappingPopup titleOfSelectedItem]];
	
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
	[buttonCell addItemWithTitle:NSLocalizedString(@"Do not import", @"text for csv import drop downs")];
	[buttonCell addItemsWithTitles:[tableSourceInstance fieldNames]];
	
	[[fieldMappingTableView tableColumnWithIdentifier:@"1"] setDataCell:buttonCell];
	[fieldMappingTableView reloadData];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
/*
reads mysql-dumpfile
*/
{
	NSString *dumpFile;
	NSError **errorStr; 
    NSMutableString *errors = [NSMutableString string];
	NSString *fileType = [[importFormatPopup selectedItem] title];

    [sheet orderOut:self];
	
    if ( returnCode != NSOKButton )
        return;

	//save path to preferences
	[prefs setObject:[sheet directory] forKey:@"openPath"];

	//load file into string
	if ( [NSString respondsToSelector:@selector(stringWithContentsOfFile:encoding:error:)] ) {
		// mac os 10.4 or later
		dumpFile = [NSString stringWithContentsOfFile:[sheet filename]
											 encoding:[CMMCPConnection encodingForMySQLEncoding:[[tableDocumentInstance encoding] cString]]
												error:errorStr];
	} else {
		// mac os pre 10.4
		dumpFile = [NSString stringWithContentsOfFile:[sheet filename]];
	}
	
	if ( !dumpFile ) {
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"),
						  NSLocalizedString(@"OK", @"OK button"),
						  nil,
						  nil,
						  tableWindow,
						  self,
						  nil,
						  nil,
						  nil,
						  NSLocalizedString(@"Couldn't open file. Be sure that the path is correct and that you have the necessary privileges.", @"message of panel when file cannot be opened"));
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
        queries = [self splitQueries:dumpFile];
    
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
		
		
	// 	
    } else if ( [fileType isEqualToString:@"CSV"] ) {
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
		
		//show fieldMapping sheet
		CMMCPResult *theResult;
		int i;
		theResult = (CMMCPResult *) [mySQLConnection listTables];
		for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
			[theResult dataSeek:i];
			[fieldMappingPopup addItemWithTitle:[[theResult fetchRowAsArray] objectAtIndex:0]];
		}
		
		if ([tableDocumentInstance table] != nil && ![(NSString *)[tableDocumentInstance table] isEqualToString:@""]) {
			[fieldMappingPopup selectItemWithTitle:[(TableDocument *)tableDocumentInstance table]];
		} else {
			[fieldMappingPopup selectItemAtIndex:0];
		}

		[tableSourceInstance loadTable:[fieldMappingPopup titleOfSelectedItem]];
		
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
        [buttonCell addItemWithTitle:NSLocalizedString(@"Do not import", @"text for csv import drop downs")];
        [buttonCell addItemsWithTitles:[tableSourceInstance fieldNames]];
		
        [[fieldMappingTableView tableColumnWithIdentifier:@"1"] setDataCell:buttonCell];
		
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
            NSMutableArray *fValuesIndexes = [NSMutableArray array];
            NSMutableString *fValues = [NSMutableString string];
            int i,j;
            
			//open progress sheet
            [NSApp beginSheet:singleProgressSheet
			   modalForWindow:tableWindow
				modalDelegate:self
			   didEndSelector:nil
				  contextInfo:nil];

			//get fields to be imported
            for ( i = 0 ; i < [fieldMappingArray count] ; i++ ) {
                if ( [[[fieldMappingArray objectAtIndex:i] objectAtIndex:1] intValue] > 0 ) {
					//field marked for import
                    if ( [fNames length] )
                        [fNames appendString:@","];
					
                    [fNames appendString:[NSString stringWithFormat:@"`%@`",[[tableSourceInstance fieldNames] objectAtIndex:([[[fieldMappingArray objectAtIndex:i] objectAtIndex:1] intValue]-1)]]];
                    [fValuesIndexes addObject:[NSNumber numberWithInt:i]];
                }
            }
			
			//import array
            for ( i = 0 ; i < [importArray count] ; i++ ) {
                //show progress bar
                [singleProgressBar setDoubleValue:((i+1)*100/[importArray count])];
                [singleProgressBar displayIfNeeded];
				
                if ( ![importFieldNamesSwitch state] || (i != 0) ) {
					//put values in string
                    [fValues setString:@""];
					
                    for ( j = 0 ; j < [fValuesIndexes count] ; j++ ) {
                        if ( [fValues length] )
                            [fValues appendString:@","];
						
                        if ( [[[importArray objectAtIndex:i] objectAtIndex:[[fValuesIndexes objectAtIndex:j] intValue]] isMemberOfClass:[NSNull class]] ) {
                            [fValues appendString:@"NULL"];
                        } else {
                            [fValues appendString:[NSString stringWithFormat:@"'%@'",[mySQLConnection prepareString:[[importArray objectAtIndex:i] objectAtIndex:[[fValuesIndexes objectAtIndex:j] intValue]]]]];
							//[fValues appendString:[NSString stringWithFormat:@"\"%@\"",[mySQLConnection prepareString:[[importArray objectAtIndex:i] objectAtIndex:[[fValuesIndexes objectAtIndex:j] intValue]]]]];
                        }
                    }
					
					//perform query
                    [mySQLConnection queryString:[NSString stringWithFormat:@"INSERT INTO `%@` (%@) VALUES (%@)",
												  [tablesListInstance table],
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
	
	// Import Finished Growl Notification
	[GrowlApplicationBridge notifyWithTitle:@"Import Finished"
								description:[NSString stringWithFormat:NSLocalizedString(@"Finished importing %@",@"description for finished importing growl notification"), [[sheet filename] lastPathComponent]]
						   notificationName:@"Import Finished"
								   iconData:nil
								   priority:0
								   isSticky:NO
							   clickContext:nil
	];
	
}

- (void)setupFieldMappingArray
/*
sets up the fieldMapping array to be shown in the tableView
*/
{
	int i, value;

    if ( fieldMappingArray ) {
        for ( i = 0 ; i < [fieldMappingArray count] ; i++ ) {
            if ( [[[importArray objectAtIndex:currentRow] objectAtIndex:i] isKindOfClass:[NSNull class]] ) {
                [[fieldMappingArray objectAtIndex:i] replaceObjectAtIndex:0 withObject:@"NULL"];
            } else {
                [[fieldMappingArray objectAtIndex:i] replaceObjectAtIndex:0 withObject:[[importArray objectAtIndex:currentRow] objectAtIndex:i]];
            }
        }
    } else {
        fieldMappingArray = [NSMutableArray array];
        for ( i = 0 ; i < [[importArray objectAtIndex:currentRow] count] ; i++ ) {
            if ( i < [[tableSourceInstance fieldNames] count] ) {
                value = i + 1;
            } else {
                value = 0;
            }
            if ( [[[importArray objectAtIndex:currentRow] objectAtIndex:i] isKindOfClass:[NSNull class]] ) {
                [fieldMappingArray addObject:[NSMutableArray arrayWithObjects:@"NULL", [NSNumber numberWithInt:value], nil]];
            } else {
                [fieldMappingArray addObject:[NSMutableArray arrayWithObjects:[[importArray objectAtIndex:currentRow] objectAtIndex:i], [NSNumber numberWithInt:value], nil]];
            }
        }
        [fieldMappingArray retain];
    }
    [fieldMappingTableView reloadData];
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
	
	[self setupFieldMappingArray];
	
	[recordCountLabel setStringValue:[NSString stringWithFormat:@"%i of %i records", currentRow+1, [importArray count]]];
	
	// enable/disable buttons
	[rowDownButton setEnabled:(currentRow != 0)];
	[rowUpButton setEnabled:(currentRow != ([importArray count]-1))];
}
		 
//format methods
- (NSString *)dumpForSelectedTables
/*
returns a dump string for the selected tables
*/
{
	int i,j,k,t,rowCount,tableCount;
	CMMCPResult *queryResult;
	NSString *tableName;
	NSArray *fieldNames;
	NSArray *theRow;
	NSMutableString *rowValue = [NSMutableString string];
	NSMutableArray *fieldValues;
	NSMutableString *dump = [NSMutableString string];
	NSMutableString *errors = [NSMutableString string];
	id createTableSyntax;

	//reset interface
	[errorsView setString:@""];
	[errorsView displayIfNeeded];
	[singleProgressText setStringValue:NSLocalizedString(@"Dumping...", @"text showing that app is writing dump")];
	[singleProgressText displayIfNeeded];
	[singleProgressBar setDoubleValue:0];
	[singleProgressBar displayIfNeeded];

	//open progress sheet
	[NSApp beginSheet:singleProgressSheet
			modalForWindow:tableWindow modalDelegate:self
			didEndSelector:nil contextInfo:nil];

//count tables
	tableCount = 0;
	for ( i = 0 ; i < [tables count] ; i++ ) {
		if ( [[[tables objectAtIndex:i] objectAtIndex:0] boolValue] ) {
			tableCount++;
		}
	}
	k = 0;

//add header of dump-file
//	[dump appendString:[NSString stringWithFormat:@"# Tables dumped %@\n# Created by Sequel Pro (Copyright (c) 2002-2003 Lorenz Textor)\n#\n# Host: %@   Database: %@\n# ******************************\n\n", [NSDate date], [tableDocumentInstance host], [tableDocumentInstance database]]];
	[dump appendString:@"# Sequel Pro dump\n"];
	[dump appendString:[NSString stringWithFormat:@"# Version %@\n",
							[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
	[dump appendString:@"# http://code.google.com/p/sequel-pro\n#\n"];
	[dump appendString:[NSString stringWithFormat:@"# Host: %@ (MySQL %@)\n",
							[tableDocumentInstance host], [tableDocumentInstance mySQLVersion]]];
	[dump appendString:[NSString stringWithFormat:@"# Database: %@\n", [tableDocumentInstance database]]];
	[dump appendString:[NSString stringWithFormat:@"# Generation Time: %@\n", [NSDate date]]];
	[dump appendString:@"# ************************************************************\n\n"];

	for ( i = 0 ; i < [tables count] ; i++ ) {
		if ( [[[tables objectAtIndex:i] objectAtIndex:0] boolValue] ) {
			k++;
//set progressbar and text
			tableName = [[tables objectAtIndex:i] objectAtIndex:1];
			[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Dumping table %@...", @"text showing that app is dumping table"), tableName]];
			[singleProgressText displayIfNeeded];
//add name of table
			[dump appendString:[NSString stringWithFormat:@"# Dump of table %@\n# ------------------------------------------------------------\n\n", tableName]];
//add drop table
			if ( [addDropTableSwitch state] == NSOnState )
				[dump appendString:[NSString stringWithFormat:@"DROP TABLE IF EXISTS `%@`;\n\n", tableName]];
//add create syntax for table
			if ( [addCreateTableSwitch state] == NSOnState ) {
				queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE `%@`", tableName]];
				if ( [queryResult numOfRows] ) {
					createTableSyntax = [[queryResult fetchRowAsDictionary] objectForKey:@"Create Table"];
					if ( [createTableSyntax isKindOfClass:[NSData class]] ) {
						createTableSyntax = [[[NSString alloc] initWithData:createTableSyntax encoding:[mySQLConnection encoding]] autorelease];
					}
					[dump appendString:[NSString stringWithFormat:@"%@;\n\n", createTableSyntax]];
				}
				if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
					[errors appendString:[NSString stringWithFormat:@"%@\n", [mySQLConnection getLastErrorMessage]]];
					if ( [addErrorsSwitch state] == NSOnState ) {
						[dump appendString:[NSString stringWithFormat:@"# Error: %@\n", [mySQLConnection getLastErrorMessage]]];
					}
				}
			}
//add table content
			if ( [addTableContentSwitch state] == NSOnState ) {
				queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT * FROM `%@`", tableName]];
				fieldNames = [queryResult fetchFieldNames];
				rowCount = [queryResult numOfRows];
				for ( j = 0 ; j < rowCount ; j++ ) {
					[queryResult dataSeek:j];
					theRow = [queryResult fetchRowAsArray];
					fieldValues = [NSMutableArray array];
					for ( t = 0 ; t < [theRow count] ; t++ ) {
						if ( [[theRow objectAtIndex:t] isKindOfClass:[NSData class]] ) {
							//escape special characters
							[rowValue setString:[mySQLConnection prepareBinaryData:[theRow objectAtIndex:t]]];
						} else {
							[rowValue setString:[[theRow objectAtIndex:t] description]];
							//escape special characters
							[rowValue setString:[mySQLConnection prepareString:rowValue]];
						}
						if ( [[theRow objectAtIndex:t] isMemberOfClass:[NSNull class]] ) {
							[fieldValues addObject:@"NULL"];
						} else {
//							[fieldValues addObject:[NSString stringWithFormat:@"\"%@\"", rowValue]];
							[fieldValues addObject:[NSString stringWithFormat:@"'%@'", rowValue]];
						}
					}
					[dump appendString:[NSString stringWithFormat:@"INSERT INTO `%@` (`%@`) VALUES (%@);\n",
						tableName, [fieldNames componentsJoinedByString:@"`,`"],
						[fieldValues componentsJoinedByString:@","]]];
				}
				if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
					[errors appendString:[NSString stringWithFormat:@"%@\n", [mySQLConnection getLastErrorMessage]]];
					if ( [addErrorsSwitch state] == NSOnState ) {
						[dump appendString:[NSString stringWithFormat:@"# Error: %@\n", [mySQLConnection getLastErrorMessage]]];
					}
				}
			}
//set progressbar and text
		[singleProgressBar setDoubleValue:(k*100/tableCount)];
		[singleProgressBar displayIfNeeded];
		[dump appendString:@"\n\n"];
		}
	}

//close progress sheet
	[NSApp endSheet:singleProgressSheet];
	[singleProgressSheet orderOut:nil];
	
//show errors sheet if there have been errors
	if ( [errors length] ) {
		[errorsView setString:errors];
		[NSApp beginSheet:errorsSheet
				modalForWindow:tableWindow modalDelegate:self
				didEndSelector:nil contextInfo:nil];
		[NSApp runModalForWindow:errorsSheet];
		
		[NSApp endSheet:errorsSheet];
		[errorsSheet orderOut:nil];
	}

	return [NSString stringWithString:dump];
}

/*
 Takes an array and returns it as a csv string
 */
- (NSString *)csvForArray:(NSArray *)array useFirstLine:(BOOL)firstLine terminatedBy:(NSString *)fieldSeparatorString
	enclosedBy:(NSString *)enclosingString escapedBy:(NSString *)escapeString lineEnds:(NSString *)lineEndString silently:(BOOL)silently;
{
	NSMutableString *csvCell = [NSMutableString string];
	NSMutableString *enclosedCsvCell = [NSMutableString string];
	NSMutableArray *csvRow = [NSMutableArray array];
	NSMutableString *csvRowString = [NSMutableString string];
	NSMutableArray *csvData = [NSMutableArray array];
	NSString *nullString = [NSString stringWithString:[prefs objectForKey:@"nullValue"]];
	NSString *escapedEscapeString, *escapedFieldSeparatorString, *escapedEnclosingString, *escapedLineEndString;
	BOOL quoteFieldSeparators = [enclosingString isEqualToString:@""];
	NSScanner *csvNumericTester;
	BOOL csvCellIsNumeric;
	int i,j, progressBarWidth, lastProgressValue;

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

	if ( !silently ) {

		// Reset progress interface
		[singleProgressText setStringValue:NSLocalizedString(@"Writing...", @"text showing that app is writing text file")];
		[singleProgressText displayIfNeeded];
		[singleProgressBar setDoubleValue:0];
		[singleProgressBar displayIfNeeded];

		// Updating the progress bar can take >20% of processing time - store details to only update when required
		progressBarWidth = (int)[singleProgressBar bounds].size.width;
		lastProgressValue = 0;
		
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

	// Walk through the array constructing the CSV string
	for ( i = 0 ; i < [array count] ; i++ ) {
	
		// Update the progress bar if the update would be visible
		if ( !silently ) {
			[singleProgressBar setDoubleValue:((i+1)*100/[array count])];
			if ((int)[singleProgressBar doubleValue] > lastProgressValue) {
				lastProgressValue = (int)[singleProgressBar doubleValue];
				[singleProgressBar displayIfNeeded];
			}
		}

		if ( (i > 0) || ((i == 0) && firstLine) ) {
			[csvRow setArray:[array objectAtIndex:i]];
			for ( j = 0 ; j < [csvRow count] ; j++ ) {
				[csvCell setString:[[csvRow objectAtIndex:j] description]];

				// Set NULL values to an empty string
				if ( [csvCell isEqualToString:nullString] ) {
					[csvRow replaceObjectAtIndex:j withObject:@""];

				// Add empty strings as a pair of enclosing characters only
				} else if ( [csvCell length] == 0 ) {
					[enclosedCsvCell setString:enclosingString];
					[enclosedCsvCell appendString:enclosingString];

				} else {
					
					// Test whether this cell contains a number
					csvNumericTester = [NSScanner scannerWithString:csvCell];
					csvCellIsNumeric = [csvNumericTester scanFloat:nil] && [csvNumericTester isAtEnd];
					if (csvCellIsNumeric && [csvCell length] > 20) {
						NSLog(csvCell);
						float testFloat;
						NSScanner *test = [NSScanner scannerWithString:csvCell];
						[test scanFloat:&testFloat];
						NSLog(@"Gives value: %f, scanner at end: %i", testFloat, [test isAtEnd] == YES);
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

					// If the string isn't quoted or otherwise enclosed, escape occurrences of the
					// field separators and the line ending separator.
					if ( quoteFieldSeparators || csvCellIsNumeric ) {
						[csvCell replaceOccurrencesOfString:fieldSeparatorString
									withString:escapedFieldSeparatorString
									options:NSLiteralSearch
									range:NSMakeRange(0,[csvCell length])];
						[csvCell replaceOccurrencesOfString:lineEndString
									withString:escapedLineEndString
									options:NSLiteralSearch
									range:NSMakeRange(0,[csvCell length])];
					}

					// Update the string in the row array using a mutable string which has each part
					// appended to it; this is significantly faster than stringWithFormat.
					if (csvCellIsNumeric) {
						[enclosedCsvCell setString:csvCell];
					} else {
						[enclosedCsvCell setString:enclosingString];
						[enclosedCsvCell appendString:csvCell];
						[enclosedCsvCell appendString:enclosingString];
					}
					[csvRow replaceObjectAtIndex:j withObject:[NSString stringWithString:enclosedCsvCell]];
				}
				
			}

			// Construct the string for this row
			[csvRowString setString:[csvRow componentsJoinedByString:fieldSeparatorString]];

			// Add it to the CSV array
			[csvData addObject:[NSString stringWithString:csvRowString]];
		}
	}
	
	// Add a trailing line end symbol
	[csvData addObject:lineEndString];

	// Close the progress sheet if it's present
	if ( !silently ) {
		[NSApp endSheet:singleProgressSheet];
		[singleProgressSheet orderOut:nil];
	}

	return [NSString stringWithString:[csvData componentsJoinedByString:lineEndString]];
}

- (NSArray *)arrayForCSV:(NSString *)csv terminatedBy:(NSString *)terminated
	enclosedBy:(NSString *)enclosed escapedBy:(NSString *)escaped lineEnds:(NSString *)lineEnds
/*
loads a csv string into an array
*/
{
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
	while ( ![scanner isAtEnd] ) {
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
		//add line to array
		[linesArray addObject:[NSString stringWithString:tempString]];
	}
	for ( x = 0 ; x < [linesArray count] ; x++ ) {
	//separate fields
		[tempRowArray removeAllObjects];
		[tempRowArray addObjectsFromArray:[self arrayForString:[linesArray objectAtIndex:x] enclosed:enclosed escaped:escaped terminated:terminated]];
		if ( x == 0 ) {
			fieldCount = [tempRowArray count];
		} else {
			while ( [tempRowArray count] < fieldCount ) {
				[tempRowArray addObject:@"NULL"];
			}
		}
		for ( i = 0 ; i < [tempRowArray count] ; i++ ) {
			if ( [[tempRowArray objectAtIndex:i] isEqualToString:@"NULL"] || [[tempRowArray objectAtIndex:i] isEqualToString:@"\\N"] || [[tempRowArray objectAtIndex:i] isEqualToString:[prefs objectForKey:@"nullValue"]] ) {
	//put nsnull object to array if field contains un-enclosed NULL string
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
	}
	
	return [NSArray arrayWithArray:tempArray];
}


- (NSString *)xmlForArray:(NSArray *)array tableName:(NSString *)table withHeader:(BOOL)header silently:(BOOL)silently
/*
takes an array and returns it as a xml string
*/
{
	NSMutableString *string = [NSMutableString string];
	int i,j;

	if ( !silently ) {
		//reset interface
		[singleProgressText setStringValue:NSLocalizedString(@"Writing...", @"text showing that app is writing text file")];
		[singleProgressText displayIfNeeded];
		[singleProgressBar setDoubleValue:0];
		[singleProgressBar displayIfNeeded];
		//open progress sheet
		[NSApp beginSheet:singleProgressSheet
				modalForWindow:tableWindow modalDelegate:self
				didEndSelector:nil contextInfo:nil];
	}

	if ( header ) {
//add header
		[string appendString:@"<?xml version=\"1.0\"?>\n\n"];
		[string appendString:@"<!--\n-\n"];
		[string appendString:@"- Sequel Pro dump\n"];
		[string appendString:[NSString stringWithFormat:@"- Version %@\n",
							[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
		[string appendString:@"- http://code.google.com/p/sequel-pro\n-\n"];
		[string appendString:[NSString stringWithFormat:@"- Host: %@ (MySQL %@)\n",
							[tableDocumentInstance host], [tableDocumentInstance mySQLVersion]]];
		[string appendString:[NSString stringWithFormat:@"- Database: %@\n", [tableDocumentInstance database]]];
		[string appendString:[NSString stringWithFormat:@"- Generation Time: %@\n", [NSDate date]]];
		[string appendString:@"-\n-->\n\n"];
	}
//add table name
	[string appendString:[NSString stringWithFormat:@"\t<%@>\n", [self htmlEscapeString:table]]];
	
	for ( i = 1 ; i < [array count] ; i++ ) {
		if ( !silently ) {
			[singleProgressBar setDoubleValue:((i+1)*100/[array count])];
			[singleProgressBar displayIfNeeded];
		}
//add rows
		[string appendString:@"\t<row>\n"];
		for ( j = 0 ; j < [[array objectAtIndex:i] count] ; j++ ) {
		   [string appendString:[NSString stringWithFormat:@"\t\t<%@>%@</%@>\n",
									[self htmlEscapeString:[[[array objectAtIndex:0] objectAtIndex:j] description]],
									[self htmlEscapeString:[[[array objectAtIndex:i] objectAtIndex:j] description]],
									[self htmlEscapeString:[[[array objectAtIndex:0] objectAtIndex:j] description]]]];
		}
		[string appendString:@"\t</row>\n"];
	}
//end table name
	[string appendString:[NSString stringWithFormat:@"\t</%@>", [self htmlEscapeString:table]]];
	
	if ( !silently ) {
		//close progress sheet
		[NSApp endSheet:singleProgressSheet];
		[singleProgressSheet orderOut:nil];
	}
	
	return [NSString stringWithString:string];
}

- (NSString *)stringForSelectedTablesWithType:(NSString *)type
/*
returns a csv/xml string for the selected tables
type has to be "csv" or "xml"
*/
{
	int i,j,k,t,rowCount,tableCount;
	CMMCPResult *queryResult;
	NSString *tableName;
	NSArray *fieldNames;
	NSArray *theRow;
	NSMutableArray *tableArray = [NSMutableArray array];
	NSMutableString *rowValue = [NSMutableString string];
	NSMutableArray *fieldValues;
	NSMutableString *dump = [NSMutableString string];
	NSMutableString *errors = [NSMutableString string];

//reset interface
	[errorsView setString:@""];
	[errorsView displayIfNeeded];
	[singleProgressText setStringValue:NSLocalizedString(@"Writing...", @"text showing that app is writing text file")];
	[singleProgressText displayIfNeeded];
	[singleProgressBar setDoubleValue:0];
	[singleProgressBar displayIfNeeded];

//open progress sheet
	[NSApp beginSheet:singleProgressSheet
			modalForWindow:tableWindow modalDelegate:self
			didEndSelector:nil contextInfo:nil];

//count tables
	tableCount = 0;
	for ( i = 0 ; i < [tables count] ; i++ ) {
		if ( [[[tables objectAtIndex:i] objectAtIndex:0] boolValue] ) {
			tableCount++;
		}
	}
	k = 0;

//add header of dump-file
	if ( [type isEqualToString:@"csv"] ) {
		[dump appendString:[NSString stringWithFormat:@"Host: %@   Database: %@   Generation Time: %@\n\n",
			[tableDocumentInstance host], [tableDocumentInstance database], [NSDate date]]];
	} else if ( [type isEqualToString:@"xml"] ) {
		[dump appendString:@"<?xml version=\"1.0\"?>\n\n"];
		[dump appendString:@"<!--\n-\n"];
		[dump appendString:@"- Sequel Pro dump\n"];
		[dump appendString:[NSString stringWithFormat:@"- Version %@\n",
							[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
		[dump appendString:@"- http://code.google.com/p/sequel-pro\n-\n"];
		[dump appendString:[NSString stringWithFormat:@"- Host: %@ (MySQL %@)\n",
							[tableDocumentInstance host], [tableDocumentInstance mySQLVersion]]];
		[dump appendString:[NSString stringWithFormat:@"- Database: %@\n", [tableDocumentInstance database]]];
		[dump appendString:[NSString stringWithFormat:@"- Generation Time: %@\n", [NSDate date]]];
		[dump appendString:@"-\n-->\n\n\n"];
		[dump appendString:[NSString stringWithFormat:@"<%@>\n\n\n",
								[self htmlEscapeString:[tableDocumentInstance database]]]];
	}
	for ( i = 0 ; i < [tables count] ; i++ ) {
		if ( [[[tables objectAtIndex:i] objectAtIndex:0] boolValue] ) {
			k++;
//set progressbar and text
			tableName = [[tables objectAtIndex:i] objectAtIndex:1];
			[singleProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Writing table %@...", @"text showing that app is writing table to text file"), tableName]];
			[singleProgressText displayIfNeeded];
//add name of table
			if ( [type isEqualToString:@"csv"] ) {
				[dump appendString:[NSString stringWithFormat:@"Table %@\n\n", tableName]];
			}
//add table content
			queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT * FROM `%@`", tableName]];
			fieldNames = [queryResult fetchFieldNames];
			rowCount = [queryResult numOfRows];
			[tableArray removeAllObjects];
			//add field names
			[tableArray addObject:fieldNames];
			for ( j = 0 ; j < rowCount ; j++ ) {
				[queryResult dataSeek:j];
				theRow = [queryResult fetchRowAsArray];
				fieldValues = [NSMutableArray array];
				for ( t = 0 ; t < [theRow count] ; t++ ) {
					if ( [[theRow objectAtIndex:t] isKindOfClass:[NSData class]] ) {
						//convert data to string
						[rowValue setString:[[NSString alloc] initWithData:[theRow objectAtIndex:t]
								encoding:[mySQLConnection encoding]]];
					} else if ( [[theRow objectAtIndex:t] isMemberOfClass:[NSNull class]] ) {
						[rowValue setString:[prefs objectForKey:@"nullValue"]];
					} else {
						[rowValue setString:[[theRow objectAtIndex:t] description]];
					}
					[fieldValues addObject:[NSString stringWithString:rowValue]];
				}
				[tableArray addObject:[NSArray arrayWithArray:fieldValues]];
			}
			if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
				[errors appendString:[NSString stringWithFormat:@"%@\n", [mySQLConnection getLastErrorMessage]]];
			}
			if ( [type isEqualToString:@"csv"] ) {
				[dump appendString:[self csvForArray:tableArray
										useFirstLine:[exportMultipleFieldNamesSwitch state]
										terminatedBy:[exportMultipleFieldsTerminatedField stringValue]
										enclosedBy:[exportMultipleFieldsEnclosedField stringValue]
										escapedBy:[exportMultipleFieldsEscapedField stringValue]
										lineEnds:[exportMultipleLinesTerminatedField stringValue]
										silently:YES]];
			} else if ( [type isEqualToString:@"xml"] ) {
				[dump appendString:[self xmlForArray:tableArray tableName:tableName withHeader:NO silently:YES]];
			}
//set progressbar and text
			[singleProgressBar setDoubleValue:(k*100/tableCount)];
			[singleProgressBar displayIfNeeded];
			[dump appendString:@"\n\n\n"];
		}
	}

//write xml end
	if ( [type isEqualToString:@"xml"] ) {
		[dump appendString:[NSString stringWithFormat:@"</%@>",
								[self htmlEscapeString:[tableDocumentInstance database]]]];
	}

//close progress sheet
	[NSApp endSheet:singleProgressSheet];
	[singleProgressSheet orderOut:nil];
	
//show errors sheet if there have been errors
	if ( [errors length] ) {
		[errorsView setString:errors];
		[NSApp beginSheet:errorsSheet
				modalForWindow:tableWindow modalDelegate:self
				didEndSelector:nil contextInfo:nil];
		[NSApp runModalForWindow:errorsSheet];
		
		[NSApp endSheet:errorsSheet];
		[errorsSheet orderOut:nil];
	}

	return [NSString stringWithString:dump];
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

- (NSArray *)splitQueries:(NSString *)query
/*
splits the queries by ;'s which aren't inside any ", ' or ` characters
*/
{
	NSMutableString *queries = [NSMutableString stringWithString:query];
	NSMutableArray *queryArray = [NSMutableArray array];
	char stringType = nil;
	BOOL inString = NO;
	BOOL escaped;
	unsigned lineStart = 0;
	unsigned i, j, x, currentLineLength;
	
	//parse string
	for ( i = 0 ; i < [queries length] ; i++ ) {
		if ( inString ) {
		//we are in a string
			//look for end of string
			for ( ; i < [queries length] ; i++ ) {
				if ( (([queries characterAtIndex:i] == '`') && (stringType == '`')) ||
						(([queries characterAtIndex:i] == stringType) && ([queries characterAtIndex:i-1] != '\\')) ) {
				//back-tick or no backslash before string end -> end of string
					inString = NO;
					break;
				} else if ( [queries characterAtIndex:i] == stringType ) {
				//check if string end isn't escaped
					escaped = YES;
					j = 2;
					currentLineLength = i - lineStart;
					while ( ((currentLineLength-j)>0) && ([queries characterAtIndex:i-j] == '\\') ) {
						escaped = !escaped;
						j++;
					}
					if ( !escaped ) {
					//it's really the end of the string
						inString = NO;
					}
				}
			}
		} else if ( ([queries characterAtIndex:i] == '#') || 
						((i+2<[queries length]) &&
						([queries characterAtIndex:i] == '-') &&
						([queries characterAtIndex:i+1] == '-') &&
						([queries characterAtIndex:i+2] == ' ')) ) {
		//it's a comment -> delete it
			x = i;
			while ( (x<[queries length]) && ([queries characterAtIndex:x] != '\r') && ([queries characterAtIndex:x] != '\n') ) {
				x++;
			}
			[queries deleteCharactersInRange:NSMakeRange(i,x-i)];
		} else if ( [queries characterAtIndex:i] == ';' ) {
		//we are at the end of a query
			[queryArray addObject:[queries substringWithRange:NSMakeRange(lineStart, (i-lineStart))]];
			while ( ((i+1)<[queries length]) && (([queries characterAtIndex:i+1]=='\n') || ([queries characterAtIndex:i+1]=='\r') || ([queries characterAtIndex:i+1]==' ')) ) {
				i++;
			}
			lineStart = i + 1;
		} else if ( ([queries characterAtIndex:i] == '\'') ||
						([queries characterAtIndex:i] == '"') ||
						([queries characterAtIndex:i] == '`') ) {
		//we are entering a string
			inString = YES;
			stringType = [queries characterAtIndex:i];
		}
	}
	//add rest of string to array (if last line has not ended with a ";")
	if ( lineStart < [queries length] ) {
		[queryArray addObject:[queries substringWithRange:NSMakeRange(lineStart, ([queries length]-lineStart))]];
	}
	//return array
	return [NSArray arrayWithArray:queryArray];
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

//tableView datasource methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
{
	if ( aTableView == fieldMappingTableView ) {
		return [fieldMappingArray count];
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
	if ( aTableView == fieldMappingTableView ) {
		return [[fieldMappingArray objectAtIndex:rowIndex] objectAtIndex:[[aTableColumn identifier] intValue]];
	} else {
		if ( [[aTableColumn identifier] isEqualToString:@"switch"] ) {
			return [[tables objectAtIndex:rowIndex] objectAtIndex:0];
		} else {
			return [[tables objectAtIndex:rowIndex] objectAtIndex:1];
		}
	}
}

- (void)tableView:(NSTableView *)aTableView
			setObjectValue:(id)anObject
			forTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	if ( aTableView == fieldMappingTableView ) {
		int i;
		for ( i = 0 ; i < [fieldMappingArray count] ; i++ ) {
		//check that field isn't already used
			if ( [[[fieldMappingArray objectAtIndex:i] objectAtIndex:1] isEqualToNumber:anObject]
					&& (rowIndex != i)
					&& ![anObject isEqualToNumber:[NSNumber numberWithInt:0]] ) {
				return;
			}
		}
		[[fieldMappingArray objectAtIndex:rowIndex] replaceObjectAtIndex:[[aTableColumn identifier] intValue] withObject:anObject];
	} else {
		[[tables objectAtIndex:rowIndex] replaceObjectAtIndex:0 withObject:anObject];
	}
}


//last but not least
- (id)init;
{
	self = [super init];

	tables = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
//	NSLog(@"TableDump dealloc");

	[tables release];
	[importArray release];
	[fieldMappingArray release];
	[savePath release];
	[openPath release];
	[prefs release];   
	
	[super dealloc];
}


@end

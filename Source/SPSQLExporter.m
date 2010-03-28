//
//  $Id$
//
//  SPSQLExporter.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on August 29, 2009
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import <MCPKit/MCPKit.h>

#import "SPSQLExporter.h"
#import "TablesList.h"
#import "SPConstants.h"
#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"

@implementation SPSQLExporter

@synthesize sqlExportTables;

@synthesize sqlDatabaseHost;
@synthesize sqlDatabaseName;
@synthesize sqlDatabaseVersion;

@synthesize sqlOutputIncludeUTF8BOM;
@synthesize sqlOutputIncludeStructure;
@synthesize sqlOutputIncludeCreateSyntax;
@synthesize sqlOutputIncludeDropSyntax;
@synthesize sqlOutputIncludeErrors;

/**
 * Start the SQL data conversion process. This method is automatically called when an instance of this object
 * is placed on an NSOperationQueue. Do not call it directly as there is no manual multithreading.
 */
- (void)main
{
	@try {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		NSInteger i,j,t,rowCount, colCount, lastProgressValue, queryLength;
		NSInteger progressBarWidth;
		SPTableType tableType = SPTableTypeTable;
		MCPResult *queryResult;
		MCPStreamingResult *streamingResult;
		NSAutoreleasePool *exportAutoReleasePool = nil;
		NSString *tableName, *tableColumnTypeGrouping, *previousConnectionEncoding;
		NSArray *fieldNames;
		NSArray *theRow;
		NSMutableArray *selectedTables = [NSMutableArray array];
		NSMutableArray *selectedProcs = [NSMutableArray array];
		NSMutableArray *selectedFuncs = [NSMutableArray array];
		NSMutableDictionary *viewSyntaxes = [NSMutableDictionary dictionary];
		NSMutableString *metaString = [NSMutableString string];
		NSMutableString *cellValue = [NSMutableString string];
		NSMutableString *sqlString = [[NSMutableString alloc] init];
		NSMutableString *errors = [NSMutableString string];
		NSDictionary *tableDetails;
		NSMutableArray *tableColumnNumericStatus;
		NSEnumerator *viewSyntaxEnumerator;
		id createTableSyntax = nil;
		BOOL previousConnectionEncodingViaLatin1;
		
		// Reset the interface
		/*[errorsView setString:@""];
		[[singleProgressTitle onMainThread] setStringValue:NSLocalizedString(@"Exporting SQL", @"text showing that the application is exporting SQL")];
		[[singleProgressText onMainThread] setStringValue:NSLocalizedString(@"Dumping...", @"text showing that app is writing dump")];
		[[singleProgressBar onMainThread] setDoubleValue:0];
		progressBarWidth = (NSInteger)[singleProgressBar bounds].size.width;
		[[singleProgressBar onMainThread] setMaxValue:progressBarWidth];
		
		// Open the progress sheet
		[[NSApp onMainThread] beginSheet:singleProgressSheet
						  modalForWindow:tableWindow modalDelegate:self
						  didEndSelector:nil contextInfo:nil];
		[[singleProgressSheet onMainThread] makeKeyWindow];
		
		[tableDocumentInstance setQueryMode:SPImportExportQueryMode];*/
		
		// Copy over the selected item names into tables in preparation for iteration
		NSMutableArray *targetArray;
		
		for (i = 0 ; i <[[self sqlExportTables] count]; i++) 
		{
			if ([NSArrayObjectAtIndex(NSArrayObjectAtIndex([self sqlExportTables], i), 0) boolValue]) {
				switch ([NSArrayObjectAtIndex(NSArrayObjectAtIndex([self sqlExportTables], i), 2) intValue]) {
					case SPTableTypeProc:
						targetArray = selectedProcs;
						break;
					case SPTableTypeFunc:
						targetArray = selectedFuncs;
						break;
					default:
						targetArray = selectedTables;
						break;
				}
				
				[targetArray addObject:[NSString stringWithString:NSArrayObjectAtIndex(NSArrayObjectAtIndex([self sqlExportTables], i), 1)]];
			}
		}
		
		
		// If required write the UTF-8 Byte Order Mark
		[metaString setString:([self sqlOutputIncludeUTF8BOM]) ? @"" : @"\xef\xbb\xbf"];
		
		// Add the dump header to the dump file
		[metaString appendString:@"# ************************************************************\n"];
		[metaString appendString:@"# Sequel Pro SQL dump\n"];
		[metaString appendString:[NSString stringWithFormat:@"# Version %@\n", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
		[metaString appendString:[NSString stringWithFormat:@"# %@\n#\n", SPDevURL]];
		[metaString appendString:[NSString stringWithFormat:@"# Host: %@ (MySQL %@)\n", [self sqlDatabaseHost], [self sqlDatabaseVersion]]];
		[metaString appendString:[NSString stringWithFormat:@"# Database: %@\n", [self sqlDatabaseName]]];
		[metaString appendString:[NSString stringWithFormat:@"# Generation Time: %@\n", [NSDate date]]];
		[metaString appendString:@"# ************************************************************\n\n"];
		
		// Add commands to store the client encodings used when importing and set to UTF8 to preserve data
		[metaString appendString:@"/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;\n"];
		[metaString appendString:@"/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;\n"];
		[metaString appendString:@"/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;\n"];
		[metaString appendString:@"/*!40101 SET NAMES utf8 */;\n"];
		
		// Add commands to store and disable unique checks, foreign key checks, mode and notes where supported.
		// Include trailing semicolons to ensure they're run individually. Use MySQL-version based comments.
		if ([self sqlOutputIncludeDropSyntax]) {
			[metaString appendString:@"/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;\n"];
		}
		
		[metaString appendString:@"/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;\n"];
		[metaString appendString:@"/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;\n"];
		[metaString appendString:@"/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;\n\n\n"];
		
		[[self exportOutputFileHandle] writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
		
		// Store the current connection encoding so it can be restored after the dump.
		previousConnectionEncoding = [[NSString alloc] initWithString:[tableDocumentInstance connectionEncoding]];
		previousConnectionEncodingViaLatin1 = [tableDocumentInstance connectionEncodingViaLatin1:nil];
		
		// Set the connection to UTF8 to be able to export correctly.
		[tableDocumentInstance setConnectionEncoding:@"utf8" reloadingViews:NO];
		
		// Loop through the selected tables
		for ( i = 0 ; i < [selectedTables count] ; i++ ) {
			if (progressCancelled) break;
			lastProgressValue = 0;
			
			// Update the progress text and reset the progress bar to indeterminate status while fetching data
			tableName = NSArrayObjectAtIndex(selectedTables, i);
			/*[[singleProgressText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %ld of %lu (%@): Fetching data...", @"text showing that app is fetching data for table dump"), (long)(i+1), (unsigned long)[selectedTables count], tableName]];
			[[singleProgressText onMainThread] displayIfNeeded];
			[[singleProgressBar onMainThread] setIndeterminate:YES];
			[[singleProgressBar onMainThread] setUsesThreadedAnimation:YES];
			[[singleProgressBar onMainThread] startAnimation:self];*/
			
			// Add the name of table
			[[self exportOutputFileHandle]] writeData:[[NSString stringWithFormat:@"# Dump of table %@\n# ------------------------------------------------------------\n\n", tableName] dataUsingEncoding:NSUTF8StringEncoding]];
			
			
			// Determine whether this table is a table or a view via the create table command, and keep the create table syntax
			queryResult = [connection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE %@", [tableName backtickQuotedString]]];
			[queryResult setReturnDataAsStrings:YES];
			if ( [queryResult numOfRows] ) {
				tableDetails = [[NSDictionary alloc] initWithDictionary:[queryResult fetchRowAsDictionary]];
				if ([tableDetails objectForKey:@"Create View"]) {
					[viewSyntaxes setValue:[[[[tableDetails objectForKey:@"Create View"] copy] autorelease] createViewSyntaxPrettifier] forKey:tableName];
					createTableSyntax = [self createViewPlaceholderSyntaxForView:tableName];
					tableType = SPTableTypeView;
				} else {
					createTableSyntax = [[[tableDetails objectForKey:@"Create Table"] copy] autorelease];
					tableType = SPTableTypeTable;
				}
				[tableDetails release];
			}
			if (![[connection getLastErrorMessage] isEqualToString:@""] ) {
				[errors appendString:[NSString stringWithFormat:@"%@\n", [connection getLastErrorMessage]]];
				
				if ([self sqlOutputIncludeErrors]) {
					[[self exportOutputFileHandle] writeData:[[NSString stringWithFormat:@"# Error: %@\n", [connection getLastErrorMessage]] dataUsingEncoding:NSUTF8StringEncoding]];
				}
			}
			
			
			// Add a "drop table" command if specified in the export dialog
			if ([self sqlOutputIncludeDropSyntax])
				[[self exportOutputFileHandle] writeData:[[NSString stringWithFormat:@"DROP %@ IF EXISTS %@;\n\n", ((tableType == SPTableTypeTable)?@"TABLE":@"VIEW"), [tableName backtickQuotedString]]
									   dataUsingEncoding:NSUTF8StringEncoding]];
			
			
			// Add the create syntax for the table if specified in the export dialog
			if ( [addCreateTableSwitch state] == NSOnState && createTableSyntax) {
				if ( [createTableSyntax isKindOfClass:[NSData class]] ) {
					createTableSyntax = [[[NSString alloc] initWithData:createTableSyntax encoding:connectionEncoding] autorelease];
				}
				[[self exportOutputFileHandle] writeData:[createTableSyntax dataUsingEncoding:NSUTF8StringEncoding]];
				[[self exportOutputFileHandle] writeData:[[NSString stringWithString:@";\n\n"] dataUsingEncoding:NSUTF8StringEncoding]];
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
				rowCount = [[[[connection queryString:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@", [tableName backtickQuotedString]]] fetchRowAsArray] objectAtIndex:0] integerValue];
				
				// Set up a result set in streaming mode
				streamingResult = [[connection streamingQueryString:[NSString stringWithFormat:@"SELECT * FROM %@", [tableName backtickQuotedString]] useLowMemoryBlockingStreaming:([sqlFullStreamingSwitch state] == NSOnState)] retain];
				fieldNames = [streamingResult fetchFieldNames];
				
				// Update the progress text and set the progress bar back to determinate
				/*[[singleProgressText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %ld of %lu (%@): Dumping...", @"text showing that app is writing data for table dump"), (long)(i+1), (unsigned long)[selectedTables count], tableName]];
				[[singleProgressBar onMainThread] stopAnimation:self];
				[[singleProgressBar onMainThread] setIndeterminate:NO];
				[[singleProgressBar onMainThread] setDoubleValue:0];*/
				
				if (rowCount) {
					queryLength = 0;
					
					// Lock the table for writing and disable keys if supported
					[metaString setString:@""];
					[metaString appendString:[NSString stringWithFormat:@"LOCK TABLES %@ WRITE;\n", [tableName backtickQuotedString]]];
					[metaString appendString:[NSString stringWithFormat:@"/*!40000 ALTER TABLE %@ DISABLE KEYS */;\n", [tableName backtickQuotedString]]];
					[[self exportOutputFileHandle] writeData:[metaString dataUsingEncoding:connectionEncoding]];
					
					// Construct the start of the insertion command
					[[self exportOutputFileHandle] writeData:[[NSString stringWithFormat:@"INSERT INTO %@ (%@)\nVALUES\n\t(",
											[tableName backtickQuotedString], [fieldNames componentsJoinedAndBacktickQuoted]] dataUsingEncoding:NSUTF8StringEncoding]];
					
					// Iterate through the rows to construct a VALUES group for each
					j = 0;
					exportAutoReleasePool = [[NSAutoreleasePool alloc] init];
					while (theRow = [streamingResult fetchNextRowAsArray]) {
						if (progressCancelled) {
							[connection cancelCurrentQuery];
							[streamingResult cancelResultLoad];
							break;
						}
						j++;
						[sqlString setString:@""];
						
						// Update the progress bar
						if ((j*progressBarWidth/rowCount) > lastProgressValue) {
							[singleProgressBar setDoubleValue:(j*progressBarWidth/rowCount)];
							lastProgressValue = (j*progressBarWidth/rowCount);
						}
						
						
						for ( t = 0 ; t < colCount ; t++ ) {
							
							// Add NULL values directly to the output row
							if ( [[theRow objectAtIndex:t] isMemberOfClass:[NSNull class]] ) {
								[sqlString appendString:@"NULL"];
								
								// Add data types directly as hex data
							} else if ( [[theRow objectAtIndex:t] isKindOfClass:[NSData class]] ) {
								[sqlString appendString:@"X'"];
								[sqlString appendString:[connection prepareBinaryData:[theRow objectAtIndex:t]]];
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
										[sqlString appendString:[connection prepareString:cellValue]];
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
						[[self exportOutputFileHandle] writeData:[sqlString dataUsingEncoding:NSUTF8StringEncoding]];
					}
					
					// Complete the command
					[[self exportOutputFileHandle] writeData:[[NSString stringWithString:@";\n\n"] dataUsingEncoding:NSUTF8StringEncoding]];
					
					// Unlock the table and re-enable keys if supported
					[metaString setString:@""];
					[metaString appendString:[NSString stringWithFormat:@"/*!40000 ALTER TABLE %@ ENABLE KEYS */;\n", [tableName backtickQuotedString]]];
					[metaString appendString:@"UNLOCK TABLES;\n"];
					[[self exportOutputFileHandle] writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
					
					// Drain the autorelease pool
					[exportAutoReleasePool drain];
				}
				
				if ( ![[connection getLastErrorMessage] isEqualToString:@""] ) {
					[errors appendString:[NSString stringWithFormat:@"%@\n", [connection getLastErrorMessage]]];
					
					if ([self sqlOutputIncludeErrors]) {
						[[self exportOutputFileHandle] writeData:[[NSString stringWithFormat:@"# Error: %@\n", [connection getLastErrorMessage]]
											   dataUsingEncoding:NSUTF8StringEncoding]];
					}
				}
				
				// Release the result set
				[streamingResult release];
				
				queryResult = [connection queryString:[NSString stringWithFormat:@"/*!50003 SHOW TRIGGERS WHERE `Table` = %@ */;", 
															[tableName tickQuotedString]]];
				[queryResult setReturnDataAsStrings:YES];
				if ( [queryResult numOfRows] ) {
					[metaString setString:@"\n"];
					[metaString appendString:@"DELIMITER ;;\n"];
					
					for (int s=0; s<[queryResult numOfRows]; s++) {
						NSDictionary *triggers = [[NSDictionary alloc] initWithDictionary:[queryResult fetchRowAsDictionary]];
						
						//Definer is user@host but we need to escape it to `user`@`host`
						NSArray *triggersDefiner = [[triggers objectForKey:@"Definer"] componentsSeparatedByString:@"@"];
						NSString *escapedDefiner = [NSString stringWithFormat:@"%@@%@", 
													[[triggersDefiner objectAtIndex:0] backtickQuotedString],
													[[triggersDefiner objectAtIndex:1] backtickQuotedString]
													];
						
						[metaString appendString:[NSString stringWithFormat:@"/*!50003 SET SESSION SQL_MODE=\"%@\" */;;\n", 
												  [triggers objectForKey:@"sql_mode"]]];
						[metaString appendString:@"/*!50003 CREATE */ "];
						[metaString appendString:[NSString stringWithFormat:@"/*!50017 DEFINER=%@ */ ", 
												  escapedDefiner]];
						[metaString appendString:[NSString stringWithFormat:@"/*!50003 TRIGGER %@ %@ %@ ON %@ FOR EACH ROW %@ */;;\n",
												  [[triggers objectForKey:@"Trigger"] backtickQuotedString],
												  [triggers objectForKey:@"Timing"],
												  [triggers objectForKey:@"Event"],
												  [[triggers objectForKey:@"Table"] backtickQuotedString],
												  [triggers objectForKey:@"Statement"]
												  ]];
						[triggers release];
					}
					
					[metaString appendString:@"DELIMITER ;\n"];
					[metaString appendString:@"/*!50003 SET SESSION SQL_MODE=@OLD_SQL_MODE */;\n"];
					[[self exportOutputFileHandle] writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
				}
				
				if ( ![[connection getLastErrorMessage] isEqualToString:@""] ) {
					[errors appendString:[NSString stringWithFormat:@"%@\n", [connection getLastErrorMessage]]];
					
					if ([self sqlOutputIncludeErrors]) {
						[[self exportOutputFileHandle] writeData:[[NSString stringWithFormat:@"# Error: %@\n", [connection getLastErrorMessage]]
											   dataUsingEncoding:NSUTF8StringEncoding]];
					}
				}
				
			}
			
			// Add an additional separator between tables
			[[self exportOutputFileHandle] writeData:[[NSString stringWithString:@"\n\n"] dataUsingEncoding:NSUTF8StringEncoding]];
		}
		
		// Process any deferred views, adding commands to delete the placeholder tables and add the actual views
		viewSyntaxEnumerator = [viewSyntaxes keyEnumerator];
		while (tableName = [viewSyntaxEnumerator nextObject]) {
			[metaString setString:@"\n\n"];
			[metaString appendFormat:@"DROP TABLE %@;\n", [tableName backtickQuotedString]];
			[metaString appendFormat:@"%@;\n", [viewSyntaxes objectForKey:tableName]];
			[[self exportOutputFileHandle] writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
		}
		
		// Export procedures and functions
		for (NSString *procedureType in [NSArray arrayWithObjects:@"PROCEDURE", @"FUNCTION", nil]) {
			
			// Retrieve the array of selected procedures or functions, and skip export if not selected
			NSMutableArray *selectedItems;
			if ([procedureType isEqualToString:@"PROCEDURE"]) selectedItems = selectedProcs;
			else selectedItems = selectedFuncs;
			if (![selectedItems count]) continue;
			
			// Retrieve the definitions
			queryResult = [connection queryString:[NSString stringWithFormat:@"/*!50003 SHOW %@ STATUS WHERE `Db` = %@ */;",
														procedureType,
														[[tableDocumentInstance database] tickQuotedString]]];
			[queryResult setReturnDataAsStrings:YES];
			if ( [queryResult numOfRows] ) {
				[metaString setString:@"\n"];
				[metaString appendString:@"--\n"];
				[metaString appendString:[NSString stringWithFormat:@"-- Dumping routines (%@) for database %@\n",
										  procedureType,
										  [[tableDocumentInstance database] tickQuotedString]]];
				[metaString appendString:@"--\n"];
				[metaString appendString:@"DELIMITER ;;\n"];
				
				// Loop through the definitions, exporting if enabled
				for (int s=0; s<[queryResult numOfRows]; s++) {
					NSDictionary *proceduresList = [[NSDictionary alloc] initWithDictionary:[queryResult fetchRowAsDictionary]];
					NSString *procedureName = [NSString stringWithFormat:@"%@", [proceduresList objectForKey:@"Name"]];
					
					// Only proceed if the item was selected for export
					if (![selectedItems containsObject:procedureName]) {
						[proceduresList release];
						continue;
					}
					
					// Add the "drop" command if specified in the export dialog
					if ([self sqlOutputIncludeDropSyntax]) {
						[metaString appendString:[NSString stringWithFormat:@"/*!50003 DROP %@ IF EXISTS %@ */;;\n", 
												  procedureType,
												  [procedureName backtickQuotedString]]];
					}
					
					// Only continue if the "create syntax" is specified in the export dialog
					if ([self sqlOutputIncludeCreateSyntax]) {
						[proceduresList release];
						continue;
					}
					
					//Definer is user@host but we need to escape it to `user`@`host`
					NSArray *procedureDefiner = [[proceduresList objectForKey:@"Definer"] componentsSeparatedByString:@"@"];
					NSString *escapedDefiner = [NSString stringWithFormat:@"%@@%@", 
												[[procedureDefiner objectAtIndex:0] backtickQuotedString],
												[[procedureDefiner objectAtIndex:1] backtickQuotedString]
												];
					
					MCPResult *createProcedureResult;
					createProcedureResult = [connection queryString:[NSString stringWithFormat:@"/*!50003 SHOW CREATE %@ %@ */;;", 
																		  procedureType,
																		  [procedureName backtickQuotedString]]];
					[createProcedureResult setReturnDataAsStrings:YES];
					NSDictionary *procedureInfo = [[NSDictionary alloc] initWithDictionary:[createProcedureResult fetchRowAsDictionary]];
					
					[metaString appendString:[NSString stringWithFormat:@"/*!50003 SET SESSION SQL_MODE=\"%@\"*/;;\n", 
											  [procedureInfo objectForKey:@"sql_mode"]]];
					
					NSString *createProcedure = [procedureInfo objectForKey:[NSString stringWithFormat:@"Create %@", [procedureType capitalizedString]]];			
					NSRange procedureRange = [createProcedure rangeOfString:procedureType options:NSCaseInsensitiveSearch];
					NSString *procedureBody = [createProcedure substringFromIndex:procedureRange.location];
					
					// /*!50003 CREATE*/ /*!50020 DEFINER=`sequelpro`@`%`*/ /*!50003 PROCEDURE `p`()
					// 													  BEGIN
					// 													  /* This procedure does nothing */
					// END */;;
					//Build the CREATE PROCEDURE string to include MySQL Version limiters
					[metaString appendString:[NSString stringWithFormat:@"/*!50003 CREATE*/ /*!50020 DEFINER=%@*/ /*!50003 %@ */;;\n",
											  escapedDefiner,
											  procedureBody]];
					
					[procedureInfo release];
					[proceduresList release];
					
					[metaString appendString:@"/*!50003 SET SESSION SQL_MODE=@OLD_SQL_MODE */;;\n"];
				}
				
				[metaString appendString:@"DELIMITER ;\n"];
				[[self exportOutputFileHandle] writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
			}
			
			if ( ![[connection getLastErrorMessage] isEqualToString:@""] ) {
				[errors appendString:[NSString stringWithFormat:@"%@\n", [connection getLastErrorMessage]]];
				
				if ([self sqlOutputIncludeErrors]) {
					[[self exportOutputFileHandle] writeData:[[NSString stringWithFormat:@"# Error: %@\n", [connection getLastErrorMessage]]
										   dataUsingEncoding:NSUTF8StringEncoding]];
				}
			}
			
		}
		
		// Restore unique checks, foreign key checks, and other settings saved at the start
		[metaString setString:@"\n\n\n"];
		[metaString appendString:@"/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;\n"];
		[metaString appendString:@"/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;\n"];
		[metaString appendString:@"/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;\n"];
		
		if ([self sqlOutputIncludeDropSyntax]) {
			[metaString appendString:@"/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;\n"];
		}
		
		// Restore the client encoding to the original encoding before import
		[metaString appendString:@"/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;\n"];
		[metaString appendString:@"/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;\n"];
		[metaString appendString:@"/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;\n"];
		
		// Write footer-type information to the file
		[[self exportOutputFileHandle] writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
		
		// Restore the connection character set to pre-export details
		[tableDocumentInstance
		 setConnectionEncoding:[NSString stringWithFormat:@"%@%@", previousConnectionEncoding, previousConnectionEncodingViaLatin1?@"-":@""]
		 reloadingViews:NO];
		[previousConnectionEncoding release];
		
		// Close the progress sheet
		/*[self closeAndStopProgressSheet];
		
		// Show errors sheet if there have been errors
		if ( [errors length] ) {
			[self showErrorSheetWithMessage:errors];
		}*/
				
		[sqlString release];
		
		[pool release];
	}
	@catch (NSException *e) {}
}

@end

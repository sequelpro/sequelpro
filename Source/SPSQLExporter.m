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
#import "SPTablesList.h"
#import "SPConstants.h"
#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"
#import "SPFileHandle.h"
#import "SPExportUtilities.h"
#import "SPTableData.h"

@interface SPSQLExporter (PrivateAPI)

- (NSString *)_createViewPlaceholderSyntaxForView:(NSString *)viewName;

@end

@implementation SPSQLExporter

@synthesize delegate;
@synthesize sqlExportTables;
@synthesize sqlDatabaseHost;
@synthesize sqlDatabaseName;
@synthesize sqlDatabaseVersion;
@synthesize sqlExportCurrentTable;
@synthesize sqlExportErrors;
@synthesize sqlOutputIncludeUTF8BOM;
@synthesize sqlOutputEncodeBLOBasHex;
@synthesize sqlOutputIncludeErrors;
@synthesize sqlCurrentTableExportIndex;
@synthesize sqlInsertAfterNValue;
@synthesize sqlInsertDivider;

/**
 * Initialise an instance of SPSQLExporter using the supplied delegate.
 *
 * @param exportDelegate The exporter delegate
 *
 * @return The initialised instance
 */
- (id)initWithDelegate:(NSObject *)exportDelegate
{
	if ((self = [super init])) {
		SPExportDelegateConformsToProtocol(exportDelegate, @protocol(SPSQLExporterProtocol));
		
		[self setDelegate:exportDelegate];
		[self setSqlExportCurrentTable:nil];
		
		[self setSqlInsertDivider:SPSQLInsertEveryNDataBytes];
		[self setSqlInsertAfterNValue:250000];
	}
	
	return self;
}

/**
 * Start the SQL export process. This method is automatically called when an instance of this class
 * is placed on an NSOperationQueue. Do not call it directly as there is no manual multithreading.
 */
- (void)main
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	sqlTableDataInstance = [[[SPTableData alloc] init] autorelease];
	[sqlTableDataInstance setConnection:connection];
			
	MCPResult *queryResult;
	MCPStreamingResult *streamingResult;
	
	NSArray *row;
	NSString *tableName;
	NSDictionary *tableDetails;
	NSMutableArray *tableColumnNumericStatus;
	SPTableType tableType = SPTableTypeTable;
	
	id createTableSyntax = nil;
	NSUInteger i, j, k, t, s, rowCount, queryLength, lastProgressValue;
	
	BOOL sqlOutputIncludeStructure;
	BOOL sqlOutputIncludeContent;
	BOOL sqlOutputIncludeDropSyntax;
	
	NSMutableArray *tables = [NSMutableArray array];
	NSMutableArray *procs  = [NSMutableArray array];
	NSMutableArray *funcs  = [NSMutableArray array];
	
	NSMutableString *metaString = [NSMutableString string];
	NSMutableString *cellValue  = [NSMutableString string];
	NSMutableString *errors     = [[NSMutableString alloc] init];
	NSMutableString *sqlString  = [[NSMutableString alloc] init];
	
	NSMutableDictionary *viewSyntaxes = [NSMutableDictionary dictionary];
			
	// Check that we have all the required info before starting the export
	if ((![self sqlExportTables])     || ([[self sqlExportTables] count] == 0)          ||
		(![self sqlDatabaseHost])     || ([[self sqlDatabaseHost] isEqualToString:@""]) ||
		(![self sqlDatabaseName])     || ([[self sqlDatabaseName] isEqualToString:@""]) ||
		(![self sqlDatabaseVersion]   || ([[self sqlDatabaseName] isEqualToString:@""])))
	{
		[errors release];
		[sqlString release];
		[pool release];
		return;
	}
			
	// Inform the delegate that the export process is about to begin
	[delegate performSelectorOnMainThread:@selector(sqlExportProcessWillBegin:) withObject:self waitUntilDone:NO];
	
	// Mark the process as running
	[self setExportProcessIsRunning:YES];
	
	// Clear errors
	[self setSqlExportErrors:@""];
			
	// Copy over the selected item names into tables in preparation for iteration
	NSMutableArray *targetArray;
	
	for (NSArray *item in [self sqlExportTables]) 
	{
		// Check for cancellation flag
		if ([self isCancelled]) {
			[errors release];
			[sqlString release];
			[pool release];
			return;
		}
		
		switch ([NSArrayObjectAtIndex(item, 4) intValue]) {
			case SPTableTypeProc:
				targetArray = procs;
				break;
			case SPTableTypeFunc:
				targetArray = funcs;
				break;
			default:
				targetArray = tables;
				break;
		}
		
		[targetArray addObject:item];
	}
			
	// If required write the UTF-8 Byte Order Mark (BOM)
	if ([self sqlOutputIncludeUTF8BOM]) {
		[metaString setString:@"\xef\xbb\xbf"];
		[metaString appendString:@"# ************************************************************\n"];
	}
	else {
		[metaString setString:@"# ************************************************************\n"];
	}
	
	// Add the dump header to the dump file
	[metaString appendString:@"# Sequel Pro SQL dump\n"];
	[metaString appendString:[NSString stringWithFormat:@"# Version %@\n#\n", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
	[metaString appendString:[NSString stringWithFormat:@"# %@\n# %@\n#\n", SPLOCALIZEDURL_HOMEPAGE, SPDevURL]];
	[metaString appendString:[NSString stringWithFormat:@"# Host: %@ (MySQL %@)\n", [self sqlDatabaseHost], [self sqlDatabaseVersion]]];
	[metaString appendString:[NSString stringWithFormat:@"# Database: %@\n", [self sqlDatabaseName]]];
	[metaString appendString:[NSString stringWithFormat:@"# Generation Time: %@\n", [NSDate date]]];
	[metaString appendString:@"# ************************************************************\n\n\n"];
	
	// Add commands to store the client encodings used when importing and set to UTF8 to preserve data
	[metaString appendString:@"/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;\n"];
	[metaString appendString:@"/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;\n"];
	[metaString appendString:@"/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;\n"];
	[metaString appendString:@"/*!40101 SET NAMES utf8 */;\n"];
	
	[metaString appendString:@"/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;\n"];
	[metaString appendString:@"/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;\n"];
	[metaString appendString:@"/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;\n\n\n"];
	
	[[self exportOutputFile] writeData:[metaString dataUsingEncoding:[self exportOutputEncoding]]];
			
	// Loop through the selected tables
	for (NSArray *table in tables) 
	{
		// Check for cancellation flag
		if ([self isCancelled]) {
			[pool release];
			return;
		}
		
		[self setSqlCurrentTableExportIndex:[self sqlCurrentTableExportIndex]+1];
		tableName = NSArrayObjectAtIndex(table, 0);
					
		sqlOutputIncludeStructure  = [NSArrayObjectAtIndex(table, 1) boolValue];
		sqlOutputIncludeContent    = [NSArrayObjectAtIndex(table, 2) boolValue];
		sqlOutputIncludeDropSyntax = [NSArrayObjectAtIndex(table, 3) boolValue];
		
		// Set the current table
		[self setSqlExportCurrentTable:tableName];
		
		// Inform the delegate that we are about to start fetcihing data for the current table
		[delegate performSelectorOnMainThread:@selector(sqlExportProcessWillBeginFetchingData:) withObject:self waitUntilDone:NO];
		
		lastProgressValue = 0;
		
		// Add the name of table
		[[self exportOutputFile] writeData:[[NSString stringWithFormat:@"# Dump of table %@\n# ------------------------------------------------------------\n\n", tableName] dataUsingEncoding:[self exportOutputEncoding]]];
		
		// Determine whether this table is a table or a view via the CREATE TABLE command, and keep the create table syntax
		queryResult = [connection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE %@", [tableName backtickQuotedString]]];
		
		[queryResult setReturnDataAsStrings:YES];
		
		if ([queryResult numOfRows]) {
			tableDetails = [[NSDictionary alloc] initWithDictionary:[queryResult fetchRowAsDictionary]];
			
			if ([tableDetails objectForKey:@"Create View"]) {
				[viewSyntaxes setValue:[[[[tableDetails objectForKey:@"Create View"] copy] autorelease] createViewSyntaxPrettifier] forKey:tableName];
				createTableSyntax = [self _createViewPlaceholderSyntaxForView:tableName];
				tableType = SPTableTypeView;
			} 
			else {
				createTableSyntax = [[[tableDetails objectForKey:@"Create Table"] copy] autorelease];
				tableType = SPTableTypeTable;
			}
			
			[tableDetails release];
		}
					
		if ([connection queryErrored]) {
			[errors appendString:[NSString stringWithFormat:@"%@\n", [connection getLastErrorMessage]]];
			
			[[self exportOutputFile] writeData:[[NSString stringWithFormat:@"# Error: %@\n\n\n", [connection getLastErrorMessage]] dataUsingEncoding:NSUTF8StringEncoding]];
			
			continue;
		}
		
		// Add a 'DROP TABLE' command if required
		if (sqlOutputIncludeDropSyntax)
			[[self exportOutputFile] writeData:[[NSString stringWithFormat:@"DROP %@ IF EXISTS %@;\n\n", ((tableType == SPTableTypeTable) ? @"TABLE" : @"VIEW"), [tableName backtickQuotedString]]
								   dataUsingEncoding:[self exportOutputEncoding]]];
		
		
		// Add the create syntax for the table if specified in the export dialog
		if (sqlOutputIncludeStructure && createTableSyntax) {
							
			if ([createTableSyntax isKindOfClass:[NSData class]]) {
				createTableSyntax = [[[NSString alloc] initWithData:createTableSyntax encoding:[self exportOutputEncoding]] autorelease];
			}
			
			[[self exportOutputFile] writeData:[createTableSyntax dataUsingEncoding:NSUTF8StringEncoding]];
			[[self exportOutputFile] writeData:[[NSString stringWithString:@";\n\n"] dataUsingEncoding:NSUTF8StringEncoding]];
		}
					
		// Add the table content if required
		if (sqlOutputIncludeContent && (tableType == SPTableTypeTable)) {
			
			// Retrieve the table details via the data class, and use it to build an array containing column numeric status
			tableDetails = [NSDictionary dictionaryWithDictionary:[sqlTableDataInstance informationForTable:tableName]];
							
			NSUInteger colCount = [[tableDetails objectForKey:@"columns"] count];
			
			tableColumnNumericStatus = [NSMutableArray arrayWithCapacity:colCount];
							
			for (j = 0; j < colCount; j++) 
			{
				// Check for cancellation flag
				if ([self isCancelled]) {
					[pool release];
					return;
				}
				
				NSString *tableColumnTypeGrouping = [NSArrayObjectAtIndex([tableDetails objectForKey:@"columns"], j) objectForKey:@"typegrouping"];
				
				[tableColumnNumericStatus addObject:[NSNumber numberWithBool:([tableColumnTypeGrouping isEqualToString:@"bit"] || [tableColumnTypeGrouping isEqualToString:@"integer"] || [tableColumnTypeGrouping isEqualToString:@"float"])]];
			}
																			
			// Retrieve the number of rows in the table for progress bar drawing
			NSArray *rowArray = [[connection queryString:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@", [tableName backtickQuotedString]]] fetchRowAsArray];
			
			if ([connection queryErrored] || ![rowArray count]) {
				[errors appendString:[NSString stringWithFormat:@"%@\n", [connection getLastErrorMessage]]];
				[[self exportOutputFileHandle] writeData:[[NSString stringWithFormat:@"# Error: %@\n\n\n", [connection getLastErrorMessage]] dataUsingEncoding:NSUTF8StringEncoding]];
				
				continue;
			}
			
			rowCount = [NSArrayObjectAtIndex(rowArray, 0) integerValue];
						
			// Set up a result set in streaming mode
			streamingResult = [[connection streamingQueryString:[NSString stringWithFormat:@"SELECT * FROM %@", [tableName backtickQuotedString]] useLowMemoryBlockingStreaming:([self exportUsingLowMemoryBlockingStreaming])] retain];
			
			NSArray *fieldNames = [streamingResult fetchFieldNames];
			
			// Inform the delegate that we are about to start writing data for the current table
			[delegate performSelectorOnMainThread:@selector(sqlExportProcessWillBeginWritingData:) withObject:self waitUntilDone:NO];
							
			if (rowCount) {
				queryLength = 0;
				
				// Lock the table for writing and disable keys if supported
				[metaString setString:@""];
				[metaString appendString:[NSString stringWithFormat:@"LOCK TABLES %@ WRITE;\n", [tableName backtickQuotedString]]];
				[metaString appendString:[NSString stringWithFormat:@"/*!40000 ALTER TABLE %@ DISABLE KEYS */;\n\n", [tableName backtickQuotedString]]];
				
				[[self exportOutputFile] writeData:[metaString dataUsingEncoding:[self exportOutputEncoding]]];
				
				// Construct the start of the insertion command
				[[self exportOutputFile] writeData:[[NSString stringWithFormat:@"INSERT INTO %@ (%@)\nVALUES\n\t(", [tableName backtickQuotedString], [fieldNames componentsJoinedAndBacktickQuoted]] dataUsingEncoding:NSUTF8StringEncoding]];
				
				// Iterate through the rows to construct a VALUES group for each
				j = 0, k = 0;
				
				NSAutoreleasePool *sqlExportPool = [[NSAutoreleasePool alloc] init];
				
				// Inform the delegate that we are about to start writing the data to disk
				[delegate performSelectorOnMainThread:@selector(sqlExportProcessWillBeginWritingData:) withObject:self waitUntilDone:NO];
				
				while (row = [streamingResult fetchNextRowAsArray]) 
				{
					// Check for cancellation flag
					if ([self isCancelled]) {
						[connection cancelCurrentQuery];
						[streamingResult cancelResultLoad];
						[sqlExportPool release];
						[pool release];
						
						return;
					}
					
					j++;
					k++;
					
					[sqlString setString:@""];
											
					// Update the progress 
					NSUInteger progress = (j * ([self exportMaxProgress] / rowCount));
					
					if (progress > lastProgressValue) {
						[self setExportProgressValue:progress];
						lastProgressValue = progress;
						
						// Inform the delegate that the export's progress has been updated
						[delegate performSelectorOnMainThread:@selector(sqlExportProcessProgressUpdated:) withObject:self waitUntilDone:NO];
					}
					
					for (t = 0; t < colCount; t++) 
					{
						// Check for cancellation flag
						if ([self isCancelled]) {
							[sqlExportPool release];
							[pool release];
							
							return;
						}
						
						id object = NSArrayObjectAtIndex(row, t);
												
						// Add NULL values directly to the output row
						if ([object isMemberOfClass:[NSNull class]]) {
							[sqlString appendString:@"NULL"];
						} 
						// If the field is off type BIT, the values need a binary prefix of b'x'.
						else if ([[NSArrayObjectAtIndex([tableDetails objectForKey:@"columns"], t) objectForKey:@"type"] isEqualToString:@"BIT"]) {
							[sqlString appendString:@"b'"];
							[sqlString appendString:[object description]];
							[sqlString appendString:@"'"];
						}
						// Add data types directly as hex data
						else if ([object isKindOfClass:[NSData class]]) {
							
							if ([self sqlOutputEncodeBLOBasHex]) {
								[sqlString appendString:@"X'"];
								[sqlString appendString:[connection prepareBinaryData:object]];
							}
							else {
								[sqlString appendString:@"'"];
								
								NSString *data = [[NSString alloc] initWithData:object encoding:[self exportOutputEncoding]];
								
								if (data == nil) {
									data = [[NSString alloc] initWithData:object encoding:NSASCIIStringEncoding];
								}
								
								[sqlString appendString:data];
								
								[data release];
							}
							
							[sqlString appendString:@"'"];
						} 
						else {
							[cellValue setString:[object description]];
							
							// Add empty strings as a pair of quotes
							if ([cellValue length] == 0) {
								[sqlString appendString:@"''"];
							} 
							else {	
								if ([NSArrayObjectAtIndex(tableColumnNumericStatus, t) boolValue]) {
									[sqlString appendString:cellValue];
								} 
								// Otherwise add a quoted string with special characters escaped
								else {
									[sqlString appendString:@"'"];
									[sqlString appendString:[connection prepareString:cellValue]];
									[sqlString appendString:@"'"];
								}
							}
						}
						
						// Add the field separator if this isn't the last cell in the row
						if (t != ([row count] - 1)) [sqlString appendString:@","];
					}
					
					queryLength += [sqlString length];
					
					// Close this VALUES group and set up the next one if appropriate
					if (j != rowCount) {
							
						// If required start a new INSERT statment
						if ((([self sqlInsertDivider] == SPSQLInsertEveryNDataBytes) && (queryLength >= ([self sqlInsertAfterNValue] * 1024))) ||
							(([self sqlInsertDivider] == SPSQLInsertEveryNRows) && (k == [self sqlInsertAfterNValue])))
						{
							[sqlString appendString:@");\n\nINSERT INTO "];
							[sqlString appendString:[tableName backtickQuotedString]];
							[sqlString appendString:@" ("];
							[sqlString appendString:[fieldNames componentsJoinedAndBacktickQuoted]];
							[sqlString appendString:@")\nVALUES\n\t("];
														
							queryLength = 0, k = 0;
							
							// Use the opportunity to drain and reset the autorelease pool
							[sqlExportPool release];
							sqlExportPool = [[NSAutoreleasePool alloc] init];
						} 
						else {
							[sqlString appendString:@"),\n\t("];
						}
					} 
					else {
						[sqlString appendString:@")"];
					}
										
					// Write this row to the file
					[[self exportOutputFile] writeData:[sqlString dataUsingEncoding:NSUTF8StringEncoding]];
				}
				
				// Complete the command
				[[self exportOutputFile] writeData:[[NSString stringWithString:@";\n\n"] dataUsingEncoding:NSUTF8StringEncoding]];
				
				// Unlock the table and re-enable keys if supported
				[metaString setString:@""];
				[metaString appendString:[NSString stringWithFormat:@"/*!40000 ALTER TABLE %@ ENABLE KEYS */;\n", [tableName backtickQuotedString]]];
				[metaString appendString:@"UNLOCK TABLES;\n"];
				
				[[self exportOutputFile] writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
				
				// Drain the autorelease pool
				[sqlExportPool release];
			}
			
			if ([connection queryErrored]) {
				[errors appendString:[NSString stringWithFormat:@"%@\n", [connection getLastErrorMessage]]];
				
				if ([self sqlOutputIncludeErrors]) {
					[[self exportOutputFile] writeData:[[NSString stringWithFormat:@"# Error: %@\n", [connection getLastErrorMessage]]
										   dataUsingEncoding:NSUTF8StringEncoding]];
				}
			}
			
			// Release the result set
			[streamingResult release];
		}
			
		queryResult = [connection queryString:[NSString stringWithFormat:@"/*!50003 SHOW TRIGGERS WHERE `Table` = %@ */;", [tableName tickQuotedString]]];
		
		[queryResult setReturnDataAsStrings:YES];
		
		if ([queryResult numOfRows]) {
			
			[metaString setString:@"\n"];
			[metaString appendString:@"DELIMITER ;;\n"];
			
			for (s = 0; s < [queryResult numOfRows]; s++) 
			{
				// Check for cancellation flag
				if ([self isCancelled]) {
					[pool release];
					return;
				}
				
				NSDictionary *triggers = [[NSDictionary alloc] initWithDictionary:[queryResult fetchRowAsDictionary]];
				
				// Definer is user@host but we need to escape it to `user`@`host`
				NSArray *triggersDefiner = [[triggers objectForKey:@"Definer"] componentsSeparatedByString:@"@"];
				
				NSString *escapedDefiner = [NSString stringWithFormat:@"%@@%@", 
											[NSArrayObjectAtIndex(triggersDefiner, 0) backtickQuotedString],
											[NSArrayObjectAtIndex(triggersDefiner, 1) backtickQuotedString]
											];
				
				[metaString appendString:[NSString stringWithFormat:@"/*!50003 SET SESSION SQL_MODE=\"%@\" */;;\n", [triggers objectForKey:@"sql_mode"]]];
				[metaString appendString:@"/*!50003 CREATE */ "];
				[metaString appendString:[NSString stringWithFormat:@"/*!50017 DEFINER=%@ */ ", escapedDefiner]];
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
			
			[[self exportOutputFile] writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
		}
		
		if ([connection queryErrored]) {
			[errors appendString:[NSString stringWithFormat:@"%@\n", [connection getLastErrorMessage]]];
			
			if ([self sqlOutputIncludeErrors]) {
				[[self exportOutputFile] writeData:[[NSString stringWithFormat:@"# Error: %@\n", [connection getLastErrorMessage]]
									   dataUsingEncoding:NSUTF8StringEncoding]];
			}
		}
		
		// Add an additional separator between tables
		[[self exportOutputFile] writeData:[[NSString stringWithString:@"\n\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	// Process any deferred views, adding commands to delete the placeholder tables and add the actual views
	for (tableName in viewSyntaxes) 
	{
		// Check for cancellation flag
		if ([self isCancelled]) {
			[pool release];
			return;
		}
		
		[metaString setString:@"\n\n"];
		// Add the name of table
		[metaString appendFormat:@"# Replace placeholder table for %@ with correct view syntax\n# ------------------------------------------------------------\n\n", tableName];
		[metaString appendFormat:@"DROP TABLE %@;\n", [tableName backtickQuotedString]];
		[metaString appendFormat:@"%@;\n", [viewSyntaxes objectForKey:tableName]];
		
		[[self exportOutputFile] writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	// Export procedures and functions
	for (NSString *procedureType in [NSArray arrayWithObjects:@"PROCEDURE", @"FUNCTION", nil]) 
	{
		// Check for cancellation flag
		if ([self isCancelled]) {
			[pool release];
			return;
		}
		
		// Retrieve the array of selected procedures or functions, and skip export if not selected
		NSMutableArray *items;
		
		if ([procedureType isEqualToString:@"PROCEDURE"]) items = procs;
		else items = funcs;
		
		if ([items count] == 0) continue;
		
		// Retrieve the definitions
		queryResult = [connection queryString:[NSString stringWithFormat:@"/*!50003 SHOW %@ STATUS WHERE `Db` = %@ */;", procedureType,
											   [[self sqlDatabaseName] tickQuotedString]]];
		
		[queryResult setReturnDataAsStrings:YES];
		
		if ([queryResult numOfRows]) {
			
			[metaString setString:@"\n"];
			[metaString appendString:@"--\n"];
			[metaString appendString:[NSString stringWithFormat:@"-- Dumping routines (%@) for database %@\n", procedureType,
									  [[self sqlDatabaseName] tickQuotedString]]];
			
			[metaString appendString:@"--\n"];
			[metaString appendString:@"DELIMITER ;;\n\n"];
			
			// Loop through the definitions, exporting if enabled
			for (s = 0; s < [queryResult numOfRows]; s++) 
			{
				// Check for cancellation flag
				if ([self isCancelled]) {
					[pool release];
					return;
				}

				NSDictionary *proceduresList = [[NSDictionary alloc] initWithDictionary:[queryResult fetchRowAsDictionary]];
				NSString *procedureName = [NSString stringWithFormat:@"%@", [proceduresList objectForKey:@"Name"]];

				// Only proceed if the item is in the list of items
				BOOL itemFound = NO;
				for (NSArray *item in items)
				{
					// Check for cancellation flag
					if ([self isCancelled]) {
						[proceduresList release];
						[pool release];
						return;
					}
					
					if ([NSArrayObjectAtIndex(item, 0) isEqualToString:procedureName]) {
						itemFound = YES;
						sqlOutputIncludeStructure  = [NSArrayObjectAtIndex(item, 1) boolValue];
						sqlOutputIncludeContent    = [NSArrayObjectAtIndex(item, 2) boolValue];
						sqlOutputIncludeDropSyntax = [NSArrayObjectAtIndex(item, 3) boolValue];
						break;
					}
				}
				if (!itemFound) {
					[proceduresList release];
					continue;
				}

				if (sqlOutputIncludeStructure || sqlOutputIncludeDropSyntax)
					[metaString appendFormat:@"# Dump of %@ %@\n# ------------------------------------------------------------\n\n", procedureType, procedureName];

				// Add the 'DROP' command if required
				if (sqlOutputIncludeDropSyntax) {
					[metaString appendString:[NSString stringWithFormat:@"/*!50003 DROP %@ IF EXISTS %@ */;;\n", procedureType,
											  [procedureName backtickQuotedString]]];
				}
				
				// Only continue if the 'CREATE SYNTAX' is required
				if (!sqlOutputIncludeStructure) {
					[proceduresList release];
					continue;
				}
				
				// Definer is user@host but we need to escape it to `user`@`host`
				NSArray *procedureDefiner = [[proceduresList objectForKey:@"Definer"] componentsSeparatedByString:@"@"];
				
				NSString *escapedDefiner = [NSString stringWithFormat:@"%@@%@", 
											[NSArrayObjectAtIndex(procedureDefiner, 0) backtickQuotedString],
											[NSArrayObjectAtIndex(procedureDefiner, 1) backtickQuotedString]
											];
				
				MCPResult *createProcedureResult = [connection queryString:[NSString stringWithFormat:@"/*!50003 SHOW CREATE %@ %@ */;;", procedureType,
																			[procedureName backtickQuotedString]]];
				[createProcedureResult setReturnDataAsStrings:YES];
				if ([connection queryErrored]) {
					[errors appendString:[NSString stringWithFormat:@"%@\n", [connection getLastErrorMessage]]];
					
					if ([self sqlOutputIncludeErrors]) {
						[[self exportOutputFile] writeData:[[NSString stringWithFormat:@"# Error: %@\n", [connection getLastErrorMessage]] dataUsingEncoding:NSUTF8StringEncoding]];
					}
					[proceduresList release];
					continue;
				}
				
				NSDictionary *procedureInfo = [[NSDictionary alloc] initWithDictionary:[createProcedureResult fetchRowAsDictionary]];
				
				[metaString appendString:[NSString stringWithFormat:@"/*!50003 SET SESSION SQL_MODE=\"%@\"*/;;\n", [procedureInfo objectForKey:@"sql_mode"]]];
				
				NSString *createProcedure = [procedureInfo objectForKey:[NSString stringWithFormat:@"Create %@", [procedureType capitalizedString]]];
				
				// A NULL result indicates a permission problem
				if ([createProcedure isNSNull]) {
					NSString *errorString = [NSString stringWithFormat:NSLocalizedString(@"Could not export the %@ '%@' because of a permisions error.\n", @"Procedure/function export permission error"), procedureType, procedureName];
					[errors appendString:errorString];
					if ([self sqlOutputIncludeErrors]) {
						[[self exportOutputFile] writeData:[[NSString stringWithFormat:@"# Error: %@\n", errorString] dataUsingEncoding:NSUTF8StringEncoding]];
					}
					[proceduresList release];
					[procedureInfo release];
					continue;
				}

				NSRange procedureRange    = [createProcedure rangeOfString:procedureType options:NSCaseInsensitiveSearch];
				NSString *procedureBody   = [createProcedure substringFromIndex:procedureRange.location];
				
				// /*!50003 CREATE*/ /*!50020 DEFINER=`sequelpro`@`%`*/ /*!50003 PROCEDURE `p`()
				// 													  BEGIN
				// 													  /* This procedure does nothing */
				// END */;;
				//
				// Build the CREATE PROCEDURE string to include MySQL Version limiters
				[metaString appendString:[NSString stringWithFormat:@"/*!50003 CREATE*/ /*!50020 DEFINER=%@*/ /*!50003 %@ */;;\n\n", escapedDefiner, procedureBody]];
				
				[procedureInfo release];
				[proceduresList release];
				
				[metaString appendString:@"/*!50003 SET SESSION SQL_MODE=@OLD_SQL_MODE */;;\n"];
			}
			
			[metaString appendString:@"DELIMITER ;\n"];
			
			[[self exportOutputFile] writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
		}
		
		if ([connection queryErrored]) {
			[errors appendString:[NSString stringWithFormat:@"%@\n", [connection getLastErrorMessage]]];
			
			if ([self sqlOutputIncludeErrors]) {
				[[self exportOutputFile] writeData:[[NSString stringWithFormat:@"# Error: %@\n", [connection getLastErrorMessage]] dataUsingEncoding:NSUTF8StringEncoding]];
			}
		}
		
	}
	
	// Restore unique checks, foreign key checks, and other settings saved at the start
	[metaString setString:@"\n"];
	[metaString appendString:@"/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;\n"];
	[metaString appendString:@"/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;\n"];
	[metaString appendString:@"/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;\n"];
	
	// Restore the client encoding to the original encoding before import
	[metaString appendString:@"/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;\n"];
	[metaString appendString:@"/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;\n"];
	[metaString appendString:@"/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;\n"];
	
	// Write footer-type information to the file
	[[self exportOutputFile] writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
			
	// Set export errors
	[self setSqlExportErrors:errors];
			
	[errors release];
	[sqlString release];
	
	// Close the file
	[[self exportOutputFile] close];
	
	// Mark the process as not running
	[self setExportProcessIsRunning:NO];
	
	// Inform the delegate that the export process is complete
	[delegate performSelectorOnMainThread:@selector(sqlExportProcessComplete:) withObject:self waitUntilDone:NO];
	
	[pool release];
}

/**
 * Returns whether or not any export errors occurred by examing the length of the errors string.
 *
 * @return A BOOL indicating the occurrence of errors
 */
- (BOOL)didExportErrorsOccur
{
	return [[self sqlExportErrors] length];
}

/**
 * Retrieve information for a view and use that to construct a CREATE TABLE string for an equivalent basic 
 * table. Allows the construction of placeholder tables to resolve view interdependencies within dumps.
 *
 * @param viewName The name of the view for which the placeholder is to be created for.
 *
 * @return The CREATE TABLE placeholder syntax
 */
- (NSString *)_createViewPlaceholderSyntaxForView:(NSString *)viewName
{
	NSInteger i, j;
	NSMutableString *placeholderSyntax;
	
	// Get structured information for the view via the SPTableData parsers
	NSDictionary *viewInformation = [sqlTableDataInstance informationForView:viewName];
	
	if (!viewInformation) return nil;
	
	NSArray *viewColumns = [viewInformation objectForKey:@"columns"];

	// Set up the start of the placeholder string and initialise an empty field string
	placeholderSyntax = [[NSMutableString alloc] initWithFormat:@"CREATE TABLE %@ (\n", [viewName backtickQuotedString]];
	
	NSMutableString *fieldString = [[NSMutableString alloc] init];
	
	// Loop through the columns, creating an appropriate column definition for each and appending it to the syntax string
	for (i = 0; i < [viewColumns count]; i++) 
	{
		NSDictionary *column = NSArrayObjectAtIndex(viewColumns, i);
		
		[fieldString setString:[[column objectForKey:@"name"] backtickQuotedString]];
		
		// Add the type and length information as appropriate
		if ([column objectForKey:@"length"]) {
			[fieldString appendFormat:@" %@(%@)", [column objectForKey:@"type"], [column objectForKey:@"length"]];
		} 
		else if ([column objectForKey:@"values"]) {
			[fieldString appendFormat:@" %@(", [column objectForKey:@"type"]];
			
			for (j = 0; j < [[column objectForKey:@"values"] count]; j++) 
			{
				[fieldString appendFormat:@"'%@'%@", [connection prepareString:NSArrayObjectAtIndex([column objectForKey:@"values"], j)], ((j + 1) == [[column objectForKey:@"values"] count]) ? @"" : @","];
			}
			
			[fieldString appendString:@")"];
		} 
		else {
			[fieldString appendFormat:@" %@", [column objectForKey:@"type"]];
		}
		
		// Field specification details
		if ([[column objectForKey:@"unsigned"] integerValue] == 1) [fieldString appendString:@" UNSIGNED"];
		if ([[column objectForKey:@"zerofill"] integerValue] == 1) [fieldString appendString:@" ZEROFILL"];
		if ([[column objectForKey:@"binary"] integerValue] == 1) [fieldString appendString:@" BINARY"];
		if ([[column objectForKey:@"null"] integerValue] == 0) [fieldString appendString:@" NOT NULL"];
		
		// Provide the field default if appropriate
		if ([column objectForKey:@"default"]) {
			
			// Some MySQL server versions show a default of NULL for NOT NULL columns - don't export those
			if ([column objectForKey:@"default"] == [NSNull null]) {
				if ([[column objectForKey:@"null"] integerValue]) {
					[fieldString appendString:@" DEFAULT NULL"];
				}
			} 
			else if ([[column objectForKey:@"type"] isEqualToString:@"TIMESTAMP"] && [column objectForKey:@"default"] != [NSNull null] && [[[column objectForKey:@"default"] uppercaseString] isEqualToString:@"CURRENT_TIMESTAMP"]) {
				[fieldString appendString:@" DEFAULT CURRENT_TIMESTAMP"];
			} 
			else {
				[fieldString appendFormat:@" DEFAULT '%@'", [connection prepareString:[column objectForKey:@"default"]]];
			}
		}
		
		// Extras aren't required for the temp table
		// Add the field string to the syntax string
		[placeholderSyntax appendFormat:@"   %@%@\n", fieldString, (i == [viewColumns count] - 1) ? @"" : @","];
	}
	
	// Append the remainder of the table string
	[placeholderSyntax appendString:@") ENGINE=MyISAM"];
	
	// Clean up and return
	[fieldString release];
	
	return [placeholderSyntax autorelease];
}

/**
 * Dealloc
 */
- (void)dealloc
{
	[sqlExportTables release], sqlExportTables = nil;
	[sqlDatabaseHost release], sqlDatabaseHost = nil;
	[sqlDatabaseName release], sqlDatabaseName = nil;
	[sqlExportCurrentTable release], sqlExportCurrentTable = nil;
	[sqlDatabaseVersion release], sqlDatabaseVersion = nil;
	
	[super dealloc];
}

@end

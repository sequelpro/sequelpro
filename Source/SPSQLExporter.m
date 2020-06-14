//
//  SPSQLExporter.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on August 29, 2009.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import "SPSQLExporter.h"
#import "SPTablesList.h"
#import "SPFileHandle.h"
#import "SPExportUtilities.h"
#import "SPExportFile.h"
#import "SPTableData.h"
#import "RegexKitLite.h"

#import <SPMySQL/SPMySQL.h>
#include <stdlib.h>

@interface SPSQLExporter ()

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
@synthesize sqlOutputIncludeAutoIncrement;
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
- (id)initWithDelegate:(NSObject<SPSQLExporterProtocol> *)exportDelegate
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

- (void)exportOperation
{
	// used in end_cleanup
	NSMutableString *errors     = [[NSMutableString alloc] init];
	NSMutableString *sqlString  = [[NSMutableString alloc] init];
	NSString *oldSqlMode        = nil;

	// Check that we have all the required info before starting the export
	if ((![self sqlExportTables])     || ([[self sqlExportTables] count] == 0)          ||
	    (![self sqlDatabaseHost])     || ([[self sqlDatabaseHost] isEqualToString:@""]) ||
	    (![self sqlDatabaseName])     || ([[self sqlDatabaseName] isEqualToString:@""]) ||
	    (![self sqlDatabaseVersion]   || ([[self sqlDatabaseName] isEqualToString:@""])))
	{
		goto end_cleanup;
	}

	sqlTableDataInstance = [[[SPTableData alloc] init] autorelease];
	[sqlTableDataInstance setConnection:connection];

	// Inform the delegate that the export process is about to begin
	[delegate performSelectorOnMainThread:@selector(sqlExportProcessWillBegin:) withObject:self waitUntilDone:NO];
	
	// Mark the process as running
	[self setExportProcessIsRunning:YES];
	
	// Clear errors
	[self setSqlExportErrors:@""];

	NSMutableArray *tables = [NSMutableArray array];
	NSMutableArray *procs  = [NSMutableArray array];
	NSMutableArray *funcs  = [NSMutableArray array];

	// Copy over the selected item names into tables in preparation for iteration
	for (NSArray *item in [self sqlExportTables])
	{
		// Check for cancellation flag
		if ([self isCancelled]) goto end_cleanup;

		NSMutableArray *targetArray;
		switch ([NSArrayObjectAtIndex(item, 4) intValue]) {
			case SPTableTypeProc:
				targetArray = procs;
				break;
			case SPTableTypeFunc:
				targetArray = funcs;
				break;
			case SPTableTypeTable:
			default:
				targetArray = tables;
				break;
		}
		
		[targetArray addObject:item];
	}

	NSMutableString *metaString = [NSMutableString string];

	// If required write the UTF-8 Byte Order Mark (BOM)
	if ([self sqlOutputIncludeUTF8BOM]) {
		[metaString appendString:@"\xef\xbb\xbf"];
	}

	// we require utf8
	[connection setEncoding:@"utf8"];
	// …but utf8mb4 (aka "really" utf8) would be even better.
	BOOL utf8mb4 = [connection setEncoding:@"utf8mb4"];
	
	// Add the dump header to the dump file
	[metaString appendString:@"# ************************************************************\n"];
	[metaString appendString:@"# Sequel Ace SQL dump\n"];
	[metaString appendFormat:@"# %@ %@\n#\n", NSLocalizedString(@"Version", @"export header version label"), [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
	[metaString appendFormat:@"# %@\n# %@\n#\n", SPLOCALIZEDURL_HOMEPAGE, SPDevURL];
	[metaString appendFormat:@"# %@: %@ (MySQL %@)\n", NSLocalizedString(@"Host", @"export header host label"), [self sqlDatabaseHost], [self sqlDatabaseVersion]];
	[metaString appendFormat:@"# %@: %@\n", NSLocalizedString(@"Database", @"export header database label"), [self sqlDatabaseName]];
	[metaString appendFormat:@"# %@: %@\n", NSLocalizedString(@"Generation Time", @"export header generation time label"), [NSDate date]];
	[metaString appendString:@"# ************************************************************\n\n\n"];
	
	// Add commands to store the client encodings used when importing and set to UTF8 to preserve data
	[metaString appendString:@"/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;\n"];
	[metaString appendString:@"/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;\n"];
	[metaString appendString:@"/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;\n"];
	[metaString appendString:@"/*!40101 SET NAMES utf8 */;\n"];
	if(utf8mb4) {
		// !! This being outside of a conditional comment is FULLY INTENTIONAL !!
		// We *absolutely* want that to fail if the export includes utf8mb4 data, but the server can't handle it.
		// MySQL would _normally_ just drop-replace such characters with "?" (a literal questionmark) without any (visible) complaint.
		// Since that means irreversible (and often hard to notice) data corruption,
		//   the user should CONSCIOUSLY make a decision for that to happen!
		//TODO we should link to a website explaining the risk here
		[metaString appendString:@"SET NAMES utf8mb4;\n"];
	}

	[metaString appendString:@"/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;\n"];

	/* A note on SQL_MODE:
	 *
	 *   BEFORE 3.23.6
	 *     No supported
	 *
	 *   FROM 3.23.6
	 *     There is a "--ansi" / "-a" CLI argument to mysqld, which is the predecessor to SQL_MODE.
	 *     It can be queried via "SHOW VARIABLES" -> "ansi_mode" = "OFF" | "ON"
	 *
	 *   FROM 3.23.41
	 *     There is a "--sql-mode=[opt[,opt[...]]]" CLI argument to mysqld.
	 *     It can be queried via "SHOW VARIABLES" -> "sql_mode" but the result will be a bitfield value with
	 *         #define MODE_REAL_AS_FLOAT        1 = "REAL_AS_FLOAT"
	 *         #define MODE_PIPES_AS_CONCAT      2 = "PIPES_AS_CONCAT"
	 *         #define MODE_ANSI_QUOTES          4 = "ANSI_QUOTES"
	 *         #define MODE_IGNORE_SPACE         8 = "IGNORE_SPACE"
	 *         #define MODE_SERIALIZABLE        16 = "SERIALIZE" (!)
	 *         #define MODE_ONLY_FULL_GROUP_BY  32 = "ONLY_FULL_GROUP_BY"
	 *     The "--ansi" switch is still supported but mostly equivalent to setting all of the options above
	 *     (it will also set the transaction isolation level to SERIALIZABLE).
	 *     "ansi_mode" is no longer returned by SHOW VARIABLES.
	 *
	 *   FROM 4.1.0
	 *     - "sql_mode" can be changed at runtime (global or per session).
	 *     - "SHOW VARIABLES" now returns a CSV list of named options
	 *
	 *   FROM 4.1.1
	 *     - "SERIALIZE" is no longer supported (must be changed via "SET TRANSACTION ISOLATION LEVEL")
	 *       (trivia: internally it has become MODE_NOT_USED: 16 = "?")
	 *
	 */

	BOOL sqlModeIsValid = NO;
	//fetch old sql mode to restore it later
	{
		SPMySQLResult *result = [connection queryString:@"SHOW VARIABLES LIKE 'sql_mode'"];
		if(![connection queryErrored]) {
			[result setReturnDataAsStrings:YES];
			NSArray *row = [result getRowAsArray];
			oldSqlMode = [[row objectAtIndex:1] unboxNull];
		}
	}
	//set sql mode for export
	if([@"" isEqualToString:oldSqlMode]) {
		// the current sql_mode is already the one we want (empty string), no need to change+revert it
		oldSqlMode = nil;
		sqlModeIsValid = YES;
	}
	else {
		[connection queryString:@"SET SQL_MODE=''"]; //mysqldump uses a conditional comment for 40100 here, but we want to see the error, since it can't simply be ignored (also ANSI mode is supported before 4.1)
		if (![connection queryErrored]) {
			sqlModeIsValid = YES;
		}
		else {
			[errors appendFormat:@"%@ (%@)\n", NSLocalizedString(@"The server's SQL_MODE could not be changed to one suitable for export. The export may be missing important details or may not be importable at all!", @"sql export : 'set @@sql_mode' query failed message"), [connection lastErrorMessage]];
			[metaString appendFormat:@"# SET SQL_MODE Error: %@\n\n\n", [connection lastErrorMessage]];
			//if we couldn't change it, we don't need to restore it either
			oldSqlMode = nil;
		}
	}
	// TODO:
	// * There is no point in writing out that the file should use a specific SQL mode when we don't even know which one was active during export.
	// * Triggers, procs/funcs have their own SQL_MODE which is still set/reset below, though.
	//
	// But an unknown SQL_MODE (!sqlModeIsValid) could perhaps still affect how MySQL returns the "SHOW CREATE…"
	// data for those objects (like it does for "SHOW CREATE TABLE") possibly rendering them invalid (need to check that),
	// so it may be better to flat out refuse to export schema object DDL if we don't have a valid sql_mode.
	[metaString appendString:@"/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;\n"];

	[metaString appendString:@"/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;\n\n\n"];

	[self writeString:metaString];

	NSMutableDictionary *viewSyntaxes = [NSMutableDictionary dictionary];

	// Loop through the selected tables
	for (NSArray *table in tables) 
	{
		// Check for cancellation flag
		if ([self isCancelled]) goto end_cleanup;
		
		[self setSqlCurrentTableExportIndex:[self sqlCurrentTableExportIndex]+1];
		NSString *tableName = NSArrayObjectAtIndex(table, 0);

		BOOL sqlOutputIncludeStructure  = [NSArrayObjectAtIndex(table, 1) boolValue];
		BOOL sqlOutputIncludeContent    = [NSArrayObjectAtIndex(table, 2) boolValue];
		BOOL sqlOutputIncludeDropSyntax = [NSArrayObjectAtIndex(table, 3) boolValue];

		// Skip tables if not set to output any detail for them
		if (!sqlOutputIncludeStructure && !sqlOutputIncludeContent && !sqlOutputIncludeDropSyntax) {
			continue;
		}

		// Set the current table
		[self setSqlExportCurrentTable:tableName];
		
		// Inform the delegate that we are about to start fetcihing data for the current table
		[delegate performSelectorOnMainThread:@selector(sqlExportProcessWillBeginFetchingData:) withObject:self waitUntilDone:NO];
		
		NSUInteger lastProgressValue = 0;
		
		// Add the name of table
		[self writeString:[NSString stringWithFormat:@"# %@ %@\n# ------------------------------------------------------------\n\n", NSLocalizedString(@"Dump of table", @"sql export dump of table label"), tableName]];

		id createTableSyntax = nil;
		SPTableType tableType = SPTableTypeTable;
		// Determine whether this table is a table or a view via the CREATE TABLE command, and keep the create table syntax
		{
			SPMySQLResult *queryResult = [connection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE %@", [tableName backtickQuotedString]]];

			[queryResult setReturnDataAsStrings:YES];

			if ([queryResult numberOfRows]) {
				NSDictionary *tableDetails = [[NSDictionary alloc] initWithDictionary:[queryResult getRowAsDictionary]];

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
				[errors appendFormat:@"%@\n", [connection lastErrorMessage]];

				[self writeUTF8String:[NSString stringWithFormat:@"# Error: %@\n\n\n", [connection lastErrorMessage]]];

				continue;
			}
		}
		
		// Add a 'DROP TABLE' command if required
		if (sqlOutputIncludeDropSyntax) {
			[self writeString:[NSString stringWithFormat:@"DROP %@ IF EXISTS %@;\n\n", ((tableType == SPTableTypeTable) ? @"TABLE" : @"VIEW"), [tableName backtickQuotedString]]];
		}
		
		// Add the create syntax for the table if specified in the export dialog
		if (sqlOutputIncludeStructure && createTableSyntax) {

			if ([createTableSyntax isKindOfClass:[NSData class]]) {
#warning This doesn't make sense. If the NSData really contains a string it would be in utf8, utf8mb4 or a mysql pre-4.1 legacy charset, but not in the export output charset. This whole if() is likely a side effect of the BINARY flag confusion (#2700)
				createTableSyntax = [[[NSString alloc] initWithData:createTableSyntax encoding:[self exportOutputEncoding]] autorelease];
			}
			
			// If necessary strip out the AUTO_INCREMENT from the table structure definition
			if (![self sqlOutputIncludeAutoIncrement]) {
				createTableSyntax = [createTableSyntax stringByReplacingOccurrencesOfRegex:[NSString stringWithFormat:@"AUTO_INCREMENT=[0-9]+ "] withString:@""];
			}

			[self writeUTF8String:createTableSyntax];
			[self writeUTF8String:@";\n\n"];
		}

		// Add the table content if required
		if (sqlOutputIncludeContent && (tableType == SPTableTypeTable)) {
			// Retrieve the table details via the data class, and use it to build an array containing column numeric status
			NSDictionary *tableDetails = [NSDictionary dictionaryWithDictionary:[sqlTableDataInstance informationForTable:tableName]];

			NSUInteger colCount = [[tableDetails objectForKey:@"columns"] count];
			NSMutableArray *rawColumnNames = [NSMutableArray arrayWithCapacity:colCount];
			NSMutableArray *queryColumnDetails = [NSMutableArray arrayWithCapacity:colCount];
			
			BOOL *useRawDataForColumnAtIndex = calloc(colCount, sizeof(BOOL));
			BOOL *useRawHexDataForColumnAtIndex = calloc(colCount, sizeof(BOOL));

			// Determine whether raw data can be used for each column during processing - safe numbers and hex-encoded data.
			for (NSUInteger j = 0; j < colCount; j++)
			{
				NSDictionary *theColumnDetail = NSArrayObjectAtIndex([tableDetails objectForKey:@"columns"], j);
				NSString *theTypeGrouping = [theColumnDetail objectForKey:@"typegrouping"];

				// Start by setting the column as non-safe
				useRawDataForColumnAtIndex[j] = NO;
				useRawHexDataForColumnAtIndex[j] = NO;

				// Determine whether the column should be retrieved as hex data from the server - for binary strings, to
				// avoid encoding issues when processing
				if ([self sqlOutputEncodeBLOBasHex]
					&& [theTypeGrouping isEqualToString:@"string"]
					&& ([[theColumnDetail objectForKey:@"binary"] boolValue] || [[theColumnDetail objectForKey:@"collation"] hasSuffix:@"_bin"]))
				{
					useRawHexDataForColumnAtIndex[j] = YES;
				}

				// Floats, integers can be output directly assuming they're non-binary
				if (![[theColumnDetail objectForKey:@"binary"] boolValue] && ([@[@"integer",@"float"] containsObject:theTypeGrouping]))
				{
					useRawDataForColumnAtIndex[j] = YES;
				}

				// Set up the column query string parts
				[rawColumnNames addObject:[theColumnDetail objectForKey:@"name"]];
				
				if (useRawHexDataForColumnAtIndex[j]) {
					[queryColumnDetails addObject:[NSString stringWithFormat:@"HEX(%@)", [[theColumnDetail objectForKey:@"name"] mySQLBacktickQuotedString]]];
				} 
				else {
					[queryColumnDetails addObject:[[theColumnDetail objectForKey:@"name"] mySQLBacktickQuotedString]];
				}
			}

			// Retrieve the number of rows in the table for progress bar drawing
			NSArray *rowArray = [[connection queryString:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@", [tableName backtickQuotedString]]] getRowAsArray];
			
			if ([connection queryErrored] || ![rowArray count]) {
				[errors appendFormat:@"%@\n", [connection lastErrorMessage]];
				[self writeUTF8String:[NSString stringWithFormat:@"# Error: %@\n\n\n", [connection lastErrorMessage]]];
				free(useRawDataForColumnAtIndex);
				free(useRawHexDataForColumnAtIndex);
				continue;
			}
			
			NSUInteger rowCount = [NSArrayObjectAtIndex(rowArray, 0) integerValue];

			if (rowCount) {
				// Set up a result set in streaming mode
				SPMySQLStreamingResult *streamingResult = [[connection streamingQueryString:[NSString stringWithFormat:@"SELECT %@ FROM %@", [queryColumnDetails componentsJoinedByString:@", "], [tableName backtickQuotedString]] useLowMemoryBlockingStreaming:([self exportUsingLowMemoryBlockingStreaming])] retain];

				// Inform the delegate that we are about to start writing data for the current table
				[delegate performSelectorOnMainThread:@selector(sqlExportProcessWillBeginWritingData:) withObject:self waitUntilDone:NO];

				NSUInteger queryLength = 0;
				
				// Lock the table for writing and disable keys if supported
				[metaString setString:@""];
				[metaString appendFormat:@"LOCK TABLES %@ WRITE;\n/*!40000 ALTER TABLE %@ DISABLE KEYS */;\n\n", [tableName backtickQuotedString], [tableName backtickQuotedString]];
				
				[self writeString:metaString];
				
				// Construct the start of the insertion command
				[self writeUTF8String:[NSString stringWithFormat:@"INSERT INTO %@ (%@)\nVALUES", [tableName backtickQuotedString], [rawColumnNames componentsJoinedAndBacktickQuoted]]];
				
				// Iterate through the rows to construct a VALUES group for each
				NSUInteger rowsWrittenForTable = 0;
				NSUInteger rowsWrittenForCurrentStmt = 0;
				BOOL cleanAutoReleasePool = NO;
				
				NSAutoreleasePool *sqlExportPool = [[NSAutoreleasePool alloc] init];
				
				// Inform the delegate that we are about to start writing the data to disk
				[delegate performSelectorOnMainThread:@selector(sqlExportProcessWillBeginWritingData:) withObject:self waitUntilDone:NO];
				
				NSArray *row;
				while ((row = [streamingResult getRowAsArray]))
				{
					// Check for cancellation flag
					if ([self isCancelled]) {
						[connection cancelCurrentQuery];
						[streamingResult cancelResultLoad];
						[streamingResult release];
						[sqlExportPool release];
						free(useRawDataForColumnAtIndex);
						free(useRawHexDataForColumnAtIndex);

						goto end_cleanup;
					}

					// Update the progress
					NSUInteger progress = (NSUInteger)((rowsWrittenForTable + 1) * ([self exportMaxProgress] / rowCount));

					if (progress > lastProgressValue) {
						[self setExportProgressValue:progress];
						lastProgressValue = progress;

						// Inform the delegate that the export's progress has been updated
						[delegate performSelectorOnMainThread:@selector(sqlExportProcessProgressUpdated:) withObject:self waitUntilDone:NO];
					}

					// Set up the new row as appropriate.  If a new INSERT statement should be created,
					// set one up; otherwise, set up a new row
					if ((([self sqlInsertDivider] == SPSQLInsertEveryNDataBytes) && (queryLength >= ([self sqlInsertAfterNValue] * 1024))) ||
						(([self sqlInsertDivider] == SPSQLInsertEveryNRows) && (rowsWrittenForCurrentStmt == [self sqlInsertAfterNValue])))
					{
						[sqlString setString:@";\n\nINSERT INTO "];
						[sqlString appendString:[tableName backtickQuotedString]];
						[sqlString appendString:@" ("];
						[sqlString appendString:[rawColumnNames componentsJoinedAndBacktickQuoted]];
						[sqlString appendString:@")\nVALUES\n\t("];

						queryLength = 0;
						rowsWrittenForCurrentStmt = 0;

						// Use the opportunity to drain and reset the autorelease pool at the end of this row
						cleanAutoReleasePool = YES;
					}
					else if (rowsWrittenForTable == 0) {
						[sqlString setString:@"\n\t("];
					}
					else {
						[sqlString setString:@",\n\t("];
					}

					for (NSUInteger t = 0; t < colCount; t++)
					{
						id object = NSArrayObjectAtIndex(row, t);

						// Add NULL values directly to the output row; use a pointer comparison to the singleton
						// instance for speed.
						if (object == [NSNull null]) {
							[sqlString appendString:@"NULL"];
						}

						// Add trusted raw values directly
						else if (useRawDataForColumnAtIndex[t]) {
							[sqlString appendString:object];
						}

						// If the field is of type BIT, the values need a binary prefix of b'x'.
						else if ([[NSArrayObjectAtIndex([tableDetails objectForKey:@"columns"], t) objectForKey:@"type"] isEqualToString:@"BIT"]) {
							[sqlString appendFormat:@"b'%@'", [object description]];
						}

						// Add pre-encoded hex types (binary strings) as enclosed but otherwise trusted data
						else if (useRawHexDataForColumnAtIndex[t]) {
							[sqlString appendFormat:@"X'%@'", object];
						}

						// GEOMETRY data types directly as hex data
						else if ([object isKindOfClass:[SPMySQLGeometryData class]]) {
							[sqlString appendString:[connection escapeAndQuoteData:[object data]]];
						}

						// Add zero-length data or strings as an empty string
						else if ([object length] == 0) {
							[sqlString appendString:@"''"];
						}
						
						// Add other data types as hex data
						else if ([object isKindOfClass:[NSData class]]) {

							if ([self sqlOutputEncodeBLOBasHex]) {
								[sqlString appendString:[connection escapeAndQuoteData:object]];
							}
							else {
								NSString *data = [[NSString alloc] initWithData:object encoding:[self exportOutputEncoding]];
								
								if (data == nil) {
#warning This can corrupt data! Check if this case ever happens and if so, export as hex-string
									data = [[NSString alloc] initWithData:object encoding:NSASCIIStringEncoding];
								}
								
								[sqlString appendFormat:@"'%@'", data];
								
								[data release];
							}
						} 

						// Otherwise add a quoted string with special characters escaped
						else {
							[sqlString appendString:[connection escapeAndQuoteString:object]];
						}
						
						// Add the field separator if this isn't the last cell in the row
						if (t != ([row count] - 1)) [sqlString appendString:@","];
					}

					[sqlString appendString:@")"];
					queryLength += [sqlString length];

					// Write this row to the file
					[self writeUTF8String:sqlString];

					// Clean autorelease pool if so decided earlier
					if (cleanAutoReleasePool) {
						[sqlExportPool release];
						sqlExportPool = [[NSAutoreleasePool alloc] init];
						cleanAutoReleasePool = NO;
					}
					
					rowsWrittenForTable++;
					rowsWrittenForCurrentStmt++;
				}
				
				// Complete the command
				[self writeUTF8String:@";\n\n"];
				
				// Unlock the table and re-enable keys if supported
				[metaString setString:@""];
				[metaString appendFormat:@"/*!40000 ALTER TABLE %@ ENABLE KEYS */;\nUNLOCK TABLES;\n", [tableName backtickQuotedString]];
				
				[self writeUTF8String:metaString];
				
				// Drain the autorelease pool
				[sqlExportPool release];
			
				// Release the result set
				[streamingResult release];
			}

			free(useRawDataForColumnAtIndex);
			free(useRawHexDataForColumnAtIndex);

			if ([connection queryErrored]) {
				[errors appendFormat:@"%@\n", [connection lastErrorMessage]];
				
				if ([self sqlOutputIncludeErrors]) {
					[self writeUTF8String:[NSString stringWithFormat:@"# Error: %@\n", [connection lastErrorMessage]]];
				}
			}
		}

		// Add triggers if the structure export was enabled
		if (sqlOutputIncludeStructure) {
			SPMySQLResult *queryResult = [connection queryString:[NSString stringWithFormat:@"/*!50003 SHOW TRIGGERS WHERE `Table` = %@ */", [tableName tickQuotedString]]];
			
			[queryResult setReturnDataAsStrings:YES];
			
			if ([queryResult numberOfRows]) {
				
				[metaString setString:@"\n"];
				[metaString appendString:@"DELIMITER ;;\n"];
				
				for (NSUInteger s = 0; s < [queryResult numberOfRows]; s++)
				{
					// Check for cancellation flag
					if ([self isCancelled]) goto end_cleanup;
					
					NSDictionary *triggers = [[NSDictionary alloc] initWithDictionary:[queryResult getRowAsDictionary]];
					
					// Definer is user@host but we need to escape it to `user`@`host`
					NSArray *triggersDefiner = [[triggers objectForKey:@"Definer"] componentsSeparatedByString:@"@"];
					
					[metaString appendFormat:@"/*!50003 SET SESSION SQL_MODE=\"%@\" */;;\n/*!50003 CREATE */ ", [triggers objectForKey:@"sql_mode"]];
					[metaString appendFormat:@"/*!50017 DEFINER=%@@%@ */ /*!50003 TRIGGER %@ %@ %@ ON %@ FOR EACH ROW %@ */;;\n",
					                         [NSArrayObjectAtIndex(triggersDefiner, 0) backtickQuotedString],
					                         [NSArrayObjectAtIndex(triggersDefiner, 1) backtickQuotedString],
					                         [[triggers objectForKey:@"Trigger"] backtickQuotedString],
					                         [triggers objectForKey:@"Timing"],
					                         [triggers objectForKey:@"Event"],
					                         [[triggers objectForKey:@"Table"] backtickQuotedString],
					                         [triggers objectForKey:@"Statement"]];
					
					[triggers release];
				}
				
				[metaString appendString:@"DELIMITER ;\n/*!50003 SET SESSION SQL_MODE=@OLD_SQL_MODE */;\n"];
				
				[self writeUTF8String:metaString];
			}
			
			if ([connection queryErrored]) {
				[errors appendFormat:@"%@\n", [connection lastErrorMessage]];
				
				if ([self sqlOutputIncludeErrors]) {
					[self writeUTF8String:[NSString stringWithFormat:@"# Error: %@\n", [connection lastErrorMessage]]];
				}
			}
		}
		
		// Add an additional separator between tables
		[self writeUTF8String:@"\n\n"];
	}
	
	// Process any deferred views, adding commands to delete the placeholder tables and add the actual views
	for (NSString *viewName in viewSyntaxes)
	{
		// Check for cancellation flag
		if ([self isCancelled]) goto end_cleanup;
		
		[metaString setString:@"\n\n"];

		// Add the name of table
		[metaString appendFormat:@"# Replace placeholder table for %@ with correct view syntax\n# ------------------------------------------------------------\n\n", viewName];
		[metaString appendFormat:@"DROP TABLE %@;\n\n", [viewName backtickQuotedString]];
		[metaString appendFormat:@"%@;\n", [viewSyntaxes objectForKey:viewName]];

		[self writeUTF8String:metaString];
	}
	
	// Export procedures and functions
	for (NSString *procedureType in @[@"PROCEDURE", @"FUNCTION"])
	{
		// Check for cancellation flag
		if ([self isCancelled]) goto end_cleanup;
		
		// Retrieve the array of selected procedures or functions, and skip export if not selected
		NSMutableArray *items;
		
		if ([procedureType isEqualToString:@"PROCEDURE"]) items = procs;
		else items = funcs;
		
		if ([items count] == 0) continue;
		
		// Retrieve the definitions
		SPMySQLResult *queryResult = [connection queryString:[NSString stringWithFormat:@"/*!50003 SHOW %@ STATUS WHERE `Db` = %@ */", procedureType,
		                                                                                [[self sqlDatabaseName] tickQuotedString]]];
		
		[queryResult setReturnDataAsStrings:YES];
		
		if ([queryResult numberOfRows]) {
			
			[metaString setString:@"\n"];
			[metaString appendFormat:@"--\n-- Dumping routines (%@) for database %@\n--\nDELIMITER ;;\n\n", procedureType,
			                         [[self sqlDatabaseName] tickQuotedString]];

			// Loop through the definitions, exporting if enabled
			for (NSUInteger s = 0; s < [queryResult numberOfRows]; s++)
			{
				// Check for cancellation flag
				if ([self isCancelled]) goto end_cleanup;

				NSDictionary *proceduresList = [[NSDictionary alloc] initWithDictionary:[queryResult getRowAsDictionary]];
				NSString *procedureName = [NSString stringWithFormat:@"%@", [proceduresList objectForKey:@"Name"]];

				// Only proceed if the item is in the list of items
				BOOL itemFound = NO;
				BOOL sqlOutputIncludeStructure = NO;
				BOOL sqlOutputIncludeDropSyntax = NO;
				for (NSArray *item in items)
				{
					// Check for cancellation flag
					if ([self isCancelled]) {
						[proceduresList release];
						goto end_cleanup;
					}
					
					if ([NSArrayObjectAtIndex(item, 0) isEqualToString:procedureName]) {
						itemFound = YES;
						sqlOutputIncludeStructure  = [NSArrayObjectAtIndex(item, 1) boolValue];
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
					[metaString appendFormat:@"/*!50003 DROP %@ IF EXISTS %@ */;;\n", procedureType,
					                         [procedureName backtickQuotedString]];
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
				                                                      [NSArrayObjectAtIndex(procedureDefiner, 1) backtickQuotedString]];
				
				SPMySQLResult *createProcedureResult = [connection queryString:[NSString stringWithFormat:@"/*!50003 SHOW CREATE %@ %@ */", procedureType,
				                                                                                          [procedureName backtickQuotedString]]];
				[createProcedureResult setReturnDataAsStrings:YES];
				if ([connection queryErrored]) {
					[errors appendFormat:@"%@\n", [connection lastErrorMessage]];
					
					if ([self sqlOutputIncludeErrors]) {
						[self writeUTF8String:[NSString stringWithFormat:@"# Error: %@\n", [connection lastErrorMessage]]];
					}
					[proceduresList release];
					continue;
				}
				
				NSDictionary *procedureInfo = [[NSDictionary alloc] initWithDictionary:[createProcedureResult getRowAsDictionary]];
				
				[metaString appendFormat:@"/*!50003 SET SESSION SQL_MODE=\"%@\"*/;;\n", [procedureInfo objectForKey:@"sql_mode"]];
				
				NSString *createProcedure = [procedureInfo objectForKey:[NSString stringWithFormat:@"Create %@", [procedureType capitalizedString]]];
				
				// A NULL result indicates a permission problem
				if ([createProcedure isNSNull]) {
					NSString *errorString = [NSString stringWithFormat:NSLocalizedString(@"Could not export the %@ '%@' because of a permissions error.\n", @"Procedure/function export permission error"), procedureType, procedureName];
					[errors appendString:errorString];
					if ([self sqlOutputIncludeErrors]) {
						[self writeUTF8String:[NSString stringWithFormat:@"# Error: %@\n", errorString]];
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
				[metaString appendFormat:@"/*!50003 CREATE*/ /*!50020 DEFINER=%@*/ /*!50003 %@ */;;\n\n/*!50003 SET SESSION SQL_MODE=@OLD_SQL_MODE */;;\n", escapedDefiner, procedureBody];
				
				[procedureInfo release];
				[proceduresList release];
				
			}
			
			[metaString appendString:@"DELIMITER ;\n"];
			
			[self writeUTF8String:metaString];
		}
		
		if ([connection queryErrored]) {
			[errors appendFormat:@"%@\n", [connection lastErrorMessage]];
			
			if ([self sqlOutputIncludeErrors]) {
				[self writeUTF8String:[NSString stringWithFormat:@"# Error: %@\n", [connection lastErrorMessage]]];
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
	[self writeUTF8String:metaString];

	// Set export errors
	[self setSqlExportErrors:errors];

	// Close the file
	[[self exportOutputFile] close];
	
	// Mark the process as not running
	[self setExportProcessIsRunning:NO];
	
	// Inform the delegate that the export process is complete
	[delegate performSelectorOnMainThread:@selector(sqlExportProcessComplete:) withObject:self waitUntilDone:NO];

end_cleanup:
	if(oldSqlMode) {
		[connection queryString:[NSString stringWithFormat:@"SET SQL_MODE=%@",[oldSqlMode tickQuotedString]]];
	}
	[errors release];
	[sqlString release];
}

/**
 * Returns whether or not any export errors occurred by examing the length of the errors string.
 *
 * @return A BOOL indicating the occurrence of errors
 */
- (BOOL)didExportErrorsOccur
{
	return ([[self sqlExportErrors] length] != 0);
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
	NSUInteger i, j;
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
			NSString *length = [column objectForKey:@"length"];
			NSString *decimals = [column objectForKey:@"decimals"];
			if([decimals length]) {
				length = [length stringByAppendingFormat:@",%@", decimals];
			}
			[fieldString appendFormat:@" %@(%@)", [column objectForKey:@"type"], length];
		} 
		else if ([column objectForKey:@"values"]) {
			[fieldString appendFormat:@" %@(", [column objectForKey:@"type"]];
			
			for (j = 0; j < [[column objectForKey:@"values"] count]; j++) 
			{
				[fieldString appendString:[connection escapeAndQuoteString:NSArrayObjectAtIndex([column objectForKey:@"values"], j)]];
				if ((j + 1) != [[column objectForKey:@"values"] count]) {
					[fieldString appendString:@","];
				}
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
		if ([[column objectForKey:@"null"] integerValue] == 0) {
			[fieldString appendString:@" NOT NULL"];
		} else {
			[fieldString appendString:@" NULL"];
		}
		
		// Provide the field default if appropriate
		if ([column objectForKey:@"default"]) {
			
			// Some MySQL server versions show a default of NULL for NOT NULL columns - don't export those.
			// Check against the NSNull singleton instance for speed.
			if ([column objectForKey:@"default"] == [NSNull null]) {
				if ([[column objectForKey:@"null"] integerValue]) {
					[fieldString appendString:@" DEFAULT NULL"];
				}
			} 
			else if (([[column objectForKey:@"type"] isInArray:@[@"TIMESTAMP",@"DATETIME"]]) && [[column objectForKey:@"default"] isMatchedByRegex:SPCurrentTimestampPattern]) {
				[fieldString appendFormat:@" DEFAULT %@",[column objectForKey:@"default"]];
			} 
			else {
				[fieldString appendFormat:@" DEFAULT %@", [connection escapeAndQuoteString:[column objectForKey:@"default"]]];
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

#pragma mark -

- (void)dealloc
{
	SPClear(sqlExportTables);
	SPClear(sqlDatabaseHost);
	SPClear(sqlDatabaseName);
	SPClear(sqlExportCurrentTable);
	SPClear(sqlDatabaseVersion);
	SPClear(sqlExportErrors);
	
	[super dealloc];
}

@end

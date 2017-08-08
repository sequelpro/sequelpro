//
//  SPExportFilenameUtilities.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on July 25, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPExportFilenameUtilities.h"
#import "SPTablesList.h"
#import "SPDatabaseViewController.h"
#import "SPExportFileNameTokenObject.h"

@implementation SPExportController (SPExportFilenameUtilities)

/**
 * Updates the displayed export filename, either custom or default.
 */
- (void)updateDisplayedExportFilename
{	
	NSString *filename  = @"";
	
	if ([[exportCustomFilenameTokenField stringValue] length] > 0) {
		
		// Get the current export file extension
		NSString *extension = [self currentDefaultExportFileExtension];
		
		//note that there will be no tableName if the export is done from a query result without a database selected (or empty).
		filename = [self expandCustomFilenameFormatUsingTableName:[[tablesListInstance tables] objectOrNilAtIndex:1]];
		
		
		if (![[self customFilenamePathExtension] length] && [extension length] > 0) filename = [filename stringByAppendingPathExtension:extension];
	}
	else {
		filename = [self generateDefaultExportFilename];
	} 
	
	[exportCustomFilenameViewLabelButton setTitle:[NSString stringWithFormat:NSLocalizedString(@"Customize Filename (%@)", @"customize file name label"), filename]];
}

- (NSString *)customFilenamePathExtension
{
	NSMutableString *flatted = [NSMutableString string];
	
	// This time we replace every token with "/a". This has the following effect:
	// "{host}.{database}"     -> "/a./a"     -> extension=""
	// "{database}_{date}.sql" -> "/a_/a.sql" -> extension="sql"
	// That seems to be the easiest way to let NSString correctly determine if an extension is present
	for (id filenamePart in [exportCustomFilenameTokenField objectValue])
	{
		if([filenamePart isKindOfClass:[NSString class]])
			[flatted appendString:filenamePart];
		else if([filenamePart isKindOfClass:[SPExportFileNameTokenObject class]])
			[flatted appendString:@"/a"];
		else
			[NSException raise:NSInternalInconsistencyException format:@"unknown object in token list: %@",filenamePart];
	}
	
	return [flatted pathExtension];
}

- (BOOL)isTableTokenAllowed
{
	NSUInteger i = 0;
	BOOL removeTable = NO;
	
	BOOL isSQL = exportType == SPSQLExport;
	BOOL isCSV = exportType == SPCSVExport;
	BOOL isDot = exportType == SPDotExport;
	BOOL isXML = exportType == SPXMLExport;
	
	// Determine whether to remove the table from the tokens list
	if (exportSource == SPQueryExport || isDot) {
		removeTable = YES;
	}
	else if (isSQL || isCSV || isXML) {
		for (NSArray *table in tables)
		{
			if ([NSArrayObjectAtIndex(table, 2) boolValue]) {
				i++;
				if (i == 2) break;
			}
		}
		
		if (i > 1) {
			removeTable = isSQL ? YES : ![exportFilePerTableCheck state];
		}
	}
	
	return (removeTable == NO);
}

/**
 * Updates the available export filename tokens based on the currently selected options.
 */
- (void)updateAvailableExportFilenameTokens
{		
	SPExportFileNameTokenObject *tableObject;
	NSMutableArray *exportTokens = [NSMutableArray arrayWithObjects:
		[SPExportFileNameTokenObject tokenWithId:SPFileNameDatabaseTokenName],
		[SPExportFileNameTokenObject tokenWithId:SPFileNameHostTokenName],
		[SPExportFileNameTokenObject tokenWithId:SPFileNameDateTokenName],
		[SPExportFileNameTokenObject tokenWithId:SPFileNameYearTokenName],
		[SPExportFileNameTokenObject tokenWithId:SPFileNameMonthTokenName],
		[SPExportFileNameTokenObject tokenWithId:SPFileNameDayTokenName],
		[SPExportFileNameTokenObject tokenWithId:SPFileNameTimeTokenName],
		[SPExportFileNameTokenObject tokenWithId:SPFileName24HourTimeTokenName],
		[SPExportFileNameTokenObject tokenWithId:SPFileNameFavoriteTokenName],
		(tableObject = [SPExportFileNameTokenObject tokenWithId:SPFileNameTableTokenName]),
		nil
	];
	
	if (![self isTableTokenAllowed]) {
		[exportTokens removeObject:tableObject];
		NSArray *tokenParts = [exportCustomFilenameTokenField objectValue];
		
		for (id token in tokenParts)
		{
			if([token isEqual:tableObject]) {
				NSMutableArray *newTokens = [NSMutableArray arrayWithArray:tokenParts];
				
				[newTokens removeObject:tableObject]; //removes all occurances
				
				[exportCustomFilenameTokenField setObjectValue:newTokens];
				break;
			}
		}
	}

	[exportCustomFilenameTokenPool setObjectValue:exportTokens];
	//update preview name as programmatically changing the exportCustomFilenameTokenField does not fire a notification
	[self updateDisplayedExportFilename];
}

- (NSArray *)currentAllowedExportFilenameTokens
{
	NSArray *mixed = [exportCustomFilenameTokenPool objectValue];
	NSMutableArray *tokens = [NSMutableArray arrayWithCapacity:[mixed count]]; // ...or less
	
	for (id obj in mixed) {
		if([obj isKindOfClass:[SPExportFileNameTokenObject class]]) [tokens addObject:obj];
	}
	
	return tokens;
}

/**
 * Generates the default export filename based on the selected export options.
 *
 * @return The default filename.
 */
- (NSString *)generateDefaultExportFilename
{
	NSString *filename = @"";
	NSString *extension = [self currentDefaultExportFileExtension];
	
	// Determine what the file name should be
	switch (exportSource) 
	{
		case SPFilteredExport:
			filename = [NSString stringWithFormat:@"%@_view", [tableDocumentInstance table]];
			break;
		case SPQueryExport:
			filename = @"query_result";
			break;
		case SPTableExport:
			filename = [NSString stringWithFormat:@"%@_%@", [tableDocumentInstance database], [[NSDate date] descriptionWithCalendarFormat:@"%Y-%m-%d" timeZone:nil locale:nil]];
			break;
	}
	
	return ([extension length] > 0) ? [filename stringByAppendingPathExtension:extension] : filename;
}

/**
 * Returns the current default export file extension based on the selected export type.
 *
 * @return The default filename extension.
 */
- (NSString *)currentDefaultExportFileExtension
{
	NSString *extension = @"";
	
	switch (exportType) {
		case SPSQLExport:
			extension = SPFileExtensionSQL;
			break;
		case SPCSVExport:
			// If the tab character (\t) is selected as the feild separator return the extension as .tsv 
			extension = ([exportCSVFieldsTerminatedField indexOfSelectedItem] == 2) ? @"tsv" : @"csv";
			break;
		case SPXMLExport:
			extension = @"xml";
			break;
		case SPDotExport:
			extension = @"dot";
			break;
		case SPPDFExport:
		case SPHTMLExport:
		case SPExcelExport:
		default:
			[NSException raise:NSInvalidArgumentException format:@"unsupported exportType=%lu",exportType];
			return nil;
	}
	
	if ([exportOutputCompressionFormatPopupButton indexOfSelectedItem] != SPNoCompression) {
		
		SPFileCompressionFormat compressionFormat = (SPFileCompressionFormat)[exportOutputCompressionFormatPopupButton indexOfSelectedItem];
		
		if ([extension length] > 0) {
			extension = [extension stringByAppendingPathExtension:(compressionFormat == SPGzipCompression) ? @"gz" : @"bz2"];
		}
		else {
			extension = (compressionFormat == SPGzipCompression) ? @"gz" : @"bz2";
		}
	}
	
	return extension;
}

/**
 * Expands the custom filename format based on the selected tokens.
 * Uses the current custom filename field as a data source.
 *
 * @param table  A table name to be used within the expanded filename.
 *               Can be nil.
 *
 * @return The expanded filename.
 */
- (NSString *)expandCustomFilenameFormatUsingTableName:(NSString *)table
{
	NSMutableString *string = [NSMutableString string];
	
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];	
	[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];

	// Walk through the token field, appending token replacements or strings
	NSArray *representedFilenameParts = [exportCustomFilenameTokenField objectValue];
	
	for (id filenamePart in representedFilenameParts) 
	{
		if ([filenamePart isKindOfClass:[SPExportFileNameTokenObject class]]) {
			NSString *tokenContent = [filenamePart tokenId];

			if ([tokenContent isEqualToString:SPFileNameHostTokenName]) {
				[string appendStringOrNil:[tableDocumentInstance host]];

			} 
			else if ([tokenContent isEqualToString:SPFileNameDatabaseTokenName]) {
				[string appendStringOrNil:[tableDocumentInstance database]];

			} 
			else if ([tokenContent isEqualToString:SPFileNameTableTokenName]) {
				[string appendStringOrNil:table];
			} 
			else if ([tokenContent isEqualToString:SPFileNameDateTokenName]) {
				[dateFormatter setDateStyle:NSDateFormatterShortStyle];
				[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
				[string appendString:[dateFormatter stringFromDate:[NSDate date]]];

			} 
			else if ([tokenContent isEqualToString:SPFileNameYearTokenName]) {
				[string appendString:[[NSDate date] descriptionWithCalendarFormat:@"%Y" timeZone:nil locale:nil]];

			} 
			else if ([tokenContent isEqualToString:SPFileNameMonthTokenName]) {
				[string appendString:[[NSDate date] descriptionWithCalendarFormat:@"%m" timeZone:nil locale:nil]];

			} 
			else if ([tokenContent isEqualToString:SPFileNameDayTokenName]) {
				[string appendString:[[NSDate date] descriptionWithCalendarFormat:@"%d" timeZone:nil locale:nil]];

			} 
			else if ([tokenContent isEqualToString:SPFileNameTimeTokenName]) {
				[dateFormatter setDateStyle:NSDateFormatterNoStyle];
				[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
				[string appendString:[dateFormatter stringFromDate:[NSDate date]]];
			}
			else if ([tokenContent isEqualToString:SPFileName24HourTimeTokenName]) {
				[string appendString:[[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S" timeZone:nil locale:nil]];
			}
			else if ([tokenContent isEqualToString:SPFileNameFavoriteTokenName]) {
				[string appendStringOrNil:[tableDocumentInstance name]];
			}
		} 
		else {
			[string appendString:filenamePart];
		}
	}

	// Replace colons with hyphens
	[string replaceOccurrencesOfString:@":" 
							withString:@"-"
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [string length])];
	
	// Replace forward slashes with hyphens
	[string replaceOccurrencesOfString:@"/" 
							withString:@"-"
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [string length])];
	
	[dateFormatter release];

	// Don't allow empty strings - if an empty string resulted, revert to the default string
	if (![string length]) [string setString:[self generateDefaultExportFilename]];

	return string;
}

@end

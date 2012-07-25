//
//  $Id$
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
//  More info at <http://code.google.com/p/sequel-pro/>

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
		
		filename = [self expandCustomFilenameFormatUsingTableName:[[tablesListInstance tables] objectAtIndex:1]];
		
		if (![[filename pathExtension] length] && [extension length] > 0) filename = [filename stringByAppendingPathExtension:extension];
	}
	else {
		filename = [self generateDefaultExportFilename];
	} 
	
	[exportCustomFilenameViewLabelButton setTitle:[NSString stringWithFormat:NSLocalizedString(@"Customize Filename (%@)", @"customize file name label"), filename]];
}

/**
 * Updates the available export filename tokens based on the currently selected options.
 */
- (void)updateAvailableExportFilenameTokens
{		
	NSUInteger i = 0;
	BOOL removeTable = NO;
	
	BOOL isSQL = exportType == SPSQLExport;
	BOOL isCSV = exportType == SPCSVExport;
	BOOL isDot = exportType == SPDotExport;
	BOOL isXML = exportType == SPXMLExport;

	NSMutableArray *exportTokens = [NSMutableArray arrayWithObjects:
										NSLocalizedString(@"host", @"export filename host token"),
										NSLocalizedString(@"database", @"export filename database token"),
										NSLocalizedString(@"table", @"table"),
										NSLocalizedString(@"date", @"export filename date token"),
										NSLocalizedString(@"year", @"export filename date token"),
										NSLocalizedString(@"month", @"export filename date token"),
										NSLocalizedString(@"day", @"export filename date token"),
										NSLocalizedString(@"time", @"export filename time token"),
									nil];

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
	
	if (removeTable) {
		[exportTokens removeObject:NSLocalizedString(@"table", @"table")];
		NSArray *tokenParts = [exportCustomFilenameTokenField objectValue];
		
		for (id token in [exportCustomFilenameTokenField objectValue])
		{
			if ([token isKindOfClass:[SPExportFileNameTokenObject class]]) {
				if ([[token tokenContent] isEqualToString:NSLocalizedString(@"table", @"table")]) {
					NSMutableArray *newTokens = [NSMutableArray arrayWithArray:tokenParts];
					
					[newTokens removeObjectAtIndex:[tokenParts indexOfObject:token]];
					
					[exportCustomFilenameTokenField setObjectValue:newTokens];
					break;
				}
			}
		}
	}

	[exportCustomFilenameTokensField setStringValue:[exportTokens componentsJoinedByString:@","]];
}

/**
 * Take a supplied string and return the token for it - a SPExportFileNameTokenObject if the token
 * has been recognized, or the supplied NSString if unmatched.
 */
- (id)tokenObjectForString:(NSString *)stringToTokenize
{
	if ([[exportCustomFilenameTokensField objectValue] containsObject:stringToTokenize]) {
		SPExportFileNameTokenObject *newToken = [[SPExportFileNameTokenObject alloc] init];
		
		[newToken setTokenContent:stringToTokenize];
		
		return [newToken autorelease];
	}

	return stringToTokenize;
}

/**
 * Tokenize the filename field.
 *
 * This is called on a delay after text entry to update the tokens during text entry.
 * There's no API to perform tokenizing, but the same result can be achieved by using the return key;
 * however, this only works if the cursor is after text, not after a token.
 */
- (void)tokenizeCustomFilenameTokenField
{
	NSCharacterSet *nonAlphanumericSet = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
	NSArray *validTokens = [exportCustomFilenameTokensField objectValue];

	if ([exportCustomFilenameTokenField currentEditor] == nil) return;

	NSRange selectedRange = [[exportCustomFilenameTokenField currentEditor] selectedRange];
	
	if (selectedRange.location == NSNotFound) return;
	if (selectedRange.length > 0) return;

	// Retrieve the object value of the token field.  This consists of plain text and recognised tokens interspersed.
	NSArray *representedObjects = [exportCustomFilenameTokenField objectValue];

	// Walk through the strings - not the tokens - and determine whether any need tokenizing
	BOOL tokenizingRequired = NO;
	
	for (id representedObject in representedObjects) 
	{
		if ([representedObject isKindOfClass:[SPExportFileNameTokenObject class]]) continue;
		
		NSArray *tokenParts = [representedObject componentsSeparatedByCharactersInSet:nonAlphanumericSet];
		
		for (NSString *tokenPart in tokenParts) 
		{
			if ([validTokens containsObject:tokenPart]) {
				tokenizingRequired = YES;
				break;
			}
		}
	}

	// If no tokenizing is required, don't process any further.
	if (!tokenizingRequired) return;

	// Detect where the cursor is currently located.  If it's at the end of a token, also return -
	// or the enter key would result in closing the sheet.
	NSUInteger stringPosition = 0;
	
	for (id representedObject in representedObjects) 
	{
		if ([representedObject isKindOfClass:[SPExportFileNameTokenObject class]]) {
			stringPosition++;
		} 
		else {
			stringPosition += [(NSString *)representedObject length];
		}
		
		if (selectedRange.location <= stringPosition) {
			if ([representedObject isKindOfClass:[SPExportFileNameTokenObject class]]) return;
			break;
		}
	}

	// All conditions met - synthesize the return key to trigger tokenization.
	NSEvent *tokenizingEvent = [NSEvent keyEventWithType:NSKeyDown 
												location:NSMakePoint(0,0) 
										   modifierFlags:0 
											   timestamp:0 
											windowNumber:[[exportCustomFilenameTokenField window] windowNumber] 
												 context:[NSGraphicsContext currentContext] 
											  characters:nil 
							 charactersIgnoringModifiers:nil 
											   isARepeat:NO 
												 keyCode:0x24];
	
	[[NSApplication sharedApplication] postEvent:tokenizingEvent atStart:NO];

	// Update the filename preview
	[self updateDisplayedExportFilename];
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
			NSString *tokenContent = [filenamePart tokenContent];

			if ([tokenContent isEqualToString:NSLocalizedString(@"host", @"export filename host token")]) {
				[string appendString:[tableDocumentInstance host]];

			} 
			else if ([tokenContent isEqualToString:NSLocalizedString(@"database", @"export filename database token")]) {
				[string appendString:[tableDocumentInstance database]];

			} 
			else if ([tokenContent isEqualToString:NSLocalizedString(@"table", @"table")]) {
				[string appendString:(table) ? table : @""];
			} 
			else if ([tokenContent isEqualToString:NSLocalizedString(@"date", @"export filename date token")]) {
				[dateFormatter setDateStyle:NSDateFormatterShortStyle];
				[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
				[string appendString:[dateFormatter stringFromDate:[NSDate date]]];

			} 
			else if ([tokenContent isEqualToString:NSLocalizedString(@"year", @"export filename date token")]) {
				[string appendString:[[NSDate date] descriptionWithCalendarFormat:@"%Y" timeZone:nil locale:nil]];

			} 
			else if ([tokenContent isEqualToString:NSLocalizedString(@"month", @"export filename date token")]) {
				[string appendString:[[NSDate date] descriptionWithCalendarFormat:@"%m" timeZone:nil locale:nil]];

			} 
			else if ([tokenContent isEqualToString:NSLocalizedString(@"day", @"export filename date token")]) {
				[string appendString:[[NSDate date] descriptionWithCalendarFormat:@"%d" timeZone:nil locale:nil]];

			} 
			else if ([tokenContent isEqualToString:NSLocalizedString(@"time", @"export filename time token")]) {
				[dateFormatter setDateStyle:NSDateFormatterNoStyle];
				[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
				[string appendString:[dateFormatter stringFromDate:[NSDate date]]];
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

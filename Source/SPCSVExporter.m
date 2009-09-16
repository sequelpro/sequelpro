//
//  $Id$
//
//  SPCSVExporter.m
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

#import "SPCSVExporter.h"
#import "SPArrayAdditions.h"

@interface SPCSVExporter (PrivateAPI)

- (void)_startCSVExportInBackgroundThread;

@end

@implementation SPCSVExporter

@synthesize csvFileHandle;

@synthesize csvDataArray;
@synthesize csvDataResult;

@synthesize csvOutputFieldNames;
@synthesize csvFieldSeparatorString;
@synthesize csvEnclosingCharacterString;
@synthesize csvEscapeString;
@synthesize csvLineEndingString;
@synthesize csvNULLString;
@synthesize csvTableColumnNumericStatus;

/**
 * Start the CSV export process.
 */
- (BOOL)startExportProcess
{	
	// Check that we have all the required info before starting the export
	if ((![self csvFileHandle]) ||
		(![self csvOutputFieldNames]) ||
		(![self csvFieldSeparatorString]) ||
		(![self csvEscapeString]) ||
		(![self csvLineEndingString]) ||
		(![self csvTableColumnNumericStatus]))
	{
		return NO;
	}
		 
	// Check that the CSV output options are not just empty strings or empty arrays
	if ((![[self csvFieldSeparatorString] isEqualToString:@""]) ||
		(![[self csvEscapeString] isEqualToString:@""]) ||
		(![[self csvLineEndingString] isEqualToString:@""]) ||
		([[self csvTableColumnNumericStatus] count] != 0)) 
	{
		return NO;
	}
	
	// Check that we have at least some data to export
	if ((![self csvDataArray]) && (![self csvDataResult])) return NO;
	
	// Tell the delegate that we are starting the export process
	if (delegate && [delegate respondsToSelector:@selector(exportProcessDidStart:)]) {
		[delegate exportProcessDidStart:self];
	}
	
	[self setExportProcessIsRunning:YES];
		
	// Start the export in a new thread
	[NSThread detachNewThreadSelector:@selector(_startCSVExportInBackgroundThread) toTarget:self withObject:nil];
	
	[self setExportProcessIsRunning:NO];
	
	// Tell the delegate that the export process has ended
	if (delegate && [delegate respondsToSelector:@selector(exportProcessDidEnd:)]) {
		[delegate exportProcessDidEnd:self];
	}
	
	return YES;
}

/**
 * Stop the CSV export process by killing the export thread and cleaning up if its running.
 */
- (BOOL)stopExportProcess
{
	if (![self exportProcessIsRunning]) return NO;
	
	// Kill the running thread here
	
	return YES;
}

/**
 * Dealloc
 */
- (void)dealloc
{
	[csvFileHandle release], csvFileHandle = nil;
	[csvDataArray release], csvDataArray = nil;
	[csvDataResult release], csvDataResult = nil;
	[csvFieldSeparatorString release], csvFieldSeparatorString = nil;
	[csvEnclosingCharacterString release], csvEnclosingCharacterString = nil;
	[csvEscapeString release], csvEscapeString = nil;
	[csvLineEndingString release], csvLineEndingString = nil;
	[csvNULLString release], csvNULLString = nil;
	[csvTableColumnNumericStatus release], csvTableColumnNumericStatus = nil;
	
	[super dealloc];
}

@end

@implementation SPCSVExporter (PrivateAPI)

/**
 * Starts the export process in a background thread.
 */
- (void)_startCSVExportInBackgroundThread
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSMutableArray *csvRow     = [NSMutableArray array];
	NSMutableString *csvCell   = [NSMutableString string];
	NSMutableString *csvString = [NSMutableString string];
	
	NSScanner *csvNumericTester;
	NSString *escapedEscapeString, *escapedFieldSeparatorString, *escapedEnclosingString, *escapedLineEndString, *dataConversionString;

	BOOL csvCellIsNumeric;
	BOOL quoteFieldSeparators = [[self csvEnclosingCharacterString] isEqualToString:@""];
	
	NSUInteger i, j, startingRow, totalRows;
	
	if ([self csvDataResult] != nil && [[self csvDataResult] numOfRows]) [[self csvDataResult] dataSeek:0];
	
	// Detect and restore special characters being used as terminating or line end strings
	NSMutableString *tempSeparatorString = [NSMutableString stringWithString:[self csvFieldSeparatorString]];
		
	// Escape tabs, line endings and carriage returns
	[tempSeparatorString replaceOccurrencesOfString:@"\\t" withString:@"\t"
											options:NSLiteralSearch
											  range:NSMakeRange(0, [tempSeparatorString length])];
	
	[tempSeparatorString replaceOccurrencesOfString:@"\\n" withString:@"\n"
											options:NSLiteralSearch
											  range:NSMakeRange(0, [tempSeparatorString length])];
	
	[tempSeparatorString replaceOccurrencesOfString:@"\\r" withString:@"\r"
											options:NSLiteralSearch
											  range:NSMakeRange(0, [tempSeparatorString length])];
	
	// Set the new field separator string
	[self setCsvFieldSeparatorString:[NSString stringWithString:tempSeparatorString]];
	
	NSMutableString *tempLineEndString = [NSMutableString stringWithString:[self csvLineEndingString]];
		
	// Escape tabs, line endings and carriage returns
	[tempLineEndString replaceOccurrencesOfString:@"\\t" withString:@"\t"
										  options:NSLiteralSearch
											range:NSMakeRange(0, [tempLineEndString length])];
	
	
	[tempLineEndString replaceOccurrencesOfString:@"\\n" withString:@"\n"
										  options:NSLiteralSearch
											range:NSMakeRange(0, [tempLineEndString length])];
	
	[tempLineEndString replaceOccurrencesOfString:@"\\r" withString:@"\r"
										  options:NSLiteralSearch
											range:NSMakeRange(0, [tempLineEndString length])];
	
	// Set the new line ending string
	[self setCsvLineEndingString:[NSString stringWithString:tempLineEndString]];
	
	// Set up escaped versions of strings for substitution within the loop
	escapedEscapeString         = [[self csvEscapeString] stringByAppendingString:[self csvEscapeString]];
	escapedFieldSeparatorString = [[self csvEscapeString] stringByAppendingString:[self csvFieldSeparatorString]];
	escapedEnclosingString      = [[self csvEscapeString] stringByAppendingString:[self csvEnclosingCharacterString]];
	escapedLineEndString        = [[self csvEscapeString] stringByAppendingString:[self csvLineEndingString]];
	
	// Determine the total number of rows and starting row depending on supplied data format
	if ([self csvDataArray] == nil) {
		startingRow = [self csvOutputFieldNames] ? -1 : 0;
		totalRows = [[self csvDataResult] numOfRows];
	} 
	else {
		startingRow = [self csvOutputFieldNames] ? 0 : 1;
		totalRows = [[self csvDataArray] count];
	}
	
	// Walk through the supplied data constructing the CSV string
	for (i = startingRow; i < totalRows; i++) 
	{
		// Check if we should stop and exit the export operation
		if ([self exportProcessShouldExit]) {
			[pool release];
			
			return;
		}
		
		// Update the progress value
		if (totalRows) [self setExportProgressValue:(((i + 1) * 100) / totalRows)];
		
		// Retrieve the row from the supplied data
		if ([self csvDataArray] == nil) {
			// Header row
			[csvRow setArray:(i == -1) ? [[self csvDataResult] fetchFieldNames] : [[self csvDataResult] fetchRowAsArray]];
		} 
		else {
			[csvRow setArray:NSArrayObjectAtIndex([self csvDataArray], i)];
		}
		
		[csvString setString:@""];
		
		for (j = 0; j < [csvRow count]; j++) 
		{
			// For NULL objects supplied from a queryResult, add an unenclosed null string as per prefs
			if ([[csvRow objectAtIndex:j] isKindOfClass:[NSNull class]]) {
				[csvString appendString:[self csvNULLString]];
				
				if (j < [csvRow count] - 1) [csvString appendString:[self csvFieldSeparatorString]];
				
				continue;
			}
			
			// Retrieve the contents of this cell
			if ([NSArrayObjectAtIndex(csvRow, j) isKindOfClass:[NSData class]]) {
				dataConversionString = [[NSString alloc] initWithData:NSArrayObjectAtIndex(csvRow, j) encoding:[self exportOutputEncoding]];
				
				if (dataConversionString == nil) {
					dataConversionString = [[NSString alloc] initWithData:NSArrayObjectAtIndex(csvRow, j) encoding:NSASCIIStringEncoding];
				}
					
				[csvCell setString:[NSString stringWithString:dataConversionString]];
				[dataConversionString release];
			} 
			else {
				[csvCell setString:[NSArrayObjectAtIndex(csvRow, j) description]];
			}
			
			// For NULL values supplied via an array add the unenclosed null string as set in preferences
			if ([csvCell isEqualToString:[self csvNULLString]]) {
				[csvString appendString:[self csvNULLString]];
			} 
			// Add empty strings as a pair of enclosing characters.
			else if ([csvCell length] == 0) {
				[csvString appendString:[self csvEnclosingCharacterString]];
				[csvString appendString:[self csvEnclosingCharacterString]];
				
			} 
			else {
				// Test whether this cell contains a number
				if ([NSArrayObjectAtIndex(csvRow, j) isKindOfClass:[NSData class]]) {
					csvCellIsNumeric = NO;
				} 
				// If an array of bools supplying information as to whether the column is numeric has been supplied, use it.
				else if ([self csvTableColumnNumericStatus] != nil) {
					csvCellIsNumeric = [NSArrayObjectAtIndex([self csvTableColumnNumericStatus], j) boolValue];
				}
				// Or fall back to testing numeric content via an NSScanner.
				else {
					csvNumericTester = [NSScanner scannerWithString:csvCell];
					csvCellIsNumeric = [csvNumericTester scanFloat:nil] && 
									   [csvNumericTester isAtEnd] && 
									   ([csvCell characterAtIndex:0] != '0' || 
										[csvCell length] == 1 || 
										([csvCell length] > 1 && 
										 [csvCell characterAtIndex:1] == '.'));
				}
				
				// Escape any occurrences of the escaping character
				[csvCell replaceOccurrencesOfString:[self csvEscapeString]
										 withString:escapedEscapeString
											options:NSLiteralSearch
											  range:NSMakeRange(0, [csvCell length])];
				
				// Escape any occurrences of the enclosure string
				if (![[self csvEscapeString] isEqualToString:[self csvEnclosingCharacterString]]) {
					[csvCell replaceOccurrencesOfString:[self csvEnclosingCharacterString]
											 withString:escapedEnclosingString
												options:NSLiteralSearch
												  range:NSMakeRange(0, [csvCell length])];
				}
				
				// Escape occurrences of the line end character
				[csvCell replaceOccurrencesOfString:[self csvLineEndingString]
										 withString:escapedLineEndString
											options:NSLiteralSearch
											  range:NSMakeRange(0, [csvCell length])];
				
				// If the string isn't quoted or otherwise enclosed, escape occurrences of the field separators
				if (quoteFieldSeparators || csvCellIsNumeric) {
					[csvCell replaceOccurrencesOfString:[self csvFieldSeparatorString]
											 withString:escapedFieldSeparatorString
												options:NSLiteralSearch
												  range:NSMakeRange(0, [csvCell length])];
				}
				
				// Write out the cell data by appending strings - this is significantly faster than stringWithFormat.
				if (csvCellIsNumeric) {
					[csvString appendString:csvCell];
				} 
				else {
					[csvString appendString:[self csvEnclosingCharacterString]];
					[csvString appendString:csvCell];
					[csvString appendString:[self csvEnclosingCharacterString]];
				}
			}
			
			if (j < ([csvRow count] - 1)) [csvString appendString:[self csvFieldSeparatorString]];
		}
		
		// Append the line ending to the string for this row
		[csvString appendString:[self csvLineEndingString]];
		
		// Write it to the fileHandle
		[csvFileHandle writeData:[csvString dataUsingEncoding:[self exportOutputEncoding]]];
	}
	
	[pool release];
}

@end

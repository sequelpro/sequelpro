//
//  $Id$
//
//  SPExportFilenameUtilities.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on July 25, 2010
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPExportFilenameUtilities.h"

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
		
		filename = [self expandCustomFilenameFormatFromString:[exportCustomFilenameTokenField stringValue] usingTableName:[[tablesListInstance tables] objectAtIndex:1]];
		
		if ([extension length] > 0) filename = [filename stringByAppendingPathExtension:extension];
	}
	else {
		filename = [self generateDefaultExportFilename];
	} 
	
	[exportCustomFilenameViewLabelButton setTitle:[NSString stringWithFormat:NSLocalizedString(@"Customize Filename (%@)", @"customize file name label"), filename]];
}

/**
 * Updates the available export filename tokens.
 */
- (void)updateAvailableExportFilenameTokens
{		
	[exportCustomFilenameTokensField setStringValue:((exportSource == SPQueryExport) || (exportType == SPDotExport)) ? NSLocalizedString(@"host,database,date,time", @"custom export filename tokens without table") : NSLocalizedString(@"host,database,table,date,time", @"default custom export filename tokens")];
}

/**
 * Generates the default export filename based on the selected export options.
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
			filename = [tableDocumentInstance database];
			break;
	}
	
	return ([extension length] > 0) ? [filename stringByAppendingPathExtension:extension] : filename;
}

/**
 * Returns the current default export file extension based on the selected export type.
 */
- (NSString *)currentDefaultExportFileExtension
{
	NSString *extension = @"";
	
	switch (exportType) {
		case SPSQLExport:
			extension = SPFileExtensionSQL;
			break;
		case SPCSVExport:
			extension = @"csv";
			break;
		case SPXMLExport:
			extension = @"xml";
			break;
		case SPDotExport:
			extension = @"dot";
			break;
	}
	
	if ([exportOutputCompressionFormatPopupButton indexOfSelectedItem] != SPNoCompression) {
		
		SPFileCompressionFormat compressionFormat = [exportOutputCompressionFormatPopupButton indexOfSelectedItem];
		
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
 */
- (NSString *)expandCustomFilenameFormatFromString:(NSString *)format usingTableName:(NSString *)table
{
	NSMutableString *string = [NSMutableString stringWithString:format];
	
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	
	[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	
	[dateFormatter setDateStyle:NSDateFormatterShortStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	
	[string replaceOccurrencesOfString:NSLocalizedString(@"host", @"export filename host token") 
							withString:[tableDocumentInstance host]
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [string length])];
	
	[string replaceOccurrencesOfString:NSLocalizedString(@"database", @"export filename database token") 
							withString:[tableDocumentInstance database]
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [string length])];
	
	[string replaceOccurrencesOfString:NSLocalizedString(@"table", @"table") 
							withString:(table) ? table : @""
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [string length])];
	
	[string replaceOccurrencesOfString:NSLocalizedString(@"date", @"export filename date token") 
							withString:[dateFormatter stringFromDate:[NSDate date]]
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [string length])];
	
	[dateFormatter setDateStyle:NSDateFormatterNoStyle];
	[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	
	[string replaceOccurrencesOfString:NSLocalizedString(@"time", @"export filename time token") 
							withString:[dateFormatter stringFromDate:[NSDate date]]
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [string length])];
	
	// Strip comma separators
	[string replaceOccurrencesOfString:@"," 
							withString:@""
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [string length])];
	
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
	
	return string;
}

@end

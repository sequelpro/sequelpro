//
//  $Id$
//
//  SPExportFileUtilities.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on July 30, 2010
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

#import "SPExportFileUtilities.h"
#import "SPExporter.h"
#import "SPAlertSheets.h"
#import "SPExportFile.h"
#import "SPDatabaseDocument.h"
#import "SPCustomQuery.h"

typedef enum
{
	SPExportErrorCancelExport   = 0,
	SPExportErrorReplaceFiles   = 1,
	SPExportErrorSkipErrorFiles = 2
} SPExportErrorChoice;

@interface SPExportController (SPExportFileUtilitiesPrivateAPI)
	- (void)_reopenExportSheet;
@end

@implementation SPExportController (SPExportFileUtilities)

/**
 * Writes the CSV file header to the supplied export file.
 *
 * @param file The export file to write the header to.
 */
- (void)writeCSVHeaderToExportFile:(SPExportFile *)file
{
	NSMutableString *lineEnding = [NSMutableString stringWithString:[exportCSVLinesTerminatedField stringValue]];
	
	// Escape tabs, line endings and carriage returns
	[lineEnding replaceOccurrencesOfString:@"\\t" withString:@"\t"
								   options:NSLiteralSearch
									 range:NSMakeRange(0, [lineEnding length])];
	
	
	[lineEnding replaceOccurrencesOfString:@"\\n" withString:@"\n"
								   options:NSLiteralSearch
									 range:NSMakeRange(0, [lineEnding length])];
	
	[lineEnding replaceOccurrencesOfString:@"\\r" withString:@"\r"
								   options:NSLiteralSearch
									 range:NSMakeRange(0, [lineEnding length])];
	
	// Write the file header and the first table name
	[file writeData:[[NSMutableString stringWithFormat:@"%@: %@   %@: %@    %@: %@%@%@%@ %@%@%@",
					  NSLocalizedString(@"Host", @"export header host label"),
					  [tableDocumentInstance host], 
					  NSLocalizedString(@"Database", @"export header database label"),
					  [tableDocumentInstance database], 
					  NSLocalizedString(@"Generation Time", @"export header generation time label"),
					  [NSDate date], 
					  lineEnding, 
					  lineEnding,
					  NSLocalizedString(@"Table", @"csv export table heading"),
					  [[tables objectAtIndex:0] objectAtIndex:0],
					  lineEnding, 
					  lineEnding] dataUsingEncoding:[connection stringEncoding]]];
}

/**
 * Writes the XML file header to the supplied export file.
 *
 * @param file The export file to write the header to.
 */
- (void)writeXMLHeaderToExportFile:(SPExportFile *)file
{
	NSMutableString *header = [NSMutableString string];
	
	[header setString:@"<?xml version=\"1.0\"?>\n\n"];
	[header appendString:@"<!--\n-\n"];
	[header appendString:@"- Sequel Pro XML dump\n"];
	[header appendFormat:@"- %@ %@\n-\n", NSLocalizedString(@"Version", @"export header version label"), [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
	[header appendFormat:@"- %@\n- %@\n-\n", SPLOCALIZEDURL_HOMEPAGE, SPDevURL];
	[header appendFormat:@"- %@: %@ (MySQL %@)\n", NSLocalizedString(@"Host", @"export header host label"), [tableDocumentInstance host], [tableDocumentInstance mySQLVersion]];
	[header appendFormat:@"- %@: %@\n", NSLocalizedString(@"Database", @"export header database label"), [tableDocumentInstance database]];
	[header appendFormat:@"- %@ Time: %@\n", NSLocalizedString(@"Generation Time", @"export header generation time label"), [NSDate date]];
	[header appendString:@"-\n-->\n\n"];
	
	if ([exportXMLFormatPopUpButton indexOfSelectedItem] == SPXMLExportMySQLFormat) {
		
		NSString *tag = @"";
		
		if (exportSource == SPTableExport) {
			tag = [NSString stringWithFormat:@"<mysqldump xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n<database name=\"%@\">\n\n", [tableDocumentInstance database]];
		}
		else {
			tag = [NSString stringWithFormat:@"<resultset statement=\"%@\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n\n", (exportSource == SPFilteredExport) ? [tableContentInstance usedQuery] : [customQueryInstance usedQuery]];
		}
		
		[header appendString:tag];
	}
	else {
		[header appendFormat:@"<%@>\n\n", [[tableDocumentInstance database] HTMLEscapeString]];
	}
	
	[file writeData:[header dataUsingEncoding:NSUTF8StringEncoding]];	
}

/**
 * Indicates that one or more errors occurred while attempting to create the export file handles. Asks the 
 * user how to proceed.
 *
 * @param files An array of export files (SPExportFile) that failed to be created. 
 */
- (void)errorCreatingExportFileHandles:(NSArray *)files
{
	// Get the number of files that already exists as well as couldn't be created because of other reasons
	NSUInteger filesAlreadyExisting = 0;
	NSUInteger filesFailed = 0;
	
	for (SPExportFile *file in files) 
	{		
		if ([file exportFileHandleStatus] == SPExportFileHandleExists) {
			filesAlreadyExisting++;

		// For file handles that we failed to create for some unknown reason, ignore them and remove any 
		// exporters that are associated with them.
		} else if ([file exportFileHandleStatus] == SPExportFileHandleFailed) {
			filesFailed++;
			for (SPExporter *exporter in exporters)
			{
				if ([[exporter exportOutputFile] isEqualTo:file]) {
					[exporters removeObject:exporter];
				}
			}
		}
	}

	NSAlert *alert = [[NSAlert alloc] init];
	[alert setAlertStyle:NSCriticalAlertStyle];

	// If files failed because they already existed, show a OS-like dialog.
	if (filesAlreadyExisting) {

		// Set up a string for use if files had to be skipped.
		NSString *additionalErrors = filesFailed ? NSLocalizedString(@"\n\n(In addition, one or more errors occurred while attempting to create the export files: %lu could not be created.  These will be ignored.", @"Additional export file errors") : @"";

		if (filesAlreadyExisting == 1) {
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"“%@” already exists. Do you want to replace it?", @"Export file already exists message"), [[[files objectAtIndex:0] exportFilePath] lastPathComponent]]];
			[alert setInformativeText:[NSString stringWithFormat:@"%@%@", NSLocalizedString(@"A file with the same name already exists in the target folder. Replacing it will overwrite its current contents.", @"Export file already exists explanatory text"), additionalErrors]];
		} else if (filesAlreadyExisting == [exportFiles count]) {
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"All the export files already exist. Do you want to replace them?", @"All export files already exist message")]];
			[alert setInformativeText:[NSString stringWithFormat:@"%@%@", NSLocalizedString(@"Files with the same names already exist in the target folder. Replacing them will overwrite their current contents.", @"All export files already exist explanatory text"), additionalErrors]];
		} else {
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"%lu files already exist. Do you want to replace them?", @"Export file already exists message"), filesAlreadyExisting]];
			[alert setInformativeText:[NSString stringWithFormat:@"%@%@", [NSString stringWithFormat:NSLocalizedString(@"%lu files with the same names already exist in the target folder. Replacing them will overwrite their current contents.", @"Some export files already exist explanatory text"), filesAlreadyExisting], additionalErrors]];
		}

		[alert addButtonWithTitle:NSLocalizedString(@"Replace", @"Replace button")];
		[[[alert buttons] objectAtIndex:0] setTag:SPExportErrorReplaceFiles];
		[[[alert buttons] objectAtIndex:0] setKeyEquivalent:@"r"];
		[[[alert buttons] objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];

		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
		[[[alert buttons] objectAtIndex:1] setTag:SPExportErrorCancelExport];
		[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\r"];
		
		if ((filesAlreadyExisting + filesFailed) != [exportFiles count]) {
			[alert addButtonWithTitle:NSLocalizedString(@"Skip existing", @"skip existing button")];
			[[[alert buttons] objectAtIndex:2] setTag:SPExportErrorSkipErrorFiles];
			[[[alert buttons] objectAtIndex:2] setKeyEquivalent:@"s"];
			[[[alert buttons] objectAtIndex:2] setKeyEquivalentModifierMask:NSCommandKeyMask];
		}

	// If one or multiple files failed, but only due to unhandled errors, show a short dialog
	} else {
		if (filesFailed == 1) {
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"“%@” could not be created", @"Export file creation error title"), [[[files objectAtIndex:0] exportFilePath] lastPathComponent]]];
			[alert setInformativeText:NSLocalizedString(@"An unhandled error occurred when attempting to create the export file.  Please check the details and try again.", @"Export file creation error explanatory text")];
		} else if (filesFailed == [exportFiles count]) {
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"No files could be created", @"All export files creation error title")]];
			[alert setInformativeText:NSLocalizedString(@"An unhandled error occurred when attempting to create each of the export files.  Please check the details and try again.", @"All export files creation error explanatory text")];
		} else {
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"%lu files could not be created", @"Export files creation error title"), filesFailed]];
			[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"An unhandled error occurred when attempting to create %lu of the export files.  Please check the details and try again.", @"Export files creation error explanatory text"), filesFailed]];
		}
	

		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
		[[[alert buttons] objectAtIndex:0] setTag:SPExportErrorCancelExport];

		if (filesFailed != [exportFiles count]) {
			[alert addButtonWithTitle:NSLocalizedString(@"Skip problems", @"skip problems button")];
			[[[alert buttons] objectAtIndex:1] setTag:SPExportErrorSkipErrorFiles];
			[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"s"];
			[[[alert buttons] objectAtIndex:1] setKeyEquivalentModifierMask:NSCommandKeyMask];
		}
	}

	// Close the progress sheet
	[NSApp endSheet:exportProgressWindow returnCode:0];
	[exportProgressWindow orderOut:self];
	
	[alert beginSheetModalForWindow:[tableDocumentInstance parentWindow] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:files];
}

/**
 * NSAlert didEnd method.
 */
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	NSArray *files = (NSArray *)contextInfo;
	
	// Ignore the files that exist and remove the associated exporters
	if (returnCode == SPExportErrorSkipErrorFiles) {
		
		for (SPExportFile *file in files) {

			// Use a numerically controlled loop to avoid mutating the collection while enumerating
			NSUInteger i;
			for (i = 0; i < [exporters count]; i++) {
				SPExporter *exporter = [exporters objectAtIndex:i];
				if ([[exporter exportOutputFile] isEqualTo:file]) {
					[exporters removeObjectAtIndex:i];
					i--;
				}
			}
		}
		
		[files release];
		
		// If we're now left with no exporters, cancel the export operation
		if ([exporters count] == 0) {
			[exportFiles removeAllObjects];

			// Trigger restoration of the export interface
			[self performSelector:@selector(_reopenExportSheet) withObject:nil afterDelay:0.1];
		}
		else {
			// Start the export after a short delay to give this sheet a chance to close
			[self performSelector:@selector(startExport) withObject:nil afterDelay:0.1];
		}
	}
	// Overwrite the files and continue
	else if (returnCode == SPExportErrorReplaceFiles) {
				
		for (SPExportFile *file in files)
		{
			if ([file exportFileHandleStatus] == SPExportFileHandleExists) {
				
				if ([file createExportFileHandle:YES] == SPExportFileHandleCreated) {
					[file setCompressionFormat:[exportOutputCompressionFormatPopupButton indexOfSelectedItem]];
					
					if ([file exportFileNeedsCSVHeader]) {
						[self writeCSVHeaderToExportFile:file];
					}
					else if ([file exportFileNeedsXMLHeader]) {
						[self writeXMLHeaderToExportFile:file];
					}
				}
			}
		}
		
		[files release];
		
		// Start the export after a short delay to give this sheet a chance to close
		[self performSelector:@selector(startExport) withObject:nil afterDelay:0.1];
		
	}
	// Cancel the entire export operation
	else if (returnCode == SPExportErrorCancelExport) {
		
		// Loop the cached export files and remove those we've already created
		for (SPExportFile *file in exportFiles)
		{
			[file delete];
		}
		
		[files release];
		
		// Finally get rid of all the exporters and files
		[exportFiles removeAllObjects];
		[exporters removeAllObjects];

		// Trigger restoration of the export interface
		[self performSelector:@selector(_reopenExportSheet) withObject:nil afterDelay:0.1];
	}
}

@end

@implementation SPExportController (SPExportFileUtilitiesPrivateAPI)

/**
 * Re-open the export sheet without resetting the interface - for use on error.
 */
- (void)_reopenExportSheet
{
	[NSApp beginSheet:[self window]
	   modalForWindow:[tableDocumentInstance parentWindow]
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

@end

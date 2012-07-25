//
//  $Id$
//
//  SPXMLExporterDelegate.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on April 6, 2010.
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

#import "SPXMLExporterDelegate.h"
#import "SPXMLExporter.h"
#import "SPDatabaseDocument.h"
#import "SPExportFile.h"

#import <SPMySQL/SPMySQL.h>

@implementation SPExportController (SPXMLExporterDelegate)

- (void)xmlExportProcessWillBegin:(SPXMLExporter *)exporter
{
	[[exportProgressText onMainThread] displayIfNeeded];
	
	[[exportProgressIndicator onMainThread] setIndeterminate:YES];
	[[exportProgressIndicator onMainThread] setUsesThreadedAnimation:YES];
	[[exportProgressIndicator onMainThread] startAnimation:self];
	
	// Only update the progress text if this is a table export
	if (exportSource == SPTableExport) {
		
		// Update the current table export index
		currentTableExportIndex = (exportTableCount - [exporters count]);
		
		[[exportProgressText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Fetching data...", @"export label showing that the app is fetching data for a specific table"), currentTableExportIndex, exportTableCount, [exporter xmlTableName]]];
	}
	else {
		[[exportProgressText onMainThread] setStringValue:NSLocalizedString(@"Fetching data...", @"export label showing that the app is fetching data")];
	}
	
	[[exportProgressText onMainThread] displayIfNeeded];
}

- (void)xmlExportProcessComplete:(SPXMLExporter *)exporter
{
	NSUInteger exportCount = [exporters count];
	
	// If required add the next exporter to the operation queue
	if ((exportCount > 0) && (exportSource == SPTableExport)) {
		
		// If we're exporting to multiple files then close the file handle of the exporter
		// that just finished, ensuring its data is written to disk.
		if (exportToMultipleFiles) {
			NSString *string = @"";
			
			if ([exporter xmlFormat] == SPXMLExportMySQLFormat) {
				string = (exportSource == SPTableExport) ? @"</database>\n</mysqldump>\n" : @"</resultset>\n";;
			}
			else if ([exporter xmlFormat] == SPXMLExportPlainFormat) {
				string = [NSString stringWithFormat:@"</%@>\n", [[tableDocumentInstance database] HTMLEscapeString]];
			}
			
			[[exporter exportOutputFile] writeData:[string dataUsingEncoding:[connection stringEncoding]]];
			[[exporter exportOutputFile] close]; 
		}
		
		[operationQueue addOperation:[exporters objectAtIndex:0]];
		
		// Remove the exporter we just added to the operation queue from our list of exporters 
		// so we know it's already been done.
		[exporters removeObjectAtIndex:0];
	}
	// Otherwise if the exporter list is empty, close the progress sheet
	else {
		NSString *string = @"";
		
		if ([exporter xmlFormat] == SPXMLExportMySQLFormat) {
			string = (exportSource == SPTableExport) ? @"</database>\n</mysqldump>\n" : @"</resultset>\n";;
		}
		else if ([exporter xmlFormat] == SPXMLExportPlainFormat) {
			string = [NSString stringWithFormat:@"</%@>\n", [[tableDocumentInstance database] HTMLEscapeString]];
		}
		
		[[exporter exportOutputFile] writeData:[string dataUsingEncoding:[connection stringEncoding]]];
		[[exporter exportOutputFile] close]; 
		
		[NSApp endSheet:exportProgressWindow returnCode:0];
		[exportProgressWindow orderOut:self];
		
		// Restore query mode
		[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
		
		// Display Growl notification
		[self displayExportFinishedGrowlNotification];
	}
}

- (void)xmlExportProcessProgressUpdated:(SPXMLExporter *)exporter
{
	[[exportProgressIndicator onMainThread] setDoubleValue:[exporter exportProgressValue]];
}

- (void)xmlExportProcessWillBeginWritingData:(SPXMLExporter *)exporter
{
	// Only update the progress text if this is a table export
	if (exportSource == SPTableExport) {
		[[exportProgressText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Writing data...", @"export label showing app if writing data for a specific table"), currentTableExportIndex, exportTableCount, [exporter xmlTableName]]];
	}
	else {
		[[exportProgressText onMainThread] setStringValue:NSLocalizedString(@"Writing data...", @"export label showing app is writing data")];
	}
	
	[[exportProgressText onMainThread] displayIfNeeded];
	
	[[exportProgressIndicator onMainThread] stopAnimation:self];
	[[exportProgressIndicator onMainThread] setUsesThreadedAnimation:NO];
	[[exportProgressIndicator onMainThread] setIndeterminate:NO];
	[[exportProgressIndicator onMainThread] setDoubleValue:0];
}

@end

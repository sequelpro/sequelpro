//
//  $Id$
//
//  SPXMLExporterDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on April 6, 2010
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

#import "SPXMLExporterDelegate.h"
#import "SPXMLExporter.h"
#import "SPMainThreadTrampoline.h"
#import "TableDocument.h"
#import "SPFileHandle.h"
#import "SPStringAdditions.h"

@implementation SPExportController (SPXMLExporterDelegate)

/**
 *
 */
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

/**
 * 
 */
- (void)xmlExportProcessComplete:(SPXMLExporter *)exporter
{
	NSUInteger exportCount = [exporters count];
	
	// If required add the next exporter to the operation queue
	if ((exportCount > 0) && (exportSource == SPTableExport)) {
		
		// If we're exporting to multiple files then close the file handle of the exporter
		// that just finished, ensuring its data is written to disk.
		if (exportToMultipleFiles) {
			[[exporter exportOutputFileHandle] writeData:[[NSString stringWithFormat:@"</%@>\n", [[tableDocumentInstance database] HTMLEscapeString]] dataUsingEncoding:[connection encoding]]];
			
			[[exporter exportOutputFileHandle] closeFile]; 
		}
		
		[operationQueue addOperation:[exporters objectAtIndex:0]];
		
		// Remove the exporter we just added to the operation queue from our list of exporters 
		// so we know it's already been done.
		[exporters removeObjectAtIndex:0];
	}
	// Otherwise if the exporter list is empty, close the progress sheet
	else {
		[[exporter exportOutputFileHandle] writeData:[[NSString stringWithFormat:@"</%@>\n", [[tableDocumentInstance database] HTMLEscapeString]] dataUsingEncoding:[connection encoding]]];
		
		// Close the last exporter's file handle
		[[exporter exportOutputFileHandle] closeFile]; 
		
		[NSApp endSheet:exportProgressWindow returnCode:0];
		[exportProgressWindow orderOut:self];
		
		// Restore query mode
		[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
	}
}

/**
 *
 */
- (void)xmlExportProcessProgressUpdated:(SPXMLExporter *)exporter
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

/**
 *
 */
- (void)xmlExportProcessWillBeginWritingData:(SPXMLExporter *)exporter
{
	[exportProgressIndicator setDoubleValue:[exporter exportProgressValue]];
}

@end

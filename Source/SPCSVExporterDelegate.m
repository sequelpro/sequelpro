//
//  $Id$
//
//  SPCSVExporterDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on March 21, 2010
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

#import <Cocoa/Cocoa.h>

#import "SPCSVExporter.h"
#import "SPCSVExporterDelegate.h"
#import "SPDatabaseDocument.h"
#import "SPMainThreadTrampoline.h"
#import "SPFileHandle.h"

@implementation SPExportController (SPCSVExporterDelegate)

/**
 *
 */
- (void)csvExportProcessWillBegin:(SPCSVExporter *)exporter
{	
	[[exportProgressText onMainThread] displayIfNeeded];
	
	[[exportProgressIndicator onMainThread] setIndeterminate:YES];
	[[exportProgressIndicator onMainThread] setUsesThreadedAnimation:YES];
	[[exportProgressIndicator onMainThread] startAnimation:self];
	
	// Only update the progress text if this is a table export
	if (exportSource == SPTableExport) {
		// Update the current table export index
		currentTableExportIndex = (exportTableCount - [exporters count]);
		
		[[exportProgressText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Fetching data...", @"export label showing that the app is fetching data for a specific table"), currentTableExportIndex, exportTableCount, [exporter csvTableName]]];
	}
	else {
		[[exportProgressText onMainThread] setStringValue:NSLocalizedString(@"Fetching data...", @"export label showing that the app is fetching data")];
	}
		
	[[exportProgressText onMainThread] displayIfNeeded];
}

/**
 * 
 */
- (void)csvExportProcessComplete:(SPCSVExporter *)exporter
{		
	NSUInteger exportCount = [exporters count];
	
	// If required add the next exporter to the operation queue
	if ((exportCount > 0) && (exportSource == SPTableExport)) {
			
		// If we're only exporting to a single file then write a header for the next table
		if (!exportToMultipleFiles) {
			
			// If we're exporting multiple tables to a single file then append some space and the next table's
			// name, but only if there is at least 2 exportes left.
			[[exporter exportOutputFile] writeData:[[NSString stringWithFormat:@"%@%@%@ %@%@%@", 
														   [exporter csvLineEndingString], 
														   [exporter csvLineEndingString],
														   NSLocalizedString(@"Table", @"csv export table heading"),
														   [(SPCSVExporter *)[exporters objectAtIndex:0] csvTableName],
														   [exporter csvLineEndingString],
														   [exporter csvLineEndingString]] dataUsingEncoding:[exporter exportOutputEncoding]]];
		}
		// Otherwise close the file handle of the exporter that just finished 
		// ensuring it's data is written to disk.
		else {
			[[exporter exportOutputFile] close];
		}
		
		[operationQueue addOperation:[exporters objectAtIndex:0]];
		
		// Remove the exporter we just added to the operation queue from our list of exporters 
		// so we know it's already been done.
		[exporters removeObjectAtIndex:0];
	}
	// Otherwise if the exporter list is empty, close the progress sheet
	else {
		// Close the last exporter's file handle
		[[exporter exportOutputFile] close];
		
		[NSApp endSheet:exportProgressWindow returnCode:0];
		[exportProgressWindow orderOut:self];
		
		// Restore query mode
		[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
		
		// Display Growl notification
		[self displayExportFinishedGrowlNotification];
	}
}

/**
 *
 */
- (void)csvExportProcessWillBeginWritingData:(SPCSVExporter *)exporter
{
	// Only update the progress text if this is a table export
	if (exportSource == SPTableExport) {
		[[exportProgressText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Writing data...", @"export label showing app if writing data for a specific table"), currentTableExportIndex, exportTableCount, [exporter csvTableName]]];
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
- (void)csvExportProcessProgressUpdated:(SPCSVExporter *)exporter
{		
	[exportProgressIndicator setDoubleValue:[exporter exportProgressValue]];
}

@end

//
//  $Id$
//
//  SPSQLExporterDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on March 28, 2010
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

#import "SPSQLExporterDelegate.h"
#import "SPSQLExporter.h"
#import "TableDocument.h"
#import "SPMainThreadTrampoline.h"

@implementation SPExportController (SPSQLExporterDelegate)

/**
 *
 */
- (void)sqlExportProcessWillBegin:(SPSQLExporter *)exporter
{
	[[exportProgressTitle onMainThread] setStringValue:NSLocalizedString(@"Exporting SQL", @"text showing that the application is exporting SQL")];
	[[exportProgressText onMainThread] setStringValue:NSLocalizedString(@"Dumping...", @"text showing that app is writing dump")];
	
	[[exportProgressTitle onMainThread] displayIfNeeded];
	[[exportProgressText onMainThread] displayIfNeeded];
}

/**
 * 
 */
- (void)sqlExportProcessComplete:(SPSQLExporter *)exporter
{
	[NSApp endSheet:exportProgressWindow returnCode:0];
	[exportProgressWindow orderOut:self];
		
	[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
	
	// Restore the connection encoding to it's pre-export value
	[tableDocumentInstance setConnectionEncoding:[NSString stringWithFormat:@"%@%@", sqlPreviousConnectionEncoding, (sqlPreviousConnectionEncodingViaLatin1) ? @"-" : @""] reloadingViews:NO];
	
	// Display Growl notification
	[self displayExportFinishedGrowlNotification];
	
	// Check for errors and display the errors sheet if necessary
	if ([exporter didExportErrorsOccur]) {
		[self openExportErrorsSheetWithString:[exporter sqlExportErrors]];
	}
}

/**
 *
 */
- (void)sqlExportProcessProgressUpdated:(SPSQLExporter *)exporter
{
	//NSLog(@"updating: %f", [exporter exportProgressValue]);
	
	[exportProgressIndicator setDoubleValue:[exporter exportProgressValue]];
}

/**
 *
 */
- (void)sqlExportProcessWillBeginFetchingData:(SPSQLExporter *)exporter
{
	// Update the current table export index
	currentTableExportIndex = (exportTableCount - [exporters count]);
	
	[[exportProgressText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Fetching data...", @"export label showing that the app is fetching data for a specific table"), currentTableExportIndex, exportTableCount, [exporter sqlExportCurrentTable]]];
		
	[[exportProgressText onMainThread] displayIfNeeded];
	
	[[exportProgressIndicator onMainThread] stopAnimation:self];
	[[exportProgressIndicator onMainThread] setUsesThreadedAnimation:NO];
	[[exportProgressIndicator onMainThread] setIndeterminate:NO];
	[[exportProgressIndicator onMainThread] setDoubleValue:0];
}

/**
 * 
 */
- (void)sqlExportProcessWillBeginWritingData:(SPSQLExporter *)exporter
{
	[[exportProgressText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Writing data...", @"export label showing app if writing data for a specific table"), currentTableExportIndex, exportTableCount, [exporter sqlExportCurrentTable]]];
	
	[[exportProgressText onMainThread] displayIfNeeded];
}

@end

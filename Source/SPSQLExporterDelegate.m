//
//  $Id$
//
//  SPSQLExporterDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on March 28, 2010.
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

#import "SPSQLExporterDelegate.h"
#import "SPSQLExporter.h"
#import "SPDatabaseDocument.h"

@implementation SPExportController (SPSQLExporterDelegate)

- (void)sqlExportProcessWillBegin:(SPSQLExporter *)exporter
{
	[[exportProgressTitle onMainThread] setStringValue:NSLocalizedString(@"Exporting SQL", @"text showing that the application is exporting SQL")];
	[[exportProgressText onMainThread] setStringValue:NSLocalizedString(@"Dumping...", @"text showing that app is writing dump")];
	
	[[exportProgressTitle onMainThread] displayIfNeeded];
	[[exportProgressText onMainThread] displayIfNeeded];
}

- (void)sqlExportProcessComplete:(SPSQLExporter *)exporter
{
	[exportProgressIndicator stopAnimation:self];
	[NSApp endSheet:exportProgressWindow returnCode:0];
	[exportProgressWindow orderOut:self];
		
	[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
	
	// Restore the connection encoding to it's pre-export value
	[tableDocumentInstance setConnectionEncoding:[NSString stringWithFormat:@"%@%@", previousConnectionEncoding, (previousConnectionEncodingViaLatin1) ? @"-" : @""] reloadingViews:NO];
	
	// Display Growl notification
	[self displayExportFinishedGrowlNotification];
	
	// Check for errors and display the errors sheet if necessary
	if ([exporter didExportErrorsOccur]) {
		[self openExportErrorsSheetWithString:[exporter sqlExportErrors]];
	}
}

- (void)sqlExportProcessProgressUpdated:(SPSQLExporter *)exporter
{
	if ([exportProgressIndicator doubleValue] == 0) {
		[exportProgressIndicator stopAnimation:self];
		[exportProgressIndicator setIndeterminate:NO];
	}
	
	[exportProgressIndicator setDoubleValue:[exporter exportProgressValue]];
}

- (void)sqlExportProcessWillBeginFetchingData:(SPSQLExporter *)exporter
{
	[exportProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Fetching data...", @"export label showing that the app is fetching data for a specific table"), [exporter sqlCurrentTableExportIndex], exportTableCount, [exporter sqlExportCurrentTable]]];
	
	[exportProgressIndicator startAnimation:self];
	[exportProgressIndicator setUsesThreadedAnimation:YES];
	[exportProgressIndicator setIndeterminate:YES];
	[exportProgressIndicator setDoubleValue:0];
}

- (void)sqlExportProcessWillBeginWritingData:(SPSQLExporter *)exporter
{
	[exportProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Writing data...", @"export label showing app if writing data for a specific table"), [exporter sqlCurrentTableExportIndex], exportTableCount, [exporter sqlExportCurrentTable]]];
}

@end

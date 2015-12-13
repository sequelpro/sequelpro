//
//  SPDotExportHander.m
//  sequel-pro
//
//  Created by Max Lohrmann on 24.11.15.
//  Copyright (c) 2015 Max Lohrmann. All rights reserved.
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

#import <SPMySQL/SPMySQL.h>
#import "SPDotExportHandler.h"
#import "SPExporterRegistry.h"
#import "SPExportController.h"
#import "SPExportFile.h"
#import "SPDotExporter.h"
#import "SPExportHandlerFactory.h"
#import "SPDatabaseDocument.h"
#import "SPExportInitializer.h"
#import "SPBaseExportHandler_Protected.h"

#pragma mark -

@interface SPDotExportHandlerFactory : NSObject <SPExportHandlerFactory>
// see protocol
@end

@interface SPDotExportViewController : NSViewController {
	// Dot
	IBOutlet NSButton *exportDotForceLowerTableNamesCheck;
}

@end

#pragma mark -

@implementation SPDotExportHandler

@synthesize serverLowerCaseTableNameValue = serverLowerCaseTableNameValue;

- (instancetype)initWithFactory:(SPDotExportHandlerFactory *)factory {
	if ((self = [super initWithFactory:factory])) {
		[self setServerLowerCaseTableNameValue:NSMixedState];
		[self setCanBeImported:NO];
		[self setIsValidForExport:YES]; //always
		SPDotExportViewController *viewController = [[[SPDotExportViewController alloc] init] autorelease];
		[viewController setRepresentedObject:self];
		[self setAccessoryViewController:viewController];
		[self setFileExtension:@"dot"];
	}
	return self;
}

- (void)willBecomeActive
{
	// When switching to Dot export, ensure the server's lower_case_table_names value is checked the first time
	// to set the export's link case sensitivity setting
	if ([self serverLowerCaseTableNameValue] == NSMixedState) {

		SPMySQLResult *caseResult = [[[self controller] connection] queryString:@"SHOW VARIABLES LIKE 'lower_case_table_names'"];

		[caseResult setReturnDataAsStrings:YES];

		if ([caseResult numberOfRows] == 1) {
			NSInteger value = [[[caseResult getRowAsDictionary] objectForKey:@"Value"] integerValue]; // can be 0,1,2
			[self setServerLowerCaseTableNameValue:(value? NSOnState : NSOffState)];
		}
		else {
			[self setServerLowerCaseTableNameValue:NSOffState];
		}
	}
}

- (SPExportersAndFiles)allExporters
{
	SPDatabaseDocument *tdi = [[self controller] tableDocumentInstance];

	NSArray *exportTables = [tdi allTableNames];
	// Cache the number of tables being exported
	exportTableCount = [exportTables count];

	SPDotExporter *dotExporter = [[SPDotExporter alloc] initWithDelegate:self];

	[dotExporter setDotTableData:[[self controller] tableDataInstance]];
	[dotExporter setDotForceLowerTableNames:([self serverLowerCaseTableNameValue] == NSOnState)];
	[dotExporter setDotDatabaseHost:[tdi host]];
	[dotExporter setDotDatabaseName:[tdi database]];
	[dotExporter setDotDatabaseVersion:[tdi mySQLVersion]];

	[dotExporter setDotExportTables:exportTables];

	SPExportFile *file = [[self controller] exportFileForTableName:nil];

	[dotExporter setExportOutputFile:file];

	SPExportersAndFiles result = {@[dotExporter],@[file]};
	[dotExporter autorelease];

	return result;
}

- (NSDictionary *)settings
{
	return @{
		//without the explicit @YES/@NO the exported object would be an int
		@"DotForceLowerTableNames": (([self serverLowerCaseTableNameValue] == NSOnState)? @YES : @NO)
	};
}

- (void)applySettings:(NSDictionary *)settings
{
	id o;
	if((o = [settings objectForKey:@"DotForceLowerTableNames"])) [self setServerLowerCaseTableNameValue:[o boolValue]];
}

#pragma mark - Exporter delegate

- (void)dotExportProcessWillBegin:(SPDotExporter *)exporter
{
	[[self controller] setExportProgressTitle:NSLocalizedString(@"Exporting Dot File", @"text showing that the application is exporting a Dot file")];
	[[self controller] setExportProgressDetail:NSLocalizedString(@"Dumping...", @"text showing that app is writing dump")];

	[[self controller] setExportProgressIndeterminate:NO];
}

- (void)dotExportProcessComplete:(SPDotExporter *)exporter
{
	[[self controller] exportEnded:exporter];
}

- (void)dotExportProcessProgressUpdated:(SPDotExporter *)exporter
{
	[[self controller] setExportProgress:[exporter exportProgressValue]];
}

- (void)dotExportProcessWillBeginFetchingData:(SPDotExporter *)exporter forTableWithIndex:(NSUInteger)tableIndex
{
	// Update the current table export index
	currentTableExportIndex = tableIndex;

	[[self controller] setExportProgressDetail:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Fetching data...", @"export label showing that the app is fetching data for a specific table"), currentTableExportIndex, exportTableCount, [exporter dotExportCurrentTable]]];
}

- (void)dotExportProcessWillBeginFetchingRelationsData:(SPDotExporter *)exporter
{
	[[self controller] setExportProgressDetail:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Fetching relations data...", @"export label showing app is fetching relations data for a specific table"), currentTableExportIndex, exportTableCount, [exporter dotExportCurrentTable]]];
	[[self controller] setExportProgressIndeterminate:YES];
}

@end

#pragma mark -

@implementation SPDotExportHandlerFactory

+ (void)load {
	[super load];
	[[SPExporterRegistry sharedRegistry] registerExportHandler:[[[self alloc] init] autorelease]];
}

- (id<SPExportHandlerInstance>)makeInstanceWithController:(SPExportController *)ctr
{
	id instance = [[SPDotExportHandler alloc] initWithFactory:self];
	[instance setController:ctr];
	return [instance autorelease];
}

- (NSString *)uniqueName {
	return @"SPDotExporter";
}

- (NSString *)localizedShortName {
	return NSLocalizedString(@"Dot","dot exporter short name");
}

- (BOOL)supportsExportToMultipleFiles {
	return NO;
}

- (BOOL)supportsExportSource:(SPExportSource)source {
	return (source == SPDatabaseExport);
}

@end

#pragma mark -

@implementation SPDotExportViewController

- (instancetype)init
{
	if((self = [super initWithNibName:@"DotExportAccessory" bundle:nil])) {

	}
	return self;
}

@end

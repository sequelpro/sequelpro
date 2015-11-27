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

#import "SPDotExportHandler.h"
#import "SPExporterRegistry.h"
#import "SPExportController.h"
#import "SPExportFile.h"
#import "SPDotExporter.h"
#import "SPExportHandlerFactory.h"

#pragma mark -

@interface SPDotExportHandlerFactory : NSObject <SPExportHandlerFactory>
// see protocol
@end

@interface SPDotExportViewController : NSViewController {
@public
	// Dot
	IBOutlet NSButton *exportDotForceLowerTableNamesCheck;
}

@end

#pragma mark -

@implementation SPDotExportHandler

- (instancetype)initWithFactory:(SPDotExportHandlerFactory *)factory {
	if ((self = [super initWithFactory:factory])) {
		[self setCanBeImported:NO];
		[self setIsValidForExport:YES]; //always
		SPDotExportViewController *viewController = [[[SPDotExportViewController alloc] init] autorelease];
		[viewController setRepresentedObject:self];
		[self setAccessoryViewController:viewController];
		[self setFileExtension:@"dot"];
	}
	return self;
}

- (SPExportersAndFiles)allExporters {
	return ((SPExportersAndFiles){nil,nil});
//	// Cache the number of tables being exported
//	exportTableCount = [exportTables count];
//
//	SPDotExporter *dotExporter = [[SPDotExporter alloc] initWithDelegate:self];
//
//	[dotExporter setDotTableData:tableDataInstance];
//	[dotExporter setDotForceLowerTableNames:[exportDotForceLowerTableNamesCheck state]];
//	[dotExporter setDotDatabaseHost:[tableDocumentInstance host]];
//	[dotExporter setDotDatabaseName:[tableDocumentInstance database]];
//	[dotExporter setDotDatabaseVersion:[tableDocumentInstance mySQLVersion]];
//
//	[dotExporter setDotExportTables:exportTables];
//
//	// Create custom filename if required
//	if (createCustomFilename) {
//		[exportFilename setString:[self expandCustomFilenameFormatUsingTableName:nil]];
//	}
//	else {
//		[exportFilename setString:[tableDocumentInstance database]];
//	}
//
//	// Only append the extension if necessary
//	if (![[exportFilename pathExtension] length]) {
//		[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
//	}
//
//	SPExportFile *file = [SPExportFile exportFileAtPath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
//
//	[dotExporter setExportOutputFile:file];
//
//	SPExportersAndFiles result = {@[dotExporter],@[file]};
//	[dotExporter autorelease];
//
//	return result;
}

- (NSDictionary *)settings
{
	return nil;
//	return @{@"DotForceLowerTableNames": IsOn(exportDotForceLowerTableNamesCheck)};
}

- (void)applySettings:(NSDictionary *)settings
{
	id o;
//	if((o = [settings objectForKey:@"DotForceLowerTableNames"])) SetOnOff(o, exportDotForceLowerTableNamesCheck);
}

- (id)specificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type
{
	// Dot is a graph of the whole database - nothing to pick from
	return nil;
}

- (void)applySpecificSettings:(id)settings forSchemaObject:(NSString *)name ofType:(SPTableType)type
{
	//should never be called
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

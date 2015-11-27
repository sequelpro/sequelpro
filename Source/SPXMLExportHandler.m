//
//  SPXMLExportHandler.m
//  sequel-pro
//
//  Created by Max Lohrmann on 22.11.15.
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

#import "SPXMLExportHandler.h"
#import "SPExporterRegistry.h"
#import "SPXMLExporter.h"
#import "SPExportController.h"
#import "SPExportFile.h"
#import "SPExportHandlerFactory.h"

@class SPXMLExportViewController;

@interface SPXMLExportHandler ()

+ (NSString *)describeXMLExportFormat:(SPXMLExportFormat)xf;
+ (BOOL)copyXMLExportFormatForDescription:(NSString *)xfd to:(SPXMLExportFormat *)dst;

- (SPXMLExporter *)initializeXMLExporterForTable:(NSString *)table orDataArray:(NSArray *)dataArray;

@end

@interface SPXMLExportHandlerFactory : NSObject  <SPExportHandlerFactory>

@end

@interface SPXMLExportViewController : NSViewController {
	@public
	// XML
	IBOutlet NSPopUpButton *exportXMLFormatPopUpButton;
	IBOutlet NSButton *exportXMLIncludeStructure;
	IBOutlet NSButton *exportXMLIncludeContent;
	IBOutlet NSTextField *exportXMLNULLValuesAsTextField;
}

- (IBAction)toggleXMLOutputFormat:(id)sender;

@end

#pragma mark -

@implementation SPXMLExportHandlerFactory

+ (void)load {
	[super load];
	[[SPExporterRegistry sharedRegistry] registerExportHandler:[[[self alloc] init] autorelease]];
}

- (id<SPExportHandlerInstance>)makeInstanceWithController:(SPExportController *)ctr
{
	id instance = [[SPXMLExportHandler alloc] initWithFactory:self];
	[instance setController:ctr];
	return [instance autorelease];
}

- (NSString *)uniqueName {
	return @"SPXMLExporter";
}

- (NSString *)localizedShortName {
	return NSLocalizedString(@"XML","xml exporter short name");
}

- (BOOL)supportsExportToMultipleFiles {
	return YES;
}

- (BOOL)supportsExportSource:(SPExportSource)source {
	switch(source) {
		case SPTableExport:
		case SPFilteredExport:
		case SPQueryExport:
			return YES;
	}
	return NO;
}


@end

#pragma mark -

static inline NSNumber *IsOn(id obj)
{
	return (([obj state] == NSOnState)? @YES : @NO);
}

static inline void SetOnOff(NSNumber *ref,id obj)
{
	[obj setState:([ref boolValue] ? NSOnState : NSOffState)];
}

@implementation SPXMLExportHandler

#define NAMEOF(x) case x: return @#x
#define VALUEOF(x,y,dst) if([y isEqualToString:@#x]) { *dst = x; return YES; }

+ (NSString *)describeXMLExportFormat:(SPXMLExportFormat)xf
{
	switch (xf) {
			NAMEOF(SPXMLExportMySQLFormat);
			NAMEOF(SPXMLExportPlainFormat);
	}
	return nil;
}

+ (BOOL)copyXMLExportFormatForDescription:(NSString *)xfd to:(SPXMLExportFormat *)dst
{
	VALUEOF(SPXMLExportMySQLFormat, xfd, dst);
	VALUEOF(SPXMLExportPlainFormat, xfd, dst);
	return NO;
}

#undef NAMEOF
#undef VALUEOF

- (instancetype)initWithFactory:(SPXMLExportHandlerFactory *)factory {
	if ((self = [super initWithFactory:factory])) {
		[self setCanBeImported:NO];
		SPXMLExportViewController *viewController = [[[SPXMLExportViewController alloc] init] autorelease];
		[viewController setRepresentedObject:self];
		[self setAccessoryViewController:viewController];
		[self setFileExtension:@"xml"];
	}

	return self;
}

- (BOOL)canExportSchemaObjectsOfType:(SPTableType)type {
	// we can only export what provides a data table
	switch (type) {
		case SPTableTypeTable:
		case SPTableTypeView:
			return YES;
	}
	return NO;
}

- (SPExportersAndFiles)allExporters {
	return ((SPExportersAndFiles){nil,nil});
//
//	BOOL singleFileHandleSet = NO;
//	SPExportFile *singleExportFile = nil, *file = nil;
//	SPXMLExporter *xmlExporter = nil;
//
//	SPExportSource exportSource = [[self controller] exportSource];
//	NSMutableArray *exporters = [NSMutableArray arrayWithCapacity:[exportTables count]];
//	NSMutableArray *exportFiles = [NSMutableArray arrayWithCapacity:[exportTables count]];
//
//	// If the user has selected to only export to a single file or this is a filtered or custom query
//	// export, create the single file now and assign it to all subsequently created exporters.
//	if ((![[self controller] exportToMultipleFiles]) || (exportSource == SPFilteredExport) || (exportSource == SPQueryExport)) {
//		NSString *selectedTableName = nil;
//		if (exportSource == SPTableExport && [exportTables count] == 1) selectedTableName = [exportTables objectAtIndex:0];
//
//		[exportFilename setString:(createCustomFilename) ? [self expandCustomFilenameFormatUsingTableName:selectedTableName] : [self generateDefaultExportFilename]];
//
//		// Only append the extension if necessary
//		if (![[exportFilename pathExtension] length]) {
//			[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
//		}
//
//		singleExportFile = [SPExportFile exportFileAtPath:[[[self controller] exportPath] stringByAppendingPathComponent:exportFilename]];
//	}
//
//	// Start the export process depending on the data source
//	if (exportSource == SPTableExport) {
//
//		// Cache the number of tables being exported
//		exportTableCount = [exportTables count];
//
//		// Loop through the tables, creating an exporter for each
//		for (NSString *table in exportTables)
//		{
//			xmlExporter = [self initializeXMLExporterForTable:table orDataArray:nil];
//
//			// If required create a single file handle for all XML exports
//			if (![[self controller] exportToMultipleFiles]) {
//				if (!singleFileHandleSet) {
//
//					[exportFiles addObject:singleExportFile];
//
//					singleFileHandleSet = YES;
//				}
//
//				[xmlExporter setExportOutputFile:singleExportFile];
//			}
//
//			[exporters addObject:xmlExporter];
//		}
//	}
//	else {
//		xmlExporter = [self initializeXMLExporterForTable:nil orDataArray:dataArray];
//
//		[exportFiles addObject:singleExportFile];
//
//		[xmlExporter setExportOutputFile:singleExportFile];
//
//		[exporters addObject:xmlExporter];
//	}
//
//	SPExportersAndFiles pair = {exporters,exportFiles};
//	return pair;
}

/**
 * Initialises a XML exporter for the supplied table name or data array.
 *
 * @param table     The table name for which the exporter should be cerated for (can be nil).
 * @param dataArray The MySQL result data array for which the exporter should be created for (can be nil).
 */
- (SPXMLExporter *)initializeXMLExporterForTable:(NSString *)table orDataArray:(NSArray *)dataArray
{
	SPXMLExporter *xmlExporter = [[SPXMLExporter alloc] initWithDelegate:self];
	
	// if required set the data array
	if ([[self controller] exportSource] != SPTableExport) {
		[xmlExporter setXmlDataArray:dataArray];
	}
	
	// Regardless of the export source, set exporter's table name as it's used in the output
	// of table and table content exports.
	[xmlExporter setXmlTableName:table];
	
//	[xmlExporter setXmlFormat:[[self accessoryViewController]->exportXMLFormatPopUpButton indexOfSelectedItem]];
//	[xmlExporter setXmlOutputIncludeStructure:[[self accessoryViewController]->exportXMLIncludeStructure state]];
//	[xmlExporter setXmlOutputIncludeContent:[[self accessoryViewController]->exportXMLIncludeContent state]];
//	[xmlExporter setXmlNULLString:[[self accessoryViewController]->exportXMLNULLValuesAsTextField stringValue]];
//
//	// If required create separate files
//	if (([[self controller] exportSource] == SPTableExport) && [[self controller] exportToMultipleFiles] && (exportTableCount > 0)) {
//
//		if (createCustomFilename) {
//
//			// Create custom filename based on the selected format
//			[exportFilename setString:[self expandCustomFilenameFormatUsingTableName:table]];
//
//			// If the user chose to use a custom filename format and we exporting to multiple files, make
//			// sure the table name is included to ensure the output files are unique.
//			if (exportTableCount > 1) {
//				BOOL tableNameInTokens = NO;
//				NSArray *representedObjects = [exportCustomFilenameTokenField objectValue];
//				for (id representedObject in representedObjects) {
//					if ([representedObject isKindOfClass:[SPExportFileNameTokenObject class]] && [[representedObject tokenId] isEqualToString:NSLocalizedString(@"table", @"table")]) tableNameInTokens = YES;
//				}
//				[exportFilename setString:(tableNameInTokens ? exportFilename : [exportFilename stringByAppendingFormat:@"_%@", table])];
//			}
//		}
//		else {
//			[exportFilename setString:(dataArray) ? [tableDocumentInstance database] : table];
//		}
//
//		// Only append the extension if necessary
//		if (![[exportFilename pathExtension] length]) {
//			[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
//		}
//
//		SPExportFile *file = [SPExportFile exportFileAtPath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
//
//		[exportFiles addObject:file];
//
//		[xmlExporter setExportOutputFile:file];
//	}
	
	return [xmlExporter autorelease];
}

-(NSDictionary *)settings
{
	return @{
		@"exportToMultipleFiles":     @([[self controller] exportToMultipleFiles]),
//		@"XMLFormat":                 [[self class] describeXMLExportFormat:(SPXMLExportFormat)[exportXMLFormatPopUpButton indexOfSelectedItem]],
//		@"XMLOutputIncludeStructure": IsOn(exportXMLIncludeStructure),
//		@"XMLOutputIncludeContent":   IsOn(exportXMLIncludeContent),
//		@"XMLNULLString":             [exportXMLNULLValuesAsTextField stringValue]
	};
}

- (void)applySettings:(NSDictionary *)settings
{
	id o;
	SPXMLExportFormat xmlf;
//	if((o = [settings objectForKey:@"exportToMultipleFiles"]))     [[self controller] setExportToMultipleFiles:[o boolValue]];
//	if((o = [settings objectForKey:@"XMLFormat"]) && [[self class] copyXMLExportFormatForDescription:o to:&xmlf]) [exportXMLFormatPopUpButton selectItemAtIndex:xmlf];
//	if((o = [settings objectForKey:@"XMLOutputIncludeStructure"])) SetOnOff(o, exportXMLIncludeStructure);
//	if((o = [settings objectForKey:@"XMLOutputIncludeContent"]))   SetOnOff(o, exportXMLIncludeContent);
//	if((o = [settings objectForKey:@"XMLNULLString"]))             [exportXMLNULLValuesAsTextField setStringValue:o];
//
//	[self toggleXMLOutputFormat:exportXMLFormatPopUpButton];
}

- (id)specificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type
{
//	// XML per table setting is only yes/no
//	if(type == SPTableTypeTable) {
//		// we have to look through the table views' rows to find the current checkbox value...
//		for (NSArray *table in tables) {
//			if([[table objectAtIndex:0] isEqualTo:name]) {
//				return @([[table objectAtIndex:2] boolValue]);
//			}
//		}
//	}
	return nil;
}

- (void)applySpecificSettings:(id)settings forSchemaObject:(NSString *)name ofType:(SPTableType)type
{
	// XML per table setting is only yes/no
//	if(type == SPTableTypeTable) {
//		// we have to look through the table views' rows to find the appropriate table...
//		for (NSMutableArray *table in tables) {
//			if([[table objectAtIndex:0] isEqualTo:name]) {
//				[table replaceObjectAtIndex:2 withObject:@([settings boolValue])];
//				return;
//			}
//		}
//	}
}

@end

#pragma mark -

@implementation SPXMLExportViewController

- (instancetype)init
{
	if((self = [super initWithNibName:@"XMLExportAccessory" bundle:nil])) {

	}
	return self;
}

- (void)awakeFromNib
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	[exportXMLNULLValuesAsTextField setStringValue:[prefs stringForKey:SPNullValue]];
}

/**
 * Toggles the options available depending on the selected XML output format.
 */
- (IBAction)toggleXMLOutputFormat:(id)sender
{
	if ([sender indexOfSelectedItem] == SPXMLExportMySQLFormat) {
		[exportXMLIncludeStructure setEnabled:YES];
		[exportXMLIncludeContent setEnabled:YES];
		[exportXMLNULLValuesAsTextField setEnabled:NO];
	}
	else if ([sender indexOfSelectedItem] == SPXMLExportPlainFormat) {
		[exportXMLIncludeStructure setEnabled:NO];
		[exportXMLIncludeContent setEnabled:NO];
		[exportXMLNULLValuesAsTextField setEnabled:YES];
	}
}

@end

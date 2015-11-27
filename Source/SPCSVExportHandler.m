//
//  SPCSVExportHander.m
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

#import "SPExportHandlerFactory.h"
#import "SPExportHandlerInstance.h"
#import "SPCSVExportHandler.h"
#import "SPExporterRegistry.h"
#import "SPExportController.h"
#import "SPExportFilenameUtilities.h"
#import "SPCSVExporter.h"

@interface SPCSVExportHandlerFactory : NSObject  <SPExportHandlerFactory>

@end

@interface SPCSVExportViewController : NSViewController {

@public
	// CSV
	IBOutlet NSButton *exportCSVIncludeFieldNamesCheck;
	IBOutlet NSComboBox *exportCSVFieldsTerminatedField;
	IBOutlet NSComboBox *exportCSVFieldsWrappedField;
	IBOutlet NSComboBox *exportCSVFieldsEscapedField;
	IBOutlet NSComboBox *exportCSVLinesTerminatedField;
	IBOutlet NSTextField *exportCSVNULLValuesAsTextField;
}

@end

static void *_KVOContext;

#pragma mark -

#define avc ((SPCSVExportViewController *)[self accessoryViewController])


@implementation SPCSVExportHandler

- (instancetype)initWithFactory:(SPCSVExportHandlerFactory *)factory {
	if ((self = [super initWithFactory:factory])) {
		[self setCanBeImported:NO];
		SPCSVExportViewController *viewController = [[[SPCSVExportViewController alloc] init] autorelease];
		[viewController setRepresentedObject:self];
		[self setAccessoryViewController:viewController];
		[self setFileExtension:@"csv"];
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
	return ((SPExportersAndFiles){nil,nil});;

//	SPCSVExporter *csvExporter = nil;
//	NSMutableArray *exporters   = [NSMutableArray arrayWithCapacity:[exportTables count]];
//	NSMutableArray *exportFiles = [NSMutableArray arrayWithCapacity:[exportTables count]];
//
//	SPExportSource exportSource = [[self controller] exportSource];
//	// If the user has selected to only export to a single file or this is a filtered or custom query
//	// export, create the single file now and assign it to all subsequently created exporters.
//	if ((![[self controller] exportToMultipleFiles]) || (exportSource == SPFilteredExport) || (exportSource == SPQueryExport)) {
//		NSString *selectedTableName = nil;
//
//		if (exportSource == SPTableExport && [exportTables count] == 1) selectedTableName = [exportTables objectAtIndex:0];
//
//		[exportFilename setString:createCustomFilename ? [self expandCustomFilenameFormatUsingTableName:selectedTableName] : [self generateDefaultExportFilename]];
//
//		// Only append the extension if necessary
//		if (![[exportFilename pathExtension] length]) {
//			[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
//		}
//
//		singleExportFile = [SPExportFile exportFileAtPath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
//	}
//
//	// Start the export process depending on the data source
//	if (exportSource == SPTableExport) {
//		NSArray *exportTables = [[self controller] schemaObjectsForType:SPTableTypeTable];
//		// Cache the number of tables being exported
//		exportTableCount = [exportTables count];
//
//		// Loop through the tables, creating an exporter for each
//		for (NSString *table in exportTables)
//		{
//			csvExporter = [self initializeCSVExporterForTable:table orDataArray:nil];
//
//			// If required create a single file handle for all CSV exports
//			if (![[self controller] exportToMultipleFiles]) {
//				if (!singleFileHandleSet) {
//
//					[exportFiles addObject:singleExportFile];
//
//					singleFileHandleSet = YES;
//				}
//
//				[csvExporter setExportOutputFile:singleExportFile];
//			}
//
//			[exporters addObject:csvExporter];
//		}
//	}
//	else {
//		csvExporter = [self initializeCSVExporterForTable:nil orDataArray:dataArray];
//
//		[exportFiles addObject:singleExportFile];
//
//		[csvExporter setExportOutputFile:singleExportFile];
//
//		[exporters addObject:csvExporter];
//	}
//
//	SPExportersAndFiles ret = {exporters, exportFiles};
//	return ret;
}

/**
 * Initialises a CSV exporter for the supplied table name or data array.
 *
 * @param table     The table name for which the exporter should be cerated for (can be nil).
 * @param dataArray The MySQL result data array for which the exporter should be created for (can be nil).
 */
- (SPCSVExporter *)initializeCSVExporterForTable:(NSString *)table orDataArray:(NSArray *)dataArray
{
	SPCSVExporter *csvExporter = [[SPCSVExporter alloc] initWithDelegate:self];

	// Depeding on the export source, set the table name or data array
	if ([[self controller] exportSource] == SPTableExport) {
		[csvExporter setCsvTableName:table];
	}
	else {
		[csvExporter setCsvDataArray:dataArray];
	}

//	[csvExporter setCsvTableData:tableDataInstance];
	[csvExporter setCsvOutputFieldNames:[avc->exportCSVIncludeFieldNamesCheck state]];
	[csvExporter setCsvFieldSeparatorString:[avc->exportCSVFieldsTerminatedField stringValue]];
	[csvExporter setCsvEnclosingCharacterString:[avc->exportCSVFieldsWrappedField stringValue]];
	[csvExporter setCsvLineEndingString:[avc->exportCSVLinesTerminatedField stringValue]];
	[csvExporter setCsvEscapeString:[avc->exportCSVFieldsEscapedField stringValue]];
	[csvExporter setCsvNULLString:[avc->exportCSVNULLValuesAsTextField stringValue]];

	// If required create separate files
//	if ([[self controller] exportSource] == SPTableExport && [[self controller] exportToMultipleFiles]) {
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
//		SPExportFile *file = [SPExportFile exportFileAtPath:[[self exportPath] stringByAppendingPathComponent:exportFilename]];
//
//		[exportFiles addObject:file];
//
//		[csvExporter setExportOutputFile:file];
//	}

	return [csvExporter autorelease];
}


-(NSDictionary *)settings
{
	return @{
			@"exportToMultipleFiles": @([[self controller] exportToMultipleFiles]),
//			@"CSVIncludeFieldNames":  IsOn(avc->exportCSVIncludeFieldNamesCheck),
			@"CSVFieldsTerminated":   [avc->exportCSVFieldsTerminatedField stringValue],
			@"CSVFieldsWrapped":      [avc->exportCSVFieldsWrappedField stringValue],
			@"CSVLinesTerminated":    [avc->exportCSVLinesTerminatedField stringValue],
			@"CSVFieldsEscaped":      [avc->exportCSVFieldsEscapedField stringValue],
			@"CSVNULLValuesAsText":   [avc->exportCSVNULLValuesAsTextField stringValue]
	};
}

- (void)applySettings:(NSDictionary *)settings
{
	id o;
	if((o = [settings objectForKey:@"exportToMultipleFiles"])) [[self controller] setExportToMultipleFiles:[o boolValue]];

//	if((o = [settings objectForKey:@"CSVIncludeFieldNames"]))  SetOnOff(o, avc->exportCSVIncludeFieldNamesCheck);
	if((o = [settings objectForKey:@"CSVFieldsTerminated"]))   [avc->exportCSVFieldsTerminatedField setStringValue:o];
	if((o = [settings objectForKey:@"CSVFieldsWrapped"]))      [avc->exportCSVFieldsWrappedField setStringValue:o];
	if((o = [settings objectForKey:@"CSVLinesTerminated"]))    [avc->exportCSVLinesTerminatedField setStringValue:o];
	if((o = [settings objectForKey:@"CSVFieldsEscaped"]))      [avc->exportCSVFieldsEscapedField setStringValue:o];
	if((o = [settings objectForKey:@"CSVNULLValuesAsText"]))   [avc->exportCSVNULLValuesAsTextField setStringValue:o];
}

- (id)specificSettingsForSchemaObject:(id<SPExportSchemaObject>)obj
{
	// CSV per table setting is only yes/no
//	if(type == SPTableTypeTable) {
//		// we have to look through the table views rows to find the current checkbox value...
//		for (NSArray *table in tables) {
//			if([[table objectAtIndex:0] isEqualTo:name]) {
//				return @([[table objectAtIndex:2] boolValue]);
//			}
//		}
//	}
	return nil;
}

- (void)applySpecificSettings:(id)settings forSchemaObject:(id<SPExportSchemaObject>)obj
{
	// CSV per table setting is only yes/no
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

- (void)updateCanBeImported
{
	if ([[self controller] exportToMultipleFiles]) {
		[self setCanBeImported:YES];
		return;
	}

	// we can't import multiple tables in a single csv file
	NSUInteger numberOfTables = 0;

	for (id<SPExportSchemaObject> eachTable in [[self controller] allSchemaObjects])
	{
		if ([self wouldIncludeSchemaObject:eachTable]) numberOfTables++;
	}

	[self setCanBeImported:(numberOfTables <= 1)];
}

- (void)willBecomeActive
{
	// we have to show the "can't be imported" warning when "export to multiple files" is enabled
	[[self controller] addObserver:self forKeyPath:@"exportToMultipleFiles" options:NSKeyValueObservingOptionInitial context:&_KVOContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(context != &_KVOContext) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}

	if([keyPath isEqualToString:@"exportToMultipleFiles"]) {
		[self updateCanBeImported];
	}
}

@end

#undef avc

#pragma mark -

@implementation SPCSVExportHandlerFactory

+ (void)load {
	[super load];
	[[SPExporterRegistry sharedRegistry] registerExportHandler:[[[self alloc] init] autorelease]];
}

- (id<SPExportHandlerInstance>)makeInstanceWithController:(SPExportController *)ctr
{
	id<SPExportHandlerInstance> instance = [[SPCSVExportHandler alloc] initWithFactory:self];
	[instance setController:ctr];
	return [instance autorelease];
}

- (NSString *)uniqueName {
	return @"SPCSVExporter";
}

- (NSString *)localizedShortName {
	return NSLocalizedString(@"CSV","csv exporter short name");
}

- (BOOL)supportsExportToMultipleFiles {
	return YES;
}

- (BOOL)supportsExportSource:(SPExportSource)source {
	switch (source) {
		case SPTableExport:
		case SPQueryExport:
		case SPFilteredExport:
			return YES;
	}
	return NO;
}

@end

#pragma mark -

@implementation SPCSVExportViewController

- (instancetype)init
{
	if((self = [super initWithNibName:@"CSVExportAccessory" bundle:nil])) {

	}
	return self;
}

- (void)awakeFromNib {
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	[exportCSVNULLValuesAsTextField setStringValue:[prefs stringForKey:SPNullValue]];
}


#pragma mark -
#pragma mark Combo box delegate methods

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
	if ([notification object] == exportCSVFieldsTerminatedField) {
		[[self representedObject] setFileExtension:(([exportCSVFieldsTerminatedField indexOfSelectedItem] == 2) ? @"tsv" : @"csv")];
	}
}

@end
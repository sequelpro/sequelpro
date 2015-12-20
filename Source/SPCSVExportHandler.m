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
#import "SPExportHandler.h"
#import "SPCSVExportHandler.h"
#import "SPExporterRegistry.h"
#import "SPExportController.h"
#import "SPCSVExporter.h"
#import "SPTableBaseExportHandler_Protected.h"
#import "SPExportFile.h"
#import "SPExportInitializer.h"
#import "SPDatabaseDocument.h"
#import "SPExportController+SharedPrivateAPI.h"

@interface SPCSVExportHandlerFactory : NSObject  <SPExportHandlerFactory>

@end

@interface SPCSVExportViewController : NSViewController <NSComboBoxDelegate> {

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

// we just need an unique value of type 'void *' to identify our KVO messages.
// The memory address of this variable will do just that, the value is never used.
static void *_KVOContext;

#pragma mark -

#define avc ((SPCSVExportViewController *)[self accessoryViewController])


@implementation SPCSVExportHandler

- (instancetype)initWithFactory:(SPCSVExportHandlerFactory *)factory
{
	if ((self = [super initWithFactory:factory])) {
		[self setCanBeImported:NO];
		SPCSVExportViewController *viewController = [[[SPCSVExportViewController alloc] init] autorelease];
		[viewController setRepresentedObject:self];
		[self setAccessoryViewController:viewController];
		[self setFileExtension:@"csv"];
		writeInitialHeaderForCurrentFile = YES;
	}
	return self;
}

- (BOOL)canExportSchemaObjectsOfType:(SPTableType)type
{
	// we can only export what provides a data table
	switch (type) {
		case SPTableTypeTable:
		case SPTableTypeView:
			return YES;
		case SPTableTypeNone:
		case SPTableTypeProc:
		case SPTableTypeFunc:
		case SPTableTypeEvent:
			;
	}
	return NO;
}

- (SPExportersAndFiles)allExportersForSchemaObjects:(NSArray *)schemaObjects
{
	SPExportFile *singleExportFile = nil;
	NSMutableArray *exporters   = [NSMutableArray arrayWithCapacity:[schemaObjects count]];
	NSMutableArray *exportFiles = [NSMutableArray arrayWithCapacity:[schemaObjects count]];

	// If the user has selected to only export to a single file, create the single file now and assign it to all subsequently created exporters.
	if ((![[self controller] exportToMultipleFiles])) {
		NSString *selectedTableName = nil;

		if ([schemaObjects count] == 1) selectedTableName = [(id<SPExportSchemaObject>)[schemaObjects objectAtIndex:0] name];

		singleExportFile = [[self controller] exportFileForTableName:selectedTableName];
	}

	// Cache the number of tables being exported
	exportTableCount = [schemaObjects count];

	BOOL singleFileHandleSet = NO;
	// Loop through the tables, creating an exporter for each
	for (id<SPExportSchemaObject> object in schemaObjects)
	{
		SPCSVExporter *csvExporter = [self initializeCSVExporterForTable:[object name] orDataArray:nil];

		// If required create a single file handle for all CSV exports
		if (![[self controller] exportToMultipleFiles]) {
			if (!singleFileHandleSet) {

				[exportFiles addObject:singleExportFile];

				singleFileHandleSet = YES;
			}

			[csvExporter setExportOutputFile:singleExportFile];
		}
		else {
			// If required create separate files
			SPExportFile *file = [[self controller] exportFileForTableName:[object name]];

			[exportFiles addObject:file];

			[csvExporter setExportOutputFile:file];
		}

		[exporters addObject:csvExporter];
	}

	SPExportersAndFiles ret = {exporters, exportFiles};
	return ret;
}

- (SPExportersAndFiles)allExportersForData:(NSArray *)dataArray
{
	SPExportFile *singleExportFile = [[self controller] exportFileForTableName:nil];

	SPCSVExporter *csvExporter = [self initializeCSVExporterForTable:nil orDataArray:dataArray];

	[csvExporter setExportOutputFile:singleExportFile];

	SPExportersAndFiles ret = {@[csvExporter],@[singleExportFile]};
	return ret;
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

	[csvExporter setCsvTableData:[[self controller] tableDataInstance]];
	[csvExporter setCsvOutputFieldNames:([avc->exportCSVIncludeFieldNamesCheck state] == NSOnState)];
	[csvExporter setCsvFieldSeparatorString:[avc->exportCSVFieldsTerminatedField stringValue]];
	[csvExporter setCsvEnclosingCharacterString:[avc->exportCSVFieldsWrappedField stringValue]];
	[csvExporter setCsvLineEndingString:[avc->exportCSVLinesTerminatedField stringValue]];
	[csvExporter setCsvEscapeString:[avc->exportCSVFieldsEscapedField stringValue]];
	[csvExporter setCsvNULLString:[avc->exportCSVNULLValuesAsTextField stringValue]];
	[csvExporter setDatabaseHost:[[[self controller] tableDocumentInstance] host]];
	[csvExporter setDatabaseName:[[[self controller] tableDocumentInstance] database]];

	return [csvExporter autorelease];
}


-(NSDictionary *)settings
{
	return @{
		@"exportToMultipleFiles": @([[self controller] exportToMultipleFiles]),
		@"CSVIncludeFieldNames":  IsOn(avc->exportCSVIncludeFieldNamesCheck),
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

	if((o = [settings objectForKey:@"CSVIncludeFieldNames"]))  SetOnOff(o, avc->exportCSVIncludeFieldNamesCheck);
	if((o = [settings objectForKey:@"CSVFieldsTerminated"]))   [avc->exportCSVFieldsTerminatedField setStringValue:o];
	if((o = [settings objectForKey:@"CSVFieldsWrapped"]))      [avc->exportCSVFieldsWrappedField setStringValue:o];
	if((o = [settings objectForKey:@"CSVLinesTerminated"]))    [avc->exportCSVLinesTerminatedField setStringValue:o];
	if((o = [settings objectForKey:@"CSVFieldsEscaped"]))      [avc->exportCSVFieldsEscapedField setStringValue:o];
	if((o = [settings objectForKey:@"CSVNULLValuesAsText"]))   [avc->exportCSVNULLValuesAsTextField setStringValue:o];
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

- (void)updateValidForExport
{
	BOOL superValid;
	if([[self controller] exportSource] == SPTableExport) {
		//super is only useful for table exports
		[super updateValidForExport];
		superValid = [self isValidForExport];
	}
	else {
		// for filtered and query exports the input is always valid if they can be selected
		superValid = YES;
	}
	
	if(superValid) {
		// Check that we have all the required info before allowing the export
		[self setIsValidForExport:(
			([[avc->exportCSVFieldsTerminatedField stringValue] length]) &&
			([[avc->exportCSVFieldsEscapedField stringValue] length]) &&
			([[avc->exportCSVLinesTerminatedField stringValue] length])
		)];
	}
}

- (void)willBecomeActive
{
	[super willBecomeActive];
	// we have to show the "can't be imported" warning when "export to multiple files" is enabled
	[[self controller] addObserver:self
	                    forKeyPath:@"exportToMultipleFiles"
	                       options:NSKeyValueObservingOptionInitial
	                       context:&_KVOContext];
}

- (void)didBecomeInactive
{
	[super didBecomeInactive];

	if([[self controller] respondsToSelector:@selector(removeObserver:forKeyPath:context:)]) {
		[[self controller] removeObserver:self forKeyPath:@"exportToMultipleFiles" context:&_KVOContext];
	}
	// 10.6 backward compatibility
	else {
		[[self controller] removeObserver:self forKeyPath:@"exportToMultipleFiles"];
	}
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// not our context -> not our resposibility
	if(context != &_KVOContext) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}

	if([keyPath isEqualToString:@"exportToMultipleFiles"]) {
		[self updateCanBeImported];
	}
}

#pragma mark Delegate

- (void)csvExportProcessWillBegin:(SPCSVExporter *)exporter
{
	[[self controller] setExportProgressIndeterminate:YES];
	
	if(writeInitialHeaderForCurrentFile) {
		[self writeInitialCSVHeaderForExporter:exporter];
		writeInitialHeaderForCurrentFile = NO;
	}
	// If we're only exporting to a single file then write a header for the next table
	else {
		[self writeContinuationCSVHeaderForExporter:exporter];
	}

	// Only update the progress text if this is a table export
	if ([[self controller] exportSource] == SPTableExport) {
		// Update the current table export index
		currentTableExportIndex = (exportTableCount - [[[self controller] waitingExporters] count]);

		[[self controller] setExportProgressDetail:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Fetching data...", @"export label showing that the app is fetching data for a specific table"), currentTableExportIndex, exportTableCount, [exporter csvTableName]]];
	}
	else {
		[[self controller] setExportProgressDetail:NSLocalizedString(@"Fetching data...", @"export label showing that the app is fetching data")];
	}
}

- (void)csvExportProcessComplete:(SPCSVExporter *)exporter
{
	// If this was the last exporter left OR
	// we are exporting to multiple files
	// => close the export file
	if (![[[self controller] waitingExporters] count] || [[self controller] exportToMultipleFiles]) {
		[[exporter exportOutputFile] close];
		writeInitialHeaderForCurrentFile = YES; //for next file
	}

	[[self controller] exportEnded:exporter];
}

- (void)csvExportProcessWillBeginWritingData:(SPCSVExporter *)exporter
{
	// Only update the progress text if this is a table export
	if ([[self controller] exportSource] == SPTableExport) {
		[[self controller] setExportProgressDetail:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Writing data...", @"export label showing app if writing data for a specific table"), currentTableExportIndex, exportTableCount, [exporter csvTableName]]];
	}
	else {
		[[self controller] setExportProgressDetail:NSLocalizedString(@"Writing data...", @"export label showing app is writing data")];
	}

	[[self controller] setExportProgressIndeterminate:NO];
	[[self controller] setExportProgress:0];
}

- (void)csvExportProcessProgressUpdated:(SPCSVExporter *)exporter
{
	[[self controller] setExportProgress:[exporter exportProgressValue]];
}

- (void)writeInitialCSVHeaderForExporter:(SPCSVExporter *)exporter
{
	// Write the file header and the first table name
	[exporter writeString:[NSString stringWithFormat:@"%@: %@   %@: %@    %@: %@",
	                                                 NSLocalizedString(@"Host", @"export header host label"),
	                                                 [exporter databaseHost],
	                                                 NSLocalizedString(@"Database", @"export header database label"),
	                                                 [exporter databaseName],
	                                                 NSLocalizedString(@"Generation Time", @"export header generation time label"),
	                                                 [NSDate date]]];
	
	[self writeContinuationCSVHeaderForExporter:exporter];
}

- (void)writeContinuationCSVHeaderForExporter:(SPCSVExporter *)exporter
{
	// If we're exporting multiple tables to a single file then append some space and the next table's name
	NSMutableString *header = [NSMutableString stringWithString:@"\n\n"];
	
	if([[exporter csvTableName] length]) {
		[header appendFormat:@"%@ %@\n\n",
		                     NSLocalizedString(@"Table", @"csv export table heading"),
		                     [exporter csvTableName]];
	}
	
	if(![@"\n" isEqualToString:[exporter csvLineEndingString]]) {
		[header replaceOccurrencesOfString:@"\n" withString:[exporter csvLineEndingString] options:NSLiteralSearch range:NSMakeRange(0, [header length])];
	}
	
	[exporter writeString:header];
}

@end

#undef avc

#pragma mark -

@implementation SPCSVExportHandlerFactory

+ (void)load
{
	[super load];
	[[SPExporterRegistry sharedRegistry] registerExportHandler:[[[self alloc] init] autorelease]];
}

- (id<SPExportHandler>)makeInstanceWithController:(SPExportController *)ctr
{
	SPCSVExportHandler *instance = [[SPCSVExportHandler alloc] initWithFactory:self];
	[instance setController:ctr];
	return [instance autorelease];
}

- (NSString *)uniqueName
{
	return @"SPCSVExporter";
}

- (NSString *)localizedShortName
{
	return NSLocalizedString(@"CSV","csv exporter short name");
}

- (BOOL)supportsExportToMultipleFiles
{
	return YES;
}

- (BOOL)supportsExportSource:(SPExportSource)source
{
	switch (source) {
		case SPTableExport:
		case SPQueryExport:
		case SPFilteredExport:
			return YES;
		case SPDatabaseExport:
			;
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

- (void)awakeFromNib
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	[exportCSVNULLValuesAsTextField setStringValue:[prefs stringForKey:SPNullValue]];
}


#pragma mark -
#pragma mark Combo box delegate methods

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
	if ([notification object] == exportCSVFieldsTerminatedField) {
		[(SPCSVExportHandler *)[self representedObject] setFileExtension:(([exportCSVFieldsTerminatedField indexOfSelectedItem] == 2) ? @"tsv" : @"csv")];
	}
}

@end
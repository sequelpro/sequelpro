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
#import "SPTableBaseExportHandler_Protected.h"
#import "SPExportInitializer.h"
#import "SPDatabaseDocument.h"
#import "SPCustomQuery.h"
#import "SPTableContent.h"
#import "SPExportController+SharedPrivateAPI.h"

@interface SPXMLExportHandler ()

+ (NSString *)describeXMLExportFormat:(SPXMLExportFormat)xf;
+ (BOOL)copyXMLExportFormatForDescription:(NSString *)xfd to:(SPXMLExportFormat *)dst;

- (SPXMLExporter *)initializeXMLExporterForTable:(NSString *)table orDataArray:(NSArray *)dataArray;

- (void)writeXMLHeaderForExporter:(SPXMLExporter *)exporter;
- (void)writeXMLFooterForExporter:(SPXMLExporter *)exporter;

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

- (id<SPExportHandler>)makeInstanceWithController:(SPExportController *)ctr
{
	SPXMLExportHandler *instance = [[SPXMLExportHandler alloc] initWithFactory:self];
	[instance setController:ctr];
	return [instance autorelease];
}

- (NSString *)uniqueName
{
	return @"SPXMLExporter";
}

- (NSString *)localizedShortName
{
	return NSLocalizedString(@"XML","xml exporter short name");
}

- (BOOL)supportsExportToMultipleFiles
{
	return YES;
}

- (BOOL)supportsExportSource:(SPExportSource)source
{
	switch(source) {
		case SPTableExport:
		case SPFilteredExport:
		case SPQueryExport:
			return YES;
		case SPDatabaseExport:
			;
	}
	return NO;
}


@end

#pragma mark -

#define avc ((SPXMLExportViewController *)[self accessoryViewController])

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

- (instancetype)initWithFactory:(SPXMLExportHandlerFactory *)factory
{
	if ((self = [super initWithFactory:factory])) {
		[self setCanBeImported:NO];
		SPXMLExportViewController *viewController = [[[SPXMLExportViewController alloc] init] autorelease];
		[viewController setRepresentedObject:self];
		[self setAccessoryViewController:viewController];
		[self setFileExtension:@"xml"];
		writeHeaderForCurrentFile = YES;
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
	NSMutableArray *exporters = [NSMutableArray arrayWithCapacity:[schemaObjects count]];
	NSMutableArray *exportFiles = [NSMutableArray arrayWithCapacity:[schemaObjects count]];
	SPExportFile *singleExportFile = nil;

	// If the user has selected to only export to a single file, create the single file now and assign it to all subsequently created exporters.
	if ((![[self controller] exportToMultipleFiles])) {
		NSString *selectedTableName = nil;
		if ([schemaObjects count] == 1) selectedTableName = [(id<SPExportSchemaObject>)[schemaObjects objectAtIndex:0] name];

		singleExportFile = [[self controller] exportFileForTableName:selectedTableName];
	}

	// Cache the number of tables being exported
	exportTableCount = [schemaObjects count];

	// Loop through the tables, creating an exporter for each
	BOOL singleFileHandleSet = NO;
	for (id<SPExportSchemaObject> object in schemaObjects)
	{
		SPXMLExporter *xmlExporter = [self initializeXMLExporterForTable:[object name] orDataArray:nil];

		// If required create a single file handle for all XML exports
		if (![[self controller] exportToMultipleFiles]) {
			if (!singleFileHandleSet) {

				[exportFiles addObject:singleExportFile];

				singleFileHandleSet = YES;
			}

			[xmlExporter setExportOutputFile:singleExportFile];
		}
		else if(exportTableCount > 0) {
			SPExportFile *file = [[self controller] exportFileForTableName:[object name]];

			[exportFiles addObject:file];

			[xmlExporter setExportOutputFile:file];
		}

		[exporters addObject:xmlExporter];
	}

	SPExportersAndFiles result = {exporters,exportFiles};
	return result;
}

- (SPExportersAndFiles)allExportersForData:(NSArray *)data
{
	SPExportFile *singleExportFile = [[self controller] exportFileForTableName:nil];
	SPXMLExporter *xmlExporter = [self initializeXMLExporterForTable:nil orDataArray:data];
	[xmlExporter setExportOutputFile:singleExportFile];

	SPExportersAndFiles result = {@[xmlExporter],@[singleExportFile]};
	return result;
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

	[xmlExporter setXmlDataArray:dataArray]; // nil stays nil
	// Regardless of the export source, set exporter's table name as it's used in the output
	// of table and table content exports.
	[xmlExporter setXmlTableName:table];
	
	[xmlExporter setXmlFormat:(SPXMLExportFormat)[avc->exportXMLFormatPopUpButton indexOfSelectedItem]];
	[xmlExporter setXmlOutputIncludeStructure:([avc->exportXMLIncludeStructure state] == NSOnState)];
	[xmlExporter setXmlOutputIncludeContent:([avc->exportXMLIncludeContent state] == NSOnState)];
	[xmlExporter setXmlNULLString:[avc->exportXMLNULLValuesAsTextField stringValue]];
	
	return [xmlExporter autorelease];
}

-(NSDictionary *)settings
{
	return @{
		@"exportToMultipleFiles":     @([[self controller] exportToMultipleFiles]),
		@"XMLFormat":                 [[self class] describeXMLExportFormat:(SPXMLExportFormat)[avc->exportXMLFormatPopUpButton indexOfSelectedItem]],
		@"XMLOutputIncludeStructure": IsOn(avc->exportXMLIncludeStructure),
		@"XMLOutputIncludeContent":   IsOn(avc->exportXMLIncludeContent),
		@"XMLNULLString":             [avc->exportXMLNULLValuesAsTextField stringValue]
	};
}

- (void)applySettings:(NSDictionary *)settings
{
	id o;
	SPXMLExportFormat xmlf;
	if((o = [settings objectForKey:@"exportToMultipleFiles"]))     [[self controller] setExportToMultipleFiles:[o boolValue]];
	if((o = [settings objectForKey:@"XMLFormat"]) && [[self class] copyXMLExportFormatForDescription:o to:&xmlf]) [avc->exportXMLFormatPopUpButton selectItemAtIndex:xmlf];
	if((o = [settings objectForKey:@"XMLOutputIncludeStructure"])) SetOnOff(o, avc->exportXMLIncludeStructure);
	if((o = [settings objectForKey:@"XMLOutputIncludeContent"]))   SetOnOff(o, avc->exportXMLIncludeContent);
	if((o = [settings objectForKey:@"XMLNULLString"]))             [avc->exportXMLNULLValuesAsTextField setStringValue:o];

	[avc toggleXMLOutputFormat:avc->exportXMLFormatPopUpButton];
}

- (void)updateValidForExport
{
	BOOL superIsValid;
	if([[self controller] exportSource] == SPTableExport) {
		// let super check for non-empty selection
		[super updateValidForExport];
		superIsValid = [self isValidForExport];
	}
	else {
		superIsValid = YES;
	}

	if(superIsValid) {
		BOOL enable = NO;
		SPXMLExportFormat fmt = (SPXMLExportFormat)[avc->exportXMLFormatPopUpButton indexOfSelectedItem];
		// we also need to make sure that at least one of structure, content is selected
		if(fmt == SPXMLExportMySQLFormat) {
			enable = (([avc->exportXMLIncludeStructure state] == NSOnState) || ([avc->exportXMLIncludeContent state] == NSOnState));
		}
		// and a null string is given for plain
		else if(fmt == SPXMLExportPlainFormat) {
			enable = ([[avc->exportXMLNULLValuesAsTextField stringValue] length] > 0);
		}
		[self setIsValidForExport:enable];
	}
}

#pragma mark Delegate

- (void)xmlExportProcessWillBegin:(SPXMLExporter *)exporter
{
	[[self controller] setExportProgressIndeterminate:YES];

	// Only update the progress text if this is a table export
	if ([[self controller] exportSource] == SPTableExport) {

		// Update the current table export index
		currentTableExportIndex = (exportTableCount - [[[self controller] waitingExporters] count]);

		[[self controller] setExportProgressDetail:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Fetching data...", @"export label showing that the app is fetching data for a specific table"), currentTableExportIndex, exportTableCount, [exporter xmlTableName]]];
	}
	else {
		[[self controller] setExportProgressDetail:NSLocalizedString(@"Fetching data...", @"export label showing that the app is fetching data")];
	}

	if(writeHeaderForCurrentFile) {
		[self writeXMLHeaderForExporter:exporter];
		writeHeaderForCurrentFile = NO;
	}
}

- (void)xmlExportProcessComplete:(SPXMLExporter *)exporter
{
	if ([[[self controller] waitingExporters] count]) {
		// if we are writing all to one file and there is still stuff left, skip the footer
		if (![[self controller] exportToMultipleFiles]) {
			goto skip_footer;
		}
	}

	[self writeXMLFooterForExporter:exporter];
	[[exporter exportOutputFile] close];
	writeHeaderForCurrentFile = YES; //for next file
	
skip_footer:
	[[self controller] exportEnded:exporter];
}

- (void)xmlExportProcessProgressUpdated:(SPXMLExporter *)exporter
{
	[[self controller] setExportProgress:[exporter exportProgressValue]];
}

- (void)xmlExportProcessWillBeginWritingData:(SPXMLExporter *)exporter
{
	// Only update the progress text if this is a table export
	if ([[self controller] exportSource] == SPTableExport) {
		[[self controller] setExportProgressDetail:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Writing data...", @"export label showing app if writing data for a specific table"), currentTableExportIndex, exportTableCount, [exporter xmlTableName]]];
	}
	else {
		[[self controller] setExportProgressDetail:NSLocalizedString(@"Writing data...", @"export label showing app is writing data")];
	}

	[[self controller] setExportProgressIndeterminate:NO];
	[[self controller] setExportProgress:0];
}

/**
 * Writes the XML file header to the supplied export file.
 *
 * @param file The export file to write the header to.
 */
- (void)writeXMLHeaderForExporter:(SPXMLExporter *)exporter
{
	NSMutableString *header = [NSMutableString string];

	[header appendString:@"<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n\n"];
	[header appendString:@"<!--\n-\n"];
	[header appendString:@"- Sequel Pro XML dump\n"];
	[header appendFormat:@"- %@ %@\n-\n", NSLocalizedString(@"Version", @"export header version label"), [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
	[header appendFormat:@"- %@\n- %@\n-\n", SPLOCALIZEDURL_HOMEPAGE, SPDevURL];
	[header appendFormat:@"- %@: %@ (MySQL %@)\n", NSLocalizedString(@"Host", @"export header host label"), [[[self controller] tableDocumentInstance] host], [[[self controller] tableDocumentInstance] mySQLVersion]];
	[header appendFormat:@"- %@: %@\n", NSLocalizedString(@"Database", @"export header database label"), [[[self controller] tableDocumentInstance] database]];
	[header appendFormat:@"- %@: %@\n", NSLocalizedString(@"Generation Time", @"export header generation time label"), [NSDate date]];
	[header appendString:@"-\n-->\n\n"];

	if ([exporter xmlFormat] == SPXMLExportMySQLFormat) {

		NSString *tag;

		if ([[self controller] exportSource] == SPTableExport) {
			tag = [NSString stringWithFormat:@"<mysqldump xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n<database name=\"%@\">\n\n", [[[self controller] tableDocumentInstance] database]];
		}
		else {
			tag = [NSString stringWithFormat:@"<resultset statement=\"%@\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n\n", ([[self controller] exportSource] == SPFilteredExport) ? [[[self controller] tableContentInstance] usedQuery] : [[[self controller] customQueryInstance] usedQuery]];
		}

		[header appendString:tag];
	}
	else {
		[header appendFormat:@"<%@>\n\n", [[[[self controller] tableDocumentInstance] database] HTMLEscapeString]];
	}

	[exporter writeUTF8String:header];
}

- (void)writeXMLFooterForExporter:(SPXMLExporter *)exporter
{
	NSString *string = @"";

	if ([exporter xmlFormat] == SPXMLExportMySQLFormat) {
		string = ([[self controller] exportSource] == SPTableExport) ? @"</database>\n</mysqldump>\n" : @"</resultset>\n";
	}
	else if ([exporter xmlFormat] == SPXMLExportPlainFormat) {
		string = [NSString stringWithFormat:@"</%@>\n", [[[[self controller] tableDocumentInstance] database] HTMLEscapeString]];
	}

	[exporter writeString:string];
}

@end

#undef avc

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

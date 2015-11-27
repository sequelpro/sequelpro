//
//  SPSQLExportHander.m
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

#import "SPSQLExportHandler.h"
#import "SPExporterRegistry.h"
#import "SPExportController.h"
#import "SPExportFile.h"
#import "SPSQLExporter.h"
#import "SPExportHandlerFactory.h"

@interface SPSQLExportViewController : NSViewController {
	// SQL
	IBOutlet NSButton *exportSQLIncludeStructureCheck;
	IBOutlet NSButton *exportSQLIncludeDropSyntaxCheck;
	IBOutlet NSButton *exportSQLIncludeContentCheck;
	IBOutlet NSButton *exportSQLIncludeErrorsCheck;
	IBOutlet NSButton *exportSQLBLOBFieldsAsHexCheck;
	IBOutlet NSTextField *exportSQLInsertNValueTextField;
	IBOutlet NSPopUpButton *exportSQLInsertDividerPopUpButton;
	IBOutlet NSButton *exportSQLIncludeAutoIncrementValueButton;
	IBOutlet NSButton *exportUseUTF8BOMButton;
}

- (IBAction)toggleSQLIncludeStructure:(NSButton *)sender;
- (IBAction)toggleSQLIncludeContent:(NSButton *)sender;
- (IBAction)toggleSQLIncludeDropSyntax:(NSButton *)sender;

@end

#pragma mark -

@interface SPSQLExportHandlerFactory : NSObject <SPExportHandlerFactory>
// see protocol
@end

#pragma mark -

@interface SPSQLExportHandler ()

+ (NSString *)describeSQLExportInsertDivider:(SPSQLExportInsertDivider)eid;
+ (BOOL)copySQLExportInsertDividerForDescription:(NSString *)xfd to:(SPSQLExportInsertDivider *)dst;

@end

#pragma mark -

@implementation SPSQLExportHandler

+ (NSString *)describeSQLExportInsertDivider:(SPSQLExportInsertDivider)eid
{
//	switch (eid) {
//		NAMEOF(SPSQLInsertEveryNDataBytes);
//		NAMEOF(SPSQLInsertEveryNRows);
//	}
	return nil;
}

+ (BOOL)copySQLExportInsertDividerForDescription:(NSString *)eidd to:(SPSQLExportInsertDivider *)dst
{
//	VALUEOF(SPSQLInsertEveryNDataBytes, eidd, dst);
//	VALUEOF(SPSQLInsertEveryNRows,      eidd, dst);
	return NO;
}

- (instancetype)initWithFactory:(SPSQLExportHandlerFactory *)factory {
	if ((self = [super initWithFactory:factory])) {
		[self setCanBeImported:YES];
		SPSQLExportViewController *viewController = [[[SPSQLExportViewController alloc] init] autorelease];
		[viewController setRepresentedObject:self];
		[self setAccessoryViewController:viewController];
		[self setFileExtension:SPFileExtensionSQL];
	}
	return self;
}

- (BOOL)canExportSchemaObjectsOfType:(SPTableType)type {
	switch (type) {
		case SPTableTypeTable:
		case SPTableTypeView:
		case SPTableTypeFunc:
		case SPTableTypeEvent:
			return YES;
	}
	return NO;
}

- (SPExportersAndFiles)allExporters
{
	return ((SPExportersAndFiles){nil,nil});
//
//	// Cache the number of tables being exported
//	exportTableCount = [exportTables count];
//
//	SPSQLExporter *sqlExporter = [[SPSQLExporter alloc] initWithDelegate:self];
//
//	[sqlExporter setSqlDatabaseHost:[tableDocumentInstance host]];
//	[sqlExporter setSqlDatabaseName:[tableDocumentInstance database]];
//	[sqlExporter setSqlDatabaseVersion:[tableDocumentInstance mySQLVersion]];
//
//	[sqlExporter setSqlOutputIncludeUTF8BOM:[exportUseUTF8BOMButton state]];
//	[sqlExporter setSqlOutputEncodeBLOBasHex:[exportSQLBLOBFieldsAsHexCheck state]];
//	[sqlExporter setSqlOutputIncludeErrors:[exportSQLIncludeErrorsCheck state]];
//	[sqlExporter setSqlOutputIncludeAutoIncrement:([exportSQLIncludeStructureCheck state] && [exportSQLIncludeAutoIncrementValueButton state])];
//
//	[sqlExporter setSqlInsertAfterNValue:[exportSQLInsertNValueTextField integerValue]];
//	[sqlExporter setSqlInsertDivider:[exportSQLInsertDividerPopUpButton indexOfSelectedItem]];
//
//	[sqlExporter setSqlExportTables:exportTables];
//
//	// Create custom filename if required
//	NSString *selectedTableName = ([[self controller] exportSource] == SPTableExport && [exportTables count] == 1)? [[exportTables objectAtIndex:0] objectAtIndex:0] : nil;
//	[exportFilename setString:(createCustomFilename) ? [self expandCustomFilenameFormatUsingTableName:selectedTableName] : [self generateDefaultExportFilename]];
//
//	// Only append the extension if necessary
//	if (![[exportFilename pathExtension] length]) {
//		[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
//	}
//
//	SPExportFile *file = [SPExportFile exportFileAtPath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
//
//
//	[sqlExporter setExportOutputFile:file];
//
//	SPExportersAndFiles result = {@[sqlExporter],@[file]};
//	[sqlExporter autorelease];
//
//	return result;
}

- (NSDictionary *)settings
{
	return nil;

//	BOOL includeStructure = ([exportSQLIncludeStructureCheck state] == NSOnState);
//
//	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{
//			@"SQLIncludeStructure": IsOn(exportSQLIncludeStructureCheck),
//			@"SQLIncludeContent":   IsOn(exportSQLIncludeContentCheck),
//			@"SQLIncludeErrors":    IsOn(exportSQLIncludeErrorsCheck),
//			@"SQLIncludeDROP":      IsOn(exportSQLIncludeDropSyntaxCheck),
//			@"SQLUseUTF8BOM":       IsOn(exportUseUTF8BOMButton),
//			@"SQLBLOBFieldsAsHex":  IsOn(exportSQLBLOBFieldsAsHexCheck),
//			@"SQLInsertNValue":     @([exportSQLInsertNValueTextField integerValue]),
//			@"SQLInsertDivider":    [[self class] describeSQLExportInsertDivider:(SPSQLExportInsertDivider)[exportSQLInsertDividerPopUpButton indexOfSelectedItem]]
//	}];
//
//	if(includeStructure) {
//		[dict addEntriesFromDictionary:@{
//				@"SQLIncludeAutoIncrementValue":  IsOn(exportSQLIncludeAutoIncrementValueButton),
//				@"SQLIncludeDropSyntax":          IsOn(exportSQLIncludeDropSyntaxCheck)
//		}];
//	}
//
//	return dict;
}

- (void)applySettings:(NSDictionary *)settings
{
	id o;
	SPSQLExportInsertDivider div;

//	if((o = [settings objectForKey:@"SQLIncludeContent"]))   SetOnOff(o, exportSQLIncludeContentCheck);
//	[self toggleSQLIncludeContent:exportSQLIncludeContentCheck];
//
//	if((o = [settings objectForKey:@"SQLIncludeDROP"]))    SetOnOff(o, exportSQLIncludeDropSyntaxCheck);
//	[self toggleSQLIncludeDropSyntax:exportSQLIncludeDropSyntaxCheck];
//
//	if((o = [settings objectForKey:@"SQLIncludeStructure"])) SetOnOff(o, exportSQLIncludeStructureCheck);
//	[self toggleSQLIncludeStructure:exportSQLIncludeStructureCheck];
//
//	if((o = [settings objectForKey:@"SQLIncludeErrors"]))    SetOnOff(o, exportSQLIncludeErrorsCheck);
//	if((o = [settings objectForKey:@"SQLUseUTF8BOM"]))       SetOnOff(o, exportUseUTF8BOMButton);
//	if((o = [settings objectForKey:@"SQLBLOBFieldsAsHex"]))  SetOnOff(o, exportSQLBLOBFieldsAsHexCheck);
//	if((o = [settings objectForKey:@"SQLInsertNValue"]))     [exportSQLInsertNValueTextField setIntegerValue:[o integerValue]];
//	if((o = [settings objectForKey:@"SQLInsertDivider"]) && [[self class] copySQLExportInsertDividerForDescription:o to:&div]) [exportSQLInsertDividerPopUpButton selectItemAtIndex:div];
//
//	if([exportSQLIncludeStructureCheck state] == NSOnState) {
//		if((o = [settings objectForKey:@"SQLIncludeAutoIncrementValue"]))  SetOnOff(o, exportSQLIncludeAutoIncrementValueButton);
//		if((o = [settings objectForKey:@"SQLIncludeDropSyntax"]))  SetOnOff(o, exportSQLIncludeDropSyntaxCheck);
//	}
}

- (id)specificSettingsForSchemaObject:(NSString *)name ofType:(SPTableType)type
{
//	BOOL structure = ([exportSQLIncludeStructureCheck state] == NSOnState);
//	BOOL content   = ([exportSQLIncludeContentCheck state] == NSOnState);
//	BOOL drop      = ([exportSQLIncludeDropSyntaxCheck state] == NSOnState);
//
//	// SQL allows per table setting of structure/content/drop table
//	if(type == SPTableTypeTable) {
//		// we have to look through the table views rows to find the current checkbox value...
//		for (NSArray *table in tables) {
//			if([[table objectAtIndex:0] isEqualTo:name]) {
//				NSMutableArray *flags = [NSMutableArray arrayWithCapacity:3];
//
//				if (structure && [[table objectAtIndex:1] boolValue]) {
//					[flags addObject:@"structure"];
//				}
//
//				if (content && [[table objectAtIndex:2] boolValue]) {
//					[flags addObject:@"content"];
//				}
//
//				if (drop && [[table objectAtIndex:3] boolValue]) {
//					[flags addObject:@"drop"];
//				}
//
//				return flags;
//			}
//		}
//	}
	return nil;
}

- (void)applySpecificSettings:(id)settings forSchemaObject:(NSString *)name ofType:(SPTableType)type
{
//	BOOL structure = ([exportSQLIncludeStructureCheck state] == NSOnState);
//	BOOL content   = ([exportSQLIncludeContentCheck state] == NSOnState);
//	BOOL drop      = ([exportSQLIncludeDropSyntaxCheck state] == NSOnState);
//
//	// SQL allows per table setting of structure/content/drop table
//	if(type == SPTableTypeTable) {
//		// we have to look through the table views' rows to find the appropriate table...
//		for (NSMutableArray *table in tables) {
//			if([[table objectAtIndex:0] isEqualTo:name]) {
//				NSArray *flags = settings;
//
//				[table replaceObjectAtIndex:1 withObject:@((structure && [flags containsObject:@"structure"]))];
//				[table replaceObjectAtIndex:2 withObject:@((content   && [flags containsObject:@"content"]))];
//				[table replaceObjectAtIndex:3 withObject:@((drop      && [flags containsObject:@"drop"]))];
//				return;
//			}
//		}
//	}
}

- (void)_validateExportButton
{
	BOOL enable = NO;
//	BOOL structureEnabled = [[uiStateDict objectForKey:SPSQLExportStructureEnabled] boolValue];
//	BOOL contentEnabled   = [[uiStateDict objectForKey:SPSQLExportContentEnabled] boolValue];
//	BOOL dropEnabled      = [[uiStateDict objectForKey:SPSQLExportDropEnabled] boolValue];
//
//	if (((!structureEnabled) || (!dropEnabled))) {
//		enable = NO;
//
//		// Only enable the button if at least one table is selected
//		for (NSArray *table in tables)
//		{
//			if ([NSArrayObjectAtIndex(table, 2) boolValue]) {
//				enable = YES;
//				break;
//			}
//		}
//	}
//	else {
//
//		// Disable if all are unchecked
//		if ((!contentEnabled) && (!structureEnabled) && (!dropEnabled)) {
//			enable = NO;
//		}
//			// If they are all checked, check to see if any of the tables are checked
//		else if (contentEnabled && structureEnabled && dropEnabled) {
//
//			// Only enable the button if at least one table is selected
//			for (NSArray *table in tables)
//			{
//				if ([NSArrayObjectAtIndex(table, 1) boolValue] ||
//						[NSArrayObjectAtIndex(table, 2) boolValue] ||
//						[NSArrayObjectAtIndex(table, 3) boolValue])
//				{
//					enable = YES;
//					break;
//				}
//			}
//		}
//			// Disable if structure is unchecked, but content and drop are as dropping a
//			// table then trying to insert into it is obviously an error.
//		else if (contentEnabled && (!structureEnabled) && (dropEnabled)) {
//			enable = NO;
//		}
//		else {
//			enable = (contentEnabled || (structureEnabled || dropEnabled));
//		}
//	}
//
	[self setIsValidForExport:enable];
}


@end

#pragma mark -

@implementation SPSQLExportHandlerFactory

+ (void)load {
	[super load];
	[[SPExporterRegistry sharedRegistry] registerExportHandler:[[[self alloc] init] autorelease]];
}

- (id<SPExportHandlerInstance>)makeInstanceWithController:(SPExportController *)ctr
{
	id instance = [[SPSQLExportHandler alloc] initWithFactory:self];
	[instance setController:ctr];
	return [instance autorelease];
}

- (NSString *)uniqueName {
	return @"SPSQLExporter";
}

- (NSString *)localizedShortName {
	return NSLocalizedString(@"SQL","sql exporter short name");
}

- (BOOL)supportsExportToMultipleFiles {
	return NO;
}

- (BOOL)supportsExportSource:(SPExportSource)source {
	// When exporting to SQL, only the selected tables option should be enabled
	return (source == SPTableExport);
}


@end

#pragma mark -

@implementation SPSQLExportViewController

- (instancetype)init
{
	if((self = [super initWithNibName:@"SQLExportAccessory" bundle:nil])) {

	}
	return self;
}

- (void)awakeFromNib
{
	// By default a new SQL INSERT statement should be created every 250KiB of data
	[exportSQLInsertNValueTextField setIntegerValue:250];
}


/**
 * Toggles the export button when choosing to include or table structures in an SQL export.
 */
- (IBAction)toggleSQLIncludeStructure:(NSButton *)sender
{
	if (![sender state])
	{
		[exportSQLIncludeDropSyntaxCheck setState:NSOffState];
	}

	[exportSQLIncludeDropSyntaxCheck setEnabled:[sender state]];
	[exportSQLIncludeAutoIncrementValueButton setEnabled:[sender state]];

//	[[exportTableList tableColumnWithIdentifier:SPTableViewDropColumnID] setHidden:(![sender state])];
//	[[exportTableList tableColumnWithIdentifier:SPTableViewStructureColumnID] setHidden:(![sender state])];
//
//	[self _toggleExportButtonOnBackgroundThread];
}

/**
 * Toggles the export button when choosing to include or exclude table contents in an SQL export.
 */
- (IBAction)toggleSQLIncludeContent:(NSButton *)sender
{
//	[[exportTableList tableColumnWithIdentifier:SPTableViewContentColumnID] setHidden:(![sender state])];
//
//	[self _toggleExportButtonOnBackgroundThread];
}

/**
 * Toggles the export button when choosing to include or exclude table drop syntax in an SQL export.
 */
- (IBAction)toggleSQLIncludeDropSyntax:(NSButton *)sender
{
//	[[exportTableList tableColumnWithIdentifier:SPTableViewDropColumnID] setHidden:(![sender state])];
//
//	[self _toggleExportButtonOnBackgroundThread];
}

@end
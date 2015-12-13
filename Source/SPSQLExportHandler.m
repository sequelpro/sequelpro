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
#import "SPTableBaseExportHandler_Protected.h"
#import "SPThreadAdditions.h"
#import "SPExportInitializer.h"
#import "SPExportController+SharedPrivateAPI.h"
#import "MGTemplateEngine.h"
#import "SPDatabaseDocument.h"
#import "SPFunctions.h"

static NSString * const SPTableViewStructureColumnID = @"structure";
static NSString * const SPTableViewContentColumnID   = @"content";
static NSString * const SPTableViewDropColumnID      = @"drop";

static void *_KVOContext;

@interface SPSQLExportViewController : NSViewController {
@public
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

@end

#pragma mark -

@interface SPSQLExportHandlerFactory : NSObject <SPExportHandlerFactory>
// see protocol
@end

#pragma mark -

@interface SPSQLExportHandler ()

+ (NSString *)describeSQLExportInsertDivider:(SPSQLExportInsertDivider)eid;
+ (BOOL)copySQLExportInsertDividerForDescription:(NSString *)xfd to:(SPSQLExportInsertDivider *)dst;

// those are directly bound to the IB controls
@property (nonatomic) BOOL sqlIncludeStructure;
@property (nonatomic) BOOL sqlIncludeContent;
@property (nonatomic) BOOL sqlIncludeDropSyntax;

@end

#pragma mark -

#define avc ((SPSQLExportViewController *)[self accessoryViewController])

@implementation SPSQLExportHandler

@synthesize sqlIncludeStructure;
@synthesize sqlIncludeContent;
@synthesize sqlIncludeDropSyntax;

#define NAMEOF(x) case x: return @#x
#define VALUEOF(x,y,dst) if([y isEqualToString:@#x]) { *dst = x; return YES; }

+ (NSString *)describeSQLExportInsertDivider:(SPSQLExportInsertDivider)eid
{
	switch (eid) {
		NAMEOF(SPSQLInsertEveryNDataBytes);
		NAMEOF(SPSQLInsertEveryNRows);
	}
	return nil;
}

+ (BOOL)copySQLExportInsertDividerForDescription:(NSString *)eidd to:(SPSQLExportInsertDivider *)dst
{
	VALUEOF(SPSQLInsertEveryNDataBytes, eidd, dst);
	VALUEOF(SPSQLInsertEveryNRows,      eidd, dst);
	return NO;
}

#undef NAMEOF
#undef VALUEOF

- (instancetype)initWithFactory:(SPSQLExportHandlerFactory *)factory
{
	if ((self = [super initWithFactory:factory])) {
		[self setCanBeImported:YES];
		SPSQLExportViewController *viewController = [[[SPSQLExportViewController alloc] init] autorelease];
		[viewController setRepresentedObject:self];
		[self setAccessoryViewController:viewController];
		[self setFileExtension:SPFileExtensionSQL];
		[self updateTableColumns];
		_discardKVOEvents = NO;
	}
	return self;
}

- (void)willBecomeActive
{
	[super willBecomeActive];

	// we subscribe to our own properties to notice IB value changes
	[self addObserver:self forKeyPath:@"sqlIncludeStructure" options:0 context:&_KVOContext];
	[self addObserver:self forKeyPath:@"sqlIncludeContent" options:0 context:&_KVOContext];
	[self addObserver:self forKeyPath:@"sqlIncludeDropSyntax" options:0 context:&_KVOContext];
}

- (void)didBecomeInactive
{
	[super didBecomeInactive];

	if([self respondsToSelector:@selector(removeObserver:forKeyPath:context:)]) {
		[self removeObserver:self forKeyPath:@"sqlIncludeStructure" context:&_KVOContext];
		[self removeObserver:self forKeyPath:@"sqlIncludeContent" context:&_KVOContext];
		[self removeObserver:self forKeyPath:@"sqlIncludeDropSyntax" context:&_KVOContext];
	}
	// 10.6 backwards compatibility
	else {
		[self removeObserver:self forKeyPath:@"sqlIncludeStructure"];
		[self removeObserver:self forKeyPath:@"sqlIncludeContent"];
		[self removeObserver:self forKeyPath:@"sqlIncludeDropSyntax"];
	}
}

- (BOOL)canExportSchemaObjectsOfType:(SPTableType)type
{
	switch (type) {
		case SPTableTypeTable:
		case SPTableTypeView:
		case SPTableTypeFunc:
		case SPTableTypeProc:
			return YES;
		case SPTableTypeNone:
		case SPTableTypeEvent:
			;
	}
	return NO;
}

- (SPExportersAndFiles)allExportersForSchemaObjects:(NSArray *)schemaObjects
{
	// Cache the number of tables being exported
	exportTableCount = [schemaObjects count];

	SPSQLExporter *sqlExporter = [[SPSQLExporter alloc] initWithDelegate:self];

	SPDatabaseDocument *tdi = [[self controller] tableDocumentInstance];
	[sqlExporter setSqlDatabaseHost:[tdi host]];
	[sqlExporter setSqlDatabaseName:[tdi database]];
	[sqlExporter setSqlDatabaseVersion:[tdi mySQLVersion]];

	[sqlExporter setSqlOutputIncludeUTF8BOM:([avc->exportUseUTF8BOMButton state] == NSOnState)];
	[sqlExporter setSqlOutputEncodeBLOBasHex:([avc->exportSQLBLOBFieldsAsHexCheck state] == NSOnState)];
	[sqlExporter setSqlOutputIncludeErrors:([avc->exportSQLIncludeErrorsCheck state] == NSOnState)];
	[sqlExporter setSqlOutputIncludeAutoIncrement:([avc->exportSQLIncludeStructureCheck state] && [avc->exportSQLIncludeAutoIncrementValueButton state])];

	[sqlExporter setSqlInsertAfterNValue:SPIntS2U([avc->exportSQLInsertNValueTextField integerValue])];
	[sqlExporter setSqlInsertDivider:(SPSQLExportInsertDivider)[avc->exportSQLInsertDividerPopUpButton indexOfSelectedItem]];

	NSMutableArray *names = [NSMutableArray arrayWithCapacity:[schemaObjects count]];
	// reformat for sqlexporter
	// FIXME: make the exporter use a common format
	for(id<SPExportSchemaObject> obj in schemaObjects) {
		[names addObject:@[
			[obj name],
			@([[[obj addonData] objectForKey:SPTableViewStructureColumnID] boolValue]),
			@([[[obj addonData] objectForKey:SPTableViewContentColumnID] boolValue]),
			@([[[obj addonData] objectForKey:SPTableViewDropColumnID] boolValue]),
			@([obj type])
		]];
	}
	[sqlExporter setSqlExportTables:names];

	SPExportFile *file = [[self controller] exportFileForTableName:(exportTableCount == 1? [(id<SPExportSchemaObject>)[schemaObjects objectAtIndex:0] name] : nil)];

	[sqlExporter setExportOutputFile:file];

	SPExportersAndFiles result = {@[sqlExporter],@[file]};
	[sqlExporter autorelease];

	return result;
}

- (NSDictionary *)settings
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{
			@"SQLIncludeStructure": @([self sqlIncludeStructure]),
			@"SQLIncludeContent":   @([self sqlIncludeContent]),
			@"SQLIncludeErrors":    IsOn(avc->exportSQLIncludeErrorsCheck),
			@"SQLUseUTF8BOM":       IsOn(avc->exportUseUTF8BOMButton),
			@"SQLBLOBFieldsAsHex":  IsOn(avc->exportSQLBLOBFieldsAsHexCheck),
			@"SQLInsertNValue":     @([avc->exportSQLInsertNValueTextField integerValue]),
			@"SQLInsertDivider":    [[self class] describeSQLExportInsertDivider:(SPSQLExportInsertDivider)[avc->exportSQLInsertDividerPopUpButton indexOfSelectedItem]]
	}];

	if([self sqlIncludeStructure]) {
		[dict addEntriesFromDictionary:@{
				@"SQLIncludeAutoIncrementValue":  IsOn(avc->exportSQLIncludeAutoIncrementValueButton),
				@"SQLIncludeDropSyntax":          @([self sqlIncludeDropSyntax])
		}];
	}

	return dict;
}

- (void)applySettings:(NSDictionary *)settings
{
	id o;
	SPSQLExportInsertDivider div;

	_discardKVOEvents = YES; // we'll batch the call to updateTableColumns, so it's not invoked three times in a row

	if((o = [settings objectForKey:@"SQLIncludeContent"]))   [self setSqlIncludeContent:[o boolValue]];

	if((o = [settings objectForKey:@"SQLIncludeStructure"])) [self setSqlIncludeStructure:[o boolValue]];

	if((o = [settings objectForKey:@"SQLIncludeErrors"]))    SetOnOff(o, avc->exportSQLIncludeErrorsCheck);
	if((o = [settings objectForKey:@"SQLUseUTF8BOM"]))       SetOnOff(o, avc->exportUseUTF8BOMButton);
	if((o = [settings objectForKey:@"SQLBLOBFieldsAsHex"]))  SetOnOff(o, avc->exportSQLBLOBFieldsAsHexCheck);
	if((o = [settings objectForKey:@"SQLInsertNValue"]))     [avc->exportSQLInsertNValueTextField setIntegerValue:[o integerValue]];
	if((o = [settings objectForKey:@"SQLInsertDivider"]) && [[self class] copySQLExportInsertDividerForDescription:o to:&div]) [avc->exportSQLInsertDividerPopUpButton selectItemAtIndex:div];

	if([self sqlIncludeStructure]) {
		if((o = [settings objectForKey:@"SQLIncludeAutoIncrementValue"]))  SetOnOff(o, avc->exportSQLIncludeAutoIncrementValueButton);
		if((o = [settings objectForKey:@"SQLIncludeDropSyntax"]))  [self setSqlIncludeDropSyntax:[o boolValue]];
	}

	[self updateTableColumns];
	_discardKVOEvents = NO;
}

- (id)specificSettingsForSchemaObject:(id <SPExportSchemaObject>)obj
{
	// SQL allows per table setting of structure/content/drop table
	if([obj type] == SPTableTypeTable) {
		NSMutableArray *flags = [NSMutableArray arrayWithCapacity:3];

		// we retain the state regardless of whether that column is visible.
		// That way we can restore state if a user changes minds about not exporting a column.
		if([[[obj addonData] objectForKey:SPTableViewStructureColumnID] boolValue]) {
			[flags addObject:@"structure"];
		}

		if([[[obj addonData] objectForKey:SPTableViewContentColumnID] boolValue]) {
			[flags addObject:@"content"];
		}

		if([[[obj addonData] objectForKey:SPTableViewDropColumnID] boolValue]) {
			[flags addObject:@"drop"];
		}

		return flags;
	}
	return nil;
}

- (void)applySpecificSettings:(id)settings forSchemaObject:(id <SPExportSchemaObject>)obj
{
	// SQL allows per table setting of structure/content/drop table
	if([obj type] == SPTableTypeTable) {
		NSArray *flags = settings;
		[[self class] ensureAddonDict:obj];

		// updating the state even if a column is hidden doesn't really hurt either
		[[obj addonData] setObject:@([flags containsObject:@"structure"]) forKey:SPTableViewStructureColumnID];
		[[obj addonData] setObject:@([flags containsObject:@"content"])   forKey:SPTableViewContentColumnID];
		[[obj addonData] setObject:@([flags containsObject:@"drop"])      forKey:SPTableViewDropColumnID];
	}
	
	[self updateValidForExport];
}

- (void)updateValidForExport
{
	BOOL enable = NO;
	BOOL structureEnabled = [self sqlIncludeStructure];
	BOOL contentEnabled   = [self sqlIncludeContent];
	BOOL dropEnabled      = [self sqlIncludeDropSyntax];

	if(structureEnabled || contentEnabled || dropEnabled) {
		for(id<SPExportSchemaObject> obj in [[self controller] allSchemaObjects]) {
			BOOL structure = (structureEnabled && [[[obj addonData] objectForKey:SPTableViewStructureColumnID] boolValue]);
			BOOL content   = (contentEnabled   && [[[obj addonData] objectForKey:SPTableViewContentColumnID] boolValue]);
			BOOL drop      = (dropEnabled      && [[[obj addonData] objectForKey:SPTableViewDropColumnID] boolValue]);

			/* a drop can't appear without structure but with content. "DROP TABLE ...; INSERT ...;" wouldn't make sense.
			 *
			 * obligatory truthiness table
			 * D C S =
			 * ----- --
			 * 0 0 0 F <--
			 * 0 0 1 T
			 * 0 1 0 T
			 * 0 1 1 T
			 * 1 0 0 T
			 * 1 0 1 T
			 * 1 1 0 F <--
			 * 1 1 1 T
			 */
			if(drop && content && !structure)
				continue;

			if(structure || content || drop) {
				enable = YES;
				break;
			}
		}
	}

	[self setIsValidForExport:enable];
}

- (void)updateIncludeStateForAllSchemaObjects:(BOOL)newState
{
	BOOL toggleStructure = [self sqlIncludeStructure];
	BOOL toggleContent   = [self sqlIncludeContent];
	BOOL toggleDropTable = [self sqlIncludeDropSyntax];

	for (id<SPExportSchemaObject> object in [[self controller] allSchemaObjects])
	{
		[[self class] ensureAddonDict:object];
		if (toggleStructure) [[object addonData] setObject:@(newState) forKey:SPTableViewStructureColumnID];
		if (toggleContent)   [[object addonData] setObject:@(newState) forKey:SPTableViewContentColumnID];
		if (toggleDropTable) [[object addonData] setObject:@(newState) forKey:SPTableViewDropColumnID];
	}

	[self updateCanBeImported];
	[self updateValidForExport];
}

- (void)updateIncludeState:(BOOL)newState forSchemaObjects:(NSArray *)objects
{
	for(id <SPExportSchemaObject> object in objects) {
		BOOL toggleStructure = [self sqlIncludeStructure];
		BOOL toggleContent   = [self sqlIncludeContent];
		BOOL toggleDropTable = [self sqlIncludeDropSyntax];

		[[self class] ensureAddonDict:object];
		if (toggleStructure) [[object addonData] setObject:@(newState) forKey:SPTableViewStructureColumnID];
		if (toggleContent)   [[object addonData] setObject:@(newState) forKey:SPTableViewContentColumnID];
		if (toggleDropTable) [[object addonData] setObject:@(newState) forKey:SPTableViewDropColumnID];
	}

	[self updateCanBeImported];
	[self updateValidForExport];
}

- (BOOL)wouldIncludeSchemaObject:(id <SPExportSchemaObject>)obj
{
	return (
		([self sqlIncludeStructure]  && [[[obj addonData] objectForKey:SPTableViewStructureColumnID] boolValue]) ||
		([self sqlIncludeContent]    && [[[obj addonData] objectForKey:SPTableViewContentColumnID] boolValue]) ||
		([self sqlIncludeStructure] && [self sqlIncludeDropSyntax] && [[[obj addonData] objectForKey:SPTableViewDropColumnID] boolValue])
	);
}

- (void)setIncludedSchemaObjects:(NSArray *)objectNames
{
	for(id <SPExportSchemaObject> object in [[self controller] allSchemaObjects]) {
		BOOL toggleStructure = [self sqlIncludeStructure];
		BOOL toggleContent   = [self sqlIncludeContent];
		BOOL toggleDropTable = [self sqlIncludeDropSyntax];

		BOOL matches = [objectNames containsObject:[object name]];

		[[self class] ensureAddonDict:object];
		if (toggleStructure) [[object addonData] setObject:@(toggleStructure && matches) forKey:SPTableViewStructureColumnID];
		if (toggleContent)   [[object addonData] setObject:@(toggleContent && matches)   forKey:SPTableViewContentColumnID];
		if (toggleDropTable) [[object addonData] setObject:@(toggleDropTable && matches) forKey:SPTableViewDropColumnID];
	}

	[self updateCanBeImported];
	[self updateValidForExport];
}

- (void)configureTableColumn:(NSTableColumn *)col
{
	if([[col identifier] isEqualToString:SPTableViewStructureColumnID]) {
		[col setHeaderToolTip:NSLocalizedString(@"Include DDL statements to create the objects",@"export : item list : S column : tooltip")];
		[[col headerCell] setStringValue:NSLocalizedString(@"S","export : item list : S column title (S=structure)")]; // 10.10+ has setTitle:

	}
	else if([[col identifier] isEqualToString:SPTableViewContentColumnID]) {
		[col setHeaderToolTip:NSLocalizedString(@"Include DML statements to fill the tables",@"export : item list : C column : tooltip")];
		[[col headerCell] setStringValue:NSLocalizedString(@"C","export : item list : C column title (C=content)")]; // 10.10+ has setTitle:
	}
	else if([[col identifier] isEqualToString:SPTableViewDropColumnID]) {
		[col setHeaderToolTip:NSLocalizedString(@"Include statements to drop preexisting objects first",@"export : item list : D column : tooltip")];
		[[col headerCell] setStringValue:NSLocalizedString(@"D","export : item list : D column title (D=drop)")]; // 10.10+ has setTitle:
	}
	else {
		SPLog(@"asking for column layout of unknown column [%@]!",col);
		return;
	}

	[col setWidth:15];
	[col setMinWidth:15];
	[col setMaxWidth:15];
	[col setEditable:YES];
	[col setResizingMask:NSTableColumnAutoresizingMask];

	NSButtonCell *dc = [[NSButtonCell alloc] init];
	[dc setButtonType:NSSwitchButton];
	[dc setAllowsMixedState:NO];

	[col setDataCell:[dc autorelease]];
}

- (id)objectValueForTableColumn:(NSTableColumn *)aTableColumn schemaObject:(id <SPExportSchemaObject>)obj
{
	NSAssert([[aTableColumn identifier] isInArray:[self tableColumns]],@"%s: asking for value of unknown table column [%@]",__PRETTY_FUNCTION__,aTableColumn);

	NSNumber *state;
	if((state = [[obj addonData] objectForKey:[aTableColumn identifier]])) return state;
	// if we don't know a key we can just assume it is "unchecked"
	return @NO;
}

- (void)setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn schemaObject:(id <SPExportSchemaObject>)obj
{
	NSAssert([[aTableColumn identifier] isInArray:[self tableColumns]],@"%s: trying to set value of unknown table column [%@]",__PRETTY_FUNCTION__,aTableColumn);

	[[self class] ensureAddonDict:obj];
	[[obj addonData] setObject:([anObject integerValue] == NSOnState? @YES : @NO) forKey:[aTableColumn identifier]];
	[self updateCanBeImported];
	[self updateValidForExport];
}

- (void)updateTableColumns
{
	NSMutableArray *items = [NSMutableArray arrayWithCapacity:3];

	if([self sqlIncludeStructure])  [items addObject:SPTableViewStructureColumnID];
	if([self sqlIncludeContent])    [items addObject:SPTableViewContentColumnID];
	if([self sqlIncludeStructure] && [self sqlIncludeDropSyntax]) [items addObject:SPTableViewDropColumnID];

	[self setTableColumns:items];
	[self updateValidForExport];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// only handle updates from our own registrations
	if(context != &_KVOContext) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}

	if(_discardKVOEvents) return;

	if([keyPath isInArray:@[@"sqlIncludeStructure",@"sqlIncludeContent",@"sqlIncludeDropSyntax"]]) {
		[self updateTableColumns];
	}
}

#pragma mark Delegate

- (void)sqlExportProcessWillBegin:(SPSQLExporter *)exporter
{
	[[self controller] setExportProgressTitle:NSLocalizedString(@"Exporting SQL", @"text showing that the application is exporting SQL")];
	[[self controller] setExportProgressDetail:NSLocalizedString(@"Dumping...", @"text showing that app is writing dump")];
}

- (void)sqlExportProcessComplete:(SPSQLExporter *)exporter
{
	[[self controller] exportEnded:exporter];

	// Check for errors and display the errors sheet if necessary
	if ([exporter didExportErrorsOccur]) {
		[[self controller] openExportErrorsSheetWithString:[exporter sqlExportErrors]];
	}
}

- (void)sqlExportProcessProgressUpdated:(SPSQLExporter *)exporter
{
	[[self controller] setExportProgress:[exporter exportProgressValue]];
}

- (void)sqlExportProcessWillBeginFetchingData:(SPSQLExporter *)exporter
{
	[[self controller] setExportProgressDetail:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Fetching data...", @"export label showing that the app is fetching data for a specific table"), [exporter sqlCurrentTableExportIndex], exportTableCount, [exporter sqlExportCurrentTable]]];

	[[self controller] setExportProgressIndeterminate:NO];
	[[self controller] setExportProgress:0];
}

- (void)sqlExportProcessWillBeginWritingData:(SPSQLExporter *)exporter
{
	[[self controller] setExportProgressDetail:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Writing data...", @"export label showing app if writing data for a specific table"), [exporter sqlCurrentTableExportIndex], exportTableCount, [exporter sqlExportCurrentTable]]];
}

@end

#undef avc

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

@end

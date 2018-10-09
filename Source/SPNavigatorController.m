//
//  SPNavigatorController.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on March 17, 2010.
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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

#import "SPNavigatorController.h"
#import "SPSplitView.h"
#ifndef SP_CODA /* headers */
#import "RegexKitLite.h"
#import "SPNavigatorOutlineView.h"
#import "ImageAndTextCell.h"
#import "SPDatabaseDocument.h"
#import "SPTablesList.h"
#import "SPLogger.h"
#import "SPTooltip.h"
#import "SPAppController.h"
#import "SPDatabaseStructure.h"
#import "SPThreadAdditions.h"

#import <objc/message.h>
#import <SPMySQL/SPMySQL.h>
#endif

static SPNavigatorController *sharedNavigatorController = nil;

@interface SPNavigatorController () <NSOutlineViewDataSource, NSOutlineViewDelegate>

@end

@implementation SPNavigatorController

#ifndef SP_CODA /* unused sort func */
static NSComparisonResult compareStrings(NSString *s1, NSString *s2, void* context)
{
	return (NSComparisonResult)objc_msgSend(s1, @selector(localizedCompare:), s2);
}
#endif


/**
 * Returns the shared query console.
 */
+ (SPNavigatorController *)sharedNavigatorController
{
	@synchronized(self) {
		if (sharedNavigatorController == nil) {
			sharedNavigatorController = [[super allocWithZone:NULL] init];
		}
	}

	return sharedNavigatorController;
}

+ (id)allocWithZone:(NSZone *)zone
{    
	@synchronized(self) {
		return [[self sharedNavigatorController] retain];
	}
	return nil;
}

- (id)init
{
	if((self = [super initWithWindowNibName:@"Navigator"])) {

		schemaDataFiltered  = [[NSMutableDictionary alloc] init];
		allSchemaKeys       = [[NSMutableDictionary alloc] init];
		schemaData          = [[NSMutableDictionary alloc] init];
		expandStatus2       = [[NSMutableDictionary alloc] init];
		cachedSortedKeys    = [[NSMutableDictionary alloc] init];
		infoArray           = [[NSMutableArray alloc] init];
		updatingConnections = [[NSMutableArray alloc] init];
#ifndef SP_CODA
		selectedKey2        = @"";
		ignoreUpdate        = NO;
		isFiltered          = NO;
		isFiltering         = NO;
		[syncButton setState:NSOffState];
		NSDictionaryClass   = [NSDictionary class];
#endif
	}

	return self;

}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if(schemaDataFiltered)  SPClear(schemaDataFiltered);
	if(allSchemaKeys)       SPClear(allSchemaKeys);
	if(schemaData)          SPClear(schemaData);
	if(infoArray)           SPClear(infoArray);
	if(updatingConnections) SPClear(updatingConnections);
	if(expandStatus2)       SPClear(expandStatus2);
	if(cachedSortedKeys)    SPClear(cachedSortedKeys);
#ifndef SP_CODA /* dealloc ivars */
	SPClear(connectionIcon);
	SPClear(databaseIcon);
	SPClear(tableIcon);
	SPClear(viewIcon);
	SPClear(procedureIcon);
	SPClear(functionIcon);
	SPClear(fieldIcon);
#endif

	[super dealloc];
}
/**
 * The following base protocol methods are implemented to ensure the singleton status of this class.
 */

- (id)copyWithZone:(NSZone *)zone { return self; }

- (id)retain { return self; }

- (NSUInteger)retainCount { return NSUIntegerMax; }

- (id)autorelease { return self; }

- (oneway void)release { }

#ifndef SP_CODA
/**
 * Set the window's auto save name and initialise display
 */
- (void)awakeFromNib
{
	prefs = [NSUserDefaults standardUserDefaults];

	// Set up the splitview
	[schemaStatusSplitView setMinSize:32.f ofSubviewAtIndex:0];
	[schemaStatusSplitView setMinSize:16.f ofSubviewAtIndex:1];

	[self setWindowFrameAutosaveName:@"SPNavigator"];
	[outlineSchema2 registerForDraggedTypes:@[SPNavigatorTableDataPasteboardDragType, SPNavigatorPasteboardDragType, NSStringPboardType]];
	[outlineSchema2 setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
	[outlineSchema2 setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];

	connectionIcon = [[NSImage imageNamed:@"network-small"] retain];
	databaseIcon = [[NSImage imageNamed:@"database-small"] retain];
	tableIcon = [[NSImage imageNamed:@"table-small-square"] retain];
	viewIcon = [[NSImage imageNamed:@"table-view-small-square"] retain];
	procedureIcon = [[NSImage imageNamed:@"proc-small"] retain];
	functionIcon = [[NSImage imageNamed:@"func-small"] retain];
	fieldIcon = [[NSImage imageNamed:@"field-small-square"] retain];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNavigator:) name:@"SPDBStructureWasUpdated" object:nil];

}

- (NSString *)windowFrameAutosaveName
{
	return @"SPNavigator";
}

#pragma mark -

- (BOOL)syncMode
{
	if([[self window] isVisible])
		return ([syncButton state] == NSOffState || [outlineSchema2 numberOfSelectedRows] > 1) ? NO : YES;
	return NO;
}

- (void)restoreExpandStatus
{

	if(!schemaData) return;

	NSInteger i;
	if(!isFiltered) {
		for( i = 0; i < [outlineSchema2 numberOfRows]; i++ ) {
			id item = [outlineSchema2 itemAtRow:i];
			id parentObject = [outlineSchema2 parentForItem:item] ? [outlineSchema2 parentForItem:item] : schemaData;
			id parentKeys = [parentObject allKeysForObject:item];
			if(parentKeys && [parentKeys count] == 1)
				if( [expandStatus2 objectForKey:[parentKeys objectAtIndex:0]] )
					[outlineSchema2 expandItem:item];
		}
	}
}

- (void)saveSelectedItems
{
	if(schemaData) {

		if(isFiltered) return;

		selectedKey2 = @"";
		selectionViewPort2 = [outlineSchema2 visibleRect];

		id selection = [outlineSchema2 selectedItem];
		if(selection) {
			id parentObject = [outlineSchema2 parentForItem:selection] ? [outlineSchema2 parentForItem:selection] : schemaData;
			if(!parentObject || ![parentObject isKindOfClass:NSDictionaryClass]) return;
			id parentKeys = [parentObject allKeysForObject:selection];
			if(parentKeys && [parentKeys count] == 1)
				selectedKey2 = [[parentKeys objectAtIndex:0] description];
		}
	}

}

- (void)selectPath:(NSString*)schemaPath
{

	if(schemaPath && [schemaPath length]) {

		// Do not change the selection if a field of schemaPath's table is already selected
		[self saveSelectedItems];
		if([selectedKey2 length] && [selectedKey2 hasPrefix:[NSString stringWithFormat:@"%@%@", schemaPath, SPUniqueSchemaDelimiter]])
			return;

		id item = schemaData;
		NSArray *pathArray = [schemaPath componentsSeparatedByString:SPUniqueSchemaDelimiter];
		if(!pathArray || [pathArray count] == 0) return;
		NSMutableString *aKey = [NSMutableString string];
		[outlineSchema2 collapseItem:[item objectForKey:[pathArray objectAtIndex:0]] collapseChildren:YES];
		for(NSUInteger i=0; i < [pathArray count]; i++) {
			[aKey appendString:[pathArray objectAtIndex:i]];
			if(!item || ![item isKindOfClass:NSDictionaryClass] || ![item objectForKey:aKey]) break;
			item = [item objectForKey:aKey];
			[outlineSchema2 expandItem:item];
			[aKey appendString:SPUniqueSchemaDelimiter];
		}
		if(item != nil) {
			NSInteger itemIndex = [outlineSchema2 rowForItem:item];
			if (itemIndex >= 0) {
				[outlineSchema2 selectRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] byExtendingSelection:NO];
				if([outlineSchema2 numberOfSelectedRows] != 1) return;
				[outlineSchema2 scrollRowToVisible:[outlineSchema2 selectedRow]];
				id selectedItem = [outlineSchema2 selectedItem];
				// Try to scroll the view that all children of schemaPath are visible if possible
				NSInteger cnt = 1;
				if([selectedItem isKindOfClass:NSDictionaryClass] || [selectedItem isKindOfClass:[NSArray class]])
					cnt = [selectedItem count]+1;
				NSRange r = [outlineSchema2 rowsInRect:[outlineSchema2 visibleRect]];
				NSInteger rangeLength = r.length;
				NSInteger offset = (cnt > rangeLength) ? (rangeLength-2) : cnt;
				offset += [outlineSchema2 selectedRow];
				if(offset >= [outlineSchema2 numberOfRows])
					offset = [outlineSchema2 numberOfRows] - 1;
				[outlineSchema2 scrollRowToVisible:offset];
			}
		}
	}
}

- (void)restoreSelectedItems
{

	if(!schemaData) return;

	BOOL viewportWasValid2 = NO;
	selectionViewPort2.size = [outlineSchema2 visibleRect].size;
	viewportWasValid2 = [outlineSchema2 scrollRectToVisible:selectionViewPort2];
	if(!isFiltered && selectedKey2 && [selectedKey2 length]) {
		id item = schemaData;
		NSArray *pathArray = [selectedKey2 componentsSeparatedByString:SPUniqueSchemaDelimiter];
		NSMutableString *aKey = [NSMutableString string];
		for(NSUInteger i=0; i < [pathArray count]; i++) {
			[aKey appendString:[pathArray objectAtIndex:i]];
			if(![item objectForKey:aKey]) break;
			item = [item objectForKey:aKey];
			[aKey appendString:SPUniqueSchemaDelimiter];
		}
		if(item != nil) {
			NSInteger itemIndex = [outlineSchema2 rowForItem:item];
			if (itemIndex >= 0) {
				[outlineSchema2 selectRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] byExtendingSelection:NO];
				if(!viewportWasValid2)
					[outlineSchema2 scrollRowToVisible:[outlineSchema2 selectedRow]];
			}
		}
	}
}

- (void)setIgnoreUpdate:(BOOL)flag
{
	ignoreUpdate = flag;
}

- (void)removeConnection:(NSString*)connectionID
{
	if(schemaData && [schemaData objectForKey:connectionID]) {
		
		NSInteger docCounter = 0;

		// Detect if more than one connection windows with the connectionID are open.
		// If so, don't remove it.
		if ([SPAppDelegate frontDocument]) {
			for(id doc in [SPAppDelegate orderedDocuments]) {
				if([[doc connectionID] isEqualToString:connectionID])
					docCounter++;
				if(docCounter > 1) break;
			}
		}

		if(docCounter > 1) return;

		if(schemaData && [schemaData objectForKey:connectionID] && [SPAppDelegate frontDocument] && [[SPAppDelegate orderedDocuments] count])
			[self saveSelectedItems];

		if(schemaDataFiltered)
			[schemaDataFiltered removeObjectForKey:connectionID];
		if(schemaData)
			[schemaData removeObjectForKey:connectionID];
		if(allSchemaKeys)
			[allSchemaKeys removeObjectForKey:connectionID];

		if([[self window] isVisible]) {
			[outlineSchema2 reloadData];
			[self restoreSelectedItems];
			if(isFiltered)
				[self filterTree:self];
		}
	}
}

- (void)_setSyncButtonOn
{
	[syncButton setState:NSOnState];
	[self syncButtonAction:self];
}

- (void)selectInActiveDocumentItem:(id)item fromView:(id)outlineView
{
	// Do nothing for connection root item yet
	if([outlineView levelForItem:item] == 0) return;

	NSPoint pos = [NSEvent mouseLocation];
	pos.y -= 20;

	// Suppress selecting for not queried database if connection is just querying an other database
	if([outlineView levelForItem:item] == 1 
		&& ![outlineView isExpandable:item] && [updatingConnections count]) {
		[SPTooltip showWithObject:NSLocalizedString(@"The connection is busy. Please wait and try again.", @"the connection is busy. please wait and try again tooltip") 
				atLocation:pos 
				ofType:@"text"];
		
		return;
	}

	
	id parentObject = [outlineView parentForItem:item] ? [outlineView parentForItem:item] : schemaData;
	if(!parentObject) return;
	id parentKeys = [parentObject allKeysForObject:item];
	if(parentKeys && [parentKeys count] == 1) {

		NSArray *pathArray = [[[parentKeys objectAtIndex:0] description] componentsSeparatedByString:SPUniqueSchemaDelimiter];
		if([pathArray count] > 1) {

			SPDatabaseDocument *doc = [SPAppDelegate frontDocument];
			if([doc isWorking]) {
				[SPTooltip showWithObject:NSLocalizedString(@"Active connection window is busy. Please wait and try again.", @"active connection window is busy. please wait and try again. tooltip") 
						atLocation:pos 
						ofType:@"text"];
				return;
			}
			if([[doc connectionID] isEqualToString:[pathArray objectAtIndex:0]]) {

				// TODO: in sync mode switch it off while selecting the item in the doc and re-enable it after a delay of one 0.1sec
				// to avoid gui rendering problems
				NSInteger oldState = [syncButton state];
				[syncButton setState:NSOffState];

				// Select the database and table
				[doc selectDatabase:[pathArray objectAtIndex:1] item:[pathArray objectOrNilAtIndex:2]];

				if(oldState == NSOnState)
					[self performSelector:@selector(_setSyncButtonOn) withObject:nil afterDelay:0.1];

			} else {

				[SPTooltip showWithObject:NSLocalizedString(@"The connection of the active connection window is not identical.", @"the connection of the active connection window is not identical tooltip") 
						atLocation:pos 
						ofType:@"text"];

			}
		}
	}
}

- (void)updateNavigator:(NSNotification *)aNotification
{
	SPDatabaseDocument *object = [(SPDatabaseStructure *)[aNotification object] delegate];

	[self performSelectorOnMainThread:@selector(updateEntriesForConnection:) withObject:object waitUntilDone:NO];
}

- (void)updateEntriesForConnection:(SPDatabaseDocument *)doc
{

	if(ignoreUpdate) {
		ignoreUpdate = NO;
		return;
	}

	if([[self window] isVisible]) {
		[self saveSelectedItems];
		[infoArray removeAllObjects];
		[cachedSortedKeys removeAllObjects];
	}

	if (doc) {

		SPMySQLConnection *theConnection = [doc getConnection];
		if(!theConnection || ![theConnection isConnected]) return;

		NSString *connectionID = [doc connectionID];
		NSString *connectionName = [doc connectionID];

		if(!connectionName || [connectionName isEqualToString:@"_"] || (connectionID && ![connectionName isEqualToString:connectionID]) ) {
			return;
		}

		[updatingConnections addObject:connectionName];

		if(![schemaData objectForKey:connectionName]) {
			[schemaData setObject:[NSMutableDictionary dictionary] forKey:connectionName];
		}

		// Remove deleted dbs
		NSArray *dbs = [doc allDatabaseNames];
		NSArray *keys = [[schemaData objectForKey:connectionName] allKeys];
		for(id db in keys) {
			if(![dbs containsObject:[[db componentsSeparatedByString:SPUniqueSchemaDelimiter] objectAtIndex:1]]) {
				[[schemaData objectForKey:connectionName] removeObjectForKey:db];
			}
		}
		id structureData = [[doc databaseStructureRetrieval] structure];
		if(structureData && [structureData objectForKey:connectionName] && [[structureData objectForKey:connectionName] isKindOfClass:NSDictionaryClass]) {
			for(id item in [[structureData objectForKey:connectionName] allKeys])
				[[schemaData objectForKey:connectionName] setObject:[[structureData objectForKey:connectionName] objectForKey:item] forKey:item];

			NSArray *a = [[doc databaseStructureRetrieval] allStructureKeys];
			if(a)
				[allSchemaKeys setObject:a forKey:connectionName];
		} else {
			[schemaData setObject:@{} forKey:[NSString stringWithFormat:@"%@&DEL&no data loaded yet", connectionName]];
			[allSchemaKeys setObject:@[] forKey:connectionName];
		}

		[updatingConnections removeObject:connectionName];

		if([[self window] isVisible]) {
			[outlineSchema2 reloadData];

			[self restoreExpandStatus];
			[self restoreSelectedItems];
		}

	}

	if([[self window] isVisible])
		[self syncButtonAction:self];

	if(isFiltered && [[self window] isVisible])
		[self filterTree:self];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"SPNavigatorStructureWasUpdated" object:self];

}

- (BOOL)schemaPathExistsForConnection:(NSString*)connectionID andDatabase:(NSString*)dbname
{
	NSString *db_id = [NSString stringWithFormat:@"%@%@%@", connectionID, SPUniqueSchemaDelimiter, dbname];

	if([schemaData objectForKey:connectionID] && [[[schemaData objectForKey:connectionID] allKeys] containsObject:db_id])
		return YES;

	return NO;
}

- (void)removeDatabase:(NSString*)db_id forConnectionID:(NSString*)connectionID
{
	[[schemaData objectForKey:connectionID] removeObjectForKey:db_id];
	[outlineSchema2 reloadData];
}
#endif

- (NSDictionary *)dbStructureForConnection:(NSString*)connectionID
{
	if([schemaData objectForKey:connectionID])
		return [NSDictionary dictionaryWithDictionary:[schemaData objectForKey:connectionID]];
	return nil;
}

- (NSArray *)allSchemaKeysForConnection:(NSString*)connectionID
{
	if([allSchemaKeys objectForKey:connectionID]) {
		NSArray *a = [allSchemaKeys objectForKey:connectionID];
		if(a && [a count])
			return a;
	}
	return nil;
}

/**
 * Returns an array with 1 for db and 2 for table name if table name is not a db name and versa visa and the found name
 * in cases user entered `foo` but an unique item is found like `Foo`.
 * Otherwise it return 0. Mainly used for completion to know whether a `foo`. can only be 
 * a db name or a table name.
 */
- (NSArray *)getUniqueDbIdentifierFor:(NSString*)term andConnection:(NSString*)connectionID ignoreFields:(BOOL)ignoreFields
{

	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH[c] %@", [NSString stringWithFormat:@"%@%@", SPUniqueSchemaDelimiter, [term lowercaseString]]];
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:5];

	NSString *re = [NSString stringWithFormat:@"%@.*?%@.*?%@", SPUniqueSchemaDelimiter, SPUniqueSchemaDelimiter, SPUniqueSchemaDelimiter];
	for(id r in [[allSchemaKeys objectForKey:connectionID] filteredArrayUsingPredicate:predicate]) {
		if(ignoreFields) {
			if(![r isMatchedByRegex:re])
				[result addObject:r];
		} else {
			[result addObject:r];
		}
	}

	if([result count] < 1 ) return @[@0, @""];
	if([result count] == 1) {
		NSArray *split = [[result objectAtIndex:0] componentsSeparatedByString:SPUniqueSchemaDelimiter];
		if([split count] == 2 ) return [NSArray arrayWithObjects:@1, [split lastObject], nil];
		if([split count] == 3 ) return [NSArray arrayWithObjects:@2, [split lastObject], nil];
		return @[@0, @""];
	}
	// case if field is equal to a table or db name
	NSMutableArray *arr = [NSMutableArray array];
	for(NSString *item in result) {
		if([[item componentsSeparatedByString:SPUniqueSchemaDelimiter] count] < 4)
			[arr addObject:item];
	}
	if([arr count] == 1) {
		NSArray *split = [[arr objectAtIndex:0] componentsSeparatedByString:SPUniqueSchemaDelimiter];
		if([split count] == 2 ) [NSArray arrayWithObjects:@1, [split lastObject], nil];
		if([split count] == 3 ) [NSArray arrayWithObjects:@2, [split lastObject], nil];
		return @[@0, @""];
	}
	return @[@0, @""];
}

#ifndef SP_CODA

- (BOOL)isUpdatingConnection:(NSString*)connectionID
{
	return ([updatingConnections containsObject:connectionID]) ? YES : NO;
}

- (BOOL)isUpdating
{
	return ([updatingConnections count]) ? YES : NO;
}

#pragma mark -
#pragma mark IBActions


- (IBAction)reloadAllStructures:(id)sender
{

	// Reset everything for current active doc connection
	SPDatabaseDocument *doc = [SPAppDelegate frontDocument];
	if(!doc) return;
	NSString *connectionID = [doc connectionID];
	if(!connectionID || [connectionID length] < 2) return;

	[searchField setStringValue:@""];
	[schemaDataFiltered removeAllObjects];
	[schemaData removeObjectForKey:connectionID];
	[allSchemaKeys removeObjectForKey:connectionID];
	[updatingConnections removeAllObjects];
	[infoArray removeAllObjects];
	[cachedSortedKeys removeAllObjects];
	[expandStatus2 removeAllObjects];
	[outlineSchema2 reloadData];
	selectedKey2 = @"";
	selectionViewPort2 = NSZeroRect;
	[syncButton setState:NSOffState];
	isFiltered = NO;

	if (![[doc getConnection] isConnected]) return;

	[[doc databaseStructureRetrieval] queryDbStructureInBackgroundWithUserInfo:@{@"forceUpdate" : @YES}];
}

- (IBAction)outlineViewAction:(id)sender
{
	
}

- (IBAction)filterTree:(id)sender
{

	NSString *pattern = [[[searchField stringValue] stringByReplacingOccurrencesOfString:@"." withString:SPUniqueSchemaDelimiter] lowercaseString];

	[self saveSelectedItems];

	id currentItem = [outlineSchema2 selectedItem];
	id parentObject = nil;
	if([outlineSchema2 levelForItem:currentItem] == 0 && !isFiltered)
		parentObject = currentItem;
	else
		if(isFiltered)
			parentObject = [outlineSchema2 parentForItem:currentItem] ? [outlineSchema2 parentForItem:currentItem] : schemaDataFiltered;
		else
			parentObject = [outlineSchema2 parentForItem:currentItem] ? [outlineSchema2 parentForItem:currentItem] : schemaData;

	@try{


		NSString *connectionID = nil;
		if(parentObject && [[parentObject allKeys] count])
			connectionID = [[[[parentObject allKeys] objectAtIndex:0] componentsSeparatedByString:SPUniqueSchemaDelimiter] objectAtIndex:0];
	
		if((pattern && ![pattern length]) || !parentObject || ![[parentObject allKeys] count] || !connectionID || [connectionID length] < 2 || ![allSchemaKeys objectForKey:connectionID]) {
			isFiltered = NO;
			[searchField setStringValue:@""];
			[schemaDataFiltered removeAllObjects];
			[outlineSchema2 reloadData];
			[self restoreExpandStatus];
			[self restoreSelectedItems];
			isFiltering = NO;
			return;
		}

		if(isFiltering || [pattern length] < 2) return;

		isFiltered = YES;

		[syncButton setState:NSOffState];

		NSMutableDictionary *structure = [NSMutableDictionary dictionary];
		[structure setObject:[NSMutableDictionary dictionary] forKey:connectionID];


		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[c] %@", pattern];
		NSArray *filteredItems = [[allSchemaKeys objectForKey:connectionID] filteredArrayUsingPredicate:predicate];

		BOOL searchFailed = YES;

		for(NSString* item in filteredItems) {
			NSArray *a = [item componentsSeparatedByString:SPUniqueSchemaDelimiter];

			NSString *db_id = [NSString stringWithFormat:@"%@%@%@", connectionID,SPUniqueSchemaDelimiter,NSArrayObjectAtIndex(a, 1)];

			if(!a || [a count] < 2) continue;

			if(![[structure valueForKey:connectionID] valueForKey:db_id]) {
				searchFailed = NO;
				[[structure valueForKey:connectionID] setObject:[NSMutableDictionary dictionary] forKey:db_id];
			}
			if([a count] > 2) {

				NSString *table_id = [NSString stringWithFormat:@"%@%@%@", db_id,SPUniqueSchemaDelimiter,[a objectAtIndex:2]];

				if(![[[structure valueForKey:connectionID] valueForKey:db_id] valueForKey:table_id]) {
					searchFailed = NO;
					[[[structure valueForKey:connectionID] valueForKey:db_id] setObject:[NSMutableDictionary dictionary] forKey:table_id];
				}

				id srcType = [[[[schemaData objectForKey:connectionID] objectForKey:db_id] objectForKey:table_id] objectForKey:@"  struct_type  "];
				NSMutableDictionary *targetDict = [[[structure valueForKey:connectionID] valueForKey:db_id] valueForKey:table_id];
				[targetDict setObject:(srcType ? srcType : @(SPTableTypeTable)) forKey:@"  struct_type  "];

				if([a count] > 3) {
					NSString *field_id = [NSString stringWithFormat:@"%@%@%@", table_id,SPUniqueSchemaDelimiter,[a objectAtIndex:3]];
					if([[[[schemaData objectForKey:connectionID] objectForKey:db_id] objectForKey:table_id] objectForKey:field_id])
						[[[[structure valueForKey:connectionID] valueForKey:db_id] valueForKey:table_id] setObject:
							[[[[schemaData objectForKey:connectionID] objectForKey:db_id] objectForKey:table_id] objectForKey:field_id] forKey:field_id];
				}
			}
		}
		if(searchFailed)
			NSBeep();

		[schemaDataFiltered setDictionary:structure];

		[NSThread detachNewThreadWithName:@"SPNavigatorController update after filtering" target:self selector:@selector(reloadAfterFiltering) object:nil];
	}
	@catch(id ae)
	{
		NSPoint pos = [NSEvent mouseLocation];
		pos.y -= 20;

		[SPTooltip showWithObject:NSLocalizedString(@"Filtering failed. Please try again.", @"filtering failed. please try again. tooltip") 
				atLocation:pos 
				ofType:@"text"];
		
		isFiltering = NO;
	}


}

- (void)reloadAfterFiltering
{
	@autoreleasepool {
		isFiltering = YES;
		[outlineSchema2 reloadData];
		[outlineSchema2 expandItem:[outlineSchema2 itemAtRow:0] expandChildren:YES];
		isFiltering = NO;
	}
}

- (IBAction)syncButtonAction:(id)sender
{

	if(!schemaData) return;

	if([syncButton state] == NSOnState) {

		if(isFiltered) {
			isFiltered = NO;
			[schemaDataFiltered removeAllObjects];
			[outlineSchema2 reloadData];
			[searchField setStringValue:@""];
		}

		SPDatabaseDocument *doc = [SPAppDelegate frontDocument];
		if (doc) {
			NSMutableString *key = [NSMutableString string];
			[key setString:[doc connectionID]];
			if([doc database] && [(NSString*)[doc database] length]){
				[key appendString:SPUniqueSchemaDelimiter];
				[key appendString:[doc database]];
			}
			if([doc table] && [(NSString*)[doc table] length]){
				[key appendString:SPUniqueSchemaDelimiter];
				[key appendString:[doc table]];
			}
			[self selectPath:key];
		}
	}
}

#pragma mark -
#pragma mark outline delegates

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
	SPNavigatorOutlineView *ov = [notification object];
	id item = [[notification userInfo] objectForKey:@"NSObject"];
	
	id parentObject = nil;
	if(isFiltered && ov == outlineSchema2)
		parentObject = [ov parentForItem:item] ? [ov parentForItem:item] : schemaDataFiltered;
	else
		parentObject = [ov parentForItem:item] ? [ov parentForItem:item] : schemaData;

	if(!parentObject || ![parentObject allKeysForObject:item] || ![[parentObject allKeysForObject:item] count]) return;

	if(ov == outlineSchema2 && !isFiltered)
	{
		[expandStatus2 setObject:@"" forKey:[[parentObject allKeysForObject:item] objectAtIndex:0]];
	}
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
	SPNavigatorOutlineView *ov = [notification object];
	id item = [[notification userInfo] objectForKey:@"NSObject"];
	
	id parentObject = nil;
	if(isFiltered && ov == outlineSchema2)
		parentObject = [ov parentForItem:item] ? [ov parentForItem:item] : schemaDataFiltered;
	else
		parentObject = [ov parentForItem:item] ? [ov parentForItem:item] : schemaData;
	
	if(!parentObject || ![parentObject allKeysForObject:item] || ![[parentObject allKeysForObject:item] count]) return;

	if(ov == outlineSchema2 && !isFiltered)
		[expandStatus2 removeObjectForKey:[[parentObject allKeysForObject:item] objectAtIndex:0]];
}

- (id)outlineView:(id)outlineView child:(NSInteger)childIndex ofItem:(id)item
{

	if (item == nil) {
		if(isFiltered && outlineView == outlineSchema2)
			item = schemaDataFiltered;
		else
			item = schemaData;
	}

	if ([item isKindOfClass:NSDictionaryClass]) {

		NSArray *allKeys = (NSArray*)objc_msgSend(item, @selector(allKeys));

		// If item contains more than 50 keys store the sort order and use the cached data to speed up
		// the displaying of the tree data
		if(!isFiltered && [allKeys count] > 50 && [outlineView parentForItem:item]) {

			// Get the parent
			id parentObject = [outlineView parentForItem:item];

			// No parent return the child by using the normal sort routine
			if(!parentObject || ![parentObject isKindOfClass:NSDictionaryClass])
				return [item objectForKey:NSArrayObjectAtIndex([allKeys sortedArrayUsingFunction:compareStrings context:nil],childIndex)];

			// Get the parent key name for storing
			id parentKeys = [parentObject allKeysForObject:item];
			if(parentKeys && [parentKeys count] == 1) {

				NSString *itemRef = [NSArrayObjectAtIndex(parentKeys,0) description];

				// For safety reasons
				if(!itemRef)
					return [item objectForKey:NSArrayObjectAtIndex([allKeys sortedArrayUsingFunction:compareStrings context:nil],childIndex)];

				// Not yet cached so do it
				if(![cachedSortedKeys objectForKey:itemRef])
					[cachedSortedKeys setObject:[allKeys sortedArrayUsingFunction:compareStrings context:nil] forKey:itemRef];

				return [item objectForKey:NSArrayObjectAtIndex([cachedSortedKeys objectForKey:itemRef],childIndex)];

			}

			// If something failed return the child by using the normal way
			return [item objectForKey:NSArrayObjectAtIndex([allKeys sortedArrayUsingFunction:compareStrings context:nil],childIndex)];

		} else {
			return [item objectForKey:NSArrayObjectAtIndex([allKeys sortedArrayUsingFunction:compareStrings context:nil],childIndex)];
		}
	}
	else if ([item isKindOfClass:[NSArray class]]) 
	{
		return NSArrayObjectAtIndex(item,childIndex);
	}
	return nil;

}

- (BOOL)outlineView:(id)outlineView isItemExpandable:(id)item
{
	if([item isKindOfClass:NSDictionaryClass]) {
		// Suppress expanding for PROCEDUREs and FUNCTIONs
		if((SPTableType)[[item objectForKey:@"  struct_type  "] intValue] > SPTableTypeView) {
			return NO;
		}
		return YES;
	}
	
	return NO;
}

- (NSInteger)outlineView:(id)outlineView numberOfChildrenOfItem:(id)item
{

	if(isFiltered && outlineView == outlineSchema2) {
		if(item == nil)
			return [schemaDataFiltered count];
	} else {
		if(item == nil)
			return [schemaData count];
	}

	if([item isKindOfClass:NSDictionaryClass] || [item isKindOfClass:[NSArray class]])
		return [item count];

	return 0;
}

- (id)outlineView:(id)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{

	id parentObject = nil;

	if(outlineView == outlineSchema2 && isFiltered) {
		parentObject = [outlineView parentForItem:item];
		if(!parentObject) parentObject = schemaDataFiltered;
	} else {
		parentObject = [outlineView parentForItem:item];
		if(!parentObject) parentObject = schemaData;
	}

	if(!parentObject) return @"…";

	if ([(NSString*)[tableColumn identifier] characterAtIndex:0] == 'f') {
		// top level is connection
		if([outlineView levelForItem:item] == 0) {
			[[tableColumn dataCell] setImage:connectionIcon];
			if([parentObject allKeysForObject:item] && [[parentObject allKeysForObject:item] count]) {
				NSString *key = [[parentObject allKeysForObject:item] objectAtIndex:0];
				if([key rangeOfString:@"&SSH&"].length)
					return [[key componentsSeparatedByString:@"&SSH&"] objectAtIndex:0];
				else if([key rangeOfString:@"&DEL&"].length)
					return [[key componentsSeparatedByString:@"&DEL&"] objectAtIndex:0];
				else
					return key;
			} else {
				return @"";
			}
		}

		if ([parentObject isKindOfClass:NSDictionaryClass]) {
			if([item isKindOfClass:NSDictionaryClass]) {
				NSNumber *type = [item objectForKey:@"  struct_type  "];
				if(type) {
					switch((SPTableType)[type intValue]) {
						case SPTableTypeTable:
							[[tableColumn dataCell] setImage:tableIcon];
							break;
						case SPTableTypeView:
							[[tableColumn dataCell] setImage:viewIcon];
							break;
						case SPTableTypeProc:
							[[tableColumn dataCell] setImage:procedureIcon];
							break;
						case SPTableTypeFunc:
							[[tableColumn dataCell] setImage:functionIcon];
							break;
						default:
							break;
					}
				} else {
					[[tableColumn dataCell] setImage:databaseIcon];
				}
				return [[NSArrayObjectAtIndex([parentObject allKeysForObject:item], 0) componentsSeparatedByString:SPUniqueSchemaDelimiter] lastObject];

			} else {
				id allKeysForItem = [parentObject allKeysForObject:item];
				if([allKeysForItem count]) {
					if([outlineView levelForItem:item] == 1) {
						// It's a db name which wasn't queried yet
						[[tableColumn dataCell] setImage:databaseIcon];
						return [[NSArrayObjectAtIndex(allKeysForItem,0) componentsSeparatedByString:SPUniqueSchemaDelimiter] lastObject];
					} else {
						// It's a field and use the key "  struct_type  " to increase the distance between node and first child
						if(![NSArrayObjectAtIndex(allKeysForItem,0) hasPrefix:@"  "]) {
							[[tableColumn dataCell] setImage:fieldIcon];
							return [[NSArrayObjectAtIndex([parentObject allKeysForObject:item], 0) componentsSeparatedByString:SPUniqueSchemaDelimiter] lastObject];
						} else {
							[[tableColumn dataCell] setImage:[NSImage imageNamed:@"dummy-small"]];
							return nil;
						}
					}
				}
				return @"…";
			}
		}
		return [item description];
	}
	else if ([(NSString*)[tableColumn identifier] characterAtIndex:0] == 't') {

		// top level is connection
		if([outlineView levelForItem:item] == 0) {
			if([parentObject allKeysForObject:item] && [[parentObject allKeysForObject:item] count]) {
				NSString *key = [[parentObject allKeysForObject:item] objectAtIndex:0];
				if([key rangeOfString:@"&SSH&"].length)
					return [NSString stringWithFormat:@"ssh: %@", [[[key componentsSeparatedByString:@"&SSH&"] lastObject]  stringByReplacingOccurrencesOfString:@"&DEL&" withString:@" - "]];
				else if([key rangeOfString:@"&DEL&"].length)
					return [[key componentsSeparatedByString:@"&DEL&"] lastObject];
				else
					return @"";
			} else {
				return @"";
			}
		}

		if([outlineView levelForItem:item] == 3 && [item isKindOfClass:[NSArray class]])
		{
			NSTokenFieldCell *b = [[[NSTokenFieldCell alloc] initTextCell:NSArrayObjectAtIndex(item, 9)] autorelease];
			[b setEditable:NO];
			[b setAlignment:NSRightTextAlignment];
			[b setFont:[NSFont systemFontOfSize:11]];
			[b setWraps:NO];
			return b;
		}
		return nil;
	}

	return nil;
}

- (BOOL)outlineView:outlineView isGroupItem:(id)item
{
	if ([outlineView levelForItem:item] == 3)
		return NO;
		
	return YES;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	id parentObject = nil;

	if(outlineView == outlineSchema2 && isFiltered)
		parentObject = [outlineView parentForItem:item] ? [outlineView parentForItem:item] : schemaDataFiltered;
	else
		parentObject = [outlineView parentForItem:item] ? [outlineView parentForItem:item] : schemaData;

	if(!parentObject) return 0;

	if([outlineView levelForItem:item] == 3 && [outlineView isExpandable:[outlineView itemAtRow:[outlineView rowForItem:item]-1]])
		return 5.0f;

	return 18.0f;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item
{
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	id parentObject = nil;

	if(outlineView == outlineSchema2 && isFiltered)
		parentObject = [outlineView parentForItem:item] ? [outlineView parentForItem:item] : schemaDataFiltered;
	else
		parentObject = [outlineView parentForItem:item] ? [outlineView parentForItem:item] : schemaData;

	if(!parentObject) return NO;

	if([outlineView levelForItem:item] == 3 && [outlineView isExpandable:[outlineView itemAtRow:[outlineView rowForItem:item]-1]])
		return NO;
	return YES;
}
/**
 * Double-click on item selects the chosen path in active connection window
 */
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	[self selectInActiveDocumentItem:item fromView:outlineView];
	return NO;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)aNotification
{

	id selectedItem = [[aNotification object] selectedItem];

	if(selectedItem) {
		[infoArray removeAllObjects];
		// First object is used as dummy to increase the distance between first item and header
		[infoArray addObject:@""];

		// selected item is a field
		if([selectedItem isKindOfClass:[NSArray class]]) {
			NSUInteger i = 0;
			for(i=0; i<[selectedItem count]-2; i++) {
				NSString *item = NSArrayObjectAtIndex(selectedItem, i);
				if([item isNSNull] || ![item length]) continue;
				[infoArray addObject:[NSString stringWithFormat:@"%@: %@", 
					[self tableInfoLabelForIndex:i ofType:SPTableTypeTable],
					[item stringByReplacingOccurrencesOfString:@"," withString:@", "]]];
			}
		}

		// check if selected item is a PROCEDURE or FUNCTION
		else if([selectedItem isKindOfClass:NSDictionaryClass] && [selectedItem objectForKey:@"  struct_type  "] && (SPTableType)[[selectedItem objectForKey:@"  struct_type  "] intValue] > SPTableTypeView) {
			NSInteger i = 0;
			SPTableType type = (SPTableType)[[selectedItem objectForKey:@"  struct_type  "] intValue];
			NSArray *keys = [selectedItem allKeys];
			NSInteger keyIndex = 0;
			if(keys && [keys count] == 2) {
				// there only are two keys, get that key which doesn't begin with "  " due to it's the struct_type key
				if([NSArrayObjectAtIndex(keys, keyIndex) hasPrefix:@"  "]) keyIndex++;
				if(NSArrayObjectAtIndex(keys, keyIndex) && [[selectedItem objectForKey:NSArrayObjectAtIndex(keys, keyIndex)] isKindOfClass:[NSArray class]]) {
					for(id item in [selectedItem objectForKey:NSArrayObjectAtIndex(keys, keyIndex)]) {
						if([item isKindOfClass:[NSString class]] && [(NSString*)item length]) {
							[infoArray addObject:[NSString stringWithFormat:@"%@: %@", [self tableInfoLabelForIndex:i ofType:type], item]];
						}
						i++;
					}
				}
			}
		}
	}
	[infoTable reloadData];
}

- (void)outlineView:(NSOutlineView *)outlineView didClickTableColumn:(NSTableColumn *)tableColumn
{
	if(outlineView == outlineSchema2) {
		[schemaStatusSplitView setPosition:1000 ofDividerAtIndex:0];
		[schema12SplitView setPosition:0 ofDividerAtIndex:0];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	// Provide data for our custom type, and simple NSStrings.
	[pboard declareTypes:@[SPNavigatorTableDataPasteboardDragType, SPNavigatorPasteboardDragType, NSStringPboardType] owner:self];

	// Collect the actual schema paths without leading connection ID
	NSMutableArray *draggedItems = [NSMutableArray array];
	for(id item in items) {
		id parentObject = [outlineView parentForItem:item] ? [outlineView parentForItem:item] : schemaData;
		if(!parentObject) return NO;
		id parentKeys = [parentObject allKeysForObject:item];
		if(parentKeys && [parentKeys count] == 1)
			[draggedItems addObject:[[[parentKeys objectAtIndex:0] description] stringByReplacingOccurrencesOfRegex:[NSString stringWithFormat:@"^.*?%@", SPUniqueSchemaDelimiter] withString:@""]];
	}

	// Drag the array with schema paths
	NSMutableData *arraydata = [[[NSMutableData alloc] init] autorelease];
	NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:arraydata] autorelease];
	[archiver encodeObject:draggedItems forKey:@"itemdata"];
	[archiver finishEncoding];
	[pboard setData:arraydata forType:SPNavigatorPasteboardDragType];

	if([draggedItems count] == 1) {
		NSArray *pathComponents = [[draggedItems objectAtIndex:0] componentsSeparatedByString:SPUniqueSchemaDelimiter];
		// Is a table?
		if([pathComponents count] == 2) {
			[pboard setString:[NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ SELECT * FROM %@", 
					[[pathComponents lastObject] backtickQuotedString],
					[pathComponents componentsJoinedByPeriodAndBacktickQuoted]
				] forType:SPNavigatorTableDataPasteboardDragType];
		}
	}
	// For external destinations provide a comma separated string
	NSMutableString *dragString = [NSMutableString string];
	for(id item in draggedItems) {
		if([dragString length]) [dragString appendString:@", "];
		[dragString appendString:[[item componentsSeparatedByString:SPUniqueSchemaDelimiter] componentsJoinedByPeriodAndBacktickQuotedAndIgnoreFirst]];
	}

	if(![dragString length]) return NO;

	[pboard setString:dragString forType:NSStringPboardType];
	return YES;
}

#pragma mark -
#pragma mark table delegates

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if(aTableView == infoTable && infoArray)
		return [infoArray count];

	return 0;

}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
	// Use first row as dummy to increase the distance between content and header
	return (row == 0) ? 5.0f : 16.0f;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	if(aTableView == infoTable && infoArray)
		return NO;
		
	return YES;
}


- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if(aTableView == infoTable) {
		if(rowIndex == 0) {
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"dummy-small"]];
			[(ImageAndTextCell*)aCell setIndentationLevel:0];
			[(ImageAndTextCell*)aCell setDrawsBackground:NO];
		} else {
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"table-property"]];
			[(ImageAndTextCell*)aCell setIndentationLevel:1];
			[(ImageAndTextCell*)aCell setDrawsBackground:NO];
		}
	}
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if(aTableView == infoTable && infoArray && (NSUInteger)rowIndex < [infoArray count]) {
		return [infoArray objectAtIndex:rowIndex];
	}

	return nil;
}

- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{

	if(tableView == infoTable) {
		CGFloat winHeight = [[self window] frame].size.height;
		// winHeight = (winHeight < 500) ? winHeight/2 : 500;
		[schemaStatusSplitView setPosition:winHeight-200 ofDividerAtIndex:0];
		[outlineSchema2 scrollRowToVisible:[outlineSchema2 selectedRow]];
	}
}

#pragma mark -
#pragma mark others

- (NSString*)tableInfoLabelForIndex:(NSInteger)anIndex ofType:(SPTableType)type
{
	if(type == SPTableTypeTable || type == SPTableTypeView) {
		switch (anIndex) {
			case 0:
				return NSLocalizedString(@"Type", @"type label (Navigator)");
			case 1:
				return NSLocalizedString(@"Default", @"default label");
			case 2:
				return NSLocalizedString(@"Is Nullable", @"is nullable label (Navigator)");
			case 3:
				return NSLocalizedString(@"Encoding", @"encoding label (Navigator)");
			case 4:
				return NSLocalizedString(@"Collation", @"collation label (Navigator)");
			case 5:
				return NSLocalizedString(@"Key", @"key label (Navigator)");
			case 6:
				return NSLocalizedString(@"Extra", @"extra label (Navigator)");
			case 7:
				return NSLocalizedString(@"Privileges", @"privileges label (Navigator)");
			case 8:
				return NSLocalizedString(@"Comment", @"comment label");
		}
	}
	else if(type == SPTableTypeProc) {
		switch (anIndex) {
			case 0:
				return NSLocalizedString(@"DTD Identifier", @"dtd identifier label (Navigator)");
			case 1:
				return NSLocalizedString(@"SQL Data Access", @"sql data access label (Navigator)");
			case 2:
				return NSLocalizedString(@"Is Deterministic", @"is deterministic label (Navigator)");
			case 3:
				return NSLocalizedString(@"Execution Privilege", @"execution privilege label (Navigator)");
			case 4:
				return NSLocalizedString(@"Definer", @"definer label (Navigator)");
		}
	}
	else if(type == SPTableTypeFunc) {
		switch (anIndex) {
			case 0:
				return NSLocalizedString(@"Return Type", @"return type label (Navigator)");
			case 1:
				return NSLocalizedString(@"SQL Data Access", @"sql data access label (Navigator)");
			case 2:
				return NSLocalizedString(@"Is Deterministic", @"is deterministic label (Navigator)");
			case 3:
				return NSLocalizedString(@"Execution Privilege", @"execution privilege label (Navigator)");
			case 4:
				return NSLocalizedString(@"Definer", @"definer label (Navigator)");
		}
	}
	return @"";
}
#endif
@end

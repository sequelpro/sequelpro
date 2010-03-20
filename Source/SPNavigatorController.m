//
//  $Id$
//
//  SPNavigatorController.m
//  sequel-pro
//
//  Created by Hans-J. Bibiko on March 17, 2010.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPNavigatorController.h"
#import "RegexKitLite.h"
#import "SPConstants.h"


static SPNavigatorController *sharedNavigatorController = nil;

@implementation SPNavigatorController


/*
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
}

- (id)init
{
	if((self = [super initWithWindowNibName:@"Navigator"])) {

		schemaData = [[NSMutableDictionary alloc] init];

	}

	return self;

}

- (void)dealloc
{
	if(schemaData) [schemaData release];
}
/*
 * The following base protocol methods are implemented to ensure the singleton status of this class.
 */

- (id)copyWithZone:(NSZone *)zone { return self; }

- (id)retain { return self; }

- (NSUInteger)retainCount { return NSUIntegerMax; }

- (id)autorelease { return self; }

- (void)release { }

/**
 * Set the window's auto save name and initialise display
 */
- (void)awakeFromNib
{
	prefs = [NSUserDefaults standardUserDefaults];

	[self setWindowFrameAutosaveName:@"SPNavigator"];

}

- (NSString *)windowFrameAutosaveName
{
	return @"SPNavigator";
}

#pragma mark -
#pragma mark IBActions

- (IBAction)updateEntries:(id)sender;
{
	id selectedItem1 = nil;
	id selectedItem2 = nil;
	if(schemaData) {
		selectedItem1 = [outlineSchema1 itemAtRow:[outlineSchema1 selectedRow]];
		selectedItem2 = [outlineSchema2 itemAtRow:[outlineSchema2 selectedRow]];
		[schemaData release]; schemaData = nil;
	}
	schemaData = [[NSMutableDictionary alloc] init];
	if ([[[NSDocumentController sharedDocumentController] documents] count]) {
		for(id doc in [[NSDocumentController sharedDocumentController] documents]) {

			if(![[doc valueForKeyPath:@"mySQLConnection"] isConnected]) continue;

			NSString *connectionName = [doc connectionID];

			if(!connectionName || [connectionName isEqualToString:@"_"]) continue;

			if(![schemaData objectForKey:connectionName]) {

				if([[doc valueForKeyPath:@"mySQLConnection"] getDbStructure] && [[[doc valueForKeyPath:@"mySQLConnection"] getDbStructure] objectForKey:connectionName]) {
					[schemaData setObject:[[[doc valueForKeyPath:@"mySQLConnection"] getDbStructure] objectForKey:connectionName] forKey:connectionName];
				} else {

					if([[doc valueForKeyPath:@"mySQLConnection"] serverMajorVersion] > 4) {
						[schemaData setObject:[NSDictionary dictionary] forKey:[NSString stringWithFormat:@"%@ – no data loaded yet", connectionName]];
					} else {
						[schemaData setObject:[NSDictionary dictionary] forKey:[NSString stringWithFormat:@"%@ – no data for this server version", connectionName]];
					}

				}
			}
		}

		[outlineSchema1 reloadData];
		[outlineSchema2 reloadData];
		if(selectedItem1) {
			NSInteger itemIndex = [outlineSchema1 rowForItem:selectedItem1];
			if (itemIndex < 0) {
				return;
			}

			[outlineSchema1 selectRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] byExtendingSelection:NO];
		}
		if(selectedItem2) {
			NSInteger itemIndex = [outlineSchema2 rowForItem:selectedItem2];
			if (itemIndex < 0) {
				return;
			}

			[outlineSchema2 selectRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] byExtendingSelection:NO];
		}
	}
}

- (IBAction)outlineViewAction:(id)sender
{
	
}

#pragma mark -
#pragma mark outline delegates

- (id)outlineView:(id)outlineView child:(NSInteger)index ofItem:(id)item
{
	if (item == nil) item = schemaData;

	if ([item isKindOfClass:[NSDictionary class]] && [item allKeys] && [[item allKeys] count]) {
		NSSortDescriptor *desc = [[NSSortDescriptor alloc] initWithKey:nil ascending:YES selector:@selector(localizedCompare:)];
		NSArray *sortedItems = [[item allKeys] sortedArrayUsingDescriptors:[NSArray arrayWithObject:desc]];
		[desc release];
		return [item objectForKey:[sortedItems objectAtIndex:index]];
	}
	else if ([item isKindOfClass:[NSArray class]]) 
	{
		return [item objectAtIndex:index];
	}
	return nil;
}

- (BOOL)outlineView:(id)outlineView isItemExpandable:(id)item
{
	if([item isKindOfClass:[NSDictionary class]] && [item count]) {
		// Suppress expanding for PROCEDUREs and FUNCTIONs
		if([item objectForKey:@"  struct_type  "] && [[item objectForKey:@"  struct_type  "] intValue] > 1) {
			return NO;
		}
		return YES;
	}
	
	return NO;
}

- (NSInteger)outlineView:(id)outlineView numberOfChildrenOfItem:(id)item
{

	if(item == nil)
		return [schemaData count];

	if([item isKindOfClass:[NSDictionary class]] || [item isKindOfClass:[NSArray class]])
		return [item count];

	return 0;
}

- (id)outlineView:(id)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{

	id parentObject = [outlineView parentForItem:item] ? [outlineView parentForItem:item] : schemaData;

	if ([[tableColumn identifier] isEqualToString:@"field"]) {

		// top level is connection
		if([outlineView levelForItem:item] == 0) {
			[[tableColumn dataCell] setImage:[NSImage imageNamed:@"network-small"]];
			return [[[[parentObject allKeysForObject:item] objectAtIndex:0] componentsSeparatedByString:@"&SSH&"] objectAtIndex:0];
		}

		if ([parentObject isKindOfClass:[NSDictionary class]]) {
			if([item isKindOfClass:[NSDictionary class]]) {
				if([item objectForKey:@"  struct_type  "]) {

					NSInteger type = [[item objectForKey:@"  struct_type  "] intValue];
					switch(type) {
						case 0:
						[[tableColumn dataCell] setImage:[NSImage imageNamed:@"table-small-square"]];
						break;
						case 1:
						[[tableColumn dataCell] setImage:[NSImage imageNamed:@"table-view-small-square"]];
						break;
						case 2:
						[[tableColumn dataCell] setImage:[NSImage imageNamed:@"proc-small"]];
						break;
						case 3:
						[[tableColumn dataCell] setImage:[NSImage imageNamed:@"func-small"]];
						break;
					}
				} else {
					[[tableColumn dataCell] setImage:[NSImage imageNamed:@"database-small"]];
				}
				return [[[[parentObject allKeysForObject:item] objectAtIndex:0] componentsSeparatedByString:SPUniqueSchemaDelimiter] lastObject];

			} else {
				// It's a field and use the key "  struct_type  " to increase the distance between node and first child
				if(![[[parentObject allKeysForObject:item] objectAtIndex:0] hasPrefix:@"  "]) {
					[[tableColumn dataCell] setImage:[NSImage imageNamed:@"field-small-square"]];
					return [[[[parentObject allKeysForObject:item] objectAtIndex:0] componentsSeparatedByString:SPUniqueSchemaDelimiter] lastObject];
				} else {
					[[tableColumn dataCell] setImage:[NSImage imageNamed:@"dummy-small"]];
					return nil;
				}
			}
		}
		return [item description];
	}
	else if ([[tableColumn identifier] isEqualToString:@"type"]) {

		if([outlineView levelForItem:item] == 0 && [[[parentObject allKeysForObject:item] objectAtIndex:0] rangeOfString:@"&SSH&"].length) {
			return [NSString stringWithFormat:@"ssh: %@", [[[[parentObject allKeysForObject:item] objectAtIndex:0] componentsSeparatedByString:@"&SSH&"] lastObject]];
		}

		if ([item isKindOfClass:[NSArray class]] && ![[[parentObject allKeysForObject:item] objectAtIndex:0] hasPrefix:@"  "]) 
		{
			NSString *typ = [NSString stringWithFormat:@"%@,%@,%@", [[item objectAtIndex:0] stringByReplacingOccurrencesOfRegex:@"\\(.*?,.*?\\)" withString:@"(…)"], [item objectAtIndex:1], [item objectAtIndex:2]]; 
			NSTokenFieldCell *b = [[[NSTokenFieldCell alloc] initTextCell:typ] autorelease];
			[b setEditable:NO];
			[b setAlignment:NSRightTextAlignment];
			[b setFont:[NSFont systemFontOfSize:11]];
			[b setDelegate:self];
			[b setWraps:NO];
			return b;
		}
		return nil;
	}

	return nil;
}

- (BOOL)outlineView:outlineView isGroupItem:(id)item
{
	if ([item isKindOfClass:[NSDictionary class]])
		return YES;
		
	return NO;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	id parentObject = [outlineView parentForItem:item] ? [outlineView parentForItem:item] : schemaData;
	
	// Use "  struct_type  " as placeholder to increase distance between table and first field name otherwise it looks ugly 
	if([[[parentObject allKeysForObject:item] objectAtIndex:0] hasPrefix:@"  "])
		return 5.0;

	return 18.0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item
{
	return YES;
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{

}
// - (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
// {
//     return [tableColumn dataCell];
// 
//     // If we return a cell for the 'nil' tableColumn, it will be used as a "full width" cell and span all the columns
//     if ([item isKindOfClass:[NSDictionary class]] && (tableColumn == nil)) {
//             // We want to use the cell for the name column, but we could construct a new cell if we wanted to, or return a different cell for each row.
//             return [[outlineView tableColumnWithIdentifier:@"field"] dataCell];
//     }
//     return [tableColumn dataCell];
// }

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	id parentObject = [outlineView parentForItem:item] ? [outlineView parentForItem:item] : schemaData;
	if([[[parentObject allKeysForObject:item] objectAtIndex:0] hasPrefix:@"  "])
		return NO;
	return YES;
}

@end

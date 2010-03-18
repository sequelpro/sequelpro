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

	// [self updateEntries:self];

	[self setWindowFrameAutosaveName:@"SPNavigator"];
	
}

- (NSString *)windowFrameAutosaveName
{
	return @"SPNavigator";
}


- (IBAction)updateEntries:(id)sender;
{
	if(schemaData) [schemaData release]; schemaData = nil;
	schemaData = [[NSMutableDictionary alloc] init];
	if ([[[NSDocumentController sharedDocumentController] documents] count]) {
		for(id doc in [[NSDocumentController sharedDocumentController] documents]) {
			NSString *connectionName;
			if([(NSString*)[doc port] length])
				connectionName = [NSString stringWithFormat:@"%@:%@", [doc host], [doc port]];
			else
				connectionName = [doc host];
			if(![schemaData objectForKey:connectionName]) {
				id data = [[doc valueForKeyPath:@"mySQLConnection"] getDbStructure];
				if(data)
					[schemaData setObject:data forKey:connectionName];
				else
					[schemaData setObject:@"No data available" forKey:connectionName];
			}
		}
		[outlineSchema1 reloadData];
		[outlineSchema2 reloadData];
	}
}

- (IBAction)outlineViewAction:(id)sender
{
	
}

// ================================================================
//  NSOutlineView data source methods
// ================================================================

- (id)outlineView:(id)outlineView child:(NSInteger)index ofItem:(id)item
{
	if (item == nil) item = schemaData;

	if ([item isKindOfClass:[NSDictionary class]] && [item allKeys] && [[item allKeys] count]) {
		NSSortDescriptor *desc = [[NSSortDescriptor alloc] initWithKey:nil ascending:YES selector:@selector(localizedCompare:)];
		NSArray *sortedItems = [[item allKeys] sortedArrayUsingDescriptors:[NSArray arrayWithObject:desc]];
		[desc release];
		if(index < [sortedItems count])
			return [item objectForKey:[sortedItems objectAtIndex:index]];
	}

	return nil;
}

- (BOOL)outlineView:(id)outlineView isItemExpandable:(id)item
{
	if([item isKindOfClass:[NSDictionary class]] && [item count]) {
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

	if([item isKindOfClass:[NSDictionary class]]) {
		// if([item objectForKey:@"  struct_type  "])
		// 	return [item count] - 1;
		// else
			return [item count];
	}
		

	return 0;
}

- (id)outlineView:(id)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{

	id parentObject = [outlineView parentForItem:item] ? [outlineView parentForItem:item] : schemaData;

	if ([[tableColumn identifier] isEqualToString:@"field"]) {
		if ([parentObject isKindOfClass:[NSDictionary class]]) {
			if([outlineView parentForItem:item]) {
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
				} else {
					// It's a field
					if(![[[parentObject allKeysForObject:item] objectAtIndex:0] hasPrefix:@"  "])
						[[tableColumn dataCell] setImage:[NSImage imageNamed:@"field-small-square"]];
					else
						[[tableColumn dataCell] setImage:[NSImage imageNamed:@"dummy-small"]];
				}
			} else {
				[[tableColumn dataCell] setImage:[NSImage imageNamed:@"network-small"]];
			}
			if([[parentObject allKeysForObject:item] count])
				// if(![[[parentObject allKeysForObject:item] objectAtIndex:0] hasPrefix:@"  "])
					// return [[parentObject allKeysForObject:item] objectAtIndex:0];
					// return [[parentObject allKeysForObject:item] componentsJoinedByString:@"|"];

				return [NSString stringWithFormat:@"%@ %ld", [[parentObject allKeysForObject:item] description], [outlineView levelForItem:item]];

			return nil;
		}
		return nil;
	}
	else if ([[tableColumn identifier] isEqualToString:@"type"]) {
		if ([item isKindOfClass:[NSArray class]] && ![[[parentObject allKeysForObject:item] objectAtIndex:0] hasPrefix:@"  "]) 
		{
			NSTokenFieldCell *b = [[[NSTokenFieldCell alloc] initTextCell:[item componentsJoinedByString:@", "]] autorelease];
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

	return 148.0;
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

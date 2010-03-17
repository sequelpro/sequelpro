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

	if ([[[NSDocumentController sharedDocumentController] documents] count]) {
		for(id doc in [[NSDocumentController sharedDocumentController] documents]) {
			NSString *connectionName = [NSString stringWithFormat:@"%@@%@", [doc user], [doc host]];
			if(![schemaData objectForKey:connectionName])
				[schemaData setObject:[[doc valueForKeyPath:@"mySQLConnection"] getDbStructure] forKey:connectionName];
		}
	}

	[self setWindowFrameAutosaveName:@"SPNavigator"];
	
}

- (NSString *)windowFrameAutosaveName
{
	return @"SPNavigator";
}


- (void)updateEntries
{

	[schemaData removeAllObjects];
	if ([[[NSDocumentController sharedDocumentController] documents] count]) {
		for(id doc in [[NSDocumentController sharedDocumentController] documents]) {
			NSString *connectionName = [NSString stringWithFormat:@"%@@%@", [doc user], [doc host]];
			if(![schemaData objectForKey:connectionName])
				[schemaData setObject:[[doc valueForKeyPath:@"mySQLConnection"] getDbStructure] forKey:connectionName];
		}
	}
	// [outlineSchema1 reloadItem:nil reloadChildren:YES];
	// [outlineSchema2 reloadItem:nil reloadChildren:YES];
}

- (IBAction)outlineViewAction:(id)sender
{
	
}

// ================================================================
//  NSOutlineView data source methods
// ================================================================

- (id)outlineView:(id)outlineView child:(NSInteger)index ofItem:(id)item
{
	if (item == nil)
		item = schemaData;

	if ([item isKindOfClass:[NSArray class]]) 
		return [item objectAtIndex:index];

	else if ([item isKindOfClass:[NSDictionary class]]) 
		return [item objectForKey:[[item allKeys] objectAtIndex:index]];

	return nil;
}

- (BOOL)outlineView:(id)outlineView isItemExpandable:(id)item
{
	if([item isKindOfClass:[NSDictionary class]] && [item count] && [[item objectForKey:@"  struct_type  "] intValue] < 2)
		return YES;
	
	return NO;
}

- (NSInteger)outlineView:(id)outlineView numberOfChildrenOfItem:(id)item
{

	if(item == nil)
		return [schemaData count];

	if([item isKindOfClass:[NSDictionary class]])
		return [item count];
	else if([item isKindOfClass:[NSArray class]])
		return 0;
	
	return 0;
}

- (id)outlineView:(id)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ([[tableColumn identifier] isEqualToString:@"field"]) {
		id parentObject = [outlineView parentForItem:item] ? [outlineView parentForItem:item] : schemaData;
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
					// [[tableColumn dataCell] setImage:[NSImage imageNamed:@"field-small-square"]];
					[[tableColumn dataCell] setImage:[NSImage imageNamed:@"dummy-small"]];
				}
			} else {
				[[tableColumn dataCell] setImage:[NSImage imageNamed:@"dummy-small"]];
			}
			// if(![[[parentObject allKeysForObject:item] objectAtIndex:0] hasPrefix:@"  "])
				return [[parentObject allKeysForObject:item] objectAtIndex:0];

			return nil;
		}
		return nil;
	}
	else if ([[tableColumn identifier] isEqualToString:@"type"]) {
		if ([item isKindOfClass:[NSString class]]) 
		{
			return nil;
		} 
		else if ([item isKindOfClass:[NSDictionary class]]) 
		{
			return nil;
		}
		else if ([item isKindOfClass:[NSArray class]]) 
		{
			NSTokenFieldCell *b = [[[NSTokenFieldCell alloc] initTextCell:[item componentsJoinedByString:@", "]] autorelease];
			[b setEditable:NO];
			[b setAlignment:NSRightTextAlignment];
			[b setFont:[NSFont systemFontOfSize:11]];
			[b setDelegate:self];
			[b setWraps:NO];
			return b;
		}
	}

	return nil;
}

- (BOOL)outlineView:outlineView isGroupItem:(id)item
{
	if([item isKindOfClass:[NSDictionary class]])
		return YES;

	return NO;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	if([item isKindOfClass:[NSDictionary class]])
		return 18.0;
	return 20.0;
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
	return YES;
}

@end

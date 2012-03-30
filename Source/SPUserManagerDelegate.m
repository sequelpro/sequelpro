//
//  $Id$
//
//  SPUserManagerDelegate.m
//  sequel-pro
//
//  Created by Mark Townsend on Jan 01, 2009
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

#import "SPUserManagerDelegate.h"
#import "SPUserMO.h"
#import "SPServerSupport.h"
#import "ImageAndTextCell.h"

static NSString *SPGeneralTabIdentifier = @"General";
static NSString *SPGlobalPrivilegesTabIdentifier = @"Global Privileges";
static NSString *SPResourcesTabIdentifier = @"Resources";
static NSString *SPSchemaPrivilegesTabIdentifier = @"Schema Privileges";

@interface SPUserManager (SPDeclaredAPI)

- (void)_initializeSchemaPrivs;
- (void)_initializeAvailablePrivs;
- (void)_selectParentFromSelection;
- (void)_selectFirstChildOfParentNode;
- (NSArray *)_fetchUserWithUserName:(NSString *)username;

- (NSArray *)_fetchPrivsWithUser:(NSString *)username schema:(NSString *)selectedSchema host:(NSString *)host;

@end


@implementation SPUserManager (SPUserManagerDelegate)

#pragma mark -
#pragma mark SplitView delegate methods

/**
 * Return the maximum possible size of the splitview.
 */
- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	return proposedMax - 620;
}

/**
 * Return the minimum possible size of the splitview.
 */
- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	return proposedMin + 120;
}

#pragma mark -
#pragma mark TableView Delegate Methods

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	id object = [notification object];
	
	if (object == schemasTableView) {
		[grantedSchemaPrivs removeAllObjects];
		[grantedTableView reloadData];
		
		[self _initializeAvailablePrivs];
		
		if ([[treeController selectedObjects] count] > 0 && [[schemaController selectedObjects] count] > 0) {
			NSManagedObject *user = [[treeController selectedObjects] objectAtIndex:0];
			
			// Check to see if the user host node was selected
			if ([user valueForKey:@"host"]) {
				NSString *selectedSchema = [[schemaController selectedObjects] objectAtIndex:0];
				
				NSArray *results = [self _fetchPrivsWithUser:[[user parent] valueForKey:@"user"] 
                                                      schema:[selectedSchema stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"]
                                                        host:[user valueForKey:@"host"]];
				
				if ([results count] > 0) {
					NSManagedObject *priv = [results objectAtIndex:0];
					
					for (NSPropertyDescription *property in [priv entity])
					{
						if ([[property name] hasSuffix:@"_priv"] && [[priv valueForKey:[property name]] boolValue])
						{
							NSString *displayName = [[[property name] stringByReplacingOccurrencesOfString:@"_priv" withString:@""] replaceUnderscoreWithSpace];
							NSDictionary *newDict = [NSDictionary dictionaryWithObjectsAndKeys:displayName, @"displayName", [property name], @"name", nil];
							[grantedController addObject:newDict];
							
							// Remove items from available so they can't be added twice.
							NSPredicate *predicate = [NSPredicate predicateWithFormat:@"displayName like[cd] %@", displayName];
							NSArray *previousObjects = [[availableController arrangedObjects] filteredArrayUsingPredicate:predicate];
							
							for (NSDictionary *dict in previousObjects)
							{
								[availableController removeObject:dict];
							}
						}
					}
				}
				
                [availableTableView setEnabled:YES];
			}
		} 
		else {
            [availableTableView setEnabled:NO];
        }
	}
	else if (object == grantedTableView) {
		[removeSchemaPrivButton setEnabled:[[grantedController selectedObjects] count] > 0];
	}
	else if (object == availableTableView) {
		[addSchemaPrivButton setEnabled:[[availableController selectedObjects] count] > 0];
	}		
}

#pragma mark -
#pragma mark Tab View Delegate methods

- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    BOOL retVal = YES;
	
    if ([[treeController selectedObjects] count] == 0) return NO;
    
    // Currently selected object in tree
    id selectedObject = [[treeController selectedObjects] objectAtIndex:0];
    
    // If we are selecting a tab view that requires there be a child,
    // make sure there is a child to select.  If not, don't allow it.
    if ([[tabViewItem identifier] isEqualToString:SPGlobalPrivilegesTabIdentifier] || 
		[[tabViewItem identifier] isEqualToString:SPResourcesTabIdentifier] ||
		[[tabViewItem identifier] isEqualToString:SPSchemaPrivilegesTabIdentifier]) {
        
		id parent = [selectedObject parent];
        
		retVal = parent ? ([[parent children] count] > 0) : ([[selectedObject children] count] > 0); 
        
		if (!retVal) {
            NSAlert *alert = [NSAlert alertWithMessageText:@"User doesn't have any hosts."
                                             defaultButton:NSLocalizedString(@"Add Host", @"Add Host")
                                           alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
                                               otherButton:nil
                                 informativeTextWithFormat:@"This user doesn't have any hosts associated with it. User will be deleted unless one is added"];
            
			if ([alert runModal] == NSAlertDefaultReturn) {
                [self addHost:nil];
            }
        }
		
		// If this is the resources tab, enable or disable the controls based on the server's support for them
		if ([[tabViewItem identifier] isEqualToString:SPResourcesTabIdentifier]) {
			
			BOOL serverSupportsUserMaxVars = [serverSupport supportsUserMaxVars];
			
			// Disable the fields according to the version
			[maxUpdatesTextField setEnabled:serverSupportsUserMaxVars];
			[maxConnectionsTextField setEnabled:serverSupportsUserMaxVars];
			[maxQuestionsTextField setEnabled:serverSupportsUserMaxVars];
		}
    }
	
    return retVal;
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ([[treeController selectedObjects] count] == 0) return;
	
	id selectedObject = [[treeController selectedObjects] objectAtIndex:0];
	
	// If the selected tab is General and a child is selected, select the
	// parent (user info).
	if ([[tabViewItem identifier] isEqualToString:SPGeneralTabIdentifier]) {
		if ([selectedObject parent]) {
			[self _selectParentFromSelection];
		}
	} 
	else if ([[tabViewItem identifier] isEqualToString:SPGlobalPrivilegesTabIdentifier] || 
			 [[tabViewItem identifier] isEqualToString:SPResourcesTabIdentifier] ||
			 [[tabViewItem identifier] isEqualToString:SPSchemaPrivilegesTabIdentifier]) {
		// If the tab is either Global Privs or Resources and we have a user 
		// selected, then open tree and select first child node.
		[self _selectFirstChildOfParentNode];
	}
}

- (void)tabView:(NSTabView *)usersTabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ([[tabViewItem identifier] isEqualToString:SPSchemaPrivilegesTabIdentifier]) {
		[self _initializeSchemaPrivs];
	}
}

#pragma mark -
#pragma mark Outline view Delegate Methods

- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([cell isKindOfClass:[ImageAndTextCell class]])
	{
		// Determines which Image to display depending on parent or child object		
		NSImage *image = [[NSImage imageNamed:[(NSManagedObject *)[item  representedObject] parent] ? NSImageNameNetwork : NSImageNameUser] retain];
		
		[image setScalesWhenResized:YES];
		[image setSize:(NSSize){16, 16}];
		[(ImageAndTextCell *)cell setImage:image];
		[image release];
	}
}

- (BOOL)outlineView:(NSOutlineView *)olv isGroupItem:(id)item
{
	return NO;
}

- (BOOL)outlineView:(NSOutlineView *)olv shouldSelectItem:(id)item
{
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)olv shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return ([[[item representedObject] children] count] == 0);
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	if ([[treeController selectedObjects] count] == 0) return;
	
	id selectedObject = [[treeController selectedObjects] objectAtIndex:0];
	
	if ([selectedObject parent] == nil && !([[[tabView selectedTabViewItem] identifier] isEqualToString:@"General"])) {
		[tabView selectTabViewItemWithIdentifier:SPGeneralTabIdentifier];
	}
	else {
		if ([selectedObject parent] != nil && [[[tabView selectedTabViewItem] identifier] isEqualToString:@"General"]) {
			[tabView selectTabViewItemWithIdentifier:SPGlobalPrivilegesTabIdentifier];
		}
	}
	
	if ([selectedObject parent] != nil && [selectedObject host] == nil)
	{
		[selectedObject setValue:@"%" forKey:@"host"];
		[outlineView reloadItem:selectedObject];
	}
	
	[schemasTableView deselectAll:nil];
	[grantedTableView deselectAll:nil];
	[availableTableView deselectAll:nil];
}

- (BOOL)selectionShouldChangeInOutlineView:(NSOutlineView *)olv
{
	if ([[treeController selectedObjects] count] > 0)
	{
		id selectedObject = [[treeController selectedObjects] objectAtIndex:0];
		
		// Check parents
		if ([selectedObject valueForKey:@"parent"] == nil)
		{
			NSString *name = [selectedObject valueForKey:@"user"];
			NSArray *results = [self _fetchUserWithUserName:name];
			
			if ([results count] > 1)
			{
				NSAlert *alert = [NSAlert alertWithMessageText:@"Duplicate User"
												 defaultButton:NSLocalizedString(@"OK", @"OK button")
											   alternateButton:nil
												   otherButton:nil
									 informativeTextWithFormat:@"A user with that name already exists"];
				[alert runModal];
				return NO;
			}
		}
		else
		{
			NSArray *children = [selectedObject valueForKeyPath:@"parent.children"];
			NSString *host = [selectedObject valueForKey:@"host"];
			
			for (NSManagedObject *child in children)
			{
				if (![selectedObject isEqual:child] && [[child valueForKey:@"host"] isEqualToString:host])
				{
					NSAlert *alert = [NSAlert alertWithMessageText:@"Duplicate Host"
													 defaultButton:NSLocalizedString(@"OK", @"OK button")
												   alternateButton:nil
													   otherButton:nil
										 informativeTextWithFormat:@"A user with that host already exists"];
					
					[alert runModal];
					
					return NO;
				}
			}
		}
	}
	
	return YES;
}

@end

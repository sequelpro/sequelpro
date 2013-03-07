//
//  $Id$
//
//  SPUserManagerDelegate.m
//  sequel-pro
//
//  Created by Mark Townsend on Jan 1, 2009.
//  Copyright (c) 2009 Mark Townsend. All rights reserved.
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPUserManagerDelegate.h"
#import "SPUserMO.h"
#import "SPServerSupport.h"
#import "ImageAndTextCell.h"

static NSString *SPGeneralTabIdentifier = @"General";
static NSString *SPGlobalPrivilegesTabIdentifier = @"Global Privileges";
static NSString *SPResourcesTabIdentifier = @"Resources";
static NSString *SPSchemaPrivilegesTabIdentifier = @"Schema Privileges";

@interface SPUserManager (DeclaredAPI)

- (void)_initializeSchemaPrivs;
- (void)_initializeAvailablePrivs;
- (void)_selectParentFromSelection;
- (void)_selectFirstChildOfParentNode;
- (NSArray *)_fetchUserWithUserName:(NSString *)username;

- (NSArray *)_fetchPrivsWithUser:(NSString *)username schema:(NSString *)selectedSchema host:(NSString *)host;

@end

@implementation SPUserManager (SPUserManagerDelegate)

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

	if (![treeController commitEditing]) {
		return NO;
	}

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
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"User has no hosts", @"user has no hosts message")
                                             defaultButton:NSLocalizedString(@"Add Host", @"Add Host")
                                           alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"This user doesn't have any hosts associated with it. It will be deleted unless one is added", @"user has no hosts informative message")];
            
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
			
			if ([results count] > 1) {
				NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Duplicate User", @"duplicate user message")
												 defaultButton:NSLocalizedString(@"OK", @"OK button")
											   alternateButton:nil
												   otherButton:nil
									 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"A user with the name '%@' already exists", @"duplicate user informative message"), name]];
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
					NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Duplicate Host", @"duplicate host message")
													 defaultButton:NSLocalizedString(@"OK", @"OK button")
												   alternateButton:nil
													   otherButton:nil
										 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"A user with the host '%@' already exists", @"duplicate host informative message"), host]];
					
					[alert runModal];
					
					return NO;
				}
			}
		}
	}
	
	return YES;
}

@end

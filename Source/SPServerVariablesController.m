//
//  $Id$
//
//  SPServerVariablesController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 13, 2009
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import <MCPKit/MCPKit.h>

#import "SPServerVariablesController.h"
#import "SPArrayAdditions.h"
#import "TableDocument.h"
#import "SPConstants.h"

@interface SPServerVariablesController (PrivateAPI)

- (void)_getDatabaseServerVariables;
- (void)_updateServerVariablesFilterForFilterString:(NSString *)filterString;
- (void)_copyServerVariablesToPasteboardIncludingName:(BOOL)name andValue:(BOOL)value;

@end

@implementation SPServerVariablesController

@synthesize connection;

/**
 * Initialisation
 */
- (id)init
{
	if ((self = [super initWithWindowNibName:@"DatabaseServerVariables"])) {
		variables = [[NSMutableArray alloc] init];
	}
	
	return self;
}

/**
 * Interface initialisation
 */
- (void)awakeFromNib
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	
	// Set the process table view's vertical gridlines if required
	[variablesTableView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];

	// Set the strutcture and index view's font
	BOOL useMonospacedFont = [prefs boolForKey:SPUseMonospacedFonts];
	
	for (NSTableColumn *column in [variablesTableView tableColumns])
	{
		[[column dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
	
	// Register as an observer for the when the UseMonospacedFonts preference changes
	[prefs addObserver:self forKeyPath:SPUseMonospacedFonts options:NSKeyValueObservingOptionNew context:NULL];
}

#pragma mark -
#pragma mark IBAction methods

/**
 * Copy implementation for server variables table view.
 */
- (IBAction)copy:(id)sender
{
	[self _copyServerVariablesToPasteboardIncludingName:YES andValue:YES];
}

/**
 * Copies the name(s) of the selected server variables.
 */
- (IBAction)copyServerVariableName:(id)sender
{
	[self _copyServerVariablesToPasteboardIncludingName:YES andValue:NO];
}

/**
 * Copies the value(s) of the selected server variables.
 */
- (IBAction)copyServerVariableValue:(id)sender
{
	[self _copyServerVariablesToPasteboardIncludingName:NO andValue:YES];
}

/**
 * Close the server variables sheet.
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[self window] returnCode:[sender tag]];
	[[self window] orderOut:self];
	
	// If the filtered array is allocated and it's not a reference to the processes array get rid of it
	if ((variablesFiltered) && (variablesFiltered != variables)) {
		[variablesFiltered release], variablesFiltered = nil;
	}		
}

/**
 * Saves the server variables to the selected file.
 */
- (IBAction)saveServerVariables:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:@"cnf"];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];
	
	[panel beginSheetForDirectory:nil file:@"ServerVariables" modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}


#pragma mark -
#pragma mark Other methods

/**
 * Displays the process list sheet attached to the supplied window.
 */
- (void)displayServerVariablesSheetAttachedToWindow:(NSWindow *)window
{
	// Weak reference
	variablesFiltered = variables;
	
	// Get the variables
	[self _getDatabaseServerVariables];
	
	// Reload the tableview
	[variablesTableView reloadData];
	
	// If the search field already has value from when the panel was previously open, apply the filter.
	if ([[filterVariablesSearchField stringValue] length] > 0) {
		[self _updateServerVariablesFilterForFilterString:[filterVariablesSearchField stringValue]];
	}
	
	// Open the sheet
	[NSApp beginSheet:[self window] modalForWindow:window modalDelegate:self didEndSelector:nil contextInfo:nil];
}

/**
 * Invoked when the save panel is dismissed.
 */
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	if (returnCode == NSOKButton) {
		if ([variablesFiltered count] > 0) {
			NSMutableString *variablesString = [NSMutableString stringWithFormat:@"# MySQL server variables for %@\n\n", [(TableDocument *)[[NSApp mainWindow] delegate] host]];
			
			for (NSDictionary *variable in variablesFiltered) 
			{
				[variablesString appendString:[NSString stringWithFormat:@"%@ = %@\n", [variable objectForKey:@"Variable_name"], [variable objectForKey:@"Value"]]];
			}
			
			[variablesString writeToFile:[panel filename] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
		}
	}
}

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	
	if (action == @selector(copy:)) {
		return ([variablesTableView numberOfSelectedRows] > 0);
	}
	
	// Copy selected server variable name(s)
	if ([menuItem action] == @selector(copyServerVariableName:)) {
		[menuItem setTitle:([variablesTableView numberOfSelectedRows] > 1) ? NSLocalizedString(@"Copy Variable Names", @"copy server variable names menu item") : NSLocalizedString(@"Copy Variable Name", @"copy server variable name menu item")];
		
		return ([variablesTableView numberOfSelectedRows] > 0);
	}
	
	// Copy selected server variable value(s)
	if ([menuItem action] == @selector(copyServerVariableValue:)) {
		[menuItem setTitle:([variablesTableView numberOfSelectedRows] > 1) ? NSLocalizedString(@"Copy Variable Values", @"copy server variable values menu item") : NSLocalizedString(@"Copy Variable Value", @"copy server variable value menu item")];
		
		return ([variablesTableView numberOfSelectedRows] > 0);
	}
	
	return YES;
}

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	// Display table veiew vertical gridlines preference changed
	if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
        [variablesTableView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
	// Use monospaced fonts preference changed
	else if ([keyPath isEqualToString:SPUseMonospacedFonts]) {
		
		BOOL useMonospacedFont = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
		
		for (NSTableColumn *column in [variablesTableView tableColumns])
		{
			[[column dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
		
		[variablesTableView reloadData];
	}
}

#pragma mark -
#pragma mark Tableview delegate methods

/**
 * Table view delegate method. Returns the number of rows in the table veiw.
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [variablesFiltered count];
}

/**
 * Table view delegate method. Returns the specific object for the request column and row.
 */
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{	
	return [[variablesFiltered objectAtIndex:row] valueForKey:[tableColumn identifier]];
}

#pragma mark -
#pragma mark Text field delegate methods

/**
 * Apply the filter string to the current process list.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	id object = [notification object];
	
	if (object == filterVariablesSearchField) {
		[self _updateServerVariablesFilterForFilterString:[object stringValue]];
	}
}

#pragma mark -

/**
 * Dealloc
 */
- (void)dealloc
{
	[variables release], variables = nil;
	
	[super dealloc];
}

@end

@implementation SPServerVariablesController (PrivateAPI)

/**
 * Gets the database's current server variables.
 */
- (void)_getDatabaseServerVariables
{
	NSUInteger i = 0;
	
	// Get processes
	MCPResult *serverVariables = [connection queryString:@"SHOW VARIABLES"];
	[serverVariables setReturnDataAsStrings:YES];
	
	if ([serverVariables numOfRows]) [serverVariables dataSeek:0];
	
	[variables removeAllObjects];
	
	for (i = 0; i < [serverVariables numOfRows]; i++) 
	{
		[variables addObject:[serverVariables fetchRowAsDictionary]];
	}
}

/**
 * Filter the displayed server variables by matching the variable name and value against the
 * filter string.
 */
- (void)_updateServerVariablesFilterForFilterString:(NSString *)filterString
{
	[saveVariablesButton setEnabled:NO];
	
	filterString = [[filterString lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	// If the filtered array is allocated and its not a reference to the variables array
	// relase it to prevent memory leaks upon the next allocation.
	if ((variablesFiltered) && (variablesFiltered != variables)) {
		[variablesFiltered release], variablesFiltered = nil;
	}
	
	variablesFiltered = [[NSMutableArray alloc] init];
	
	if ([filterString length] == 0) {
		[variablesFiltered release];
		variablesFiltered = variables;
		
		[saveVariablesButton setEnabled:YES];
		[saveVariablesButton setTitle:@"Save As..."];
		[variablesCountTextField setStringValue:@""];
		
		[variablesTableView reloadData];
		
		return;
	}
	
	for (NSDictionary *variable in variables) 
	{
		if (([[variable objectForKey:@"Variable_name"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound) ||
			([[variable objectForKey:@"Value"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound))
		{
			[variablesFiltered addObject:variable];
		}
	}
	
	[variablesTableView reloadData];
	
	[variablesCountTextField setHidden:NO];
	[variablesCountTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%lu of %lu", "filtered item count"), (unsigned long)[variablesFiltered count], (unsigned long)[variables count]]];
	
	if ([variablesFiltered count] == 0) return;
	
	[saveVariablesButton setEnabled:YES];
	[saveVariablesButton setTitle:@"Save View As..."];
}

/**
 * Copies either the name or value or both (as name = value pairs) of the currently selected server variables.
 */
- (void)_copyServerVariablesToPasteboardIncludingName:(BOOL)name andValue:(BOOL)value
{
	// At least one of either name or value must be true
	if ((!name) && (!value)) return;
	
	NSResponder *firstResponder = [[self window] firstResponder];
	
	if ((firstResponder == variablesTableView) && ([variablesTableView numberOfSelectedRows] > 0)) {
		
		NSString *string = @"";
		NSIndexSet *rows = [variablesTableView selectedRowIndexes];
		
		NSUInteger i = [rows firstIndex];
		
		while (i != NSNotFound) 
		{
			if (i < [variablesFiltered count]) {
				NSDictionary *variable = NSArrayObjectAtIndex(variablesFiltered, i);
				
				NSString *variableName  = [variable objectForKey:@"Variable_name"];
				NSString *variableValue = [variable objectForKey:@"Value"];
				
				// Decide what to include in the string
				if (name && value) {
					string = [string stringByAppendingFormat:@"%@ = %@\n", variableName, variableValue];
				}
				else {
					string = [string stringByAppendingFormat:@"%@\n", (name) ? variableName : variableValue];
				}
			}
			
			i = [rows indexGreaterThanIndex:i];
		}
		
		NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
		
		// Copy the string to the pasteboard
		[pasteBoard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
		[pasteBoard setString:string forType:NSStringPboardType];
	}
}

@end

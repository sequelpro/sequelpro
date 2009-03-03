//
//  CustomQuery.m
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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
//  Or mail to <lorenz@textor.ch>

#import "CustomQuery.h"
#import "SPSQLParser.h"
#import "SPGrowlController.h"

@implementation CustomQuery

//IBAction methods
- (IBAction)performQuery:(id)sender;
/*
performs the mysql-query given by the user
sets the tableView columns corresponding to the mysql-result
*/
{	
	// Fixes bug in key equivalents.
	if ([[NSApp currentEvent] type] == NSKeyUp)
	{
		return;
	}
	
	NSArray		*theColumns;
	NSTableColumn	*theCol;
	CMMCPResult	*theResult = nil;
	NSArray		*queries;
	NSMutableArray	*menuItems = [NSMutableArray array];
	NSMutableArray	*tempResult = [NSMutableArray array];
	NSMutableString	*errors = [NSMutableString string];
	SPSQLParser *queryParser;
	int i;

	// Notify listeners that a query has started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];

	// Retrieve the custom query string and split it into separate SQL queries
	queryParser = [[SPSQLParser alloc] initWithString:[textView string]];
	queries = [queryParser splitStringByCharacter:';'];
	[queryParser release];

	// Perform the queries in series
	for ( i = 0 ; i < [queries count] ; i++ ) {
		theResult = [mySQLConnection queryString:[queries objectAtIndex:i]];
		if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {

			// If the query errored, append error to the error log for display at the end
			if ( [queries count] > 1 ) {
				[errors appendString:[NSString stringWithFormat:NSLocalizedString(@"[ERROR in query %d] %@\n", @"error text when multiple custom query failed"),
										i+1,
										[mySQLConnection getLastErrorMessage]]];
			} else {
				[errors setString:[mySQLConnection getLastErrorMessage]];
			}
		}
	}
	
	//perform empty query if no query is given
	if ( [queries count] == 0 ) {
		theResult = [mySQLConnection queryString:@""];
		[errors setString:[mySQLConnection getLastErrorMessage]];
	}
	
//put result in array
	[queryResult release];
	queryResult = nil;
	if ( nil != theResult )
	{
		int r = [theResult numOfRows];
		if (r) [theResult dataSeek:0];
		for ( i = 0 ; i < r ; i++ ) {
			[tempResult addObject:[theResult fetchRowAsArray]];
		}
		queryResult = [[NSArray arrayWithArray:tempResult] retain];
	}

//add query to history
	[queryHistoryButton insertItemWithTitle:[textView string] atIndex:1];
	while ( [queryHistoryButton numberOfItems] > 21 ) {
		[queryHistoryButton removeItemAtIndex:[queryHistoryButton numberOfItems]-1];
	}
	for ( i = 1 ; i < [queryHistoryButton numberOfItems] ; i++ )
	{
		[menuItems addObject:[queryHistoryButton itemTitleAtIndex:i]];
	}
	[prefs setObject:menuItems forKey:@"queryHistory"];

//select the text of the query textView and set standard font
	[textView selectAll:self];
	if ( [errors length] ) {
		[errorText setStringValue:errors];
	} else {
		[errorText setStringValue:NSLocalizedString(@"There were no errors.", @"text shown when query was successfull")];
	}
	if ( [mySQLConnection affectedRows] != -1 ) {
		[affectedRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%@ row(s) affected", @"text showing how many rows have been affected"),
					[[NSNumber numberWithLongLong:[mySQLConnection affectedRows]] stringValue]]];
	} else {
		[affectedRowsText setStringValue:@""];
	}
	if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
		[textView setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
	} else {
		[textView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}

	if ( !theResult || ![theResult numOfRows] ) {
//no rows in result
	//free tableView
		theColumns = [customQueryView tableColumns];
		while ([theColumns count]) {
			[customQueryView removeTableColumn:[theColumns objectAtIndex:0]];
		}
//		theCol = [[NSTableColumn alloc] initWithIdentifier:@""];
//		[[theCol headerCell] setStringValue:@""];
//		[customQueryView addTableColumn:theCol];
//		[customQueryView sizeLastColumnToFit];
		[customQueryView reloadData];
//		[theCol release];

		//query finished
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];

		// Query finished Growl notification        
        [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Query Finished"
                                                       description:[NSString stringWithFormat:NSLocalizedString(@"%@",@"description for query finished growl notification"), [errorText stringValue]] 
                                                  notificationName:@"Query Finished"];
		
		return;
	}

//set columns
//remove all columns
	theColumns = [customQueryView tableColumns];
//	i=0;
	while ([theColumns count]) {
		[customQueryView removeTableColumn:[theColumns objectAtIndex:0]];
//		i++;
	}

//add columns, corresponding to the query result
	theColumns = [theResult fetchFieldNames];
	for ( i = 0 ; i < [theResult numOfFields] ; i++) {
		theCol = [[NSTableColumn alloc] initWithIdentifier:[NSNumber numberWithInt:i]];
		[theCol setResizingMask:NSTableColumnUserResizingMask];
		NSTextFieldCell *dataCell = [[[NSTextFieldCell alloc] initTextCell:@""] autorelease];
		[dataCell setEditable:NO];
		if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
			[dataCell setFont:[NSFont fontWithName:@"Monaco" size:10]];
		} else {
			[dataCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
		[dataCell setLineBreakMode:NSLineBreakByTruncatingTail];
		[theCol setDataCell:dataCell];
		[[theCol headerCell] setStringValue:[theColumns objectAtIndex:i]];

		[customQueryView addTableColumn:theCol];
		[theCol release];
	}
	
	[customQueryView sizeLastColumnToFit];
	//tries to fix problem with last row (otherwise to small)
	//sets last column to width of the first if smaller than 30
	//problem not fixed for resizing window
	if ( [[customQueryView tableColumnWithIdentifier:[NSNumber numberWithInt:[theColumns count]-1]] width] < 30 )
		[[customQueryView tableColumnWithIdentifier:[NSNumber numberWithInt:[theColumns count]-1]]
				setWidth:[[customQueryView tableColumnWithIdentifier:[NSNumber numberWithInt:0]] width]];
	[customQueryView reloadData];
	
	//query finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
	
	// Query finished Growl notification    
    [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Query Finished"
                                                   description:[NSString stringWithFormat:NSLocalizedString(@"%@",@"description for query finished growl notification"), [errorText stringValue]] 
                                              notificationName:@"Query Finished"];
}

- (IBAction)chooseQueryFavorite:(id)sender
/*
insert the choosen favorite query in the query textView or save query to favorites or opens window to edit favorites
*/
{
	if ( [queryFavoritesButton indexOfSelectedItem] == 1) {
//save query to favorites
		//check if favorite doesn't exist
		NSEnumerator *enumerator = [queryFavorites objectEnumerator];
		id favorite;
		while ( (favorite = [enumerator nextObject]) ) {
			if ( [favorite isEqualToString:[textView string]] ) {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
						NSLocalizedString(@"Query already exists in favorites.", @"message of panel when trying to save query which already exists in favorites"));
				return;
			}
		}
		if ( [[textView string] isEqualToString:@""] ) {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
						NSLocalizedString(@"Query can't be empty.", @"message of panel when trying to save empty query"));
				return;
		}
		[queryFavorites addObject:[NSString stringWithString:[textView string]]];
		[queryFavoritesView reloadData];
		[prefs setObject:queryFavorites forKey:@"queryFavorites"];
		[self setFavorites];
	} else if ( [queryFavoritesButton indexOfSelectedItem] == 2) {
//edit favorites
		[NSApp beginSheet:queryFavoritesSheet
				modalForWindow:tableWindow modalDelegate:self
				didEndSelector:nil contextInfo:nil];
		[NSApp runModalForWindow:queryFavoritesSheet];
	
		[NSApp endSheet:queryFavoritesSheet];
		[queryFavoritesSheet orderOut:nil];
	} else if ( [queryFavoritesButton indexOfSelectedItem] != 3) {
//choose favorite
		[textView replaceCharactersInRange:[textView selectedRange] withString:[queryFavoritesButton titleOfSelectedItem]];
	}
}

- (IBAction)chooseQueryHistory:(id)sender
/*
insert the choosen history query in the query textView
*/
{
	[textView setString:[queryHistoryButton titleOfSelectedItem]];
	[textView selectAll:self];
}

- (IBAction)closeSheet:(id)sender
/*
closes the sheet
*/
{
	[NSApp stopModal];
}


//queryFavoritesSheet methods
- (IBAction)addQueryFavorite:(id)sender
/*
adds a query favorite
*/
{
	int row = [queryFavoritesView editedRow];
	int column = [queryFavoritesView editedColumn];
	NSTableColumn *tableColumn;
	NSCell *cell;

//end editing
	if ( row != -1 ) {
		tableColumn = [[queryFavoritesView tableColumns] objectAtIndex:column]; 
		cell = [tableColumn dataCellForRow:row]; 
		[cell endEditing:[queryFavoritesView currentEditor]]; 
	}

	[queryFavorites addObject:[NSString string]];
	[queryFavoritesView reloadData];
	[queryFavoritesView selectRow:[queryFavoritesView numberOfRows]-1 byExtendingSelection:NO];
	[queryFavoritesView editColumn:0 row:[queryFavoritesView numberOfRows]-1 withEvent:nil select:YES];
}

- (IBAction)removeQueryFavorite:(id)sender
/*
removes a query favorite
*/
{
	int row = [queryFavoritesView editedRow];
	int column = [queryFavoritesView editedColumn];
	NSTableColumn *tableColumn;
	NSCell *cell;

//end editing
	if ( row != -1 ) {
		tableColumn = [[queryFavoritesView tableColumns] objectAtIndex:column]; 
		cell = [tableColumn dataCellForRow:row]; 
		[cell endEditing:[queryFavoritesView currentEditor]]; 
	}

	if ( [queryFavoritesView numberOfSelectedRows] > 0 ) {
		[queryFavorites removeObjectAtIndex:[queryFavoritesView selectedRow]];
		[queryFavoritesView reloadData];
	}
}

- (IBAction)copyQueryFavorite:(id)sender
/*
copies a query favorite
*/
{
	int row = [queryFavoritesView editedRow];
	int column = [queryFavoritesView editedColumn];
	NSTableColumn *tableColumn;
	NSCell *cell;

//end editing
	if ( row != -1 ) {
		tableColumn = [[queryFavoritesView tableColumns] objectAtIndex:column]; 
		cell = [tableColumn dataCellForRow:row]; 
		[cell endEditing:[queryFavoritesView currentEditor]]; 
	}

	if ( [queryFavoritesView numberOfSelectedRows] > 0 ) {
		[queryFavorites insertObject:
					[NSString stringWithString:[queryFavorites objectAtIndex:[queryFavoritesView selectedRow]]]
					atIndex:[queryFavoritesView selectedRow]+1];
		[queryFavoritesView reloadData];
		[queryFavoritesView selectRow:[queryFavoritesView selectedRow]+1 byExtendingSelection:NO];
		[queryFavoritesView editColumn:0 row:[queryFavoritesView selectedRow] withEvent:nil select:YES];
	}
}

- (IBAction)closeQueryFavoritesSheet:(id)sender
/*
closes queryFavoritesSheet and saves favorites to preferences
*/
{
	int row = [queryFavoritesView editedRow];
	int column = [queryFavoritesView editedColumn];
	NSTableColumn *tableColumn;
	NSCell *cell;

//end editing
	if ( row != -1 ) {
		tableColumn = [[queryFavoritesView tableColumns] objectAtIndex:column]; 
		cell = [tableColumn dataCellForRow:row]; 
		[cell endEditing:[queryFavoritesView currentEditor]]; 
	}

	[NSApp stopModal];
	[prefs setObject:queryFavorites forKey:@"queryFavorites"];
	[self setFavorites];
}


//getter methods
- (NSArray *)currentResult
/*
returns the current result (as shown in custom result view) as array, the first object containing the field names as array, the following objects containing the rows as array
*/
{
	NSArray *tableColumns = [customQueryView tableColumns];
	NSEnumerator *enumerator = [tableColumns objectEnumerator];
	id tableColumn;
	NSMutableArray *currentResult = [NSMutableArray array];
	NSMutableArray *tempRow = [NSMutableArray array];
	int i;
	
	//set field names as first line
	while ( (tableColumn = [enumerator nextObject]) ) {
		[tempRow addObject:[[tableColumn headerCell] stringValue]];
	}
	[currentResult addObject:[NSArray arrayWithArray:tempRow]];
	
	//add rows
	for ( i = 0 ; i < [self numberOfRowsInTableView:customQueryView] ; i++) {
		[tempRow removeAllObjects];
		enumerator = [tableColumns objectEnumerator];
		while ( (tableColumn = [enumerator nextObject]) ) {
			[tempRow addObject:[self tableView:customQueryView objectValueForTableColumn:tableColumn row:i]];
		}
		[currentResult addObject:[NSArray arrayWithArray:tempRow]];
	}
	return currentResult;
}


//additional methods
- (void)setConnection:(CMMCPConnection *)theConnection
/*
sets the connection (received from TableDocument) and makes things that have to be done only once 
*/
{
	NSArray *tableColumns = [queryFavoritesView tableColumns];
	NSEnumerator *enumerator = [tableColumns objectEnumerator];
	id column;

	mySQLConnection = theConnection;

	prefs = [[NSUserDefaults standardUserDefaults] retain];
	if ( [prefs objectForKey:@"queryFavorites"] ) {
		queryFavorites = [[NSMutableArray alloc] initWithArray:[prefs objectForKey:@"queryFavorites"]];
	} else {
		queryFavorites = [[NSMutableArray array] retain];
	}

//set up interface
	[customQueryView setVerticalMotionCanBeginDrag:NO];
	if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
		[textView setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
	} else {
		[textView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
	[textView setContinuousSpellCheckingEnabled:NO];
	[queryFavoritesView registerForDraggedTypes:[NSArray arrayWithObjects:@"SequelProPasteboard", nil]];
	while ( (column = [enumerator nextObject]) )
	{
		if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
			[[column dataCell] setFont:[NSFont fontWithName:@"Monaco" size:10]];
		} else {
			[[column dataCell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
	}
	if ( [prefs objectForKey:@"queryHistory"] )
	{
		[queryHistoryButton addItemsWithTitles:[prefs objectForKey:@"queryHistory"]];
	}
	[self setFavorites];
}

- (void)setFavorites
/*
set up the favorites popUpButton
*/
{
	int i;

//remove all menuItems and add favorites from preferences
	for ( i = 4 ; i < [queryFavoritesButton numberOfItems] ; i++ ) {
		[queryFavoritesButton removeItemAtIndex:i];
	}
	[queryFavoritesButton addItemsWithTitles:queryFavorites];
}

- (void)doPerformQueryService:(NSString *)query
/*
inserts the query in the textView and performs query
*/
{
	[textView setString:query];
	[self performQuery:self];
}


//tableView datasource methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if ( aTableView == customQueryView ) {
		if ( nil == queryResult ) {
			return 0;
		} else {
			return [queryResult count];
		}
	} else if ( aTableView == queryFavoritesView ) {
		return [queryFavorites count];
	} else {
		return 0;
	}
}

- (id)tableView:(NSTableView *)aTableView
			objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	NSArray	*theRow;
	NSNumber *theIdentifier = [aTableColumn identifier];

	if ( aTableView == customQueryView ) {
		theRow = [queryResult objectAtIndex:rowIndex];
		
		if ( [[theRow objectAtIndex:[theIdentifier intValue]] isKindOfClass:[NSData class]] ) {
			NSString *tmp = [[NSString alloc] initWithData:[theRow objectAtIndex:[theIdentifier intValue]]
												  encoding:[mySQLConnection encoding]];
			if (tmp == nil) {
				tmp = [[NSString alloc] initWithData:[theRow objectAtIndex:[theIdentifier intValue]]
											encoding:NSASCIIStringEncoding];
			}
			return [tmp autorelease];
		}
		if ( [[theRow objectAtIndex:[theIdentifier intValue]] isMemberOfClass:[NSNull class]] )
			return [prefs objectForKey:@"nullValue"];
	
		return [theRow objectAtIndex:[theIdentifier intValue]];
	} else if ( aTableView == queryFavoritesView ) {
		return [queryFavorites objectAtIndex:rowIndex];
	} else {
		return @"";
	}
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject
			forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if ( aTableView == queryFavoritesView ) {
		NSEnumerator *enumerator = [queryFavorites objectEnumerator];
		id favorite;
		int i = 0;

		if ( [anObject isEqualToString:@""] ) {
			[queryFavoritesView deselectAll:self];
			[queryFavorites removeObjectAtIndex:rowIndex];
			[queryFavoritesView reloadData];
			return;
		}

		while ( (favorite = [enumerator nextObject]) ) {
			if ( [favorite isEqualToString:anObject] && i != rowIndex) {
				NSRunAlertPanel(@"Error", @"Query already exists in favorites.", @"OK", nil, nil);
				//remove row if it was a (blank) new row or a copied row
				if ( [[queryFavorites objectAtIndex:rowIndex] isEqualToString:@""] ||
						[[queryFavorites objectAtIndex:rowIndex] isEqualToString:anObject] ) {
					[queryFavoritesView deselectAll:self];
					[queryFavorites removeObjectAtIndex:rowIndex];
					[queryFavoritesView reloadData];
				}
				return;
			}
			i++;
		}
		[queryFavorites replaceObjectAtIndex:rowIndex withObject:anObject];
		[queryFavoritesView reloadData];
	}
}


//tableView drag&drop datasource methods
- (BOOL)tableView:(NSTableView *)aTableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{
	int originalRow;
	NSArray *pboardTypes;

	if ( aTableView == queryFavoritesView ) 
	{
		if ( [rows count] == 1 ) 
		{
			pboardTypes = [NSArray arrayWithObjects:@"SequelProPasteboard", nil];
			originalRow = [[rows objectAtIndex:0] intValue];
	
			[pboard declareTypes:pboardTypes owner:nil];
			[pboard setString:[[NSNumber numberWithInt:originalRow] stringValue] forType:@"SequelProPasteboard"];
			
			return YES;
		} 
		else 
		{
			return NO;
		}
	} else if ( aTableView == customQueryView ) {
		NSString *tmp = [customQueryView draggedRowsAsTabString:rows];
		if ( nil != tmp )
		{
			[pboard declareTypes:[NSArray arrayWithObjects: NSTabularTextPboardType, 
				NSStringPboardType, nil]
						   owner:nil];
			[pboard setString:tmp forType:NSStringPboardType];
			[pboard setString:tmp forType:NSTabularTextPboardType];
			return YES;
		}
		return NO;
	} else {
		return NO;
	}
}

- (NSDragOperation)tableView:(NSTableView*)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row
	proposedDropOperation:(NSTableViewDropOperation)operation
{
	NSArray *pboardTypes = [[info draggingPasteboard] types];
	int originalRow;

	if ( aTableView == queryFavoritesView ) {
		if ([pboardTypes count] == 1 && row != -1)
		{
			if ([[pboardTypes objectAtIndex:0] isEqualToString:@"SequelProPasteboard"]==YES && operation==NSTableViewDropAbove)
			{
				originalRow = [[[info draggingPasteboard] stringForType:@"SequelProPasteboard"] intValue];
	
				if (row != originalRow && row != (originalRow+1))
				{
					return NSDragOperationMove;
				}
			}
		}
		return NSDragOperationNone;
	} else {
		return NSDragOperationNone;
	}
}

- (BOOL)tableView:(NSTableView*)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	int originalRow;
	int destinationRow;
	NSMutableDictionary *draggedRow;

	if ( aTableView == queryFavoritesView ) {
		originalRow = [[[info draggingPasteboard] stringForType:@"SequelProPasteboard"] intValue];
		destinationRow = row;
	
		if ( destinationRow > originalRow )
			destinationRow--;
	
		draggedRow = [queryFavorites objectAtIndex:originalRow];
		[queryFavorites removeObjectAtIndex:originalRow];
		[queryFavorites insertObject:draggedRow atIndex:destinationRow];
		
		[queryFavoritesView reloadData];
		[queryFavoritesView selectRow:destinationRow byExtendingSelection:NO];
	
		return YES;
	} else {
		return NO;
	}
}


//tableView delegate methods
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
/*
opens sheet with value when double clicking on a field
*/
{
	if ( aTableView == customQueryView ) {
		NSArray *theRow;
		NSString *theValue;
		NSNumber *theIdentifier = [aTableColumn identifier];
	
	//get the value
		theRow = [queryResult objectAtIndex:rowIndex];
	
		if ( [[theRow objectAtIndex:[theIdentifier intValue]] isKindOfClass:[NSData class]] ) {
			theValue = [[NSString alloc] initWithData:[theRow objectAtIndex:[theIdentifier intValue]]
								encoding:[mySQLConnection encoding]];
			if (theValue == nil) {
				theValue = [[NSString alloc] initWithData:[theRow objectAtIndex:[theIdentifier intValue]]
												 encoding:NSASCIIStringEncoding];
			}
			[theValue autorelease];
		} else if ( [[theRow objectAtIndex:[theIdentifier intValue]] isMemberOfClass:[NSNull class]] ) {
			theValue = [prefs objectForKey:@"nullValue"];
		} else {
			theValue = [theRow objectAtIndex:[theIdentifier intValue]];
		}
	
		[valueTextField setString:[theValue description]];
		[valueTextField selectAll:self];
		[NSApp beginSheet:valueSheet
				modalForWindow:tableWindow modalDelegate:self
				didEndSelector:nil contextInfo:nil];
		[NSApp runModalForWindow:valueSheet];
	
		[NSApp endSheet:valueSheet];
		[valueSheet orderOut:nil];
	
		return NO;
	} else {
		return YES;
	}
}


//splitView delegate methods
- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
/*
tells the splitView that it can collapse views
*/
{
	return YES;
}

- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
/*
defines max position of splitView
*/
{
	if ( offset == 0 ) {
		return proposedMax - 100;
	} else {
		return proposedMax - 73;
	}
}

- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
/*
defines min position of splitView
*/
{
	if ( offset == 0 ) {
		return proposedMin + 100;
	} else {
		return proposedMin + 100;
	}
}


//textView delegate methods
- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
/*
traps enter key and
	performs query instead of inserting a line break if aTextView == textView
	closes valueSheet if aTextView == valueTextField
*/
{
	if ( aTextView == textView ) {
		if ( [aTextView methodForSelector:aSelector] == [aTextView methodForSelector:@selector(insertNewline:)] &&
				[[[NSApp currentEvent] characters] isEqualToString:@"\003"] )
		{
			[self performQuery:self];
			return YES;
		} else {
			return NO;
		}
	} else if ( aTextView == valueTextField ) {
		if ( [aTextView methodForSelector:aSelector] == [aTextView methodForSelector:@selector(insertNewline:)] )
		{
			[self closeSheet:self];
			return YES;
		} else {
			return NO;
		}
	}
	return NO;
}

/*
 * Updates various interface elements based on the current table view selection.
 */
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{	
	if ([notification object] == queryFavoritesView) {
		
		// Enable/disable buttons
		[removeQueryFavoriteButton setEnabled:([queryFavoritesView numberOfSelectedRows] == 1)];
		[copyQueryFavoriteButton setEnabled:([queryFavoritesView numberOfSelectedRows] == 1)];
	}
}

// Last but not least
- (id)init;
{
	self = [super init];
	return self;
}

- (void)dealloc
{
	[queryResult release];
	[prefs release];
	[queryFavorites release];
	
	[super dealloc];
}
	
@end

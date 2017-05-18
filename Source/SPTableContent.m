//
//  SPTableContent.m
//  sequel-pro
//
//  Created by Lorenz Textor (lorenz@textor.ch) on May 1, 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  Copyright (c) 2012 Sequel Pro Team. All rights reserved.
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

#import "SPTableContent.h"
#import "SPTableContentFilter.h"
#import "SPDatabaseDocument.h"
#import "SPTableStructure.h"
#import "SPTableInfo.h"
#import "SPTablesList.h"
#import "SPImageView.h"
#import "SPCopyTable.h"
#import "SPDataCellFormatter.h"
#import "SPTableData.h"
#import "SPQueryController.h"
#import "SPQueryDocumentsController.h"
#import "SPTextAndLinkCell.h"
#ifndef SP_CODA
#import "SPSplitView.h"
#endif
#import "SPFieldEditorController.h"
#import "SPTooltip.h"
#import "RegexKitLite.h"
#import "SPContentFilterManager.h"
#import "SPDataStorage.h"
#import "SPAlertSheets.h"
#import "SPHistoryController.h"
#import "SPGeometryDataView.h"
#import "SPTextView.h"
#import "SPDatabaseViewController.h"
#ifndef SP_CODA /* headers */
#import "SPAppController.h"
#import "SPBundleHTMLOutputController.h"
#endif
#import "SPCustomQuery.h"
#import "SPThreadAdditions.h"
#import "SPTableFilterParser.h"
#import "SPFunctions.h"

#import <pthread.h>
#import <SPMySQL/SPMySQL.h>
#include <stdlib.h>

#ifndef SP_CODA
static NSString *SPTableFilterSetDefaultOperator = @"SPTableFilterSetDefaultOperator";
#endif

@interface SPTableContent (SPTableContentDataSource_Private_API)

- (id)_contentValueForTableColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex asPreview:(BOOL)asPreview;

@end

@interface SPTableContent ()

- (BOOL)cancelRowEditing;
- (void)documentWillClose:(NSNotification *)notification;

@end

@implementation SPTableContent

#ifdef SP_CODA
@synthesize addButton;
@synthesize argumentField;
@synthesize betweenTextField;
@synthesize compareField;
@synthesize duplicateButton;
@synthesize fieldField;
@synthesize filterButton;
@synthesize firstBetweenField;
@synthesize paginationNextButton;
@synthesize paginationPageField;
@synthesize paginationPreviousButton;
@synthesize reloadButton;
@synthesize removeButton;
@synthesize secondBetweenField;
@synthesize tableContentView;
@synthesize tableDataInstance;
@synthesize tableDocumentInstance;
@synthesize tableSourceInstance;
@synthesize tablesListInstance;
#endif

#pragma mark -

- (id)init
{
	if ((self = [super init])) {
		_mainNibLoaded = NO;
		isWorking = NO;
		
		pthread_mutex_init(&tableValuesLock, NULL);
#ifndef SP_CODA
		nibObjectsToRelease = [[NSMutableArray alloc] init];
#endif

		tableValues       = [[SPDataStorage alloc] init];
		dataColumns       = [[NSMutableArray alloc] init];
		oldRow            = [[NSMutableArray alloc] init];
#ifndef SP_CODA
		filterTableData   = [[NSMutableDictionary alloc] initWithCapacity:1];
#endif

		tableRowsCount         = 0;
		previousTableRowsCount = 0;

#ifndef SP_CODA
		filterTableNegate          = NO;
		filterTableDistinct        = NO;
		filterTableIsSwapped       = NO;
		lastEditedFilterTableValue = nil;
		activeFilter               = 0;
		schemeFilter               = nil;
		paginationPopover          = nil;
#endif

		selectedTable = nil;
		sortCol       = nil;
		isDesc        = NO;
		keys          = nil;

		currentlyEditingRow = -1;
		contentPage = 1;

		sortColumnToRestore = nil;
		sortColumnToRestoreIsAsc = YES;
		pageToRestore = 1;
		selectionToRestore = nil;
		selectionViewportToRestore = NSZeroRect;
		filterFieldToRestore = nil;
		filterComparisonToRestore = nil;
		filterValueToRestore = nil;
		firstBetweenValueToRestore = nil;
		secondBetweenValueToRestore = nil;
		tableRowsSelectable = YES;
		contentFilterManager = nil;
		isFirstChangeInView = YES;

		isFiltered = NO;
		isLimited = NO;
		isInterruptedLoad = NO;

		prefs = [NSUserDefaults standardUserDefaults];

		usedQuery = [[NSString alloc] initWithString:@""];

		tableLoadTimer = nil;

		blackColor = [NSColor blackColor];
		lightGrayColor = [NSColor lightGrayColor];
		blueColor = [NSColor blueColor];
		whiteColor = [NSColor whiteColor];

		// Init default filters for Content Browser
		contentFilters = nil;
		contentFilters = [[NSMutableDictionary alloc] init];
		numberOfDefaultFilters = [[NSMutableDictionary alloc] init];

		NSError *readError = nil;
		NSString *convError = nil;
		NSPropertyListFormat format;
		NSData *defaultFilterData = [NSData dataWithContentsOfFile:[NSBundle pathForResource:@"ContentFilters.plist" ofType:nil inDirectory:[[NSBundle mainBundle] bundlePath]]
			options:NSMappedRead error:&readError];

		[contentFilters setDictionary:[NSPropertyListSerialization propertyListFromData:defaultFilterData
				mutabilityOption:NSPropertyListMutableContainersAndLeaves format:&format errorDescription:&convError]];
		
		if (contentFilters == nil || readError != nil || convError != nil) {
			NSLog(@"Error while reading 'ContentFilters.plist':\n%@\n%@", [readError localizedDescription], convError);
			NSBeep();
		} 
		else {
			[numberOfDefaultFilters setObject:[NSNumber numberWithInteger:[[contentFilters objectForKey:@"number"] count]] forKey:@"number"];
			[numberOfDefaultFilters setObject:[NSNumber numberWithInteger:[[contentFilters objectForKey:@"date"] count]] forKey:@"date"];
			[numberOfDefaultFilters setObject:[NSNumber numberWithInteger:[[contentFilters objectForKey:@"string"] count]] forKey:@"string"];
			[numberOfDefaultFilters setObject:[NSNumber numberWithInteger:[[contentFilters objectForKey:@"spatial"] count]] forKey:@"spatial"];
		}

		kCellEditorErrorNoMatch = NSLocalizedString(@"Field is not editable. No matching record found.\nReload table, check the encoding, or try to add\na primary key field or more fields\nin the view declaration of '%@' to identify\nfield origin unambiguously.", @"Table Content result editing error - could not identify original row");
		kCellEditorErrorNoMultiTabDb = NSLocalizedString(@"Field is not editable. Field has no or multiple table or database origin(s).",@"field is not editable due to no table/database");
		kCellEditorErrorTooManyMatches = NSLocalizedString(@"Field is not editable. Couldn't identify field origin unambiguously (%ld matches).", @"Query result editing error - could not match row being edited uniquely");
	}

	return self;
}

- (void)awakeFromNib
{
	if (_mainNibLoaded) return;
	_mainNibLoaded = YES;

#ifndef SP_CODA /* ui manipulation */
	// Temporary to avoid nib conflicts during WIP
	[contentSplitView setCollapsibleSubviewIndex:0];
	[contentSplitView setCollapsibleSubviewCollapsed:YES animate:NO];
	[contentSplitView setMaxSize:0.f ofSubviewAtIndex:0];

	// Set the table content view's vertical gridlines if required
	[tableContentView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	[filterTableView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];

	// Set the double-click action in blank areas of the table to create new rows
	[tableContentView setEmptyDoubleClickAction:@selector(addRow:)];

	// Load the pagination view, keeping references to the top-level objects for later release
	NSArray *paginationViewTopLevelObjects = nil;
	NSNib *nibLoader = [[NSNib alloc] initWithNibNamed:@"ContentPaginationView" bundle:[NSBundle mainBundle]];
	
	if (![nibLoader instantiateNibWithOwner:self topLevelObjects:&paginationViewTopLevelObjects]) {
		NSLog(@"Content pagination nib could not be loaded; pagination will not function correctly.");
	} 
	else {
		[nibObjectsToRelease addObjectsFromArray:paginationViewTopLevelObjects];
	}
	
	[nibLoader release];
	
	//let's see if we can use the NSPopover (10.7+) or have to make do with our legacy clone.
	//this is using reflection right now, as our SDK is 10.8 but our minimum supported version is 10.6
	Class popOverClass = NSClassFromString(@"NSPopover");
	if(popOverClass) {
		paginationPopover = [[popOverClass alloc] init];
		[paginationPopover setDelegate:(SPTableContent<NSPopoverDelegate> *)self];
		[paginationPopover setContentViewController:paginationViewController];
		[paginationPopover setBehavior:NSPopoverBehaviorTransient];
	}
	else {
		[paginationBox setContentView:[paginationViewController view]];
		
		// Add the pagination view to the content area
		NSRect paginationViewFrame = [paginationView frame];
		NSRect paginationButtonFrame = [paginationButton frame];
		paginationViewHeight = paginationViewFrame.size.height;
		paginationViewFrame.origin.x = paginationButtonFrame.origin.x + paginationButtonFrame.size.width - paginationViewFrame.size.width;
		paginationViewFrame.origin.y = paginationButtonFrame.origin.y + paginationButtonFrame.size.height - 2;
		paginationViewFrame.size.height = 0;
		[paginationView setFrame:paginationViewFrame];
		[contentViewPane addSubview:paginationView];
	}

	// Modify the filter table split view sizes
	[filterTableSplitView setMinSize:135 ofSubviewAtIndex:1];
#endif

	[tableContentView setFieldEditorSelectedRange:NSMakeRange(0,0)];

#ifndef SP_CODA
	// Init Filter Table GUI
	[filterTableDistinctCheckbox setState:(filterTableDistinct) ? NSOnState : NSOffState];
	[filterTableNegateCheckbox setState:(filterTableNegate) ? NSOnState : NSOffState];
	[filterTableLiveSearchCheckbox setState:NSOffState];
#endif
#ifndef SP_CODA /* patch */
	filterTableDefaultOperator = [[self escapeFilterTableDefaultOperator:[prefs objectForKey:SPFilterTableDefaultOperator]] retain];
#else
//	filterTableDefaultOperator = [[self escapeFilterTableDefaultOperator:nil] retain];
#endif

	// Add observers for document task activity
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDocumentTaskForTab:)
												 name:SPDocumentTaskStartNotification
											   object:tableDocumentInstance];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(endDocumentTaskForTab:)
												 name:SPDocumentTaskEndNotification
											   object:tableDocumentInstance];
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(documentWillClose:)
	                                             name:SPDocumentWillCloseNotification
	                                           object:tableDocumentInstance];
}

#pragma mark -
#pragma mark Table loading methods and information

/**
 * Loads aTable, retrieving column information and updating the tableViewColumns before
 * reloading table data into the data array and redrawing the table.
 *
 * @param aTable The to be loaded table name
 */
- (void)loadTable:(NSString *)aTable
{
	// Abort the reload if the user is still editing a row
	if (isEditingRow) return;

	// If no table has been supplied, clear the table interface and return
	if (!aTable || [aTable isEqualToString:@""]) {
		[[self onMainThread] setTableDetails:nil];
		return;
	}

	// Attempt to retrieve the table encoding; if that fails (indicating an error occurred
	// while retrieving table data), or if the Rows variable is null, clear and return
	if (![tableDataInstance tableEncoding] || [[tableDataInstance statusValueForKey:@"Rows"] isNSNull]) {
		[[self onMainThread] setTableDetails:nil];
		return;
	}

	// Post a notification that a query will be performed
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryWillBePerformed" object:tableDocumentInstance];

	// Set up the table details for the new table, and trigger an interface update
	NSDictionary *tableDetails = [NSDictionary dictionaryWithObjectsAndKeys:
									aTable, @"name",
									[tableDataInstance columns], @"columns",
									[tableDataInstance columnNames], @"columnNames",
									[tableDataInstance getConstraints], @"constraints",
									nil];
	[[self onMainThread] setTableDetails:tableDetails];

	// Init copyTable with necessary information for copying selected rows as SQL INSERT
	[tableContentView setTableInstance:self withTableData:tableValues withColumns:dataColumns withTableName:selectedTable withConnection:mySQLConnection];

	// Trigger a data refresh
	[self loadTableValues];

	// Restore the view origin if appropriate
	if (!NSEqualRects(selectionViewportToRestore, NSZeroRect)) {

		// Scroll the viewport to the saved location
		selectionViewportToRestore.size = [tableContentView visibleRect].size;
		[(SPCopyTable*)[tableContentView onMainThread] scrollRectToVisible:selectionViewportToRestore];
	}

	// Update display if necessary
	if (!NSEqualRects(selectionViewportToRestore, NSZeroRect))
		[[tableContentView onMainThread] setNeedsDisplayInRect:selectionViewportToRestore];
	else
		[[tableContentView onMainThread] setNeedsDisplay:YES];

	// Post the notification that the query is finished
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];

	// Clear any details to restore now that they have been restored
	[self clearDetailsToRestore];
}

/**
 * Update stored table details and update the interface to match the supplied
 * table details.
 * Should be called on the main thread.
 */
- (void) setTableDetails:(NSDictionary *)tableDetails
{
	NSString *newTableName;
	NSInteger sortColumnNumberToRestore = NSNotFound;
#ifndef SP_CODA
	NSNumber *colWidth;
#endif
	NSArray *columnNames;
	NSMutableDictionary *preservedColumnWidths = nil;
	NSTableColumn	*theCol;
#ifndef SP_CODA
	NSTableColumn *filterCol;
#endif
	BOOL enableInteraction =
#ifndef SP_CODA /* checking toolbar state */
	 ![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableContent] || 
#endif
	 ![tableDocumentInstance isWorking];

	if (!tableDetails) {
		
		// If no table is currently selected, no action required - return.
		if (!selectedTable) return;

		newTableName = nil;
	} else {
		newTableName = [tableDetails objectForKey:@"name"];
	}

#ifndef SP_CODA
	// Ensure the pagination view hides itself if visible, after a tiny delay for smoothness
	[self performSelector:@selector(setPaginationViewVisibility:) withObject:nil afterDelay:0.1];
#endif

	// Reset table key store for use in argumentForRow:
	if (keys) SPClear(keys);

	// Check the supplied table name.  If it matches the old one, a reload is being performed;
	// reload the data in-place to maintain table state if possible.
	if ([selectedTable isEqualToString:newTableName]) {
		previousTableRowsCount = tableRowsCount;

		// Store the column widths for later restoration
		preservedColumnWidths = [NSMutableDictionary dictionaryWithCapacity:[[tableContentView tableColumns] count]];
		for (NSTableColumn *eachColumn in [tableContentView tableColumns]) {
			[preservedColumnWidths setObject:[NSNumber numberWithFloat:[eachColumn width]] forKey:[[eachColumn headerCell] stringValue]];
		}

	// Otherwise store the newly selected table name and reset the data
	} else {
		if (selectedTable) SPClear(selectedTable);
		if (newTableName) selectedTable = [[NSString alloc] initWithString:newTableName];
		previousTableRowsCount = 0;
		contentPage = 1;
		[paginationPageField setStringValue:@"1"];

		// Clear the selection
		[tableContentView deselectAll:self];

		// Restore the table content view to the top left
		// Note: This may cause the table view to reload it's data!
		[tableContentView scrollRowToVisible:0];
		[tableContentView scrollColumnToVisible:0];

		// Set the maximum table rows to an estimated count pre-load
		NSString *rows = [tableDataInstance statusValueForKey:@"Rows"];
		maxNumRows = (rows && ![rows isNSNull])? [rows integerValue] : 0;
		maxNumRowsIsEstimate = YES;
	}
	
	// Reset data column store
	[dataColumns removeAllObjects];

	// If no table has been supplied, reset the view to a blank table and disabled elements.
	if (!newTableName) {
		// Remove existing columns from the table
		while ([[tableContentView tableColumns] count]) {
			[NSArrayObjectAtIndex([tableContentView tableColumns], 0) setHeaderToolTip:nil]; // prevent crash #2414
			[tableContentView removeTableColumn:NSArrayObjectAtIndex([tableContentView tableColumns], 0)];
		}

		// Empty the stored data arrays, including emptying the tableValues array
		// by ressignment for thread safety.
		previousTableRowsCount = 0;
		[self clearTableValues];
		[tableContentView reloadData];
		isFiltered = NO;
		isLimited = NO;
#ifndef SP_CODA
		[countText setStringValue:@""];
#endif

		// Reset sort column
		if (sortCol) SPClear(sortCol);
		isDesc = NO;

		// Empty and disable filter options
		[fieldField setEnabled:NO];
		[fieldField removeAllItems];
		[fieldField addItemWithTitle:NSLocalizedString(@"field", @"popup menuitem for field (showing only if disabled)")];
		[compareField setEnabled:NO];
		[compareField removeAllItems];
		[compareField addItemWithTitle:@"="];
		[argumentField setHidden:NO];
		[argumentField setEnabled:NO];
		[firstBetweenField setEnabled:NO];
		[secondBetweenField setEnabled:NO];
		[firstBetweenField setStringValue:@""];
		[secondBetweenField setStringValue:@""];
		[argumentField setStringValue:@""];
		[filterButton setEnabled:NO];

		// Hide BETWEEN operator controls
		[firstBetweenField setHidden:YES];
		[secondBetweenField setHidden:YES];
		[betweenTextField setHidden:YES];

		// Disable pagination
		[paginationPreviousButton setEnabled:NO];
#ifndef SP_CODA
		[paginationButton setEnabled:NO];
		[paginationButton setTitle:@""];
#endif
		[paginationNextButton setEnabled:NO];

		// Disable table action buttons
		[addButton setEnabled:NO];
		[duplicateButton setEnabled:NO];
		[removeButton setEnabled:NO];

		// Clear restoration settings
		[self clearDetailsToRestore];

#ifndef SP_CODA
		// Clear filter table
		while ([[filterTableView tableColumns] count]) {
			[NSArrayObjectAtIndex([filterTableView tableColumns], 0) setHeaderToolTip:nil]; // prevent crash #2414
			[filterTableView removeTableColumn:NSArrayObjectAtIndex([filterTableView tableColumns], 0)];
		}
		// Clear filter table data
		[filterTableData removeAllObjects];
		[filterTableWhereClause setString:@""];
		activeFilter = 0;
#endif
		return;
	}

	// Otherwise, prepare to set up the new table - the table data instance already has table details set.

	// Remove existing columns from the table
	while ([[tableContentView tableColumns] count]) {
		[NSArrayObjectAtIndex([tableContentView tableColumns], 0) setHeaderToolTip:nil]; // prevent crash #2414
		[tableContentView removeTableColumn:NSArrayObjectAtIndex([tableContentView tableColumns], 0)];
	}
#ifndef SP_CODA
	// Remove existing columns from the filter table
	[filterTableView abortEditing];
	while ([[filterTableView tableColumns] count]) {
		[NSArrayObjectAtIndex([filterTableView tableColumns], 0) setHeaderToolTip:nil]; // prevent crash #2414
		[filterTableView removeTableColumn:NSArrayObjectAtIndex([filterTableView tableColumns], 0)];
	}
	// Clear filter table data
	[filterTableData removeAllObjects];
	[filterTableWhereClause setString:@""];
	activeFilter = 0;
#endif

	// Retrieve the field names and types for this table from the data cache. This is used when requesting all data as part
	// of the fieldListForQuery method, and also to decide whether or not to preserve the current filter/sort settings.
	[dataColumns addObjectsFromArray:[tableDetails objectForKey:@"columns"]];
	columnNames = [tableDetails objectForKey:@"columnNames"];

	// Retrieve the constraints, and loop through them to add up to one foreign key to each column
	NSArray *constraints = [tableDetails objectForKey:@"constraints"];

	for (NSDictionary *constraint in constraints)
	{
		NSString *firstColumn    = [[constraint objectForKey:@"columns"] objectAtIndex:0];
		NSString *firstRefColumn = [[constraint objectForKey:@"ref_columns"] objectAtIndex:0];
		NSUInteger columnIndex   = [columnNames indexOfObject:firstColumn];

		if (columnIndex != NSNotFound && ![[dataColumns objectAtIndex:columnIndex] objectForKey:@"foreignkeyreference"]) {
			NSDictionary *refDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											[constraint objectForKey:@"ref_table"], @"table",
											firstRefColumn, @"column",
											nil];
			NSMutableDictionary *rowDictionary = [NSMutableDictionary dictionaryWithDictionary:[dataColumns objectAtIndex:columnIndex]];
			[rowDictionary setObject:refDictionary forKey:@"foreignkeyreference"];
			[dataColumns replaceObjectAtIndex:columnIndex withObject:rowDictionary];
		}
	}

	NSString *nullValue = [prefs objectForKey:SPNullValue];
#ifndef SP_CODA /* get font from prefs */
	NSFont *tableFont = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPGlobalResultTableFont]];
#else
	NSFont *tableFont = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
#endif
	[tableContentView setRowHeight:2.0f+NSSizeToCGSize([@"{ǞṶḹÜ∑zgyf" sizeWithAttributes:@{NSFontAttributeName : tableFont}]).height];

	// Add the new columns to the table and filterTable
	for (NSDictionary *columnDefinition in dataColumns ) {

		// Set up the column
		theCol = [[NSTableColumn alloc] initWithIdentifier:[columnDefinition objectForKey:@"datacolumnindex"]];
		[[theCol headerCell] setStringValue:[columnDefinition objectForKey:@"name"]];
		[theCol setHeaderToolTip:[NSString stringWithFormat:@"%@ – %@%@%@%@", 
			[columnDefinition objectForKey:@"name"], 
			[columnDefinition objectForKey:@"type"], 
			([columnDefinition objectForKey:@"length"]) ? [NSString stringWithFormat:@"(%@)", [columnDefinition objectForKey:@"length"]] : @"", 
			([columnDefinition objectForKey:@"values"]) ? [NSString stringWithFormat:@"(\n- %@\n)", [[columnDefinition objectForKey:@"values"] componentsJoinedByString:@"\n- "]] : @"", 
			([columnDefinition objectForKey:@"comment"] && [(NSString *)[columnDefinition objectForKey:@"comment"] length]) ? [NSString stringWithFormat:@"\n%@", [[columnDefinition objectForKey:@"comment"] stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"]] : @""
			]];
		
		// Copy in the width if present in a reloaded table
		if ([preservedColumnWidths objectForKey:[columnDefinition objectForKey:@"name"]]) {
			[theCol setWidth:[[preservedColumnWidths objectForKey:[columnDefinition objectForKey:@"name"]] floatValue]];
		}
		
		[theCol setEditable:YES];

#ifndef SP_CODA
		// Set up column for filterTable 
		filterCol = [[NSTableColumn alloc] initWithIdentifier:[columnDefinition objectForKey:@"datacolumnindex"]];
		[[filterCol headerCell] setStringValue:[columnDefinition objectForKey:@"name"]];
		[filterCol setEditable:YES];
		SPTextAndLinkCell *filterDataCell = [[[SPTextAndLinkCell alloc] initTextCell:@""] autorelease];
		[filterDataCell setEditable:YES];
		[filterCol setDataCell:filterDataCell];
		[filterTableView addTableColumn:filterCol];
		[filterCol release];

		[filterTableData setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[columnDefinition objectForKey:@"name"], @"name",
				[columnDefinition objectForKey:@"typegrouping"], @"typegrouping",
				[NSMutableArray arrayWithObjects:@"", @"", @"", @"", @"", @"", @"", @"", @"", @"", nil], SPTableContentFilterKey,
				nil] forKey:[columnDefinition objectForKey:@"datacolumnindex"]];
#endif

		// Set up the data cell depending on the column type
		id dataCell;
		if ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"enum"]) {
			dataCell = [[[NSComboBoxCell alloc] initTextCell:@""] autorelease];
			[dataCell setButtonBordered:NO];
			[dataCell setBezeled:NO];
			[dataCell setDrawsBackground:NO];
			[dataCell setCompletes:YES];
			[dataCell setControlSize:NSSmallControlSize];
			// add prefs NULL value representation if NULL value is allowed for that field
			if([[columnDefinition objectForKey:@"null"] boolValue])
				[dataCell addItemWithObjectValue:nullValue];
			[dataCell addItemsWithObjectValues:[columnDefinition objectForKey:@"values"]];

		// Add a foreign key arrow if applicable
		} else if ([columnDefinition objectForKey:@"foreignkeyreference"]) {
			dataCell = [[[SPTextAndLinkCell alloc] initTextCell:@""] autorelease];
			[dataCell setTarget:self action:@selector(clickLinkArrow:)];

		// Otherwise instantiate a text-only cell
		} else {
			dataCell = [[[SPTextAndLinkCell alloc] initTextCell:@""] autorelease];
		}

		// Set the column to right-aligned for numeric data types
		if ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"integer"]
			|| [[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"float"])
		{
			[dataCell setAlignment:NSRightTextAlignment];
		}

		[dataCell setEditable:YES];

		// Set the line break mode and an NSFormatter subclass which displays line breaks nicely
		[dataCell setLineBreakMode:NSLineBreakByTruncatingTail];
		[dataCell setFormatter:[[SPDataCellFormatter new] autorelease]];

		// Set field length limit if field is a varchar to match varchar length
		if ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"string"]
			|| [[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"bit"]) {
			[[dataCell formatter] setTextLimit:[[columnDefinition objectForKey:@"length"] integerValue]];
		}

		// Set field type for validations
		[[dataCell formatter] setFieldType:[columnDefinition objectForKey:@"type"]];

		// Set the data cell font according to the preferences
		[dataCell setFont:tableFont];

		// Assign the data cell
		[theCol setDataCell:dataCell];

#ifndef SP_CODA /* prefs access */
		// Set the width of this column to saved value if exists
		colWidth = [[[[prefs objectForKey:SPTableColumnWidths] objectForKey:[NSString stringWithFormat:@"%@@%@", [tableDocumentInstance database], [tableDocumentInstance host]]] objectForKey:[tablesListInstance tableName]] objectForKey:[columnDefinition objectForKey:@"name"]];
		if ( colWidth ) {
			[theCol setWidth:[colWidth floatValue]];
		}
#endif

		// Set the column to be reselected for sorting if appropriate
		if (sortColumnToRestore && [sortColumnToRestore isEqualToString:[columnDefinition objectForKey:@"name"]])
			sortColumnNumberToRestore = [[columnDefinition objectForKey:@"datacolumnindex"] integerValue];

		// Add the column to the table
		[tableContentView addTableColumn:theCol];
		[theCol release];
	}

#ifndef SP_CODA
	[filterTableView setDelegate:self];
	[filterTableView setDataSource:self];
	[filterTableView reloadData];
#endif

	// If the table has been reloaded and the previously selected sort column is still present, reselect it.
	if (sortColumnNumberToRestore != NSNotFound) {
		theCol = [tableContentView tableColumnWithIdentifier:[NSString stringWithFormat:@"%lld", (long long)sortColumnNumberToRestore]];
		if (sortCol) [sortCol release];
		sortCol = [[NSNumber alloc] initWithInteger:sortColumnNumberToRestore];
		[tableContentView setHighlightedTableColumn:theCol];
		isDesc = !sortColumnToRestoreIsAsc;
		if ( isDesc ) {
			[tableContentView setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:theCol];
		} else {
			[tableContentView setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:theCol];
		}

	// Otherwise, clear sorting
	} else {
		if (sortCol) {
			SPClear(sortCol);
		}
		isDesc = NO;
	}

	// Store the current first responder so filter field doesn't steal focus
	id currentFirstResponder = [[tableDocumentInstance parentWindow] firstResponder];
	// For text inputs the window's fieldEditor will be the actual firstResponder, but that is useless for setting.
	// We need the visible view object, which is the delegate of the field editor.
	if([currentFirstResponder respondsToSelector:@selector(isFieldEditor)] && [currentFirstResponder isFieldEditor]) {
		currentFirstResponder = [currentFirstResponder delegate];
	}

	// Enable and initialize filter fields (with tags for position of menu item and field position)
	[fieldField setEnabled:YES];
	[fieldField removeAllItems];
	NSArray *columnTitles = ([prefs boolForKey:SPAlphabeticalTableSorting])? [columnNames sortedArrayUsingSelector:@selector(compare:)] : columnNames;
	[fieldField addItemsWithTitles:columnTitles];
	[compareField setEnabled:YES];
	[self setCompareTypes:self];
	[argumentField setEnabled:YES];
	[argumentField setStringValue:@""];
	[filterButton setEnabled:enableInteraction];

	// Restore preserved filter settings if appropriate and valid
	if (filterFieldToRestore) {
		[fieldField selectItemWithTitle:filterFieldToRestore];
		[self setCompareTypes:self];

		if ([fieldField itemWithTitle:filterFieldToRestore]
			&& ((!filterComparisonToRestore && filterValueToRestore)
				|| (filterComparisonToRestore && [compareField itemWithTitle:filterComparisonToRestore])))
		{
			if (filterComparisonToRestore) [compareField selectItemWithTitle:filterComparisonToRestore];
			if([filterComparisonToRestore isEqualToString:@"BETWEEN"]) {
				[argumentField setHidden:YES];
				if (firstBetweenValueToRestore) [firstBetweenField setStringValue:firstBetweenValueToRestore];
				if (secondBetweenValueToRestore) [secondBetweenField setStringValue:secondBetweenValueToRestore];
			} else {
				if (filterValueToRestore) [argumentField setStringValue:filterValueToRestore];
			}
			[self toggleFilterField:self];

		}
	}

	// Restore page number if limiting is set
	if ([prefs boolForKey:SPLimitResults])
		contentPage = pageToRestore;

	// Restore first responder
	[[tableDocumentInstance parentWindow] makeFirstResponder:currentFirstResponder];

	// Set the state of the table buttons
	[addButton setEnabled:(enableInteraction && [tablesListInstance tableType] == SPTableTypeTable)];
	[duplicateButton setEnabled:NO];
	[removeButton setEnabled:NO];

	// Reset the table store if required - basically if the table is being changed,
	// reassigning before emptying for thread safety.
	if (!previousTableRowsCount) {
		[self clearTableValues];
	}
#ifndef SP_CODA
	[filterTableView reloadData];
#endif

}

/**
 * Remove all items from the current table value store.  Do this by
 * reassigning the tableValues store and releasing the old location,
 * while setting thread safety flags.
 */
- (void) clearTableValues
{
	SPDataStorage *tableValuesTransition;

	tableValuesTransition = tableValues;
	pthread_mutex_lock(&tableValuesLock);
	tableRowsCount = 0;
	tableValues = [[SPDataStorage alloc] init];
	[tableContentView setTableData:tableValues];
	pthread_mutex_unlock(&tableValuesLock);
	[tableValuesTransition release];
}

/**
 * Reload the table data without reconfiguring the tableView,
 * using filters and limits as appropriate.
 * Will not refresh the table view itself.
 * Note that this does not empty the table array - see use of previousTableRowsCount.
 */
- (void) loadTableValues
{
	// If no table is selected, return
	if (!selectedTable) return;

	NSMutableString *queryString;
	NSString *queryStringBeforeLimit = nil;
	NSString *filterString;
	SPMySQLStreamingResultStore *resultStore;
	NSInteger rowsToLoad = [[tableDataInstance statusValueForKey:@"Rows"] integerValue];

#ifndef SP_CODA
	[[countText onMainThread] setStringValue:NSLocalizedString(@"Loading table data...", @"Loading table data string")];
#endif

	// Notify any listeners that a query has started
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryWillBePerformed" object:tableDocumentInstance];

	// Start construction of the query string
	queryString = [NSMutableString stringWithFormat:@"SELECT %@%@ FROM %@", 
#ifndef SP_CODA
			(activeFilter == 1 && [self tableFilterString] && filterTableDistinct) ? @"DISTINCT " : 
#endif
			@"", 
			[self fieldListForQuery], [selectedTable backtickQuotedString]];

	// Add a filter string if appropriate
	filterString = [[self onMainThread] tableFilterString];

	if (filterString) {
		[queryString appendFormat:@" WHERE %@", filterString];
		isFiltered = YES;
	} else {
		isFiltered = NO;
	}

	// Add sorting details if appropriate
	if (sortCol) {
		[queryString appendFormat:@" ORDER BY %@", [[[dataColumns objectAtIndex:[sortCol integerValue]] objectForKey:@"name"] backtickQuotedString]];
		if (isDesc) [queryString appendString:@" DESC"];
	}

	// Check to see if a limit needs to be applied
	if ([prefs boolForKey:SPLimitResults]) 
	{
		// Ensure the page supplied is within the appropriate limits
		if (contentPage <= 0)
			contentPage = 1;
		else if (contentPage > 1 && (NSInteger)(contentPage - 1) * [prefs integerForKey:SPLimitResultsValue] >= maxNumRows)
			contentPage = ceilf((CGFloat)maxNumRows / [prefs floatForKey:SPLimitResultsValue]);

		// If the result set is from a late page, take a copy of the string to allow resetting limit
		// if no results are found
		if (contentPage > 1) {
			queryStringBeforeLimit = [NSString stringWithString:queryString];
		}

		// Append the limit settings
		[queryString appendFormat:@" LIMIT %ld,%ld", (long)((contentPage-1)*[prefs integerForKey:SPLimitResultsValue]), (long)[prefs integerForKey:SPLimitResultsValue]];

		// Update the approximate count of the rows to load
		rowsToLoad = rowsToLoad - (contentPage-1)*[prefs integerForKey:SPLimitResultsValue];
		if (rowsToLoad > [prefs integerForKey:SPLimitResultsValue]) rowsToLoad = [prefs integerForKey:SPLimitResultsValue];
	}

	// If within a task, allow this query to be cancelled
	[tableDocumentInstance enableTaskCancellationWithTitle:NSLocalizedString(@"Stop", @"stop button") callbackObject:nil callbackFunction:NULL];

	// Perform and process the query
	[tableContentView performSelectorOnMainThread:@selector(noteNumberOfRowsChanged) withObject:nil waitUntilDone:YES];
	[self setUsedQuery:queryString];
	resultStore = [[mySQLConnection resultStoreFromQueryString:queryString] retain];

	// Ensure the number of columns are unchanged; if the column count has changed, abort the load
	// and queue a full table reload.
	BOOL fullTableReloadRequired = NO;
	if (resultStore && [dataColumns count] != [resultStore numberOfFields]) {
		[tableDocumentInstance disableTaskCancellation];
		[mySQLConnection cancelCurrentQuery];
		[resultStore cancelResultLoad];
		fullTableReloadRequired = YES;
	}

	// Process the result into the data store
	if (!fullTableReloadRequired && resultStore) {
		[self updateResultStore:resultStore approximateRowCount:rowsToLoad];
	}
	if (resultStore) [resultStore release];

	// If the result is empty, and a late page is selected, reset the page
	if (!fullTableReloadRequired && [prefs boolForKey:SPLimitResults] && queryStringBeforeLimit && !tableRowsCount && ![mySQLConnection lastQueryWasCancelled]) {
		contentPage = 1;
		previousTableRowsCount = tableRowsCount;
		queryString = [NSMutableString stringWithFormat:@"%@ LIMIT 0,%ld", queryStringBeforeLimit, (long)[prefs integerForKey:SPLimitResultsValue]];
		[self setUsedQuery:queryString];
		resultStore = [[mySQLConnection resultStoreFromQueryString:queryString] retain];
		if (resultStore) {
			[self updateResultStore:resultStore approximateRowCount:[prefs integerForKey:SPLimitResultsValue]];
			[resultStore release];
		}
	}

	if ([mySQLConnection lastQueryWasCancelled] || [mySQLConnection queryErrored])
		isInterruptedLoad = YES;
	else
		isInterruptedLoad = NO;

	// End cancellation ability
	[tableDocumentInstance disableTaskCancellation];

	// Restore selection indexes if appropriate
	if (selectionToRestore) {
		BOOL previousTableRowsSelectable = tableRowsSelectable;
		tableRowsSelectable = YES;
		NSMutableIndexSet *selectionSet = [NSMutableIndexSet indexSet];

		// Currently two types of stored selection are supported: primary keys and direct index sets.
		if ([[selectionToRestore objectForKey:@"type"] isEqualToString:SPSelectionDetailTypePrimaryKeyed]) {

			// Check whether the keys are still present and get their positions
			BOOL columnsFound = YES;
			NSArray *primaryKeyFieldNames = [selectionToRestore objectForKey:@"keys"];
			NSUInteger primaryKeyFieldCount = [primaryKeyFieldNames count];
			NSUInteger *primaryKeyFieldIndexes = calloc(primaryKeyFieldCount, sizeof(NSUInteger));
			for (NSUInteger i = 0; i < primaryKeyFieldCount; i++) {
				primaryKeyFieldIndexes[i] = [[tableDataInstance columnNames] indexOfObject:[primaryKeyFieldNames objectAtIndex:i]];
				if (primaryKeyFieldIndexes[i] == NSNotFound) {
					columnsFound = NO;
				}
			}

			// Only proceed with reselection if all columns were found
			if (columnsFound && primaryKeyFieldCount) {
				NSDictionary *selectionKeysToRestore = [selectionToRestore objectForKey:@"rows"];
				NSUInteger rowsToSelect = [selectionKeysToRestore count];
				BOOL rowMatches = NO;

				for (NSUInteger i = 0; i < tableRowsCount; i++) {

					// For single-column primary keys look up the cell value in the dictionary for a match
					if (primaryKeyFieldCount == 1) {
						if ([selectionKeysToRestore objectForKey:SPDataStorageObjectAtRowAndColumn(tableValues, i, primaryKeyFieldIndexes[0])]) {
							rowMatches = YES;
						}

					// For multi-column primary keys, convert all the cells to a string for lookup.
					} else {
						NSMutableString *lookupString = [[NSMutableString alloc] initWithString:[SPDataStorageObjectAtRowAndColumn(tableValues, i, primaryKeyFieldIndexes[0]) description]];
						for (NSUInteger j = 1; j < primaryKeyFieldCount; j++) {
							[lookupString appendString:SPUniqueSchemaDelimiter];
							[lookupString appendString:[SPDataStorageObjectAtRowAndColumn(tableValues, i, primaryKeyFieldIndexes[j]) description]];
						}
						if ([selectionKeysToRestore objectForKey:lookupString]) rowMatches = YES;
						[lookupString release];
					}
					
					if (rowMatches) {
						[selectionSet addIndex:i];
						rowsToSelect--;
						if (rowsToSelect <= 0) break;
						rowMatches = NO;
					}
				}
			}

			free(primaryKeyFieldIndexes);

		} else if ([[selectionToRestore objectForKey:@"type"] isEqualToString:SPSelectionDetailTypeIndexed]) {
			selectionSet = [selectionToRestore objectForKey:@"rows"];
		}

		[[tableContentView onMainThread] selectRowIndexes:selectionSet byExtendingSelection:NO];
		tableRowsSelectable = previousTableRowsSelectable;
	}

	if ([prefs boolForKey:SPLimitResults] && (contentPage > 1 || (NSInteger)tableRowsCount == [prefs integerForKey:SPLimitResultsValue]))
	{
		isLimited = YES;
	} else {
		isLimited = NO;
	}

	// Update the rows count as necessary
	[self updateNumberOfRows];

	// Set the filter text
	[self updateCountText];

	// Update pagination
	[[self onMainThread] updatePaginationState];

	// Retrieve and cache the column definitions for editing views
	if (cqColumnDefinition) [cqColumnDefinition release];
	cqColumnDefinition = [[resultStore fieldDefinitions] retain];


	// Notify listenters that the query has finished
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];

	if ([mySQLConnection queryErrored] && ![mySQLConnection lastQueryWasCancelled]) {
#ifndef SP_CODA
		if(activeFilter == 0) {
#endif
			NSString *errorDetail;
			if(filterString)
				errorDetail = [NSString stringWithFormat:NSLocalizedString(@"The table data couldn't be loaded presumably due to used filter clause. \n\nMySQL said: %@", @"message of panel when loading of table failed and presumably due to used filter argument"), [mySQLConnection lastErrorMessage]];
			else
				errorDetail = [NSString stringWithFormat:NSLocalizedString(@"The table data couldn't be loaded.\n\nMySQL said: %@", @"message of panel when loading of table failed"), [mySQLConnection lastErrorMessage]];
		
			SPOnewayAlertSheet(NSLocalizedString(@"Error", @"error"), [tableDocumentInstance parentWindow], errorDetail);
		}
#ifndef SP_CODA
		// Filter task came from filter table
		else if(activeFilter == 1){
			[filterTableWindow setTitle:[NSString stringWithFormat:@"%@ – %@", NSLocalizedString(@"Filter", @"filter label"), NSLocalizedString(@"WHERE clause not valid", @"WHERE clause not valid")]];
		}
	} 
#endif
	else 
	{
#ifndef SP_CODA
		// Trigger a full reload if required
		if (fullTableReloadRequired) [self reloadTable:self];
		[[filterTableWindow onMainThread] setTitle:NSLocalizedString(@"Filter", @"filter label")];
#endif
	}
}

/**
 * Processes a supplied streaming result store, monitoring the load and updating the data
 * displayed during download.
 */
- (void)updateResultStore:(SPMySQLStreamingResultStore *)theResultStore approximateRowCount:(NSUInteger)targetRowCount;
{
	NSUInteger i;
	NSUInteger dataColumnsCount = [dataColumns count];
	tableLoadTargetRowCount = targetRowCount;

	// Update the data storage, updating the current store if appropriate
	pthread_mutex_lock(&tableValuesLock);
	tableRowsCount = 0;
	[tableValues setDataStorage:theResultStore updatingExisting:!![tableValues count]];
	pthread_mutex_unlock(&tableValuesLock);

	// Start the data downloading
	[theResultStore startDownload];

#ifndef SP_CODA
	NSProgressIndicator *dataLoadingIndicator = [tableDocumentInstance valueForKey:@"queryProgressBar"];
#else
	NSProgressIndicator *dataLoadingIndicator = [tableDocumentInstance queryProgressBar];
#endif

#ifndef SP_CODA
	// Set the column load states on the table values store
	if ([prefs boolForKey:SPLoadBlobsAsNeeded]) {
		for ( i = 0; i < dataColumnsCount ; i++ ) {
			if ([tableDataInstance columnIsBlobOrText:[NSArrayObjectAtIndex(dataColumns, i) objectForKey:@"name"]]) {
				[tableValues setColumnAsUnloaded:i];
			}
		}
	}
#endif

	// Set up the table updates timer and wait for it to notify this thread about completion
	[[self onMainThread] initTableLoadTimer];

	[tableValues awaitDataDownloaded];

	tableRowsCount = [tableValues count];

	// If the final column autoresize wasn't performed, perform it
	if (tableLoadLastRowCount < 200) [[self onMainThread] autosizeColumns];

	// Ensure the table is aware of changes
	[[tableContentView onMainThread] noteNumberOfRowsChanged];

	// Reset the progress indicator
	[dataLoadingIndicator setIndeterminate:YES];
}

/**
 * Returns the query string for the current filter settings,
 * ready to be dropped into a WHERE clause, or nil if no filtering
 * is active.
 *
 * @warning Uses UI. ONLY call from main thread!
 */
- (NSString *)tableFilterString
{

#ifndef SP_CODA
	// If filter command was passed by sequelpro url scheme
	if(activeFilter == 2) {
		if(schemeFilter)
			return schemeFilter;
	}

	// Call did come from filter table and is filter table window still open?
	if(activeFilter == 1 && [filterTableWindow isVisible]) {

		if([[[filterTableWhereClause textStorage] string] length])
			if([filterTableNegateCheckbox state] == NSOnState)
				return [NSString stringWithFormat:@"NOT (%@)", [[filterTableWhereClause textStorage] string]];
			else
				return [[filterTableWhereClause textStorage] string];
		else
			return nil;

	}
#endif

	// If the clause has the placeholder $BINARY that placeholder will be replaced
	// by BINARY if the user pressed ⇧ while invoking 'Filter' otherwise it will
	// replaced by @"".
	BOOL caseSensitive = (([[[NSApp onMainThread] currentEvent] modifierFlags] & NSShiftKeyMask) > 0);

	if(contentFilters == nil) {
		NSLog(@"Fatal error while retrieving content filters. No filters found.");
		NSBeep();
		return nil;
	}

	// Current selected filter type
	if(![contentFilters objectForKey:compareType]) {
		NSLog(@"Error while retrieving filters. Filter type “%@” unknown.", compareType);
		NSBeep();
		return nil;
	}
	NSDictionary *filter = [[contentFilters objectForKey:compareType] objectAtIndex:[[compareField selectedItem] tag]];

	if(![filter objectForKey:@"NumberOfArguments"]) {
		NSLog(@"Error while retrieving filter clause. No “NumberOfArguments” key found.");
		NSBeep();
		return nil;
	}

	if(![filter objectForKey:@"Clause"] || ![(NSString *)[filter objectForKey:@"Clause"] length]) {

		SPOnewayAlertSheet(
			NSLocalizedString(@"Warning", @"warning"),
			[tableDocumentInstance parentWindow],
			NSLocalizedString(@"Content Filter clause is empty.", @"content filter clause is empty tooltip.")
		);

		return nil;
	}
	
	SPTableFilterParser *parser = [[[SPTableFilterParser alloc] initWithFilterClause:[filter objectForKey:@"Clause"] numberOfArguments:[[filter objectForKey:@"NumberOfArguments"] integerValue]] autorelease];
	[parser setArgument:[argumentField stringValue]];
	[parser setFirstBetweenArgument:[firstBetweenField stringValue]];
	[parser setSecondBetweenArgument:[secondBetweenField stringValue]];
	[parser setSuppressLeadingTablePlaceholder:[[filter objectForKey:@"SuppressLeadingFieldPlaceholder"] boolValue]];
	[parser setCaseSensitive:caseSensitive];
	[parser setCurrentField:[fieldField titleOfSelectedItem]];
	
	return [parser filterString];
}

/**
 * Update the table count/selection text
 */
- (void)updateCountText
{
	NSString *rowString;
	NSMutableString *countString = [NSMutableString string];
	NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];

	// Set up a couple of common strings
	NSString *tableCountString = [numberFormatter stringFromNumber:[NSNumber numberWithUnsignedInteger:tableRowsCount]];
	NSString *maxRowsString = [numberFormatter stringFromNumber:[NSNumber numberWithUnsignedInteger:maxNumRows]];

	// If the result is partial due to an error or query cancellation, show a very basic count
	if (isInterruptedLoad) {
		if (tableRowsCount == 1)
			[countString appendFormat:NSLocalizedString(@"%@ row in partial load", @"text showing a single row a partially loaded result"), tableCountString];
		else
			[countString appendFormat:NSLocalizedString(@"%@ rows in partial load", @"text showing how many rows are in a partially loaded result"), tableCountString];

	// If no filter or limit is active, show just the count of rows in the table
	} else if (!isFiltered && !isLimited) {
		if (tableRowsCount == 1)
			[countString appendFormat:NSLocalizedString(@"%@ row in table", @"text showing a single row in the result"), tableCountString];
		else
			[countString appendFormat:NSLocalizedString(@"%@ rows in table", @"text showing how many rows are in the result"), tableCountString];

	// If a limit is active, display a string suggesting a limit is active
	} else if (!isFiltered && isLimited) {
		NSUInteger limitStart = (contentPage-1)*[prefs integerForKey:SPLimitResultsValue] + 1;
		[countString appendFormat:NSLocalizedString(@"Rows %@ - %@ of %@%@ from table", @"text showing how many rows are in the limited result"),  [numberFormatter stringFromNumber:[NSNumber numberWithUnsignedInteger:limitStart]], [numberFormatter stringFromNumber:[NSNumber numberWithUnsignedInteger:(limitStart+tableRowsCount-1)]], maxNumRowsIsEstimate?@"~":@"", maxRowsString];

	// If just a filter is active, show a count and an indication a filter is active
	} else if (isFiltered && !isLimited) {
		if (tableRowsCount == 1)
			[countString appendFormat:NSLocalizedString(@"%@ row of %@%@ matches filter", @"text showing how a single rows matched filter"), tableCountString, maxNumRowsIsEstimate?@"~":@"", maxRowsString];
		else
			[countString appendFormat:NSLocalizedString(@"%@ rows of %@%@ match filter", @"text showing how many rows matched filter"), tableCountString, maxNumRowsIsEstimate?@"~":@"", maxRowsString];

	// If both a filter and limit is active, display full string
	} else {
		NSUInteger limitStart = (contentPage-1)*[prefs integerForKey:SPLimitResultsValue] + 1;
		[countString appendFormat:NSLocalizedString(@"Rows %@ - %@ from filtered matches", @"text showing how many rows are in the limited filter match"), [numberFormatter stringFromNumber:[NSNumber numberWithUnsignedInteger:limitStart]], [numberFormatter stringFromNumber:[NSNumber numberWithUnsignedInteger:(limitStart+tableRowsCount-1)]]];
	}

	// If rows are selected, append selection count
	if ([tableContentView numberOfSelectedRows] > 0) {
		[countString appendString:@"; "];
		if ([tableContentView numberOfSelectedRows] == 1)
			rowString = [NSString stringWithString:NSLocalizedString(@"row", @"singular word for row")];
		else
			rowString = [NSString stringWithString:NSLocalizedString(@"rows", @"plural word for rows")];
		[countString appendFormat:NSLocalizedString(@"%@ %@ selected", @"text showing how many rows are selected"), [numberFormatter stringFromNumber:[NSNumber numberWithInteger:[tableContentView numberOfSelectedRows]]], rowString];
	}

#ifndef SP_CODA
	[[countText onMainThread] setStringValue:countString];
#endif
}

/**
 * Set up the table loading interface update timer.
 * This should be called on the main thread.
 */
- (void) initTableLoadTimer
{
	if (tableLoadTimer) [self clearTableLoadTimer];
	tableLoadInterfaceUpdateInterval = 1;
	tableLoadLastRowCount = 0;
	tableLoadTimerTicksSinceLastUpdate = 0;

	tableLoadTimer = [[NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(tableLoadUpdate:) userInfo:nil repeats:YES] retain];
}

/**
 * Invalidate and release the table loading interface update timer.
 * This should be called on the main thread.
 */
- (void) clearTableLoadTimer
{
	if (tableLoadTimer) {
		[tableLoadTimer invalidate];
		SPClear(tableLoadTimer);
	}
}

/**
 * Perform table interface updates when loading tables, based on timer
 * ticks.  As data becomes available, the table should be redrawn to
 * show new rows - quickly at the start of the table, and then slightly
 * slower after some time to avoid needless updates.
 */
- (void) tableLoadUpdate:(NSTimer *)theTimer
{
	tableRowsCount = [tableValues count];

	// Update the task interface as necessary
	if (!isFiltered && tableLoadTargetRowCount != NSUIntegerMax) {
		if (tableRowsCount < tableLoadTargetRowCount) {
			[tableDocumentInstance setTaskPercentage:(tableRowsCount*100/tableLoadTargetRowCount)];
		} else if (tableRowsCount >= tableLoadTargetRowCount) {
			[tableDocumentInstance setTaskPercentage:100.0f];
			[tableDocumentInstance setTaskProgressToIndeterminateAfterDelay:YES];
			tableLoadTargetRowCount = NSUIntegerMax;
		}
	}

	if (tableLoadTimerTicksSinceLastUpdate < tableLoadInterfaceUpdateInterval) {
		tableLoadTimerTicksSinceLastUpdate++;
		return;
	}

	if ([tableValues dataDownloaded]) {
		[self clearTableLoadTimer];
	}

	// Check whether a table update is required, based on whether new rows are
	// available to display.
	if (tableRowsCount == tableLoadLastRowCount) {
		return;
	}

	// Update the table display
	[tableContentView noteNumberOfRowsChanged];

	// Update column widths in two cases: on very first rows displayed, and once
	// more than 200 rows are present.
	if (tableLoadInterfaceUpdateInterval == 1 || (tableRowsCount >= 200 && tableLoadLastRowCount < 200)) {
		[self autosizeColumns];
	}

	tableLoadLastRowCount = tableRowsCount;

	// Determine whether to decrease the update frequency
	switch (tableLoadInterfaceUpdateInterval) {
		case 1:
			tableLoadInterfaceUpdateInterval = 10;
			break;
		case 10:
			tableLoadInterfaceUpdateInterval = 25;
			break;
	}
	tableLoadTimerTicksSinceLastUpdate = 0;
}


#pragma mark -
#pragma mark Table interface actions

/**
 * Reloads the current table data, performing a new SQL query. Now attempts to preserve sort
 * order, filters, and viewport. Performs the action in a new thread if a task is not already
 * running.
 */
- (IBAction)reloadTable:(id)sender
{
	[tableDocumentInstance startTaskWithDescription:NSLocalizedString(@"Reloading data...", @"Reloading data task description")];

	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadWithName:SPCtxt(@"SPTableContent table reload task", tableDocumentInstance) target:self selector:@selector(reloadTableTask) object:nil];
	} else {
		[self reloadTableTask];
	}
}

- (void)reloadTableTask
{
	NSAutoreleasePool *reloadPool = [[NSAutoreleasePool alloc] init];

	// Check whether a save of the current row is required.
	if (![[self onMainThread] saveRowOnDeselect]) return;

	// Save view details to restore safely if possible (except viewport, which will be
	// preserved automatically, and can then be scrolled as the table loads)
	[self storeCurrentDetailsForRestoration];
	[self setViewportToRestore:NSZeroRect];

	// Clear the table data column cache and status (including counts)
	[tableDataInstance resetColumnData];
	[tableDataInstance resetStatusData];

	// Load the table's data
	[self loadTable:[tablesListInstance tableName]];

	[tableDocumentInstance endTask];

	[reloadPool drain];
}

/**
 * Filter the table with arguments given by the user.
 * Performs the action in a new thread if necessary.
 */
- (IBAction)filterTable:(id)sender
{
	BOOL senderIsPaginationButton = (sender == paginationPreviousButton || sender == paginationNextButton
#ifndef SP_CODA
		|| sender == paginationGoButton
#endif
		);

	// Record whether the filter is being triggered by using delete/backspace in the filter field, which
	// can trigger the effect of clicking the "clear filter" button in the field.
	// (Keycode 51 is backspace, 117 is delete.)
	BOOL deleteTriggeringFilter = ([sender isKindOfClass:[NSSearchField class]] && [[[sender window] currentEvent] type] == NSKeyDown && ([[[sender window] currentEvent] keyCode] == 51 || [[[sender window] currentEvent] keyCode] == 117));

#ifndef SP_CODA

	// If the filter table is being used - the advanced filter - switch type
	if(sender == filterTableFilterButton) {
		activeFilter = 1;
	}

	// If a string was supplied, use a custom query from that URL scheme
	else if([sender isKindOfClass:[NSString class]] && [(NSString *)sender length]) {
		if(schemeFilter) SPClear(schemeFilter);
		schemeFilter = [sender retain];
		activeFilter = 2;
	}

	// If a button other than the pagination buttons was used, set the active filter type to
	// the standard filter field.
	else if (!senderIsPaginationButton) {
		activeFilter = 0;
	}
#endif

	NSString *taskString;

	if ([tableDocumentInstance isWorking]) return;

	// If the filter field is being cleared by deleting the contents, and there's no current filter,
	// don't trigger a reload.
	if (deleteTriggeringFilter && !isFiltered && ![self tableFilterString]) {
		return;
	}

	// Check whether a save of the current row is required, restoring focus afterwards if appropriate
	if (![self saveRowOnDeselect]) return;
	if (deleteTriggeringFilter) {
		[sender becomeFirstResponder];
	}

#ifndef SP_CODA
	[self setPaginationViewVisibility:NO];
#endif

	// Select the correct pagination value.
	// If the filter button was used, or if pagination is disabled, reset to page one
	if (!senderIsPaginationButton && ([sender isKindOfClass:[NSButton class]] || [sender isKindOfClass:[NSTextField class]] || ![prefs boolForKey:SPLimitResults] || [paginationPageField integerValue] <= 0))
		contentPage = 1;

	// If the current page is out of bounds, move it within bounds
	else if (([paginationPageField integerValue] - 1) * [prefs integerForKey:SPLimitResultsValue] >= maxNumRows)
		contentPage = ceilf((CGFloat)maxNumRows / [prefs floatForKey:SPLimitResultsValue]);

	// Otherwise, use the pagination value
	else
		contentPage = [paginationPageField integerValue];

	if ([self tableFilterString]) {
		taskString = NSLocalizedString(@"Filtering table...", @"Filtering table task description");
	} else if (contentPage == 1) {
		taskString = [NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), selectedTable];
	} else {
		taskString = [NSString stringWithFormat:NSLocalizedString(@"Loading page %lu...", @"Loading table page task string"), (unsigned long)contentPage];
	}

	[tableDocumentInstance startTaskWithDescription:taskString];

	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadWithName:SPCtxt(@"SPTableContent filter table task", tableDocumentInstance) target:self selector:@selector(filterTableTask) object:nil];
	} else {
		[self filterTableTask];
	}
}
- (void)filterTableTask
{
	NSAutoreleasePool *filterPool = [[NSAutoreleasePool alloc] init];

#ifndef SP_CODA
	// Update history
	[spHistoryControllerInstance updateHistoryEntries];
#endif

	// Reset and reload data using the new filter settings
	[self setSelectionToRestore:[self selectionDetailsAllowingIndexSelection:NO]];
	previousTableRowsCount = 0;
	[self clearTableValues];
	[self loadTableValues];
	[[tableContentView onMainThread] scrollPoint:NSMakePoint(0.0f, 0.0f)];

	[tableDocumentInstance endTask];
	[filterPool drain];
}

/**
 * Enables or disables the filter input field based on the selected filter type.
 */
- (IBAction)toggleFilterField:(id)sender
{

	// Check if user called "Edit Filter…"
	if([[compareField selectedItem] tag] == (NSInteger)[[contentFilters objectForKey:compareType] count]) {
		[self openContentFilterManager];
		return;
	}

	// Remember last selection for "Edit filter…"
	lastSelectedContentFilterIndex = [[compareField selectedItem] tag];

	NSDictionary *filter = [[contentFilters objectForKey:compareType] objectAtIndex:lastSelectedContentFilterIndex];
	NSUInteger numOfArgs = [[filter objectForKey:@"NumberOfArguments"] integerValue];
	if (numOfArgs == 2) {
		[argumentField setHidden:YES];

		if([filter objectForKey:@"ConjunctionLabels"] && [[filter objectForKey:@"ConjunctionLabels"] count] == 1)
			[betweenTextField setStringValue:[[filter objectForKey:@"ConjunctionLabels"] objectAtIndex:0]];
		else
			[betweenTextField setStringValue:@""];

		[betweenTextField setHidden:NO];
		[firstBetweenField setHidden:NO];
		[secondBetweenField setHidden:NO];

		[firstBetweenField setEnabled:YES];
		[secondBetweenField setEnabled:YES];
		[firstBetweenField selectText:self];
	}
	else if (numOfArgs == 1){
		[argumentField setHidden:NO];
		[argumentField setEnabled:YES];
		[argumentField selectText:self];

		[betweenTextField setHidden:YES];
		[firstBetweenField setHidden:YES];
		[secondBetweenField setHidden:YES];
	}
	else {
		[argumentField setHidden:NO];
		[argumentField setEnabled:NO];

		[betweenTextField setHidden:YES];
		[firstBetweenField setHidden:YES];
		[secondBetweenField setHidden:YES];

		// Start search if no argument is required
		if(numOfArgs == 0)
			[self filterTable:self];
	}

}

- (void)setUsedQuery:(NSString *)query
{
	if (usedQuery) [usedQuery release];
	usedQuery = [[NSString alloc] initWithString:query];
}

- (void)sortTableTaskWithColumn:(NSTableColumn *)tableColumn
{
	NSAutoreleasePool *sortPool = [[NSAutoreleasePool alloc] init];
	
	// Check whether a save of the current row is required.
	if (![[self onMainThread] saveRowOnDeselect]) {

		// If the save failed, cancel the sort task and return
		[tableDocumentInstance endTask];
		[sortPool drain];
		return;
	}
	
    NSUInteger modifierFlags = [[NSApp currentEvent] modifierFlags];
    
	// Sets column order as tri-state descending, ascending, no sort, descending, ascending etc. order if the same
	// header is clicked several times
	if (sortCol && [[tableColumn identifier] integerValue] == [sortCol integerValue]) {
        BOOL invert = NO;
        if (modifierFlags & NSShiftKeyMask) {
            invert = YES;
        }
        
        // this is the same as saying (isDesc && !invert) || (!isDesc && invert)
        if (isDesc != invert) {
			SPClear(sortCol);
		} 
		else {
			isDesc = !isDesc;
		}
	} 
	else {
        // When the column is not sorted, allow to sort in reverse order using Shift+click
        if (modifierFlags & NSShiftKeyMask) {
            isDesc = YES;
        } else {
            isDesc = NO;
        }
		
		[[tableContentView onMainThread] setIndicatorImage:nil inTableColumn:[tableContentView tableColumnWithIdentifier:[NSString stringWithFormat:@"%lld", (long long)[sortCol integerValue]]]];
		
		if (sortCol) [sortCol release];
		
		sortCol = [[NSNumber alloc] initWithInteger:[[tableColumn identifier] integerValue]];
	}
	
	if (sortCol) {
		// Set the highlight and indicatorImage
		[[tableContentView onMainThread] setHighlightedTableColumn:tableColumn];
		
		if (isDesc) {
			[[tableContentView onMainThread] setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:tableColumn];
		} 
		else {
			[[tableContentView onMainThread] setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:tableColumn];
		}
	} 
	else {
		// If no sort order deselect column header and
		// remove indicator image
		[[tableContentView onMainThread] setHighlightedTableColumn:nil];
		[[tableContentView onMainThread] setIndicatorImage:nil inTableColumn:tableColumn];
	}
	
	// Update data using the new sort order
	previousTableRowsCount = tableRowsCount;
	[self setSelectionToRestore:[self selectionDetailsAllowingIndexSelection:NO]];
	[[tableContentView onMainThread] selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
	[self loadTableValues];
	
	if ([mySQLConnection queryErrored] && ![mySQLConnection lastQueryWasCancelled]) {
		SPOnewayAlertSheet(
			NSLocalizedString(@"Error", @"error"),
			[tableDocumentInstance parentWindow],
			[NSString stringWithFormat:NSLocalizedString(@"Couldn't sort table. MySQL said: %@", @"message of panel when sorting of table failed"), [mySQLConnection lastErrorMessage]]
		);
		
		[tableDocumentInstance endTask];
		[sortPool drain];
		
		return;
	}
	
	[tableDocumentInstance endTask];
	[sortPool drain];
}

#pragma mark -
#pragma mark Pagination

/**
 * Move the pagination backwards or forwards one page, or update
 * the page to respect the submitted field.
 */
- (IBAction) navigatePaginationFromButton:(id)sender
{
	if (![self saveRowOnDeselect]) return;

	if (sender == paginationPreviousButton) {
		if (contentPage <= 1) return;
		[paginationPageField setIntegerValue:(contentPage - 1)];
	} else if (sender == paginationNextButton) {
		if ((NSInteger)contentPage * [prefs integerForKey:SPLimitResultsValue] >= maxNumRows) return;
		[paginationPageField setIntegerValue:(contentPage + 1)];
	}

	[self filterTable:sender];
}

/**
 * When the Pagination button is pressed, show or hide the pagination
 * layer depending on the current state.
 */
#ifndef SP_CODA
- (IBAction) togglePagination:(NSButton *)sender
{
	[self setPaginationViewVisibility:([sender state] == NSOnState)];
}
#endif

- (void)popoverDidClose:(NSNotification *)notification
{
	//not to hide the view, but to change the paginationButton
	[self setPaginationViewVisibility:NO];
}

/**
 * Show or hide the pagination layer, also changing the first responder as appropriate.
 */
- (void) setPaginationViewVisibility:(BOOL)makeVisible
{
#ifndef SP_CODA
	NSRect paginationViewFrame = [paginationView frame];
	
	if(makeVisible) {
		[paginationButton setState:NSOnState];
		[paginationButton setImage:[NSImage imageNamed:@"button_action"]];
		[[paginationPageField window] makeFirstResponder:paginationPageField];
	}
	else {
		[paginationButton setState:NSOffState];
		[paginationButton setImage:[NSImage imageNamed:@"button_pagination"]];
		if ([[paginationPageField window] firstResponder] == paginationPageField
			|| ([[[paginationPageField window] firstResponder] respondsToSelector:@selector(superview)]
				&& [(id)[[paginationPageField window] firstResponder] superview]
				&& [[(id)[[paginationPageField window] firstResponder] superview] respondsToSelector:@selector(superview)]
				&& [[(id)[[paginationPageField window] firstResponder] superview] superview] == paginationPageField))
		{
			[[paginationPageField window] makeFirstResponder:nil];
		}
	}
	
	if(paginationPopover) {
		if(makeVisible) {
			[paginationPopover showRelativeToRect:[paginationButton bounds] ofView:paginationButton preferredEdge:NSMinYEdge];
		}
		else if([paginationPopover isShown]) {
			//usually this should not happen, as the popover will disappear once the user clicks somewhere
			//else in the window (including the paginationButton).
			[paginationPopover close];
		}
		return;
	}
	
	if (makeVisible) {
		if (paginationViewFrame.size.height == paginationViewHeight) return;
		paginationViewFrame.size.height = paginationViewHeight;
	} else {
		if (paginationViewFrame.size.height == 0) return;
		paginationViewFrame.size.height = 0;
	}

	[[paginationView animator] setFrame:paginationViewFrame];
#endif
}

/**
 * Update the state of the pagination buttons and text.
 * This function is not thread-safe and should be called on the main thread.
 */
- (void) updatePaginationState
{
	NSUInteger maxPage = ceilf((CGFloat)maxNumRows / [prefs floatForKey:SPLimitResultsValue]);
	if (isFiltered && !isLimited) {
		maxPage = contentPage;
	}
	BOOL enabledMode = ![tableDocumentInstance isWorking];

	NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];

	// Set up the previous page button
	if ([prefs boolForKey:SPLimitResults] && contentPage > 1)
		[paginationPreviousButton setEnabled:enabledMode];
	else
		[paginationPreviousButton setEnabled:NO];

	// Set up the next page button
	if ([prefs boolForKey:SPLimitResults] && contentPage < maxPage)
		[paginationNextButton setEnabled:enabledMode];
	else
		[paginationNextButton setEnabled:NO];

#ifndef SP_CODA
	// As long as a table is selected (which it will be if this is called), enable pagination detail button
	[paginationButton setEnabled:enabledMode];
#endif

	// Set the values and maximums for the text field and associated pager
	[paginationPageField setStringValue:[numberFormatter stringFromNumber:[NSNumber numberWithUnsignedInteger:contentPage]]];
	[[paginationPageField formatter] setMaximum:[NSNumber numberWithUnsignedInteger:maxPage]];
#ifndef SP_CODA
	[paginationPageStepper setIntegerValue:contentPage];
	[paginationPageStepper setMaxValue:maxPage];
#endif
}

#pragma mark -
#pragma mark Edit methods

/**
 * Collect all columns for a given 'tableForColumn' table and
 * return a WHERE clause for identifying the field in quesyion.
 */
- (NSString *)argumentForRow:(NSUInteger)rowIndex ofTable:(NSString *)tableForColumn andDatabase:(NSString *)database includeBlobs:(BOOL)includeBlobs
{
	NSArray *dataRow;
	id field;
	NSMutableArray *argumentParts = [NSMutableArray array];

	// Check the table/view columns and select only those coming from the supplied database and table
	NSMutableArray *columnsInSpecifiedTable = [NSMutableArray array];
	for(field in cqColumnDefinition) {
		if([[field objectForKey:@"db"] isEqualToString:database] && [[field objectForKey:@"org_table"] isEqualToString:tableForColumn])
			[columnsInSpecifiedTable addObject:field];
	}

	// --- Build WHERE clause ---
	dataRow = [tableValues rowContentsAtIndex:rowIndex];

	// Get the primary key if there is one, using any columns present within it
	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM %@.%@",
		[database backtickQuotedString], [tableForColumn backtickQuotedString]]];
	[theResult setReturnDataAsStrings:YES];
	NSMutableArray *primaryColumnsInSpecifiedTable = [NSMutableArray array];
	for (NSDictionary *eachRow in theResult) {
		if ( [[eachRow objectForKey:@"Key"] isEqualToString:@"PRI"] ) {
			for (field in columnsInSpecifiedTable) {
				if([[field objectForKey:@"org_name"] isEqualToString:[eachRow objectForKey:@"Field"]]) {
					[primaryColumnsInSpecifiedTable addObject:field];
				}
			}
		}
	}

	// Determine whether to use the primary keys list or fall back to all fields when building the query string
	NSMutableArray *columnsToQuery = [primaryColumnsInSpecifiedTable count] ? primaryColumnsInSpecifiedTable : columnsInSpecifiedTable;

	// Build up the argument
	for (field in columnsToQuery) {
		id aValue = [dataRow objectAtIndex:[[field objectForKey:@"datacolumnindex"] integerValue]];
		if ([aValue isNSNull]) {
			[argumentParts addObject:[NSString stringWithFormat:@"%@ IS NULL", [[field objectForKey:@"org_name"] backtickQuotedString]]];
		} else {
			NSString *fieldTypeGrouping = [field objectForKey:@"typegrouping"];

			// Skip blob-type fields if requested
			if (!includeBlobs
				&& ([fieldTypeGrouping isEqualToString:@"textdata"]
					||  [fieldTypeGrouping isEqualToString:@"blobdata"]
					|| [[field objectForKey:@"type"] isEqualToString:@"BINARY"]
					|| [[field objectForKey:@"type"] isEqualToString:@"VARBINARY"]))
			{
				continue;
			}

			// If the field is of type BIT then it needs a binary prefix
			if ([fieldTypeGrouping isEqualToString:@"bit"]) {
				[argumentParts addObject:[NSString stringWithFormat:@"%@=b'%@'", [[field objectForKey:@"org_name"] backtickQuotedString], [aValue description]]];
			}
			else if ([fieldTypeGrouping isEqualToString:@"geometry"]) {
				[argumentParts addObject:[NSString stringWithFormat:@"%@=%@", [[field objectForKey:@"org_name"] backtickQuotedString], [mySQLConnection escapeAndQuoteData:[aValue data]]]];
			}
			// BLOB/TEXT data
			else if ([aValue isKindOfClass:[NSData class]]) {
				[argumentParts addObject:[NSString stringWithFormat:@"%@=%@", [[field objectForKey:@"org_name"] backtickQuotedString], [mySQLConnection escapeAndQuoteData:aValue]]];
			}
			else {
				[argumentParts addObject:[NSString stringWithFormat:@"%@=%@", [[field objectForKey:@"org_name"] backtickQuotedString], [mySQLConnection escapeAndQuoteString:aValue]]];
			}
		}
	}

	// Check for empty strings
	if (![argumentParts count]) return nil;

	return [NSString stringWithFormat:@"WHERE (%@)", [argumentParts componentsJoinedByString:@" AND "]];
}

/**
 * Adds an empty row to the table-array and goes into edit mode
 */
- (IBAction)addRow:(id)sender
{
	NSMutableArray *newRow = [NSMutableArray array];

	// Check whether table editing is permitted (necessary as some actions - eg table double-click - bypass validation)
	if ([tableDocumentInstance isWorking] || [tablesListInstance tableType] != SPTableTypeTable) return;

	// Check whether a save of the current row is required.
	if ( ![self saveRowOnDeselect] ) return;

	for (NSDictionary *column in dataColumns) {
		if ([column objectForKey:@"default"] == nil || [[column objectForKey:@"default"] isNSNull]) {
			[newRow addObject:[NSNull null]];
		} else if ([[column objectForKey:@"default"] isEqualToString:@""]
					&& ![[column objectForKey:@"null"] boolValue]
					&& ([[column objectForKey:@"typegrouping"] isEqualToString:@"float"]
						|| [[column objectForKey:@"typegrouping"] isEqualToString:@"integer"]
						|| [[column objectForKey:@"typegrouping"] isEqualToString:@"bit"]))
		{
			[newRow addObject:@"0"];
		} else if ([[column objectForKey:@"typegrouping"] isEqualToString:@"bit"] && [[column objectForKey:@"default"] hasPrefix:@"b'"] && [(NSString*)[column objectForKey:@"default"] length] > 3) {
			// remove leading b' and final '
			[newRow addObject:[[[column objectForKey:@"default"] substringFromIndex:2] substringToIndex:[(NSString*)[column objectForKey:@"default"] length]-3]];
		} else {
			[newRow addObject:[column objectForKey:@"default"]];
		}
	}
	[tableValues addRowWithContents:newRow];
	tableRowsCount++;

	[tableContentView reloadData];
	[tableContentView selectRowIndexes:[NSIndexSet indexSetWithIndex:[tableContentView numberOfRows]-1] byExtendingSelection:NO];
	[tableContentView scrollRowToVisible:[tableContentView selectedRow]];
	isEditingRow = YES;
	isEditingNewRow = YES;
	currentlyEditingRow = [tableContentView selectedRow];
#ifndef SP_CODA
	if ( [multipleLineEditingButton state] == NSOffState )
#endif
		[tableContentView editColumn:0 row:[tableContentView numberOfRows]-1 withEvent:nil select:YES];
}

/**
 * Copies a row of the table-array and goes into edit mode
 */
- (IBAction)duplicateRow:(id)sender
{
	NSMutableArray *tempRow;
	SPMySQLResult *queryResult;
	NSDictionary *row;
	NSArray *dbDataRow = nil;
	NSUInteger i;

	// Check whether a save of the current row is required.
	if (![self saveRowOnDeselect]) return;

	if (![tableContentView numberOfSelectedRows]) return;
	
	if ([tableContentView numberOfSelectedRows] > 1) {
		SPOnewayAlertSheet(
			NSLocalizedString(@"Error", @"error"),
			[tableDocumentInstance parentWindow],
			NSLocalizedString(@"You can only copy single rows.", @"message of panel when trying to copy multiple rows")
		);
		return;
	}

	// Row contents
	tempRow = [tableValues rowContentsAtIndex:[tableContentView selectedRow]];

#ifndef SP_CODA
	// If we don't show blobs, read data for this duplicate column from db
	if ([prefs boolForKey:SPLoadBlobsAsNeeded]) {
		
		// Abort if there are no indices on this table - argumentForRow will display an error.
		NSString *whereArgument = [self argumentForRow:[tableContentView selectedRow]];
		if (![whereArgument length]) {
			return;
		}
		
		// If we have indexes, use argumentForRow
		queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@", [selectedTable backtickQuotedString], whereArgument]];
		dbDataRow = [queryResult getRowAsArray];
	}
#endif

	// Set autoincrement fields to NULL
	queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM %@", [selectedTable backtickQuotedString]]];
	
	[queryResult setReturnDataAsStrings:YES];
	
	for (i = 0; i < [queryResult numberOfRows]; i++) 
	{
		row = [queryResult getRowAsDictionary];
		
		if ([[row objectForKey:@"Extra"] isEqualToString:@"auto_increment"]) {
			[tempRow replaceObjectAtIndex:i withObject:[NSNull null]];
		} 
		else if ([tableDataInstance columnIsBlobOrText:[row objectForKey:@"Field"]] && 
#ifndef SP_CODA
				[prefs boolForKey:SPLoadBlobsAsNeeded] 
#else
				NO
#endif
				&& dbDataRow) {
			[tempRow replaceObjectAtIndex:i withObject:[dbDataRow objectAtIndex:i]];
		}
	}

	// Insert the copied row
	[tableValues insertRowContents:tempRow atIndex:[tableContentView selectedRow] + 1];
	tableRowsCount++;

	// Select row and go in edit mode
	[tableContentView reloadData];
	[tableContentView selectRowIndexes:[NSIndexSet indexSetWithIndex:[tableContentView selectedRow] + 1] byExtendingSelection:NO];
	
	isEditingRow = YES;
	isEditingNewRow = YES;
	
	currentlyEditingRow = [tableContentView selectedRow];
#ifndef SP_CODA
	if ([multipleLineEditingButton state]) {
#endif
		[tableContentView editColumn:0 row:[tableContentView selectedRow] withEvent:nil select:YES];
#ifndef SP_CODA
	}
#endif
}

/**
 * Asks the user if they really want to delete the selected rows
 */
- (IBAction)removeRow:(id)sender
{
	// cancel editing (maybe this is not the ideal method -- see xcode docs for that method)
	[[tableDocumentInstance parentWindow] endEditingFor:nil];

	if (![tableContentView numberOfSelectedRows]) return;

	NSAlert *alert = [NSAlert alertWithMessageText:@""
									 defaultButton:NSLocalizedString(@"Delete", @"delete button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil
						 informativeTextWithFormat:@""];

	[alert setAlertStyle:NSCriticalAlertStyle];

	NSArray *buttons = [alert buttons];

#ifndef SP_CODA
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
#else
	[[buttons objectAtIndex:0] setKeyEquivalent:@"\r"];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\e"];
#endif

	[alert setShowsSuppressionButton:NO];
	[[alert suppressionButton] setState:NSOffState];

	NSString *contextInfo = @"removerow";

	if (([tableContentView numberOfSelectedRows] == [tableContentView numberOfRows]) && [tableContentView numberOfSelectedRows] > 50 && !isFiltered && !isLimited && !isInterruptedLoad && !isEditingNewRow) {

		contextInfo = @"removeallrows";

		// If table has PRIMARY KEY ask for resetting the auto increment after deletion if given
		if(![[tableDataInstance statusValueForKey:@"Auto_increment"] isNSNull]) {
			[alert setShowsSuppressionButton:YES];
#ifndef SP_CODA
			[[alert suppressionButton] setState:([prefs boolForKey:SPResetAutoIncrementAfterDeletionOfAllRows]) ? NSOnState : NSOffState];
#endif
			[[[alert suppressionButton] cell] setControlSize:NSSmallControlSize];
			[[[alert suppressionButton] cell] setFont:[NSFont systemFontOfSize:11]];
			[[alert suppressionButton] setTitle:NSLocalizedString(@"Reset AUTO_INCREMENT after deletion?", @"reset auto_increment after deletion of all rows message")];
		}

		[alert setMessageText:NSLocalizedString(@"Delete all rows?", @"delete all rows message")];
		[alert setInformativeText:NSLocalizedString(@"Are you sure you want to delete all the rows from this table? This action cannot be undone.", @"delete all rows informative message")];
	}
	else if ([tableContentView numberOfSelectedRows] == 1) {
		[alert setMessageText:NSLocalizedString(@"Delete selected row?", @"delete selected row message")];
		[alert setInformativeText:NSLocalizedString(@"Are you sure you want to delete the selected row from this table? This action cannot be undone.", @"delete selected row informative message")];
	}
	else {
		[alert setMessageText:NSLocalizedString(@"Delete rows?", @"delete rows message")];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the selected %ld rows from this table? This action cannot be undone.", @"delete rows informative message"), (long)[tableContentView numberOfSelectedRows]]];
	}

	[alert beginSheetModalForWindow:[tableDocumentInstance parentWindow] modalDelegate:self didEndSelector:@selector(removeRowSheetDidEnd:returnCode:contextInfo:) contextInfo:contextInfo];
}

/**
 * Perform the requested row deletion action.
 */
- (void)removeRowSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	NSMutableIndexSet *selectedRows = [NSMutableIndexSet indexSet];
	NSString *wherePart;
	NSInteger i, errors;
	BOOL consoleUpdateStatus;
	BOOL reloadAfterRemovingRow = 
#ifndef SP_CODA
	[prefs boolForKey:SPReloadAfterRemovingRow]
#else
	NO
#endif
	;
	// Order out current sheet to suppress overlapping of sheets
	[[alert window] orderOut:nil];

	if ( [(NSString*)contextInfo isEqualToString:@"removeallrows"] ) {
		if ( returnCode == NSAlertDefaultReturn ) {

			// Check if the user is currently editing a row, and revert to ensure a somewhat
			// consistent state if deletion fails.
			if (isEditingRow) [self cancelRowEditing];

			[mySQLConnection queryString:[NSString stringWithFormat:@"DELETE FROM %@", [selectedTable backtickQuotedString]]];
			if ( ![mySQLConnection queryErrored] ) {
				maxNumRows = 0;
				tableRowsCount = 0;
				maxNumRowsIsEstimate = NO;
				[self updateCountText];

				// Reset auto increment if suppression button was ticked
				if([[alert suppressionButton] state] == NSOnState) {
					[tableSourceInstance setAutoIncrementTo:@1];
#ifndef SP_CODA
					[prefs setBool:YES forKey:SPResetAutoIncrementAfterDeletionOfAllRows];
#endif
				} else {
#ifndef SP_CODA
					[prefs setBool:NO forKey:SPResetAutoIncrementAfterDeletionOfAllRows];
#endif
				}

				[self reloadTable:self];

			} else {
				[self performSelector:@selector(showErrorSheetWith:)
					withObject:[NSArray arrayWithObjects:NSLocalizedString(@"Error", @"error"),
						[NSString stringWithFormat:NSLocalizedString(@"Couldn't delete rows.\n\nMySQL said: %@", @"message when deleteing all rows failed"),
						   [mySQLConnection lastErrorMessage]],
						nil]
					afterDelay:0.3];
			}
		}
	} else if ( [(NSString*)contextInfo isEqualToString:@"removerow"] ) {
		if ( returnCode == NSAlertDefaultReturn ) {
			[selectedRows addIndexes:[tableContentView selectedRowIndexes]];

			//check if the user is currently editing a row
			if (isEditingRow) {
				//make sure that only one row is selected. This should never happen
				if ([selectedRows count]!=1) {
					NSLog(@"Expected only one selected row, but found %lu", (unsigned long)[selectedRows count]);
				}

				// Always cancel the edit; if the user is currently editing a new row, we can just discard it;
				// if editing an old row, restore it to the original to ensure consistent state if deletion fails.
				// If editing a new row, deselect the row and return - as no table reload is required.
				if ( isEditingNewRow ) {
					[self cancelRowEditing]; // Resets isEditingNewRow!
					[tableContentView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
					return;
				} else {
					[self cancelRowEditing];
				}
			}
			[tableContentView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];

			NSInteger affectedRows = 0;
			errors = 0;

			// Disable updating of the Console Log window for large number of queries
			// to speed the deletion
			consoleUpdateStatus = [[SPQueryController sharedQueryController] allowConsoleUpdate];
			if([selectedRows count] > 10)
				[[SPQueryController sharedQueryController] setAllowConsoleUpdate:NO];

			NSUInteger anIndex = [selectedRows firstIndex];

			NSArray *primaryKeyFieldNames = [tableDataInstance primaryKeyColumnNames];

			// If no PRIMARY KEY is found and numberOfSelectedRows > 3 then
			// check for uniqueness of rows via combining all column values;
			// if unique then use the all columns as 'primary keys'
			if([selectedRows count] > 3 && primaryKeyFieldNames == nil) {
				primaryKeyFieldNames = [tableDataInstance columnNames];

				NSInteger numberOfRows = 0;

				// Get the number of rows in the table
				NSString *returnedCount = [mySQLConnection getFirstFieldFromQuery:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@", [selectedTable backtickQuotedString]]];
				if (returnedCount) {
					numberOfRows = [returnedCount integerValue];
				}

				// Check for uniqueness via LIMIT numberOfRows-1,numberOfRows for speed
				if(numberOfRows > 0) {
					[mySQLConnection queryString:[NSString stringWithFormat:@"SELECT * FROM %@ GROUP BY %@ LIMIT %ld,%ld", [selectedTable backtickQuotedString], [primaryKeyFieldNames componentsJoinedAndBacktickQuoted], (long)(numberOfRows-1), (long)numberOfRows]];
					if ([mySQLConnection rowsAffectedByLastQuery] == 0)
						primaryKeyFieldNames = nil;
				} else {
					primaryKeyFieldNames = nil;
				}
			}

			if(primaryKeyFieldNames == nil) {
				// delete row by row
				while (anIndex != NSNotFound) {

					wherePart = [NSString stringWithString:[self argumentForRow:anIndex]];

					//argumentForRow might return empty query, in which case we shouldn't execute the partial query
					if([wherePart length]) {
						[mySQLConnection queryString:[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@", [selectedTable backtickQuotedString], wherePart]];

						// Check for errors
						if ( ![mySQLConnection rowsAffectedByLastQuery] || [mySQLConnection queryErrored]) {
							// If error delete that index from selectedRows for reloading table if
							// "ReloadAfterRemovingRow" is disbaled
							if(!reloadAfterRemovingRow)
								[selectedRows removeIndex:anIndex];
							errors++;
						} else {
							affectedRows++;
						}
					} else {
						if(!reloadAfterRemovingRow)
							[selectedRows removeIndex:anIndex];
						errors++;
					}
					anIndex = [selectedRows indexGreaterThanIndex:anIndex];
				}
			} else if ([primaryKeyFieldNames count] == 1) {
				// if table has only one PRIMARY KEY
				// delete the fast way by using the PRIMARY KEY in an IN clause
				NSMutableString *deleteQuery = [NSMutableString string];

				[deleteQuery setString:[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ IN (", [selectedTable backtickQuotedString], [NSArrayObjectAtIndex(primaryKeyFieldNames,0) backtickQuotedString]]];

				while (anIndex != NSNotFound) {

					id keyValue = [tableValues cellDataAtRow:anIndex column:[[[tableDataInstance columnWithName:NSArrayObjectAtIndex(primaryKeyFieldNames,0)] objectForKey:@"datacolumnindex"] integerValue]];

					if([keyValue isKindOfClass:[NSData class]])
						[deleteQuery appendString:[mySQLConnection escapeAndQuoteData:keyValue]];
					else
						[deleteQuery appendString:[mySQLConnection escapeAndQuoteString:[keyValue description]]];

					// Split deletion query into 256k chunks
					if([deleteQuery length] > 256000) {
						[deleteQuery appendString:@")"];
						[mySQLConnection queryString:deleteQuery];

						// Remember affected rows for error checking
						affectedRows += (NSInteger)[mySQLConnection rowsAffectedByLastQuery];

						// Reinit a new deletion query
						[deleteQuery setString:[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ IN (", [selectedTable backtickQuotedString], [NSArrayObjectAtIndex(primaryKeyFieldNames,0) backtickQuotedString]]];
					} else {
						[deleteQuery appendString:@","];
					}

					anIndex = [selectedRows indexGreaterThanIndex:anIndex];
				}

				// Check if deleteQuery's maximal length was reached for the last index
				// if yes omit the empty query
				if(![deleteQuery hasSuffix:@"("]) {
					// Replace final , by ) and delete the remaining rows
					[deleteQuery setString:[NSString stringWithFormat:@"%@)", [deleteQuery substringToIndex:([deleteQuery length]-1)]]];
					[mySQLConnection queryString:deleteQuery];

					// Remember affected rows for error checking
					affectedRows += (NSInteger)[mySQLConnection rowsAffectedByLastQuery];
				}

				errors = (affectedRows > 0) ? [selectedRows count] - affectedRows : [selectedRows count];
			} 
			else {
				// if table has more than one PRIMARY KEY
				// delete the row by using all PRIMARY KEYs in an OR clause
				NSMutableString *deleteQuery = [NSMutableString string];

				[deleteQuery setString:[NSString stringWithFormat:@"DELETE FROM %@ WHERE ", [selectedTable backtickQuotedString]]];

				while (anIndex != NSNotFound) {

					// Build the AND clause of PRIMARY KEYS
					NSString *whereArg = [self argumentForRow:anIndex excludingLimits:YES];
					if(![whereArg length]) {
						SPLog(@"empty WHERE clause not acceptable for DELETE! Abort.");
						NSBeep();
						return;
					}
					
					[deleteQuery appendFormat:@"(%@)",whereArg];

					// Split deletion query into 64k chunks
					if([deleteQuery length] > 64000) {
						[mySQLConnection queryString:deleteQuery];

						// Remember affected rows for error checking
						affectedRows += (NSInteger)[mySQLConnection rowsAffectedByLastQuery];

						// Reinit a new deletion query
						[deleteQuery setString:[NSString stringWithFormat:@"DELETE FROM %@ WHERE ", [selectedTable backtickQuotedString]]];
					} else {
						[deleteQuery appendString:@" OR "];
					}

					anIndex = [selectedRows indexGreaterThanIndex:anIndex];
				}

				// Check if deleteQuery's maximal length was reached for the last index
				// if yes omit the empty query
				if(![deleteQuery hasSuffix:@"WHERE "]) {

					// Remove final ' OR ' and delete the remaining rows
					[deleteQuery setString:[deleteQuery substringToIndex:([deleteQuery length]-4)]];
					[mySQLConnection queryString:deleteQuery];

					// Remember affected rows for error checking
					affectedRows += (NSInteger)[mySQLConnection rowsAffectedByLastQuery];
				}

				errors = (affectedRows > 0) ? [selectedRows count] - affectedRows : [selectedRows count];
			}

			// Restore Console Log window's updating bahaviour
			[[SPQueryController sharedQueryController] setAllowConsoleUpdate:consoleUpdateStatus];

			if (errors) {
				NSMutableString *messageText = [NSMutableString stringWithCapacity:50];
				NSString *messageTitle = NSLocalizedString(@"Unexpected number of rows removed!", @"Table Content : Remove Row : Result : n Error title");
								
				if (errors < 0) {
					long numErrors = (long)(errors *- 1);
					if(numErrors == 1)
						[messageText appendString:NSLocalizedString(@"One additional row was removed!",@"Table Content : Remove Row : Result : Too Many : Part 1 : n+1 rows instead of n selected were deleted.")];
					else
						 [messageText appendFormat:NSLocalizedString(@"%ld additional rows were removed!",@"Table Content : Remove Row : Result : Too Many : Part 1 : n+y (y!=1) rows instead of n selected were deleted."),numErrors];
					
					[messageText appendString:NSLocalizedString(@" Please check the Console and inform the Sequel Pro team!",@"Table Content : Remove Row : Result : Too Many : Part 2 : Generic text")];
					
				}
				else {
					//part 1 number of rows not deleted
					if(errors == 1)
						[messageText appendString:NSLocalizedString(@"One row was not removed.",@"Table Content : Remove Row : Result : Too Few : Part 1 : Only n-1 of n selected rows were deleted.")];
					else
						[messageText appendFormat:NSLocalizedString(@"%ld rows were not removed.",@"Table Content : Remove Row : Result : Too Few : Part 1 : n-x (x!=1) of n selected rows were deleted."),errors];
					//part 2 generic help text
					[messageText appendString:NSLocalizedString(@" Reload the table to be sure that the contents have not changed in the meantime.",@"Table Content : Remove Row : Result : Too Few : Part 2 : Generic help message")];
					//part 3 primary keys
					if (primaryKeyFieldNames == nil)
						[messageText appendString:NSLocalizedString(@" You should also add a primary key to this table!",@"Table Content : Remove Row : Result : Too Few : Part 3 : no primary key in table generic message")];
					else
						[messageText appendString:NSLocalizedString(@" Check the Console for possible errors inside the primary key(s) of this table!",@"Table Content : Remove Row : Result : Too Few : Part 3 : Row not deleted when using primary key for DELETE statement.")];
				}

				[self performSelector:@selector(showErrorSheetWith:)
						   withObject:[NSArray arrayWithObjects:messageTitle,messageText,nil]
						   afterDelay:0.3];
			}

			// Refresh table content
			if (errors || reloadAfterRemovingRow) {
				previousTableRowsCount = tableRowsCount;
				[self loadTableValues];
			} 
			else {
				for ( i = tableRowsCount - 1; i >= 0; i--) 
				{
					if ([selectedRows containsIndex:i]) [tableValues removeRowAtIndex:i];
				}
				
				tableRowsCount = [tableValues count];
				[tableContentView reloadData];

				// Update the maximum number of rows and the count text
				maxNumRows -= affectedRows;
				[self updateCountText];
			}
			
			[tableContentView deselectAll:self];
		}
	}
}


#pragma mark -
#pragma mark Data accessors

/**
 * Returns the current result (as shown in table content view) as array, the first object containing the field
 * names as array, the following objects containing the rows as array.
 */
- (NSArray *)currentResult
{
	NSInteger i;
	NSArray *tableColumns;
	NSMutableArray *currentResult = [NSMutableArray array];
	NSMutableArray *tempRow = [NSMutableArray array];
	
	// Load the table if not already loaded
	if (![tableDocumentInstance contentLoaded]) {
		[self loadTable:[tableDocumentInstance table]];
	}
	
	tableColumns = [tableContentView tableColumns];
	
	// Add the field names as the first line
	for (NSTableColumn *tableColumn in tableColumns) 
	{
		[tempRow addObject:[[tableColumn headerCell] stringValue]];
	}
	
	[currentResult addObject:[NSArray arrayWithArray:tempRow]];
	
	// Add the rows
	for (i = 0 ; i < [self numberOfRowsInTableView:tableContentView]; i++) 
	{
		[tempRow removeAllObjects];
		
		for (NSTableColumn *tableColumn in tableColumns) 
		{
			[tempRow addObject:[self _contentValueForTableColumn:[[tableColumn identifier] integerValue] row:i asPreview:NO]];
		}
		
		[currentResult addObject:[NSArray arrayWithArray:tempRow]];
	}
	
	return currentResult;
}

/**
 * Returns the current result (as shown in table content view) as array, the first object containing the field
 * names as array, the following objects containing the rows as array.
 */ 
- (NSArray *)currentDataResultWithNULLs:(BOOL)includeNULLs hideBLOBs:(BOOL)hide hexBLOBs:(BOOL)hexBLOBs
{
	NSInteger i;
	NSArray *tableColumns;
	NSMutableArray *currentResult = [NSMutableArray array];
	NSMutableArray *tempRow = [NSMutableArray array];

	// Load table if not already done
	if (![tableDocumentInstance contentLoaded]) {
		[self loadTable:[tableDocumentInstance table]];
	}

	tableColumns = [tableContentView tableColumns];

	// Set field names as first line
	for (NSTableColumn *aTableColumn in tableColumns) 
	{
		[tempRow addObject:[[aTableColumn headerCell] stringValue]];
	}
	
	[currentResult addObject:[NSArray arrayWithArray:tempRow]];

	// Add rows
	for (i = 0; i < [self numberOfRowsInTableView:tableContentView]; i++) 
	{
		[tempRow removeAllObjects];
		
		for (NSTableColumn *aTableColumn in tableColumns) 
		{
			id o = SPDataStorageObjectAtRowAndColumn(tableValues, i, [[aTableColumn identifier] integerValue]);
			
			if ([o isNSNull]) {
				[tempRow addObject:includeNULLs ? [NSNull null] : [prefs objectForKey:SPNullValue]];
			}
			else if ([o isSPNotLoaded]) {
				[tempRow addObject:NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields")];
			}
			else if([o isKindOfClass:[NSString class]]) {
				[tempRow addObject:[o description]];
			}
			else if([o isKindOfClass:[SPMySQLGeometryData class]]) {
				SPGeometryDataView *v = [[SPGeometryDataView alloc] initWithCoordinates:[o coordinates]];
				NSImage *image = [v thumbnailImage];
				NSString *imageStr = @"";
				
				if(image) {
					NSString *maxSizeValue = @"WIDTH";
					NSInteger imageWidth = [image size].width;
					NSInteger imageHeight = [image size].height;
					
					if(imageHeight > imageWidth) {
						maxSizeValue = @"HEIGHT";
						imageWidth = imageHeight;
					}
					
					if (imageWidth > 100) imageWidth = 100;
					
					imageStr = [NSString stringWithFormat:
					@"<BR><IMG %@='%ld' SRC=\"data:image/auto;base64,%@\">",
						maxSizeValue,
						(long)imageWidth,
						[[image TIFFRepresentationUsingCompression:NSTIFFCompressionJPEG factor:0.01f] base64Encoding]];
				}
				
				[v release];
				[tempRow addObject:[NSString stringWithFormat:@"%@%@", [o wktString], imageStr]];
			}
			else {
				NSImage *image = [[NSImage alloc] initWithData:o];
				
				if (image) {
					NSInteger imageWidth = [image size].width;
					
					if (imageWidth > 100) imageWidth = 100;
					[tempRow addObject:[NSString stringWithFormat:
						@"<IMG WIDTH='%ld' SRC=\"data:image/auto;base64,%@\">",
						(long)imageWidth,
						[[image TIFFRepresentationUsingCompression:NSTIFFCompressionJPEG factor:0.01f] base64Encoding]]];
				} 
				else {
					NSString *str;
					if (hide)
						str = @"&lt;BLOB&gt;";
					else if (hexBLOBs) {
						str = [o dataToHexString];
					}
					else {
						str = [o stringRepresentationUsingEncoding:[mySQLConnection stringEncoding]];
					}
					[tempRow addObject: str];
				}
				
				if(image) [image release];
			}
		}
		
		[currentResult addObject:[NSArray arrayWithArray:tempRow]];
	}
	
	return currentResult;
}

#pragma mark -

/**
 * Sets the connection (received from SPDatabaseDocument) and makes things that have to be done only once
 */
- (void)setConnection:(SPMySQLConnection *)theConnection
{
	mySQLConnection = theConnection;

	[tableContentView setVerticalMotionCanBeginDrag:NO];
}

/**
 * Performs the requested action - switching to another table
 * with the appropriate filter settings - when a link arrow is
 * selected.
 */
- (void)clickLinkArrow:(SPTextAndLinkCell *)theArrowCell
{
	if ([tableDocumentInstance isWorking]) return;

	if ([theArrowCell getClickedColumn] == NSNotFound || [theArrowCell getClickedRow] == NSNotFound) return;

	// Check whether a save of the current row is required.
	if ( ![self saveRowOnDeselect] ) return;

	// If on the main thread, fire up a thread to perform the load while keeping the modification flag
	[tableDocumentInstance startTaskWithDescription:NSLocalizedString(@"Loading reference...", @"Loading referece task string")];
	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadWithName:SPCtxt(@"SPTableContent linked data load task", tableDocumentInstance) target:self selector:@selector(clickLinkArrowTask:) object:theArrowCell];
	} else {
		[self clickLinkArrowTask:theArrowCell];
	}
}

- (void)clickLinkArrowTask:(SPTextAndLinkCell *)theArrowCell
{
	NSAutoreleasePool *linkPool = [[NSAutoreleasePool alloc] init];
	NSUInteger dataColumnIndex = [[[[tableContentView tableColumns] objectAtIndex:[theArrowCell getClickedColumn]] identifier] integerValue];
	BOOL tableFilterRequired = NO;

	// Ensure the clicked cell has foreign key details available
	NSDictionary *columnDefinition = [dataColumns objectAtIndex:dataColumnIndex];
	NSDictionary *refDictionary = [columnDefinition objectForKey:@"foreignkeyreference"];
	if (!refDictionary) {
		[linkPool release];
		return;
	}

#ifndef SP_CODA
	// Save existing scroll position and details and mark that state is being modified
	[spHistoryControllerInstance updateHistoryEntries];
	[spHistoryControllerInstance setModifyingState:YES];
#endif

	NSString *targetFilterValue = [tableValues cellDataAtRow:[theArrowCell getClickedRow] column:dataColumnIndex];

	//when navigating binary relations (eg. raw UUID) do so via a hex-encoded value for charset safety
	BOOL navigateAsHex = ([targetFilterValue isKindOfClass:[NSData class]] && [[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"binary"]);
	if(navigateAsHex) targetFilterValue = [mySQLConnection escapeData:(NSData *)targetFilterValue includingQuotes:NO];
	
	// If the link is within the current table, apply filter settings manually
	if ([[refDictionary objectForKey:@"table"] isEqualToString:selectedTable]) {
		SPMainQSync(^{
			[fieldField selectItemWithTitle:[refDictionary objectForKey:@"column"]];
			[self setCompareTypes:self];
			if ([targetFilterValue isNSNull]) {
				[compareField selectItemWithTitle:@"IS NULL"];
			}
			else {
				if(navigateAsHex) [compareField selectItemWithTitle:@"= (Hex String)"];
				[argumentField setStringValue:targetFilterValue];
			}
		});
		tableFilterRequired = YES;
	} else {
		NSString *filterComparison = nil;
		if([targetFilterValue isNSNull]) filterComparison = @"IS NULL";
		else if(navigateAsHex) filterComparison = @"= (Hex String)";
		
		// Store the filter details to use when loading the target table
		NSDictionary *filterSettings = @{
			@"filterField": [refDictionary objectForKey:@"column"],
			@"filterValue": targetFilterValue,
			@"filterComparison": SPBoxNil(filterComparison)
		};
		SPMainQSync(^{
			[self setFiltersToRestore:filterSettings];
			
			// Attempt to switch to the target table
			if (![tablesListInstance selectItemWithName:[refDictionary objectForKey:@"table"]]) {
				NSBeep();
				[self setFiltersToRestore:nil];
			}
		});
	}

#ifndef SP_CODA
	// End state and ensure a new history entry
	[spHistoryControllerInstance setModifyingState:NO];
	[spHistoryControllerInstance updateHistoryEntries];
#endif

	// End the task
	[tableDocumentInstance endTask];

#ifndef SP_CODA
	// If the same table is the target, trigger a filter task on the main thread
	if (tableFilterRequired)
		[self performSelectorOnMainThread:@selector(filterTable:) withObject:self waitUntilDone:NO];
#endif

	// Empty the loading pool and exit the thread
	[linkPool drain];
}

/**
 * Sets the compare types for the filter and the appropriate formatter for the textField
 */
- (IBAction)setCompareTypes:(id)sender
{

	if(contentFilters == nil
		|| ![contentFilters objectForKey:@"number"]
		|| ![contentFilters objectForKey:@"string"]
		|| ![contentFilters objectForKey:@"date"]) {
		NSLog(@"Error while setting filter types.");
		NSBeep();
		return;
	}

	// Retrieve the current field comparison setting for later restoration if possible
	NSString *titleToRestore = [[compareField selectedItem] title];

	// Reset the menu before building it back up
	[compareField removeAllItems];

	NSString *fieldTypeGrouping;
	if([[tableDataInstance columnWithName:[fieldField titleOfSelectedItem]] objectForKey:@"typegrouping"])
		fieldTypeGrouping = [NSString stringWithString:[[tableDataInstance columnWithName:[fieldField titleOfSelectedItem]] objectForKey:@"typegrouping"]];
	else
		return;

	if ( [fieldTypeGrouping isEqualToString:@"date"] ) {
		compareType = @"date";

		/*
		 if ([fieldType isEqualToString:@"timestamp"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc]
		 initWithDateFormat:@"%Y-%m-%d %H:%M:%S" allowNaturalLanguage:YES]];
		 }
		 if ([fieldType isEqualToString:@"datetime"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%Y-%m-%d %H:%M:%S" allowNaturalLanguage:YES]];
		 }
		 if ([fieldType isEqualToString:@"date"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%Y-%m-%d" allowNaturalLanguage:YES]];
		 }
		 if ([fieldType isEqualToString:@"time"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%H:%M:%S" allowNaturalLanguage:YES]];
		 }
		 if ([fieldType isEqualToString:@"year"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%Y" allowNaturalLanguage:YES]];
		 }
		 */

	// TODO: A bug in the framework previously meant enum fields had to be treated as string fields for the purposes
	// of comparison - this can now be split out to support additional comparison fucntionality if desired.
	} else if ([fieldTypeGrouping isEqualToString:@"string"]   || [fieldTypeGrouping isEqualToString:@"binary"]
			|| [fieldTypeGrouping isEqualToString:@"textdata"] || [fieldTypeGrouping isEqualToString:@"blobdata"]
			|| [fieldTypeGrouping isEqualToString:@"enum"]) {

		compareType = @"string";
		// [argumentField setFormatter:nil];

	} else if ([fieldTypeGrouping isEqualToString:@"bit"] || [fieldTypeGrouping isEqualToString:@"integer"]
				|| [fieldTypeGrouping isEqualToString:@"float"]) {
		compareType = @"number";
		// [argumentField setFormatter:numberFormatter];

	} else if ([fieldTypeGrouping isEqualToString:@"geometry"]) {
		compareType = @"spatial";

	} else  {
		compareType = @"";
		NSBeep();
		NSLog(@"ERROR: unknown type for comparision: %@, in %@", [[tableDataInstance columnWithName:[fieldField titleOfSelectedItem]] objectForKey:@"type"], fieldTypeGrouping);
	}

	// Add IS NULL and IS NOT NULL as they should always be available
	// [compareField addItemWithTitle:@"IS NULL"];
	// [compareField addItemWithTitle:@"IS NOT NULL"];

	// Remove user-defined filters first
	if([numberOfDefaultFilters objectForKey:compareType]) {
		NSUInteger cycles = [[contentFilters objectForKey:compareType] count] - [[numberOfDefaultFilters objectForKey:compareType] integerValue];
		while(cycles > 0) {
			[[contentFilters objectForKey:compareType] removeLastObject];
			cycles--;
		}
	}

#ifndef SP_CODA /* content filters */
	// Load global user-defined content filters
	if([prefs objectForKey:SPContentFilters]
		&& [contentFilters objectForKey:compareType]
		&& [[prefs objectForKey:SPContentFilters] objectForKey:compareType])
	{
		[[contentFilters objectForKey:compareType] addObjectsFromArray:[[prefs objectForKey:SPContentFilters] objectForKey:compareType]];
	}

	// Load doc-based user-defined content filters
	if([[SPQueryController sharedQueryController] contentFilterForFileURL:[tableDocumentInstance fileURL]]) {
		id filters = [[SPQueryController sharedQueryController] contentFilterForFileURL:[tableDocumentInstance fileURL]];
		if([filters objectForKey:compareType])
			[[contentFilters objectForKey:compareType] addObjectsFromArray:[filters objectForKey:compareType]];
	}
#endif

	// Rebuild operator popup menu
	NSUInteger i = 0;
	NSMenu *menu = [compareField menu];
	if([contentFilters objectForKey:compareType])
		for(id filter in [contentFilters objectForKey:compareType]) {
			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:([filter objectForKey:@"MenuLabel"])?[filter objectForKey:@"MenuLabel"]:@"not specified" action:NULL keyEquivalent:@""];
			// Create the tooltip
			if([filter objectForKey:@"Tooltip"])
				[item setToolTip:[filter objectForKey:@"Tooltip"]];
			else {
				NSMutableString *tip = [[NSMutableString alloc] init];
				if([filter objectForKey:@"Clause"] && [(NSString *)[filter objectForKey:@"Clause"] length]) {
					[tip setString:[[filter objectForKey:@"Clause"] stringByReplacingOccurrencesOfRegex:@"(?<!\\\\)(\\$\\{.*?\\})" withString:@"[arg]"]];
					if([tip isMatchedByRegex:@"(?<!\\\\)\\$BINARY"]) {
						[tip replaceOccurrencesOfRegex:@"(?<!\\\\)\\$BINARY" withString:@""];
						[tip appendString:NSLocalizedString(@"\n\nPress ⇧ for binary search (case-sensitive).", @"\n\npress shift for binary search tooltip message")];
					}
					[tip flushCachedRegexData];
					[tip replaceOccurrencesOfRegex:@"(?<!\\\\)\\$CURRENT_FIELD" withString:[[fieldField titleOfSelectedItem] backtickQuotedString]];
					[tip flushCachedRegexData];
					[item setToolTip:tip];
				} else {
					[item setToolTip:@""];
				}
				[tip release];
			}
			[item setTag:i];
			[menu addItem:item];
			[item release];
			i++;
		}

#ifndef SP_CODA
	[menu addItem:[NSMenuItem separatorItem]];
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Edit Filters…", @"edit filter") action:NULL keyEquivalent:@""];
	[item setToolTip:NSLocalizedString(@"Edit user-defined Filters…", @"edit user-defined filter")];
	[item setTag:i];
	[menu addItem:item];
	[item release];
#endif

	// Attempt to reselect the previously selected title, falling back to the first
	// item on failure, as long as there is no filter selection to be restored.
	if (!filterFieldToRestore) {
		[compareField selectItemWithTitle:titleToRestore];
		if (![compareField selectedItem]) [compareField selectItemAtIndex:0];
	}

	// Update the argumentField enabled state
	[self performSelectorOnMainThread:@selector(toggleFilterField:) withObject:self waitUntilDone:YES];

	// set focus on argumentField
	[argumentField performSelectorOnMainThread:@selector(selectText:) withObject:self waitUntilDone:YES];

}

- (void)openContentFilterManager
{
	[compareField selectItemWithTag:lastSelectedContentFilterIndex];

	// init query favorites controller
#ifndef SP_CODA
	[prefs synchronize];
#endif
	if(contentFilterManager) [contentFilterManager release];
	contentFilterManager = [[SPContentFilterManager alloc] initWithDelegate:self forFilterType:compareType];

	// Open query favorite manager
	[NSApp beginSheet:[contentFilterManager window]
	   modalForWindow:[tableDocumentInstance parentWindow]
		modalDelegate:contentFilterManager
	   didEndSelector:nil
		  contextInfo:nil];
}

/**
 * Tries to write a new row to the table.
 * Returns YES if row is written to table, otherwise NO; also returns YES if no row
 * is being edited or nothing has to be written to the table.
 */
- (BOOL)saveRowToTable
{
	// Only handle tables - views should be handled per-cell.
	if ([tablesListInstance tableType] == SPTableTypeView) return NO;

	// If no row is being edited, return success.
	if (!isEditingRow) return YES;

	// If editing, quickly compare the new row to the old row and if they are identical finish editing without saving.
	if (!isEditingNewRow && [oldRow isEqualToArray:[tableValues rowContentsAtIndex:currentlyEditingRow]]) {
		isEditingRow = NO;
		currentlyEditingRow = -1;
		return YES;
	}

	// Iterate through the row contents, constructing the (ordered) arrays of keys and values to be saved
	NSMutableArray *rowFieldsToSave = [[NSMutableArray alloc] initWithCapacity:[dataColumns count]];
	NSMutableArray *rowValuesToSave = [[NSMutableArray alloc] initWithCapacity:[dataColumns count]];
	NSUInteger i;
	NSDictionary *fieldDefinition;
	id rowObject;
	
	for (i = 0; i < [dataColumns count]; i++) 
	{
		rowObject = [tableValues cellDataAtRow:currentlyEditingRow column:i];
		fieldDefinition = NSArrayObjectAtIndex(dataColumns, i);

		// Skip "not loaded" cells entirely - these only occur when editing tables when the
		// preference setting is enabled, and don't need to be saved back to the table.
		if ([rowObject isSPNotLoaded]) continue;

		// If an edit has taken place, and the field value hasn't changed, the value
		// can also be skipped
		if (!isEditingNewRow && [rowObject isEqual:NSArrayObjectAtIndex(oldRow, i)]) continue;

		// Prepare to derive the value to save
		NSString *fieldValue;
		NSString *fieldTypeGroup = [fieldDefinition objectForKey:@"typegrouping"];

		// Use NULL when the user has entered the nullValue string defined in the preferences,
		// or when a numeric  or date field is empty.
		if ([rowObject isNSNull]
			|| (([fieldTypeGroup isEqualToString:@"float"] || [fieldTypeGroup isEqualToString:@"integer"] || [fieldTypeGroup isEqualToString:@"date"])
				&& [[rowObject description] isEqualToString:@""] && [[fieldDefinition objectForKey:@"null"] boolValue]))
		{
			fieldValue = @"NULL";

		// Convert geometry values to their string values
		} else if ([fieldTypeGroup isEqualToString:@"geometry"]) {
			fieldValue = ([rowObject isKindOfClass:[SPMySQLGeometryData class]]) ? [[rowObject wktString] getGeomFromTextString] : [(NSString*)rowObject getGeomFromTextString];
	
		// Convert the object to a string (here we can add special treatment for date-, number- and data-fields)
		} else {

			// I believe these class matches are not ever met at present.
			if ([rowObject isKindOfClass:[NSCalendarDate class]]) {
				fieldValue = [mySQLConnection escapeAndQuoteString:[rowObject description]];
			} else if ([rowObject isKindOfClass:[NSNumber class]]) {
				fieldValue = [rowObject stringValue];

			// Convert data to its hex representation
			} else if ([rowObject isKindOfClass:[NSData class]]) {
				fieldValue = [mySQLConnection escapeAndQuoteData:rowObject];

			} else {
				NSString *desc = [rowObject description];
				if ([desc isMatchedByRegex:SPCurrentTimestampPattern]) {
					fieldValue = desc;
				} else if ([fieldTypeGroup isEqualToString:@"bit"]) {
					fieldValue = [NSString stringWithFormat:@"b'%@'", ((![desc length] || [desc isEqualToString:@"0"]) ? @"0" : desc)];
				} else if ([fieldTypeGroup isEqualToString:@"date"] && [desc isEqualToString:@"NOW()"]) {
					fieldValue = @"NOW()";
               } else if ([fieldTypeGroup isEqualToString:@"string"] && [[rowObject description] isEqualToString:@"UUID()"]) {
                   fieldValue = @"UUID()";
				} else {
					fieldValue = [mySQLConnection escapeAndQuoteString:desc];
				}
			}
		}

		// Store the key and value in the ordered arrays for saving.
		[rowFieldsToSave addObject:[fieldDefinition objectForKey:@"name"]];
		[rowValuesToSave addObject:fieldValue];
	}

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryWillBePerformed" object:tableDocumentInstance];

	NSMutableString *queryString;

	// Use INSERT syntax when creating new rows
	if (isEditingNewRow) {
		queryString = [NSMutableString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)",
					   [selectedTable backtickQuotedString], [rowFieldsToSave componentsJoinedAndBacktickQuoted], [rowValuesToSave componentsJoinedByString:@", "]];

	// Otherwise use an UPDATE syntax to save only the changed cells - if this point is reached,
	// the equality test has failed and so there is always at least one changed cell
	} else {
		queryString = [NSMutableString stringWithFormat:@"UPDATE %@ SET ", [selectedTable backtickQuotedString]];
		for (i = 0; i < [rowFieldsToSave count]; i++) {
			if (i) [queryString appendString:@", "];
			[queryString appendFormat:@"%@ = %@",
									   [NSArrayObjectAtIndex(rowFieldsToSave, i) backtickQuotedString], NSArrayObjectAtIndex(rowValuesToSave, i)];
		}
		NSString *whereArg = [self argumentForRow:-2];
		if(![whereArg length]) {
			SPLog(@"Did not find plausible WHERE condition for UPDATE.");
			NSBeep();
			[rowFieldsToSave release];
			[rowValuesToSave release];
			return NO;
		}
		[queryString appendFormat:@" WHERE %@", whereArg];
	}

	[rowFieldsToSave release];
	[rowValuesToSave release];

	// Run the query
	[mySQLConnection queryString:queryString];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];

	// If no rows have been changed, show error if appropriate.
	if ( ![mySQLConnection rowsAffectedByLastQuery] && ![mySQLConnection queryErrored] ) {
#ifndef SP_CODA
		if ( [prefs boolForKey:SPShowNoAffectedRowsError] ) {
			SPOnewayAlertSheet(
				NSLocalizedString(@"Warning", @"warning"),
				[tableDocumentInstance parentWindow],
				NSLocalizedString(@"The row was not written to the MySQL database. You probably haven't changed anything.\nReload the table to be sure that the row exists and use a primary key for your table.\n(This error can be turned off in the preferences.)", @"message of panel when no rows have been affected after writing to the db")
			);
		} else {
			NSBeep();
		}
#endif

		// If creating a new row, remove the row; otherwise revert the row contents
		if (isEditingNewRow) {
			tableRowsCount--;
			[tableValues removeRowAtIndex:currentlyEditingRow];
			[self updateCountText];
			isEditingNewRow = NO;
		}
		else {
			[tableValues replaceRowAtIndex:currentlyEditingRow withRowContents:oldRow];
		}

		isEditingRow = NO;
		currentlyEditingRow = -1;
		[tableContentView reloadData];

		[[SPQueryController sharedQueryController] showErrorInConsole:NSLocalizedString(@"/* WARNING: No rows have been affected */\n", @"warning shown in the console when no rows have been affected after writing to the db") connection:[tableDocumentInstance name] database:[tableDocumentInstance database]];

		return YES;

	// On success...
	} else if ( ![mySQLConnection queryErrored] ) {
		isEditingRow = NO;

		// New row created successfully
		if ( isEditingNewRow ) {
#ifndef SP_CODA
			if ( [prefs boolForKey:SPReloadAfterAddingRow] ) {

				// Save any edits which have been started but not saved to the underlying table/data structures
				// yet - but not if currently undoing/redoing, as this can cause a processing loop
				if (![[[[tableContentView window] firstResponder] undoManager] isUndoing] && ![[[[tableContentView window] firstResponder] undoManager] isRedoing]) {
				[[tableDocumentInstance parentWindow] endEditingFor:nil];
				}

				previousTableRowsCount = tableRowsCount;
				[self loadTableValues];
			} 
			else {
#endif
				// Set the insertId for fields with auto_increment
				for ( i = 0; i < [dataColumns count] ; i++ ) {
					if ([[NSArrayObjectAtIndex(dataColumns, i) objectForKey:@"autoincrement"] integerValue]) {
						[tableValues replaceObjectInRow:currentlyEditingRow column:i withObject:[[NSNumber numberWithUnsignedLongLong:[mySQLConnection lastInsertID]] description]];
					}
				}
#ifndef SP_CODA
			}
#endif
			isEditingNewRow = NO;

		// Existing row edited successfully
		} else {

			// Reload table if set to - otherwise no action required.
#ifndef SP_CODA
			if ([prefs boolForKey:SPReloadAfterEditingRow]) {

				// Save any edits which have been started but not saved to the underlying table/data structures
				// yet - but not if currently undoing/redoing, as this can cause a processing loop
				if (![[[[tableContentView window] firstResponder] undoManager] isUndoing] && ![[[[tableContentView window] firstResponder] undoManager] isRedoing]) {
				[[tableDocumentInstance parentWindow] endEditingFor:nil];
				}

				previousTableRowsCount = tableRowsCount;
				[self loadTableValues];
			}
#endif
		}
		currentlyEditingRow = -1;

		return YES;

	// Report errors which have occurred
	} 
	else {
		SPBeginAlertSheet(NSLocalizedString(@"Unable to write row", @"Unable to write row error"), NSLocalizedString(@"Edit row", @"Edit row button"), NSLocalizedString(@"Discard changes", @"discard changes button"), nil, [tableDocumentInstance parentWindow], self, @selector(addRowErrorSheetDidEnd:returnCode:contextInfo:), NULL,
						  [NSString stringWithFormat:NSLocalizedString(@"MySQL said:\n\n%@", @"message of panel when error while adding row to db"), [mySQLConnection lastErrorMessage]]);
		return NO;
	}
}

/**
 * Handle the user decision as a result of an addRow error.
 */
- (void) addRowErrorSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	// Order out current sheet to suppress overlapping of sheets
	[[alert window] orderOut:nil];

	// Edit row selected - reselect the row, and start editing.
	if ( returnCode == NSAlertDefaultReturn ) {
		[tableContentView selectRowIndexes:[NSIndexSet indexSetWithIndex:currentlyEditingRow] byExtendingSelection:NO];
		[tableContentView performSelector:@selector(keyDown:) withObject:[NSEvent keyEventWithType:NSKeyDown location:NSMakePoint(0,0) modifierFlags:0 timestamp:0 windowNumber:[[tableContentView window] windowNumber] context:[NSGraphicsContext currentContext] characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:0x24] afterDelay:0.0];

	} 
	else {
	// Discard changes selected
		[self cancelRowEditing];
	}
	
	[tableContentView reloadData];
}

/**
 * A method to be called whenever the table selection changes; checks whether the current
 * row is being edited, and if so attempts to save it.  Returns YES if no save was necessary
 * or the save was successful, and NO if a save was necessary and failed - in which case further
 * editing is required.  In that case this method will reselect the row in question for reediting.
 */
- (BOOL)saveRowOnDeselect
{
	if ([tablesListInstance tableType] == SPTableTypeView) {
		isSavingRow = NO;
		return YES;
	}

	// Save any edits which have been started but not saved to the underlying table/data structures
	// yet - but not if currently undoing/redoing, as this can cause a processing loop
	if (![[[[tableContentView window] firstResponder] undoManager] isUndoing] && ![[[[tableContentView window] firstResponder] undoManager] isRedoing]) {
		[[tableDocumentInstance parentWindow] endEditingFor:nil];
	}

	// If no rows are currently being edited, or a save is in progress, return success at once.
	if (!isEditingRow || isSavingRow) return YES;
	
	isSavingRow = YES;

	// Attempt to save the row, and return YES if the save succeeded.
	if ([self saveRowToTable]) {
		isSavingRow = NO;
		return YES;
	}

	// Saving failed - return failure.
	isSavingRow = NO;
	
	return NO;
}

/**
 * Cancel active row editing, replacing the previous row if there was one
 * and resetting state.
 * Returns whether row editing was cancelled.
 */
- (BOOL)cancelRowEditing
{
	[[tableContentView window] makeFirstResponder:tableContentView];

	if (!isEditingRow) return NO;
	if (isEditingNewRow) {
		tableRowsCount--;
		[tableValues removeRowAtIndex:currentlyEditingRow];
		[self updateCountText];
		isEditingNewRow = NO;
	} else {
		[tableValues replaceRowAtIndex:currentlyEditingRow withRowContents:oldRow];
	}
	isEditingRow = NO;
	currentlyEditingRow = -1;
	[tableContentView reloadData];
	[[tableContentView window] makeFirstResponder:tableContentView];
	return YES;
}

/**
 * Returns the WHERE argument to identify a row.
 * If "row" is -2, it uses the oldRow.
 * Uses the primary key if available, otherwise uses all fields as argument and sets LIMIT to 1
 */
- (NSString *)argumentForRow:(NSInteger)row
{
	return [self argumentForRow:row excludingLimits:NO];
}

/**
 * Returns the WHERE argument to identify a row.
 * If "row" is -2, it uses the oldRow value.
 * "excludeLimits" controls whether a LIMIT 1 is appended if no primary key was available to
 * uniquely identify the row.
 */
- (NSString *)argumentForRow:(NSInteger)row excludingLimits:(BOOL)excludeLimits
{
	if ( row == -1 )
		return @"";

	// Retrieve the field names for this table from the data cache.  This is used when requesting all data as part
	// of the fieldListForQuery method, and also to decide whether or not to preserve the current filter/sort settings.
	NSArray *columnNames = [tableDataInstance columnNames];

	// Get the primary key if there is one
	if ( !keys ) {
		setLimit = NO;
		keys = [[NSMutableArray alloc] init];
		SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM %@", [selectedTable backtickQuotedString]]];
		if(!theResult) {
			SPLog(@"no result from SHOW COLUMNS mysql query! Abort.");
			return @"";
		}
		[theResult setReturnDataAsStrings:YES];
		for (NSDictionary *eachRow in theResult) {
			if ( [[eachRow objectForKey:@"Key"] isEqualToString:@"PRI"] ) {
				[keys addObject:[eachRow objectForKey:@"Field"]];
			}
		}
	}

	// If there is no primary key, all the fields are used in the argument.
	if ( ![keys count] ) {
		[keys setArray:columnNames];
		setLimit = YES;

		// When the option to not show blob or text options is set, we have a problem - we don't have
		// the right values to use in the WHERE statement.  Throw an error if this is the case.
#ifndef SP_CODA
		if ( [prefs boolForKey:SPLoadBlobsAsNeeded] && [self tableContainsBlobOrTextColumns] ) {
			SPOnewayAlertSheet(
				NSLocalizedString(@"Error", @"error"),
				[tableDocumentInstance parentWindow],
				NSLocalizedString(@"You can't hide blob and text fields when working with tables without index.", @"message of panel when trying to edit tables without index and with hidden blob/text fields")
			);
			[keys removeAllObjects];
			[tableContentView deselectAll:self];
			return @"";
		}
#endif
	}

	NSMutableString *argument = [NSMutableString string];
	// Walk through the keys list constructing the argument list
	for (NSUInteger i = 0 ; i < [keys count] ; i++ ) {
		if ( i )
			[argument appendString:@" AND "];

		id tempValue;
		// Use the selected row if appropriate
		if ( row >= 0 ) {
			tempValue = [tableValues cellDataAtRow:row column:[[[tableDataInstance columnWithName:NSArrayObjectAtIndex(keys, i)] objectForKey:@"datacolumnindex"] integerValue]];
		}
		// Otherwise use the oldRow
		else {
			tempValue = [oldRow objectAtIndex:[[[tableDataInstance columnWithName:NSArrayObjectAtIndex(keys, i)] objectForKey:@"datacolumnindex"] integerValue]];
		}

		if ([tempValue isNSNull]) {
			[argument appendFormat:@"%@ IS NULL", [NSArrayObjectAtIndex(keys, i) backtickQuotedString]];
		}
		else if ([tempValue isSPNotLoaded]) {
			SPLog(@"Exceptional case: SPNotLoaded object found! Abort.");
			return @"";
		}
		else {
			NSString *escVal;
			NSString *fmt = @"%@";
			// If the field is of type BIT then it needs a binary prefix
			if ([[[tableDataInstance columnWithName:NSArrayObjectAtIndex(keys, i)] objectForKey:@"type"] isEqualToString:@"BIT"]) {
				escVal = [mySQLConnection escapeString:tempValue includingQuotes:NO];
				fmt = @"b'%@'";
			}
			else if ([tempValue isKindOfClass:[SPMySQLGeometryData class]]) {
				escVal = [mySQLConnection escapeAndQuoteData:[tempValue data]];
			}
			// BLOB/TEXT data
			else if ([tempValue isKindOfClass:[NSData class]]) {
				escVal = [mySQLConnection escapeAndQuoteData:tempValue];
			}
			else {
				escVal = [mySQLConnection escapeAndQuoteString:tempValue];
			}
			
			if(!escVal) {
				SPLog(@"(row=%ld) nil value for key <%@> is invalid! Abort.",row,NSArrayObjectAtIndex(keys, i));
				return @"";
			}
			
			[argument appendFormat:@"%@ = %@", [NSArrayObjectAtIndex(keys, i) backtickQuotedString], [NSString stringWithFormat:fmt,escVal]];
		}
	}

	if (setLimit && !excludeLimits) [argument appendString:@" LIMIT 1"];

	return argument;
}


/**
 * Returns YES if the table contains any columns which are of any of the blob or text types,
 * NO otherwise.
 */
- (BOOL)tableContainsBlobOrTextColumns
{
	for (NSDictionary *column in dataColumns) {
		if ( [tableDataInstance columnIsBlobOrText:[column objectForKey:@"name"]] ) {
			return YES;
		}
	}

	return NO;
}

/**
 * Returns a string controlling which fields to retrieve for a query.  Returns * (all fields) if the preferences
 * option dontShowBlob isn't set; otherwise, returns a comma-separated list of all non-blob/text fields.
 */
- (NSString *)fieldListForQuery
{
#ifndef SP_CODA
	if (([prefs boolForKey:SPLoadBlobsAsNeeded]) && [dataColumns count]) {

		NSMutableArray *fields = [NSMutableArray arrayWithCapacity:[dataColumns count]];
		BOOL tableHasBlobs = NO;
		NSString *fieldName;

		for (NSDictionary* field in dataColumns)
			if (![tableDataInstance columnIsBlobOrText:fieldName = [field objectForKey:@"name"]] )
				[fields addObject:[fieldName backtickQuotedString]];
			else {
				// For blob/text fields, select a null placeholder so the column count is still correct
				[fields addObject:@"NULL"];
				tableHasBlobs = YES;
			}

		return (tableHasBlobs) ? [fields componentsJoinedByString:@", "] : @"*";

	}
#endif
		return @"*";

}

/**
 * Check if table cell is editable
 * Returns as array the minimum number of possible changes or
 * -1 if no table name can be found or multiple table origins
 * -2 for other errors
 * and the used WHERE clause to identify
 */
- (NSArray*)fieldEditStatusForRow:(NSInteger)rowIndex andColumn:(NSInteger)columnIndex
{

	// Retrieve the column defintion
	NSDictionary *columnDefinition = [NSDictionary dictionaryWithDictionary:[cqColumnDefinition objectAtIndex:[[[[tableContentView tableColumns] objectAtIndex:columnIndex] identifier] integerValue]]];

	if(!columnDefinition)
		return @[@(-2), @""];

	// Resolve the original table name for current column if AS was used
	NSString *tableForColumn = [columnDefinition objectForKey:@"org_table"];

	// Get the database name which the field belongs to
	NSString *dbForColumn = [columnDefinition objectForKey:@"db"];

	// No table/database name found indicates that the field's column contains data from more than one table as for UNION
	// or the field data are not bound to any table as in SELECT 1 or if column database is unset
	if(!tableForColumn || ![tableForColumn length] || !dbForColumn || ![dbForColumn length])
		return @[@(-1), @""];

	// if table and database name are given check if field can be identified unambiguously
	// first without blob data
	NSString *fieldIDQueryStr = [self argumentForRow:rowIndex ofTable:tableForColumn andDatabase:[columnDefinition objectForKey:@"db"] includeBlobs:NO];
	if(!fieldIDQueryStr)
		return @[@(-1), @""];

	[tableDocumentInstance startTaskWithDescription:NSLocalizedString(@"Checking field data for editing...", @"checking field data for editing task description")];

	// Actual check whether field can be identified bijectively
	SPMySQLResult *tempResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@.%@ %@",
		[[columnDefinition objectForKey:@"db"] backtickQuotedString],
		[tableForColumn backtickQuotedString],
		fieldIDQueryStr]];

	if ([mySQLConnection queryErrored]) {
		[tableDocumentInstance endTask];
		return @[@(-1), @""];
	}

	NSArray *tempRow = [tempResult getRowAsArray];

	if([tempRow count] && [[tempRow objectAtIndex:0] integerValue] > 1) {
		// try to identify the cell by using blob data
		fieldIDQueryStr = [self argumentForRow:rowIndex ofTable:tableForColumn andDatabase:[columnDefinition objectForKey:@"db"] includeBlobs:YES];
		if(!fieldIDQueryStr) {
			[tableDocumentInstance endTask];
			return @[@(-1), @""];
		}

		tempResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@.%@ %@",
			[[columnDefinition objectForKey:@"db"] backtickQuotedString],
			[tableForColumn backtickQuotedString],
			fieldIDQueryStr]];

		if ([mySQLConnection queryErrored]) {
			[tableDocumentInstance endTask];
			return @[@(-1), @""];
		}

		tempRow = [tempResult getRowAsArray];

		if([tempRow count] && [[tempRow objectAtIndex:0] integerValue] < 1) {
			[tableDocumentInstance endTask];
			return @[@(-1), @""];
		}

	}

	[tableDocumentInstance endTask];

	if(fieldIDQueryStr == nil)
		fieldIDQueryStr = @"";

	return [NSArray arrayWithObjects:[NSNumber numberWithInteger:[[tempRow objectAtIndex:0] integerValue]], fieldIDQueryStr, nil];

}

/**
 * Close an open sheet.
 */
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
#ifndef SP_CODA
	[sheet orderOut:self];
	
	if([contextInfo isEqualToString:SPTableFilterSetDefaultOperator]) {
		if(returnCode) {
			if(filterTableDefaultOperator) [filterTableDefaultOperator release];
			NSString *newOperator = [filterTableSetDefaultOperatorValue stringValue];
			filterTableDefaultOperator = [[self escapeFilterTableDefaultOperator:newOperator] retain];
			[prefs setObject:newOperator forKey:SPFilterTableDefaultOperator];

			if(![newOperator isMatchedByRegex:@"(?i)like\\s+['\"]%@%['\"]\\s*"]) {
				if(![prefs objectForKey:SPFilterTableDefaultOperatorLastItems])
					[prefs setObject:[NSMutableArray array] forKey:SPFilterTableDefaultOperatorLastItems];

				NSMutableArray *lastItems = [NSMutableArray array];
				[lastItems setArray:[prefs objectForKey:SPFilterTableDefaultOperatorLastItems]];

				if([lastItems containsObject:newOperator])
					[lastItems removeObject:newOperator];
				if([lastItems count] > 0)
					[lastItems insertObject:newOperator atIndex:0];
				else
					[lastItems addObject:newOperator];
				// Remember only the last 15 items
				if([lastItems count] > 15)
					while([lastItems count] > 15)
						[filterTableSetDefaultOperatorValue removeItemAtIndex:[lastItems count]-1];

				[prefs setObject:lastItems forKey:SPFilterTableDefaultOperatorLastItems];
			}
			[self updateFilterTableClause:nil];
		}
	}
#endif
}

/**
 * Show Error sheet (can be called from inside of a endSheet selector)
 * via [self performSelector:@selector(showErrorSheetWithTitle:) withObject: afterDelay:]
 */
- (void)showErrorSheetWith:(NSArray *)error
{
	// error := first object is the title , second the message, only one button OK
	SPOnewayAlertSheet([error objectAtIndex:0], [tableDocumentInstance parentWindow], [error objectAtIndex:1]);
}

- (void)processFieldEditorResult:(id)data contextInfo:(NSDictionary*)contextInfo
{

	NSInteger row = -1;
	NSInteger column = -1;

	if(contextInfo) {
		row = [[contextInfo objectForKey:@"rowIndex"] integerValue];
		column = [[contextInfo objectForKey:@"columnIndex"] integerValue];
	}

	if (data && contextInfo) {
		NSTableColumn *theTableColumn = [[tableContentView tableColumns] objectAtIndex:column];
		BOOL isFieldEditable = ([contextInfo objectForKey:@"isFieldEditable"]) ? YES : NO;
		if (!isEditingRow && [tablesListInstance tableType] != SPTableTypeView) {
			[oldRow setArray:[tableValues rowContentsAtIndex:row]];
			isEditingRow = YES;
			currentlyEditingRow = row;
		}

		if ([data isKindOfClass:[NSString class]]
			&& [data isEqualToString:[prefs objectForKey:SPNullValue]] && [[NSArrayObjectAtIndex(dataColumns, [[theTableColumn identifier] integerValue]) objectForKey:@"null"] boolValue])
		{
			data = [[NSNull null] retain];
		}
		if(isFieldEditable) {
			if ([tablesListInstance tableType] == SPTableTypeView) {

				// since in a view we're editing a field rather than a row
				isEditingRow = NO;

				// update the field and refresh the table
				[self saveViewCellValue:[[data copy] autorelease] forTableColumn:theTableColumn row:row];

			// Otherwise, in tables, save back to the row store
			} else {
				[tableValues replaceObjectInRow:row column:[[theTableColumn identifier] integerValue] withObject:[[data copy] autorelease]];
			}
		}
	}
	
	// this is a delegate method of the field editor controller. calling release
	// now would risk a dealloc while it is still our parent on the stack:
	[fieldEditor autorelease], fieldEditor = nil;

	[[tableContentView window] makeFirstResponder:tableContentView];

	if(row > -1 && column > -1)
		[tableContentView editColumn:column row:row withEvent:nil select:YES];
}

- (void)saveViewCellValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSUInteger)rowIndex
{

	// Field editing
	NSDictionary *columnDefinition = [cqColumnDefinition objectAtIndex:[[aTableColumn identifier] integerValue]];

	// Resolve the original table name for current column if AS was used
	NSString *tableForColumn = [columnDefinition objectForKey:@"org_table"];

	if (!tableForColumn || ![tableForColumn length]) {
		NSPoint pos = [NSEvent mouseLocation];
		pos.y -= 20;
		[SPTooltip showWithObject:NSLocalizedString(@"Field is not editable. Field has no or multiple table or database origin(s).",@"field is not editable due to no table/database")
				atLocation:pos
				ofType:@"text"];
		NSBeep();
		return;
	}

	// Resolve the original column name if AS was used
	NSString *columnName = [columnDefinition objectForKey:@"org_name"];

	[tableDocumentInstance startTaskWithDescription:NSLocalizedString(@"Updating field data...", @"updating field task description")];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:tableDocumentInstance];

	[self storeCurrentDetailsForRestoration];

	// Check if the IDstring identifies the current field bijectively and get the WHERE clause
	NSArray *editStatus = [self fieldEditStatusForRow:rowIndex andColumn:[[aTableColumn identifier] integerValue]];
	NSString *fieldIDQueryStr = [editStatus objectAtIndex:1];
	NSInteger numberOfPossibleUpdateRows = [[editStatus objectAtIndex:0] integerValue];

	if(numberOfPossibleUpdateRows == 1) {

		NSString *newObject = nil;
		if ( [anObject isKindOfClass:[NSCalendarDate class]] ) {
			newObject = [mySQLConnection escapeAndQuoteString:[anObject description]];
		} else if ( [anObject isKindOfClass:[NSNumber class]] ) {
			newObject = [anObject stringValue];
		} else if ( [anObject isKindOfClass:[NSData class]] ) {
			newObject = [mySQLConnection escapeAndQuoteData:anObject];
		} else {
			NSString *desc = [anObject description];
			if ( [desc isMatchedByRegex:SPCurrentTimestampPattern] ) {
				newObject = desc;
			} else if([anObject isEqualToString:[prefs stringForKey:SPNullValue]]) {
				newObject = @"NULL";
			} else if ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"geometry"]) {
				newObject = [(NSString*)anObject getGeomFromTextString];
			} else if ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"bit"]) {
				newObject = [NSString stringWithFormat:@"b'%@'", ((![desc length] || [desc isEqualToString:@"0"]) ? @"0" : desc)];
			} else if ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"date"] && [desc isEqualToString:@"NOW()"]) {
				newObject = @"NOW()";
			} else {
				newObject = [mySQLConnection escapeAndQuoteString:desc];
			}
		}

		[mySQLConnection queryString:
			[NSString stringWithFormat:@"UPDATE %@.%@ SET %@.%@.%@ = %@ %@ LIMIT 1",
				[[columnDefinition objectForKey:@"db"] backtickQuotedString], [tableForColumn backtickQuotedString],
				[[columnDefinition objectForKey:@"db"] backtickQuotedString], [tableForColumn backtickQuotedString], [columnName backtickQuotedString], newObject, fieldIDQueryStr]];


		// Check for errors while UPDATE
		if ([mySQLConnection queryErrored]) {
			SPOnewayAlertSheet(
				NSLocalizedString(@"Error", @"error"),
				[tableDocumentInstance parentWindow],
				[NSString stringWithFormat:NSLocalizedString(@"Couldn't write field.\nMySQL said: %@", @"message of panel when error while updating field to db"), [mySQLConnection lastErrorMessage]]
			);

			[tableDocumentInstance endTask];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];
			return;
		}


		// This shouldn't happen – for safety reasons
		if ( ![mySQLConnection rowsAffectedByLastQuery] ) {
#ifndef SP_CODA
			if ( [prefs boolForKey:SPShowNoAffectedRowsError] ) {
				SPOnewayAlertSheet(
					NSLocalizedString(@"Warning", @"warning"),
					[tableDocumentInstance parentWindow],
					NSLocalizedString(@"The row was not written to the MySQL database. You probably haven't changed anything.\nReload the table to be sure that the row exists and use a primary key for your table.\n(This error can be turned off in the preferences.)", @"message of panel when no rows have been affected after writing to the db")
				);
			} else {
				NSBeep();
			}
#endif
			[tableDocumentInstance endTask];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];
			return;
		}

	} else {
		SPOnewayAlertSheet(
			NSLocalizedString(@"Error", @"error"),
			[tableDocumentInstance parentWindow],
			[NSString stringWithFormat:NSLocalizedString(@"Updating field content failed. Couldn't identify field origin unambiguously (%1$ld matches). It's very likely that while editing this field the table `%2$@` was changed by an other user.", @"message of panel when error while updating field to db after enabling it"),(long)numberOfPossibleUpdateRows, tableForColumn]
		);

		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];
		[tableDocumentInstance endTask];
		return;

	}

	// Reload table after each editing due to complex declarations
	if (isFirstChangeInView) {

		// Set up the table details for the new table, and trigger an interface update
		// if the view was modified for the very first time
		NSDictionary *tableDetails = [NSDictionary dictionaryWithObjectsAndKeys:
										selectedTable, @"name",
										[tableDataInstance columns], @"columns",
										[tableDataInstance columnNames], @"columnNames",
										[tableDataInstance getConstraints], @"constraints",
										nil];
		[self performSelectorOnMainThread:@selector(setTableDetails:) withObject:tableDetails waitUntilDone:YES];
		isFirstChangeInView = NO;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];
	[tableDocumentInstance endTask];

	[self loadTableValues];
}

#pragma mark -
#pragma mark Filter Table

/**
 * Clear the filter table
 */
- (IBAction)tableFilterClear:(id)sender
{
#ifndef SP_CODA

	[filterTableView abortEditing];

	if(filterTableData && [filterTableData count]) {

		// Clear filter data
		for(NSNumber *col in [filterTableData allKeys])
		{
			[[filterTableData objectForKey:col] setObject:[NSMutableArray arrayWithObjects:@"", @"", @"", @"", @"", @"", @"", @"", @"", @"", nil] forKey:SPTableContentFilterKey];
		}

		[filterTableView reloadData];
		[filterTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
		[filterTableWhereClause setString:@""];

		// Reload table
		[self filterTable:nil];
	}
#endif
}

/**
 * Show filter table
 */
- (IBAction)showFilterTable:(id)sender
{
#ifndef SP_CODA
	[filterTableWindow makeKeyAndOrderFront:nil];
	[filterTableWhereClause setContinuousSpellCheckingEnabled:NO];
	[filterTableWhereClause setAutoindent:NO];
	[filterTableWhereClause setAutoindentIgnoresEnter:NO];
	[filterTableWhereClause setAutopair:[prefs boolForKey:SPCustomQueryAutoPairCharacters]];
	[filterTableWhereClause setAutohelp:NO];
	[filterTableWhereClause setAutouppercaseKeywords:[prefs boolForKey:SPCustomQueryAutoUppercaseKeywords]];
	[filterTableWhereClause setCompletionWasReinvokedAutomatically:NO];
	[filterTableWhereClause insertText:@""];
	[filterTableWhereClause didChangeText];
	
	[[filterTableView window] makeFirstResponder:filterTableView];
#endif
}

/**
 * Set filter table's Negate
 */
- (IBAction)toggleNegateClause:(id)sender
{
#ifndef SP_CODA
	filterTableNegate = !filterTableNegate;

	if (filterTableNegate) {
		[filterTableQueryTitle setStringValue:NSLocalizedString(@"WHERE NOT query", @"Title of filter preview area when the query WHERE is negated")];
	} 
	else {
		[filterTableQueryTitle setStringValue:NSLocalizedString(@"WHERE query", @"Title of filter preview area when the query WHERE is normal")];
	}

	// If live search is set perform filtering
	if ([filterTableLiveSearchCheckbox state] == NSOnState) {
		[self filterTable:filterTableFilterButton];
	}
#endif

}

/**
 * Set filter table's Distinct
 */
- (IBAction)toggleDistinctSelect:(id)sender
{
#ifndef SP_CODA
	filterTableDistinct = !filterTableDistinct;

	[filterTableDistinctCheckbox setState:(filterTableDistinct) ? NSOnState : NSOffState];

	// If live search is set perform filtering
	if ([filterTableLiveSearchCheckbox state] == NSOnState) {
		[self filterTable:filterTableFilterButton];
	}
#endif

}

/**
 * Set filter table's default operator
 */
- (IBAction)setDefaultOperator:(id)sender
{
#ifndef SP_CODA

	[filterTableWindow makeFirstResponder:filterTableView];

	// Load history
	if([prefs objectForKey:SPFilterTableDefaultOperatorLastItems]) {
		NSMutableArray *lastItems = [NSMutableArray array];
		
		[lastItems addObject:@"LIKE '%@%'"];

		for(NSString* item in [prefs objectForKey:SPFilterTableDefaultOperatorLastItems])
		{
			[lastItems addObject:item];
		}

		[filterTableSetDefaultOperatorValue removeAllItems];
		[filterTableSetDefaultOperatorValue addItemsWithObjectValues:lastItems];
	}

	[filterTableSetDefaultOperatorValue setStringValue:[prefs objectForKey:SPFilterTableDefaultOperator]];

	[NSApp beginSheet:filterTableSetDefaultOperatorSheet
	   modalForWindow:filterTableWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:SPTableFilterSetDefaultOperator];
#endif

}

/**
 * Generate WHERE clause to look for last typed pattern in all fields
 */
- (IBAction)toggleLookAllFieldsMode:(id)sender
{
	[self updateFilterTableClause:sender];

#ifndef SP_CODA
	// If live search is set perform filtering
	if ([filterTableLiveSearchCheckbox state] == NSOnState) {
		[self filterTable:filterTableFilterButton];
	}
#endif

}

/**
 * Closes the current sheet and stops the modal session
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

/**
 * Opens the content filter help page in the default browser.
 */
- (IBAction)showDefaultOperaterHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SPLOCALIZEDURL_CONTENTFILTERHELP]];
}

#pragma mark -
#pragma mark Retrieving and setting table state

/**
 * Provide a getter for the table's sort column name
 */
- (NSString *) sortColumnName
{
	if (!sortCol || !dataColumns) return nil;

	return [[dataColumns objectAtIndex:[sortCol integerValue]] objectForKey:@"name"];
}

/**
 * Provide a getter for the table current sort order
 */
- (BOOL) sortColumnIsAscending
{
	return !isDesc;
}

/**
 * Provide a getter for the table's selected rows.  If a primary key is available,
 * the returned dictionary will contain details of the primary key used, and an
 * identifier for each selected row.  If no primary key is available, the returned
 * dictionary will contain details and a list of the selected row *indexes* if the
 * supplied argument is set to true, which may not always be appropriate.
 */
- (NSDictionary *)selectionDetailsAllowingIndexSelection:(BOOL)allowIndexFallback
{

	// If a primary key is available, store the selection details for rows using the primary key.
	NSArray *primaryKeyFieldNames = [tableDataInstance primaryKeyColumnNames];
	if (primaryKeyFieldNames) {

		// Set up an array of the column indexes to store
		NSUInteger primaryKeyFieldCount = [primaryKeyFieldNames count];
		NSUInteger *primaryKeyFieldIndexes = calloc(primaryKeyFieldCount, sizeof(NSUInteger));
		BOOL problemColumns = NO;
		for (NSUInteger i = 0; i < primaryKeyFieldCount; i++) {
			primaryKeyFieldIndexes[i] = [[tableDataInstance columnNames] indexOfObject:[primaryKeyFieldNames objectAtIndex:i]];
			if (primaryKeyFieldIndexes[i] == NSNotFound) {
				problemColumns = YES;
#ifndef SP_CODA
			} else {
				if ([prefs boolForKey:SPLoadBlobsAsNeeded]) {
					if ([tableDataInstance columnIsBlobOrText:[primaryKeyFieldNames objectAtIndex:i]]) {
						problemColumns = YES;
					}
				}
#endif
			}
		}

		// Only proceed with key-based selection if there were no problem columns
		if (!problemColumns) {
			NSIndexSet *selectedRowIndexes = [tableContentView selectedRowIndexes];
			NSUInteger *indexBuffer = calloc([selectedRowIndexes count], sizeof(NSUInteger));
			NSUInteger indexCount = [selectedRowIndexes getIndexes:indexBuffer maxCount:[selectedRowIndexes count] inIndexRange:NULL];

			NSMutableDictionary *selectedRowLookupTable = [NSMutableDictionary dictionaryWithCapacity:indexCount];
			NSNumber *trueNumber = @YES;
			for (NSUInteger i = 0; i < indexCount; i++) {

				// For single-column primary keys, use the cell value as a dictionary key for fast lookups
				if (primaryKeyFieldCount == 1) {
					[selectedRowLookupTable setObject:trueNumber forKey:SPDataStorageObjectAtRowAndColumn(tableValues, indexBuffer[i], primaryKeyFieldIndexes[0])];

				// For multi-column primary keys, convert all the cell values to a string and use that as the key.
				} else {
					NSMutableString *lookupString = [NSMutableString stringWithString:[SPDataStorageObjectAtRowAndColumn(tableValues, indexBuffer[i], primaryKeyFieldIndexes[0]) description]];
					for (NSUInteger j = 1; j < primaryKeyFieldCount; j++) {
						[lookupString appendString:SPUniqueSchemaDelimiter];
						[lookupString appendString:[SPDataStorageObjectAtRowAndColumn(tableValues, indexBuffer[i], primaryKeyFieldIndexes[j]) description]];
					}
					[selectedRowLookupTable setObject:trueNumber forKey:lookupString];
				}
			}
			free(indexBuffer);
			free(primaryKeyFieldIndexes);

			return [NSDictionary dictionaryWithObjectsAndKeys:
						SPSelectionDetailTypePrimaryKeyed, @"type",
						selectedRowLookupTable, @"rows",
						primaryKeyFieldNames, @"keys",
					nil];
		}
		free(primaryKeyFieldIndexes);
	}

	// If no primary key was available, fall back to using just the selected row indexes if permitted
	if (allowIndexFallback) {
		return [NSDictionary dictionaryWithObjectsAndKeys:
					SPSelectionDetailTypeIndexed, @"type",
					[tableContentView selectedRowIndexes], @"rows",
				nil];
	}

	// Otherwise return a blank selection
	return [NSDictionary dictionaryWithObjectsAndKeys:
				SPSelectionDetailTypeIndexed, @"type",
				[NSIndexSet indexSet], @"rows",
			nil];
}

/**
 * Provide a getter for the page number
 */
- (NSUInteger) pageNumber
{
	return contentPage;
}

/**
 * Provide a getter for the table's current viewport
 */
- (NSRect) viewport
{
	return [tableContentView visibleRect];
}

/**
 * Provide a getter for the table's list view width
 */
- (CGFloat) tablesListWidth
{
	return [[[[tableDocumentInstance valueForKeyPath:@"contentViewSplitter"] subviews] objectAtIndex:0] frame].size.width;
}

/**
 * Provide a getter for the current filter details
 *
 * @warning Uses UI. MUST call from main thread!
 */
- (NSDictionary *) filterSettings
{
	NSDictionary *theDictionary;

	if (![fieldField isEnabled]) return nil;

	theDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
						[self tableFilterString], @"menuLabel",
						[fieldField titleOfSelectedItem], @"filterField",
						[[compareField selectedItem] title], @"filterComparison",
						[NSNumber numberWithInteger:[[compareField selectedItem] tag]], @"filterComparisonTag",
						[argumentField stringValue], @"filterValue",
						[firstBetweenField stringValue], @"firstBetweenField",
						[secondBetweenField stringValue], @"secondBetweenField",
						nil];

	return theDictionary;
}

/**
 * Set the sort column and sort order to restore on next table load
 */
- (void) setSortColumnNameToRestore:(NSString *)theSortColumnName isAscending:(BOOL)isAscending
{
	if (sortColumnToRestore) SPClear(sortColumnToRestore);

	if (theSortColumnName) {
		sortColumnToRestore = [[NSString alloc] initWithString:theSortColumnName];
		sortColumnToRestoreIsAsc = isAscending;
	}
}

/**
 * Sets the value for the page number to use on next table load
 */
- (void) setPageToRestore:(NSUInteger)thePage
{
	pageToRestore = thePage;
}

/**
 * Set the selected row indexes to restore on next table load
 */
- (void) setSelectionToRestore:(NSDictionary *)theSelection
{
	if (selectionToRestore) SPClear(selectionToRestore);

	if (theSelection) selectionToRestore = [theSelection copy];
}

/**
 * Set the viewport to restore on next table load
 */
- (void) setViewportToRestore:(NSRect)theViewport
{
	selectionViewportToRestore = theViewport;
}

/**
 * Set the filter settings to restore (if possible) on next table load
 */
- (void) setFiltersToRestore:(NSDictionary *)filterSettings
{
	if (filterFieldToRestore) SPClear(filterFieldToRestore);
	if (filterComparisonToRestore) SPClear(filterComparisonToRestore);
	if (filterValueToRestore) SPClear(filterValueToRestore);
	if (firstBetweenValueToRestore) SPClear(firstBetweenValueToRestore);
	if (secondBetweenValueToRestore) SPClear(secondBetweenValueToRestore);

	if ([filterSettings count]) {
		if ([filterSettings objectForKey:@"filterField"])
			filterFieldToRestore = [[NSString alloc] initWithString:[filterSettings objectForKey:@"filterField"]];
		if ([[filterSettings objectForKey:@"filterComparison"] unboxNull]) {
			// Check if operator is BETWEEN, if so set up input fields
			if([[filterSettings objectForKey:@"filterComparison"] isEqualToString:@"BETWEEN"]) {
				[argumentField setHidden:YES];
				[betweenTextField setHidden:NO];
				[firstBetweenField setHidden:NO];
				[secondBetweenField setHidden:NO];
				[firstBetweenField setEnabled:YES];
				[secondBetweenField setEnabled:YES];
			}

			filterComparisonToRestore = [[NSString alloc] initWithString:[filterSettings objectForKey:@"filterComparison"]];
		}
		if([filterComparisonToRestore isEqualToString:@"BETWEEN"]) {
			if ([filterSettings objectForKey:@"firstBetweenField"])
				firstBetweenValueToRestore = [[NSString alloc] initWithString:[filterSettings objectForKey:@"firstBetweenField"]];
			if ([filterSettings objectForKey:@"secondBetweenField"])
				secondBetweenValueToRestore = [[NSString alloc] initWithString:[filterSettings objectForKey:@"secondBetweenField"]];
		} else {
			id filterValue = [filterSettings objectForKey:@"filterValue"];
			if ([filterValue unboxNull]) {
				if ([filterValue isKindOfClass:[NSData class]]) {
					filterValueToRestore = [[NSString alloc] initWithData:(NSData *)filterValue encoding:[mySQLConnection stringEncoding]];
				} else {
					filterValueToRestore = [[NSString alloc] initWithString:(NSString *)filterValue];
				}
			}
		}
	}
}

/**
 * Convenience method for storing all current settings for restoration
 */
- (void) storeCurrentDetailsForRestoration
{
	[self setSortColumnNameToRestore:[self sortColumnName] isAscending:[self sortColumnIsAscending]];
	[self setPageToRestore:[self pageNumber]];
	[self setSelectionToRestore:[self selectionDetailsAllowingIndexSelection:YES]];
	[self setViewportToRestore:[self viewport]];
	[self setFiltersToRestore:[self filterSettings]];
}

/**
 * Convenience method for clearing any settings to restore
 */
- (void) clearDetailsToRestore
{
	[self setSortColumnNameToRestore:nil isAscending:YES];
	[self setPageToRestore:1];
	[self setSelectionToRestore:nil];
	[self setViewportToRestore:NSZeroRect];
	[self setFiltersToRestore:nil];
}

- (void) setFilterTableData:(NSData*)arcData
{
#ifndef SP_CODA
	if(!arcData) return;
	NSDictionary *filterData = [NSUnarchiver unarchiveObjectWithData:arcData];
	[filterTableData removeAllObjects];
	[filterTableData addEntriesFromDictionary:filterData];
	[filterTableWindow makeKeyAndOrderFront:nil];
	// [filterTableView reloadData];
#endif
}

- (NSData*) filterTableData
{
#ifndef SP_CODA
	if(![filterTableWindow isVisible]) return nil;

	[filterTableView deselectAll:nil];

	return [NSArchiver archivedDataWithRootObject:filterTableData];
#else
	return nil;
#endif
}

#pragma mark -
#pragma mark Table drawing and editing

/**
 * Updates the number of rows in the selected table.
 * Attempts to use the fullResult count if available, also updating the
 * table data store; otherwise, uses the table data store if accurate or
 * falls back to a fetch if necessary and set in preferences.
 * The prefs option "fetch accurate row counts" is used as a last resort as
 * it can be very slow on large InnoDB tables which require a full table scan.
 */
- (void)updateNumberOfRows
{
	BOOL checkStatusCount = NO;

	// For unfiltered and non-limited tables, use the result count - and update the status count
	if (!isLimited && !isFiltered && !isInterruptedLoad) {
		maxNumRows = tableRowsCount;
		maxNumRowsIsEstimate = NO;
		[tableDataInstance setStatusValue:[NSString stringWithFormat:@"%ld", (long)maxNumRows] forKey:@"Rows"];
		[tableDataInstance setStatusValue:@"y" forKey:@"RowsCountAccurate"];
#ifndef SP_CODA
		[[tableInfoInstance onMainThread] tableChanged:nil];
		[[[tableDocumentInstance valueForKey:@"extendedTableInfoInstance"] onMainThread] loadTable:selectedTable];
#endif

	} else {

		// Trigger an update via the SPTableData instance if preferences require it, and if
		// the state is not already accurate
		[tableDataInstance updateAccurateNumberOfRowsForCurrentTableForcingUpdate:NO];

		// If the state is now accurate, use it
		NSString *rows = [tableDataInstance statusValueForKey:@"Rows"];
		if ([[tableDataInstance statusValueForKey:@"RowsCountAccurate"] boolValue]) {
			maxNumRows = [rows integerValue];
			maxNumRowsIsEstimate = NO;
			checkStatusCount = YES;
		}
		// Otherwise, use the estimate count
		else {
			maxNumRows = (rows && ![rows isNSNull])? [rows integerValue] : 0;
			maxNumRowsIsEstimate = YES;
			checkStatusCount = YES;
		}
	}

	// Check whether the estimated count requires updating, ie if the retrieved count exceeds it
	if (checkStatusCount) {
		NSInteger foundMaxRows;
		if ([prefs boolForKey:SPLimitResults])
		{
			foundMaxRows = ((contentPage - 1) * [prefs integerForKey:SPLimitResultsValue]) + tableRowsCount;
			if (foundMaxRows > maxNumRows) {
				if ((NSInteger)tableRowsCount == [prefs integerForKey:SPLimitResultsValue]) 
				{
					maxNumRows = foundMaxRows + 1;
					maxNumRowsIsEstimate = YES;
				} else {
					maxNumRows = foundMaxRows;
					maxNumRowsIsEstimate = NO;
				}
			} else if (!isInterruptedLoad && !isFiltered && (NSInteger)tableRowsCount < [prefs integerForKey:SPLimitResultsValue]) {
				maxNumRows = foundMaxRows;
				maxNumRowsIsEstimate = NO;
			}
		} else if ((NSInteger)tableRowsCount > maxNumRows) {
			maxNumRows = tableRowsCount;
			maxNumRowsIsEstimate = YES;
		}
		[tableDataInstance setStatusValue:[NSString stringWithFormat:@"%ld", (long)maxNumRows] forKey:@"Rows"];
		[tableDataInstance setStatusValue:maxNumRowsIsEstimate?@"n":@"y" forKey:@"RowsCountAccurate"];
#ifndef SP_CODA
		[[tableInfoInstance onMainThread] tableChanged:nil];
#endif
	}
}

/**
 * Autosize all columns based on their content.
 * Should be called on the main thread.
 */
- (void)autosizeColumns
{
	if (isWorking) pthread_mutex_lock(&tableValuesLock);
	NSDictionary *columnWidths = [tableContentView autodetectColumnWidths];
	if (isWorking) pthread_mutex_unlock(&tableValuesLock);
	[tableContentView setDelegate:nil];
	for (NSDictionary *columnDefinition in dataColumns) {

#ifndef SP_CODA
		// Skip columns with saved widths
		if ([[[[prefs objectForKey:SPTableColumnWidths] objectForKey:[NSString stringWithFormat:@"%@@%@", [tableDocumentInstance database], [tableDocumentInstance host]]] objectForKey:[tablesListInstance tableName]] objectForKey:[columnDefinition objectForKey:@"name"]]) continue;
#endif

		// Otherwise set the column width
		NSTableColumn *aTableColumn = [tableContentView tableColumnWithIdentifier:[columnDefinition objectForKey:@"datacolumnindex"]];
		NSInteger targetWidth = [[columnWidths objectForKey:[columnDefinition objectForKey:@"datacolumnindex"]] integerValue];
		[aTableColumn setWidth:targetWidth];
	}
	[tableContentView setDelegate:self];
}

#pragma mark -
#pragma mark Task interaction

/**
 * Disable all content interactive elements during an ongoing task.
 */
- (void) startDocumentTaskForTab:(NSNotification *)aNotification
{
	isWorking = YES;

#ifndef SP_CODA /* Only proceed if this view is selected */
	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableContent])
		return;
#endif

	[addButton setEnabled:NO];
	[removeButton setEnabled:NO];
	[duplicateButton setEnabled:NO];
	[reloadButton setEnabled:NO];
	[filterButton setEnabled:NO];
	tableRowsSelectable = NO;
	[paginationPreviousButton setEnabled:NO];
	[paginationNextButton setEnabled:NO];
#ifndef SP_CODA
	[paginationButton setEnabled:NO];
#endif
}

/**
 * Enable all content interactive elements after an ongoing task.
 */
- (void) endDocumentTaskForTab:(NSNotification *)aNotification
{
	isWorking = NO;

#ifndef SP_CODA /* Only proceed if this view is selected */
	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableContent])
		return;
#endif

	if ( ![[tableDataInstance statusValueForKey:@"Rows"] isNSNull] && selectedTable && [selectedTable length] && [tableDataInstance tableEncoding]) {
		[addButton setEnabled:([tablesListInstance tableType] == SPTableTypeTable)];
		[self updatePaginationState];
		[reloadButton setEnabled:YES];
	}

	if ([tableContentView numberOfSelectedRows] > 0) {
		if([tablesListInstance tableType] == SPTableTypeTable) {
			[removeButton setEnabled:YES];
			[duplicateButton setEnabled:YES];
		}
	}

	[filterButton setEnabled:[fieldField isEnabled]];
	tableRowsSelectable = YES;
}

//this method is called right before the UI objects are deallocated
- (void)documentWillClose:(NSNotification *)notification
{
	// if a result load is in progress we must stop the timer or it may try to call invalid IBOutlets
	[self clearTableLoadTimer];
}

#pragma mark -
#pragma mark KVO methods

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
#ifndef SP_CODA /* observe pref changes */
	// Display table veiew vertical gridlines preference changed
	if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
        [tableContentView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
		[filterTableView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
	// Table font preference changed
	else if ([keyPath isEqualToString:SPGlobalResultTableFont]) {
		NSFont *tableFont = [NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]];

		[tableContentView setRowHeight:2.0f + NSSizeToCGSize([@"{ǞṶḹÜ∑zgyf" sizeWithAttributes:@{NSFontAttributeName : tableFont}]).height];
		[tableContentView setFont:tableFont];
		[tableContentView reloadData];
	}
	// Display binary data as Hex
	else if ([keyPath isEqualToString:SPDisplayBinaryDataAsHex] && [tableContentView numberOfRows] > 0) {
		[tableContentView reloadData];
	}
#endif
}

#pragma mark -
#pragma mark Other methods

/**
 * Menu validation
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	
	// Remove row
	if (action == @selector(removeRow:)) {
		[menuItem setTitle:([tableContentView numberOfSelectedRows] > 1) ? NSLocalizedString(@"Delete Rows", @"delete rows menu item plural") : NSLocalizedString(@"Delete Row", @"delete row menu item singular")];

		return ([tableContentView numberOfSelectedRows] > 0 && [tablesListInstance tableType] == SPTableTypeTable);
	}

	// Duplicate row
	if (action == @selector(duplicateRow:)) {
		return (([tableContentView numberOfSelectedRows]) == 1 && ([tablesListInstance tableType] == SPTableTypeTable));
	}
	
	// Add new row
	if (action == @selector(addRow:)) {
		return ((![tableContentView numberOfSelectedRows]) && ([tablesListInstance tableType] == SPTableTypeTable));
	}

	return YES;
}

- (void)setFieldEditorSelectedRange:(NSRange)aRange
{
	[tableContentView setFieldEditorSelectedRange:aRange];
}

- (NSRange)fieldEditorSelectedRange
{
	return [tableContentView fieldEditorSelectedRange];
}


#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	// Cancel previous performSelector: requests on ourselves and the table view
	// to prevent crashes for deferred actions
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:tableContentView];

	if(fieldEditor) SPClear(fieldEditor);

	[self clearTableLoadTimer];
	SPClear(tableValues);
	pthread_mutex_destroy(&tableValuesLock);
	SPClear(dataColumns);
	SPClear(oldRow);
#ifndef SP_CODA
	for (id retainedObject in nibObjectsToRelease) [retainedObject release];	
	SPClear(nibObjectsToRelease);
	SPClear(paginationPopover);

	SPClear(filterTableData);
	if (lastEditedFilterTableValue) SPClear(lastEditedFilterTableValue);
	if (filterTableDefaultOperator) SPClear(filterTableDefaultOperator);
#endif
	if (selectedTable)          SPClear(selectedTable);
	if (contentFilters)         SPClear(contentFilters);
	if (numberOfDefaultFilters) SPClear(numberOfDefaultFilters);
	if (keys)                   SPClear(keys);
	if (sortCol)                SPClear(sortCol);
	SPClear(usedQuery);
	if (sortColumnToRestore)    SPClear(sortColumnToRestore);
	if (selectionToRestore)     SPClear(selectionToRestore);
	if (cqColumnDefinition)     SPClear(cqColumnDefinition);

	if (filterFieldToRestore) filterFieldToRestore = nil;
	if (filterComparisonToRestore) filterComparisonToRestore = nil;
	if (filterValueToRestore) filterValueToRestore = nil;
	if (firstBetweenValueToRestore) firstBetweenValueToRestore = nil;
	if (secondBetweenValueToRestore) secondBetweenValueToRestore = nil;

	[super dealloc];
}

@end

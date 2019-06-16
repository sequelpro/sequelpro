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
#import "SPDatabaseDocument.h"
#import "SPTableStructure.h"
#import "SPTableInfo.h"
#import "SPTablesList.h"
#import "SPImageView.h"
#import "SPCopyTable.h"
#import "SPDataCellFormatter.h"
#import "SPTableData.h"
#import "SPQueryController.h"
#import "SPTextAndLinkCell.h"
#import "SPFieldEditorController.h"
#import "SPTooltip.h"
#import "RegexKitLite.h"
#import "SPDataStorage.h"
#import "SPAlertSheets.h"
#import "SPHistoryController.h"
#import "SPGeometryDataView.h"
#import "SPTextView.h"
#ifndef SP_CODA /* headers */
#import "SPAppController.h"
#import "SPBundleHTMLOutputController.h"
#endif
#import "SPCustomQuery.h"
#import "SPThreadAdditions.h"
#import "SPTableFilterParser.h"
#import "SPFunctions.h"
#import "SPRuleFilterController.h"
#import "SPFilterTableController.h"

#import <pthread.h>
#import <SPMySQL/SPMySQL.h>
#include <stdlib.h>

/**
 * This is the unique KVO context of code that resides in THIS class.
 * Do not try to give it to other classes, ESPECIALLY NOT child classes!
 */
static void *TableContentKVOContext = &TableContentKVOContext;

/**
 * TODO:
 * This class is a temporary workaround, because before SPTableContent was both a child class in one xib
 * and an owner class in another xib, which is bad style and causes other complications.
 */
@interface ContentPaginationViewController : NSViewController
{
	id target;
	SEL action;

	NSNumber *page;
	NSNumber *maxPage;

	IBOutlet NSButton *paginationGoButton;
	IBOutlet NSTextField *paginationPageField;
	IBOutlet NSStepper *paginationPageStepper;
}
- (IBAction)paginationGoAction:(id)sender;
- (void)makeInputFirstResponder;
- (BOOL)isFirstResponderInside;

@property (assign, nonatomic) id target;
@property (assign, nonatomic) SEL action;

// IB Bindings
@property (copy, nonatomic) NSNumber *page;
@property (copy, nonatomic) NSNumber *maxPage;

@end

@interface SPTableContent ()

- (BOOL)cancelRowEditing;
- (void)documentWillClose:(NSNotification *)notification;

- (void)updateFilterRuleEditorSize:(CGFloat)requestedHeight animate:(BOOL)animate;
- (void)filterRuleEditorPreferredSizeChanged:(NSNotification *)notification;
- (void)contentViewSizeChanged:(NSNotification *)notification;
- (void)setRuleEditorVisible:(BOOL)show animate:(BOOL)animate;

- (void)_setViewBlankState;

#pragma mark - SPTableContentDataSource_Private_API

- (id)_contentValueForTableColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex asPreview:(BOOL)asPreview;

@end

@implementation SPTableContent

#ifdef SP_CODA
@synthesize addButton;
@synthesize duplicateButton;
@synthesize paginationNextButton;
@synthesize paginationPreviousButton;
@synthesize reloadButton;
@synthesize removeButton;
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

		tableValues       = [[SPDataStorage alloc] init];
		dataColumns       = [[NSMutableArray alloc] init];
		oldRow            = [[NSMutableArray alloc] init];

		tableRowsCount         = 0;
		previousTableRowsCount = 0;

#ifndef SP_CODA
		activeFilter               = SPTableContentFilterSourceNone;
		schemeFilter               = nil;
		paginationViewController   = [[ContentPaginationViewController alloc] init]; // the view itself is lazily loaded
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
		filtersToRestore = nil;
		activeFilterToRestore = SPTableContentFilterSourceNone;
		tableRowsSelectable = YES;
		isFirstChangeInView = YES;

		isFiltered = NO;
		isLimited = NO;
		isInterruptedLoad = NO;

		prefs = [NSUserDefaults standardUserDefaults];

		showFilterRuleEditor = [prefs boolForKey:SPRuleFilterEditorLastVisibilityChoice];

		usedQuery = [[NSString alloc] initWithString:@""];

		tableLoadTimer = nil;

		textForegroundColor  = [NSColor controlTextColor]; // this color dynamically adapts to the rest of the UI
		nullHighlightColor   = [NSColor lightGrayColor];
		binhexHighlightColor = [NSColor blueColor];

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

	// initially hide the filter rule editor
	[self updateFilterRuleEditorSize:0.0 animate:NO];

	// Set the table content view's vertical gridlines if required
	[tableContentView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];

	// Set the double-click action in blank areas of the table to create new rows
	[tableContentView setEmptyDoubleClickAction:@selector(addRow:)];

	[paginationViewController setTarget:self];
	[paginationViewController setAction:@selector(navigatePaginationFromButton:)];
	[paginationViewController view]; // make sure the nib is actually loaded
	
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
		[[paginationButton superview] addSubview:paginationView];
	}
#endif

	[tableContentView setFieldEditorSelectedRange:NSMakeRange(0,0)];

	[prefs addObserver:self forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:TableContentKVOContext];
	[prefs addObserver:self forKeyPath:SPGlobalResultTableFont             options:NSKeyValueObservingOptionNew context:TableContentKVOContext];
	[prefs addObserver:self forKeyPath:SPDisplayBinaryDataAsHex            options:NSKeyValueObservingOptionNew context:TableContentKVOContext];

	// Add observer to change view sizes with filter rule editor
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(filterRuleEditorPreferredSizeChanged:)
	                                             name:SPRuleFilterHeightChangedNotification
	                                           object:ruleFilterController];
	[contentAreaContainer setPostsFrameChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(contentViewSizeChanged:)
	                                             name:NSViewFrameDidChangeNotification
	                                           object:contentAreaContainer];
	[ruleFilterController setTarget:self];
	[ruleFilterController setAction:@selector(filterTable:)];
	
	[filterTableController setTarget:self];
	[filterTableController setAction:@selector(filterTable:)];
	//TODO This is only needed for 10.6 compatibility
	scrollViewHasRubberbandScrolling = [[[ruleFilterController view] enclosingScrollView] respondsToSelector:@selector(setVerticalScrollElasticity:)];

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
		SPMainQSync(^{
			// Scroll the viewport to the saved location
			selectionViewportToRestore.size = [tableContentView visibleRect].size;
			[tableContentView scrollRectToVisible:selectionViewportToRestore];
		});
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
 * This configures the table content view in the way it should look like when no valid table is selected
 */
- (void)_setViewBlankState
{
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
	[self setRuleEditorVisible:NO animate:NO];
	[toggleRuleFilterButton setEnabled:NO];
	[toggleRuleFilterButton setState:NSOffState];
	[ruleFilterController setColumns:nil];

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
	[filterTableController setColumns:nil];
	activeFilter = SPTableContentFilterSourceNone;
#endif
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
	NSTableColumn *theCol;

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
		[paginationViewController setPage:@1];

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
		[self _setViewBlankState];
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
	[filterTableController setColumns:nil];
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

	// Add the new columns to the table
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

	[filterTableController setColumns:dataColumns];
	// Enable and initialize filter fields (with tags for position of menu item and field position)
	[ruleFilterController setColumns:dataColumns];
	// Restore preserved filter settings if appropriate and valid
	[ruleFilterController restoreSerializedFilters:filtersToRestore];
	// hide/show the rule filter editor, based on its previous state (so that it says visible when switching tables, if someone has enabled it and vice versa)
	if(showFilterRuleEditor) {
		[self setRuleEditorVisible:YES animate:NO];
		[toggleRuleFilterButton setState:NSOnState];
	}
	else {
		[self setRuleEditorVisible:NO animate:NO];
		[toggleRuleFilterButton setState:NSOffState];
	}
	[ruleFilterController setEnabled:enableInteraction];
	[toggleRuleFilterButton setEnabled:enableInteraction];
	// restore the filter to the previously choosen one for the table
	activeFilter = activeFilterToRestore;

	// Restore page number if limiting is set
	if ([prefs boolForKey:SPLimitResults]) contentPage = pageToRestore;

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
}

- (NSString *)selectedTable
{
	return selectedTable;
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

	// Add a filter string if appropriate
	filterString = [[self onMainThread] tableFilterString];
	
	// Start construction of the query string
	queryString = [NSMutableString stringWithFormat:@"SELECT %@%@ FROM %@", 
#ifndef SP_CODA
			(activeFilter == SPTableContentFilterSourceTableFilter && filterString && [filterTableController isDistinct]) ? @"DISTINCT " :
#endif
			@"", 
			[self fieldListForQuery], [selectedTable backtickQuotedString]];

	if ([filterString length]) {
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

	SPMainQSync(^{
		// Set the filter text
		[self updateCountText];
		
		// Update pagination
		[self updatePaginationState];
	});

	// Retrieve and cache the column definitions for editing views
	if (cqColumnDefinition) [cqColumnDefinition release];
	cqColumnDefinition = [[resultStore fieldDefinitions] retain];


	// Notify listenters that the query has finished
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];

	if ([mySQLConnection queryErrored] && ![mySQLConnection lastQueryWasCancelled]) {
#ifndef SP_CODA
		if(activeFilter == SPTableContentFilterSourceRuleFilter || activeFilter == SPTableContentFilterSourceNone) {
#endif
			NSString *errorDetail;
			if([filterString length])
				errorDetail = [NSString stringWithFormat:NSLocalizedString(@"The table data couldn't be loaded presumably due to used filter clause. \n\nMySQL said: %@", @"message of panel when loading of table failed and presumably due to used filter argument"), [mySQLConnection lastErrorMessage]];
			else
				errorDetail = [NSString stringWithFormat:NSLocalizedString(@"The table data couldn't be loaded.\n\nMySQL said: %@", @"message of panel when loading of table failed"), [mySQLConnection lastErrorMessage]];
		
			SPOnewayAlertSheet(NSLocalizedString(@"Error", @"error"), [tableDocumentInstance parentWindow], errorDetail);
		}
#ifndef SP_CODA
		// Filter task came from filter table
		else if(activeFilter == SPTableContentFilterSourceTableFilter) {
			[[filterTableController onMainThread] setFilterError:[mySQLConnection lastErrorID]
			                                             message:[mySQLConnection lastErrorMessage]
			                                            sqlstate:[mySQLConnection lastSqlstate]];
		}
	} 
#endif
	else 
	{
#ifndef SP_CODA
		// Trigger a full reload if required
		if (fullTableReloadRequired) [self reloadTable:self];
		[[filterTableController onMainThread] setFilterError:0 message:nil sqlstate:nil];
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
#warning Private ivar accessed from outside (#2978)
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

	SPMainQSync(^{
		tableRowsCount = [tableValues count];
		
		// If the final column autoresize wasn't performed, perform it
		if (tableLoadLastRowCount < 200) [self autosizeColumns];

		// Ensure the table is aware of changes
		[tableContentView noteNumberOfRowsChanged]; // UI method!

		// Reset the progress indicator
		[dataLoadingIndicator setIndeterminate:YES]; // UI method!
	});
}

/**
 * Returns the query string for the current filter settings,
 * ready to be dropped into a WHERE clause, or nil if no filtering
 * is active.
 *
 * MUST BE CALLED ON THE UI THREAD!
 */
- (NSString *)tableFilterString
{

#ifndef SP_CODA
	// If filter command was passed by sequelpro url scheme
	if(activeFilter == SPTableContentFilterSourceURLScheme) {
		if(schemeFilter) return schemeFilter;
	}

	// Call did come from filter table and is filter table window still open?
	if(activeFilter == SPTableContentFilterSourceTableFilter && [[filterTableController window] isVisible]) {
		return [filterTableController tableFilterString];
	}
#endif
	if(activeFilter == SPTableContentFilterSourceRuleFilter && showFilterRuleEditor) {
		// If the clause has the placeholder $BINARY that placeholder will be replaced
		// by BINARY if the user pressed ⇧ while invoking 'Filter' otherwise it will
		// replaced by @"".
		BOOL caseSensitive = (([[NSApp currentEvent] modifierFlags] & NSEventModifierFlagShift) > 0);

		NSError *err = nil;
		NSString *filter = [ruleFilterController sqlWhereExpressionWithBinary:caseSensitive error:&err];
		if(err) {
			SPOnewayAlertSheet(
				NSLocalizedString(@"Invalid Filter", @"table content : apply filter : invalid filter message title"),
				[tableDocumentInstance parentWindow],
				[err localizedDescription]
			);
			return nil;
		}
		return filter;
	}

	return nil;
}

/**
 * Update the table count/selection text
 *
 * MUST BE CALLED ON THE UI THREAD!
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
	NSInteger selectedRows = [tableContentView numberOfSelectedRows]; // -numberOfSelectedRows is a UI method!
	if (selectedRows > 0) {
		[countString appendString:@"; "];
		if (selectedRows == 1)
			rowString = [NSString stringWithString:NSLocalizedString(@"row", @"singular word for row")];
		else
			rowString = [NSString stringWithString:NSLocalizedString(@"rows", @"plural word for rows")];
		[countString appendFormat:NSLocalizedString(@"%@ %@ selected", @"text showing how many rows are selected"), [numberFormatter stringFromNumber:[NSNumber numberWithInteger:selectedRows]], rowString];
	}

#ifndef SP_CODA
	[countText setStringValue:countString];
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
	@autoreleasepool {
		// Check whether a save of the current row is required, abort if pending changes couldn't be saved.
		if ([[self onMainThread] saveRowOnDeselect]) {

			// Save view details to restore safely if possible (except viewport, which will be
			// preserved automatically, and can then be scrolled as the table loads)
			[[self onMainThread] storeCurrentDetailsForRestoration];
			[self setViewportToRestore:NSZeroRect];

			// Clear the table data column cache and status (including counts)
			[tableDataInstance resetColumnData];
			[tableDataInstance resetStatusData];

			// Load the table's data
			[self loadTable:[tablesListInstance tableName]];
		}

		[tableDocumentInstance endTask];
	}
}

/**
 * Filter the table with arguments given by the user.
 * Performs the action in a new thread if necessary.
 */
- (IBAction)filterTable:(id)sender
{
	// Record whether the filter is being triggered by using delete/backspace in the filter field, which
	// can trigger the effect of clicking the "clear filter" button in the field.
	// (Keycode 51 is backspace, 117 is delete.)
	BOOL deleteTriggeringFilter = ([sender isKindOfClass:[NSSearchField class]] && [[[sender window] currentEvent] type] == NSKeyDown && ([[[sender window] currentEvent] keyCode] == 51 || [[[sender window] currentEvent] keyCode] == 117));

#ifndef SP_CODA

	BOOL resetPaging = NO; // if filtering was triggered by pressing the "Filter" button, reset to page 1
	
	// If the filter table is being used - the advanced filter - switch type
	if(sender == filterTableController) {
		activeFilter = SPTableContentFilterSourceTableFilter;
		resetPaging = YES;
	}
	// If a string was supplied, use a custom query from that URL scheme
	else if([sender isKindOfClass:[NSString class]] && [(NSString *)sender length]) {
		if(schemeFilter) SPClear(schemeFilter);
		schemeFilter = [sender retain];
		activeFilter = SPTableContentFilterSourceURLScheme;
		resetPaging = YES;
	}
	// If a button other than the pagination buttons was used, set the active filter type to
	// the standard filter field.
	else if (sender == ruleFilterController) {
		activeFilter = SPTableContentFilterSourceRuleFilter;
		resetPaging = YES;
	}
	else if (sender == nil) {
		activeFilter = SPTableContentFilterSourceNone;
		resetPaging = YES;
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
	NSInteger paginationViewPage = [[paginationViewController page] integerValue];
	if (resetPaging || ![prefs boolForKey:SPLimitResults] || paginationViewPage <= 0) {
		contentPage = 1;
	}
	// If the current page is out of bounds, move it within bounds
	else if ((paginationViewPage - 1) * [prefs integerForKey:SPLimitResultsValue] >= maxNumRows) {
		contentPage = ceilf((CGFloat) maxNumRows / [prefs floatForKey:SPLimitResultsValue]);
	}
	// Otherwise, use the pagination value
	else {
		contentPage = paginationViewPage;
	}

	if ([self tableFilterString]) {
		taskString = NSLocalizedString(@"Filtering table...", @"Filtering table task description");
	} else if (contentPage == 1) {
		taskString = [NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), selectedTable];
	} else {
		taskString = [NSString stringWithFormat:NSLocalizedString(@"Loading page %lu...", @"Loading table page task string"), (unsigned long)contentPage];
	}

	[tableDocumentInstance startTaskWithDescription:taskString];

	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadWithName:SPCtxt(@"SPTableContent filter table task", tableDocumentInstance)
		                           target:self
		                         selector:@selector(filterTableTask)
		                           object:nil];
	} else {
		[self filterTableTask];
	}
}

- (void)filterTableTask
{
	@autoreleasepool {
#ifndef SP_CODA
		// Update history
		[spHistoryControllerInstance updateHistoryEntries];
#endif

		// Reset and reload data using the new filter settings
		[self setSelectionToRestore:[[self onMainThread] selectionDetailsAllowingIndexSelection:NO]];
		previousTableRowsCount = 0;
		[self clearTableValues];
		[self loadTableValues];
		[[tableContentView onMainThread] scrollRowToVisible:0];

		[tableDocumentInstance endTask];
	}
}

- (IBAction)toggleRuleEditorVisible:(id)sender
{
	BOOL shouldShow = !showFilterRuleEditor;
	[prefs setBool:shouldShow forKey:SPRuleFilterEditorLastVisibilityChoice];
	[self setRuleEditorVisible:shouldShow animate:YES];
	// if this was the active filter before, it no longer can be the active filter when it is hidden
	if(activeFilter == SPTableContentFilterSourceRuleFilter && !shouldShow) {
		activeFilter = SPTableContentFilterSourceNone;
	}
}

- (void)setRuleEditorVisible:(BOOL)show animate:(BOOL)animate
{
	// we can't change the state of the button here, because the mouse click already changed it
	if((showFilterRuleEditor = show)) {
		[ruleFilterController setEnabled:YES];
		// if it was the user who enabled the filter (indicated by the animation) add an empty row by default
		if([ruleFilterController isEmpty] && animate) {
			[ruleFilterController addFilterExpression];
			// the sizing will be updated automatically by adding a row
		}
		else {
			[self updateFilterRuleEditorSize:[ruleFilterController preferredHeight] animate:animate];
		}
	}
	else {
		[ruleFilterController setEnabled:NO]; // disable it to not trigger any key bindings when hidden
		[self updateFilterRuleEditorSize:0.0 animate:animate];
	}
}

- (void)setUsedQuery:(NSString *)query
{
	if (usedQuery) [usedQuery release];
	usedQuery = [[NSString alloc] initWithString:query];
}

- (void)sortTableTaskWithColumn:(NSTableColumn *)tableColumn
{
	@autoreleasepool {
		// Check whether a save of the current row is required.
		if (![[self onMainThread] saveRowOnDeselect]) {
			// If the save failed, cancel the sort task and return
			[tableDocumentInstance endTask];
			return;
		}

		NSEventModifierFlags modifierFlags = [[NSApp currentEvent] modifierFlags];

		// Sets column order as tri-state descending, ascending, no sort, descending, ascending etc. order if the same
		// header is clicked several times
		if (sortCol && [[tableColumn identifier] integerValue] == [sortCol integerValue]) {
			BOOL invert = NO;
			if (modifierFlags & NSEventModifierFlagShift) {
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
			if (modifierFlags & NSEventModifierFlagShift) {
				isDesc = YES;
			} else {
				isDesc = NO;
			}

			[[tableContentView onMainThread] setIndicatorImage:nil inTableColumn:[tableContentView tableColumnWithIdentifier:[NSString stringWithFormat:@"%lld", (long long)[sortCol integerValue]]]];

			if (sortCol) [sortCol release];

			sortCol = [[NSNumber alloc] initWithInteger:[[tableColumn identifier] integerValue]];
		}

		SPMainQSync(^{
			if (sortCol) {
				// Set the highlight and indicatorImage
				[tableContentView setHighlightedTableColumn:tableColumn];

				if (isDesc) {
					[tableContentView setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:tableColumn];
				}
				else {
					[tableContentView setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:tableColumn];
				}
			}
			else {
				// If no sort order deselect column header and
				// remove indicator image
				[tableContentView setHighlightedTableColumn:nil];
				[tableContentView setIndicatorImage:nil inTableColumn:tableColumn];
			}
		});

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
			return;
		}

		[tableDocumentInstance endTask];
	}
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
		[paginationViewController setPage:@(contentPage - 1)];
	} else if (sender == paginationNextButton) {
		if ((NSInteger)contentPage * [prefs integerForKey:SPLimitResultsValue] >= maxNumRows) return;
		[paginationViewController setPage:@(contentPage + 1)];
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
		[paginationViewController makeInputFirstResponder];
	}
	else {
		[paginationButton setState:NSOffState];
		[paginationButton setImage:[NSImage imageNamed:@"button_pagination"]];
		// TODO This is only relevant in 10.6 legacy mode.
		// When using a modern NSPopover, the view controller's parent window is an _NSPopoverWindow,
		// not the SP window and we don't care what the first responder in the popover is.
		// (when it is not being displayed anyway).
		if (!paginationPopover && [paginationViewController isFirstResponderInside]) {
			[[[paginationViewController view] window] makeFirstResponder:nil];
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

	BOOL limitResults = [prefs boolForKey:SPLimitResults];
	// Set up the previous page button
	[paginationPreviousButton setEnabled:(limitResults && contentPage > 1 ? enabledMode : NO)];

	// Set up the next page button
	[paginationNextButton setEnabled:(limitResults && contentPage < maxPage ? enabledMode : NO)];

#ifndef SP_CODA
	// As long as a table is selected (which it will be if this is called), enable pagination detail button
	[paginationButton setEnabled:enabledMode];
#endif

	// "1" is the minimum page, so maxPage must not be less (which it would be for empty tables)
	if(maxPage < 1) maxPage = 1;

	// Set the values and maximums for the text field and associated pager
	[paginationViewController setPage:@(contentPage)];
	[paginationViewController setMaxPage:@(maxPage)];
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
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
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

	[alert beginSheetModalForWindow:[tableDocumentInstance parentWindow]
	                  modalDelegate:self
	                 didEndSelector:@selector(removeRowSheetDidEnd:returnCode:contextInfo:)
	                    contextInfo:contextInfo];
}

/**
 * Perform the requested row deletion action.
 */
- (void)removeRowSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
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
 *
 * MUST BE CALLED ON THE UI THREAD!
 */ 
- (NSArray *)currentDataResultWithNULLs:(BOOL)includeNULLs hideBLOBs:(BOOL)hide
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
			NSUInteger columnIndex = [[aTableColumn identifier] integerValue];
			id o = SPDataStorageObjectAtRowAndColumn(tableValues, i, columnIndex);
			
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
					if (hide) {
						str = @"&lt;BLOB&gt;";
					}
					else if ([self cellValueIsDisplayedAsHexForColumn:columnIndex]) {
						str = [NSString stringWithFormat:@"0x%@", [o dataToHexString]];
					}
					else {
						str = [o stringRepresentationUsingEncoding:[mySQLConnection stringEncoding]];
					}
					[tempRow addObject:str];
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
	@autoreleasepool {
		NSUInteger dataColumnIndex = [[[[tableContentView tableColumns] objectAtIndex:[theArrowCell getClickedColumn]] identifier] integerValue];
		BOOL tableFilterRequired = NO;

		// Ensure the clicked cell has foreign key details available
		NSDictionary *columnDefinition = [dataColumns objectAtIndex:dataColumnIndex];
		NSDictionary *refDictionary = [columnDefinition objectForKey:@"foreignkeyreference"];
		if (!refDictionary) {
			return;
		}

#ifndef SP_CODA
		// Save existing scroll position and details and mark that state is being modified
		[spHistoryControllerInstance updateHistoryEntries];
		[spHistoryControllerInstance setModifyingState:YES];
#endif

		id targetFilterValue = [tableValues cellDataAtRow:[theArrowCell getClickedRow] column:dataColumnIndex];

		//when navigating binary relations (eg. raw UUID) do so via a hex-encoded value for charset safety
		BOOL navigateAsHex = ([targetFilterValue isKindOfClass:[NSData class]] && [[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"binary"]);
		if(navigateAsHex) targetFilterValue = [mySQLConnection escapeData:(NSData *)targetFilterValue includingQuotes:NO];

		NSString *filterComparison = @"=";
		if([targetFilterValue isNSNull]) filterComparison = @"IS NULL";
		else if(navigateAsHex) filterComparison = @"= (Hex String)";

		// Store the filter details to use when loading the target table
		NSDictionary *filterSettings = [SPRuleFilterController makeSerializedFilterForColumn:[refDictionary objectForKey:@"column"]
		                                                                            operator:filterComparison
		                                                                              values:@[targetFilterValue]];

		// If the link is within the current table, apply filter settings manually
		if ([[refDictionary objectForKey:@"table"] isEqualToString:selectedTable]) {
			SPMainQSync(^{
				[ruleFilterController restoreSerializedFilters:filterSettings];
				[self setRuleEditorVisible:YES animate:YES];
				activeFilter = SPTableContentFilterSourceRuleFilter;
			});
			tableFilterRequired = YES;
		}
		else {
			SPMainQSync(^{
				[self setFiltersToRestore:filterSettings];
				[self setActiveFilterToRestore:SPTableContentFilterSourceRuleFilter];
				// Attempt to switch to the target table
				if (![tablesListInstance selectItemWithName:[refDictionary objectForKey:@"table"]]) {
					NSBeep();
					[self setFiltersToRestore:nil];
					[self setActiveFilterToRestore:SPTableContentFilterSourceNone];
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
		if (tableFilterRequired) [self performSelectorOnMainThread:@selector(filterTable:) withObject:self waitUntilDone:NO];
#endif
	}
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
	}
	// Report errors which have occurred
	else {
		SPBeginAlertSheet(
			NSLocalizedString(@"Unable to write row", @"Unable to write row error"),
			NSLocalizedString(@"Edit row", @"Edit row button"),
			NSLocalizedString(@"Discard changes", @"discard changes button"),
			nil,
			[tableDocumentInstance parentWindow],
			self,
			@selector(addRowErrorSheetDidEnd:returnCode:contextInfo:),
			NULL,
			[NSString stringWithFormat:NSLocalizedString(@"MySQL said:\n\n%@", @"message of panel when error while adding row to db"), [mySQLConnection lastErrorMessage]]
		);
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
	if (![[[[tableContentView window] firstResponder] undoManager] isUndoing] && ![[[[tableContentView window] firstResponder] undoManager] isRedoing]) { // -window is a UI method!
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
		[[self onMainThread] setTableDetails:tableDetails];
		isFirstChangeInView = NO;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];
	[tableDocumentInstance endTask];

	[self loadTableValues];
}

#pragma mark -
#pragma mark Filter Table

/**
 * Show filter table
 */
- (IBAction)showFilterTable:(id)sender
{
	[filterTableController showFilterTableWindow];
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
 *
 * MUST BE CALLED ON THE UI THREAD!
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
					[tableContentView selectedRowIndexes], @"rows", // -selectedRowIndexes is a UI method!
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
 *
 * MUST BE CALLED FROM THE UI THREAD!
 */
- (NSRect) viewport
{
	return [tableContentView visibleRect]; // UI method!
}

/**
 * Provide a getter for the table's list view width
 */
- (CGFloat) tablesListWidth
{
#warning Private ivar accessed from outside (#2978)
	return [[[[tableDocumentInstance valueForKey:@"contentViewSplitter"] subviews] objectAtIndex:0] frame].size.width;
}

/**
 * Provide a getter for the current filter details
 *
 * MUST BE CALLED ON THE UI THREAD!
 */
- (NSDictionary *) filterSettings
{
	return [ruleFilterController serializedFilter];
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
	[filterSettings retain];
	SPClear(filtersToRestore);
	filtersToRestore = filterSettings;
}

/**
 * Convenience method for storing all current settings for restoration
 *
 * MUST BE CALLED ON THE UI THREAD!
 */
- (void) storeCurrentDetailsForRestoration
{
	[self setSortColumnNameToRestore:[self sortColumnName] isAscending:[self sortColumnIsAscending]];
	[self setPageToRestore:[self pageNumber]];
	[self setSelectionToRestore:[self selectionDetailsAllowingIndexSelection:YES]];
	[self setViewportToRestore:[self viewport]];
	[self setFiltersToRestore:[self filterSettings]];
	[self setActiveFilterToRestore:activeFilter];
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
	[self setActiveFilterToRestore:SPTableContentFilterSourceNone];
}

- (NSData*) filterTableData
{
	return [filterTableController filterTableData];
}

- (void)setFilterTableData:(NSData *)arcData;
{
	[filterTableController setFilterTableData:arcData];
}

- (SPTableContentFilterSource)activeFilter
{
	return activeFilter;
}

- (void)setActiveFilterToRestore:(SPTableContentFilterSource)filter
{
	activeFilterToRestore = filter;
}

#pragma mark -
#pragma mark Table drawing and editing

- (void)updateFilterRuleEditorSize:(CGFloat)requestedHeight animate:(BOOL)animate
{
	NSRect contentAreaRect = [contentAreaContainer frame];
	CGFloat availableHeight = contentAreaRect.size.height;

	NSRect ruleEditorRect = [[[ruleFilterController view] enclosingScrollView] frame];

	//adjust for the UI elements below the rule editor, but only if the view should not be hidden
	CGFloat containerRequestedHeight = showFilterRuleEditor ? requestedHeight + ruleEditorRect.origin.y : 0;

	//the rule editor can ask for about one-third of the available space before we have it use it's scrollbar
	CGFloat topContainerGivenHeight = MIN(containerRequestedHeight,(availableHeight / 3));

	// abort if the size didn't really change
	NSRect topContainerRect = [filterRuleEditorContainer frame];
	if(topContainerGivenHeight == topContainerRect.size.height) return;

	CGFloat newBottomContainerHeight = availableHeight - topContainerGivenHeight;

	NSRect bottomContainerRect = [tableContentContainer frame];
	bottomContainerRect.size.height = newBottomContainerHeight;

	topContainerRect.origin.y = newBottomContainerHeight;
	topContainerRect.size.height = topContainerGivenHeight;

	// this one should be inferable from the IB layout IMHO, but the OS gets it wrong
	ruleEditorRect.size.height = topContainerGivenHeight - ruleEditorRect.origin.y;

	if(animate) {
		[NSAnimationContext beginGrouping];
		[[tableContentContainer animator] setFrame:bottomContainerRect];
		[[filterRuleEditorContainer animator] setFrame:topContainerRect];
		[[[[ruleFilterController view] enclosingScrollView] animator] setFrame:ruleEditorRect];
		[NSAnimationContext endGrouping];
	}
	else {
		[tableContentContainer setFrameSize:bottomContainerRect.size];
		[filterRuleEditorContainer setFrame:topContainerRect];
		[[[ruleFilterController view] enclosingScrollView] setFrame:ruleEditorRect];
	}

	//disable rubberband scrolling as long as there is nothing to scroll
	if(scrollViewHasRubberbandScrolling) {
		NSScrollView *filterControllerScroller = [[ruleFilterController view] enclosingScrollView];
		if (ruleEditorRect.size.height >= requestedHeight) {
			[filterControllerScroller setVerticalScrollElasticity:NSScrollElasticityNone];
		} else {
			[filterControllerScroller setVerticalScrollElasticity:NSScrollElasticityAutomatic];
		}
	}
}

- (void)filterRuleEditorPreferredSizeChanged:(NSNotification *)notification
{
	if(showFilterRuleEditor) {
		[self updateFilterRuleEditorSize:[ruleFilterController preferredHeight] animate:YES];
	}
}

- (void)contentViewSizeChanged:(NSNotification *)notification
{
	if(showFilterRuleEditor) {
		[self updateFilterRuleEditorSize:[ruleFilterController preferredHeight] animate:NO];
	}
}

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
#warning Private ivar accessed from outside (#2978)
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
	[ruleFilterController setEnabled:NO];
	[toggleRuleFilterButton setEnabled:NO];
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

	[ruleFilterController setEnabled:(!![selectedTable length])];
	[toggleRuleFilterButton setEnabled:(!![selectedTable length])];
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
	// a parent class (or cocoa) can also use KVO, so we need to watch out to only catch those KVO messages we requested
	if(context == TableContentKVOContext) {
		// Display table veiew vertical gridlines preference changed
		if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
			[tableContentView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
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
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
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
#pragma mark TableView datasource methods

- (NSInteger)numberOfRowsInTableView:(SPCopyTable *)tableView
{
	if (tableView == tableContentView) {
		return tableRowsCount;
	}

	return 0;
}

- (id)tableView:(SPCopyTable *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	NSUInteger columnIndex = [[tableColumn identifier] integerValue];
	if (tableView == tableContentView) {

		id value = nil;

		// While the table is being loaded, additional validation is required - data
		// locks must be used to avoid crashes, and indexes higher than the available
		// rows or columns may be requested.  Return "..." to indicate loading in these
		// cases.
		if (isWorking) {
			pthread_mutex_lock(&tableValuesLock);

			if (rowIndex < (NSInteger)tableRowsCount && columnIndex < [tableValues columnCount]) {
				value = [self _contentValueForTableColumn:columnIndex row:rowIndex asPreview:YES];
			}

			pthread_mutex_unlock(&tableValuesLock);

			if (!value) return @"...";
		}
		else {
			if ([tableView editedColumn] == (NSInteger)columnIndex && [tableView editedRow] == rowIndex) {
				value = [self _contentValueForTableColumn:columnIndex row:rowIndex asPreview:NO];
			}
			else {
				value = [self _contentValueForTableColumn:columnIndex row:rowIndex asPreview:YES];
			}
		}

		if ([value isKindOfClass:[SPMySQLGeometryData class]]) {
			return [value wktString];
		}

		if ([value isNSNull]) {
			return [prefs objectForKey:SPNullValue];
		}

		if ([value isKindOfClass:[NSData class]]) {

			if ([self cellValueIsDisplayedAsHexForColumn:columnIndex]) {
				if ([(NSData *)value length] > 255) {
					return [NSString stringWithFormat:@"0x%@…", [[(NSData *)value subdataWithRange:NSMakeRange(0, 255)] dataToHexString]];
				}
				return [NSString stringWithFormat:@"0x%@", [(NSData *)value dataToHexString]];
			}

			pthread_mutex_t *fieldEditorCheckLock = NULL;
			if (isWorking) {
				fieldEditorCheckLock = &tableValuesLock;
			}

			// Unless we're editing, always retrieve the short string representation, truncating the value where necessary
			if ([tableView editedColumn] == (NSInteger)columnIndex || [tableView editedRow] == rowIndex) {
				return [value stringRepresentationUsingEncoding:[mySQLConnection stringEncoding]];
			} else {
				return [value shortStringRepresentationUsingEncoding:[mySQLConnection stringEncoding]];
			}
		}

		if ([value isSPNotLoaded]) {
			return NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields");
		}

		return value;
	}

	return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (tableView == tableContentView) {
		NSInteger columnIndex = [[tableColumn identifier] integerValue];
		// If the current cell should have been edited in a sheet, do nothing - field closing will have already
		// updated the field.
		if ([tableContentView shouldUseFieldEditorForRow:rowIndex column:columnIndex checkWithLock:NULL]) {
			return;
		}

		// If table data comes from a view, save back to the view
		if ([tablesListInstance tableType] == SPTableTypeView) {
			[self saveViewCellValue:object forTableColumn:tableColumn row:rowIndex];
			return;
		}

		// Catch editing events in the row and if the row isn't currently being edited,
		// start an edit.  This allows edits including enum changes to save correctly.
		if (isEditingRow && [tableContentView selectedRow] != currentlyEditingRow) {
			[self saveRowOnDeselect];
		}

		if (!isEditingRow) {
			[oldRow setArray:[tableValues rowContentsAtIndex:rowIndex]];

			isEditingRow = YES;
			currentlyEditingRow = rowIndex;
		}

		NSDictionary *column = NSArrayObjectAtIndex(dataColumns, columnIndex);

		if (object) {
			// Restore NULLs if necessary
			if ([object isEqualToString:[prefs objectForKey:SPNullValue]] && [[column objectForKey:@"null"] boolValue]) {
				object = [NSNull null];
			}
			else if ([self cellValueIsDisplayedAsHexForColumn:columnIndex]) {
				// This is a binary object being edited as a hex string.
				// Convert the string back to binary.
				// Error checking is done in -control:textShouldEndEditing:
				NSData *data = [NSData dataWithHexString:object];
				if (!data) {
					NSBeep();
					return;
				}
				object = data;
			}

			[tableValues replaceObjectInRow:rowIndex column:columnIndex withObject:object];
		}
		else {
			[tableValues replaceObjectInRow:rowIndex column:columnIndex withObject:@""];
		}
	}
}

- (BOOL)cellValueIsDisplayedAsHexForColumn:(NSUInteger)columnIndex
{
	if (![prefs boolForKey:SPDisplayBinaryDataAsHex]) {
		return NO;
	}

	NSDictionary *columnDefinition = [[(id <SPDatabaseContentViewDelegate>)[tableContentView delegate] dataColumnDefinitions] objectAtIndex:columnIndex];
	NSString *typeGrouping = columnDefinition[@"typegrouping"];

	if ([typeGrouping isEqual:@"binary"]) {
		return YES;
	}

	if ([typeGrouping isEqual:@"blobdata"]) {
		return YES;
	}


	return NO;
}

#pragma mark - SPTableContentDataSource_Private_API

- (id)_contentValueForTableColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex asPreview:(BOOL)asPreview
{
	if (asPreview) {
		return SPDataStoragePreviewAtRowAndColumn(tableValues, rowIndex, columnIndex, 150);
	}

	return SPDataStorageObjectAtRowAndColumn(tableValues, rowIndex, columnIndex);
}

#pragma mark - SPTableContentFilter

#ifndef SP_CODA

/**
 * Makes the content filter field have focus by making it the first responder.
 */
- (void)makeContentFilterHaveFocus
{
	// don't show the filter UI if no table is selected - would result in invalid state
	if (!selectedTable || [selectedTable isEqualToString:@""]) {
		NSBeep();
		return;
	}
	
	[self setRuleEditorVisible:YES animate:YES];
	[toggleRuleFilterButton setState:NSOnState];
	[ruleFilterController focusFirstInputField];
}

#endif

#pragma mark -
#pragma mark TableView delegate methods

/**
 * Sorts the tableView by the clicked column. If clicked twice, order is altered to descending.
 * Performs the task in a new thread if necessary.
 */
- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	if ([selectedTable isEqualToString:@""] || !selectedTable || tableView != tableContentView) return;

	// Prevent sorting while the table is still loading
	if ([tableDocumentInstance isWorking]) return;

	// Start the task
	[tableDocumentInstance startTaskWithDescription:NSLocalizedString(@"Sorting table...", @"Sorting table task description")];

	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadWithName:SPCtxt(@"SPTableContent table sort task", tableDocumentInstance) target:self selector:@selector(sortTableTaskWithColumn:) object:tableColumn];
	}
	else {
		[self sortTableTaskWithColumn:tableColumn];
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	// Check our notification object is our table content view
	if ([aNotification object] != tableContentView) return;

	isFirstChangeInView = YES;

	[addButton setEnabled:([tablesListInstance tableType] == SPTableTypeTable)];

	// If we are editing a row, attempt to save that row - if saving failed, reselect the edit row.
	if (isEditingRow && [tableContentView selectedRow] != currentlyEditingRow && ![self saveRowOnDeselect]) return;

	if (![tableDocumentInstance isWorking]) {
		// Update the row selection count
		// and update the status of the delete/duplicate buttons
		if([tablesListInstance tableType] == SPTableTypeTable) {
			if ([tableContentView numberOfSelectedRows] > 0) {
				[duplicateButton setEnabled:([tableContentView numberOfSelectedRows] == 1)];
				[removeButton setEnabled:YES];
			}
			else {
				[duplicateButton setEnabled:NO];
				[removeButton setEnabled:NO];
			}
		}
		else {
			[duplicateButton setEnabled:NO];
			[removeButton setEnabled:NO];
		}
	}

	[self updateCountText];

#ifndef SP_CODA /* triggered commands */
	NSArray *triggeredCommands = [SPAppDelegate bundleCommandsForTrigger:SPBundleTriggerActionTableRowChanged];

	for (NSString *cmdPath in triggeredCommands)
	{
		NSArray *data = [cmdPath componentsSeparatedByString:@"|"];
		NSMenuItem *aMenuItem = [[[NSMenuItem alloc] init] autorelease];

		[aMenuItem setTag:0];
		[aMenuItem setToolTip:[data objectAtIndex:0]];

		// For HTML output check if corresponding window already exists
		BOOL stopTrigger = NO;

		if ([(NSString *)[data objectAtIndex:2] length]) {
			BOOL correspondingWindowFound = NO;
			NSString *uuid = [data objectAtIndex:2];

			for (id win in [NSApp windows])
			{
				if ([[[[win delegate] class] description] isEqualToString:@"SPBundleHTMLOutputController"]) {
					if ([[[win delegate] windowUUID] isEqualToString:uuid]) {
						correspondingWindowFound = YES;
						break;
					}
				}
			}

			if (!correspondingWindowFound) stopTrigger = YES;
		}
		if (!stopTrigger) {
			id firstResponder = [[NSApp keyWindow] firstResponder];
			if ([[data objectAtIndex:1] isEqualToString:SPBundleScopeGeneral]) {
				[[SPAppDelegate onMainThread] executeBundleItemForApp:aMenuItem];
			}
			else if ([[data objectAtIndex:1] isEqualToString:SPBundleScopeDataTable]) {
				if ([[[firstResponder class] description] isEqualToString:@"SPCopyTable"]) {
					[[firstResponder onMainThread] executeBundleItemForDataTable:aMenuItem];
				}
			}
			else if ([[data objectAtIndex:1] isEqualToString:SPBundleScopeInputField]) {
				if ([firstResponder isKindOfClass:[NSTextView class]]) {
					[[firstResponder onMainThread] executeBundleItemForInputField:aMenuItem];
				}
			}
		}
	}
#endif
}

/**
 * Saves the new column size in the preferences.
 */
- (void)tableViewColumnDidResize:(NSNotification *)notification
{
	// Check our notification object is our table content view
	if ([notification object] != tableContentView) return;

	// Sometimes the column has no identifier. I can't figure out what is causing it, so we just skip over this item
	if (![[[notification userInfo] objectForKey:@"NSTableColumn"] identifier]) return;

	NSMutableDictionary *tableColumnWidths;
	NSString *database = [NSString stringWithFormat:@"%@@%@", [tableDocumentInstance database], [tableDocumentInstance host]];
	NSString *table = [tablesListInstance tableName];

	// Get tableColumnWidths object
#ifndef SP_CODA
	if ([prefs objectForKey:SPTableColumnWidths] != nil ) {
		tableColumnWidths = [NSMutableDictionary dictionaryWithDictionary:[prefs objectForKey:SPTableColumnWidths]];
	}
	else {
#endif
		tableColumnWidths = [NSMutableDictionary dictionary];
#ifndef SP_CODA
	}
#endif

	// Get the database object
	if  ([tableColumnWidths objectForKey:database] == nil) {
		[tableColumnWidths setObject:[NSMutableDictionary dictionary] forKey:database];
	}
	else {
		[tableColumnWidths setObject:[NSMutableDictionary dictionaryWithDictionary:[tableColumnWidths objectForKey:database]] forKey:database];
	}

	// Get the table object
	if  ([[tableColumnWidths objectForKey:database] objectForKey:table] == nil) {
		[[tableColumnWidths objectForKey:database] setObject:[NSMutableDictionary dictionary] forKey:table];
	}
	else {
		[[tableColumnWidths objectForKey:database] setObject:[NSMutableDictionary dictionaryWithDictionary:[[tableColumnWidths objectForKey:database] objectForKey:table]] forKey:table];
	}

	// Save column size
	[[[tableColumnWidths objectForKey:database] objectForKey:table]
	 setObject:[NSNumber numberWithDouble:[(NSTableColumn *)[[notification userInfo] objectForKey:@"NSTableColumn"] width]]
	 forKey:[[[[notification userInfo] objectForKey:@"NSTableColumn"] headerCell] stringValue]];
#ifndef SP_CODA
	[prefs setObject:tableColumnWidths forKey:SPTableColumnWidths];
#endif
}

/**
 * Confirm whether to allow editing of a row. Returns YES by default, unless the multipleLineEditingButton is in
 * the ON state, or for blob or text fields - in those cases opens a sheet for editing instead and returns NO.
 */
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if ([tableDocumentInstance isWorking]) return NO;

	if (tableView == tableContentView) {

		// Nothing is editable while the field editor is running.
		// This guards against a special case where accessibility services might
		// check if a table field is editable while the sheet is running.
		if (fieldEditor) return NO;

		// Ensure that row is editable since it could contain "(not loaded)" columns together with
		// issue that the table has no primary key
		NSString *wherePart = [NSString stringWithString:[self argumentForRow:[tableContentView selectedRow]]];

		if (![wherePart length]) return NO;

		// If the selected cell hasn't been loaded, load it.
		if ([[tableValues cellDataAtRow:rowIndex column:[[tableColumn identifier] integerValue]] isSPNotLoaded]) {

			// Only get the data for the selected column, not all of them
			NSString *query = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@", [[[tableColumn headerCell] stringValue] backtickQuotedString], [selectedTable backtickQuotedString], wherePart];

			SPMySQLResult *tempResult = [mySQLConnection queryString:query];

			if (![tempResult numberOfRows]) {
				SPOnewayAlertSheet(
					NSLocalizedString(@"Error", @"error"),
					[tableDocumentInstance parentWindow],
					NSLocalizedString(@"Couldn't load the row. Reload the table to be sure that the row exists and use a primary key for your table.", @"message of panel when loading of row failed")
				);
				return NO;
			}

			NSArray *tempRow = [tempResult getRowAsArray];

			[tableValues replaceObjectInRow:rowIndex column:[[tableContentView tableColumns] indexOfObject:tableColumn] withObject:[tempRow objectAtIndex:0]];
			[tableContentView reloadData];
		}

		// Retrieve the column definition
		NSDictionary *columnDefinition = [cqColumnDefinition objectAtIndex:[[tableColumn identifier] integerValue]];

		// Open the editing sheet if required
		if ([tableContentView shouldUseFieldEditorForRow:rowIndex column:[[tableColumn identifier] integerValue] checkWithLock:NULL]) {

			BOOL isBlob = [tableDataInstance columnIsBlobOrText:[[tableColumn headerCell] stringValue]];

			// A table is per definition editable
			BOOL isFieldEditable = YES;

			// Check for Views if field is editable
			if ([tablesListInstance tableType] == SPTableTypeView) {
				NSArray *editStatus = [self fieldEditStatusForRow:rowIndex andColumn:[[tableColumn identifier] integerValue]];
				isFieldEditable = [[editStatus objectAtIndex:0] integerValue] == 1;
			}

			NSUInteger fieldLength = 0;
			NSString *fieldEncoding = nil;
			BOOL allowNULL = YES;

			NSString *fieldType = [columnDefinition objectForKey:@"type"];

			if ([columnDefinition objectForKey:@"char_length"]) {
				fieldLength = [[columnDefinition objectForKey:@"char_length"] integerValue];
			}

			if ([columnDefinition objectForKey:@"null"]) {
				allowNULL = (![[columnDefinition objectForKey:@"null"] integerValue]);
			}

			if ([columnDefinition objectForKey:@"charset_name"] && ![[columnDefinition objectForKey:@"charset_name"] isEqualToString:@"binary"]) {
				fieldEncoding = [columnDefinition objectForKey:@"charset_name"];
			}

			fieldEditor = [[SPFieldEditorController alloc] init];

			[fieldEditor setEditedFieldInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											 [[tableColumn headerCell] stringValue], @"colName",
											 [self usedQuery], @"usedQuery",
											 @"content", @"tableSource",
											 nil]];

			[fieldEditor setTextMaxLength:fieldLength];
			[fieldEditor setFieldType:fieldType == nil ? @"" : fieldType];
			[fieldEditor setFieldEncoding:fieldEncoding == nil ? @"" : fieldEncoding];
			[fieldEditor setAllowNULL:allowNULL];

			id cellValue = [tableValues cellDataAtRow:rowIndex column:[[tableColumn identifier] integerValue]];

			if ([cellValue isNSNull]) {
				cellValue = [NSString stringWithString:[prefs objectForKey:SPNullValue]];
			}

			if ([self cellValueIsDisplayedAsHexForColumn:[[tableColumn identifier] integerValue]]) {
				[fieldEditor setTextMaxLength:[[self tableView:tableContentView objectValueForTableColumn:tableColumn row:rowIndex] length]];
				isFieldEditable = NO;
			}

			NSInteger editedColumn = 0;

			for (NSTableColumn* col in [tableContentView tableColumns])
			{
				if ([[col identifier] isEqualToString:[tableColumn identifier]]) break;

				editedColumn++;
			}

			[fieldEditor editWithObject:cellValue
			                  fieldName:[[tableColumn headerCell] stringValue]
			              usingEncoding:[mySQLConnection stringEncoding]
			               isObjectBlob:isBlob
			                 isEditable:isFieldEditable
			                 withWindow:[tableDocumentInstance parentWindow]
			                     sender:self
			                contextInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:rowIndex], @"rowIndex",
			                                                                       [NSNumber numberWithInteger:editedColumn], @"columnIndex",
			                                                                       [NSNumber numberWithBool:isFieldEditable], @"isFieldEditable",
			                                                                       nil]];

			return NO;
		}

		return YES;
	}

	return YES;
}

/**
 * Enable drag from tableview
 */
- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard*)pboard
{
	if (tableView == tableContentView) {
		NSString *tmp;

		// By holding ⌘, ⇧, or/and ⌥ copies selected rows as SQL INSERTS
		// otherwise \t delimited lines
		if ([[NSApp currentEvent] modifierFlags] & (NSEventModifierFlagCommand|NSEventModifierFlagShift|NSEventModifierFlagOption)) {
			tmp = [tableContentView rowsAsSqlInsertsOnlySelectedRows:YES];
		}
		else {
			tmp = [tableContentView draggedRowsAsTabString];
		}

		if (tmp && [tmp length])
		{
			[pboard declareTypes:@[NSTabularTextPboardType, NSStringPboardType] owner:nil];

			[pboard setString:tmp forType:NSStringPboardType];
			[pboard setString:tmp forType:NSTabularTextPboardType];

			return YES;
		}
	}

	return NO;
}

/**
 * Disable row selection while the document is working.
 */
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex
{
	return tableView == tableContentView ? tableRowsSelectable : YES;
}

/**
 * Resize a column when it's double-clicked (10.6+ only).
 */
- (CGFloat)tableView:(NSTableView *)tableView sizeToFitWidthOfColumn:(NSInteger)columnIndex
{
	NSTableColumn *theColumn = [[tableView tableColumns] objectAtIndex:columnIndex];
	NSDictionary *columnDefinition = [dataColumns objectAtIndex:[[theColumn identifier] integerValue]];

	// Get the column width
	NSUInteger targetWidth = [tableContentView autodetectWidthForColumnDefinition:columnDefinition maxRows:500];

#ifndef SP_CODA
	// Clear any saved widths for the column
	NSString *dbKey = [NSString stringWithFormat:@"%@@%@", [tableDocumentInstance database], [tableDocumentInstance host]];
	NSString *tableKey = [tablesListInstance tableName];
	NSMutableDictionary *savedWidths = [NSMutableDictionary dictionaryWithDictionary:[prefs objectForKey:SPTableColumnWidths]];
	NSMutableDictionary *dbDict = [NSMutableDictionary dictionaryWithDictionary:[savedWidths objectForKey:dbKey]];
	NSMutableDictionary *tableDict = [NSMutableDictionary dictionaryWithDictionary:[dbDict objectForKey:tableKey]];

	if ([tableDict objectForKey:[columnDefinition objectForKey:@"name"]]) {
		[tableDict removeObjectForKey:[columnDefinition objectForKey:@"name"]];

		if ([tableDict count]) {
			[dbDict setObject:[NSDictionary dictionaryWithDictionary:tableDict] forKey:tableKey];
		}
		else {
			[dbDict removeObjectForKey:tableKey];
		}

		if ([dbDict count]) {
			[savedWidths setObject:[NSDictionary dictionaryWithDictionary:dbDict] forKey:dbKey];
		}
		else {
			[savedWidths removeObjectForKey:dbKey];
		}

		[prefs setObject:[NSDictionary dictionaryWithDictionary:savedWidths] forKey:SPTableColumnWidths];
	}
#endif

	// Return the width, while the delegate is empty to prevent column resize notifications
	[tableContentView setDelegate:nil];
	[tableContentView performSelector:@selector(setDelegate:) withObject:self afterDelay:0.1];

	return targetWidth;
}

/**
 * This function changes the text color of text/blob fields which are null or not yet loaded to gray
 */
- (void)tableView:(SPCopyTable *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (tableView == tableContentView) {

		if (![cell respondsToSelector:@selector(setTextColor:)]) return;

		BOOL cellIsNullOrUnloaded = NO;
		BOOL cellIsLinkCell = [cell isMemberOfClass:[SPTextAndLinkCell class]];

		NSUInteger columnIndex = [[tableColumn identifier] integerValue];

		// If user wants to edit 'cell' set text color to black and return to avoid
		// writing in gray if value was NULL
		if ([tableView editedColumn] != -1
			&& [tableView editedRow] == rowIndex
			&& (NSUInteger)[[NSArrayObjectAtIndex([tableView tableColumns], [tableView editedColumn]) identifier] integerValue] == columnIndex) {
			[cell setTextColor:textForegroundColor];
			if (cellIsLinkCell) [cell setLinkActive:NO];
			return;
		}

		// While the table is being loaded, additional validation is required - data
		// locks must be used to avoid crashes, and indexes higher than the available
		// rows or columns may be requested.  Use gray to indicate loading in these cases.
		if (isWorking) {
			pthread_mutex_lock(&tableValuesLock);

			if (rowIndex < (NSInteger)tableRowsCount && columnIndex < [tableValues columnCount]) {
				cellIsNullOrUnloaded = [tableValues cellIsNullOrUnloadedAtRow:rowIndex column:columnIndex];
			}

			pthread_mutex_unlock(&tableValuesLock);
		}
		else {
			cellIsNullOrUnloaded = [tableValues cellIsNullOrUnloadedAtRow:rowIndex column:columnIndex];
		}

		if (cellIsNullOrUnloaded) {
			[cell setTextColor:(rowIndex == [tableContentView selectedRow] ? textForegroundColor : nullHighlightColor)];
		}
		else {
			[cell setTextColor:textForegroundColor];

			if (
				[self cellValueIsDisplayedAsHexForColumn:[[tableColumn identifier] integerValue]] &&
				rowIndex != [tableContentView selectedRow]
			) {
				[cell setTextColor:binhexHighlightColor];
			}
		}

		// Disable link arrows for the currently editing row and for any NULL or unloaded cells
		if (cellIsLinkCell) {
			if (cellIsNullOrUnloaded || [tableView editedRow] == rowIndex) {
				[cell setLinkActive:NO];
			}
			else {
				[cell setLinkActive:YES];
			}
		}
	}
}

#ifndef SP_CODA
/**
 * Show the table cell content as tooltip
 *
 * - for text displays line breaks and tabs as well
 * - if blob data can be interpret as image data display the image as  transparent thumbnail
 *   (up to now using base64 encoded HTML data).
 */
- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(id)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation
{
	if (tableView == tableContentView) {

		if ([[aCell stringValue] length] < 2 || [tableDocumentInstance isWorking]) return nil;

		// Suppress tooltip if another toolip is already visible, mainly displayed by a Bundle command
		// TODO has to be improved
		for (id win in [NSApp orderedWindows])
		{
			if ([[[[win contentView] class] description] isEqualToString:@"WebView"]) return nil;
		}

		NSImage *image;

		NSPoint pos = [NSEvent mouseLocation];
		pos.y -= 20;

		id theValue = nil;

		// While the table is being loaded, additional validation is required - data
		// locks must be used to avoid crashes, and indexes higher than the available
		// rows or columns may be requested.  Return "..." to indicate loading in these
		// cases.
		if (isWorking) {
			pthread_mutex_lock(&tableValuesLock);

			if (row < (NSInteger)tableRowsCount && [[tableColumn identifier] integerValue] < (NSInteger)[tableValues columnCount]) {
				theValue = [[SPDataStorageObjectAtRowAndColumn(tableValues, row, [[tableColumn identifier] integerValue]) copy] autorelease];
			}

			pthread_mutex_unlock(&tableValuesLock);

			if (!theValue) theValue = @"...";
		}
		else {
			theValue = SPDataStorageObjectAtRowAndColumn(tableValues, row, [[tableColumn identifier] integerValue]);
		}

		if (theValue == nil) return nil;

		if ([theValue isKindOfClass:[NSData class]]) {
			image = [[[NSImage alloc] initWithData:theValue] autorelease];

			if (image) {
				[SPTooltip showWithObject:image atLocation:pos ofType:@"image"];
				return nil;
			}
		}
		else if ([theValue isKindOfClass:[SPMySQLGeometryData class]]) {
			SPGeometryDataView *v = [[SPGeometryDataView alloc] initWithCoordinates:[theValue coordinates]];
			image = [v thumbnailImage];

			if (image) {
				[SPTooltip showWithObject:image atLocation:pos ofType:@"image"];
				[v release];
				return nil;
			}

			[v release];
		}

		// Show the cell string value as tooltip (including line breaks and tabs)
		// by using the cell's font
		[SPTooltip showWithObject:[aCell stringValue]
		               atLocation:pos
		                   ofType:@"text"
		           displayOptions:[NSDictionary dictionaryWithObjectsAndKeys:[[aCell font] familyName], @"fontname",
		                                                                     [NSString stringWithFormat:@"%f", [[aCell font] pointSize]], @"fontsize",
		                                                                     nil]];

		return nil;
	}

	return nil;
}
#endif

#pragma mark -
#pragma mark Control delegate methods

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)editor
{
	// Validate hex input
	// We do this here because the textfield will still be selected with the pending changes if we bail out here
	if(control == tableContentView) {
		NSInteger columnIndex = [tableContentView editedColumn];
		if ([self cellValueIsDisplayedAsHexForColumn:columnIndex]) {
			// special case: the "NULL" string
			NSDictionary *column = NSArrayObjectAtIndex(dataColumns, columnIndex);
			if ([[editor string] isEqualToString:[prefs objectForKey:SPNullValue]] && [[column objectForKey:@"null"] boolValue]) {
				return YES;
			}
			// This is a binary object being edited as a hex string.
			// Convert the string back to binary, checking for errors.
			NSData *data = [NSData dataWithHexString:[editor string]];
			if (!data) {
				SPOnewayAlertSheet(
								   NSLocalizedString(@"Invalid hexadecimal value", @"table content : editing : error message title when parsing as hex string failed"),
								   [tableDocumentInstance parentWindow],
								   NSLocalizedString(@"A valid hex string may only contain the numbers 0-9 and letters A-F (a-f). It can optionally begin with „0x“ and spaces will be ignored.\nAlternatively the syntax X'val' is supported, too.", @"table content : editing : error message description when parsing as hex string failed")
								   );
				return NO;
			}
		}
	}
	return YES;
}

/**
 * If the user selected a table cell which is a blob field and tried to edit it
 * cancel the inline edit, display the field editor sheet instead for editing
 * and re-enable inline editing after closing the sheet.
 */
- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)aFieldEditor
{
	if (control != tableContentView) return YES;

	NSUInteger row, column;
	BOOL shouldBeginEditing = YES;

	row = [tableContentView editedRow];
	column = [tableContentView editedColumn];

	// If cell editing mode and editing request comes
	// from the keyboard show an error tooltip
	// or bypass if numberOfPossibleUpdateRows == 1
	if ([tableContentView isCellEditingMode]) {

		NSArray *editStatus = [self fieldEditStatusForRow:row andColumn:[[NSArrayObjectAtIndex([tableContentView tableColumns], column) identifier] integerValue]];
		NSInteger numberOfPossibleUpdateRows = [[editStatus objectAtIndex:0] integerValue];
		NSPoint pos = [[tableDocumentInstance parentWindow] convertBaseToScreen:[tableContentView convertPoint:[tableContentView frameOfCellAtColumn:column row:row].origin toView:nil]];

		pos.y -= 20;

		switch (numberOfPossibleUpdateRows)
		{
			case -1:
				[SPTooltip showWithObject:kCellEditorErrorNoMultiTabDb
							   atLocation:pos
								   ofType:@"text"];
				shouldBeginEditing = NO;
				break;
			case 0:
				[SPTooltip showWithObject:[NSString stringWithFormat:kCellEditorErrorNoMatch, selectedTable]
							   atLocation:pos
								   ofType:@"text"];
				shouldBeginEditing = NO;
				break;
			case 1:
				shouldBeginEditing = YES;
				break;
			default:
				[SPTooltip showWithObject:[NSString stringWithFormat:kCellEditorErrorTooManyMatches, (long)numberOfPossibleUpdateRows]
							   atLocation:pos
								   ofType:@"text"];
				shouldBeginEditing = NO;
		}

	}

	// Open the field editor sheet if required
	if ([tableContentView shouldUseFieldEditorForRow:row column:column checkWithLock:NULL])
	{
		[tableContentView setFieldEditorSelectedRange:[aFieldEditor selectedRange]];

		// Cancel editing
		[control abortEditing];

		NSAssert(fieldEditor == nil, @"Method should not to be called while a field editor sheet is open!");
		// Call the field editor sheet
		[self tableView:tableContentView shouldEditTableColumn:NSArrayObjectAtIndex([tableContentView tableColumns], column) row:row];

		// send current event to field editor sheet
		if ([NSApp currentEvent]) {
			[NSApp sendEvent:[NSApp currentEvent]];
		}

		return NO;
	}

	return shouldBeginEditing;
}

/**
 * Trap the enter, escape, tab and arrow keys, overriding default behaviour and continuing/ending editing,
 * only within the current row.
 */
- (BOOL)control:(NSControl<NSControlTextEditingDelegate> *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	// Check firstly if SPCopyTable can handle command
	if ([control control:control textView:textView doCommandBySelector:command])
		return YES;

	// Trap the escape key
	if ([[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(cancelOperation:)]) {
		// Abort editing
		[control abortEditing];

		if ((SPCopyTable*)control == tableContentView) {
			[self cancelRowEditing];
		}

		return YES;
	}

	return NO;
}

#pragma mark -
#pragma mark Database content view delegate methods

- (NSString *)usedQuery
{
	return usedQuery;
}

/**
 * Retrieve the data column definitions
 */
- (NSArray *)dataColumnDefinitions
{
	return dataColumns;
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if(_mainNibLoaded) {
		//TODO this should be changed to the variant with …context: after 10.6 support is removed!
		[prefs removeObserver:self forKeyPath:SPGlobalResultTableFont];
		[prefs removeObserver:self forKeyPath:SPDisplayBinaryDataAsHex];
		[prefs removeObserver:self forKeyPath:SPDisplayTableViewVerticalGridlines];
	}

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
	SPClear(paginationPopover);
	SPClear(paginationViewController);

#endif
	if (selectedTable)          SPClear(selectedTable);
	if (keys)                   SPClear(keys);
	if (sortCol)                SPClear(sortCol);
	SPClear(usedQuery);
	if (sortColumnToRestore)    SPClear(sortColumnToRestore);
	if (selectionToRestore)     SPClear(selectionToRestore);
	if (cqColumnDefinition)     SPClear(cqColumnDefinition);

	SPClear(filtersToRestore);

	[super dealloc];
}

@end

#pragma mark -

@implementation ContentPaginationViewController

@synthesize page = page;
@synthesize maxPage = maxPage;
@synthesize target = target;
@synthesize action = action;

- (instancetype)init
{
	if((self = [super initWithNibName:@"ContentPaginationView" bundle:nil])) {
		[self setPage:@1];
		[self setMaxPage:@1];
	}
	return self;
}

- (IBAction)paginationGoAction:(id)sender
{
	if(target && action) [target performSelector:action withObject:self];
}

- (void)makeInputFirstResponder
{
	[[paginationPageField window] makeFirstResponder:paginationPageField];
}

- (BOOL)isFirstResponderInside
{
	NSResponder *firstResponder = [[paginationPageField window] firstResponder];
	return (
		[firstResponder isKindOfClass:[NSView class]] &&
		[(NSView *)firstResponder isDescendantOf:[self view]]
	);
}

- (void)dealloc
{
	[self setPage:nil];
	[self setMaxPage:nil];
	[super dealloc];
}

@end

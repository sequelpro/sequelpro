//
//  SPFilterTableController.h
//  sequel-pro
//
//  Created by Max Lohrmann on 07.05.18.
//  Copyright (c) 2018 Max Lohrmann. All rights reserved.
//  Relocated from existing files. Previous copyright applies.
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

@class SPSplitView;
@class SPCopyTable;
@class SPTextView;

@interface SPFilterTableController : NSWindowController
{
	IBOutlet SPSplitView *filterTableSplitView;
	IBOutlet NSButton *filterTableFilterButton;
	IBOutlet NSButton *filterTableClearButton;
	IBOutlet NSButton *filterTableSearchAllFields;

	IBOutlet SPCopyTable *filterTableView;

	IBOutlet NSButton *filterTableLiveSearchCheckbox;
	IBOutlet NSButton *filterTableNegateCheckbox;
	IBOutlet NSButton *filterTableDistinctCheckbox;

	IBOutlet NSTextField *filterTableQueryTitle;
	IBOutlet SPTextView *filterTableWhereClause;

	IBOutlet NSPanel *filterTableSetDefaultOperatorSheet;
	IBOutlet NSComboBox* filterTableSetDefaultOperatorValue;

	NSUserDefaults *prefs;

	NSMutableDictionary *filterTableData;
	BOOL filterTableNegate;
	BOOL filterTableDistinct;
	BOOL filterTableIsSwapped;
	NSString *filterTableDefaultOperator;
	NSString *lastEditedFilterTableValue;

	id target;
	SEL action;
}

/**
 * Puts the filter table window on screen
 *
 * MUST BE CALLED ON THE UI THREAD!
 */
- (void)showFilterTableWindow;

/**
 * Restores filter table content state from serialized data
 *
 * MUST BE CALLED ON THE UI THREAD!
 */
- (void)setFilterTableData:(NSData *)arcData;

/**
 * Returns the current contents of the filter table window as serialized data
 *
 * MUST BE CALLED ON THE UI THREAD!
 */
- (NSData *)filterTableData;

/**
 * The SQL expression to use as filter.
 * Can be nil if no filter is set!
 *
 * MUST BE CALLED ON THE UI THREAD!
 */
- (NSString *)tableFilterString;

/**
 * Will reconfigure the columns of the filter table view from the given array.
 * Call with nil to reset the table view to its initial empty state.
 *
 * MUST BE CALLED ON THE UI THREAD!
 */
- (void)setColumns:(NSArray *)dataColumns;

/**
 * Will return YES if the SQL expression returned by -tableFilterString should be
 * used in a "SELECT DISTINCT …" query.
 *
 * Results may be inconsistent if not called on the main thread!
 */
- (BOOL)isDistinct;

/**
 * Use this method to make the filter window indicate an error state after executing the filter.
 * Pass 0 for error ID to indicate an OK state.
 *
 * MUST BE CALLED ON THE UI THREAD!
 */
- (void)setFilterError:(NSUInteger)errorID message:(NSString *)message sqlstate:(NSString *)sqlstate;

/**
 * Used when the filter table window wants to trigger filtering
 *
 * Results may be inconsistent if not called on the main thread!
 */
@property (assign, nonatomic) id target;
@property (assign, nonatomic) SEL action;

@end

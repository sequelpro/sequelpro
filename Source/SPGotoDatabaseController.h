//
//  GotoDatbaseController.h
//  sequel-pro
//
//  Created by Max Lohrmann on 12.10.14.
//  Copyright (c) 2014 Max Lohrmann. All rights reserved.
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

#import <Cocoa/Cocoa.h>

/**
 * This class provides a dialog with a single-column table view and a
 * search field. It can be used for finding databases by name and/or faster,
 * keyboard-based navigation between databases. The dialog also enables
 * jumping to a database by C&P-ing its full name.
 */
@interface SPGotoDatabaseController : NSWindowController <NSTableViewDataSource,NSTableViewDelegate,NSControlTextEditingDelegate,NSUserInterfaceValidations>
{
	IBOutlet NSSearchField *searchField;
	IBOutlet NSButton *okButton;
	IBOutlet NSButton *cancelButton;
	IBOutlet NSTableView *databaseListView;
	
	NSMutableArray *unfilteredList;
	NSMutableArray *filteredList;

	BOOL isFiltered;
	BOOL allowCustomNames;
	
	NSDictionary *highlightAttrs;
}

/**
 * Specifies whether custom names (i.e. names that were not in the list supplied
 * by setDatabaseList:) will be allowed. This is useful if it has to be assumed
 * that the list of databases is not exhaustive (eg. databases added after fetching
 * the database list).
 */
@property BOOL allowCustomNames;

/**
 * Set the list of databases the user can pick from.
 * @param list An array of NSStrings, will be shallow-copied
 *
 * This method must be called before runModal. The list will not be updated
 * while the dialog is on screen.
 */
- (void)setDatabaseList:(NSArray *)list;

/**
 * Retrieve the user selection.
 * @return The selected database or nil, if there is no selection
 *
 * This method retrieves the database selected by the user. Note that this is
 * not neccesarily one of the objects which were passed in, if allowCustomNames
 * is enabled. The return value of this function is undefined after calling
 * setDatabaseList:!
 */
- (NSString *)selectedDatabase;

/**
 * Starts displaying the dialog as application modal.
 * @return YES if the user pressed "OK", NO otherwise
 *
 * This method will only return once the dialog was closed again.
 */
- (BOOL)runModal;

@end

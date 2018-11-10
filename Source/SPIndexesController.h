//
//  SPIndexesController.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on June 13, 2010.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

@class SPDatabaseDocument;
@class SPTablesList;
@class SPTableData;
@class SPTableStructure;
@class SPMySQLConnection;
@class SPTableView;

@interface SPIndexesController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource, NSComboBoxCellDataSource>
{
	// Controllers
	IBOutlet SPDatabaseDocument *dbDocument;
	IBOutlet SPTableStructure *tableStructure;
	IBOutlet SPTablesList *tablesList;
	IBOutlet SPTableData *tableData;
	
	// Index table view
	IBOutlet SPTableView *indexesTableView;
	IBOutlet NSButton *addIndexButton;
	IBOutlet NSButton *removeIndexButton;
	
	// New index sheet
	IBOutlet NSPopUpButton *indexTypePopUpButton;
	IBOutlet NSTextField *indexNameTextField;
	IBOutlet NSTableView *indexedColumnsTableView;
	IBOutlet NSScrollView *indexedColumnsScrollView;
	IBOutlet NSTextField *indexTypeLabel;
	IBOutlet NSTextField *indexNameLabel;
	IBOutlet NSTableColumn *indexSizeTableColumn;
	IBOutlet NSButton *addIndexedColumnButton;
	IBOutlet NSButton *removeIndexedColumnButton;
	IBOutlet NSButton *confirmAddIndexButton;
	IBOutlet NSBox *anchoredButtonBar;
	
	// Advanced options view
	IBOutlet NSButton *indexAdvancedOptionsViewButton;
	IBOutlet NSView *indexAdvancedOptionsView;
	IBOutlet NSButton *indexAdvancedOptionsViewLabelButton;
	IBOutlet NSPopUpButton *indexStorageTypePopUpButton;
	IBOutlet NSTextField *indexKeyBlockSizeTextField;
		
	BOOL mainNibLoaded;
	BOOL isMyISAMTable;
	BOOL isInnoDBTable;
	NSString *table;
	
	NSMutableArray *fields, *indexes, *indexedFields;
	NSArray *supportsLength, *requiresLength;
	
	NSUserDefaults *prefs;
	
	SPMySQLConnection *connection;

	BOOL showAdvancedView;
	
	NSInteger heightOffset;
	NSUInteger windowMinWidth;
	NSUInteger windowMinHeigth;
}

/**
 * @property table The table currently being viewed
 */
@property (readwrite, retain) NSString *table;

/**
 * @property connection The MySQL connection to use
 */
@property (readwrite, assign) SPMySQLConnection *connection;

- (IBAction)addIndex:(id)sender;
- (IBAction)removeIndex:(id)sender;
- (IBAction)chooseIndexType:(id)sender;
- (IBAction)closeSheet:(id)sender;

- (IBAction)addIndexedField:(id)sender;
- (IBAction)removeIndexedField:(id)sender;
- (IBAction)toggleAdvancedIndexOptionsView:(id)sender;

- (void)setFields:(NSArray *)tableFields;
- (void)setIndexes:(NSArray *)tableIndexes;

@end

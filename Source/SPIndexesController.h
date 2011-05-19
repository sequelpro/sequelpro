//
//  $Id$
//
//  SPIndexesController.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on June 13, 2010
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

#ifndef SP_REFACTOR
@class SPDatabaseDocument, SPTablesList, SPTableData, SPTableStructure, MCPConnection, BWAnchoredButtonBar, SPTableView;
#else
@class SPDatabaseDocument, SPTablesList, SPTableData, SPTableStructure, MCPConnection, SPTableView;
#endif

#ifndef SP_REFACTOR
@interface SPIndexesController : NSWindowController 
#else
@interface SPIndexesController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource>
#endif
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
#ifndef SP_REFACTOR
	IBOutlet BWAnchoredButtonBar *anchoredButtonBar;
	
	// Advanced options view
	IBOutlet NSButton *indexAdvancedOptionsViewButton;
	IBOutlet NSView *indexAdvancedOptionsView;
	IBOutlet NSButton *indexAdvancedOptionsViewLabelButton;
	IBOutlet NSPopUpButton *indexStorageTypePopUpButton;
	IBOutlet NSTextField *indexKeyBlockSizeTextField;
#endif
		
	NSString *table;
	
	NSMutableArray *fields, *indexes, *indexedFields, *supportsLength, *requiresLength;
	
#ifndef SP_REFACTOR /* ivars */
	NSUserDefaults *prefs;
#endif
	
	MCPConnection *connection;
	
#ifndef SP_REFACTOR /* ivars */
	BOOL showAdvancedView;
	
	NSInteger heightOffset;
	NSUInteger windowMinWidth;
	NSUInteger windowMinHeigth;
#endif
}

#ifdef SP_REFACTOR
@property (assign) SPTableView* indexesTableView;
@property (assign) SPTableStructure* tableStructure;
@property (assign) NSButton* addIndexButton;
@property (assign) NSButton* removeIndexButton;

- (void)setDatabaseDocument:(SPDatabaseDocument*)db;
#endif

/**
 * @property table The table currently being viewed
 */
@property (readwrite, retain) NSString *table;

/**
 * @property connection The MySQL connection to use
 */
@property (readwrite, assign) MCPConnection *connection;

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

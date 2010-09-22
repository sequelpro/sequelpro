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

@class SPDatabaseDocument, SPTablesList, SPTableData, SPTableStructure, MCPConnection, BWAnchoredButtonBar;

// Constants
extern NSString *SPNewIndexIndexName;
extern NSString *SPNewIndexIndexType;
extern NSString *SPNewIndexIndexedColumns;
extern NSString *SPNewIndexStorageType;
extern NSString *SPNewIndexKeyBlockSize;

@interface SPIndexesController : NSWindowController 
{
	// Controllers
	IBOutlet SPDatabaseDocument *dbDocument;
	IBOutlet SPTableStructure *tableStructure;
	IBOutlet SPTablesList *tablesList;
	IBOutlet SPTableData *tableData;
	
	// Index table view
	IBOutlet NSTableView *indexesTableView;
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
	IBOutlet BWAnchoredButtonBar *anchoredButtonBar;
	
	// Advanced options view
	IBOutlet NSButton *indexAdvancedOptionsViewButton;
	IBOutlet NSView *indexAdvancedOptionsView;
	IBOutlet NSButton *indexAdvancedOptionsViewLabelButton;
	IBOutlet NSPopUpButton *indexStorageTypePopUpButton;
	IBOutlet NSTextField *indexKeyBlockSizeTextField;
		
	NSString *table;
	
	NSMutableArray *fields, *indexes, *indexedFields, *supportsLength, *requiresLength;
	
	NSUserDefaults *prefs;
	
	MCPConnection *connection;
	
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

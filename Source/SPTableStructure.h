//
//  $Id$
//
//  SPTableStructure.h
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

#import <Cocoa/Cocoa.h>
#import <MCPKit/MCPKit.h>

@interface SPTableStructure : NSObject 
{
	IBOutlet id tablesListInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id tableDocumentInstance;
	IBOutlet id tableInfoInstance;
	IBOutlet id extendedTableInfoInstance;
	IBOutlet id indexesController;

	IBOutlet id keySheet;
	IBOutlet id resetAutoIncrementSheet;
	IBOutlet id resetAutoIncrementValue;
	IBOutlet id resetAutoIncrementLine;
	IBOutlet id tableSourceView;
	IBOutlet id addFieldButton;
	IBOutlet id copyFieldButton;
	IBOutlet id removeFieldButton;
	IBOutlet id reloadFieldsButton;
	IBOutlet id chooseKeyButton;
	IBOutlet id structureGrabber;
	IBOutlet id editTableButton;
	IBOutlet id addIndexButton;
	IBOutlet id removeIndexButton;
	IBOutlet id refreshIndexesButton;
	IBOutlet id indexesTableView;
	IBOutlet NSSplitView *tablesIndexesSplitView;
	IBOutlet NSButton *indexesShowButton;

	IBOutlet id encodingPopupCell;

	id databaseDataInstance;

	MCPConnection *mySQLConnection;
	MCPResult *tableSourceResult;
	MCPResult *indexResult;

	NSString *selectedTable;
	NSMutableArray *tableFields;
	NSMutableDictionary *oldRow, *enumFields;
	NSDictionary *defaultValues;
	BOOL isEditingRow, isEditingNewRow, isSavingRow, alertSheetOpened;
	NSInteger currentlyEditingRow;
	NSUserDefaults *prefs;
	NSArray *collations;
	NSArray *typeSuggestions;

}

// Table methods
- (void)loadTable:(NSString *)aTable;
- (IBAction)reloadTable:(id)sender;
- (void) setTableDetails:(NSDictionary *)tableDetails;

// Edit methods
- (IBAction)addField:(id)sender;
- (IBAction)copyField:(id)sender;
- (IBAction)removeField:(id)sender;
- (IBAction)resetAutoIncrement:(id)sender;
- (IBAction)showOptimizedFieldType:(id)sender;
- (BOOL)cancelRowEditing;

// Index sheet methods
- (IBAction)closeSheet:(id)sender;

// Key sheet methods
- (IBAction)closeKeySheet:(id)sender;

// Additional methods
- (void)setConnection:(MCPConnection *)theConnection;
- (NSArray *)fetchResultAsArray:(MCPResult *)theResult;
- (BOOL)saveRowOnDeselect;
- (BOOL)addRowToDB;
- (void)setAutoIncrementTo:(NSString*)valueAsString;

// Getter methods
- (NSString *)defaultValueForField:(NSString *)field;
- (NSArray *)fieldNames;
- (NSDictionary *)enumFields;
- (NSDictionary *)tableSourceForPrinting;

// Task interaction
- (void)startDocumentTaskForTab:(NSNotification *)aNotification;
- (void)endDocumentTaskForTab:(NSNotification *)aNotification;

// Split view interaction
- (IBAction)unhideIndexesView:(id)sender;

@end

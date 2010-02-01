//
//  $Id$
//
//  TableSource.h
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

@interface TableSource : NSObject 
{
	IBOutlet id tablesListInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id tableDocumentInstance;

	IBOutlet id tableWindow;
	IBOutlet id indexSheet;
	IBOutlet id keySheet;
	IBOutlet id tableSourceView;
	IBOutlet id indexView;
	IBOutlet id addFieldButton;
	IBOutlet id copyFieldButton;
	IBOutlet id removeFieldButton;
	IBOutlet id reloadFieldsButton;
	IBOutlet id addIndexButton;
	IBOutlet id removeIndexButton;
	IBOutlet id reloadIndexesButton;
	IBOutlet id indexTypeField;
	IBOutlet id indexNameField;
	IBOutlet id indexedColumnsField;
	IBOutlet id chooseKeyButton;
	IBOutlet id structureGrabber;
	IBOutlet id editTableButton;

	MCPConnection *mySQLConnection;
	MCPResult *tableSourceResult;
	MCPResult *indexResult;

	NSString *selectedTable;
	NSMutableArray *tableFields, *indexes;
	NSMutableDictionary *oldRow, *enumFields;
	NSDictionary *defaultValues;
	BOOL isEditingRow, isEditingNewRow, isSavingRow, alertSheetOpened;
	NSInteger currentlyEditingRow;
	NSUserDefaults *prefs;
}

// Table methods
- (void)loadTable:(NSString *)aTable;
- (IBAction)reloadTable:(id)sender;

// Edit methods
- (IBAction)addField:(id)sender;
- (IBAction)copyField:(id)sender;
- (IBAction)removeField:(id)sender;
- (IBAction)removeIndex:(id)sender;

// Index sheet methods
- (IBAction)openIndexSheet:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)chooseIndexType:(id)sender;
- (void)closeAlertSheet;

// Key sheet methods
- (IBAction)closeKeySheet:(id)sender;

// Additional methods
- (void)setConnection:(MCPConnection *)theConnection;
- (NSArray *)fetchResultAsArray:(MCPResult *)theResult;
- (BOOL)saveRowOnDeselect;
- (BOOL)addRowToDB;

// Getter methods
- (NSString *)defaultValueForField:(NSString *)field;
- (NSArray *)fieldNames;
- (NSDictionary *)enumFields;
- (NSArray *)tableStructureForPrint;

// Task interaction
- (void)startDocumentTaskForTab:(NSNotification *)aNotification;
- (void)endDocumentTaskForTab:(NSNotification *)aNotification;

@end

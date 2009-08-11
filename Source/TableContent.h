//
//  $Id$
//
//  TableDocument.h
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  
//  Forked by Abhi Beckert (abhibeckert.com) 2008-04-04
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

@class CMCopyTable, SPTextAndLinkCell, SPHistoryController;

@interface TableContent : NSObject 
{	
	IBOutlet id tableDocumentInstance;
	IBOutlet id tablesListInstance;
	IBOutlet id tableDataInstance;
	IBOutlet SPHistoryController *spHistoryControllerInstance;
	
	IBOutlet id tableWindow;
	IBOutlet CMCopyTable *tableContentView;
	IBOutlet id fieldField;
	IBOutlet id compareField;
	IBOutlet id argumentField;
	IBOutlet id filterButton;
	IBOutlet id addButton;
	IBOutlet id copyButton;
	IBOutlet id removeButton;
	IBOutlet id multipleLineEditingButton;
	IBOutlet id countText;
	IBOutlet id limitRowsField;
	IBOutlet id limitRowsButton;
	IBOutlet id limitRowsStepper;
	
	MCPConnection *mySQLConnection;
	
	NSString *selectedTable, *usedQuery;
	NSMutableArray *tableValues, *dataColumns, *keys, *oldRow;
	NSString *compareType;
	NSNumber *sortCol;
	BOOL isEditingRow, isEditingNewRow, isSavingRow, isDesc, setLimit;
	BOOL isFiltered, isLimited;
	NSUserDefaults *prefs;
	int numRows, currentlyEditingRow, maxNumRowsOfCurrentTable;

	BOOL sortColumnToRestoreIsAsc;
	NSString *sortColumnToRestore;
	unsigned int limitStartPositionToRestore;
	NSIndexSet *selectionIndexToRestore;
	NSRect selectionViewportToRestore;
	NSString *filterFieldToRestore, *filterComparisonToRestore, *filterValueToRestore;
}

// Table loading methods and information
- (void) loadTable:(NSString *)aTable;
- (void) loadTableValues;
- (NSString *) tableFilterString;
- (void) updateCountText;

// Table interface actions
- (IBAction) reloadTable:(id)sender;
- (IBAction) filterTable:(id)sender;
- (IBAction) toggleFilterField:(id)sender;
- (NSString *) usedQuery;
- (void) setUsedQuery:(NSString *)query;

//edit methods
- (IBAction)addRow:(id)sender;
- (IBAction)copyRow:(id)sender;
- (IBAction)removeRow:(id)sender;


//getter methods
- (NSArray *)currentResult;
- (NSArray *)currentDataResult;

//additional methods
- (void)setConnection:(MCPConnection *)theConnection;
- (void)clickLinkArrow:(SPTextAndLinkCell *)theArrowCell;
- (IBAction)setCompareTypes:(id)sender;
- (IBAction)stepLimitRows:(id)sender;
- (NSArray *)fetchResultAsArray:(MCPResult *)theResult;
- (BOOL)addRowToDB;
- (NSString *)argumentForRow:(int)row;
- (BOOL)tableContainsBlobOrTextColumns;
- (NSString *)fieldListForQuery;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo;
- (int)getNumberOfRows;
- (int)fetchNumberOfRows;
- (BOOL)saveRowOnDeselect;

// Retrieving and setting table state
- (NSString *) sortColumnName;
- (BOOL) sortColumnIsAscending;
- (unsigned int) limitStart;
- (NSIndexSet *) selectedRowIndexes;
- (NSRect) viewport;
- (NSDictionary *) filterSettings;
- (void) setSortColumnNameToRestore:(NSString *)theSortColumnName isAscending:(BOOL)isAscending;
- (void) setLimitStartToRestore:(unsigned int)theLimitStart;
- (void) setSelectedRowIndexesToRestore:(NSIndexSet *)theIndexSet;
- (void) setViewportToRestore:(NSRect)theViewport;
- (void) setFiltersToRestore:(NSDictionary *)filterSettings;
- (void) storeCurrentDetailsForRestoration;
- (void) clearDetailsToRestore;

//tableView datasource methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(CMCopyTable *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex;
- (void)tableView:(NSTableView *)aTableView
	 setObjectValue:(id)anObject
	 forTableColumn:(NSTableColumn *)aTableColumn
							row:(int)rowIndex;

//tableView delegate methods
- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn;
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;
- (void)tableViewColumnDidResize:(NSNotification *)aNotification;
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard;
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command;

//textView delegate methods
// - (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector;

@end

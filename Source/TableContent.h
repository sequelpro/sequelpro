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
#import <MCPKit_bundled/MCPKit_bundled.h>
#import "CMCopyTable.h"
#import "CMMCPConnection.h"
#import "CMMCPResult.h"

@interface TableContent : NSObject 
{	
	IBOutlet id tableDocumentInstance;
	IBOutlet id tablesListInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id queryConsoleInstance;
	
	IBOutlet id tableWindow;
	IBOutlet CMCopyTable *tableContentView;
	IBOutlet id editSheet;
	IBOutlet id editSheetTabView;
	IBOutlet id editImage;
	IBOutlet id editTextView;
	IBOutlet id hexTextView;
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
	IBOutlet id limitRowsText;
	
	CMMCPConnection *mySQLConnection;
	
	id editData;
	NSString *selectedTable;
	NSMutableArray *fullResult, *filteredResult, *keys;
	NSMutableDictionary *oldRow;
	NSString *compareType, *sortField;
	BOOL isEditingRow, isEditingNewRow, isDesc, setLimit;
	NSUserDefaults *prefs;
	int numRows, currentlyEditingRow;
	bool areShowingAllRows;
}

//table methods
- (void)loadTable:(NSString *)aTable;
- (IBAction)reloadTable:(id)sender;
- (IBAction)reloadTableValues:(id)sender;
- (IBAction)filterTable:(id)sender;
- (IBAction)showAll:(id)sender;
- (IBAction)toggleFilterField:(id)sender;

//edit methods
- (IBAction)addRow:(id)sender;
- (IBAction)copyRow:(id)sender;
- (IBAction)removeRow:(id)sender;

//editSheet methods
- (IBAction)closeEditSheet:(id)sender;
- (IBAction)openEditSheet:(id)sender;
- (IBAction)saveEditSheet:(id)sender;
- (void)processUpdatedImageData:(NSData *)data;
- (IBAction)dropImage:(id)sender;
- (void)textDidChange:(NSNotification *)notification;
- (NSString *)dataToHex:(NSData *)data;

//getter methods
- (NSArray *)currentResult;

//additional methods
- (void)setConnection:(CMMCPConnection *)theConnection;
- (IBAction)setCompareTypes:(id)sender;
- (IBAction)stepLimitRows:(id)sender;
- (NSArray *)fetchResultAsArray:(CMMCPResult *)theResult;
- (BOOL)addRowToDB;
- (NSString *)argumentForRow:(int)row;
- (BOOL)tableContainsBlobOrTextColumns;
- (NSString *)fieldListForQuery;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo;
- (int)getNumberOfRows;
- (int)fetchNumberOfRows;
- (BOOL)saveRowOnDeselect;

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
- (void)tableViewSelectionIsChanging:(NSNotification *)aNotification;
- (void)tableViewColumnDidResize:(NSNotification *)aNotification;
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard;
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command;

//textView delegate methods
- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector;

@end

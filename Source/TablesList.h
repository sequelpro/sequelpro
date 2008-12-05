//
//  TablesList.h
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
//  Or mail to <lorenz@textor.ch>

#import <Cocoa/Cocoa.h>
#import <MCPKit_bundled/MCPKit_bundled.h>

@class CMMCResult;
@class CMMCPConnection;

@interface TablesList : NSObject {

	IBOutlet id tableDocumentInstance;
	IBOutlet id tableSourceInstance;
	IBOutlet id tableContentInstance;
	IBOutlet id customQueryInstance;
	IBOutlet id tableDumpInstance;
	IBOutlet id tableStatusInstance;

	IBOutlet id tableWindow;
	IBOutlet id copyTableSheet;
	IBOutlet id tablesListView;
	IBOutlet id copyTableNameField;
	IBOutlet id copyTableContentSwitch;
	IBOutlet id tabView;

	CMMCPConnection *mySQLConnection;
	NSMutableArray *tables;
//	NSUserDefaults *prefs;
	BOOL structureLoaded, contentLoaded, statusLoaded, alertSheetOpened;
}

//IBAction methods
- (IBAction)updateTables:(id)sender;
- (IBAction)addTable:(id)sender;
- (IBAction)removeTable:(id)sender;
- (IBAction)copyTable:(id)sender;

//alert sheet methods
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo;

//copyTableSheet methods
- (IBAction)closeCopyTableSheet:(id)sender;

//additional methods
- (void)removeTable;
- (void)setConnection:(CMMCPConnection *)theConnection;
- (void)doPerformQueryService:(NSString *)query;

//getter methods
- (NSString *)table;
- (BOOL)structureLoaded;
- (BOOL)contentLoaded;
- (BOOL)statusLoaded;

// Setter methods
- (void)setContentRequiresReload:(BOOL)reload;

//tableView datasource methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView
			objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex;
- (void)tableView:(NSTableView *)aTableView
			setObjectValue:(id)anObject
			forTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex;

//tableView delegate methods
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command;
- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView;
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;

//last but not least
- (id)init;
- (void)dealloc;

@end

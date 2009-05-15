//
//  TableRelations.h
//  sequel-pro
//
//  Created by J Knight on 13/05/09.
//  Copyright 2009 J Knight. All rights reserved.
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
//

#import <Cocoa/Cocoa.h>
#import <MCPKit/MCPKit.h>

@class CMMCPConnection, CMMCPResult, CMCopyTable;

@interface TableRelations : NSObject {
	
	IBOutlet id tableDocumentInstance;
	IBOutlet id tablesListInstance;	
	IBOutlet id tableList;
	IBOutlet id tableWindow;
	IBOutlet id tableDataInstance;
	IBOutlet id addButton;
	IBOutlet id removeButton;	
	IBOutlet id labelText;		
	IBOutlet id relationsView;
	IBOutlet id relationSheet;

	IBOutlet id tableBox;
	IBOutlet id columnSelect;
	IBOutlet id refTableSelect;
	IBOutlet id refColumnSelect;
	IBOutlet id onUpdateSelect;
	IBOutlet id onDeleteSelect;
	
		
	CMMCPConnection *mySQLConnection;

	NSMutableArray *relData;
}

- (void)setConnection:(CMMCPConnection *)theConnection;

//edit methods
- (IBAction)addRow:(id)sender;
- (IBAction)removeRow:(id)sender;
- (IBAction)closeRelationSheet:(id)sender;
- (IBAction)addRelation:(id)sender;
- (IBAction)chooseRefTable:(id)sender;

- (IBAction)refresh:(id)sender;

- (void)tableChanged:(NSNotification *)notification;

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
- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn;
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;
- (void)tableViewSelectionIsChanging:(NSNotification *)aNotification;
- (void)tableViewColumnDidResize:(NSNotification *)aNotification;
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard;
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command;

@end

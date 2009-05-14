//
//  TableRelations.h
//  sequel-pro
//
//  Created by J Knight on 13/05/09.
//  Copyright 2009 TalonEdge Ltd.. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MCPKit_bundled/MCPKit_bundled.h>

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

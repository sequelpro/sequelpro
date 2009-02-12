//
//  CustomQuery.h
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
#import "CMCopyTable.h"
#import "CMMCPConnection.h"
#import "CMMCPResult.h"


@interface CustomQuery : NSObject {

	IBOutlet id tableWindow;
	IBOutlet id queryFavoritesButton;
	IBOutlet id queryHistoryButton;
	IBOutlet id textView;
	IBOutlet CMCopyTable *customQueryView;
	IBOutlet id errorText;
	IBOutlet id affectedRowsText;
	IBOutlet id valueSheet;
	IBOutlet id valueTextField;
	IBOutlet id queryFavoritesSheet;
	IBOutlet id queryFavoritesView;

	CMMCPConnection *mySQLConnection;
	NSArray *queryResult;
	NSUserDefaults *prefs;
	NSMutableArray *queryFavorites;
}

//IBAction methods
- (IBAction)performQuery:(id)sender;
- (IBAction)chooseQueryFavorite:(id)sender;
- (IBAction)chooseQueryHistory:(id)sender;
- (IBAction)closeSheet:(id)sender;

//queryFavoritesSheet methods
- (IBAction)addQueryFavorite:(id)sender;
- (IBAction)removeQueryFavorite:(id)sender;
- (IBAction)copyQueryFavorite:(id)sender;
- (IBAction)closeQueryFavoritesSheet:(id)sender;

//getter methods
- (NSArray *)currentResult;

//additional methods
- (void)setConnection:(CMMCPConnection *)theConnection;
- (void)setFavorites;
- (void)doPerformQueryService:(NSString *)query;

//tableView datasource methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView
			objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex;
- (void)tableView:(NSTableView *)aTableView
			setObjectValue:(id)anObject
			forTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex;

//tableView drag&drop datasource methods
- (BOOL)tableView:(NSTableView *)aTableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard;
- (NSDragOperation)tableView:(NSTableView*)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row
	proposedDropOperation:(NSTableViewDropOperation)operation;
- (BOOL)tableView:(NSTableView*)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation;

//tableView delegate methods
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;

//splitView delegate methods
- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview;
- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset;
- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset;

//textView delegate methods
- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector;

//last but not least
- (id)init;
- (void)dealloc;

@end

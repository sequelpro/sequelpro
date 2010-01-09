//
//  $Id$
//
//  CMCopyTable.h
//  sequel-pro
//
//  Created by Stuart Glenn on Wed Apr 21 2004.
//  Changed by Lorenz Textor on Sat Nov 13 2004
//  Copyright (c) 2004 Stuart Glenn. All rights reserved.
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

#import <AppKit/AppKit.h>
#import "SPTableView.h"

/*!
	@class copyTable
	@abstract   subclassed NSTableView to implement copy & drag-n-drop
	@discussion Allows copying by creating a string with each table row as
		a separate line and each cell then separate via tabs. The drag out
		is in similar format. The values for each cell are obtained via the
		objects description method
*/
@interface CMCopyTable : SPTableView 
{
	id tableInstance;				// the table content view instance
	id tableData;					// the actual table data source
	id mySQLConnection;				// current MySQL connection
	NSArray* columnDefinitions;		// array of NSDictionary containing info about columns
	NSString* selectedTable;		// the name of the current selected table
	
	NSUserDefaults *prefs;
}

/*!
	@method	 copy:
	@abstract   does the work of copying
	@discussion gets selected (if any) row(s) as a string setting it 
	   then into th default pasteboard as a string type and tabular text type.
	@param	  sender who asked for this copy?
*/
- (void)copy:(id)sender;

/*!
	@method	 validateMenuItem:
	@abstract   Dynamically enable Copy menu item for the table view
	@discussion Will only enable the Copy item when something is selected in
	  this table view
	@param	  anItem the menu item being validated
	@result	 YES if there is at least one row selected & the menu item is
	  copy, NO otherwise
*/
- (BOOL)validateMenuItem:(NSMenuItem*)anItem;

/*!
	@method	 draggingSourceOperationMaskForLocal:
	@discussion Allows for dragging out of the table to other applications
	@param	  isLocal who cares
	@result	 Always calls for a copy type drag operation
*/
- (NSUInteger)draggingSourceOperationMaskForLocal:(BOOL)isLocal;

/*!
	@method	 selectedRowsAsTabStringWithHeaders
	@abstract   getter of the selected rows of the table for copy
	@discussion For the selected rows returns a single string with each row
	   separated by a newline and then for each column value separated by a 
	   tab. Values are from the objects description method, so make sure it
	   returns something meaningful. 
	@result	 The above described string, or nil if nothing selected
*/
- (NSString *)selectedRowsAsTabStringWithHeaders:(BOOL)withHeaders;

/*!
	@method	 draggedRowsAsTabString:
	@abstract   getter of the dragged rows of the table for drag
	@discussion For the dragged rows returns a single string with each row
	   separated by a newline and then for each column value separated by a 
	   tab. Values are from the objects description method, so make sure it
	   returns something meaningful. 
	@result	 The above described string, or nil if nothing selected
*/
- (NSString *)draggedRowsAsTabString;

/*
 * Generate a string in form of INSERT INTO <table> VALUES () of 
 * currently selected rows. Support blob data as well.
 */
- (NSString *)selectedRowsAsSqlInserts;

/*
 * Set all necessary data from the table content view.
 */
- (void)setTableInstance:(id)anInstance withTableData:(id)theTableData withColumns:(NSArray *)columnDefs withTableName:(NSString *)aTableName withConnection:(id)aMySqlConnection;

@end

extern NSInteger MENU_EDIT_COPY_WITH_COLUMN;
extern NSInteger MENU_EDIT_COPY_AS_SQL;

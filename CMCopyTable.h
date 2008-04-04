/*!
 @header CMCopyTable.h
 @abstract   CocoaMySQL
 @discussion <pre>
 $Id:$
 Created by Stuart Glenn on Wed Apr 21 2004.
 Changed by Lorenz Textor on Sat Nov 13 2004
 Copyright (c) 2004 Stuart Glenn. All rights reserved.
</pre>
*/

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


/*!
    @class copyTable
    @abstract   subclassed NSTableView to implement copy & drag-n-drop
    @discussion Allows copying by creating a string with each table row as
        a separate line and each cell then separate via tabs. The drag out
        is in similar format. The values for each cell are obtained via the
        objects description method
*/
@interface CMCopyTable : NSTableView 
{

}

/*!
    @method     copy:
    @abstract   does the work of copying
    @discussion gets selected (if any) row(s) as a string setting it 
       then into th default pasteboard as a string type and tabular text type.
    @param      sender who asked for this copy?
*/
- (void)copy:(id)sender;

/*!
    @method     validateMenuItem:
    @abstract   Dynamically enable Copy menu item for the table view
    @discussion Will only enable the Copy item when something is selected in
      this table view
    @param      anItem the menu item being validated
    @result     YES if there is at least one row selected & the menu item is
      copy, NO otherwise
*/
- (BOOL)validateMenuItem:(NSMenuItem*)anItem;

/*!
    @method     draggingSourceOperationMaskForLocal:
    @discussion Allows for dragging out of the table to other applications
    @param      isLocal who cares
    @result     Always calls for a copy type drag operation
*/
- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal;

/*!
    @method     selectedRowsAsTabString
    @abstract   getter of the selected rows of the table for copy
    @discussion For the selected rows returns a single string with each row
       separated by a newline and then for each column value separated by a 
       tab. Values are from the objects description method, so make sure it
       returns something meaningful. 
    @result     The above described string, or nil if nothing selected
*/
- (NSString *)selectedRowsAsTabString;

/*!
    @method     draggedRowsAsTabString:
    @abstract   getter of the dragged rows of the table for drag
    @discussion For the dragged rows returns a single string with each row
       separated by a newline and then for each column value separated by a 
       tab. Values are from the objects description method, so make sure it
       returns something meaningful. 
    @result     The above described string, or nil if nothing selected
*/
- (NSString *)draggedRowsAsTabString:(NSArray *)rows;

@end

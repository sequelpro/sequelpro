//
//  CMCopyTable.m
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

#import "CMCopyTable.h"


@implementation CMCopyTable

- (void)copy:(id)sender
{
    NSString *tmp = [self selectedRowsAsTabString];
    
    if ( nil != tmp )
    {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        
        [pb declareTypes:[NSArray arrayWithObjects: NSTabularTextPboardType, 
            NSStringPboardType, nil]
                   owner:nil];
        
        [pb setString:tmp forType:NSStringPboardType];
        [pb setString:tmp forType:NSTabularTextPboardType];
    }
}

//allow for drag-n-drop out of the application as a copy
- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationCopy;
}

//only have the copy menu item enabled when row(s) are selected
- (BOOL)validateMenuItem:(NSMenuItem*)anItem 
{    
    int row = [self selectedRow];
    if ([[anItem title] isEqualToString:@"Copy"] )
    {
        if (row < 0 )
        {
            return NO;
        }
    }
    return YES;
}

//get selected rows a string of newline separated lines of tab separated fields
//the value in each field is from the objects description method
- (NSString *)selectedRowsAsTabString
{
    if ( [self numberOfSelectedRows] > 0 )
    {
        NSArray *columns = [self tableColumns];
        int numColumns = [columns count];
        id dataSource = [self dataSource];
        
        NSMutableString *result = [NSMutableString stringWithCapacity:numColumns];

        //this is really deprecated in 10.3, but the new method is really weird
        NSEnumerator *enumerator = [self selectedRowEnumerator]; 
        
        int c;
        id row = nil;
        id rowData = nil;
        NSTableColumn *col = nil;
        
        while (row = [enumerator nextObject]) 
        { 
            rowData = nil;
            for ( c = 0; c < numColumns; c++)
            {
                col = [columns objectAtIndex:c];
                rowData = [dataSource tableView:self 
                      objectValueForTableColumn:col 
                                            row:[row intValue] ];
                
                if ( nil != rowData )
                {
                    [result appendString:[NSString stringWithFormat:@"%@\t", [rowData description] ] ];
                }
                else
                {
                    [result appendString:@"\t"];
                }
            } //end for each column
            
            if ( [result length] )
            {
                [result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
            }
            [result appendString: [ NSString stringWithFormat:@"\n"]];
        } //end for each row
        
        if ( [result length] )
        {
            [result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
        }
        return result;
    }
    else
    {
        return nil;
    }
}

//get dragged rows a string of newline separated lines of tab separated fields
//the value in each field is from the objects description method
- (NSString *)draggedRowsAsTabString:(NSArray *)rows
{
    if ( [rows count] > 0 )
    {
        NSArray *columns = [self tableColumns];
        int numColumns = [columns count];
        id dataSource = [self dataSource];
        
        NSMutableString *result = [NSMutableString stringWithCapacity:numColumns];

        //this is really deprecated in 10.3, but the new method is really weird
        NSEnumerator *enumerator = [rows objectEnumerator]; 
        
        int c;
        id row = nil;
        id rowData = nil;
        NSTableColumn *col = nil;
        
        while (row = [enumerator nextObject]) 
        { 
            rowData = nil;
            for ( c = 0; c < numColumns; c++)
            {
                col = [columns objectAtIndex:c];
                rowData = [dataSource tableView:self 
                      objectValueForTableColumn:col 
                                            row:[row intValue] ];
                
                if ( nil != rowData )
                {
                    [result appendString:[NSString stringWithFormat:@"%@\t", [rowData description] ] ];
                }
                else
                {
                    [result appendString:@"\t"];
                }
            } //end for each column
            
            if ( [result length] )
            {
                [result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
            }
            [result appendString: [ NSString stringWithFormat:@"\n"]];
        } //end for each row
        
        if ( [result length] )
        {
            [result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
        }
        return result;
    }
    else
    {
        return nil;
    }
}

@end

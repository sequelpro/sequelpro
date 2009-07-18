//
//  $Id$
//
//  SPExtendedTableInfo.h
//  sequel-pro
//
//  Created by Jason Hallford (jason.hallford@byu.edu) on Th July 08 2004.
//  sequel-pro Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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

@class SPTableData, SPDatabaseData;

@interface SPExtendedTableInfo : NSObject
{
	IBOutlet SPTableData *tableDataInstance;
	IBOutlet SPDatabaseData *databaseDataInstance;

	IBOutlet NSTextField *tableRowNumber;
	IBOutlet NSTextField *tableRowFormat;
	IBOutlet NSTextField *tableRowAvgLength;
	IBOutlet NSTextField *tableRowAutoIncrement;
	IBOutlet NSTextField *tableDataSize;
	IBOutlet NSTextField *tableSizeFree;
	IBOutlet NSTextField *tableIndexSize;
	IBOutlet NSTextField *tableMaxDataSize;
	IBOutlet NSTextField *tableCreatedAt;
	IBOutlet NSTextField *tableUpdatedAt;
	
	IBOutlet NSTextView *tableCommentsTextView;
	IBOutlet NSTextView *tableCreateSyntaxTextView;
	
	IBOutlet NSPopUpButton *tableTypePopUpButton;
	IBOutlet NSPopUpButton *tableEncodingPopUpButton;
	IBOutlet NSPopUpButton *tableCollationPopUpButton;
	
	NSString *selectedTable;
	
	MCPConnection *connection;
}

@property (readwrite, assign) MCPConnection *connection;

// IBAction methods
- (IBAction)reloadTable:(id)sender;
- (IBAction)updateTableType:(id)sender;
- (IBAction)updateTableEncoding:(id)sender;
- (IBAction)updateTableCollation:(id)sender;

// Others
- (void)loadTable:(NSString *)table; 

@end

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

enum sp_table_types
{
	SP_TABLETYPE_TABLE = 0,
	SP_TABLETYPE_VIEW = 1
};

@class CMMCResult, CMMCPConnection;

@interface TablesList : NSObject {

	IBOutlet id tableDocumentInstance;
	IBOutlet id tableSourceInstance;
	IBOutlet id tableContentInstance;
	IBOutlet id customQueryInstance;
	IBOutlet id tableDumpInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id tableStatusInstance;

	IBOutlet id tableWindow;
	IBOutlet id copyTableSheet;
	IBOutlet id tablesListView;
	IBOutlet id copyTableNameField;
	IBOutlet id copyTableContentSwitch;
	IBOutlet id tabView;
	IBOutlet id tableSheet;
	IBOutlet id tableNameField;
	IBOutlet id tableEncodingButton;
	IBOutlet id addTableButton;
	
	IBOutlet NSMenuItem *removeTableMenuItem;
	IBOutlet NSMenuItem *duplicateTableMenuItem;

	CMMCPConnection *mySQLConnection;
	
	NSMutableArray *tables;
	NSMutableArray *tableTypes;

	BOOL structureLoaded, contentLoaded, statusLoaded, alertSheetOpened;
}

// IBAction methods
- (IBAction)updateTables:(id)sender;
- (IBAction)addTable:(id)sender;
- (IBAction)closeTableSheet:(id)sender;
- (IBAction)removeTable:(id)sender;
- (IBAction)copyTable:(id)sender;

// copyTableSheet methods
- (IBAction)closeCopyTableSheet:(id)sender;

// Additional methods
- (void)removeTable;
- (void)setConnection:(CMMCPConnection *)theConnection;
- (void)doPerformQueryService:(NSString *)query;

// Getters
- (NSString *)tableName;
- (int)tableType;
- (NSArray *)tables;
- (NSArray *)tableTypes;
- (BOOL)structureLoaded;
- (BOOL)contentLoaded;
- (BOOL)statusLoaded;

// Setters
- (void)setContentRequiresReload:(BOOL)reload;

@end

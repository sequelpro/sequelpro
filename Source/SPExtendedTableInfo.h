//
//  SPExtendedTableInfo.h
//  sequel-pro
//
//  Created by Jason Hallford (jason.hallford@byu.edu) on July 8, 2004.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  Copyright (c) 2012 Sequel Pro Team. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

@class SPTableData;
@class SPDatabaseData;
@class SPTablesList;
@class SPMySQLConnection;

@interface SPExtendedTableInfo : NSObject
{
	IBOutlet id tableDocumentInstance;
	IBOutlet SPTablesList *tablesListInstance;
	IBOutlet SPTableData *tableDataInstance;
	IBOutlet SPDatabaseData *databaseDataInstance;
	IBOutlet id tableSourceInstance;

	IBOutlet id resetAutoIncrementResetButton;

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
	
	SPMySQLConnection *connection;
}

@property (readwrite, retain) SPMySQLConnection *connection;

// IBAction methods
- (IBAction)reloadTable:(id)sender;
- (IBAction)updateTableType:(id)sender;
- (IBAction)updateTableEncoding:(id)sender;
- (IBAction)updateTableCollation:(id)sender;
- (IBAction)resetAutoIncrement:(id)sender;
- (IBAction)tableRowAutoIncrementWasEdited:(id)sender;

// Others
- (void)loadTable:(NSString *)table; 
- (NSDictionary *)tableInformationForPrinting;

// Task interaction
- (void)startDocumentTaskForTab:(NSNotification *)aNotification;
- (void)endDocumentTaskForTab:(NSNotification *)aNotification;

@end

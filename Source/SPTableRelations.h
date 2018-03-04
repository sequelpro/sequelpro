//
//  SPTableRelations.h
//  sequel-pro
//
//  Created by Jim Knight on May 12, 2009.
//  Copyright (c) 2009 Jim Knight. All rights reserved.
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

@class SPTableView;
@class SPMySQLConnection;
@class SPDatabaseDocument;
@class SPTablesList;
@class SPTableData;

@interface SPTableRelations : NSObject <NSTableViewDelegate, NSTableViewDataSource>
{	
	IBOutlet SPDatabaseDocument *tableDocumentInstance;
	IBOutlet SPTablesList       *tablesListInstance;
	IBOutlet SPTableData        *tableDataInstance;
	IBOutlet SPTableView        *tableList;
		
	IBOutlet NSButton    *addRelationButton;
	IBOutlet NSButton    *removeRelationButton;	
	IBOutlet NSButton    *refreshRelationsButton;
	IBOutlet NSTextField *labelTextField;		
	IBOutlet SPTableView *relationsTableView;
	IBOutlet NSPanel     *addRelationPanel;

	IBOutlet NSTextField         *constraintName;
	IBOutlet NSBox               *addRelationTableBox;
	IBOutlet NSPopUpButton       *columnPopUpButton;
	IBOutlet NSPopUpButton       *refTablePopUpButton;
	IBOutlet NSPopUpButton       *refColumnPopUpButton;
	IBOutlet NSPopUpButton       *onUpdatePopUpButton;
	IBOutlet NSPopUpButton       *onDeletePopUpButton;
	IBOutlet NSButton            *confirmAddRelationButton;
	IBOutlet NSProgressIndicator *dataProgressIndicator;
	IBOutlet NSTextField         *progressStatusTextField;
	
	IBOutlet NSView     *detailErrorView;
	IBOutlet NSTextView *detailErrorText;
	
	SPMySQLConnection *connection;

	NSUserDefaults *prefs;
	NSMutableArray *relationData;
	NSMutableArray *takenConstraintNames;
}

@property (readonly) NSMutableArray *relationData;
@property (readwrite, assign) SPMySQLConnection *connection;

// IB action methods
- (IBAction)addRelation:(id)sender;
- (IBAction)removeRelation:(id)sender;
- (IBAction)openRelationSheet:(id)sender;
- (IBAction)closeRelationSheet:(id)sender;
- (IBAction)confirmAddRelation:(id)sender;
- (IBAction)selectTableColumn:(id)sender;
- (IBAction)selectReferenceTable:(id)sender;
- (IBAction)refreshRelations:(id)sender;

- (void)tableSelectionChanged:(NSNotification *)notification;

// Task interaction
- (void)startDocumentTaskForTab:(NSNotification *)notification;
- (void)endDocumentTaskForTab:(NSNotification *)notification;

// Other
- (NSArray *)relationDataForPrinting;

@end

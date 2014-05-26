//
//  SPTableTriggers.h
//  sequel-pro
//
//  Created by Marius Ursache.
//  Copyright (c) 2010 Marius Ursache. All rights reserved.
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

@interface SPTableTriggers : NSObject 
{
	IBOutlet id tableDocumentInstance;
	IBOutlet id tablesListInstance;
	IBOutlet id tableDataInstance;
	
	IBOutlet id tableList;
	
	IBOutlet NSButton      *addTriggerButton;
	IBOutlet NSButton      *removeTriggerButton;	
	IBOutlet NSButton      *refreshTriggersButton;
	IBOutlet SPTableView   *triggersTableView;
	IBOutlet NSPanel       *addTriggerPanel;
	IBOutlet NSTextField   *labelTextField;
	
	IBOutlet NSTextField   *triggerNameTextField;
	IBOutlet NSPopUpButton *triggerActionTimePopUpButton;
	IBOutlet NSPopUpButton *triggerEventPopUpButton;
	IBOutlet NSTextView    *triggerStatementTextView;
	
	IBOutlet NSBox         *addTriggerTableBox;
	IBOutlet NSButton      *confirmAddTriggerButton;
	
	SPMySQLConnection *connection;
	
	NSMutableArray *triggerData;
	NSUserDefaults *prefs;
	
	BOOL isEdit;
	
	// Store a previously edited trigger for backup/cache
	NSDictionary *editedTrigger;
}

@property (readwrite, assign) SPMySQLConnection *connection;

- (void)loadTriggers;
- (void)resetInterface;

// IB action methods
- (IBAction)addTrigger:(id)sender;
- (IBAction)editTrigger:(id)sender;
- (IBAction)removeTrigger:(id)sender;
- (IBAction)closeTriggerSheet:(id)sender;
- (IBAction)confirmAddTrigger:(id)sender;
- (IBAction)refreshTriggers:(id)sender;

// Task interaction
- (void)startDocumentTaskForTab:(NSNotification *)notification;
- (void)endDocumentTaskForTab:(NSNotification *)notification;

// Other
- (NSArray *)triggerDataForPrinting;

@end

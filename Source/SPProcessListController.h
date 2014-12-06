//
//  SPProcessListController.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 12, 2009.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

@class SPMySQLConnection;

@interface SPProcessListController : NSWindowController 
{
	SPMySQLConnection *connection;
	
	BOOL showFullProcessList, processListThreadRunning;
	
	NSTimer *autoRefreshTimer;
	
	NSUserDefaults *prefs;
	NSMutableArray *processes, *processesFiltered;
	
	IBOutlet NSWindow            *customIntervalWindow;
	IBOutlet NSTextField         *customIntervalTextField;
	IBOutlet NSButton            *customIntervalButton;
	IBOutlet NSTableView         *processListTableView;
	IBOutlet NSTextField         *processesCountTextField;
	IBOutlet NSSearchField       *filterProcessesSearchField;
	IBOutlet NSProgressIndicator *refreshProgressIndicator; 
	IBOutlet NSButton            *saveProcessesButton;
	IBOutlet NSButton            *refreshProcessesButton;
	IBOutlet NSButton            *autoRefreshButton;
	IBOutlet NSMenuItem          *autoRefreshIntervalMenuItem;
}

@property (readwrite, assign) SPMySQLConnection *connection;

- (IBAction)copy:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)refreshProcessList:(id)sender;
- (IBAction)saveServerProcesses:(id)sender;
- (IBAction)killProcessQuery:(id)sender;
- (IBAction)killProcessConnection:(id)sender;
- (IBAction)toggleShowProcessID:(NSMenuItem *)sender;
- (IBAction)toggeleShowFullProcessList:(NSMenuItem *)sender;
- (IBAction)toggleProcessListAutoRefresh:(NSButton *)sender;
- (IBAction)setAutoRefreshInterval:(id)sender;
- (IBAction)setCustomAutoRefreshInterval:(id)sender;

- (void)displayProcessListWindow;

@end

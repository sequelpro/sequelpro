//
//  $Id$
//
//  SPProcessListController.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 12, 2009
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

@interface SPProcessListController : NSWindowController 
{
	MCPConnection *connection;
	
	BOOL showFullProcessList;
	
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

@property (readwrite, assign) MCPConnection *connection;

- (IBAction)copy:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)refreshProcessList:(id)sender;
- (IBAction)saveServerProcesses:(id)sender;
- (IBAction)killProcessQuery:(id)sender;
- (IBAction)killProcessConnection:(id)sender;
- (IBAction)toggleShowProcessID:(id)sender;
- (IBAction)toggleProcessListAutoRefresh:(id)sender;
- (IBAction)setAutoRefreshInterval:(id)sender;
- (IBAction)setCustomAutoRefreshInterval:(id)sender;

- (void)displayProcessListWindow;

@end

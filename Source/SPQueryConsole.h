//
//  $Id$
//
//  SPQueryConsole.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Jan 30, 2009
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

@interface SPQueryConsole : NSWindowController 
{
	IBOutlet NSView *saveLogView;
	IBOutlet NSTableView *consoleTableView;
	IBOutlet NSSearchField *consoleSearchField;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSButton *includeTimeStampsButton, *saveConsoleButton, *clearConsoleButton;
	IBOutlet NSMenuItem *showTimeStampsMenuItem, *showSelectShowStatementsMenuItem, *showHelpMenuItem;
	
	NSFont *consoleFont;
	NSMutableArray *messagesFullSet, *messagesFilteredSet, *messagesVisibleSet;
	BOOL showSelectStatementsAreDisabled;
	BOOL showHelpStatementsAreDisabled;
	BOOL filterIsActive;
	NSMutableString *activeFilterString;
}

@property (readwrite, retain) NSFont *consoleFont;

+ (SPQueryConsole *)sharedQueryConsole;

- (IBAction)copy:(id)sender;
- (IBAction)clearConsole:(id)sender;
- (IBAction)saveConsoleAs:(id)sender;
- (IBAction)toggleShowTimeStamps:(id)sender;
- (IBAction)toggleShowSelectShowStatements:(id)sender;
- (IBAction)toggleShowHelpStatements:(id)sender;


- (void)showMessageInConsole:(NSString *)message;
- (void)showErrorInConsole:(NSString *)error;

- (NSUInteger)consoleMessageCount;

@end

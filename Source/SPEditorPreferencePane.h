//
//  $Id$
//
//  SPEditorPreferencePane.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 31, 2010
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPPreferencePane.h"

/**
 * @class SPEditorPreferencePane SPEditorPreferencePane.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * Editor preference pane controller.
 */
@interface SPEditorPreferencePane : SPPreferencePane <SPPreferencePaneProtocol> 
{
	IBOutlet NSWindow *enterNameWindow;
	IBOutlet NSWindow *editThemeListWindow;
	
	IBOutlet NSTextField *enterNameLabel;
	IBOutlet NSTextField *enterNameInputField;
	IBOutlet NSTextField *enterNameAlertField;
	IBOutlet NSTextField *colorThemeName;
	IBOutlet NSTextField *colorThemeNameLabel;
	IBOutlet NSTextField *editorFontName;
	
	IBOutlet NSButton *themeNameSaveButton;
	IBOutlet NSTableView *editThemeListTable;
	IBOutlet NSButton *removeThemeButton;
	IBOutlet NSButton *duplicateThemeButton;
	IBOutlet NSMenuItem *saveThemeMenuItem;
	
	IBOutlet NSTableView *colorSettingTableView;
	IBOutlet NSMenu *themeSelectionMenu;
	
	NSArray *editorColors;
	NSArray *editorNameForColors;
	NSUInteger colorRow;
	
	NSString *themePath;
	NSArray *editThemeListItems;
	NSInteger checkForUnsavedThemeSheetStatus;
}

- (IBAction)showCustomQueryFontPanel:(id)sender;
- (IBAction)showGlobalResultTableFontPanel:(id)sender;
- (IBAction)setDefaultColors:(id)sender;
- (IBAction)exportColorScheme:(id)sender;
- (IBAction)importColorScheme:(id)sender;
- (IBAction)saveAsColorScheme:(id)sender;
- (IBAction)loadColorScheme:(id)sender;
- (IBAction)closePanelSheet:(id)sender;
- (IBAction)duplicateTheme:(id)sender;
- (IBAction)removeTheme:(id)sender;
- (IBAction)editThemeList:(id)sender;

- (void)updateDisplayedEditorFontName;
- (void)updateColorSchemeSelectionMenu;
- (void)updateDisplayColorThemeName;

@end

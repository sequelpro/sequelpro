//
//  SPEditorPreferencePane.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 31, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPPreferencePane.h"

/**
 * @class SPEditorPreferencePane SPEditorPreferencePane.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * Editor preference pane controller.
 */
@interface SPEditorPreferencePane : SPPreferencePane <SPPreferencePaneProtocol, NSOpenSavePanelDelegate> 
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

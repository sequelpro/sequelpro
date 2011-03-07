//
//  $Id$
//
//  SPEditorPreferencePane.m
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

#import "SPEditorPreferencePane.h"
#import "SPPreferenceController.h"
#import "SPColorWellCell.h"
#import "SPAlertSheets.h"
#import "SPCategoryAdditions.h"

// Constants
static NSString *SPImportColorScheme             = @"ImportColorScheme";
static NSString *SPExportColorScheme             = @"ExportColorScheme";
static NSString *SPSaveColorScheme               = @"SaveColorScheme";
static NSString *SPDefaultColorSchemeName        = @"Default";
static NSString *SPDefaultColorSchemeNameLC      = @"default";
static NSString *SPCustomColorSchemeName         = @"User-defined";
static NSString *SPCustomColorSchemeNameLC       = @"user-defined";
static NSString *SPDefaultExportColourSchemeName = @"MyTheme";

@interface SPEditorPreferencePane (PrivateAPI)

- (BOOL)_checkForUnsavedTheme;
- (NSArray *)_getAvailableThemes;
- (void)_saveColorThemeAtPath:(NSString *)path;
- (BOOL)_loadColorSchemeFromFile:(NSString *)filename;

@end

@implementation SPEditorPreferencePane

#pragma mark -
#pragma mark Initialisation

/**
 * Init.
 */
- (id)init
{
	if ((self = [super init])) {
		
		themePath = [[[NSFileManager defaultManager] applicationSupportDirectoryForSubDirectory:SPThemesSupportFolder error:nil] retain];
		
		editThemeListItems = [[NSArray arrayWithArray:[self _getAvailableThemes]] retain];
		
		editorColors = 
		[[NSArray arrayWithObjects:
		  SPCustomQueryEditorTextColor,
		  SPCustomQueryEditorBackgroundColor,
		  SPCustomQueryEditorCaretColor,
		  SPCustomQueryEditorCommentColor,
		  SPCustomQueryEditorSQLKeywordColor,
		  SPCustomQueryEditorNumericColor,
		  SPCustomQueryEditorQuoteColor,
		  SPCustomQueryEditorBacktickColor,
		  SPCustomQueryEditorVariableColor,
		  SPCustomQueryEditorHighlightQueryColor,
		  SPCustomQueryEditorSelectionColor,
		  nil] retain];
		
		editorNameForColors = 
		[[NSArray arrayWithObjects:
		  NSLocalizedString(@"Text", @"text label for color table (Prefs > Editor)"),
		  NSLocalizedString(@"Background", @"background label for color table (Prefs > Editor)"),
		  NSLocalizedString(@"Caret", @"caret label for color table (Prefs > Editor)"),
		  NSLocalizedString(@"Comment", @"comment label"),
		  NSLocalizedString(@"Keyword", @"keyword label for color table (Prefs > Editor)"),
		  NSLocalizedString(@"Numeric", @"numeric label for color table (Prefs > Editor)"),
		  NSLocalizedString(@"Quote", @"quote label for color table (Prefs > Editor)"),
		  NSLocalizedString(@"Backtick Quote", @"backtick quote label for color table (Prefs > Editor)"),
		  NSLocalizedString(@"Variable", @"variable label for color table (Prefs > Editor)"),
		  NSLocalizedString(@"Query Background", @"query background label for color table (Prefs > Editor)"),
		  NSLocalizedString(@"Selection", @"selection label for color table (Prefs > Editor)"),
		  nil] retain];
	}
	
	return self;
}

/**
 * Initialise the UI, specifically the colours table view.
 */
- (void)awakeFromNib
{
	[NSColor setIgnoresAlpha:NO];
	
	NSTableColumn *column = [[colorSettingTableView tableColumns] objectAtIndex:0];
	NSTextFieldCell *textCell = [[[NSTextFieldCell alloc] init] autorelease];
	
	[textCell setFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]]];
	
	column = [[colorSettingTableView tableColumns] objectAtIndex: 1];
	
	SPColorWellCell *colorCell = [[[SPColorWellCell alloc] init] autorelease];
	
	[colorCell setEditable:YES];
	[colorCell setTarget:self];
	[colorCell setAction:@selector(colorClick:)];
	
	[column setDataCell:colorCell];
}

#pragma mark -
#pragma mark IB action methods

- (IBAction)exportColorScheme:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:SPColorThemeFileExtension];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:NO];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];
	
	[panel beginSheetForDirectory:nil 
							 file:[SPDefaultExportColourSchemeName stringByAppendingPathExtension:SPColorThemeFileExtension] 
				   modalForWindow:[[self view] window] 
					modalDelegate:self 
				   didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) 
					  contextInfo:SPExportColorScheme];
}

- (IBAction)importColorScheme:(id)sender
{
	if (![self _checkForUnsavedTheme]) return;	
	
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setCanSelectHiddenExtension:YES];
	[panel setDelegate:self];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:NO];
	
	[panel beginSheetForDirectory:nil 
							 file:@"" 
							types:[NSArray arrayWithObjects:SPColorThemeFileExtension, @"tmTheme", nil] 
				   modalForWindow:[[self view] window]
					modalDelegate:self 
				   didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) 
					  contextInfo:SPImportColorScheme];
	
}

- (IBAction)loadColorScheme:(id)sender
{
	if (![self _checkForUnsavedTheme]) return;
	
	if ([self _loadColorSchemeFromFile:[NSString stringWithFormat:@"%@/%@.%@", themePath, [sender title], SPColorThemeFileExtension]]) {
		[prefs setObject:[sender title] forKey:SPCustomQueryEditorThemeName];
		
		[self updateDisplayColorThemeName];
	}
}

- (IBAction)saveAsColorScheme:(id)sender
{
	[[NSColorPanel sharedColorPanel] close];
	
	[enterNameAlertField setHidden:YES];
	[enterNameInputField setStringValue:@""];
	[enterNameLabel setStringValue:NSLocalizedString(@"Theme Name:", @"theme name label")];
	
	[NSApp beginSheet:enterNameWindow
	   modalForWindow:[[self view] window]
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:SPSaveColorScheme];
	
}

- (IBAction)duplicateTheme:(id)sender
{
	if ([editThemeListTable numberOfSelectedRows] != 1) return;
	
	NSString *selectedPath = [NSString stringWithFormat:@"%@/%@_copy.%@", themePath, [editThemeListItems objectAtIndex:[editThemeListTable selectedRow]], SPColorThemeFileExtension];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	
	if (![fm fileExistsAtPath:selectedPath isDirectory:nil]) {
		if ([fm copyItemAtPath:[NSString stringWithFormat:@"%@/%@.%@", themePath, [editThemeListItems objectAtIndex:[editThemeListTable selectedRow]], SPColorThemeFileExtension] toPath:selectedPath error:nil]) {
			
			if (editThemeListItems) [editThemeListItems release], editThemeListItems = nil;
			
			editThemeListItems = [[NSArray arrayWithArray:[self _getAvailableThemes]] retain];
			
			[editThemeListTable reloadData];
			
			[self updateDisplayColorThemeName];
			[self updateColorSchemeSelectionMenu];
			
			return;
		}
	}
	
	NSBeep();
	
	[editThemeListTable reloadData];
}

- (IBAction)removeTheme:(id)sender
{
	if ([editThemeListTable numberOfSelectedRows] != 1) return;
	
	NSString *selectedPath = [NSString stringWithFormat:@"%@/%@.%@", themePath, [editThemeListItems objectAtIndex:[editThemeListTable selectedRow]], SPColorThemeFileExtension];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	
	if ([fm fileExistsAtPath:selectedPath isDirectory:nil]) {
		if ([fm removeItemAtPath:selectedPath error:nil]) {
			
			// Refresh current color theme setting name
			if ([[[prefs objectForKey:SPCustomQueryEditorThemeName] lowercaseString] isEqualToString:[[editThemeListItems objectAtIndex:[editThemeListTable selectedRow]] lowercaseString]]) {
				[prefs setObject:SPCustomColorSchemeName forKey:SPCustomQueryEditorThemeName];
			}
			
			if (editThemeListItems) [editThemeListItems release], editThemeListItems = nil;
			
			editThemeListItems = [[NSArray arrayWithArray:[self _getAvailableThemes]] retain];
			
			[editThemeListTable reloadData];
			
			[self updateDisplayColorThemeName];
			[self updateColorSchemeSelectionMenu];
			
			return;
		}
	}
	
	NSBeep();
	
	[editThemeListTable reloadData];
}

- (IBAction)closePanelSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

/**
 * Opens the font panel.
 */
- (IBAction)showCustomQueryFontPanel:(id)sender
{
	[(SPPreferenceController *)[[[self view] window] delegate] setFontChangeTarget:2];
	
	[[NSFontPanel sharedFontPanel] setPanelFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]] isMultiple:NO];
	[[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:self];
}

/**
 * Sets the syntax colours back to there defaults.
 */
- (IBAction)setDefaultColors:(id)sender
{
	if (![self _checkForUnsavedTheme]) return;
	
	[[NSColorPanel sharedColorPanel] close];
	
	[prefs setObject:SPDefaultColorSchemeName forKey:SPCustomQueryEditorThemeName];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.000 green:0.455 blue:0.000 alpha:1.000]] forKey:SPCustomQueryEditorCommentColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.769 green:0.102 blue:0.086 alpha:1.000]] forKey:SPCustomQueryEditorQuoteColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.200 green:0.250 blue:1.000 alpha:1.000]] forKey:SPCustomQueryEditorSQLKeywordColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.000 green:0.000 blue:0.658 alpha:1.000]] forKey:SPCustomQueryEditorBacktickColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.506 green:0.263 blue:0.000 alpha:1.000]] forKey:SPCustomQueryEditorNumericColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.500 green:0.500 blue:0.500 alpha:1.000]] forKey:SPCustomQueryEditorVariableColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.950 green:0.950 blue:0.950 alpha:1.000]] forKey:SPCustomQueryEditorHighlightQueryColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.7098 green:0.8352 blue:1.000 alpha:1.000]] forKey:SPCustomQueryEditorSelectionColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor blackColor]] forKey:SPCustomQueryEditorTextColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor blackColor]] forKey:SPCustomQueryEditorCaretColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]] forKey:SPCustomQueryEditorBackgroundColor];
	
	[colorSettingTableView reloadData];
	
	[self updateDisplayColorThemeName];
}

/**
 * Opens the theme liste sheet.
 */
- (IBAction)editThemeList:(id)sender
{
	[[NSColorPanel sharedColorPanel] close];
	
	if (editThemeListItems) [editThemeListItems release], editThemeListItems = nil;
	
	editThemeListItems = [[NSArray arrayWithArray:[self _getAvailableThemes]] retain];
	
	[editThemeListTable reloadData];
	
	[NSApp beginSheet:editThemeListWindow
	   modalForWindow:[[self view] window]
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
}

#pragma mark -
#pragma mark Public API

/**
 * Updates the displayed font according to the user's preferences.
 */
- (void)updateDisplayedEditorFontName
{
	NSFont *font = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]];
	
	[editorFontName setFont:font];
	[editorFontName setStringValue:[NSString stringWithFormat:@"%@, %.1f pt", [font displayName], [font pointSize]]];
	
	[colorSettingTableView reloadData];
}

/**
 * Updates the colour scheme selection menu according to the available schemes.
 */
- (void)updateColorSchemeSelectionMenu
{	
	NSMenuItem *defaultItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Default", @"default label") action:@selector(setDefaultColors:) keyEquivalent:@""];
	
	[defaultItem setTarget:self];
	
	// Build theme selection submenu
	[themeSelectionMenu compatibleRemoveAllItems];
	[themeSelectionMenu addItem:defaultItem];
	[themeSelectionMenu addItem:[NSMenuItem separatorItem]];
	
	[defaultItem release];
	
	NSArray *foundThemes = [self _getAvailableThemes];
	
	if ([foundThemes count]) {
		for (NSString* item in foundThemes)
		{
			NSMenuItem *loadItem = [[NSMenuItem alloc] initWithTitle:item action:@selector(loadColorScheme:) keyEquivalent:@""];
			
			[loadItem setTarget:self];
			
			[themeSelectionMenu addItem:loadItem];
			
			[loadItem release];
		}
		
		[themeSelectionMenu addItem:[NSMenuItem separatorItem]];
	}
	
	NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Edit Theme List…", @"edit theme list label") action:@selector(editThemeList:) keyEquivalent:@""];
	
	[editItem setTarget:self];
	
	[themeSelectionMenu addItem:editItem];
	
	[editItem release];
}

/**
 * Updates the currently selected colour scheme theme name.
 */
- (void)updateDisplayColorThemeName
{
	if (![prefs objectForKey:SPCustomQueryEditorThemeName]) {
		[colorThemeName setHidden:YES];
		[colorThemeNameLabel setHidden:YES];
		
		return;
	}
	
	if ([[[prefs objectForKey:SPCustomQueryEditorThemeName] lowercaseString] isEqualToString:SPCustomColorSchemeNameLC]) {
		[colorThemeName setHidden:YES];
		[colorThemeNameLabel setHidden:YES];
		
		return;
	}
	
	NSString *currentThemeName = [[prefs objectForKey:SPCustomQueryEditorThemeName] lowercaseString];
	
	if ([currentThemeName isEqualToString:SPDefaultColorSchemeNameLC]) {
		[colorThemeName setHidden:NO];
		[colorThemeNameLabel setHidden:NO];
		
		return;
	}
	
	BOOL nameValid = NO;
	
	for (NSString* item in [self _getAvailableThemes]) 
	{
		if ([[item lowercaseString] isEqualToString:currentThemeName]) {
			nameValid = YES;
			break;
		}
	}
	
	if (nameValid) {
		[colorThemeName setHidden:NO];
		[colorThemeNameLabel setHidden:NO];
		
		return;
	} 
	else {
		[prefs setObject:SPCustomColorSchemeName forKey:SPCustomQueryEditorThemeName];
		[colorThemeName setHidden:YES];
		[colorThemeNameLabel setHidden:YES];
		
		[self updateColorSchemeSelectionMenu];
		
		return;
	}
	
	[colorThemeName setHidden:NO];
	[colorThemeNameLabel setHidden:NO];
}

#pragma mark -
#pragma mark Font panel methods

/**
 * Invoked when the user clicks a colour cell.
 */
- (void)colorClick:(id)sender
{	
	colorRow = [sender clickedRow];
	
	NSColorPanel *panel = [NSColorPanel sharedColorPanel];
	
	[panel setTarget:self];
	[panel setAction:@selector(colorChanged:)];
	[panel setColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:[editorColors objectAtIndex:colorRow]]]];
	
	[colorSettingTableView deselectAll:nil];
	
	[panel makeKeyAndOrderFront:self];
}

/**
 * Invoked when the user changes and editor colour.
 */
- (void)colorChanged:(id)sender
{
	if (![[NSColorPanel sharedColorPanel] isVisible]) return;
	
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[sender color]] forKey:[editorColors objectAtIndex:colorRow]];
	[colorSettingTableView reloadData];
	
	[prefs setObject:SPCustomColorSchemeName forKey:SPCustomQueryEditorThemeName];
	
	[self updateDisplayColorThemeName];
}

/**
 * Sets the font panel's valid modes.
 */
- (NSUInteger)validModesForFontPanel:(NSFontPanel *)fontPanel
{
	return (NSFontPanelSizeModeMask | NSFontPanelCollectionModeMask);
}

#pragma mark -
#pragma mark Sheet callbacks

- (void)checkForUnsavedThemeDidEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	checkForUnsavedThemeSheetStatus = returnCode;
}

- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	// Order out current sheet to suppress overlapping of sheets
	if ([sheet respondsToSelector:@selector(orderOut:)]) {
		[sheet orderOut:nil];
	}
	else if ([sheet respondsToSelector:@selector(window)]) {
		[[sheet window] orderOut:nil];
	}
	
	if ([contextInfo isEqualToString:SPSaveColorScheme]) {
		if (returnCode == NSOKButton) {
			NSFileManager *fm = [NSFileManager defaultManager];
			
			if (![fm fileExistsAtPath:themePath isDirectory:nil]) {
				if (![fm createDirectoryAtPath:themePath withIntermediateDirectories:YES attributes:nil error:nil]) {
					NSBeep();
					return;
				}
			}
			
			[self _saveColorThemeAtPath:[NSString stringWithFormat:@"%@/%@.%@", themePath, [enterNameInputField stringValue], SPColorThemeFileExtension]];
			[self updateColorSchemeSelectionMenu];
			
			[prefs setObject:[enterNameInputField stringValue] forKey:SPCustomQueryEditorThemeName];
			
			[self updateDisplayColorThemeName];
		}
	}
}

- (void)panelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	if ([contextInfo isEqualToString:SPExportColorScheme]) {
		if (returnCode == NSOKButton) {
			[self _saveColorThemeAtPath:[panel filename]];
		}
	}
	else if ([contextInfo isEqualToString:SPImportColorScheme]) {
		if (returnCode == NSOKButton) {
			if ([self _loadColorSchemeFromFile:[[panel filenames] objectAtIndex:0]]) {
				[prefs setObject:SPCustomColorSchemeName forKey:SPCustomQueryEditorThemeName];
				[self updateDisplayColorThemeName];
			}
		}
	}
}

#pragma mark -
#pragma mark TableView datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (tableView == colorSettingTableView) {
		return [editorColors count];
	}
	else if (tableView == editThemeListTable) {
		return [editThemeListItems count];
	}
	
	return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (tableView == colorSettingTableView) {
		return ([[tableColumn identifier] isEqualToString:@"name"]) ? [editorNameForColors objectAtIndex:rowIndex] : [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:[editorColors objectAtIndex:rowIndex]]];
	} 
	else if (tableView == editThemeListTable) {
		return [editThemeListItems objectAtIndex:rowIndex];
	} 
	
	return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (tableView == editThemeListTable) {
		
		// Theme name editing
		NSString *newName = (NSString*)anObject;
		
		// Check for non-valid names
		if (![newName length] || [[newName lowercaseString] isEqualToString:SPDefaultColorSchemeNameLC] || [[newName lowercaseString] isEqualToString:SPCustomColorSchemeNameLC]) {
			NSBeep();
			[editThemeListTable reloadData];
			return;
		}
		
		// Check if new name already exists
		for (NSString* item in editThemeListItems) 
		{
			if ([[item lowercaseString] isEqualToString:newName]) {
				NSBeep();
				[editThemeListTable reloadData];
				return;
			}
		}
		
		// Rename theme file
		NSFileManager *fm = [NSFileManager defaultManager];
		
		if (![fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@.%@", themePath, [editThemeListItems objectAtIndex:rowIndex], SPColorThemeFileExtension] toPath:[NSString stringWithFormat:@"%@/%@.%@", themePath, newName, SPColorThemeFileExtension] error:nil]) {
			NSBeep();
			[editThemeListTable reloadData];
			return;
		}
		
		// Refresh current color theme setting name
		if ([[[prefs objectForKey:SPCustomQueryEditorThemeName] lowercaseString] isEqualToString:[[editThemeListItems objectAtIndex:rowIndex] lowercaseString]]) {
			[prefs setObject:newName forKey:SPCustomQueryEditorThemeName];
		}
		
		// Reload everything needed
		if (editThemeListItems) [editThemeListItems release], editThemeListItems = nil;
		editThemeListItems = [[NSArray arrayWithArray:[self _getAvailableThemes]] retain];
		
		[editThemeListTable reloadData];
		
		[self updateDisplayColorThemeName];
		[self updateColorSchemeSelectionMenu];
	}
}

#pragma mark -
#pragma mark TableView delegate methods

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if(aTableView == colorSettingTableView) {
		
		NSColorPanel* panel;
		
		colorRow = rowIndex;
		panel = [NSColorPanel sharedColorPanel];
		
		[panel setTarget:self];
		[panel setAction:@selector(colorChanged:)];
		[panel setColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:[editorColors objectAtIndex:colorRow]]]];
		[colorSettingTableView deselectAll:nil];
		[panel makeKeyAndOrderFront:self];
		
		return NO;
	}
	
	return YES;
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)index
{
	if (tableView == colorSettingTableView && [[tableColumn identifier] isEqualToString:@"name"]) {
		if ([cell isKindOfClass:[NSTextFieldCell class]]) {
			[cell setDrawsBackground:YES];
			
			NSFont *nf = [NSFont fontWithName:[[[NSFontPanel sharedFontPanel] panelConvertFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]]] fontName] size:13.0f];
			
			[cell setFont:nf];
			
			switch (index) 
			{
				case 1:
					[cell setTextColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorTextColor]]];
					[cell setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorBackgroundColor]]];
					break;
				case 9:
					[cell setTextColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorTextColor]]];
					[cell setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorHighlightQueryColor]]];
					break;
				case 10:
					[cell setTextColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorTextColor]]];
					[cell setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorSelectionColor]]];
					break;
				default:
					[cell setTextColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:[editorColors objectAtIndex:index]]]];
					[cell setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorBackgroundColor]]];
			}
		}
	}
}

#pragma mark -
#pragma mark TextField delegate methods

/**
 * Trap and control the 'name' field of the selected favorite. If the user pressed
 * 'Add Favorite' the 'name' field is set to "New Favorite". If the user do not
 * change the 'name' field or delete that field it will be set to user@host automatically.
 */
- (void)controlTextDidChange:(NSNotification *)aNotification
{
	id field = [aNotification object];
	
	// Validate 'Save' button for entering a valid theme name
	if (field == enterNameInputField) {
		NSString *name = [[enterNameInputField stringValue] lowercaseString];
		
		if (![name length] || [name isEqualToString:SPDefaultColorSchemeNameLC] || [name isEqualToString:SPCustomColorSchemeNameLC]) {
			[themeNameSaveButton setEnabled:NO];
		} 
		else {
			BOOL hide = YES;
			
			for (NSString* item in [self _getAvailableThemes]) 
			{
				if ([[item lowercaseString] isEqualToString:name]) {
					hide = NO;
					break;
				}
			}
			
			[enterNameAlertField setHidden:hide];
			[themeNameSaveButton setEnabled:YES];
		}
		
		return;
	}
}

#pragma mark -
#pragma mark Preference pane protocol methods

- (NSView *)preferencePaneView
{
	return [self view];
}

- (NSImage *)preferencePaneIcon
{
	return [NSImage imageNamed:@"toolbar-preferences-queryeditor"];
}

- (NSString *)preferencePaneName
{
	return NSLocalizedString(@"Query Editor", @"query editor preference pane name");
}

- (NSString *)preferencePaneIdentifier
{
	return SPPreferenceToolbarEditor;
}

- (NSString *)preferencePaneToolTip
{
	return NSLocalizedString(@"Query Editor Preferences", @"query editor preference pane tooltip");
}

- (BOOL)preferencePaneAllowsResizing
{
	return NO;
}

#pragma mark -
#pragma mark Private API

- (BOOL)_checkForUnsavedTheme
{
	if (![prefs objectForKey:SPCustomQueryEditorThemeName] || [[[prefs objectForKey:SPCustomQueryEditorThemeName] lowercaseString] isEqualToString:SPCustomColorSchemeNameLC]) {
		
		[[NSColorPanel sharedColorPanel] close];
		
		SPBeginWaitingAlertSheet(@"title",
								 NSLocalizedString(@"Proceed", @"proceed button"), 
								 NSLocalizedString(@"Cancel", @"cancel button"), 
								 nil,
								 NSWarningAlertStyle, 
								 [[self view] window], 
								 self,
								 @selector(checkForUnsavedThemeDidEndSheet:returnCode:contextInfo:),
								 nil,
								 NSLocalizedString(@"Unsaved Theme", @"unsaved theme message"),
								 NSLocalizedString(@"The current color theme is unsaved. Do you want to proceed without saving it?", @"unsaved theme informative message"),
								 checkForUnsavedThemeSheetStatus
								 );
		
		return (checkForUnsavedThemeSheetStatus == NSAlertDefaultReturn);
	}
	
	[[NSColorPanel sharedColorPanel] close];
	
	return YES;
}

- (NSArray *)_getAvailableThemes
{
	// Read ~/Library/Application Support/Sequel Pro/Themes
	NSFileManager *fm = [NSFileManager defaultManager];
	
	if ([fm fileExistsAtPath:themePath isDirectory:nil]) {
		NSArray *allItemsRaw = [fm contentsOfDirectoryAtPath:themePath error:NULL];
		
		if(!allItemsRaw) return [NSArray array];
		
		// Filter out all themes
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH %@", [NSString stringWithFormat:@".%@", SPColorThemeFileExtension]];
		NSMutableArray *allItems = [NSMutableArray arrayWithArray:allItemsRaw];
		
		[allItems filterUsingPredicate:predicate];
		
		allItemsRaw = [NSArray arrayWithArray:allItems];
		
		[allItems removeAllObjects];
		
		// Remove file extension
		for (NSString* item in allItemsRaw)
		{
			[allItems addObject:[item substringToIndex:[item length]-[SPColorThemeFileExtension length]-1]];
		}
		
		return (NSArray *)allItems;
	}
	
	return [NSArray array];
}

- (void)_saveColorThemeAtPath:(NSString *)path
{
	// Build plist dictionary
	NSMutableDictionary *scheme = [NSMutableDictionary dictionary];
	NSMutableDictionary *mainsettings = [NSMutableDictionary dictionary];
	NSMutableArray *settings = [NSMutableArray array];
		
	[prefs synchronize];
	
	NSColor *aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorBackgroundColor]];
	[mainsettings setObject:[aColor rgbHexString] forKey:@"background"];
	
	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorCaretColor]];
	[mainsettings setObject:[aColor rgbHexString] forKey:@"caret"];
	
	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorTextColor]];
	[mainsettings setObject:[aColor rgbHexString] forKey:@"foreground"];
	
	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorHighlightQueryColor]];
	[mainsettings setObject:[aColor rgbHexString] forKey:@"lineHighlight"];
	
	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorSelectionColor]];
	[mainsettings setObject:[aColor rgbHexString] forKey:@"selection"];
	
	[settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:mainsettings, @"settings", nil]];
	
	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorCommentColor]];
	[settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						 @"Comment", @"name",
						 [NSDictionary dictionaryWithObjectsAndKeys:
						  [aColor rgbHexString], @"foreground",
						  nil
						  ], @"settings",
						 nil
						 ]];
	
	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorQuoteColor]];
	[settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						 @"String", @"name",
						 [NSDictionary dictionaryWithObjectsAndKeys:
						  [aColor rgbHexString], @"foreground",
						  nil
						  ], @"settings",
						 nil
						 ]];
	
	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorSQLKeywordColor]];
	[settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						 @"Keyword", @"name",
						 [NSDictionary dictionaryWithObjectsAndKeys:
						  [aColor rgbHexString], @"foreground",
						  nil
						  ], @"settings",
						 nil
						 ]];
	
	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorBacktickColor]];
	[settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						 @"User-defined constant", @"name",
						 [NSDictionary dictionaryWithObjectsAndKeys:
						  [aColor rgbHexString], @"foreground",
						  nil
						  ], @"settings",
						 nil
						 ]];
	
	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorNumericColor]];
	[settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						 @"Number", @"name",
						 [NSDictionary dictionaryWithObjectsAndKeys:
						  [aColor rgbHexString], @"foreground",
						  nil
						  ], @"settings",
						 nil
						 ]];
	
	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorVariableColor]];
	[settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						 @"Variable", @"name",
						 [NSDictionary dictionaryWithObjectsAndKeys:
						  [aColor rgbHexString], @"foreground",
						  nil
						  ], @"settings",
						 nil
						 ]];
	
	[scheme setObject:settings forKey:@"settings"];
	
	NSString *err = nil;
	NSData *plist = [NSPropertyListSerialization dataFromPropertyList:scheme
															   format:NSPropertyListXMLFormat_v1_0
													 errorDescription:&err];
	
	if(err != nil) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while converting color scheme data", @"error while converting color scheme data")]
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										   otherButton:nil 
							 informativeTextWithFormat:err];
		
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		
		return;
	}
	
	NSError *error = nil;
	[plist writeToFile:path options:NSAtomicWrite error:&error];
	
	if (error) [[NSAlert alertWithError:error] runModal];
}

- (BOOL)_loadColorSchemeFromFile:(NSString *)filename
{
	NSError *readError = nil;
	NSString *convError = nil;
	NSPropertyListFormat format;
	
	NSDictionary *theme = nil;
	
	NSData *pData = [NSData dataWithContentsOfFile:filename options:NSUncachedRead error:&readError];
	
	theme = [[NSPropertyListSerialization propertyListFromData:pData 
											  mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];
	
	if (!theme || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading data file", @"error while reading data file")]
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										   otherButton:nil 
							 informativeTextWithFormat:NSLocalizedString(@"File couldn't be read.", @"error while reading data file")];
		
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		if (theme) [theme release];
		[self updateDisplayColorThemeName];
		return NO;
	}
	
	if ([theme objectForKey:@"settings"] 
		&& [[theme objectForKey:@"settings"] isKindOfClass:[NSArray class]] 
		&& [[theme objectForKey:@"settings"] count] 
		&& [[[theme objectForKey:@"settings"] objectAtIndex:0] isKindOfClass:[NSDictionary class]]
		&& [[[theme objectForKey:@"settings"] objectAtIndex:0] objectForKey:@"settings"]) {
		
		NSInteger counter = 0;
		
		for (NSDictionary *dict in [theme objectForKey:@"settings"]) 
		{
			if (counter == 0) {
				if ([dict objectForKey:@"settings"]) {
					NSDictionary *dic = [dict objectForKey:@"settings"];
					if([dic objectForKey:@"background"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithRGBHexString:[dic objectForKey:@"background"]]] forKey:SPCustomQueryEditorBackgroundColor];
					if([dic objectForKey:@"caret"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithRGBHexString:[dic objectForKey:@"caret"]]] forKey:SPCustomQueryEditorCaretColor];
					if([dic objectForKey:@"foreground"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithRGBHexString:[dic objectForKey:@"foreground"]]] forKey:SPCustomQueryEditorTextColor];
					if([dic objectForKey:@"lineHighlight"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithRGBHexString:[dic objectForKey:@"lineHighlight"]]] forKey:SPCustomQueryEditorHighlightQueryColor];
					if([dic objectForKey:@"selection"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithRGBHexString:[dic objectForKey:@"selection"]]] forKey:SPCustomQueryEditorSelectionColor];
				} 
				else {
					continue;
				}
			} 
			else {
				if ([dict objectForKey:@"name"] && [dict objectForKey:@"settings"] && [[dict objectForKey:@"settings"] isKindOfClass:[NSDictionary class]] && [[dict objectForKey:@"settings"] objectForKey:@"foreground"]) {
					if ([[dict objectForKey:@"name"] isEqualToString:@"Comment"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:
										  [NSColor colorWithRGBHexString:[[dict objectForKey:@"settings"] objectForKey:@"foreground"]]] 
								  forKey:SPCustomQueryEditorCommentColor];
					else if ([[dict objectForKey:@"name"] isEqualToString:@"String"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:
										  [NSColor colorWithRGBHexString:[[dict objectForKey:@"settings"] objectForKey:@"foreground"]]] 
								  forKey:SPCustomQueryEditorQuoteColor];
					else if ([[dict objectForKey:@"name"] isEqualToString:@"Keyword"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:
										  [NSColor colorWithRGBHexString:[[dict objectForKey:@"settings"] objectForKey:@"foreground"]]] 
								  forKey:SPCustomQueryEditorSQLKeywordColor];
					else if ([[dict objectForKey:@"name"] isEqualToString:@"User-defined constant"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:
										  [NSColor colorWithRGBHexString:[[dict objectForKey:@"settings"] objectForKey:@"foreground"]]] 
								  forKey:SPCustomQueryEditorBacktickColor];
					else if ([[dict objectForKey:@"name"] isEqualToString:@"Number"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:
										  [NSColor colorWithRGBHexString:[[dict objectForKey:@"settings"] objectForKey:@"foreground"]]] 
								  forKey:SPCustomQueryEditorNumericColor];
					else if ([[dict objectForKey:@"name"] isEqualToString:@"Variable"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:
										  [NSColor colorWithRGBHexString:[[dict objectForKey:@"settings"] objectForKey:@"foreground"]]] 
								  forKey:SPCustomQueryEditorVariableColor];
				}
			}
			
			counter++;
		}
		
		[theme release];
		[colorSettingTableView reloadData];
	} 
	else {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading data file", @"error while reading data file")]
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										   otherButton:nil 
							 informativeTextWithFormat:NSLocalizedString(@"No color theme data found.", @"error that no color theme found")];
		
		[alert setAlertStyle:NSInformationalAlertStyle];
		[alert runModal];
		[theme release];
		
		return NO;
	}
	
	return YES;
}

#pragma mark -

/**
 * Dealloc.
 */
- (void)dealloc
{
	if (themePath)           [themePath release], themePath = nil;
	if (editThemeListItems)  [editThemeListItems release], editThemeListItems = nil;
	if (editorColors)        [editorColors release], editorColors = nil;
	if (editorNameForColors) [editorNameForColors release], editorNameForColors = nil;
	
	[super dealloc];
}

@end

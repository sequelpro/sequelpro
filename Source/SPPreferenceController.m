//
//  $Id$
//
//  SPPreferenceController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on December 10, 2008.
//  Copyright (c) 2008 Stuart Connolly. All rights reserved.
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPPreferenceController.h"
#import "SPTablesPreferencePane.h"
#import "SPEditorPreferencePane.h"
#import "SPGeneralPreferencePane.h"

@interface SPPreferenceController (PrivateAPI)

- (void)_setupToolbar;
- (void)_resizeWindowForContentView:(NSView *)view;

@end

#pragma mark -

@implementation SPPreferenceController

@synthesize generalPreferencePane;
@synthesize tablesPreferencePane;
@synthesize notificationsPreferencePane;
@synthesize editorPreferencePane;
@synthesize autoUpdatePreferencePane;
@synthesize networkPreferencePane;
@synthesize fontChangeTarget;

/**
 * init.
 */
- (id)init
{
	if ((self = [super initWithWindowNibName:@"Preferences"])) {		
		fontChangeTarget = 0;
	}

	return self;
}

/**
 * Sets up various interface controls once the window is loaded.
 */
- (void)windowDidLoad
{		
	[self _setupToolbar];

	[(SPGeneralPreferencePane *)generalPreferencePane updateDefaultFavoritePopup];
	
	preferencePanes = [[NSArray alloc] initWithObjects:
					   generalPreferencePane,
					   tablesPreferencePane,
					   notificationsPreferencePane,
					   editorPreferencePane,
					   autoUpdatePreferencePane,
					   networkPreferencePane,
					   nil];
}

#pragma mark -
#pragma mark Toolbar item IBAction methods

- (IBAction)displayPreferencePane:(id)sender
{	
	SPPreferencePane <SPPreferencePaneProtocol> *preferencePane = nil;
	
	if (!sender) {
		preferencePane = generalPreferencePane;
	}
	else {
		for (SPPreferencePane <SPPreferencePaneProtocol> *prefPane in preferencePanes)
		{
			if ([[prefPane preferencePaneIdentifier] isEqualToString:[sender itemIdentifier]]) {
				preferencePane = prefPane;
				break;
			}
		}
	}
	
	[[self window] setMinSize:NSMakeSize(0, 0)];
	[[self window] setShowsResizeIndicator:[preferencePane preferencePaneAllowsResizing]];
	
	[toolbar setSelectedItemIdentifier:[preferencePane preferencePaneIdentifier]];
	
	[self _resizeWindowForContentView:[preferencePane preferencePaneView]];
}

/**
 * Displays the table preferences pane.
 */
- (IBAction)displayTablePreferences:(id)sender
{
	[[self window] setMinSize:NSMakeSize(0, 0)];
	[[self window] setShowsResizeIndicator:[tablesPreferencePane preferencePaneAllowsResizing]];
	
	[toolbar setSelectedItemIdentifier:[tablesPreferencePane preferencePaneIdentifier]];
	
	[(SPTablesPreferencePane *)tablesPreferencePane updateDisplayedTableFontName];
	
	[self _resizeWindowForContentView:[tablesPreferencePane preferencePaneView]];
}

/**
 * Displays the editor preferences pane.
 */
- (IBAction)displayEditorPreferences:(id)sender
{
	[(SPEditorPreferencePane *)editorPreferencePane updateColorSchemeSelectionMenu];
	[(SPEditorPreferencePane *)editorPreferencePane updateDisplayColorThemeName];
	
	[[self window] setMinSize:NSMakeSize(0, 0)];
	[[self window] setShowsResizeIndicator:[editorPreferencePane preferencePaneAllowsResizing]];
	
	[toolbar setSelectedItemIdentifier:[editorPreferencePane preferencePaneIdentifier]];
	
	[(SPEditorPreferencePane *)editorPreferencePane updateDisplayedEditorFontName];
	
	[self _resizeWindowForContentView:[editorPreferencePane preferencePaneView]];
}

#pragma mark -
#pragma mark Other

/**
 * Called when the user changes the selected font. This method is defined here as the specific preference
 * pane controllers (NSViewController subclasses) don't seem to be in the responder chain so we need to catch
 * it here.
 */
- (void)changeFont:(id)sender
{		
	NSFont *font;
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	
	switch (fontChangeTarget)
	{
		case SPPrefFontChangeTargetTable:
			font = [[NSFontPanel sharedFontPanel] panelConvertFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPGlobalResultTableFont]]];
			
			[prefs setObject:[NSArchiver archivedDataWithRootObject:font] forKey:SPGlobalResultTableFont];
			
			[(SPTablesPreferencePane *)tablesPreferencePane updateDisplayedTableFontName];
			break;
		case SPPrefFontChangeTargetEditor:
			font = [[NSFontPanel sharedFontPanel] panelConvertFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]]];
			
			[prefs setObject:[NSArchiver archivedDataWithRootObject:font] forKey:SPCustomQueryEditorFont];
			
			[(SPEditorPreferencePane *)editorPreferencePane updateDisplayedEditorFontName];
			break;
	}
}

#pragma mark -
#pragma mark Private API

/**
 * Constructs the preferences' window toolbar.
 */
- (void)_setupToolbar
{
	toolbar = [[[NSToolbar alloc] initWithIdentifier:@"Preference Toolbar"] autorelease];

	// General preferences
	generalItem = [[NSToolbarItem alloc] initWithItemIdentifier:[generalPreferencePane preferencePaneIdentifier]];

	[generalItem setLabel:[generalPreferencePane preferencePaneName]];
	[generalItem setImage:[generalPreferencePane preferencePaneIcon]];
	[generalItem setToolTip:[generalPreferencePane preferencePaneToolTip]];
	[generalItem setTarget:self];
	[generalItem setAction:@selector(displayPreferencePane:)];

	// Table preferences
	tablesItem = [[NSToolbarItem alloc] initWithItemIdentifier:[tablesPreferencePane preferencePaneIdentifier]];

	[tablesItem setLabel:[tablesPreferencePane preferencePaneName]];
	[tablesItem setImage:[tablesPreferencePane preferencePaneIcon]];
	[tablesItem setTarget:self];
	[tablesItem setAction:@selector(displayTablePreferences:)];

	// Notification preferences
	notificationsItem = [[NSToolbarItem alloc] initWithItemIdentifier:[notificationsPreferencePane preferencePaneIdentifier]];

	[notificationsItem setLabel:[notificationsPreferencePane preferencePaneName]];
	[notificationsItem setImage:[notificationsPreferencePane preferencePaneIcon]];
	[notificationsItem setTarget:self];
	[notificationsItem setAction:@selector(displayPreferencePane:)];

	// Editor preferences
	editorItem = [[NSToolbarItem alloc] initWithItemIdentifier:[editorPreferencePane preferencePaneIdentifier]];
	
	[editorItem setLabel:[editorPreferencePane preferencePaneName]];
	[editorItem setImage:[editorPreferencePane preferencePaneIcon]];
	[editorItem setTarget:self];
	[editorItem setAction:@selector(displayEditorPreferences:)];
	
	// AutoUpdate preferences
	autoUpdateItem = [[NSToolbarItem alloc] initWithItemIdentifier:[autoUpdatePreferencePane preferencePaneIdentifier]];

	[autoUpdateItem setLabel:[autoUpdatePreferencePane preferencePaneName]];
	[autoUpdateItem setImage:[autoUpdatePreferencePane preferencePaneIcon]];
	[autoUpdateItem setTarget:self];
	[autoUpdateItem setAction:@selector(displayPreferencePane:)];

	// Network preferences
	networkItem = [[NSToolbarItem alloc] initWithItemIdentifier:[networkPreferencePane preferencePaneIdentifier]];

	[networkItem setLabel:[networkPreferencePane preferencePaneName]];
	[networkItem setImage:[networkPreferencePane preferencePaneIcon]];
	[networkItem setTarget:self];
	[networkItem setAction:@selector(displayPreferencePane:)];

	[toolbar setDelegate:self];
	[toolbar setSelectedItemIdentifier:[generalPreferencePane preferencePaneIdentifier]];
	[toolbar setAllowsUserCustomization:NO];

	[[self window] setToolbar:toolbar];
	[[self window] setShowsToolbarButton:NO];

	[self displayPreferencePane:nil];
}

/**
 * Resizes the window to the size of the supplied view.
 */
- (void)_resizeWindowForContentView:(NSView *)view
{  
	// Remove all subviews
	for (NSView *subview in [[[self window] contentView] subviews]) [subview removeFromSuperview];
  
	// Resize window
	[[self window] resizeForContentView:view titleBarVisible:YES];
  
	// Add view
	[[[self window] contentView] addSubview:view];
	
	[view setFrameOrigin:NSMakePoint(0, 0)];
}

#pragma mark -

/**
 * Dealloc.
 */
- (void)dealloc
{
	[preferencePanes release], preferencePanes = nil;
	
	[super dealloc];
}

@end

//
//  $Id$
//
//  SPPreferenceController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Dec 10, 2008
//  Modified by Ben Perry (benperry.com.au) on Mar 28, 2009
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

#import "SPPreferenceController.h"
#import "SPPreferencesUpgrade.h"
#import "SPTablesPreferencePane.h"
#import "SPEditorPreferencePane.h"

@interface SPPreferenceController (PrivateAPI)

- (void)_setupToolbar;
- (void)_resizeWindowForContentView:(NSView *)view;

@end

#pragma mark -

@implementation SPPreferenceController

@synthesize generalPreferencePane;
@synthesize tablesPreferencePane;
@synthesize favoritesPreferencePane;
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
						
		// Upgrade prefs
		SPApplyRevisionChanges();
		
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

	[generalPreferencePane updateDefaultFavoritePopup];
	
	preferencePanes = [[NSArray alloc] initWithObjects:
					   generalPreferencePane,
					   tablesPreferencePane,
					   notificationsPreferencePane,
					   favoritesPreferencePane,
					   editorPreferencePane,
					   autoUpdatePreferencePane,
					   networkPreferencePane,
					   nil];
}

#pragma mark -
#pragma mark Toolbar item IBAction methods

- (IBAction)displayPreferencePane:(id)sender
{	
	SPPreferencePane *preferencePane = nil;
	
	if (!sender) {
		preferencePane = generalPreferencePane;
	}
	else {
		for (SPPreferencePane *prefPane in preferencePanes)
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
	
	[tablesPreferencePane updateDisplayedTableFontName];
	
	[self _resizeWindowForContentView:[tablesPreferencePane preferencePaneView]];
}

/** 
 * Displays the favorite preferences pane.
 */
- (IBAction)displayFavoritePreferences:(id)sender
{
	// To make the Favorites pane resizable give the window a minimum size and display the resize indicator. 
	// Notice that we still make all other panes non-resizable by removing the dsiplay of the indicator and
	// resetting the minimum size to zero.
	[[self window] setMinSize:NSMakeSize(500, 381)];
	[[self window] setShowsResizeIndicator:[favoritesPreferencePane preferencePaneAllowsResizing]];
	
	[toolbar setSelectedItemIdentifier:[favoritesPreferencePane preferencePaneIdentifier]];
	
	[self _resizeWindowForContentView:[favoritesPreferencePane preferencePaneView]];
	
	// Set the default favorite popup back to preference
	if ([sender isKindOfClass:[NSMenuItem class]]) {
		[generalPreferencePane resetDefaultFavoritePopupSelection];
	}
}

/**
 * Displays the editor preferences pane.
 */
- (IBAction)displayEditorPreferences:(id)sender
{
	[editorPreferencePane updateColorSchemeSelectionMenu];
	[editorPreferencePane updateDisplayColorThemeName];
	
	[[self window] setMinSize:NSMakeSize(0, 0)];
	[[self window] setShowsResizeIndicator:[editorPreferencePane preferencePaneAllowsResizing]];
	
	[toolbar setSelectedItemIdentifier:[editorPreferencePane preferencePaneIdentifier]];
	
	[editorPreferencePane updateDisplayedEditorFontName];
	
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
		case 1:
			font = [[NSFontPanel sharedFontPanel] panelConvertFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPGlobalResultTableFont]]];
			
			[prefs setObject:[NSArchiver archivedDataWithRootObject:font] forKey:SPGlobalResultTableFont];
			
			[tablesPreferencePane updateDisplayedTableFontName];
			break;
		case 2:
			font = [[NSFontPanel sharedFontPanel] panelConvertFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]]];
			
			[prefs setObject:[NSArchiver archivedDataWithRootObject:font] forKey:SPCustomQueryEditorFont];
			
			[editorPreferencePane updateDisplayedEditorFontName];
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

	// Favorite preferences
	favoritesItem = [[NSToolbarItem alloc] initWithItemIdentifier:[favoritesPreferencePane preferencePaneIdentifier]];

	[favoritesItem setLabel:[favoritesPreferencePane preferencePaneName]];
	[favoritesItem setImage:[favoritesPreferencePane preferencePaneIcon]];
	[favoritesItem setTarget:self];
	[favoritesItem setAction:@selector(displayFavoritePreferences:)];

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

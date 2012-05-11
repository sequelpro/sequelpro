//
//  $Id$
//
//  SPConnectionControllerInitializer.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on January 22, 2012
//  Copyright (c) 2012 Stuart Connolly. All rights reserved.
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

#import "SPConnectionControllerInitializer.h"
#import "SPKeychain.h"
#import "SPFavoritesController.h"
#import "SPTreeNode.h"
#import "SPFavoriteNode.h"
#import "SPGroupNode.h"
#import "SPDatabaseViewController.h"

static NSString *SPConnectionViewNibName = @"ConnectionView";

@interface SPConnectionController ()

- (void)_reloadFavoritesViewData;
- (void)_selectNode:(SPTreeNode *)node;
- (void)_scrollToSelectedNode;
- (void)_restoreOutlineViewStateNode:(SPTreeNode *)node;

- (SPTreeNode *)_favoriteNodeForFavoriteID:(NSInteger)favoriteID;

@end

@implementation SPConnectionController (SPConnectionControllerInitializer)

/**
 * Initialise the connection controller, linking it to the parent document and setting up the parent window.
 */
- (id)initWithDocument:(SPDatabaseDocument *)document
{
	if ((self = [super init])) {
		
		// Weak reference
		dbDocument = document;
		
		databaseConnectionSuperview = [dbDocument databaseView];
		databaseConnectionView = [dbDocument valueForKey:@"contentViewSplitter"];
		
		// Keychain references
		connectionKeychainID = nil;
		connectionKeychainItemName = nil;
		connectionKeychainItemAccount = nil;
		connectionSSHKeychainItemName = nil;
		connectionSSHKeychainItemAccount = nil;
		
		isEditing = NO;
		isConnecting = NO;
		sshTunnel = nil;
		mySQLConnection = nil;
		cancellingConnection = NO;
		mySQLConnectionCancelled = NO;
		favoriteNameFieldWasTouched = YES;
		automaticFavoriteSelection = NO;
		
		[self loadNib];
		[self registerForNotifications];
		
		// Hide the main view and position and display the connection view
		[databaseConnectionView setHidden:YES];
		[connectionView setFrame:[databaseConnectionView frame]];
		[databaseConnectionSuperview addSubview:connectionView];		
		[connectionSplitView setPosition:[[dbDocument valueForKey:@"dbTablesTableView"] frame].size.width ofDividerAtIndex:0];
		[connectionSplitView setDelegate:self];
		
		// Generic folder image for use in the outline view's groups
		folderImage = [[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)] retain];
		
		[folderImage setSize:NSMakeSize(16, 16)];
		
		// Set up a keychain instance and preferences reference, and create the initial favorites list
		keychain = [[SPKeychain alloc] init];
		prefs = [[NSUserDefaults standardUserDefaults] retain];
		
		// Create a reference to the favorites controller, forcing the data to be loaded from disk 
		// and the tree to be constructed.
		favoritesController = [SPFavoritesController sharedFavoritesController];
		
		// Tree references
		favoritesRoot = [favoritesController favoritesTree];
		currentFavorite = nil;
		
		// Update the UI
		[self _reloadFavoritesViewData];
		[self setUpFavoritesOutlineView];
		[self _restoreOutlineViewStateNode:favoritesRoot];

		// Set up the selected favourite, and scroll after a small delay to fix animation delay on Lion
		[self setUpSelectedConnectionFavorite];
		if ([favoritesOutlineView selectedRow] != -1) {
			[self performSelector:@selector(_scrollToSelectedNode) withObject:nil afterDelay:0.0];
		}
		
		// Set sort items
		currentSortItem = (SPFavoritesSortItem)[prefs integerForKey:SPFavoritesSortedBy];
		reverseFavoritesSort = [prefs boolForKey:SPFavoritesSortedInReverse];
	}
	
	return self;
}

/**
 * Loads the connection controllers UI nib.
 */
- (void)loadNib
{
	// Load the connection nib, keeping references to the top-level objects for later release
	nibObjectsToRelease = [[NSMutableArray alloc] init];
	
	NSArray *connectionViewTopLevelObjects = nil;
	NSNib *nibLoader = [[NSNib alloc] initWithNibNamed:SPConnectionViewNibName bundle:[NSBundle mainBundle]];
	
	[nibLoader instantiateNibWithOwner:self topLevelObjects:&connectionViewTopLevelObjects];
	[nibObjectsToRelease addObjectsFromArray:connectionViewTopLevelObjects];
	[nibLoader release];
}

/**
 * Registers for various notifications.
 */
- (void)registerForNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(scrollViewFrameChanged:) 
												 name:NSViewFrameDidChangeNotification 
											   object:nil];
	
	// Registered to be notified of changes to connection information
	[self addObserver:self 
		   forKeyPath:SPFavoriteNameKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteHostKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteUserKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteDatabaseKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteSocketKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoritePortKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteUseSSLKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteSSHHostKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteSSHUserKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteSSHPortKey
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteSSHKeyLocationEnabledKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteSSHKeyLocationKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteSSLKeyFileLocationEnabledKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteSSLKeyFileLocationKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteSSLCertificateFileLocationEnabledKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteSSLCertificateFileLocationKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteSSLCACertFileLocationEnabledKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
	
	[self addObserver:self 
		   forKeyPath:SPFavoriteSSLCACertFileLocationKey 
			  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
			  context:NULL];
}

/**
 * Performs any set up necessary for the favorities outline view.
 */
- (void)setUpFavoritesOutlineView
{
	// Register double click action for the favorites outline view (double click favorite to connect)
	[favoritesOutlineView setTarget:self];
	[favoritesOutlineView setDoubleAction:@selector(nodeDoubleClicked:)];
	
	// Register drag types for the favorites outline view
	[favoritesOutlineView registerForDraggedTypes:[NSArray arrayWithObject:SPFavoritesPasteboardDragType]];
	[favoritesOutlineView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];	
}

/**
 * Sets up the selected connection favorite according to the user's preferences.
 */
- (void)setUpSelectedConnectionFavorite 
{
	SPTreeNode *favorite = [self _favoriteNodeForFavoriteID:[prefs integerForKey:[prefs boolForKey:SPSelectLastFavoriteUsed] ? SPLastFavoriteID : SPDefaultFavorite]];
	
	if (favorite) {
		
		NSNumber *typeNumber = [[[favorite representedObject] nodeFavorite] objectForKey:SPFavoriteTypeKey];
		
		previousType = typeNumber ? [typeNumber integerValue] : SPTCPIPConnection;
		
		[self _selectNode:favorite];
		[self resizeTabViewToConnectionType:[[[[favorite representedObject] nodeFavorite] objectForKey:SPFavoriteTypeKey] integerValue] animating:NO];

		[self _scrollToSelectedNode];
	} 
	else {
		previousType = SPTCPIPConnection;
		
		[self resizeTabViewToConnectionType:SPTCPIPConnection animating:NO];
	}
}

#pragma mark -
#pragma mark Private API

/**
 * Restores the outline views group nodes expansion state.
 *
 * @param node The node to traverse
 */
- (void)_restoreOutlineViewStateNode:(SPTreeNode *)node
{
	if ([node isGroup]) {
		if ([[node representedObject] nodeIsExpanded]) {
			[favoritesOutlineView expandItem:node];
		}
		else {
			[favoritesOutlineView collapseItem:node];
		}
		
		for (SPTreeNode *childNode in [node childNodes])
		{
			if ([childNode isGroup]) {
				[self _restoreOutlineViewStateNode:childNode];
			}
		}
	}
}

@end

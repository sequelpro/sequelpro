//
//  BWSelectableToolbar.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>

@class BWSelectableToolbarHelper;

// Notification that gets sent when a toolbar item has been clicked. You can get the button that was clicked by getting the object
// for the key @"BWClickedItem" in the supplied userInfo dictionary.
extern NSString * const BWSelectableToolbarItemClickedNotification;

@interface BWSelectableToolbar : NSToolbar 
{
	BWSelectableToolbarHelper *helper;
	NSMutableArray *itemIdentifiers;
	NSMutableDictionary *itemsByIdentifier, *enabledByIdentifier;
	BOOL inIB;
	
	// For the IB inspector
	int selectedIndex;
	BOOL isPreferencesToolbar;
}

// Call one of these methods to set the active tab. 
- (void)setSelectedItemIdentifier:(NSString *)itemIdentifier; // Use if you want an action in the tabbed window to change the tab.
- (void)setSelectedItemIdentifierWithoutAnimation:(NSString *)itemIdentifier; // Use if you want to show the window with a certain item selected.

// Programmatically disable or enable a toolbar item. 
- (void)setEnabled:(BOOL)flag forIdentifier:(NSString *)itemIdentifier;

@end

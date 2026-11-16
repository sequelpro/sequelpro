//
//  SPMainToolbar.h
//  sequel-pro
//
//  The main window toolbar ("TableWindowToolbar"), shared by MySQL and PostgreSQL tabs: one set of
//  identifiers and one item factory, so that switching between the engines' tabs in a window shows
//  the same items (artwork, size, position, kind). Each document adds its own targets, actions and
//  views.
//
//  (Default visibility so the app-hosted test bundle can link these despite the app hiding symbols.)
//

#import <Cocoa/Cocoa.h>

/// Every item the toolbar can show (the customization palette).
__attribute__((visibility("default"))) NSArray *SPMainToolbarAllowedItemIdentifiers(void);

/// The default layout.
__attribute__((visibility("default"))) NSArray *SPMainToolbarDefaultItemIdentifiers(void);

/// The items that show a selection (the table view switchers). These are drawn without a button bezel.
__attribute__((visibility("default"))) NSArray *SPMainToolbarSelectableItemIdentifiers(void);

/**
 * A new (autoreleased) item for `identifier`, as MySQL tabs show it: label, palette label, tooltip,
 * compact (24 pt) image and item class (the Transfer item is an SPDisabledToolbarItem). Targets,
 * actions and views are the caller's. The database picker and history items get their labels only.
 * Returns nil for an identifier the toolbar doesn't have.
 */
__attribute__((visibility("default"))) NSToolbarItem *SPCreateMainToolbarItem(NSString *identifier);

/// The Users item's image: two people, the one behind lighter (a template image, so white in Dark Mode), 24 x 24.
__attribute__((visibility("default"))) NSImage *SPUsersToolbarImage(void);

/**
 * A new (autoreleased) database picker, styled as DBView.xib's chooseDatabaseButton: textured
 * rounded bezel, centred title in the 12 pt title bar font, truncated at the tail, and the same
 * autoresizing. Has no items.
 */
__attribute__((visibility("default"))) NSPopUpButton *SPCreateDatabaseToolbarPopUpButton(void);

/**
 * A new (autoreleased) history navigation control, as DBView.xib's historyControl: two 27 pt
 * textured-square momentary segments (back, forward), both disabled, sized to fit.
 */
__attribute__((visibility("default"))) NSSegmentedControl *SPCreateHistoryToolbarControl(void);

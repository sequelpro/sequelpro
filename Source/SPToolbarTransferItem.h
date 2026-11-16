//
//  SPToolbarTransferItem.h
//  sequel-pro
//
//  The main toolbar's Transfer item (SPMainToolbarTransfer), shared by the MySQL and PostgreSQL tabs
//  of a window. Both use the toolbar identifier "TableWindowToolbar", so they share the saved layout.
//  Transfer is PostgreSQL-only: MySQL tabs show it, always disabled.
//
//  (Default visibility so the app-hosted test bundle can link these despite the app hiding symbols.)
//

#import <Cocoa/Cocoa.h>

/**
 * The Transfer image: SF Symbol "arrow.left.arrow.right" centred on a 24 pt canvas, like the other
 * compact toolbar images (see SPCompactToolbarImage). A template image.
 */
__attribute__((visibility("default"))) NSImage *SPTransferToolbarImage(void);

/**
 * Sets the Transfer item's label, palette label, tooltip and image. Target, action and enabling are the
 * caller's.
 */
__attribute__((visibility("default"))) void SPConfigureTransferToolbarItem(NSToolbarItem *item);

/**
 * A saved layout from before the Transfer item existed lacks it: insert it once, right after Query
 * (or after Users if Query was removed, else before Console, else at the end), and record that under
 * SPToolbarTransferItemAdded in `defaults`. Once recorded nothing is inserted again, so removing the
 * item with Customize Toolbar sticks. Call once the toolbar is in a window: before that it has no
 * items, and nothing is inserted or recorded.
 *
 * Returns YES if the item was inserted.
 */
__attribute__((visibility("default"))) BOOL SPInsertTransferToolbarItemIfNeeded(NSToolbar *toolbar, NSUserDefaults *defaults);

/**
 * Transfer used to come right after Users: in a saved layout that has both Transfer and Query, move
 * Transfer once to right after Query, and record that under SPToolbarTransferItemMovedAfterQuery in
 * `defaults`. Once recorded nothing is moved again, so placing the item elsewhere with Customize
 * Toolbar sticks. A layout without Transfer or Query is left as it is (and recorded). Call once the
 * toolbar is in a window (after SPInsertTransferToolbarItemIfNeeded): before that it has no items,
 * and nothing is moved or recorded.
 *
 * Returns YES if the item was moved.
 */
__attribute__((visibility("default"))) BOOL SPMoveTransferToolbarItemAfterQueryIfNeeded(NSToolbar *toolbar, NSUserDefaults *defaults);

/**
 * A toolbar item that is never enabled: -setEnabled: always stores NO and validation keeps it so.
 * (Used for MySQL's Transfer item, which SPConnectionController's "enable every item" after a
 * connect would otherwise enable.)
 */
__attribute__((visibility("default")))
@interface SPDisabledToolbarItem : NSToolbarItem
@end

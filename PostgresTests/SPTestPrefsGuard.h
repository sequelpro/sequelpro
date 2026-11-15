#import <Cocoa/Cocoa.h>

/// The preference SPInsertTransferToolbarItemIfNeeded records itself in (forced to YES for the test run).
extern NSString * const SPTestTransferAddedKey;
/// The preference SPMoveTransferToolbarItemAfterQueryIfNeeded records itself in (forced to YES for the test run).
extern NSString * const SPTestTransferMovedKey;

/// MySQL's SPSelectLastFavoriteUsed / SPDefaultFavorite (forced to NO / 0 for the test run, so MySQL
/// connection tabs preselect no saved favorite and never read its password from the keychain).
extern NSString * const SPTestSelectLastFavoriteUsedKey;
extern NSString * const SPTestDefaultFavoriteKey;

/// Sparkle's SUEnableAutomaticChecks (forced to NO for the test run, so no update check fires during a test).
extern NSString * const SPTestSparkleAutomaticChecksKey;

/// NSAutomaticWindowAnimationsEnabled (forced to NO for the test run, so windows order in and out without animating).
extern NSString * const SPTestWindowAnimationsKey;

@interface NSToolbar (SPTestPrefsGuard)
/// The value last passed to -setAutosavesConfiguration: (which, in tests, always stores NO).
- (BOOL)sp_requestedAutosave;
@end

@interface NSSplitView (SPTestPrefsGuard)
/// The name last passed to -setAutosaveName: (which, in tests, always stores nil).
- (NSString *)sp_requestedAutosaveName;
@end

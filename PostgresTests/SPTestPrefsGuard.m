#import "SPTestPrefsGuard.h"
#import "../Source/Postgres/SPPostgresQueryStore.h"
#import "../Source/Postgres/SPQueryScriptStore.h"
#import "../Source/Postgres/SPPostgresFeatureScope.h"
#import <objc/runtime.h>
#import <XCTest/XCTest.h>

NSString * const SPTestTransferAddedKey = @"SPToolbarTransferItemAdded";
NSString * const SPTestTransferMovedKey = @"SPToolbarTransferItemMovedAfterQuery";
NSString * const SPTestUsersPlacedKey = @"SPToolbarUsersItemPlacedAfterTransfer";
NSString * const SPTestUpdateAutomaticChecksKey = @"SPUpdateAutomaticChecks";
NSString * const SPTestSelectLastFavoriteUsedKey = @"SelectLastFavoriteUsed";
NSString * const SPTestDefaultFavoriteKey = @"DefaultFavorite";
NSString * const SPTestSparkleAutomaticChecksKey = @"SUEnableAutomaticChecks";
NSString * const SPTestWindowAnimationsKey = @"NSAutomaticWindowAnimationsEnabled";
NSString * const SPTestAlwaysShowTabBarKey = @"WindowAlwaysShowTabBar";

static const void *SPRequestedAutosaveKey = &SPRequestedAutosaveKey;
static const void *SPRequestedAutosaveNameKey = &SPRequestedAutosaveNameKey;

#pragma mark - Keeping the test run out of the real preferences

/**
 * The test bundle runs inside the app, so [NSUserDefaults standardUserDefaults] is the owner's real
 * preferences, where the "TableWindowToolbar" layout is saved. For the whole test run (every test
 * class):
 *
 * - Toolbars never autosave: -setAutosavesConfiguration: always stores NO (the requested value is
 *   kept on the toolbar for assertions, see -sp_requestedAutosave). So toolbars in tests use their
 *   delegate's default layout and nothing a test does to them (insert, remove, hide) is saved.
 * - Split views never autosave: -[NSSplitView setAutosaveName:] always stores nil (the requested
 *   name is kept on the split view for assertions, see -sp_requestedAutosaveName). With no name,
 *   neither AppKit ("NSSplitView Subview Frames <name>") nor SPSplitView ("SPSplitView Lengths
 *   <name>") saves or restores divider positions, so split views in tests use their built layout.
 * - SPToolbarTransferItemAdded reads YES from the volatile argument domain, so documents created by
 *   tests never try the one-time Transfer insertion, which records itself in the given defaults.
 *   SPToolbarTransferItemMovedAfterQuery reads YES too, so they never try the one-time move either, nor (with
 *   SPToolbarUsersItemPlacedAfterTransfer) the one-time placing of Users.
 * - MySQL connection tabs preselect no saved favorite: SelectLastFavoriteUsed reads NO and
 *   DefaultFavorite 0 (Quick Connect) from the volatile argument domain. Otherwise a new MySQL tab
 *   selects the owner's favorite and reads its password from the login keychain
 *   (-[SPConnectionController updateFavoriteSelection:]), which can block the run on a keychain
 *   access prompt (e.g. after a rebuild changes the app's signature).
 *
 * - The Postgres Query tab's shared history and favorites stores (+[SPPostgresQueryStore sharedHistoryStore] /
 *   +sharedFavoritesStore) are stores on a temporary directory of this run, never the real files under Application
 *   Support: every query a test runs through a Query view is recorded in the shared history unless the test injects
 *   its own store. Their files are removed after every test (so no test sees another's history), and the folder at
 *   the end of the run.
 *
 * - The Query editors' saved scripts (+[SPQueryScriptStore sharedStore], MySQL and PostgreSQL tabs) are in a folder of
 *   this run's temporary directory, never the real "Query Scripts" folder under Application Support. Its files are
 *   removed after every test.
 *
 * - Sequel Plus's GitHub update checks are off too (SPUpdateAutomaticChecks reads NO), so a test run never asks
 *   GitHub or shows an update alert.
 * - Sparkle's automatic update checks are off (SUEnableAutomaticChecks reads NO from the volatile argument
 *   domain, and a check already scheduled is dropped), so no check runs in the middle of a test.
 *
 * - Postgres tabs have every feature (SPPostgresFeatureScopeSetFullScopeForTesting(YES)), not the release's scope
 *   (SPPostgresFeatureScope.m), so the tests of features a release holds back keep exercising them. It is set again
 *   before every test, so a test of the release scope (SPPostgresFeatureScopeTests, which sets NO) can't leak it.
 *
 * All are in place before any test runs (+load runs when the bundle is loaded).
 *
 * This file must stay in the "Postgres Tests" target for as long as any test creates a document,
 * window or toolbar: it is deliberately not part of any test class, so removing or renaming test
 * files can never switch it off. SPPostgresToolbarTests asserts that it is active.
 */
@implementation NSToolbar (SPTestPrefsGuard)

- (void)sp_test_setAutosavesConfiguration:(BOOL)flag
{
	objc_setAssociatedObject(self, SPRequestedAutosaveKey, @(flag), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[self sp_test_setAutosavesConfiguration:NO]; // the original implementation (swapped)
}

- (BOOL)sp_requestedAutosave
{
	return [objc_getAssociatedObject(self, SPRequestedAutosaveKey) boolValue];
}

@end

@implementation NSSplitView (SPTestPrefsGuard)

- (void)sp_test_setAutosaveName:(NSString *)name
{
	objc_setAssociatedObject(self, SPRequestedAutosaveNameKey, name, OBJC_ASSOCIATION_COPY_NONATOMIC);
	[self sp_test_setAutosaveName:nil]; // the original implementation (swapped)
}

- (NSString *)sp_requestedAutosaveName
{
	return objc_getAssociatedObject(self, SPRequestedAutosaveNameKey);
}

@end

@interface SPTestPrefsGuard : NSObject <XCTestObservation>
@end

/// The redirected stores' folder (see +load)
static NSString *SPTestQueryStoreDirectory = nil;

@implementation SPTestPrefsGuard

+ (void)load
{
	// Every Postgres feature, whatever the release's scope (see the comment above)
	SPPostgresFeatureScopeSetFullScopeForTesting(YES);

	Method original = class_getInstanceMethod([NSToolbar class], @selector(setAutosavesConfiguration:));
	Method replacement = class_getInstanceMethod([NSToolbar class], @selector(sp_test_setAutosavesConfiguration:));
	method_exchangeImplementations(original, replacement);

	Method originalSplit = class_getInstanceMethod([NSSplitView class], @selector(setAutosaveName:));
	Method replacementSplit = class_getInstanceMethod([NSSplitView class], @selector(sp_test_setAutosaveName:));
	method_exchangeImplementations(originalSplit, replacementSplit);

	// The Postgres Query tab's shared stores: on a temporary directory of this run
	NSString *storeDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:
		[NSString stringWithFormat:@"SPPostgresTestQueryStores-%d-%@", [[NSProcessInfo processInfo] processIdentifier], [[NSUUID UUID] UUIDString]]];
	SPTestQueryStoreDirectory = [storeDirectory copy];
	SPPostgresQueryStore *historyStore = [[SPPostgresQueryStore alloc] initWithFileURL:[NSURL fileURLWithPath:[storeDirectory stringByAppendingPathComponent:@"PostgresQueryHistory.plist"]]];
	SPPostgresQueryStore *favoritesStore = [[SPPostgresQueryStore alloc] initWithFileURL:[NSURL fileURLWithPath:[storeDirectory stringByAppendingPathComponent:@"PostgresQueryFavorites.plist"]]];
	method_setImplementation(class_getClassMethod([SPPostgresQueryStore class], @selector(sharedHistoryStore)),
							 imp_implementationWithBlock(^id(id me) { return historyStore; }));
	method_setImplementation(class_getClassMethod([SPPostgresQueryStore class], @selector(sharedFavoritesStore)),
							 imp_implementationWithBlock(^id(id me) { return favoritesStore; }));
	// The Query editors' saved scripts: in the same temporary directory
	SPQueryScriptStore *scriptStore = [[SPQueryScriptStore alloc] initWithDirectoryURL:[NSURL fileURLWithPath:[storeDirectory stringByAppendingPathComponent:@"Query Scripts"] isDirectory:YES]];
	method_setImplementation(class_getClassMethod([SPQueryScriptStore class], @selector(sharedStore)),
							 imp_implementationWithBlock(^id(id me) { return scriptStore; }));
	// Emptied after every test, removed at the end of the run
	static SPTestPrefsGuard *observer = nil;
	observer = [[SPTestPrefsGuard alloc] init];
	[[XCTestObservationCenter sharedTestObservationCenter] addTestObserver:observer];

	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *domain = [([prefs volatileDomainForName:NSArgumentDomain] ?: @{}) mutableCopy];
	domain[SPTestTransferAddedKey] = @YES;
	domain[SPTestTransferMovedKey] = @YES;
	domain[SPTestUsersPlacedKey] = @YES;
	domain[SPTestUpdateAutomaticChecksKey] = @NO;
	domain[SPTestSelectLastFavoriteUsedKey] = @NO;
	domain[SPTestDefaultFavoriteKey] = @0;
	// Sparkle never checks for updates during the run: a check needs the bundle version, which test builds leave
	// empty, and its SUNoVersionException would surface in whichever test is spinning the run loop
	domain[SPTestSparkleAutomaticChecksKey] = @NO;
	// Windows order in and out without AppKit's open/close animation: in the test host each such animation runs on a
	// GCD worker that never finishes, so a full run exhausts the worker pool and blocks later dispatches (the task
	// runner's cancel request among them)
	domain[SPTestWindowAnimationsKey] = @NO;
	// The window tab bar is always shown, so it never runs its show/hide animation: a test that frees its window
	// controller right after closing a tab would otherwise leave that animation firing on the freed controller.
	// (Before the app had its own ID, the runs inherited this setting from the owner's Sequel Pro preferences.)
	domain[SPTestAlwaysShowTabBarKey] = @YES;
	[prefs removeVolatileDomainForName:NSArgumentDomain];
	[prefs setVolatileDomain:domain forName:NSArgumentDomain];

	// A check the updater already scheduled is dropped: it reschedules from the (now disabled) preference. This
	// doesn't write the preference (unlike -setAutomaticallyChecksForUpdates:).
	dispatch_async(dispatch_get_main_queue(), ^{
		Class updaterClass = NSClassFromString(@"SUUpdater");
		id updater = [updaterClass respondsToSelector:@selector(sharedUpdater)] ? [updaterClass performSelector:@selector(sharedUpdater)] : nil;
		if ([updater respondsToSelector:@selector(resetUpdateCycle)]) [updater performSelector:@selector(resetUpdateCycle)];
	});
}

/// Each test starts with the full Postgres feature scope (a test of the release scope sets its own in -setUp).
- (void)testCaseWillStart:(XCTestCase *)testCase
{
	SPPostgresFeatureScopeSetFullScopeForTesting(YES);
}

/// The redirected shared stores' files are removed, so the next test starts with no history or favorites (the stores
/// reload when their file changes, so a missing file reads as empty).
- (void)testCaseDidFinish:(XCTestCase *)testCase
{
	NSFileManager *manager = [NSFileManager defaultManager];
	[manager removeItemAtURL:[[SPPostgresQueryStore sharedHistoryStore] fileURL] error:NULL];
	[manager removeItemAtURL:[[SPPostgresQueryStore sharedFavoritesStore] fileURL] error:NULL];
	[manager removeItemAtURL:[[SPQueryScriptStore sharedStore] directoryURL] error:NULL];
}

- (void)testBundleDidFinish:(NSBundle *)testBundle
{
	if (SPTestQueryStoreDirectory) [[NSFileManager defaultManager] removeItemAtPath:SPTestQueryStoreDirectory error:NULL];
}

@end

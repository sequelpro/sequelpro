#import <XCTest/XCTest.h>
#import "SPTestPrefsGuard.h"
#import "../Source/SPUpdateChecker.h"

/// Preferences in memory (never a file).
@interface SPUpdateTestsDefaults : NSUserDefaults
@property (strong) NSMutableDictionary *values;
@end

@implementation SPUpdateTestsDefaults
- (instancetype)init
{
	if ((self = [super init])) _values = [NSMutableDictionary dictionary];
	return self;
}
- (id)objectForKey:(NSString *)key { return self.values[key]; }
- (void)setObject:(id)value forKey:(NSString *)key { if (value) self.values[key] = value; else [self.values removeObjectForKey:key]; }
- (void)removeObjectForKey:(NSString *)key { [self.values removeObjectForKey:key]; }
- (BOOL)boolForKey:(NSString *)key { return [self.values[key] boolValue]; }
- (double)doubleForKey:(NSString *)key { return [self.values[key] doubleValue]; }
- (NSString *)stringForKey:(NSString *)key { id value = self.values[key]; return [value isKindOfClass:[NSString class]] ? value : nil; }
- (void)setBool:(BOOL)value forKey:(NSString *)key { self.values[key] = @(value); }
@end

/**
 * SPUpdateChecker: GitHub's latest release against this app's version, with GitHub, the alerts and the browser
 * replaced (nothing is fetched, shown or opened for real).
 */
@interface SPUpdateCheckerTests : XCTestCase
@property (strong) SPUpdateTestsDefaults *defaults;
@property (strong) SPUpdateChecker *checker;
@property (strong) NSMutableArray<NSURL *> *fetched;
@property (strong) NSMutableArray<NSAlert *> *alerts;
@property (strong) NSMutableArray<NSURL *> *opened;
/// What the fake GitHub answers.
@property (strong) NSData *answer;
@property NSInteger status;
@property (strong) NSError *error;
/// The button the fake alert presenter clicks.
@property NSModalResponse click;
@end

@implementation SPUpdateCheckerTests

- (BOOL)spinUntil:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout
{
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
	while (!condition() && [deadline timeIntervalSinceNow] > 0) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	}
	return condition();
}

- (NSData *)releaseJSON:(NSString *)tag notes:(NSString *)notes zip:(BOOL)zip
{
	NSMutableDictionary *json = [@{@"tag_name": tag, @"name": [NSString stringWithFormat:@"Sequel Plus %@", tag], @"body": notes,
								   @"html_url": [NSString stringWithFormat:@"https://github.com/JackXiao2017/sequel-plus/releases/tag/%@", tag],
								   @"draft": @NO, @"prerelease": @NO} mutableCopy];
	NSMutableArray *assets = [NSMutableArray arrayWithObject:@{@"name": @"checksums.txt", @"browser_download_url": @"https://example.invalid/checksums.txt"}];
	if (zip) [assets addObject:@{@"name": [NSString stringWithFormat:@"Sequel-Plus-%@.zip", tag],
								 @"browser_download_url": [NSString stringWithFormat:@"https://github.com/JackXiao2017/sequel-plus/releases/download/%@/Sequel-Plus-%@.zip", tag, tag]}];
	json[@"assets"] = assets;
	return [NSJSONSerialization dataWithJSONObject:json options:0 error:NULL];
}

- (void)setUp
{
	self.defaults = [[SPUpdateTestsDefaults alloc] init];
	self.defaults.values[@"SPUpdateAutomaticChecks"] = @YES;
	self.defaults.values[@"SPUpdateCheckInterval"] = @86400;
	self.checker = [[SPUpdateChecker alloc] initWithDefaults:self.defaults];
	self.checker.currentVersion = @"2.0.3";
	self.fetched = [NSMutableArray array];
	self.alerts = [NSMutableArray array];
	self.opened = [NSMutableArray array];
	self.status = 200;
	self.click = NSAlertSecondButtonReturn;

	__weak SPUpdateCheckerTests *weakSelf = self;
	self.checker.fetcher = ^(NSURL *url, void (^completion)(NSData *, NSInteger, NSError *)) {
		SPUpdateCheckerTests *me = weakSelf;
		[me.fetched addObject:url];
		NSData *data = me.answer;
		NSInteger status = me.status;
		NSError *error = me.error;
		// As NSURLSession's: on another thread, later
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ completion(data, status, error); });
	};
	self.checker.alertPresenter = ^NSModalResponse(NSAlert *alert) {
		[weakSelf.alerts addObject:alert];
		return weakSelf.click;
	};
	self.checker.urlOpener = ^(NSURL *url) { [weakSelf.opened addObject:url]; };
}

- (void)waitForCheck
{
	XCTAssertTrue([self spinUntil:^BOOL{ return !self.checker.checking; } timeout:5]);
}

#pragma mark - Versions

- (void)testVersionsCompareNumerically
{
	XCTAssertEqual([SPUpdateChecker compareVersion:@"2.0.4" toVersion:@"2.0.3"], NSOrderedDescending);
	XCTAssertEqual([SPUpdateChecker compareVersion:@"2.0.10" toVersion:@"2.0.9"], NSOrderedDescending);
	XCTAssertEqual([SPUpdateChecker compareVersion:@"2.1" toVersion:@"2.0.9"], NSOrderedDescending);
	XCTAssertEqual([SPUpdateChecker compareVersion:@"2.0" toVersion:@"2.0.0"], NSOrderedSame);
	XCTAssertEqual([SPUpdateChecker compareVersion:@"v2.0.3" toVersion:@"2.0.3"], NSOrderedSame);
	XCTAssertEqual([SPUpdateChecker compareVersion:@"2.0.2" toVersion:@"2.0.3"], NSOrderedAscending);
	// A pre-release is older than its release, newer than the one before
	XCTAssertEqual([SPUpdateChecker compareVersion:@"2.0.0-RC4" toVersion:@"2.0.0"], NSOrderedAscending);
	XCTAssertEqual([SPUpdateChecker compareVersion:@"2.0.0" toVersion:@"2.0.0-RC4"], NSOrderedDescending);
	XCTAssertEqual([SPUpdateChecker compareVersion:@"2.0.0 RC3" toVersion:@"1.9"], NSOrderedDescending);
}

- (void)testReleaseReadsTheZipAndNotes
{
	SPUpdateRelease *release = [SPUpdateRelease releaseWithJSON:[NSJSONSerialization JSONObjectWithData:[self releaseJSON:@"v2.0.4" notes:@"  Fixes.\n" zip:YES] options:0 error:NULL]];
	XCTAssertEqualObjects(release.version, @"2.0.4");
	XCTAssertEqualObjects(release.notes, @"Fixes.");
	XCTAssertEqualObjects(release.downloadURL.absoluteString, @"https://github.com/JackXiao2017/sequel-plus/releases/download/v2.0.4/Sequel-Plus-v2.0.4.zip");
	XCTAssertEqualObjects(release.pageURL.absoluteString, @"https://github.com/JackXiao2017/sequel-plus/releases/tag/v2.0.4");
	XCTAssertNil([SPUpdateRelease releaseWithJSON:(NSDictionary *)@[]]);
	XCTAssertNil([SPUpdateRelease releaseWithJSON:@{@"name": @"no tag"}]);
}

- (void)testTheDefaultURLIsTheRepositorysLatestRelease
{
	SPUpdateChecker *checker = [[SPUpdateChecker alloc] initWithDefaults:self.defaults];
	XCTAssertEqualObjects(checker.latestReleaseURL.absoluteString, @"https://api.github.com/repos/JackXiao2017/sequel-plus/releases/latest");
	XCTAssertEqualObjects(checker.currentVersion, [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]);
}

#pragma mark - Asked by the user

- (void)testANewerReleaseIsOfferedAndDownloadOpensTheZip
{
	self.answer = [self releaseJSON:@"2.0.4" notes:@"New: update check." zip:YES];
	self.click = NSAlertFirstButtonReturn;
	[self.checker checkForUpdates:nil];
	XCTAssertTrue(self.checker.checking);
	[self waitForCheck];

	XCTAssertEqualObjects(self.fetched.firstObject.absoluteString, @"https://api.github.com/repos/JackXiao2017/sequel-plus/releases/latest");
	XCTAssertEqual(self.alerts.count, 1u);
	NSAlert *alert = self.alerts.firstObject;
	XCTAssertEqualObjects(alert.messageText, @"A new version of Sequel Plus is available");
	XCTAssertTrue([alert.informativeText containsString:@"Sequel Plus 2.0.4 is available — you have 2.0.3."], @"%@", alert.informativeText);
	XCTAssertEqualObjects([alert.buttons valueForKey:@"title"], (@[@"Download", @"Remind Me Later", @"Skip This Version"]));
	NSTextView *notes = [(NSScrollView *)alert.accessoryView documentView];
	XCTAssertEqualObjects(notes.string, @"New: update check.");
	XCTAssertFalse(notes.isEditable);

	XCTAssertEqualObjects(self.opened, (@[[NSURL URLWithString:@"https://github.com/JackXiao2017/sequel-plus/releases/download/2.0.4/Sequel-Plus-2.0.4.zip"]]));
	XCTAssertTrue([self.defaults.values[@"SPUpdateLastCheckTime"] isKindOfClass:[NSDate class]]);
}

- (void)testWithoutAZipDownloadOpensTheReleasePage
{
	self.answer = [self releaseJSON:@"2.0.4" notes:@"" zip:NO];
	self.click = NSAlertFirstButtonReturn;
	[self.checker checkForUpdates:nil];
	[self waitForCheck];
	XCTAssertNil(self.alerts.firstObject.accessoryView, @"no notes, no notes view");
	XCTAssertEqualObjects(self.opened.firstObject.absoluteString, @"https://github.com/JackXiao2017/sequel-plus/releases/tag/2.0.4");
}

- (void)testUpToDateSaysSo
{
	for (NSString *tag in @[@"2.0.3", @"2.0.2", @"2.0.3-RC1"]) {
		[self.alerts removeAllObjects];
		self.answer = [self releaseJSON:tag notes:@"" zip:YES];
		[self.checker checkForUpdates:nil];
		[self waitForCheck];
		XCTAssertEqual(self.alerts.count, 1u, @"%@", tag);
		XCTAssertEqualObjects(self.alerts.firstObject.messageText, @"You're up to date!", @"%@", tag);
		XCTAssertEqualObjects(self.alerts.firstObject.informativeText, @"Sequel Plus 2.0.3 is the newest version available.");
	}
	XCTAssertEqual(self.opened.count, 0u);
}

- (void)testFailuresSaySo
{
	NSDictionary *cases = @{@404: @"No Sequel Plus release was found on GitHub.",
							@403: @"GitHub is limiting how often it can be asked. Try again in an hour.",
							@500: @"GitHub answered with HTTP status 500."};
	for (NSNumber *status in cases) {
		[self.alerts removeAllObjects];
		self.status = status.integerValue;
		self.answer = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
		[self.checker checkForUpdates:nil];
		[self waitForCheck];
		XCTAssertEqualObjects(self.alerts.firstObject.messageText, @"Couldn't check for updates");
		XCTAssertEqualObjects(self.alerts.firstObject.informativeText, cases[status]);
	}

	[self.alerts removeAllObjects];
	self.status = 0;
	self.error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:@{NSLocalizedDescriptionKey: @"The Internet connection appears to be offline."}];
	[self.checker checkForUpdates:nil];
	[self waitForCheck];
	XCTAssertEqualObjects(self.alerts.firstObject.informativeText, @"The Internet connection appears to be offline.");

	[self.alerts removeAllObjects];
	self.error = nil;
	self.status = 200;
	self.answer = [@"not json" dataUsingEncoding:NSUTF8StringEncoding];
	[self.checker checkForUpdates:nil];
	[self waitForCheck];
	XCTAssertEqualObjects(self.alerts.firstObject.informativeText, @"GitHub's answer couldn't be read.");
	XCTAssertNil(self.defaults.values[@"SPUpdateLastCheckTime"], @"a failed check isn't a check");
}

- (void)testSkipThisVersion
{
	self.answer = [self releaseJSON:@"2.0.4" notes:@"" zip:YES];
	self.click = NSAlertThirdButtonReturn;
	[self.checker checkForUpdates:nil];
	[self waitForCheck];
	XCTAssertEqualObjects(self.defaults.values[@"SPUpdateSkippedVersion"], @"2.0.4");
	XCTAssertEqual(self.opened.count, 0u);

	// Asking again still shows it
	[self.alerts removeAllObjects];
	self.click = NSAlertSecondButtonReturn;
	[self.checker checkForUpdates:nil];
	[self waitForCheck];
	XCTAssertEqualObjects(self.alerts.firstObject.messageText, @"A new version of Sequel Plus is available");

	// An automatic check doesn't
	[self.alerts removeAllObjects];
	[self.defaults removeObjectForKey:@"SPUpdateLastCheckTime"];
	XCTAssertTrue([self.checker checkInBackgroundIfDue]);
	[self waitForCheck];
	XCTAssertEqual(self.alerts.count, 0u);

	// But it does show the next one
	self.answer = [self releaseJSON:@"2.0.5" notes:@"" zip:YES];
	[self.defaults removeObjectForKey:@"SPUpdateLastCheckTime"];
	XCTAssertTrue([self.checker checkInBackgroundIfDue]);
	[self waitForCheck];
	XCTAssertEqual(self.alerts.count, 1u);
	XCTAssertTrue([self.alerts.firstObject.informativeText containsString:@"2.0.5"]);
}

#pragma mark - Automatic

- (void)testAutomaticChecksAreQuietUnlessThereIsAnUpdate
{
	self.answer = [self releaseJSON:@"2.0.3" notes:@"" zip:YES];
	XCTAssertTrue([self.checker checkInBackgroundIfDue]);
	[self waitForCheck];
	XCTAssertEqual(self.alerts.count, 0u, @"up to date: nothing said");
	XCTAssertNotNil(self.defaults.values[@"SPUpdateLastCheckTime"]);

	// Failures are quiet too
	[self.defaults removeObjectForKey:@"SPUpdateLastCheckTime"];
	self.status = 500;
	XCTAssertTrue([self.checker checkInBackgroundIfDue]);
	[self waitForCheck];
	XCTAssertEqual(self.alerts.count, 0u);

	// An update is offered
	self.status = 200;
	self.answer = [self releaseJSON:@"2.1.0" notes:@"" zip:YES];
	XCTAssertTrue([self.checker checkInBackgroundIfDue]);
	[self waitForCheck];
	XCTAssertEqual(self.alerts.count, 1u);
}

- (void)testAutomaticChecksFollowThePreferences
{
	self.answer = [self releaseJSON:@"2.0.3" notes:@"" zip:YES];

	// Checked an hour ago, daily: not due
	self.defaults.values[@"SPUpdateLastCheckTime"] = [NSDate dateWithTimeIntervalSinceNow:-3600];
	XCTAssertFalse([self.checker checkInBackgroundIfDue]);
	// Hourly: due
	self.defaults.values[@"SPUpdateCheckInterval"] = @3600;
	self.defaults.values[@"SPUpdateLastCheckTime"] = [NSDate dateWithTimeIntervalSinceNow:-3700];
	XCTAssertTrue([self.checker checkInBackgroundIfDue]);
	[self waitForCheck];
	// Off: never
	self.defaults.values[@"SPUpdateAutomaticChecks"] = @NO;
	[self.defaults removeObjectForKey:@"SPUpdateLastCheckTime"];
	XCTAssertFalse([self.checker checkInBackgroundIfDue]);
	XCTAssertEqual(self.fetched.count, 1u);
}

- (void)testAskingDuringAnAutomaticCheckMakesItAnswer
{
	self.answer = [self releaseJSON:@"2.0.3" notes:@"" zip:YES];
	XCTAssertTrue([self.checker checkInBackgroundIfDue]);
	[self.checker checkForUpdates:nil];
	XCTAssertFalse([self.checker checkInBackgroundIfDue], @"one at a time");
	[self waitForCheck];
	XCTAssertEqual(self.fetched.count, 1u);
	XCTAssertEqualObjects(self.alerts.firstObject.messageText, @"You're up to date!");
}

#pragma mark - The app

- (void)testTestRunsNeverCheckAutomatically
{
	XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:SPTestUpdateAutomaticChecksKey]);
}

- (void)testTheAppMenuOffersCheckForUpdates
{
	NSMenu *appMenu = [[[NSApp mainMenu] itemAtIndex:0] submenu];
	NSInteger index = [appMenu indexOfItemWithTitle:@"Check for Updates..."];
	XCTAssertNotEqual(index, -1);
	NSMenuItem *item = [appMenu itemAtIndex:index];
	XCTAssertFalse(item.hidden);
	XCTAssertEqualObjects(NSStringFromSelector(item.action), @"checkForUpdates:");
	XCTAssertNil(item.target, @"up the responder chain, to the app's delegate");
	XCTAssertTrue([[NSApp delegate] respondsToSelector:@selector(checkForUpdates:)]);
	XCTAssertEqual([NSApp targetForAction:@selector(checkForUpdates:)], [NSApp delegate]);
}

@end

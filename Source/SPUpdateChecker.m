//
//  SPUpdateChecker.m
//  Sequel Plus
//

#import "SPUpdateChecker.h"
#import "SPConstants.h"

NSString * const SPUpdateLatestReleaseURL = @"https://api.github.com/repos/JackXiao2017/sequel-plus/releases/latest";

/// The first automatic check comes this long after launch (not in the middle of opening the first window).
static const NSTimeInterval SPUpdateFirstCheckDelay = 5;
/// How often whether a check is due is looked at again.
static const NSTimeInterval SPUpdateRecheckInterval = 3600;
/// Below this the preference is ignored (a check at most hourly).
static const NSTimeInterval SPUpdateMinimumInterval = 3600;
static const NSTimeInterval SPUpdateDefaultInterval = 86400;

#pragma mark - SPUpdateRelease

@interface SPUpdateRelease ()
@property (readwrite, copy) NSString *version;
@property (readwrite, copy) NSString *title;
@property (readwrite, copy) NSString *notes;
@property (readwrite, copy) NSURL *pageURL;
@property (readwrite, copy) NSURL *downloadURL;
@end

@implementation SPUpdateRelease

@synthesize version;
@synthesize title;
@synthesize notes;
@synthesize pageURL;
@synthesize downloadURL;

static NSString *SPUpdateString(id value)
{
	return [value isKindOfClass:[NSString class]] ? value : nil;
}

+ (instancetype)releaseWithJSON:(NSDictionary *)json
{
	if (![json isKindOfClass:[NSDictionary class]]) return nil;
	NSString *tag = [SPUpdateString([json objectForKey:@"tag_name"]) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([tag hasPrefix:@"v"] || [tag hasPrefix:@"V"]) tag = [tag substringFromIndex:1];
	if (![tag length]) return nil;

	SPUpdateRelease *release = [[[self alloc] init] autorelease];
	release.version = tag;
	release.title = [SPUpdateString([json objectForKey:@"name"]) length] ? SPUpdateString([json objectForKey:@"name"]) : tag;
	release.notes = [SPUpdateString([json objectForKey:@"body"]) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
	NSString *page = SPUpdateString([json objectForKey:@"html_url"]);
	if (page) release.pageURL = [NSURL URLWithString:page];

	id assets = [json objectForKey:@"assets"];
	if ([assets isKindOfClass:[NSArray class]]) {
		for (NSDictionary *asset in assets) {
			if (![asset isKindOfClass:[NSDictionary class]]) continue;
			NSString *name = SPUpdateString([asset objectForKey:@"name"]);
			NSString *url = SPUpdateString([asset objectForKey:@"browser_download_url"]);
			if (url && [[name lowercaseString] hasSuffix:@".zip"]) {
				release.downloadURL = [NSURL URLWithString:url];
				break;
			}
		}
	}
	return release;
}

- (void)dealloc
{
	[version release];
	[title release];
	[notes release];
	[pageURL release];
	[downloadURL release];
	[super dealloc];
}

@end

#pragma mark - SPUpdateChecker

@implementation SPUpdateChecker
{
	NSUserDefaults *defaults;
	BOOL checking;
	BOOL answerThisCheck;       // the user asked: say what came of it, whatever it is
	NSTimer *recheckTimer;
	NSAlert *lastAlert;
}

@synthesize defaults;
@synthesize checking;
@synthesize currentVersion;
@synthesize latestReleaseURL;
@synthesize fetcher;
@synthesize alertPresenter;
@synthesize urlOpener;
@synthesize lastAlert;

+ (instancetype)sharedChecker
{
	static SPUpdateChecker *shared = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		shared = [[SPUpdateChecker alloc] initWithDefaults:[NSUserDefaults standardUserDefaults]];
	});
	return shared;
}

- (instancetype)initWithDefaults:(NSUserDefaults *)theDefaults
{
	if ((self = [super init])) {
		defaults = [theDefaults retain];
		currentVersion = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] copy];
		latestReleaseURL = [[NSURL URLWithString:SPUpdateLatestReleaseURL] copy];
	}
	return self;
}

- (void)dealloc
{
	[recheckTimer invalidate];
	[recheckTimer release];
	[defaults release];
	[currentVersion release];
	[latestReleaseURL release];
	[fetcher release];
	[alertPresenter release];
	[urlOpener release];
	[lastAlert release];
	[super dealloc];
}

#pragma mark Versions

/// The numbers of a version and whether it has a pre-release suffix (@"2.0.0-RC4" → 2, 0, 0, YES).
static NSArray<NSNumber *> *SPUpdateVersionNumbers(NSString *version, BOOL *prerelease)
{
	NSString *trimmed = [version stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([trimmed hasPrefix:@"v"] || [trimmed hasPrefix:@"V"]) trimmed = [trimmed substringFromIndex:1];
	NSRange suffix = [trimmed rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"- "]];
	if (prerelease) *prerelease = (suffix.location != NSNotFound);
	if (suffix.location != NSNotFound) trimmed = [trimmed substringToIndex:suffix.location];

	NSMutableArray *numbers = [NSMutableArray array];
	for (NSString *part in [trimmed componentsSeparatedByString:@"."]) [numbers addObject:@([part integerValue])];
	return numbers;
}

+ (NSComparisonResult)compareVersion:(NSString *)version toVersion:(NSString *)otherVersion
{
	BOOL prerelease = NO, otherPrerelease = NO;
	NSArray *numbers = SPUpdateVersionNumbers(version ?: @"", &prerelease);
	NSArray *otherNumbers = SPUpdateVersionNumbers(otherVersion ?: @"", &otherPrerelease);

	NSUInteger count = MAX([numbers count], [otherNumbers count]);
	for (NSUInteger i = 0; i < count; i++) {
		NSInteger a = i < [numbers count] ? [[numbers objectAtIndex:i] integerValue] : 0;
		NSInteger b = i < [otherNumbers count] ? [[otherNumbers objectAtIndex:i] integerValue] : 0;
		if (a < b) return NSOrderedAscending;
		if (a > b) return NSOrderedDescending;
	}
	if (prerelease != otherPrerelease) return prerelease ? NSOrderedAscending : NSOrderedDescending;
	return NSOrderedSame;
}

#pragma mark Checking

- (IBAction)checkForUpdates:(id)sender
{
	answerThisCheck = YES;
	if (checking) return; // the running check answers
	[self _check];
}

- (NSTimeInterval)_interval
{
	NSTimeInterval interval = [defaults doubleForKey:SPUpdateCheckInterval];
	if (interval <= 0) interval = SPUpdateDefaultInterval;
	return MAX(interval, SPUpdateMinimumInterval);
}

- (BOOL)checkInBackgroundIfDue
{
	if (checking || ![defaults boolForKey:SPUpdateAutomaticChecks]) return NO;
	NSDate *last = [defaults objectForKey:SPUpdateLastCheckTime];
	if ([last isKindOfClass:[NSDate class]] && -[last timeIntervalSinceNow] < [self _interval]) return NO;
	answerThisCheck = NO;
	[self _check];
	return YES;
}

- (void)startAutomaticChecks
{
	if (recheckTimer) return;
	recheckTimer = [[NSTimer scheduledTimerWithTimeInterval:SPUpdateRecheckInterval target:self selector:@selector(_recheck:) userInfo:nil repeats:YES] retain];
	[self performSelector:@selector(checkInBackgroundIfDue) withObject:nil afterDelay:SPUpdateFirstCheckDelay];
}

- (void)_recheck:(NSTimer *)timer
{
	[self checkInBackgroundIfDue];
}

- (void)_check
{
	checking = YES;
	NSURL *url = [[latestReleaseURL copy] autorelease];
	[self retain]; // until the answer is handled
	void (^completion)(NSData *, NSInteger, NSError *) = ^(NSData *data, NSInteger status, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self _handleData:data status:status error:error];
			[self autorelease];
		});
	};

	if (fetcher) {
		fetcher(url, completion);
		return;
	}

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20];
	[request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
	// A generic client name, as GitHub's API asks for one (nothing about the user)
	[request setValue:[NSString stringWithFormat:@"Sequel-Plus/%@", currentVersion ?: @"0"] forHTTPHeaderField:@"User-Agent"];
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
		completion(data, status, error);
	}] resume];
}

- (void)_handleData:(NSData *)data status:(NSInteger)status error:(NSError *)error
{
	checking = NO;
	BOOL answer = answerThisCheck;
	answerThisCheck = NO;

	SPUpdateRelease *release = nil;
	NSString *failure = nil;
	if (error) {
		failure = [error localizedDescription];
	}
	else if (status == 404) {
		failure = NSLocalizedString(@"No Sequel Plus release was found on GitHub.", @"update check: no release");
	}
	else if (status == 403 || status == 429) {
		failure = NSLocalizedString(@"GitHub is limiting how often it can be asked. Try again in an hour.", @"update check: rate limited");
	}
	else if (status != 200) {
		failure = [NSString stringWithFormat:NSLocalizedString(@"GitHub answered with HTTP status %ld.", @"update check: unexpected status"), (long)status];
	}
	else {
		id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
		release = [SPUpdateRelease releaseWithJSON:json];
		if (!release) failure = NSLocalizedString(@"GitHub's answer couldn't be read.", @"update check: unreadable answer");
	}

	if (failure) {
		if (answer) {
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert setAlertStyle:NSAlertStyleWarning];
			[alert setMessageText:NSLocalizedString(@"Couldn't check for updates", @"update check failed title")];
			[alert setInformativeText:failure];
			[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
			[self _present:alert];
		}
		return;
	}

	[defaults setObject:[NSDate date] forKey:SPUpdateLastCheckTime];

	BOOL newer = [[self class] compareVersion:[release version] toVersion:currentVersion] == NSOrderedDescending;
	if (!newer) {
		if (answer) {
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert setMessageText:NSLocalizedString(@"You're up to date!", @"update check: up to date title")];
			[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Sequel Plus %@ is the newest version available.", @"update check: up to date message"), currentVersion]];
			[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
			[self _present:alert];
		}
		return;
	}

	// An automatic check says nothing about a version the user skipped
	if (!answer && [[release version] isEqualToString:[defaults stringForKey:SPUpdateSkippedVersion]]) return;

	[self _offerRelease:release];
}

- (void)_offerRelease:(SPUpdateRelease *)release
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:NSLocalizedString(@"A new version of Sequel Plus is available", @"update available title")];
	[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Sequel Plus %@ is available — you have %@. Download it, then replace the app in your Applications folder with the new one.", @"update available message"), [release version], currentVersion]];
	[alert addButtonWithTitle:NSLocalizedString(@"Download", @"update: download button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Remind Me Later", @"update: later button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Skip This Version", @"update: skip button")];

	if ([[release notes] length]) {
		NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 420, 180)] autorelease];
		[scrollView setHasVerticalScroller:YES];
		[scrollView setBorderType:NSBezelBorder];
		NSTextView *textView = [[[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
		[textView setEditable:NO];
		[textView setRichText:NO];
		[textView setAutoresizingMask:NSViewWidthSizable];
		[textView setTextContainerInset:NSMakeSize(4, 4)];
		[textView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		[textView setString:[release notes]];
		[scrollView setDocumentView:textView];
		[alert setAccessoryView:scrollView];
	}

	NSModalResponse response = [self _present:alert];
	if (response == NSAlertFirstButtonReturn) {
		NSURL *url = [release downloadURL] ?: [release pageURL];
		if (url) [self _open:url];
	}
	else if (response == NSAlertThirdButtonReturn) {
		[defaults setObject:[release version] forKey:SPUpdateSkippedVersion];
	}
}

- (NSModalResponse)_present:(NSAlert *)alert
{
	[lastAlert release];
	lastAlert = [alert retain];
	if (alertPresenter) return alertPresenter(alert);
	[NSApp activateIgnoringOtherApps:YES];
	return [alert runModal];
}

- (void)_open:(NSURL *)url
{
	if (urlOpener) urlOpener(url);
	else [[NSWorkspace sharedWorkspace] openURL:url];
}

@end

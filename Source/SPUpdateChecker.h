//
//  SPUpdateChecker.h
//  Sequel Plus
//
//  Checks GitHub for a newer Sequel Plus release and offers to download it.
//

#import <Cocoa/Cocoa.h>

/// The latest (non-draft, non-prerelease) release of the Sequel Plus repository, from GitHub's API.
extern NSString * const SPUpdateLatestReleaseURL __attribute__((visibility("default")));

/// One GitHub release, as the checker reads it.
__attribute__((visibility("default")))
@interface SPUpdateRelease : NSObject
/// The tag without a leading "v" (e.g. @"2.0.4").
@property (readonly, copy) NSString *version;
@property (readonly, copy) NSString *title;
/// The release notes (GitHub's Markdown, shown as plain text), @"" when none.
@property (readonly, copy) NSString *notes;
/// The release's page.
@property (readonly, copy) NSURL *pageURL;
/// The release's .zip asset, nil when it has none (Download then opens pageURL).
@property (readonly, copy) NSURL *downloadURL;

/// A release from the API's JSON object; nil when it has no tag.
+ (instancetype)releaseWithJSON:(NSDictionary *)json;
@end

/**
 * "Check for Updates…" for Sequel Plus: asks GitHub for the repository's latest release and, when its version is
 * newer than this app's, shows its version and notes with Download (opens the release's zip in the browser; the app
 * is replaced by hand), Remind Me Later and Skip This Version. Nothing is installed by the app itself.
 *
 * - A check the user asks for (-checkForUpdates:) always answers: the new version, "You're up to date", or why the
 *   check failed. It shows a skipped version too.
 * - Automatic checks (-startAutomaticChecks) run when SPUpdateAutomaticChecks is on and SPUpdateCheckInterval seconds
 *   have passed since SPUpdateLastCheckTime (a few seconds after launch, then hourly, re-evaluated each time); they
 *   say nothing unless there is a new version that isn't SPUpdateSkippedVersion.
 *
 * Main thread only; one check at a time (asking while one runs makes it answer, as one the user asked for).
 */
__attribute__((visibility("default")))
@interface SPUpdateChecker : NSObject

+ (instancetype)sharedChecker;
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;

/// The check the user asks for (the app menu's Check for Updates…, Preferences ▸ Auto Update ▸ Check Now).
- (IBAction)checkForUpdates:(id)sender;
/// An automatic check if one is due (see the class comment); YES if one was started.
- (BOOL)checkInBackgroundIfDue;
/// Starts the automatic checks (once).
- (void)startAutomaticChecks;

/// Compares dotted versions numerically (@"2.0.10" > @"2.0.9"); a suffix after "-" or a space (e.g. @"2.0.0-RC4") is a
/// pre-release, older than the same version without one.
+ (NSComparisonResult)compareVersion:(NSString *)version toVersion:(NSString *)otherVersion;

@property (readonly, getter=isChecking) BOOL checking;
@property (readonly) NSUserDefaults *defaults;

#pragma mark - Seams (tests)

/// This app's version. Default: CFBundleShortVersionString.
@property (copy) NSString *currentVersion;
/// Where the latest release is read. Default: SPUpdateLatestReleaseURL.
@property (copy) NSURL *latestReleaseURL;
/// Fetches url; completion on any thread with the body, the HTTP status (0 without a response) and the error.
/// Default: NSURLSession.
@property (copy) void (^fetcher)(NSURL *url, void (^completion)(NSData *data, NSInteger status, NSError *error));
/// Shows an alert and gives back the button clicked. Default: -[NSAlert runModal].
@property (copy) NSModalResponse (^alertPresenter)(NSAlert *alert);
/// Opens Download's URL. Default: NSWorkspace.
@property (copy) void (^urlOpener)(NSURL *url);
/// The last alert shown (tests).
@property (readonly) NSAlert *lastAlert;

@end

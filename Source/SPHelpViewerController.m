//
//  SPHelpViewerController.m
//  sequel-pro
//
//  Created by Max Lohrmann on 21.05.18.
//  Copyright (c) 2018 Max Lohrmann. All rights reserved.
//  Parts relocated from existing files. Previous copyright applies.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPHelpViewerController.h"

#import "SPOSInfo.h"
#import <WebKit/WebKit.h>

NSString * const SPHelpViewerSearchTOC = @"contents";

NSString * const SPUserClosedHelpViewerNotification = @"SPUserClosedHelpViewer";

typedef NS_ENUM(NSInteger, HelpNavButton) {
	HelpNavButtonGoBack = 0,
	HelpNavButtonShowTOC = 1,
	HelpNavButtonGoForward = 2,
};

static void *HelpViewerControllerKVOContext = &HelpViewerControllerKVOContext;

@interface SPHelpViewerController () <WebPolicyDelegate, WebUIDelegate, NSWindowDelegate>
- (IBAction)showHelpForSearchString:(id)sender;
- (IBAction)helpSegmentDispatcher:(id)sender;
- (IBAction)helpSearchFindNextInPage:(id)sender;
- (IBAction)helpSearchFindPreviousInPage:(id)sender;
- (IBAction)helpTargetDispatcher:(id)sender;
- (IBAction)helpSelectHelpTargetMySQL:(id)sender;
- (IBAction)helpSelectHelpTargetPage:(id)sender;
- (IBAction)helpSelectHelpTargetWeb:(id)sender;

- (IBAction)showHelpForWebViewSelection:(id)sender;
- (IBAction)searchInDocForWebViewSelection:(id)sender;
- (void)helpTargetValidation;
- (void)themeChanged;
- (void)updateWindowTitle;
@end

#pragma mark -

@implementation SPHelpViewerController

@synthesize dataSource = dataSource;

+ (void)initialize
{
	
}

- (instancetype)init
{
	if ((self = [super initWithWindowNibName:@"HelpViewer"])) {
		//force window to be loaded for simplicity
		[self window];
	}
	return self;
}

- (void)dealloc
{
	[helpWebView removeObserver:self forKeyPath:@"mainFrameTitle"]; //TODO: update to ...context: variant after 10.6
	if (@available(macOS 10.14, *)) {
		[[self window] removeObserver:self forKeyPath:@"effectiveAppearance" context:HelpViewerControllerKVOContext];
	}
	[super dealloc];
}

- (void)windowDidLoad
{
	// init search history
	[helpWebView setMaintainsBackForwardList:YES];
	[[helpWebView backForwardList] setCapacity:20];

	[self updateWindowTitle];

	[helpWebView addObserver:self forKeyPath:@"mainFrameTitle" options:0 context:HelpViewerControllerKVOContext];
	if (@available(macOS 10.14, *)) {
		[[self window] addObserver:self forKeyPath:@"effectiveAppearance" options:0 context:HelpViewerControllerKVOContext];
	}
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context
{
	if(context == HelpViewerControllerKVOContext) {
		if([@"mainFrameTitle" isEqualToString:keyPath] && object == helpWebView) {
			[self updateWindowTitle];
		}
		else if([@"effectiveAppearance" isEqualToString:keyPath]) {
			// Apple says to not do stuff here that could take some time or it may interrupt animations
			[self performSelector:@selector(themeChanged) withObject:nil afterDelay:0.0];
		}
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)themeChanged
{
	if (@available(macOS 10.14, *)) {

		NSString *match = [[[self window] effectiveAppearance] bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
		NSString *newTheme = @"unknown";
		if([NSAppearanceNameAqua isEqualToString:match]) {
			newTheme = @"light";
		}
		else if([NSAppearanceNameDarkAqua isEqualToString:match]) {
			newTheme = @"dark";
		}

		NSString *eval = [NSString stringWithFormat:@"window.onThemeChange('%@')", newTheme];
		[helpWebView stringByEvaluatingJavaScriptFromString:eval];
	}
}

- (void)updateWindowTitle
{
	NSString *title = NSLocalizedString(@"MySQL Help", @"mysql help");

	NSString *webTitle = [helpWebView mainFrameTitle];
	if([webTitle length]) title = [title stringByAppendingFormat:@" (%@)", webTitle];

	[[self window] setTitle:title];
}

#pragma mark -
#pragma mark MySQL Help

/**
 * Show the data for "HELP 'searchString'".
 */
- (void)showHelpFor:(NSString *)searchString addToHistory:(BOOL)addToHistory calledByAutoHelp:(BOOL)autoHelp
{
	// If there's no search string, ignore if called by autohelp, show the index otherwise
	if (![searchString length]) {
		if (autoHelp) return;
		searchString = SPHelpViewerSearchTOC;
	}

	NSString *helpString = [dataSource HTMLHelpContentsForSearchString:searchString autoHelp:autoHelp];

	// init the Help window if not visible
	if(![[self window] isVisible]) {
		// init goback/forward buttons
		if([[helpWebView backForwardList] backListCount] < 1) {
			[helpNavigator setEnabled:NO forSegment:HelpNavButtonGoBack];
			[helpNavigator setEnabled:NO forSegment:HelpNavButtonGoForward];
		}
		else {
			[helpNavigator setEnabled:([[helpWebView backForwardList] backListCount] != 0) forSegment:HelpNavButtonGoBack];
			[helpNavigator setEnabled:([[helpWebView backForwardList] forwardListCount] != 0) forSegment:HelpNavButtonGoForward];
		}

		// set default to search in MySQL help
		helpTarget = HelpTargetMySQL;
		[helpTargetSelector setSelectedSegment:HelpTargetMySQL];
		[self helpTargetValidation];

		// show Help window
		[[self window] orderFront:helpWebView];
	}

	if(![helpString length]) return;

	// add searchString to history list
	if(addToHistory) {
		WebHistoryItem *aWebHistoryItem = [[WebHistoryItem alloc] initWithURLString:[NSString stringWithFormat:@"applewebdata://%@", searchString] title:searchString lastVisitedTimeInterval:[[NSDate date] timeIntervalSinceDate:[NSDate distantFuture]]];
		[[helpWebView backForwardList] addItem:aWebHistoryItem];
		[aWebHistoryItem release];
	}

	// validate goback/forward buttons
	[helpNavigator setEnabled:([[helpWebView backForwardList] backListCount] != 0) forSegment:HelpNavButtonGoBack];
	[helpNavigator setEnabled:([[helpWebView backForwardList] forwardListCount] != 0) forSegment:HelpNavButtonGoForward];

	// load HTML formatted help into the webview
	[[helpWebView mainFrame] loadHTMLString:helpString baseURL:nil];
}

/**
 * Show the data for "HELP 'search word'" according to helpTarget
 */
- (IBAction)showHelpForSearchString:(id)sender
{
	NSString *searchString = [[helpSearchField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	switch(helpTarget) {
		case HelpTargetPage:
			if(![helpWebView searchFor:searchString direction:YES caseSensitive:NO wrap:YES]) {
				if([searchString length]) NSBeep();
			}
			break;
		case HelpTargetWeb:
			if(![searchString length]) break;
			[dataSource openOnlineHelpForTopic:searchString];
			break;
		case HelpTargetMySQL:
			[self showHelpFor:searchString addToHistory:YES calledByAutoHelp:NO];
			break;
	}
}

/**
 * Show the Help for the selected text in the webview
 */
- (IBAction)showHelpForWebViewSelection:(id)sender
{
	[self showHelpFor:[[helpWebView selectedDOMRange] text] addToHistory:YES calledByAutoHelp:NO];
}

/**
 * Show MySQL's online documentation for the selected text in the webview
 */
- (IBAction)searchInDocForWebViewSelection:(id)sender
{
	NSString *searchString = [[[helpWebView selectedDOMRange] text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if(![searchString length]) {
		NSBeep();
		return;
	}
	[dataSource openOnlineHelpForTopic:searchString];
}

/**
 * Find Next/Previous in current page
 */
- (IBAction)helpSearchFindNextInPage:(id)sender
{
	if(helpTarget == HelpTargetPage) {
		if(![helpWebView searchFor:[[helpSearchField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] direction:YES caseSensitive:NO wrap:YES]) NSBeep();
	}
}

- (IBAction)helpSearchFindPreviousInPage:(id)sender
{
	if(helpTarget == HelpTargetPage) {
		if(![helpWebView searchFor:[[helpSearchField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] direction:NO caseSensitive:NO wrap:YES]) NSBeep();
	}
}

/**
 * Navigation for back/TOC/forward
 */
- (IBAction)helpSegmentDispatcher:(id)sender
{
	switch((HelpNavButton)[helpNavigator selectedSegment]) {
		case HelpNavButtonGoBack:
			[helpWebView goBack];
			break;
		case HelpNavButtonShowTOC:
			[self showHelpFor:SPHelpViewerSearchTOC addToHistory:YES calledByAutoHelp:NO];
			break;
		case HelpNavButtonGoForward:
			[helpWebView goForward];
			break;
	}

	// validate goback and goforward buttons according history
	[helpNavigator setEnabled:([[helpWebView backForwardList] backListCount] != 0) forSegment:HelpNavButtonGoBack];
	[helpNavigator setEnabled:([[helpWebView backForwardList] forwardListCount] != 0) forSegment:HelpNavButtonGoForward];
}

/**
 * Set helpTarget according user choice via mouse and keyboard short-cuts.
 */
- (IBAction)helpSelectHelpTargetMySQL:(id)sender
{
	helpTarget = HelpTargetMySQL;
	[helpTargetSelector setSelectedSegment:HelpTargetMySQL];
	[self helpTargetValidation];
}

- (IBAction)helpSelectHelpTargetPage:(id)sender
{
	helpTarget = HelpTargetPage;
	[helpTargetSelector setSelectedSegment:HelpTargetPage];
	[self helpTargetValidation];
}

- (IBAction)helpSelectHelpTargetWeb:(id)sender
{
	helpTarget = HelpTargetWeb;
	[helpTargetSelector setSelectedSegment:HelpTargetWeb];
	[self helpTargetValidation];
}

- (IBAction)helpTargetDispatcher:(id)sender
{
	helpTarget = (HelpTarget)[helpTargetSelector selectedSegment];
	[self helpTargetValidation];
}

/**
 * Control the help search field behaviour.
 */
- (void)helpTargetValidation
{
	switch(helpTarget) {
		case HelpTargetPage:
		case HelpTargetWeb:
			[helpSearchFieldCell setSendsWholeSearchString:YES];
			break;
		case HelpTargetMySQL:
			[helpSearchFieldCell setSendsWholeSearchString:NO];
			break;
	}
}

- (BOOL)windowShouldClose:(NSWindow *)sender
{
	// -windowShouldClose: is the only method that will ONLY be invoked when the user closes the window (or by -performClose:)
	[[NSNotificationCenter defaultCenter] postNotificationName:SPUserClosedHelpViewerNotification object:self];
	return YES;
}

#pragma mark -
#pragma mark WebView delegate methods

/**
 * Link detector: If user clicked at an http link open it in the default browser,
 * otherwise search for it in the MySQL help. Additionally handle back/forward events from
 * keyboard and context menu.
 */
- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	NSInteger navigationType = [[actionInformation objectForKey:WebActionNavigationTypeKey] integerValue];

	if([[[request URL] scheme] isEqualToString:@"applewebdata"] && navigationType == WebNavigationTypeLinkClicked) {
		[self showHelpFor:[[[request URL] path] lastPathComponent] addToHistory:YES calledByAutoHelp:NO];
		[listener ignore];
	}
	else {
		if (navigationType == WebNavigationTypeOther) {
			// catch reload event
			// if([[[actionInformation objectForKey:WebActionOriginalURLKey] absoluteString] isEqualToString:@"about:blank"])
			// 	[listener use];
			// else
			[listener use];
		}
		else if (navigationType == WebNavigationTypeLinkClicked) {
			// show http in browser
			[[NSWorkspace sharedWorkspace] openURL:[actionInformation objectForKey:WebActionOriginalURLKey]];
			[listener ignore];
		}
		else if (navigationType == WebNavigationTypeBackForward) {
			// catch back/forward events from contextual menu
			[self showHelpFor:[[[[actionInformation objectForKey:WebActionOriginalURLKey] absoluteString] lastPathComponent] stringByReplacingPercentEscapesUsingEncoding:NSASCIIStringEncoding] addToHistory:NO calledByAutoHelp:NO];
			[listener ignore];
		}
		else {
			// Ignore WebNavigationTypeFormSubmitted, WebNavigationTypeFormResubmitted, WebNavigationTypeReload.
			[listener ignore];
		}
	}
}

/**
 * Manage contextual menu in helpWebView
 * Ignore "Reload", "Open Link", "Open Link in new Window", "Download link" etc.
 */
- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSMutableArray *webViewMenuItems = [[defaultMenuItems mutableCopy] autorelease];

	if (webViewMenuItems) {
		// Remove all needless default menu items
		NSEnumerator *itemEnumerator = [defaultMenuItems objectEnumerator];
		NSMenuItem *menuItem = nil;

		while ((menuItem = [itemEnumerator nextObject])) {
			NSInteger tag = [menuItem tag];

			switch (tag) {
				case 2000: // WebMenuItemTagOpenLink
				case WebMenuItemTagOpenLinkInNewWindow:
				case WebMenuItemTagDownloadLinkToDisk:
				case WebMenuItemTagOpenImageInNewWindow:
				case WebMenuItemTagDownloadImageToDisk:
				case WebMenuItemTagCopyImageToClipboard:
				case WebMenuItemTagOpenFrameInNewWindow:
				case WebMenuItemTagStop:
				case WebMenuItemTagReload:
				case WebMenuItemTagCut:
				case WebMenuItemTagPaste:
				case WebMenuItemTagSpellingGuess:
				case WebMenuItemTagNoGuessesFound:
				case WebMenuItemTagIgnoreSpelling:
				case WebMenuItemTagLearnSpelling:
				case WebMenuItemTagOther:
				case WebMenuItemTagOpenWithDefaultApplication:
					[webViewMenuItems removeObjectIdenticalTo: menuItem];
					break;
			}
		}
	}

	// Add two menu items for a selection if no link is given
	if(webViewMenuItems
	    && [[element objectForKey:@"WebElementIsSelected"] boolValue]
	    && ![[element objectForKey:@"WebElementLinkIsLive"] boolValue])
	{

		NSMenuItem *searchInMySQL;
		NSMenuItem *searchInMySQLonline;

		[webViewMenuItems insertObject:[NSMenuItem separatorItem] atIndex:0];

		searchInMySQLonline = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Search in MySQL Documentation", @"Search in MySQL Documentation") action:@selector(searchInDocForWebViewSelection:) keyEquivalent:@""];
		[searchInMySQLonline setEnabled:YES];
		[searchInMySQLonline setTarget:self];
		[webViewMenuItems insertObject:searchInMySQLonline atIndex:0];
		[searchInMySQLonline release];

		searchInMySQL = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Search in MySQL Help", @"Search in MySQL Help") action:@selector(showHelpForWebViewSelection:) keyEquivalent:@""];
		[searchInMySQL setEnabled:YES];
		[searchInMySQL setTarget:self];
		[webViewMenuItems insertObject:searchInMySQL atIndex:0];
		[searchInMySQL release];
	}

	return webViewMenuItems;
}

@end

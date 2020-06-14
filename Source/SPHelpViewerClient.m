//
//  SPHelpViewerClient.m
//  sequel-pro
//
//  Created by Max Lohrmann on 25.05.18.
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

#import "SPHelpViewerClient.h"
#import "SPHelpViewerController.h"
#import <SPMySQL/SPMySQL.h>
#import "RegexKitLite.h"
#import "MGTemplateEngine.h"
#import "ICUTemplateMatcher.h"
#import "SPOSInfo.h"

@interface SPHelpViewerClient () <SPHelpViewerDataSource>

+ (NSString *)linkToHelpTopic:(NSString *)aTopic;

- (void)helpViewerClosed:(NSNotification *)notification;

@end

@implementation SPHelpViewerClient

+ (void)initialize
{
	
}

- (instancetype)init
{
	if (self = [super init]) {
		controller = [[SPHelpViewerController alloc] init];
		[controller setDataSource:self];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(helpViewerClosed:) name:SPUserClosedHelpViewerNotification object:controller];

		// init helpHTMLTemplate
		NSError *error;

		helpHTMLTemplate = [[NSString alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:SPHTMLHelpTemplate ofType:@"html"]
		                                                   encoding:NSUTF8StringEncoding
		                                                      error:&error];

		// Set up template engine with your chosen matcher
		engine = [[MGTemplateEngine alloc] init];
		[engine setMatcher:[ICUTemplateMatcher matcherWithTemplateEngine:engine]];

		// an error occurred while reading
		if (helpHTMLTemplate == nil) {
			helpHTMLTemplate = [@"<html><body>{{body}}</body></html>" copy]; //fallback
			NSLog(@"%@", [NSString stringWithFormat:@"Error reading “%@.html”!<br>%@", SPHTMLHelpTemplate, [error localizedFailureReason]]);
			NSBeep();
		}
	}
	
	return self;
}

#pragma mark -

- (void)helpViewerClosed:(NSNotification *)notification
{
	//we'll just proxy that notification because outsiders can't/shouldn't access the controller
	[[NSNotificationCenter defaultCenter] postNotificationName:SPUserClosedHelpViewerNotification object:self];
}

- (void)openOnlineHelpForTopic:(NSString *)searchString
{
	NSString *version = nil;

	if (![mySQLConnection serverVersionIsGreaterThanOrEqualTo:4 minorVersion:1 releaseVersion:0])
	{
		version = @"4.1";
	}
	else {
		version = [NSString stringWithFormat:@"%u.%u",(unsigned int)[mySQLConnection serverMajorVersion], (unsigned int)[mySQLConnection serverMinorVersion]];
	}

	NSString *url = [[NSString stringWithFormat:
		SPMySQLSearchURL,
		version,
		NSLocalizedString(@"en", @"MySQL search language code - eg in http://search.mysql.com/search?q=select&site=refman-50&lr=lang_en"),
		searchString]
		stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];

	if ([url length]) {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
	}
}

- (NSString *)HTMLHelpContentsForSearchString:(NSString *)searchString autoHelp:(BOOL)autoHelp
{
	if(![searchString length]) return @"";

	NSMutableString *theTitle = [NSMutableString stringWithFormat:NSLocalizedString(@"Version %@", @"Mysql Help Viewer : window title : mysql server version"),[mySQLConnection serverVersionString]];
	NSMutableString *theHelp = [NSMutableString string];

	// Don't escape % when being used as a wildcard, but escape it when it's being used by itself.
	if ([searchString isEqualToString:@"%"]) searchString = @"\\%";

	// search via: HELP 'searchString'
	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"HELP %@", [searchString tickQuotedString]]];
	if ([mySQLConnection queryErrored]) {
		[theTitle setString:NSLocalizedString(@"Error", @"Mysql Help Viewer : window title : query error")];
		NSString *errMsg = [NSString stringWithFormat:@"ERROR %lu (%@): %@", (unsigned long)[mySQLConnection lastErrorID], [mySQLConnection lastSqlstate], [mySQLConnection lastErrorMessage]];
		[theHelp appendFormat:@"<b>%@:</b><br><p class='error'>%@</p>", NSLocalizedString(@"MySQL Help Query Failed", @"Mysql Help Viewer : title of error message"), errMsg];
		goto generate_help;
	}

	// nothing found?
	if(![theResult numberOfRows]) {
		// try to search via: HELP 'searchString%'
		theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"HELP %@", [[searchString stringByAppendingString:@"%"] tickQuotedString]]];

		// really nothing found?
		if(![theResult numberOfRows]) {
			[theTitle appendFormat:@": %@", NSLocalizedString(@"No Results", @"Mysql Help Viewer : window title : nothing found")];
			[theHelp appendFormat:@"<em class='nothing'>%@</em>", NSLocalizedString(@"No results found.", @"Mysql Help Viewer : Search : No results")];
			goto generate_help;
		}
	}

	// Ensure rows are returned as strings to prevent data problems with older 4.1 servers
	[theResult setReturnDataAsStrings:YES];

	NSDictionary *tableDetails = [[NSDictionary alloc] initWithDictionary:[theResult getRowAsDictionary]];

	if ([tableDetails objectForKey:@"description"]) { // one single help topic found
		if ([tableDetails objectForKey:@"name"]) {
			[theTitle appendFormat:@": %@", [tableDetails objectForKey:@"name"]];
			[theHelp appendString:@"<h2 class='header'>"];
			[theHelp appendString:[tableDetails objectForKey:@"name"]];
			[theHelp appendString:@"</h2>"];
		}
		if ([tableDetails objectForKey:@"description"]) {
			NSMutableString *desc = [NSMutableString string];
			NSError *err1 = NULL;
			NSString *aUrl;

			[desc setString:[tableDetails objectForKey:@"description"]];

			//[desc replaceOccurrencesOfString:[searchString uppercaseString] withString:[NSString stringWithFormat:@"<span class='searchstring'>%@</span>", [searchString uppercaseString]] options:NSLiteralSearch range:NSMakeRange(0,[desc length])];

			// detect and generate http links
			NSRange aRange = NSMakeRange(0,0);
			NSInteger safeCnt = 0; // safety counter - not more than 200 loops allowed
			while(1) {
				aRange = [desc rangeOfRegex:@"\\s((https?|ftp|file)://.*?html)" options:RKLNoOptions inRange:NSMakeRange(NSMaxRange(aRange), [desc length]-aRange.location-aRange.length) capture:1 error:&err1];
				if(aRange.location != NSNotFound) {
					aUrl = [desc substringWithRange:aRange];
					[desc replaceCharactersInRange:aRange withString:[NSString stringWithFormat:@"<a href='%@'>%@</a>", aUrl, aUrl]];
				}
				else {
					break;
				}
				safeCnt++;
				if(safeCnt > 200) break;
			}

			// Detect and generate cross-links.  First, handle the old-style [HELP ...] text.
			[desc replaceOccurrencesOfRegex:@"(\\[HELP ([^\\]]*?)\\]" withString:[[self class] linkToHelpTopic:@"$1"]];

			// Handle "see [...]" and "in [...]"-style 5.x links.
			//look-behind won't work here because of the \s+
			[desc replaceOccurrencesOfRegex:@"(See|see|In|in|and)\\s+\\[(?:HELP\\s+)?([^\\]]*?)\\]" withString:[NSString stringWithFormat:@"$1 %@",[[self class] linkToHelpTopic:@"$2"]]];

			[theHelp appendFormat:@"<pre class='description'>%@</pre>", desc];
		}
		// are examples available?
		if([tableDetails objectForKey:@"example"]){
			NSString *examples = [[[tableDetails objectForKey:@"example"] copy] autorelease];
			if([examples length]) [theHelp appendFormat:@"<br><i><b>%1$@</b></i><br><pre class='example'>%2$@</pre>",NSLocalizedString(@"Example:",@"Mysql Help Viewer : Help Topic: Example section title"), examples];
		}
	}
	else { // list all found topics
		// check if HELP 'contents' is called
		if(![searchString isEqualToString:SPHelpViewerSearchTOC]) {
			[theTitle appendString:@": "];
			[theTitle appendFormat:NSLocalizedString(@"Multiple Results for “%@”", @"Mysql Help Viewer : window title : multiple topics found"), searchString];
			[theHelp appendFormat:@"<br><i>%@</i><br>", [NSString stringWithFormat:NSLocalizedString(@"Help topics for “%@”", @"MySQL Help Viewer : Results list : Page title"), searchString]];
		}
		else {
			[theTitle appendFormat:@": %@", NSLocalizedString(@"Table of Contents", @"Mysql Help Viewer : window title : TOC")];
			[theHelp appendFormat:@"<br><b>%@:</b><br>", NSLocalizedString(@"MySQL Help – Categories", @"mysql help categories")];
		}

		// iterate through all found rows and print them as HTML ul/li list
		[theHelp appendString:@"<ul>"];
		[theResult setDefaultRowReturnType:SPMySQLResultRowAsArray];

		for (NSArray *eachRow in theResult)
		{
			NSString *topic = [eachRow objectAtIndex:[eachRow count] - 2];

			[theHelp appendFormat:@"<li>%@</li>", [[self class] linkToHelpTopic:topic]];
		}

		[theHelp appendString:@"</ul>"];
	}

	[tableDetails release];

generate_help:
	{ // C syntax disallows a new variable directly following a label…
		NSString *addBodyClass = @"";
		// Add CSS class if running in dark UI mode (10.14+)
		if (@available(macOS 10.14, *)) {
			NSString *match = [[[controller window] effectiveAppearance] bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
			// aqua is already the default theme
			if ([NSAppearanceNameDarkAqua isEqualToString:match]) {
				addBodyClass = @"dark";
			}
		}

		return [engine processTemplate:helpHTMLTemplate withVariables:@{
			@"bodyClass": addBodyClass,
			@"title": theTitle,
			@"body": theHelp,
		}];
	}
}

+ (NSString *)linkToHelpTopic:(NSString *)aTopic
{
	NSString *linkTitle = [NSString stringWithFormat:NSLocalizedString(@"Show MySQL help for “%@”", @"MySQL Help Viewer : Results list : Link tooltip"),aTopic];
	return [NSString stringWithFormat:@"<a title='%2$@' href='%1$@' class='internallink'>%1$@</a>", aTopic, linkTitle];
}

- (void)setConnection:(SPMySQLConnection *)theConnection
{
	mySQLConnection = theConnection;
}

/**
 * Return the Help window.
 */
- (NSWindow *)helpWebViewWindow
{
	return [controller window];
}

- (void)showHelpFor:(NSString *)aString addToHistory:(BOOL)addToHistory calledByAutoHelp:(BOOL)autoHelp
{
	[controller showHelpFor:aString addToHistory:addToHistory calledByAutoHelp:autoHelp];
}

/**
 * Show the data for "HELP 'currentWord'"
 */
- (IBAction)showHelpForCurrentWord:(id)sender
{
	NSString *searchString = [[sender string] substringWithRange:[sender getRangeForCurrentWord]];
	[controller showHelpFor:searchString addToHistory:YES calledByAutoHelp:NO];
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[controller setDataSource:nil]; // we are the (unretained) datasource, but the controller may outlive us (if retained by other objects)
	[controller close]; // hide the window if it is still visible (can't update anymore without delegate anyway)

	mySQLConnection = nil;

	SPClear(controller);
	SPClear(helpHTMLTemplate);
	SPClear(engine);

	[super dealloc];
}

@end

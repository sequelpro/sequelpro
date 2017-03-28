//
//  SPQueryControllerInitializer.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on September 1, 2011.
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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

#import "SPQueryControllerInitializer.h"

static NSString *SPCompletionTokensFilename = @"CompletionTokens.plist";

static NSString *SPCompletionTokensKeywordsKey = @"core_keywords";
static NSString *SPCompletionTokensFunctionsKey = @"core_builtin_functions";
static NSString *SPCompletionTokensSnippetsKey = @"function_argument_snippets";

@interface SPQueryController ()

- (void)_updateFilterState;

@end

@implementation SPQueryController (SPQueryControllerInitializer)

/**
 * Set the window's auto save name and initialise display.
 */
- (void)awakeFromNib
{
#ifndef SP_CODA /* init ivars */
	prefs = [NSUserDefaults standardUserDefaults];
	
	[self setWindowFrameAutosaveName:SPQueryConsoleWindowAutoSaveName];
	
	// Show/hide table columns
	[[consoleTableView tableColumnWithIdentifier:SPTableViewDateColumnID] setHidden:![prefs boolForKey:SPConsoleShowTimestamps]];
	[[consoleTableView tableColumnWithIdentifier:SPTableViewConnectionColumnID] setHidden:![prefs boolForKey:SPConsoleShowConnections]];
	[[consoleTableView tableColumnWithIdentifier:SPTableViewDatabaseColumnID] setHidden:![prefs boolForKey:SPConsoleShowDatabases]];
	
	showSelectStatementsAreDisabled = ![prefs boolForKey:SPConsoleShowSelectsAndShows];
	showHelpStatementsAreDisabled = ![prefs boolForKey:SPConsoleShowHelps];
	
	[self _updateFilterState];
	
	[loggingDisabledTextField setStringValue:([prefs boolForKey:SPConsoleEnableLogging]) ? @"" : NSLocalizedString(@"Query logging is currently disabled", @"query logging disabled label")];
	
	// Setup data formatter
	dateFormatter = [[NSDateFormatter alloc] init];
	
	[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	
	[dateFormatter setDateStyle:NSDateFormatterNoStyle];
	[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
	
	// Set the process table view's vertical gridlines if required
	[consoleTableView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	
	// Set the strutcture and index view's font
	BOOL useMonospacedFont = [prefs boolForKey:SPUseMonospacedFonts];
	CGFloat monospacedFontSize = [prefs floatForKey:SPMonospacedFontSize] > 0 ? [prefs floatForKey:SPMonospacedFontSize] : [NSFont smallSystemFontSize];

	for (NSTableColumn *column in [consoleTableView tableColumns])
	{
		[[column dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:monospacedFontSize] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}

	//allow drag-out copying of selected rows
	[consoleTableView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
#endif
}

/**
 * Loads the query controller's completion tokens data.
 */
- (NSError *)loadCompletionLists
{	
	NSError *readError = nil;
	NSString *convError = nil;
	NSString *errorDescription = nil;
	
	NSPropertyListFormat format;
	NSData *completionTokensData = [NSData dataWithContentsOfFile:
									[NSBundle pathForResource:SPCompletionTokensFilename
													   ofType:nil 
												  inDirectory:[[NSBundle mainBundle] bundlePath]] 
														  options:NSMappedRead error:&readError];
	
	NSDictionary *completionPlist = [NSDictionary dictionaryWithDictionary:
									 [NSPropertyListSerialization propertyListFromData:completionTokensData
																	  mutabilityOption:NSPropertyListMutableContainersAndLeaves 
																				format:&format 
																	  errorDescription:&convError]];
	
	if (completionPlist == nil || readError != nil || convError != nil) {
		errorDescription = [NSString stringWithFormat:@"Error reading '%@': %@, %@", SPCompletionTokensFilename, [readError localizedDescription], convError];
	} 
	else {
		if ([completionPlist objectForKey:SPCompletionTokensKeywordsKey]) {
			completionKeywordList = [[NSArray arrayWithArray:[completionPlist objectForKey:SPCompletionTokensKeywordsKey]] retain];
		} 
		else {
			errorDescription = [NSString stringWithFormat:@"No '%@' array found.", SPCompletionTokensKeywordsKey];
		}
		
		if ([completionPlist objectForKey:SPCompletionTokensFunctionsKey]) {
			completionFunctionList = [[NSArray arrayWithArray:[completionPlist objectForKey:SPCompletionTokensFunctionsKey]] retain];
		} 
		else {
			errorDescription = [NSString stringWithFormat:@"No '%@' array found.", SPCompletionTokensFunctionsKey];
		}
		
		if ([completionPlist objectForKey:SPCompletionTokensSnippetsKey]) {
			functionArgumentSnippets = [[NSDictionary dictionaryWithDictionary:[completionPlist objectForKey:SPCompletionTokensSnippetsKey]] retain];
		} 
		else {
			errorDescription = [NSString stringWithFormat:@"No '%@' dictionary found.", SPCompletionTokensSnippetsKey];
		}
	}
	
	return errorDescription ? [NSError errorWithDomain:NSCocoaErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey : errorDescription}] : nil;
}

@end

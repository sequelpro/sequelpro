//
//  $Id$
//
//  SPQueryControllerInitializer.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on September 1, 2011
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

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
 * Set the window's auto save name and initialise display
 */
- (void)awakeFromNib
{
#ifndef SP_REFACTOR /* init ivars */
	prefs = [NSUserDefaults standardUserDefaults];
	
	[self setWindowFrameAutosaveName:SPQueryConsoleWindowAutoSaveName];
	
	// Show/hide table columns
	[[consoleTableView tableColumnWithIdentifier:SPTableViewDateColumnID] setHidden:![prefs boolForKey:SPConsoleShowTimestamps]];
	[[consoleTableView tableColumnWithIdentifier:SPTableViewConnectionColumnID] setHidden:![prefs boolForKey:SPConsoleShowConnections]];
	
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
	
	for (NSTableColumn *column in [consoleTableView tableColumns])
	{
		[[column dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
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
	
	return errorDescription ? [NSError errorWithDomain:NSCocoaErrorDomain code:1 userInfo:[NSDictionary dictionaryWithObject:errorDescription forKey:NSLocalizedDescriptionKey]] : nil;
}

@end

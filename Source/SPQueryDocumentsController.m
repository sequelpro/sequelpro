//
//  $Id$
//
//  SPQueryDocumentsController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on August 30, 2011
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

#import "SPQueryDocumentsController.h"

@implementation SPQueryController (SPQueryDocumentsController)

- (NSURL *)registerDocumentWithFileURL:(NSURL *)fileURL andContextInfo:(NSMutableDictionary *)contextInfo
{
#ifndef SP_REFACTOR
	// Register a new untiled document and return its URL
	if (fileURL == nil) {
		NSURL *new = [NSURL URLWithString:[[NSString stringWithFormat:NSLocalizedString(@"Untitled %ld",@"Title of a new Sequel Pro Document"), (unsigned long)untitledDocumentCounter] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
		untitledDocumentCounter++;
		
		if (![favoritesContainer objectForKey:[new absoluteString]]) {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[favoritesContainer setObject:arr forKey:[new absoluteString]];
			[arr release];
		}
		
		// Set the global history coming from the Prefs as default if available
		if (![historyContainer objectForKey:[new absoluteString]]) {
			if ([prefs objectForKey:SPQueryHistory]) {
				NSMutableArray *arr = [[NSMutableArray alloc] init];
				[arr addObjectsFromArray:[prefs objectForKey:SPQueryHistory]];
				[historyContainer setObject:arr forKey:[new absoluteString]];
				[arr release];
			} 
			else {
				NSMutableArray *arr = [[NSMutableArray alloc] init];
				[historyContainer setObject:[NSMutableArray array] forKey:[new absoluteString]];
				[arr release];
			}
		}
		
		// Set the doc-based content filters
		if (![contentFilterContainer objectForKey:[new absoluteString]]) {
			[contentFilterContainer setObject:[NSMutableDictionary dictionary] forKey:[new absoluteString]];
		}
		
		return new;
	}
	
	// Register a spf file to manage all query favorites and query history items
	// file path based (incl. Untitled docs) in a dictionary whereby the key represents the file URL as string.
	if (![favoritesContainer objectForKey:[fileURL absoluteString]]) {
		if (contextInfo != nil && [contextInfo objectForKey:SPQueryFavorites] && [[contextInfo objectForKey:SPQueryFavorites] count]) {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[arr addObjectsFromArray:[contextInfo objectForKey:SPQueryFavorites]];
			[favoritesContainer setObject:arr forKey:[fileURL absoluteString]];
			[arr release];
		} 
		else {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[favoritesContainer setObject:arr forKey:[fileURL absoluteString]];
			[arr release];
		}
	}
	
	if (![historyContainer objectForKey:[fileURL absoluteString]]) {
		if (contextInfo != nil && [contextInfo objectForKey:SPQueryHistory] && [[contextInfo objectForKey:SPQueryHistory] count]) {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[arr addObjectsFromArray:[contextInfo objectForKey:SPQueryHistory]];
			[historyContainer setObject:arr forKey:[fileURL absoluteString]];
			[arr release];
		} 
		else {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[historyContainer setObject:arr forKey:[fileURL absoluteString]];
			[arr release];
		}
	}
	
	if (![contentFilterContainer objectForKey:[fileURL absoluteString]]) {
		if (contextInfo != nil && [contextInfo objectForKey:SPContentFilters]) {
			[contentFilterContainer setObject:[contextInfo objectForKey:SPContentFilters] forKey:[fileURL absoluteString]];
		} 
		else {
			NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
			[contentFilterContainer setObject:dict forKey:[fileURL absoluteString]];
			[dict release];
		}
	}
	
	return fileURL;
#else
	return nil;
#endif
}

- (void)removeRegisteredDocumentWithFileURL:(NSURL *)fileURL
{
#ifndef SP_REFACTOR
	// Check for multiple instance of the same document.
	// Remove it if only one instance was registerd.
	NSArray *allDocs = [[NSApp delegate] orderedDocuments];
	NSMutableArray *allURLs = [NSMutableArray array];
	
	for (id doc in allDocs) 
	{
		if (![doc fileURL]) continue;
		
		if ([allURLs containsObject:[doc fileURL]]) {
			return;
		}
		else {
			[allURLs addObject:[doc fileURL]];
		}
	}
	
	if ([favoritesContainer objectForKey:[fileURL absoluteString]]) {
		[favoritesContainer removeObjectForKey:[fileURL absoluteString]];
	}
	
	if ([historyContainer objectForKey:[fileURL absoluteString]]) {
		[historyContainer removeObjectForKey:[fileURL absoluteString]];
	}
	
	if ([contentFilterContainer objectForKey:[fileURL absoluteString]]) {
		[contentFilterContainer removeObjectForKey:[fileURL absoluteString]];
	}
#endif
}

- (void)replaceContentFilterByArray:(NSArray *)contentFilterArray ofType:(NSString *)filterType forFileURL:(NSURL *)fileURL
{
#ifndef SP_REFACTOR
	if ([contentFilterContainer objectForKey:[fileURL absoluteString]]) {
		NSMutableDictionary *c = [[NSMutableDictionary alloc] init];
		[c setDictionary:[contentFilterContainer objectForKey:[fileURL absoluteString]]];
		[c setObject:contentFilterArray forKey:filterType];
		[contentFilterContainer setObject:c forKey:[fileURL absoluteString]];
		[c release];
	}
#endif
}

- (void)replaceFavoritesByArray:(NSArray *)favoritesArray forFileURL:(NSURL *)fileURL
{
#ifndef SP_REFACTOR
	if ([favoritesContainer objectForKey:[fileURL absoluteString]]) {
		[favoritesContainer setObject:favoritesArray forKey:[fileURL absoluteString]];
	}
#endif
}

/**
 * Remove a Query Favorite the passed file URL
 *
 * @param index The index of the to be removed favorite
 *
 * @param fileURL The NSURL of the current active SPDatabaseDocument
 */
- (void)removeFavoriteAtIndex:(NSUInteger)index forFileURL:(NSURL *)fileURL
{
#ifndef SP_REFACTOR
	[[favoritesContainer objectForKey:[fileURL absoluteString]] removeObjectAtIndex:index];
#endif
}

- (void)insertFavorite:(NSDictionary *)favorite atIndex:(NSUInteger)index forFileURL:(NSURL *)fileURL
{
#ifndef SP_REFACTOR
	[[favoritesContainer objectForKey:[fileURL absoluteString]] insertObject:favorite atIndex:index];
#endif
}

- (void)replaceHistoryByArray:(NSArray *)historyArray forFileURL:(NSURL *)fileURL
{
#ifndef SP_REFACTOR
	if ([historyContainer objectForKey:[fileURL absoluteString]]) {
		[historyContainer setObject:historyArray forKey:[fileURL absoluteString]];
	}
	
	// Inform all opened documents to update the history list
	for (id doc in [[NSApp delegate] orderedDocuments])
	{
		if([[doc valueForKeyPath:@"customQueryInstance"] respondsToSelector:@selector(historyItemsHaveBeenUpdated:)]) {
			[[doc valueForKeyPath:@"customQueryInstance"] performSelectorOnMainThread:@selector(historyItemsHaveBeenUpdated:) withObject:self waitUntilDone:NO];
		}
	}
			
	// User did choose to clear the global history list
	if (![fileURL isFileURL] && ![historyArray count]) {
		[prefs setObject:historyArray forKey:SPQueryHistory];
	}
#endif
}

- (void)addFavorite:(NSDictionary *)favorite forFileURL:(NSURL *)fileURL
{
#ifndef SP_REFACTOR
	if ([favoritesContainer objectForKey:[fileURL absoluteString]]) {
		[[favoritesContainer objectForKey:[fileURL absoluteString]] addObject:favorite];
	}
#endif
}

- (void)addHistory:(NSString *)history forFileURL:(NSURL *)fileURL
{
#ifndef SP_REFACTOR
	NSUInteger maxHistoryItems = [[prefs objectForKey:SPCustomQueryMaxHistoryItems] integerValue];
	
	// Save each history item due to its document source
	if ([historyContainer objectForKey:[fileURL absoluteString]]) {
		
		// Remove all duplicates by using a NSPopUpButton
		NSPopUpButton *uniquifier = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0,0,0) pullsDown:YES];
		
		[uniquifier addItemsWithTitles:[historyContainer objectForKey:[fileURL absoluteString]]];
		[uniquifier insertItemWithTitle:history atIndex:0];
		
		while ((NSUInteger)[uniquifier numberOfItems] > maxHistoryItems)
		{
			[uniquifier removeItemAtIndex:[uniquifier numberOfItems]-1];
		}
		
		[self replaceHistoryByArray:[uniquifier itemTitles] forFileURL:fileURL];
		[uniquifier release];
	}
	
	// Save history items coming from each Untitled document in the global Preferences successively
	// regardingless of the source document.
	if (![fileURL isFileURL]) {
		
		// Remove all duplicates by using a NSPopUpButton
		NSPopUpButton *uniquifier = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0,0,0) pullsDown:YES];
		[uniquifier addItemsWithTitles:[prefs objectForKey:SPQueryHistory]];
		[uniquifier insertItemWithTitle:history atIndex:0];
		
		while ((NSUInteger)[uniquifier numberOfItems] > maxHistoryItems)
		{
			[uniquifier removeItemAtIndex:[uniquifier numberOfItems] - 1];
		}
		
		[prefs setObject:[uniquifier itemTitles] forKey:SPQueryHistory];
		[uniquifier release];
	}
#endif
}

- (NSMutableArray *)favoritesForFileURL:(NSURL *)fileURL
{
#ifndef SP_REFACTOR
	if ([favoritesContainer objectForKey:[fileURL absoluteString]]) {
		return [favoritesContainer objectForKey:[fileURL absoluteString]];
	}
#endif
	
	return [NSMutableArray array];
}

- (NSMutableArray *)historyForFileURL:(NSURL *)fileURL
{
#ifndef SP_REFACTOR
	if ([historyContainer objectForKey:[fileURL absoluteString]]) {
		return [historyContainer objectForKey:[fileURL absoluteString]];
	}
#endif
	
	return [NSMutableArray array];
}

- (NSArray *)historyMenuItemsForFileURL:(NSURL *)fileURL
{
#ifndef SP_REFACTOR
	if ([historyContainer objectForKey:[fileURL absoluteString]]) {
		NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:[[historyContainer objectForKey:[fileURL absoluteString]] count]];
		NSMenuItem *historyMenuItem;
		
		for (NSString* history in [historyContainer objectForKey:[fileURL absoluteString]]) 
		{
			historyMenuItem = [[[NSMenuItem alloc] initWithTitle:([history length] > 64) ? [NSString stringWithFormat:@"%@…", [history substringToIndex:63]] : history
														  action:NULL
												   keyEquivalent:@""] autorelease];
			
			[historyMenuItem setToolTip:([history length] > 256) ? [NSString stringWithFormat:@"%@…", [history substringToIndex:255]] : history];
			[returnArray addObject:historyMenuItem];
		}
		
		return returnArray;
	}
#endif
	
	return [NSArray array];
}

/**
 * Return the number of history items for the passed file URL
 *
 * @param fileURL The NSURL of the current active SPDatabaseDocument
 *
 */
- (NSUInteger)numberOfHistoryItemsForFileURL:(NSURL *)fileURL
{
#ifndef SP_REFACTOR
	if ([historyContainer objectForKey:[fileURL absoluteString]]) {
				return [[historyContainer objectForKey:[fileURL absoluteString]] count];
	}
	else {
		return 0;
	}
#endif
	
	return 0;
}

/**
 * Return a mutable dictionary of all content filters for the passed file URL.
 * If no content filters were found it returns an empty mutable dictionary.
 *
 * @param fileURL The NSURL of the current active SPDatabaseDocument
 *
 */
- (NSMutableDictionary *)contentFilterForFileURL:(NSURL *)fileURL
{
#ifndef SP_REFACTOR
	if ([contentFilterContainer objectForKey:[fileURL absoluteString]]) {
		return [contentFilterContainer objectForKey:[fileURL absoluteString]];
	}
#endif
	
	return [NSMutableDictionary dictionary];
}

- (NSArray *)queryFavoritesForFileURL:(NSURL *)fileURL andTabTrigger:(NSString *)tabTrigger includeGlobals:(BOOL)includeGlobals
{
	if (![tabTrigger length]) return [NSArray array];
	
	NSMutableArray *result = [[NSMutableArray alloc] init];
	
	for (id fav in [self favoritesForFileURL:fileURL]) 
	{
		if ([fav objectForKey:@"tabtrigger"] && [[fav objectForKey:@"tabtrigger"] isEqualToString:tabTrigger]) {
			[result addObject:fav];
		}
	}
	
#ifndef SP_REFACTOR
	if (includeGlobals && [prefs objectForKey:SPQueryFavorites]) {
		
		for (id fav in [prefs objectForKey:SPQueryFavorites]) 
		{
			if ([fav objectForKey:@"tabtrigger"] && [[fav objectForKey:@"tabtrigger"] isEqualToString:tabTrigger]) {
				[result addObject:fav];
				break;
			}
		}
	}
#endif
	
	return [result autorelease];
}

#pragma mark -
#pragma mark Completion list controller

/**
 * Return an array of all pre-defined SQL functions for completion.
 */
- (NSArray*)functionList
{
	return (completionFunctionList != nil && [completionFunctionList count]) ? completionFunctionList : [NSArray array];
}

/**
 * Return an array of all pre-defined SQL keywords for completion.
 */
- (NSArray*)keywordList
{
	return (completionKeywordList != nil && [completionKeywordList count]) ? completionKeywordList : [NSArray array];
}

/**
 * Return the parameter list as snippet of the passed SQL functions for completion.
 *
 * @param func The name of the function whose parameter list is asked for
 */
- (NSString*)argumentSnippetForFunction:(NSString*)func
{
	return (functionArgumentSnippets && [functionArgumentSnippets objectForKey:[func uppercaseString]]) ? [functionArgumentSnippets objectForKey:[func uppercaseString]] : @"";
}

@end

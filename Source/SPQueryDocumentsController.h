//
//  $Id$
//
//  SPQueryDocumentsController.h
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

#import "SPQueryController.h"

@interface SPQueryController (SPQueryDocumentsController)

- (NSURL *)registerDocumentWithFileURL:(NSURL *)fileURL andContextInfo:(NSMutableDictionary *)contextInfo;
- (void)removeRegisteredDocumentWithFileURL:(NSURL *)fileURL;

- (void)addFavorite:(NSDictionary *)favorite forFileURL:(NSURL *)fileURL;
- (void)replaceFavoritesByArray:(NSArray *)favoritesArray forFileURL:(NSURL *)fileURL;
- (void)removeFavoriteAtIndex:(NSUInteger)index forFileURL:(NSURL *)fileURL;
- (void)insertFavorite:(NSDictionary *)favorite atIndex:(NSUInteger)index forFileURL:(NSURL *)fileURL;

- (void)addHistory:(NSString *)history forFileURL:(NSURL *)fileURL;
- (void)replaceHistoryByArray:(NSArray *)historyArray forFileURL:(NSURL *)fileURL;

- (void)replaceContentFilterByArray:(NSArray *)contentFilterArray ofType:(NSString *)filterType forFileURL:(NSURL *)fileURL;

- (NSMutableArray *)favoritesForFileURL:(NSURL *)fileURL;
- (NSMutableArray *)historyForFileURL:(NSURL *)fileURL;
- (NSArray *)historyMenuItemsForFileURL:(NSURL *)fileURL;
- (NSUInteger)numberOfHistoryItemsForFileURL:(NSURL *)fileURL;
- (NSMutableDictionary *)contentFilterForFileURL:(NSURL *)fileURL;

- (NSArray *)queryFavoritesForFileURL:(NSURL *)fileURL andTabTrigger:(NSString *)tabTrigger includeGlobals:(BOOL)includeGlobals;

// Completion list controller
- (NSArray*)functionList;
- (NSArray*)keywordList;
- (NSString*)argumentSnippetForFunction:(NSString*)func;

@end

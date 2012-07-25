//
//  $Id$
//
//  SPQueryDocumentsController.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on August 30, 2011.
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

//
//  SPQueryFavoriteManager.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Aug 23, 2009.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

@class SPTextView;
@class SPDatabaseDocument;
@class SPSplitView;

@interface SPQueryFavoriteManager : NSWindowController <NSOpenSavePanelDelegate>
{
#ifndef SP_CODA /* ivars */
	NSUserDefaults *prefs;

	NSURL *delegatesFileURL;
#endif
	SPDatabaseDocument *tableDocumentInstance;
	IBOutlet NSPopUpButton *encodingPopUp;
	IBOutlet NSTableView *favoritesTableView;
	IBOutlet NSTextField *favoriteNameTextField;
	IBOutlet NSTextField *favoriteTabTriggerTextField;
	IBOutlet SPTextView  *favoriteQueryTextView;
	IBOutlet SPSplitView *favoritesSplitView;
	IBOutlet NSButton *removeButton;

	IBOutlet NSArrayController *favoritesArrayController;

	NSMutableArray *favorites;

	BOOL isTableCellEditing;
}

- (id)initWithDelegate:(id)managerDelegate;

#ifndef SP_CODA

// Accessors
- (NSMutableArray *)queryFavoritesForFileURL:(NSURL *)fileURL;
- (id)customQueryInstance;

// IBAction methods
- (IBAction)addQueryFavorite:(id)sender;
- (IBAction)removeQueryFavorite:(id)sender;
- (IBAction)removeAllQueryFavorites:(id)sender;
- (IBAction)duplicateQueryFavorite:(id)sender;
- (IBAction)saveFavoriteToFile:(id)sender;
- (IBAction)exportFavorites:(id)sender;
- (IBAction)importFavoritesByAdding:(id)sender;
- (IBAction)importFavoritesByReplacing:(id)sender;
- (IBAction)closeQueryManagerSheet:(id)sender;
- (IBAction)insertPlaceholder:(id)sender;
- (IBAction)showHelp:(id)sender;

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo;
- (void)importPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo;
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo;
#endif

@end

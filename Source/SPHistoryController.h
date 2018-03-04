//
//  SPHistoryController.h
//  sequel-pro
//
//  Created by Rowan Beentje on July 23, 2009.
//  Copyright (c) 2008 Rowan Beentje. All rights reserved.
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

@class SPDatabaseDocument;
@class SPTableContent;
@class SPTablesList;

@interface SPHistoryController : NSObject 
{
	IBOutlet SPDatabaseDocument *theDocument;
	IBOutlet NSSegmentedControl *historyControl;

	SPTableContent *tableContentInstance;
	SPTablesList *tablesListInstance;
	NSMutableArray *history;
	NSMutableDictionary *tableContentStates;
	NSUInteger historyPosition;
	BOOL modifyingState;
	BOOL toolbarItemVisible;
}

@property (readonly) NSUInteger historyPosition;
@property (readonly) NSMutableArray *history;
@property (readwrite, assign) BOOL modifyingState;

// Interface interaction
- (void) updateToolbarItem;
- (void)goBackInHistory;
- (void)goForwardInHistory;
- (IBAction) historyControlClicked:(NSSegmentedControl *)theControl;
- (void) setupInterface;
- (void) startDocumentTask:(NSNotification *)aNotification;
- (void) endDocumentTask:(NSNotification *)aNotification;

// Adding or updating history entries
- (void) updateHistoryEntries;

// Loading history entries
- (void) loadEntryAtPosition:(NSUInteger)position;
- (void) loadEntryTaskWithPosition:(NSNumber *)positionNumber;
- (void) abortEntryLoadWithPool:(NSAutoreleasePool *)pool;
- (void) loadEntryFromMenuItem:(id)theMenuItem;

// Restoring view states
- (void) restoreViewStates;

// History entry details and description
- (NSMenuItem *) menuEntryForHistoryEntryAtIndex:(NSInteger)theIndex;
- (NSString *) nameForHistoryEntryDetails:(NSDictionary *)theEntry;

@end

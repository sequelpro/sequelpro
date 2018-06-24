//
//  SPContentFilterManager.h
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on Sep 29, 2009.
//  Copyright (c) 2009 Hans-Jörg Bibiko. All rights reserved.
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
@class SPSplitView;

@interface SPContentFilterManager : NSWindowController <NSOpenSavePanelDelegate>
{
#ifndef SP_CODA /* ivars */
	NSUserDefaults *prefs;
#endif
	
	SPDatabaseDocument *tableDocumentInstance;
#ifndef SP_CODA /* ivars */
	NSURL *documentFileURL;
#endif

	IBOutlet id encodingPopUp;
	IBOutlet id contentFilterTableView;
	IBOutlet id contentFilterNameTextField;
	IBOutlet id contentFilterConjunctionTextField;
	IBOutlet id contentFilterConjunctionLabel;
	IBOutlet id contentFilterTextView;
	IBOutlet SPSplitView *contentFilterSplitView;
	IBOutlet id removeButton;
	IBOutlet id numberOfArgsLabel;
	IBOutlet id resultingClauseLabel;
	IBOutlet id resultingClauseContentLabel;
	IBOutlet id insertPlaceholderButton;
	IBOutlet NSButton *suppressLeadingFieldPlaceholderCheckbox;

	IBOutlet id contentFilterArrayController;
	
	NSMutableArray *contentFilters;

	BOOL isTableCellEditing;
	
	NSString *filterType;
}

- (id)initWithDatabaseDocument:(SPDatabaseDocument *)document forFilterType:(NSString *)compareType;

// Accessors
- (NSMutableArray *)contentFilterForFileURL:(NSURL *)fileURL;
- (id)customQueryInstance;

// IBAction methods
- (IBAction)addContentFilter:(id)sender;
- (IBAction)removeContentFilter:(id)sender;
- (IBAction)insertPlaceholder:(id)sender;
- (IBAction)duplicateContentFilter:(id)sender;
- (IBAction)exportContentFilter:(id)sender;
- (IBAction)importContentFilterByAdding:(id)sender;
- (IBAction)closeContentFilterManagerSheet:(id)sender;
- (IBAction)suppressLeadingFieldPlaceholderWasChanged:(id)sender;

@end

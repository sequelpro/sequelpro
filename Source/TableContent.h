//
//  $Id$
//
//  TableDocument.h
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  
//  Forked by Abhi Beckert (abhibeckert.com) 2008-04-04
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

#import <Cocoa/Cocoa.h>
#import <MCPKit_bundled/MCPKit_bundled.h>

@interface QLPreviewPanel : NSPanel
{
}

+ (id)sharedPreviewPanel;
+ (id)_previewPanel;
+ (BOOL)isSharedPreviewPanelLoaded;
- (id)initWithContentRect:(struct _NSRect)fp8 styleMask:(unsigned int)fp24 backing:(unsigned int)fp28 defer:(BOOL)fp32;
- (id)initWithCoder:(id)fp8;
- (void)dealloc;
- (BOOL)isOpaque;
- (BOOL)canBecomeKeyWindow;
- (BOOL)canBecomeMainWindow;
- (BOOL)shouldIgnorePanelFrameChanges;
- (BOOL)isOpen;
- (void)setFrame:(struct _NSRect)fp8 display:(BOOL)fp24 animate:(BOOL)fp28;
- (id)_subEffectsForWindow:(id)fp8 itemFrame:(struct _NSRect)fp12 transitionWindow:(id *)fp28;
- (id)_scaleEffectForItemFrame:(struct _NSRect)fp8 transitionWindow:(id *)fp24;
- (void)_invertCurrentEffect;
- (struct _NSRect)_currentItemFrame;
- (void)setAutosizesAndCenters:(BOOL)fp8;
- (BOOL)autosizesAndCenters;
- (void)makeKeyAndOrderFront:(id)fp8;
- (void)makeKeyAndOrderFrontWithEffect:(int)fp8;
- (void)makeKeyAndGoFullscreenWithEffect:(int)fp8;
- (void)makeKeyAndOrderFrontWithEffect:(int)fp8 canClose:(BOOL)fp12;
- (void)_makeKeyAndOrderFrontWithEffect:(int)fp8 canClose:(BOOL)fp12 willOpen:(BOOL)fp16 toFullscreen:(BOOL)fp20;
- (int)openingEffect;
- (void)closePanel;
- (void)close;
- (void)closeWithEffect:(int)fp8;
- (void)closeWithEffect:(int)fp8 canReopen:(BOOL)fp12;
- (void)_closeWithEffect:(int)fp8 canReopen:(BOOL)fp12;
- (void)windowEffectDidTerminate:(id)fp8;
- (void)_close:(id)fp8;
- (void)sendEvent:(id)fp8;
- (void)selectNextItem;
- (void)selectPreviousItem;
- (void)setURLs:(id)fp8 currentIndex:(unsigned int)fp12 preservingDisplayState:(BOOL)fp16;
- (void)setURLs:(id)fp8 preservingDisplayState:(BOOL)fp12;
- (void)setURLs:(id)fp8;
- (id)URLs;
- (unsigned int)indexOfCurrentURL;
- (void)setIndexOfCurrentURL:(unsigned int)fp8;
- (void)setDelegate:(id)fp8;
- (id)sharedPreviewView;
- (void)setSharedPreviewView:(id)fp8;
- (void)setCyclesSelection:(BOOL)fp8;
- (BOOL)cyclesSelection;
- (void)setShowsAddToiPhotoButton:(BOOL)fp8;
- (BOOL)showsAddToiPhotoButton;
- (void)setShowsiChatTheaterButton:(BOOL)fp8;
- (BOOL)showsiChatTheaterButton;
- (void)setShowsFullscreenButton:(BOOL)fp8;
- (BOOL)showsFullscreenButton;
- (void)setShowsIndexSheetButton:(BOOL)fp8;
- (BOOL)showsIndexSheetButton;
- (void)setAutostarts:(BOOL)fp8;
- (BOOL)autostarts;
- (void)setPlaysDuringPanelAnimation:(BOOL)fp8;
- (BOOL)playsDuringPanelAnimation;
- (void)setDeferredLoading:(BOOL)fp8;
- (BOOL)deferredLoading;
- (void)setEnableDragNDrop:(BOOL)fp8;
- (BOOL)enableDragNDrop;
- (void)start:(id)fp8;
- (void)stop:(id)fp8;
- (void)setShowsIndexSheet:(BOOL)fp8;
- (BOOL)showsIndexSheet;
- (void)setShareWithiChat:(BOOL)fp8;
- (BOOL)shareWithiChat;
- (void)setPlaysSlideShow:(BOOL)fp8;
- (BOOL)playsSlideShow;
- (void)setIsFullscreen:(BOOL)fp8;
- (BOOL)isFullscreen;
- (void)setMandatoryClient:(id)fp8;
- (id)mandatoryClient;
- (void)setForcedContentTypeUTI:(id)fp8;
- (id)forcedContentTypeUTI;
- (void)setDocumentURLs:(id)fp8;
- (void)setDocumentURLs:(id)fp8 preservingDisplayState:(BOOL)fp12;
- (void)setDocumentURLs:(id)fp8 itemFrame:(struct _NSRect)fp12;
- (void)setURLs:(id)fp8 itemFrame:(struct _NSRect)fp12;
- (void)setAutoSizeAndCenterOnScreen:(BOOL)fp8;
- (void)setShowsAddToiPhoto:(BOOL)fp8;
- (void)setShowsiChatTheater:(BOOL)fp8;
- (void)setShowsFullscreen:(BOOL)fp8;

@end


@class CMMCPConnection, CMMCPResult, CMCopyTable;

@interface TableContent : NSObject 
{	
	IBOutlet id tableDocumentInstance;
	IBOutlet id tablesListInstance;
	IBOutlet id tableDataInstance;
	
	IBOutlet id editSheetProgressBar;
	
	IBOutlet id tableWindow;
	IBOutlet CMCopyTable *tableContentView;
	IBOutlet id editSheet;
	IBOutlet id editSheetSegmentControl;
	IBOutlet id editSheetQuickLookButton;
	IBOutlet id editImage;
	IBOutlet id editTextView;
	IBOutlet id hexTextView;
	IBOutlet id editTextScrollView;
	IBOutlet id hexTextScrollView;
	IBOutlet id fieldField;
	IBOutlet id compareField;
	IBOutlet id argumentField;
	IBOutlet id filterButton;
	IBOutlet id addButton;
	IBOutlet id copyButton;
	IBOutlet id removeButton;
	IBOutlet id multipleLineEditingButton;
	IBOutlet id countText;
	IBOutlet id limitRowsField;
	IBOutlet id limitRowsButton;
	IBOutlet id limitRowsStepper;
	IBOutlet id limitRowsText;
	
	CMMCPConnection *mySQLConnection;
	
	id editData;
	NSString *selectedTable, *usedQuery;
	NSMutableArray *fullResult, *filteredResult, *keys;
	NSMutableDictionary *oldRow;
	NSString *compareType, *sortField;
	BOOL isEditingRow, isEditingNewRow, isSavingRow, isDesc, setLimit;
	NSUserDefaults *prefs;
	int numRows, currentlyEditingRow, maxNumRowsOfCurrentTable;
	bool areShowingAllRows;
	
	int qlPane;
}

//table methods
- (void)loadTable:(NSString *)aTable;
- (IBAction)reloadTable:(id)sender;
- (IBAction)reloadTableValues:(id)sender;
- (IBAction)filterTable:(id)sender;
- (IBAction)showAll:(id)sender;
- (IBAction)toggleFilterField:(id)sender;
- (NSString *)usedQuery;
- (void)setUsedQuery:(NSString *)query;

//edit methods
- (IBAction)addRow:(id)sender;
- (IBAction)copyRow:(id)sender;
- (IBAction)removeRow:(id)sender;

//editSheet methods
- (IBAction)closeEditSheet:(id)sender;
- (IBAction)openEditSheet:(id)sender;
- (IBAction)saveEditSheet:(id)sender;
- (IBAction)segmentControllerChanged:(id)sender;
- (IBAction)quickLookAsMovie:(id)sender;
- (IBAction)quickLookAsSoundLinear:(id)sender;
- (IBAction)quickLookAsSoundM4A:(id)sender;
- (IBAction)quickLookAsSoundMP3:(id)sender;
- (IBAction)quickLookAsImage:(id)sender;
- (IBAction)quickLookAsPDF:(id)sender;
- (IBAction)quickLookAsWordDoc:(id)sender;
- (IBAction)quickLookAsRTF:(id)sender;
- (IBAction)quickLookAsHTML:(id)sender;
- (void)invokeQuickLookOfType:(NSString *)type;
- (void)processUpdatedImageData:(NSData *)data;
- (IBAction)dropImage:(id)sender;
- (void)textDidChange:(NSNotification *)notification;
- (NSString *)dataToHex:(NSData *)data;

//getter methods
- (NSArray *)currentResult;

//additional methods
- (void)setConnection:(CMMCPConnection *)theConnection;
- (IBAction)setCompareTypes:(id)sender;
- (IBAction)stepLimitRows:(id)sender;
- (NSArray *)fetchResultAsArray:(CMMCPResult *)theResult;
- (BOOL)addRowToDB;
- (NSString *)argumentForRow:(int)row;
- (BOOL)tableContainsBlobOrTextColumns;
- (NSString *)fieldListForQuery;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo;
- (int)getNumberOfRows;
- (int)fetchNumberOfRows;
- (BOOL)saveRowOnDeselect;

//tableView datasource methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(CMCopyTable *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex;
- (void)tableView:(NSTableView *)aTableView
	 setObjectValue:(id)anObject
	 forTableColumn:(NSTableColumn *)aTableColumn
							row:(int)rowIndex;

//tableView delegate methods
- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn;
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;
- (void)tableViewSelectionIsChanging:(NSNotification *)aNotification;
- (void)tableViewColumnDidResize:(NSNotification *)aNotification;
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard;
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command;

//textView delegate methods
- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector;

@end

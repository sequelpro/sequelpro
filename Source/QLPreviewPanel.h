//
//  $Id$
//
//  QLPreviewPanel.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on June 15, 2009.
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
//  More info at <http://code.google.com/p/sequel-pro/>

// As the QuickLook framework is private we have to make
// these methods public to avoid warnings while compiling
@interface QLPreviewPanel : NSPanel

+ (id)sharedPreviewPanel;
+ (id)_previewPanel;
+ (BOOL)isSharedPreviewPanelLoaded;
- (id)initWithContentRect:(struct _NSRect)fp8 styleMask:(NSUInteger)fp24 backing:(NSUInteger)fp28 defer:(BOOL)fp32;
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
- (void)makeKeyAndOrderFrontWithEffect:(NSInteger)fp8;
- (void)makeKeyAndGoFullscreenWithEffect:(NSInteger)fp8;
- (void)makeKeyAndOrderFrontWithEffect:(NSInteger)fp8 canClose:(BOOL)fp12;
- (void)_makeKeyAndOrderFrontWithEffect:(NSInteger)fp8 canClose:(BOOL)fp12 willOpen:(BOOL)fp16 toFullscreen:(BOOL)fp20;
- (NSInteger)openingEffect;
- (void)closePanel;
- (void)close;
- (void)closeWithEffect:(NSInteger)fp8;
- (void)closeWithEffect:(NSInteger)fp8 canReopen:(BOOL)fp12;
- (void)_closeWithEffect:(NSInteger)fp8 canReopen:(BOOL)fp12;
- (void)windowEffectDidTerminate:(id)fp8;
- (void)_close:(id)fp8;
- (void)sendEvent:(id)fp8;
- (void)selectNextItem;
- (void)selectPreviousItem;
- (void)setURLs:(id)fp8 currentIndex:(NSUInteger)fp12 preservingDisplayState:(BOOL)fp16;
- (void)setURLs:(id)fp8 preservingDisplayState:(BOOL)fp12;
- (void)setURLs:(id)fp8;
- (id)URLs;
- (NSUInteger)indexOfCurrentURL;
- (void)setIndexOfCurrentURL:(NSUInteger)fp8;
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

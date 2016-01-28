//
//  SPComboBoxCell.m
//  sequel-pro
//
//  Created by Max Lohrmann on 08.11.15.
//  Copyright (c) 2015 Max Lohrmann. All rights reserved.
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

#import "SPComboBoxCell.h"
#import <objc/runtime.h>

static NSString *_CellSelectionDidChangeNotification = @"NSComboBoxCellSelectionDidChangeNotification";
static NSString *_CellWillPopUpNotification = @"NSComboBoxCellWillPopUpNotification";
static NSString *_CellWillDismissNotification = @"NSComboBoxCellWillDismissNotification";

@interface NSComboBoxCell (Apple_Private)
- (IBAction)popUp:(id)sender;
@end

@interface SPComboBoxCell ()

- (void)sp_selectionDidChange:(NSNotification *)notification;
- (void)sp_cellWillPopUp:(NSNotification *)notification;
- (void)sp_cellWillDismiss:(NSNotification *)notification;
@end

@implementation SPComboBoxCell

@synthesize spDelegate;

- (id)copyWithZone:(NSZone *)zone
{
	SPComboBoxCell *cpy = [super copyWithZone:zone];
	
	cpy->spDelegate = [self spDelegate];
	
	return cpy;
}

- (void)dealloc
{
	[self setSpDelegate:nil];
	[super dealloc];
}

- (NSWindow *)spPopUpWindow
{
	NSWindow *popUp;
	Ivar popUpVar = object_getInstanceVariable(self,"_popUp",(void **)&popUp);
	if(popUpVar) {
		const char *typeEnc = ivar_getTypeEncoding(popUpVar);
		if(typeEnc[0] == '@' && [popUp isKindOfClass:[NSWindow class]]) { // it is an object and of class NSWindow
			return popUp;
		}
	}
	return nil;
}

- (void)popUp:(id)sender
{
	// this notification will be sent after the popup window is resized and moved to the correct position
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(sp_cellWillPopUp:)
												 name:_CellWillPopUpNotification
											   object:self];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(sp_cellWillDismiss:)
												 name:_CellWillDismissNotification
											   object:self];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(sp_selectionDidChange:)
												 name:_CellSelectionDidChangeNotification
											   object:self];
	
	[super popUp:sender]; // this method won't return until the window is closed again
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:_CellSelectionDidChangeNotification
												  object:self];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:_CellWillPopUpNotification
												  object:self];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:_CellWillDismissNotification
												  object:self];
}

- (void)sp_selectionDidChange:(NSNotification *)notification
{
	if([[self spDelegate] respondsToSelector:@selector(comboBoxCellSelectionDidChange:)]) {
		[[self spDelegate] comboBoxCellSelectionDidChange:self];
	}
}

- (void)sp_cellWillPopUp:(NSNotification *)notification
{
	NSWindow *popUp = [self spPopUpWindow];
	if(popUp && [[self spDelegate] respondsToSelector:@selector(comboBoxCell:willPopUpWindow:)]) {
		[[self spDelegate] comboBoxCell:self willPopUpWindow:popUp];
	}
}

- (void)sp_cellWillDismiss:(NSNotification *)notification
{
	NSWindow *popUp = [self spPopUpWindow];
	if(popUp && [[self spDelegate] respondsToSelector:@selector(comboBoxCell:willDismissWindow:)]) {
		[[self spDelegate] comboBoxCell:self willDismissWindow:popUp];
	}
}

@end

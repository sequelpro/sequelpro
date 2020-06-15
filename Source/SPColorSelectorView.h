//
//  SPColorSelectorView.h
//  sequel-pro
//
//  Created by Max Lohrmann on 2013-10-20
//  Copyright (c) 2013 Max Lohrmann. All rights reserved.
//
//  Adapted from:
//    CCTColorLabelMenuItemView.h
//    LabelPickerMenu
//
//    Copyright (c) 2010 Dan Messing. All Rights Reserved.
//
//  Based on:
//    TrackView.h
//    MenuItemView example code
//
//    Copyright (C) Apple Inc. All Rights Reserved. 
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


#import <Foundation/Foundation.h>

@interface SPColorSelectorView : NSView {
	
	NSMutableArray* trackingAreas;
	
	NSInteger		selectedTag;	// indicates the selected tag
	NSInteger       hoverTag;       // indicated the currently tracked tag
	BOOL			trackEntered;	// indicates we are currently inside a label tracking area
	
	id observer;                    // used for reverse notification with cocoa bindings
	NSString *observerKeyPath;
	
	IBOutlet id delegate;
	
	NSArray *colorList;
}

@property (nonatomic,readwrite,assign) NSInteger selectedTag;

/**
 * Provide a list of (NSColor *) objects (at most 7) which will be displayed in the view
 */
@property (readwrite,copy) NSArray *colorList;

@end

@protocol SPColorSelectorViewDelegate <NSObject>
@optional
/**
 * Called on a delegate when the selection did (really) change
 * @param aView The changed view
 */
- (void)colorSelectorDidChange:(SPColorSelectorView *)aView;

@end

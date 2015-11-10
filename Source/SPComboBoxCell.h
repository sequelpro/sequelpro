//
//  SPComboBoxCell.h
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

#import <Cocoa/Cocoa.h>

@class SPComboBoxCell;

@protocol SPComboBoxCellDelegate <NSObject>

@optional
- (void)comboBoxCell:(SPComboBoxCell *)cell willPopUpWindow:(NSWindow *)win;
- (void)comboBoxCell:(SPComboBoxCell *)cell willDismissWindow:(NSWindow *)win;
- (void)comboBoxCellSelectionDidChange:(SPComboBoxCell *)cell;

@end

/**
 * See this class as a kind of "rapid prototype".
 * It heavily relies on the inner workings of the NSComboBoxCell to implement
 * the additional features we want (namely the option to show a tooltip
 * window beside the popup list).
 *
 * App Store-wise it would probably we better to implement this from scratch,
 * but NSComboBoxCell uses some quite difficult logic inside -filterEvents:
 * which is the core method of the selection process.
 *
 * We could somewhat work around the private interface by relying on notification
 *   NSComboBoxCellWillPopUpNotification
 * and overriding -[NSWindow addChildWindow:] / -[NSWindow removeChildWindow:]
 * but NSTableView foils that as it will copy the cell right before the notification
 * is sent, so we don't know what object to observe.
 */
@interface SPComboBoxCell : NSComboBoxCell {
	id<SPComboBoxCellDelegate> spDelegate;
}

@property (assign) IBOutlet id<SPComboBoxCellDelegate> spDelegate; // NSComboBoxCell already has a delegate property

/**
 * The popUp window that contains the item list.
 * Will return nil if the implementation changes and the underlying ivar
 * is removed or no longer a NSWindow.
 */
- (NSWindow *)spPopUpWindow;

@end

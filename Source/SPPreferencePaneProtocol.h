//
//  SPPreferencePaneProtocol.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 29, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

/**
 * @protocol SPPreferencePane SPPreferencePane.h
 *
 * @author Stuart Connolly http://stuconnolly.com/ 
 *
 * Protocol that all preference pane controllers should conform to.
 */
@protocol SPPreferencePaneProtocol

/**
 * Returns the preference pane's view.
 *
 * @return The pane's NSView instance
 */
- (NSView *)preferencePaneView;

/**
 * Returns the preference pane's toolbar item icon/image.
 *
 * @return The pane's NSImage instance
 */
- (NSImage *)preferencePaneIcon;

/**
 * Returns the preference pane's name.
 *
 * @return The pane's name
 */
- (NSString *)preferencePaneName;

/**
 * Returns the preference pane's toolbar item identifier.
 *
 * @return The pane's identifier
 */
- (NSString *)preferencePaneIdentifier;

/**
 * Returns the preference pane's toolbar item tooltip.
 *
 * @return The pane's tooltip
 */
- (NSString *)preferencePaneToolTip;

/**
 * Indicates whether or not the preference pane can be resized.
 *
 * @return A BOOL indicating resizability
 */
- (BOOL)preferencePaneAllowsResizing;

/**
 * Called shortly before the preference pane will be made visible
 */
- (void)preferencePaneWillBeShown;

@end

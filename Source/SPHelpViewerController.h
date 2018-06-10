//
//  SPHelpViewerController.h
//  sequel-pro
//
//  Created by Max Lohrmann on 21.05.18.
//  Copyright (c) 2018 Max Lohrmann. All rights reserved.
//  Parts relocated from existing files. Previous copyright applies.
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

@class WebView;

//private
typedef NS_ENUM(NSUInteger, HelpTarget) {
	HelpTargetMySQL = 0,
	HelpTargetPage = 1,
	HelpTargetWeb = 2,
};

NSString * const SPHelpViewerSearchTOC;

/**
 * This notification is posted by the SPHelpViewerController when the user
 * triggered closing the help viewer window (or by -performClose:).
 * The window is not guaranteed to be off screen already, when the notification is sent.
 *
 * It will NOT be sent when the window was closed or hidden by code (including app termination).
 */
NSString * const SPUserClosedHelpViewerNotification;

@protocol SPHelpViewerDataSource <NSObject>

@required
/**
 * When called with a search string this method should open the user's default browser
 * with an URL to the MySQL online manual for the page that explains the search string.
 */
- (void)openOnlineHelpForTopic:(NSString *)searchString;

/**
 * This method is called by the SPHelpViewerController when it wants to receive the HTML
 * page to display in response to a search string.
 *
 * The implementation has to handle the magic search string SPHelpViewerSearchTOC to
 * return a table of contents document.
 */
- (NSString *)HTMLHelpContentsForSearchString:(NSString *)searchString autoHelp:(BOOL)autoHelp;

@end

/**
 * This is the window controller class for the MySQL Help Viewer panel.
 *
 * See SPHelpViewerClient for the class that provides data for this controller and which
 * can be instantiated from within an XIB.
 *
 * - Do NOT instantiate this class from within an XIB.
 * - None of the methods in this class are thread-safe - always use the UI thread!
 */
@interface SPHelpViewerController : NSWindowController
{
	IBOutlet WebView *helpWebView;

	IBOutlet NSSearchField *helpSearchField;
	IBOutlet NSSearchFieldCell *helpSearchFieldCell;
	IBOutlet NSSegmentedControl *helpNavigator;
	IBOutlet NSSegmentedControl *helpTargetSelector;

	HelpTarget helpTarget;

	id<SPHelpViewerDataSource> dataSource;
}

@property (assign, nonatomic) id <SPHelpViewerDataSource> dataSource;

- (void)showHelpFor:(NSString *)aString addToHistory:(BOOL)addToHistory calledByAutoHelp:(BOOL)autoHelp;

@end

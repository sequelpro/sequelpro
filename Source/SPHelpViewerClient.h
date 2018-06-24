//
//  SPHelpViewerClient.h
//  sequel-pro
//
//  Created by Max Lohrmann on 25.05.18.
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

@class SPHelpViewerController;
@class SPMySQLConnection;
@class MGTemplateEngine;

/**
 * This is the client side of the Help Viewer window, i.e. this class
 * can be instantiated from within an xib file as a custom object.
 *
 * It also contains the logic to look up the help in the mysql database
 * using the mySQLConnection (which does not belong into the Help Viewer's
 * window controller).
 *
 * Notifications posted:
 *  * SPUserClosedHelpViewerNotification
 *      When the user triggered closing the help viewer window
 */
@interface SPHelpViewerClient : NSObject
{
	SPHelpViewerController *controller;

	NSString *helpHTMLTemplate;
	SPMySQLConnection *mySQLConnection;

	MGTemplateEngine *engine;
}

- (void)setConnection:(SPMySQLConnection *)theConnection;

- (NSWindow *)helpWebViewWindow;

- (void)showHelpFor:(NSString *)aString addToHistory:(BOOL)addToHistory calledByAutoHelp:(BOOL)autoHelp;

// this is not bound in Interface Builder, but used by the SPTextView context menu
- (IBAction)showHelpForCurrentWord:(id)sender;
@end

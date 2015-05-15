//
//  SPPreferenceController.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on December 10, 2008.
//  Copyright (c) 2008 Stuart Connolly. All rights reserved.
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

#import "SPPreferencePaneProtocol.h"

@class SPGeneralPreferencePane;
@class SPTablesPreferencePane;
@class SPNotificationsPreferencePane;
@class SPEditorPreferencePane;
@class SPAutoUpdatePreferencePane;
@class SPNetworkPreferencePane;

/**
 * @class SPPreferenceController SPPreferenceController.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * Main preferences window controller.
 */
@interface SPPreferenceController : NSWindowController <NSToolbarDelegate>
{	
	// Preference pane controllers
	IBOutlet SPGeneralPreferencePane <SPPreferencePaneProtocol>       *generalPreferencePane;
	IBOutlet SPTablesPreferencePane  <SPPreferencePaneProtocol>       *tablesPreferencePane;
	IBOutlet SPNotificationsPreferencePane <SPPreferencePaneProtocol> *notificationsPreferencePane;
	IBOutlet SPEditorPreferencePane <SPPreferencePaneProtocol>        *editorPreferencePane;
	IBOutlet SPAutoUpdatePreferencePane <SPPreferencePaneProtocol>    *autoUpdatePreferencePane;
	IBOutlet SPNetworkPreferencePane <SPPreferencePaneProtocol>       *networkPreferencePane;

	NSToolbar *toolbar;
	NSArray *preferencePanes;
	
	// Toolbar items
	NSToolbarItem *generalItem;
	NSToolbarItem *notificationsItem;
	NSToolbarItem *tablesItem;
	NSToolbarItem *autoUpdateItem;
	NSToolbarItem *networkItem;
	NSToolbarItem *editorItem;
	NSToolbarItem *shortcutItem;
	
	SPPreferenceFontChangeTarget fontChangeTarget;
}

@property (readonly) SPGeneralPreferencePane       *generalPreferencePane;
@property (readonly) SPTablesPreferencePane        *tablesPreferencePane;
@property (readonly) SPNotificationsPreferencePane *notificationsPreferencePane;
@property (readonly) SPEditorPreferencePane        *editorPreferencePane;
@property (readonly) SPAutoUpdatePreferencePane    *autoUpdatePreferencePane;
@property (readonly) SPNetworkPreferencePane       *networkPreferencePane;

/**
 * @property fontChangeTarget Indicates which font was changed. See SPPreferenceFontChangeTarget for values.
 */
@property (readwrite, assign) SPPreferenceFontChangeTarget fontChangeTarget;

// Toolbar item IBAction methods
- (IBAction)displayPreferencePane:(id)sender;

- (void)changeFont:(id)sender;

@end

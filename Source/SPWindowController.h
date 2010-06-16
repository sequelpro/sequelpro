//
//  $Id$
//
//  SPWindowController.h
//  sequel-pro
//
//  Created by Rowan Beentje on May 16, 2010
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
@class PSMTabBarControl, SPDatabaseDocument;

@interface SPWindowController : NSWindowController <NSUserInterfaceValidations>
{
	IBOutlet PSMTabBarControl *tabBar;
	IBOutlet NSTabView *tabView;

	NSMenuItem *closeWindowMenuItem;
	NSMenuItem *closeTabMenuItem;

	NSMutableArray *managedDatabaseConnections;
	SPDatabaseDocument *selectedTableDocument;
}

// Database connection management
- (IBAction) addNewConnection:(id)sender;
- (IBAction) moveSelectedTabInNewWindow:(id)sender;
- (SPDatabaseDocument *) selectedTableDocument;
- (void) updateSelectedTableDocument;
- (void) updateAllTabTitles:(id)sender;
- (IBAction)closeTab:(id)sender;
- (IBAction)selectNextDocumentTab:(id)sender;
- (IBAction)selectPreviousDocumentTab:(id)sender;
- (NSArray *)documents;

@end

//
//  $Id$
//
//  SPNavigatorController.h
//  sequel-pro
//
//  Created by Hans-J. Bibiko on March 17, 2010.
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
#import <MCPKit/MCPKit.h>

@interface SPNavigatorController : NSWindowController 
{
	IBOutlet id outlineSchema2;
	IBOutlet id navigatorWindow;
	IBOutlet id infoTable;
	IBOutlet id searchField;
	IBOutlet id syncButton;

	IBOutlet id schemaStatusSplitView;
	IBOutlet id schema12SplitView;

	NSUserDefaults *prefs;

	NSMutableDictionary *schemaData;
	NSMutableDictionary *schemaDataFiltered;
	NSMutableDictionary *allSchemaKeys;
	NSMutableArray *infoArray;
	NSMutableArray *updatingConnections;
	NSMutableDictionary *expandStatus1;
	NSMutableDictionary *expandStatus2;

	NSString *selectedKey2;
	NSRect selectionViewPort2;
	BOOL ignoreUpdate;
	BOOL isFiltered;
	
	BOOL isFiltering;
	
	NSImage *connectionIcon;
	NSImage *databaseIcon;
	NSImage *tableIcon;
	NSImage *viewIcon;
	NSImage *procedureIcon;
	NSImage *functionIcon;
	NSImage *fieldIcon;
	
	Class NSDictionaryClass;
	
}

+ (SPNavigatorController *)sharedNavigatorController;

- (IBAction)outlineViewAction:(id)sender;
- (IBAction)reloadAllStructures:(id)sender;
- (IBAction)filterTree:(id)sender;
- (IBAction)syncButtonAction:(id)sender;

- (void)updateEntriesForConnection:(id)object;
- (NSString*)tableInfoLabelForIndex:(NSInteger)index ofType:(NSInteger)type;

- (void)updateNavigator:(NSNotification *)aNotification;

- (NSDictionary *)dbStructureForConnection:(NSString*)connectionID;
- (NSArray *)allSchemaKeysForConnection:(NSString*)connectionID;
- (NSArray *)getUniqueDbIdentifierFor:(NSString*)term andConnection:(NSString*)connectionID;

- (BOOL)isUpdatingConnection:(NSString*)connectionID;
- (BOOL)isUpdating;

- (void)restoreSelectedItems;
- (void)setIgnoreUpdate:(BOOL)flag;
- (void)selectPath:(NSString*)schemaPath;
- (BOOL)syncMode;
- (void)removeConnection:(NSString*)connectionID;
- (void)selectInActiveDocumentItem:(id)item fromView:(id)outlineView;

- (BOOL)schemaPathExistsForConnection:(NSString*)connectionID andDatabase:(NSString*)dbname;
- (void)removeDatabase:(NSString*)db_id forConnectionID:(NSString*)connectionID;

@end

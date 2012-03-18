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

@class SPNavigatorOutlineView;

@interface SPNavigatorController : NSWindowController 
{
#ifndef SP_REFACTOR /* ivars */
	IBOutlet SPNavigatorOutlineView *outlineSchema2;
	IBOutlet id navigatorWindow;
	IBOutlet id infoTable;
	IBOutlet id searchField;
	IBOutlet NSButton *syncButton;

	IBOutlet id schemaStatusSplitView;
	IBOutlet id schema12SplitView;

	NSUserDefaults *prefs;
#endif
	NSMutableDictionary *schemaData;
	NSMutableDictionary *schemaDataFiltered;
	NSMutableDictionary *allSchemaKeys;
	NSMutableArray *infoArray;
	NSMutableArray *updatingConnections;
	NSMutableDictionary *expandStatus2;
	NSMutableDictionary *cachedSortedKeys;
#ifndef SP_REFACTOR /* ivars */
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
#endif	
}

+ (SPNavigatorController *)sharedNavigatorController;

#ifndef SP_REFACTOR /* method decls */
- (IBAction)outlineViewAction:(id)sender;
- (IBAction)reloadAllStructures:(id)sender;
- (IBAction)filterTree:(id)sender;
- (void)reloadAfterFiltering;
- (IBAction)syncButtonAction:(id)sender;

- (void)updateEntriesForConnection:(id)object;
- (NSString*)tableInfoLabelForIndex:(NSInteger)index ofType:(NSInteger)type;

- (void)updateNavigator:(NSNotification *)aNotification;
#endif

- (NSDictionary *)dbStructureForConnection:(NSString*)connectionID;
- (NSArray *)allSchemaKeysForConnection:(NSString*)connectionID;
- (NSArray *)getUniqueDbIdentifierFor:(NSString*)term andConnection:(NSString*)connectionID ignoreFields:(BOOL)ignoreFields;

#ifndef SP_REFACTOR /* method decls */
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
#endif

@end

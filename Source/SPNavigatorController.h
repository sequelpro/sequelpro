//
//  SPNavigatorController.h
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on March 17, 2010.
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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

@class SPNavigatorOutlineView, SPSplitView, SPDatabaseDocument;

@interface SPNavigatorController : NSWindowController 
{
#ifndef SP_CODA /* ivars */
	IBOutlet SPNavigatorOutlineView *outlineSchema2;
	IBOutlet id navigatorWindow;
	IBOutlet id infoTable;
	IBOutlet id searchField;
	IBOutlet NSButton *syncButton;

	IBOutlet SPSplitView *schemaStatusSplitView;
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
#ifndef SP_CODA /* ivars */
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

#ifndef SP_CODA /* method decls */
- (IBAction)outlineViewAction:(id)sender;
- (IBAction)reloadAllStructures:(id)sender;
- (IBAction)filterTree:(id)sender;
- (void)reloadAfterFiltering;
- (IBAction)syncButtonAction:(id)sender;

- (void)updateEntriesForConnection:(SPDatabaseDocument *)doc;
- (NSString*)tableInfoLabelForIndex:(NSInteger)index ofType:(SPTableType)type;

- (void)updateNavigator:(NSNotification *)aNotification;
#endif

- (NSDictionary *)dbStructureForConnection:(NSString*)connectionID;
- (NSArray *)allSchemaKeysForConnection:(NSString*)connectionID;
- (NSArray *)getUniqueDbIdentifierFor:(NSString*)term andConnection:(NSString*)connectionID ignoreFields:(BOOL)ignoreFields;

#ifndef SP_CODA /* method decls */
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

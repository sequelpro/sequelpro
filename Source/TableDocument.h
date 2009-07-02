//
//  $Id$
//
//  TableDocument.h
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  
//  Forked by Abhi Beckert (abhibeckert.com) 2008-04-04
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
#import <WebKit/WebKit.h>
#import "SPSSHTunnel.h"

/**
 * The TableDocument class controls the primary database view window.
 */
@interface TableDocument : NSDocument
{
	// IBOutlets
	IBOutlet id keyChainInstance;
	IBOutlet id tablesListInstance;
	IBOutlet id tableSourceInstance;
	IBOutlet id tableContentInstance;
	IBOutlet id tableRelationsInstance;
	IBOutlet id customQueryInstance;
	IBOutlet id tableDumpInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id extendedTableInfoInstance;
	IBOutlet id databaseDataInstance;
	IBOutlet id spExportControllerInstance;

	IBOutlet id tableWindow;
	
	IBOutlet id titleAccessoryView;
	IBOutlet id titleImageView;
	IBOutlet id titleStringView;
	
	IBOutlet id connectSheet;
	IBOutlet id databaseSheet;
	IBOutlet id variablesSheet;

	IBOutlet id queryProgressBar;
	IBOutlet id favoritesButton;
	IBOutlet NSTableView *connectFavoritesTableView;
	IBOutlet NSArrayController *favoritesController;
	IBOutlet id nameField;
	IBOutlet id hostField;
	IBOutlet id socketField;
	IBOutlet id userField;
	IBOutlet id passwordField;
	IBOutlet id portField;
	IBOutlet id databaseField;
	IBOutlet id sshCheckbox;
	IBOutlet id sshHostField;
	IBOutlet id sshUserField;
	IBOutlet id sshPasswordField;
	IBOutlet id sshPortField;
	IBOutlet NSWindow *errorDetailWindow;
	IBOutlet NSTextView *errorDetailText;

	IBOutlet NSProgressIndicator *connectProgressBar;
	IBOutlet NSTextField *connectProgressStatusText;
	IBOutlet id databaseNameField;
	IBOutlet id databaseEncodingButton;
	IBOutlet id addDatabaseButton;
	IBOutlet id chooseDatabaseButton;
	IBOutlet id variablesTableView;
	IBOutlet NSTabView *tableTabView;
	
	IBOutlet NSTableView *tableInfoTable;
	IBOutlet NSSplitView *tableListSplitter;
	IBOutlet NSSplitView *contentViewSplitter;
	IBOutlet id sidebarGrabber;
	
	IBOutlet NSTextView *customQueryTextView;
	
	IBOutlet NSTableView *dbTablesTableView;

	IBOutlet id syntaxView;
	IBOutlet id syntaxViewContent;
	IBOutlet NSWindow *createTableSyntaxWindow;

	MCPConnection *mySQLConnection;
	SPSSHTunnel *sshTunnel;

	NSArray *variables;
	NSString *selectedDatabase;
	NSString *mySQLVersion;
	NSUserDefaults *prefs;

	NSString *connectionKeychainItemName;
	NSString *connectionKeychainItemAccount;
	NSString *connectionSSHKeychainItemName;
	NSString *connectionSSHKeychainItemAccount;

	NSMenu *selectEncodingMenu;
	BOOL _supportsEncoding;
	NSString *_encoding;
	BOOL _encodingViaLatin1;
	BOOL _shouldOpenConnectionAutomatically;

	NSToolbar *mainToolbar;
	NSToolbarItem *chooseDatabaseToolbarItem;
	
	WebView *printWebView;
}

//start sheet
- (void)setShouldAutomaticallyConnect:(BOOL)shouldAutomaticallyConnect;
- (IBAction)connectToDB:(id)sender;
- (IBAction)initiateConnection:(id)sender;
- (void)initiateSSHTunnelConnection;
- (void)sshTunnelCallback:(SPSSHTunnel *)theTunnel;
- (void)initiateMySQLConnection;
- (void)failConnectionWithErrorMessage:(NSString *)theErrorMessage withDetail:(NSString *)errorDetail;
- (IBAction)cancelConnectSheet:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)chooseFavorite:(id)sender;
- (IBAction)toggleUseSSH:(id)sender;
- (IBAction)editFavorites:(id)sender;
- (id)selectedFavorite;
- (void)connectSheetAddToFavorites:(id)sender;
- (void)addToFavoritesName:(NSString *)name host:(NSString *)host socket:(NSString *)socket 
					  user:(NSString *)user password:(NSString *)password
					  port:(NSString *)port database:(NSString *)database
					useSSH:(BOOL)useSSH // no-longer in use
				   sshHost:(NSString *)sshHost // no-longer in use
				   sshUser:(NSString *)sshUser // no-longer in use
			   sshPassword:(NSString *)sshPassword // no-longer in use
				   sshPort:(NSString *)sshPort; // no-longer in use
- (IBAction)connectSheetShowHelp:(id)sender;

- (NSString *)getHTMLforPrint;

//connection getter
- (MCPConnection *)sharedConnection;

//database methods
- (IBAction)setDatabases:(id)sender;
- (IBAction)chooseDatabase:(id)sender;
- (IBAction)addDatabase:(id)sender;
- (IBAction)closeDatabaseSheet:(id)sender;
- (IBAction)removeDatabase:(id)sender;
- (IBAction)showMySQLHelp:(id)sender;
- (IBAction)saveServerVariables:(id)sender;

//encoding methods
- (void)setConnectionEncoding:(NSString *)mysqlEncoding reloadingViews:(BOOL)reloadViews;
- (NSString *)databaseEncoding;
- (NSString *)connectionEncoding;
- (BOOL)connectionEncodingViaLatin1;
- (IBAction)chooseEncoding:(id)sender;
- (BOOL)supportsEncoding;
- (void)updateEncodingMenuWithSelectedEncoding:(NSString *)encoding;
- (NSString *)encodingNameFromMySQLEncoding:(NSString *)mysqlEncoding;
- (NSString *)mysqlEncodingFromDisplayEncoding:(NSString *)encodingName;

//table methods
- (IBAction)showCreateTableSyntax:(id)sender;
- (IBAction)copyCreateTableSyntax:(id)sender;
- (NSArray *)columnNames;
- (IBAction)checkTable:(id)sender;
- (IBAction)analyzeTable:(id)sender;
- (IBAction)optimizeTable:(id)sender;
- (IBAction)repairTable:(id)sender;
- (IBAction)flushTable:(id)sender;
- (IBAction)checksumTable:(id)sender;

//other methods
- (NSString *)host;
- (void)doPerformQueryService:(NSString *)query;
- (void)flushPrivileges:(id)sender;
- (void)showVariables:(id)sender;
- (void)closeConnection;
- (NSWindow *)getCreateTableSyntaxWindow;
- (void) refreshCurrentDatabase;

//getter methods
- (NSString *)name;
- (NSString *)database;
- (NSString *)table;
- (NSString *)mySQLVersion;
- (NSString *)user;

//notification center methods
- (void)willPerformQuery:(NSNotification *)notification;
- (void)hasPerformedQuery:(NSNotification *)notification;
- (void)applicationWillTerminate:(NSNotification *)notification;
- (void)tunnelStatusChanged:(NSNotification *)notification;

//menu methods
- (BOOL)validateMenuItem:(NSMenuItem *)anItem;
- (IBAction)import:(id)sender;
- (IBAction)export:(id)sender;
- (IBAction)exportTable:(id)sender;
- (IBAction)exportMultipleTables:(id)sender;
- (IBAction)viewStructure:(id)sender;
- (IBAction)viewContent:(id)sender;
- (IBAction)viewQuery:(id)sender;
- (IBAction)viewStatus:(id)sender;
- (IBAction)viewRelations:(id)sender;
- (IBAction)addConnectionToFavorites:(id)sender;

// titlebar methods
- (void)setStatusIconToImageWithName:(NSString *)imagePath;
- (void)setTitlebarStatus:(NSString *)status;
- (void)clearStatusIcon;

//toolbar methods
- (void)setupToolbar;
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem;
- (void)updateChooseDatabaseToolbarItemWidth;

//SMySQL delegate methods
- (void)willQueryString:(NSString *)query;
- (void)queryGaveError:(NSString *)error;

@end

extern NSString *TableDocumentFavoritesControllerSelectionIndexDidChange;
extern NSString *TableDocumentFavoritesControllerFavoritesDidChange;

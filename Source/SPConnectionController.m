//
//  SPConnectionController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 15, 2010.
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

#import "SPConnectionController.h"
#import "SPDatabaseDocument.h"
#ifndef SP_CODA /* headers */
#import "SPAppController.h"
#import "SPPreferenceController.h"
#import "ImageAndTextCell.h"
#import "RegexKitLite.h"
#endif
#import "SPAlertSheets.h"
#import "SPKeychain.h"
#import "SPSSHTunnel.h"
#import "SPTableTextFieldCell.h"
#import "SPFavoritesController.h"
#import "SPFavoriteNode.h"
#import "SPGeneralPreferencePane.h"
#import "SPTreeNode.h"
#import "SPFavoritesExporter.h"
#import "SPFavoritesImporter.h"
#import "SPThreadAdditions.h"
#import "SPFavoriteColorSupport.h"
#import "SPNamedNode.h"
#import "SPWindowController.h"
#import "SPFavoritesOutlineView.h"
#import "SPCategoryAdditions.h"
#ifndef SP_CODA
#import "SPFavoriteTextFieldCell.h"
#import "SPGroupNode.h"
#endif
#import "SPSplitView.h"
#import "SPColorSelectorView.h"
#import "SPFunctions.h"

#import <SPMySQL/SPMySQL.h>

// Constants
#ifndef SP_CODA
static NSString *SPRemoveNode              = @"RemoveNode";
static NSString *SPExportFavoritesFilename = @"SequelProFavorites.plist";
static NSString *SPLocalhostAddress        = @"127.0.0.1";

static NSString *SPDatabaseImage           = @"database-small";
static NSString *SPQuickConnectImage       = @"quick-connect-icon.pdf";
static NSString *SPQuickConnectImageWhite  = @"quick-connect-icon-white.pdf";

static NSString *SPConnectionViewNibName   = @"ConnectionView";
#endif

/**
 * This is a utility function to validate SSL key/certificate files
 * @param fileData   The contents of the file
 * @param first      Buffer with Data that has to occur on a line
 * @param first_len  Length of first
 * @param second     Buffer with Data that has to occur on a line after first
 * @param second_len Length of second
 * @return True if file contains two lines matching first and second and second comes after first
 */
static BOOL FindLinesInFile(NSData *fileData,const void *first,size_t first_len,const void *second,size_t second_len);

static BOOL isOSAtLeast10_7;

@interface SPConnectionController ()

// Privately redeclare as read/write to get the synthesized setter
@property (readwrite, assign) BOOL isEditingConnection;

- (void)_saveCurrentDetailsCreatingNewFavorite:(BOOL)createNewFavorite validateDetails:(BOOL)validateDetails;
- (BOOL)_checkHost;
#ifndef SP_CODA
- (void)_sortFavorites;
- (void)_sortTreeNode:(SPTreeNode *)node usingKey:(NSString *)key;
- (void)_favoriteTypeDidChange;
- (void)_reloadFavoritesViewData;
- (void)_updateFavoriteFirstResponder;
- (void)_restoreConnectionInterface;
- (void)_selectNode:(SPTreeNode *)node;
- (void)_scrollToSelectedNode;
- (void)_removeNode:(SPTreeNode *)node;
- (void)_removeAllPasswordsForNode:(SPTreeNode *)node;

- (NSNumber *)_createNewFavoriteID;
- (SPTreeNode *)_favoriteNodeForFavoriteID:(NSInteger)favoriteID;
- (NSString *)_stripInvalidCharactersFromString:(NSString *)subject;

- (NSString *)_generateNameForConnection;

- (void)_startEditingConnection;

- (void)_documentWillClose:(NSNotification *)notification;

static NSComparisonResult _compareFavoritesUsingKey(id favorite1, id favorite2, void *key);
#endif

#pragma mark - SPConnectionControllerDelegate

- (void)_stopEditingConnection;

#pragma mark - SPConnectionHandlerPrivateAPI

- (void)_showConnectionTestResult:(NSString *)resultString;

#pragma mark - SPConnectionControllerDelegate_Private_API

- (void)_setNodeIsExpanded:(BOOL)expanded fromNotification:(NSNotification *)notification;

#pragma mark - SPConnectionControllerInitializer_Private_API

- (void)_restoreOutlineViewStateNode:(SPTreeNode *)node;
- (void)_processFavoritesDataChange:(NSNotification *)aNotification;
- (void)scrollViewFrameChanged:(NSNotification *)aNotification;

@end

@implementation SPConnectionController

@synthesize delegate;
@synthesize type;
@synthesize name;
@synthesize host;
@synthesize user;
@synthesize password;
@synthesize database;
@synthesize socket;
@synthesize port;
@synthesize colorIndex;
@synthesize useSSL;
@synthesize sslKeyFileLocationEnabled;
@synthesize sslKeyFileLocation;
@synthesize sslCertificateFileLocationEnabled;
@synthesize sslCertificateFileLocation;
@synthesize sslCACertFileLocationEnabled;
@synthesize sslCACertFileLocation;
@synthesize sshHost;
@synthesize sshUser;
@synthesize sshPassword;
@synthesize sshKeyLocationEnabled;
@synthesize sshKeyLocation;
@synthesize sshPort;
@synthesize useCompression;

#ifdef SP_CODA
@synthesize dbDocument;
#endif

@synthesize connectionKeychainID = connectionKeychainID;
@synthesize connectionKeychainItemName;
@synthesize connectionKeychainItemAccount;
@synthesize connectionSSHKeychainItemName;
@synthesize connectionSSHKeychainItemAccount;

@synthesize isConnecting;
@synthesize isEditingConnection;

+ (void)initialize {
	isOSAtLeast10_7 = [SPOSInfo isOSVersionAtLeastMajor:10 minor:7 patch:0];
}

- (NSString *)keychainPassword
{
	NSString *kcItemName = [self connectionKeychainItemName];
	// If no keychain item is available, return an empty password
	if (!kcItemName) return nil;

	// Otherwise, pull the password from the keychain using the details from this connection
	NSString *kcPassword = [keychain getPasswordForName:kcItemName account:[self connectionKeychainItemAccount]];

	return kcPassword;
}

- (NSString *)keychainPasswordForSSH
{
	if (![self connectionKeychainItemName]) return nil;

	// Otherwise, pull the password from the keychain using the details from this connection
	NSString *kcSSHPassword = [keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount];

	return kcSSHPassword;
}

#pragma mark -
#pragma mark Connection processes

/**
 * Starts the connection process; invoked when user hits the connect button
 * or double-clicks on a favourite.
 * Error-checks fields as required, and triggers connection of MySQL or any
 * connection proxies in use.
 */
- (IBAction)initiateConnection:(id)sender
{
	// If this action was triggered via a double-click on the favorites outline view,
	// ensure that one of the connections was double-clicked, not the area above or below
#ifndef SP_CODA
	if (sender == favoritesOutlineView && [favoritesOutlineView clickedRow] <= 0) return;
#endif
	
	// If triggered via the "Test Connection" button, set the state - otherwise clear it
	isTestingConnection = (sender == testConnectButton);

	// Ensure that host is not empty if this is a TCP/IP or SSH connection
	if (([self type] == SPTCPIPConnection || [self type] == SPSSHTunnelConnection) && ![[self host] length]) {
		SPOnewayAlertSheet(
			NSLocalizedString(@"Insufficient connection details", @"insufficient details message"),
			[dbDocument parentWindow],
			NSLocalizedString(@"Insufficient details provided to establish a connection. Please enter at least the hostname.", @"insufficient details informative message")
		);
		return;
	}

	// If SSH is enabled, ensure that the SSH host is not nil
	if ([self type] == SPSSHTunnelConnection && ![[self sshHost] length]) {
		SPOnewayAlertSheet(
			NSLocalizedString(@"Insufficient connection details", @"insufficient details message"),
			[dbDocument parentWindow],
			NSLocalizedString(@"Insufficient details provided to establish a connection. Please enter the hostname for the SSH Tunnel, or disable the SSH Tunnel.", @"insufficient SSH tunnel details informative message")
		);
		return;
	}

	// If an SSH key has been provided, verify it exists
	if ([self type] == SPSSHTunnelConnection && sshKeyLocationEnabled && sshKeyLocation) {
		if (![[NSFileManager defaultManager] fileExistsAtPath:[sshKeyLocation stringByExpandingTildeInPath]]) {
			[self setSshKeyLocationEnabled:NSOffState];
			SPOnewayAlertSheet(
				NSLocalizedString(@"SSH Key not found", @"SSH key check error"),
				[dbDocument parentWindow],
				NSLocalizedString(@"A SSH key location was specified, but no file was found in the specified location.  Please re-select the key and try again.", @"SSH key not found message")
			);
			return;
		}
	}

	// Ensure that a socket connection is not inadvertently used
	if (![self _checkHost]) return;

	// If SSL keys have been supplied, verify they exist
	if (([self type] == SPTCPIPConnection || [self type] == SPSocketConnection) && [self useSSL]) {
		
		if (sslKeyFileLocationEnabled && sslKeyFileLocation && 
			![[NSFileManager defaultManager] fileExistsAtPath:[sslKeyFileLocation stringByExpandingTildeInPath]])
		{
			[self setSslKeyFileLocationEnabled:NSOffState];
			[self setSslKeyFileLocation:nil];
			
			SPOnewayAlertSheet(
				NSLocalizedString(@"SSL Key File not found", @"SSL key file check error"),
				[dbDocument parentWindow],
				NSLocalizedString(@"A SSL key file location was specified, but no file was found in the specified location.  Please re-select the key file and try again.", @"SSL key file not found message")
			);
			
			return;
		}
		
		if (sslCertificateFileLocationEnabled && sslCertificateFileLocation && 
			![[NSFileManager defaultManager] fileExistsAtPath:[sslCertificateFileLocation stringByExpandingTildeInPath]])
		{
			[self setSslCertificateFileLocationEnabled:NSOffState];
			[self setSslCertificateFileLocation:nil];
			
			SPOnewayAlertSheet(
				NSLocalizedString(@"SSL Certificate File not found", @"SSL certificate file check error"),
				[dbDocument parentWindow],
				NSLocalizedString(@"A SSL certificate location was specified, but no file was found in the specified location.  Please re-select the certificate and try again.", @"SSL certificate file not found message")
			);
			
			return;
		}
		
		if (sslCACertFileLocationEnabled && sslCACertFileLocation && 
			![[NSFileManager defaultManager] fileExistsAtPath:[sslCACertFileLocation stringByExpandingTildeInPath]])
		{
			[self setSslCACertFileLocationEnabled:NSOffState];
			[self setSslCACertFileLocation:nil];
			
			SPOnewayAlertSheet(
				NSLocalizedString(@"SSL Certificate Authority File not found", @"SSL certificate authority file check error"),
				[dbDocument parentWindow],
				NSLocalizedString(@"A SSL Certificate Authority certificate location was specified, but no file was found in the specified location.  Please re-select the Certificate Authority certificate and try again.", @"SSL CA certificate file not found message")
			);
			
			return;
		}
	}

	// Basic details have validated - start the connection process animating
	isConnecting = YES;
	cancellingConnection = NO;

#ifndef SP_CODA
	// Disable the favorites outline view to prevent further connections attempts
	[favoritesOutlineView setEnabled:NO];

	[helpButton setHidden:YES];
	[connectButton setEnabled:NO];
	[testConnectButton setEnabled:NO];
	[progressIndicator startAnimation:self];
	[progressIndicatorText setHidden:NO];
#endif
	
	// Start the current tab's progress indicator
	[dbDocument setIsProcessing:YES];

	// If the password(s) are marked as having been originally sourced from a keychain, check whether they
	// have been changed or not; if not, leave the mark in place and remove the password from the field
	// for increased security.
#ifndef SP_CODA
	if (connectionKeychainItemName && !isTestingConnection) {
		if ([[keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount] isEqualToString:[self password]]) {
			[self setPassword:[[NSString string] stringByPaddingToLength:[[self password] length] withString:@"sp" startingAtIndex:0]];
			
			[[standardPasswordField undoManager] removeAllActionsWithTarget:standardPasswordField];
			[[socketPasswordField undoManager] removeAllActionsWithTarget:socketPasswordField];
			[[sshPasswordField undoManager] removeAllActionsWithTarget:sshPasswordField];
		} 
		else {
			SPClear(connectionKeychainItemName);
			SPClear(connectionKeychainItemAccount);
		}
	}
	
	if (connectionSSHKeychainItemName && !isTestingConnection) {
		if ([[keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount] isEqualToString:[self sshPassword]]) {
			[self setSshPassword:[[NSString string] stringByPaddingToLength:[[self sshPassword] length] withString:@"sp" startingAtIndex:0]];
			[[sshSSHPasswordField undoManager] removeAllActionsWithTarget:sshSSHPasswordField];
		} 
		else {
			SPClear(connectionSSHKeychainItemName);
			SPClear(connectionSSHKeychainItemAccount);
		}
	}
#endif

	// Inform the delegate that we are starting the connection process
	if (delegate && [delegate respondsToSelector:@selector(connectionControllerInitiatingConnection:)]) {
		[delegate connectionControllerInitiatingConnection:self];
	}

	// Trim whitespace and newlines from the host field before attempting to connect
	[self setHost:[[self host] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];

	// Initiate the SSH connection process for tunnels
	if ([self type] == SPSSHTunnelConnection) {
		[self performSelector:@selector(initiateSSHTunnelConnection) withObject:nil afterDelay:0.0];
		
		return;
	}

	// ...or start the MySQL connection process directly
	[self performSelector:@selector(initiateMySQLConnection) withObject:nil afterDelay:0.0];
}

/**
 * Cancels the current connection - both SSH and MySQL.
 */
- (IBAction)cancelConnection:(id)sender
{
#ifndef SP_CODA
	[connectButton setEnabled:NO];

	[progressIndicatorText setStringValue:NSLocalizedString(@"Cancelling...", @"cancelling task status message")];
	[progressIndicatorText display];
#endif

	cancellingConnection = YES;

	// Cancel the MySQL connection - handing it off to a background thread - if one is present
	if (mySQLConnection) {
		[mySQLConnection setDelegate:nil];
		[NSThread detachNewThreadWithName:SPCtxt(@"SPConnectionController cancellation background disconnect",dbDocument) target:mySQLConnection selector:@selector(disconnect) object:nil];
		[mySQLConnection autorelease];
		mySQLConnection = nil;
	}

	// Cancel the SSH tunnel if present
	if (sshTunnel) {
		[sshTunnel disconnect];
		SPClear(sshTunnel);
	}

#ifndef SP_CODA
	// Restore the connection interface
	[self _restoreConnectionInterface];
#endif
}

#ifdef SP_CODA
- (BOOL)cancellingConnection
{
	return cancellingConnection;
}
#endif


#pragma mark -
#pragma mark Interface interaction

/**
 * Registered to be the double click action of the favorites outline view.
 */
- (void)nodeDoubleClicked:(id)sender
{
#ifndef SP_CODA
	SPTreeNode *node = [favoritesOutlineView itemForDoubleAction];
		
	if (node) {
		if (node == quickConnectItem) {
			return;
		}

		// Only proceed to initiate a connection if a leaf node (i.e. a favorite and not a group) was double clicked.
		if (![node isGroup]) {
			[self initiateConnection:self];
		} 

		// Otherwise start editing the group node's name
		else {
			[favoritesOutlineView editColumn:0 row:[favoritesOutlineView selectedRow] withEvent:nil select:YES];
		}
	}
#endif
}

/**
 * Opens the SSH/SSL key selection window, ready to select a key file.
 */
- (IBAction)chooseKeyLocation:(NSButton *)sender
{
#ifndef SP_CODA
	NSString *directoryPath = nil;
	NSString *filePath = nil;
	NSView *accessoryView = nil;

	// If the button was toggled off, ensure editing is ended
	if ([sender state] == NSOffState) {
		[self _startEditingConnection];
	}

	// Switch details by sender.
	// First, SSH keys:
	if (sender == sshSSHKeyButton) {

		// If the custom key location is currently disabled - after the button
		// action - leave it disabled and return without showing the sheet.
		if (!sshKeyLocationEnabled) {
			return;
		}

		// Otherwise open a panel at the last or default location
		if (sshKeyLocation && [sshKeyLocation length]) {
			filePath = [sshKeyLocation lastPathComponent];
			directoryPath = [sshKeyLocation stringByDeletingLastPathComponent];
		}

		accessoryView = sshKeyLocationHelp;
	}
	// SSL key file location:
	else if (sender == standardSSLKeyFileButton || sender == socketSSLKeyFileButton || sender == sslOverSSHKeyFileButton) {
		if ([sender state] == NSOffState) {
			[self setSslKeyFileLocation:nil];
			return;
		}
		
		accessoryView = sslKeyFileLocationHelp;
	}
	// SSL certificate file location:
	else if (sender == standardSSLCertificateButton || sender == socketSSLCertificateButton || sender == sslOverSSHCertificateButton) {
		if ([sender state] == NSOffState) {
			[self setSslCertificateFileLocation:nil];
			return;
		}
		
		accessoryView = sslCertificateLocationHelp;
	}
	// SSL CA certificate file location:
	else if (sender == standardSSLCACertButton || sender == socketSSLCACertButton || sender == sslOverSSHCACertButton) {
		if ([sender state] == NSOffState) {
			[self setSslCACertFileLocation:nil];
			return;
		}
		
		accessoryView = sslCACertLocationHelp;
	}
	
	keySelectionPanel = [[NSOpenPanel openPanel] retain]; // retain/release needed on OS X ≤ 10.6 according to Apple doc
	[keySelectionPanel setShowsHiddenFiles:[prefs boolForKey:SPHiddenKeyFileVisibilityKey]];
	[keySelectionPanel setAccessoryView:accessoryView];
	//on os x 10.11+ the accessory view will be hidden by default and has to be made visible
	if(accessoryView && [keySelectionPanel respondsToSelector:@selector(setAccessoryViewDisclosed:)]) {
		[keySelectionPanel setAccessoryViewDisclosed:YES];
	}
	[keySelectionPanel setDelegate:self];
	[keySelectionPanel beginSheetModalForWindow:[dbDocument parentWindow] completionHandler:^(NSInteger returnCode)
	{
		NSString *abbreviatedFileName = [[[keySelectionPanel URL] path] stringByAbbreviatingWithTildeInPath];
		
		//delay the release so it won't happen while this block is still executing.
		dispatch_async(dispatch_get_current_queue(), ^{
			SPClear(keySelectionPanel);
		});

		// SSH key file selection
		if (sender == sshSSHKeyButton) {
			if (returnCode == NSCancelButton) {
				[self setSshKeyLocationEnabled:NSOffState];
				return;
			}

			[self setSshKeyLocation:abbreviatedFileName];
		}
		// SSL key file selection
		else if (sender == standardSSLKeyFileButton || sender == socketSSLKeyFileButton || sender == sslOverSSHKeyFileButton) {
			if (returnCode == NSCancelButton) {
				[self setSslKeyFileLocationEnabled:NSOffState];
				[self setSslKeyFileLocation:nil];
				return;
			}

			[self setSslKeyFileLocation:abbreviatedFileName];
		}
		// SSL certificate file selection
		else if (sender == standardSSLCertificateButton || sender == socketSSLCertificateButton || sender == sslOverSSHCertificateButton) {
			if (returnCode == NSCancelButton) {
				[self setSslCertificateFileLocationEnabled:NSOffState];
				[self setSslCertificateFileLocation:nil];
				return;
			}

			[self setSslCertificateFileLocation:abbreviatedFileName];
		}
		// SSL CA certificate file selection
		else if (sender == standardSSLCACertButton || sender == socketSSLCACertButton || sender == sslOverSSHCACertButton) {
			if (returnCode == NSCancelButton) {
				[self setSslCACertFileLocationEnabled:NSOffState];
				[self setSslCACertFileLocation:nil];
				return;
			}

			[self setSslCACertFileLocation:abbreviatedFileName];
		}
		
		[self _startEditingConnection];
	}];
#endif
}

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError
{
	// mysql limits yaSSL to PEM format files (it would support DER)
	if([keySelectionPanel accessoryView] == sslKeyFileLocationHelp) {
		// and yaSSL only supports RSA type keys, with the exact string below on a single line
		NSError *err = nil;
		NSData *file = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:&err];
		if(err) {
			*outError = err;
			return NO;
		}

		// see PemToDer() in crypto_wrapper.cpp in yaSSL
		const char rsaHead[] = "-----BEGIN RSA PRIVATE KEY-----";
		const char rsaFoot[] = "-----END RSA PRIVATE KEY-----";
		
		if(FindLinesInFile(file, rsaHead, strlen(rsaHead), rsaFoot, strlen(rsaFoot)))
			return YES;

		*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:@{
			NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"“%@” is not a valid private key file.", @"connection view : ssl : key file picker : wrong format error title"),[url lastPathComponent]],
			NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Make sure the file contains a RSA private key and is using PEM encoding.", @"connection view : ssl : key file picker : wrong format error description"),
			NSURLErrorKey: url
		}];
		return NO;
	}
	else if([keySelectionPanel accessoryView] == sslCertificateLocationHelp) {
		NSError *err = nil;
		NSData *file = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:&err];
		if(err) {
			*outError = err;
			return NO;
		}
		
		// see PemToDer() in crypto_wrapper.cpp in yaSSL
		const char cerHead[] = "-----BEGIN CERTIFICATE-----";
		const char cerFoot[] = "-----END CERTIFICATE-----";
		
		if(FindLinesInFile(file, cerHead, strlen(cerHead), cerFoot, strlen(cerFoot)))
			return YES;
		
		*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:@{
			NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"“%@” is not a valid client certificate file.", @"connection view : ssl : client cert file picker : wrong format error title"),[url lastPathComponent]],
			NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Make sure the file contains a X.509 client certificate and is using PEM encoding.", @"connection view : ssl : client cert picker : wrong format error description"),
			NSURLErrorKey: url
		}];
		return NO;
	}
	//unknown, accept by default
	return YES;
	
	/* And now, an intermission from the mysql source code:
	 
  if (!cert_file &&  key_file)
	 cert_file= key_file;
  
  if (!key_file &&  cert_file)
	 key_file= cert_file;

	 */
}

/**
 * Show connection help webpage.
 */
- (IBAction)showHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SPLOCALIZEDURL_CONNECTIONHELP]];
}

/**
 * Resize parts of the interface to reflect SSL status.
 */
- (IBAction)updateSSLInterface:(id)sender
{
#ifndef SP_CODA
	[self _startEditingConnection];
	[self resizeTabViewToConnectionType:[self type] animating:YES];
#endif
}

/**
 * Toggle hidden file visiblity in response to accessory view changes
 */
- (IBAction)updateKeyLocationFileVisibility:(id)sender
{
	[keySelectionPanel setShowsHiddenFiles:[prefs boolForKey:SPHiddenKeyFileVisibilityKey]];
}

/**
 * Update the interface in response to external split view size changes.
 */
- (void)updateSplitViewSize
{
#ifndef SP_CODA
	if ([dbDocument getConnection]) {
		return;
	}

	[connectionSplitView setDelegate:nil];
	[connectionSplitView setPosition:[[[databaseConnectionView subviews] objectAtIndex:0] frame].size.width ofDividerAtIndex:0];
	[connectionSplitView setDelegate:self];
#endif
}

#pragma mark -
#pragma mark Connection details interaction and display

/**
 * Control tab view resizing based on the supplied connection type,
 * with an option defining whether it should be animated or not.
 */
- (void)resizeTabViewToConnectionType:(NSUInteger)theType animating:(BOOL)animate
{
	NSRect frameRect, targetResizeRect;

	// Use a magic number which needs to be added to the form when calculating resizes -
	// including the height of the button areas below.
	NSInteger additionalFormHeight = 92;

	frameRect = [connectionResizeContainer frame];

	switch (theType) {
		case SPTCPIPConnection:
			targetResizeRect = [standardConnectionFormContainer frame];
			if ([self useSSL]) additionalFormHeight += [standardConnectionSSLDetailsContainer frame].size.height;
			break;
		case SPSocketConnection:
			targetResizeRect = [socketConnectionFormContainer frame];
			if ([self useSSL]) additionalFormHeight += [socketConnectionSSLDetailsContainer frame].size.height;
			break;
		case SPSSHTunnelConnection:
			targetResizeRect = [sshConnectionFormContainer frame];
			if ([self useSSL]) additionalFormHeight += [sshConnectionSSLDetailsContainer frame].size.height;
			break;
	}

	frameRect.size.height = targetResizeRect.size.height + additionalFormHeight;

	if (animate && initComplete) {
		[[connectionResizeContainer animator] setFrame:frameRect];
	} 
	else {
		[connectionResizeContainer setFrame:frameRect];
	}
}

#pragma mark -
#pragma mark Favorites interaction

/**
 * Sorts the favorites table view based on the selected sort by item.
 */
- (void)sortFavorites:(id)sender
{
#ifndef SP_CODA
    SPFavoritesSortItem previousSortItem = currentSortItem;
	currentSortItem  = (SPFavoritesSortItem)[[sender menu] indexOfItem:sender];

	[prefs setInteger:currentSortItem forKey:SPFavoritesSortedBy];

	// Perform sorting
	[self _sortFavorites];

	if (previousSortItem > SPFavoritesSortUnsorted) [[[sender menu] itemAtIndex:previousSortItem] setState:NSOffState];

	[[[sender menu] itemAtIndex:currentSortItem] setState:NSOnState];
#endif
}

/**
 * Reverses the favorites table view sorting based on the selected criteria.
 */
- (void)reverseSortFavorites:(NSMenuItem *)sender
{
#ifndef SP_CODA
	reverseFavoritesSort = (![sender state]);

	[prefs setBool:reverseFavoritesSort forKey:SPFavoritesSortedInReverse];

	// Perform re-sorting
	[self _sortFavorites];

	[sender setState:reverseFavoritesSort];
#endif
}

/**
 * Sets fields for the chosen favorite.
 */
- (void)updateFavoriteSelection:(id)sender
{
#ifndef SP_CODA

	// Clear the keychain referral items as appropriate
	[self setConnectionKeychainID:nil];
	if (connectionKeychainItemName) SPClear(connectionKeychainItemName);
	if (connectionKeychainItemAccount) SPClear(connectionKeychainItemAccount);
	if (connectionSSHKeychainItemName) SPClear(connectionSSHKeychainItemName);
	if (connectionSSHKeychainItemAccount) SPClear(connectionSSHKeychainItemAccount);

	SPTreeNode *node = [self selectedFavoriteNode];
	if ([node isGroup]) node = nil;
	
	// Update key-value properties from the selected favourite, using empty strings where not found
	NSDictionary *fav = [[node representedObject] nodeFavorite];
	
	// Keep a copy of the favorite as it currently stands
	if (currentFavorite) SPClear(currentFavorite);
	currentFavorite = [fav copy];
	
	[connectionResizeContainer setHidden:NO];
	[self _stopEditingConnection];

	// Set up the type, also storing it in the previous type store to prevent type "changes" triggering actions
	NSUInteger connectionType = ([fav objectForKey:SPFavoriteTypeKey] ? [[fav objectForKey:SPFavoriteTypeKey] integerValue] : SPTCPIPConnection);
	previousType = connectionType;
	[self setType:connectionType];

	// Standard details
	[self setName:([fav objectForKey:SPFavoriteNameKey] ? [fav objectForKey:SPFavoriteNameKey] : @"")];
	[self setHost:([fav objectForKey:SPFavoriteHostKey] ? [fav objectForKey:SPFavoriteHostKey] : @"")];
	[self setSocket:([fav objectForKey:SPFavoriteSocketKey] ? [fav objectForKey:SPFavoriteSocketKey] : @"")];
	[self setUser:([fav objectForKey:SPFavoriteUserKey] ? [fav objectForKey:SPFavoriteUserKey] : @"")];
	[self setColorIndex:([fav objectForKey:SPFavoriteColorIndexKey]? [[fav objectForKey:SPFavoriteColorIndexKey] integerValue] : -1)];
	[self setPort:([fav objectForKey:SPFavoritePortKey] ? [fav objectForKey:SPFavoritePortKey] : @"")];
	[self setDatabase:([fav objectForKey:SPFavoriteDatabaseKey] ? [fav objectForKey:SPFavoriteDatabaseKey] : @"")];
	[self setUseCompression:([fav objectForKey:SPFavoriteUseCompressionKey] ? [[fav objectForKey:SPFavoriteUseCompressionKey] boolValue] : YES)];
	
	// SSL details
	[self setUseSSL:([fav objectForKey:SPFavoriteUseSSLKey] ? [[fav objectForKey:SPFavoriteUseSSLKey] intValue] : NSOffState)];
	[self setSslKeyFileLocationEnabled:([fav objectForKey:SPFavoriteSSLKeyFileLocationEnabledKey] ? [[fav objectForKey:SPFavoriteSSLKeyFileLocationEnabledKey] intValue] : NSOffState)];
	[self setSslKeyFileLocation:([fav objectForKey:SPFavoriteSSLKeyFileLocationKey] ? [fav objectForKey:SPFavoriteSSLKeyFileLocationKey] : @"")];
	[self setSslCertificateFileLocationEnabled:([fav objectForKey:SPFavoriteSSLCertificateFileLocationEnabledKey] ? [[fav objectForKey:SPFavoriteSSLCertificateFileLocationEnabledKey] intValue] : NSOffState)];
	[self setSslCertificateFileLocation:([fav objectForKey:SPFavoriteSSLCertificateFileLocationKey] ? [fav objectForKey:SPFavoriteSSLCertificateFileLocationKey] : @"")];
	[self setSslCACertFileLocationEnabled:([fav objectForKey:SPFavoriteSSLCACertFileLocationEnabledKey] ? [[fav objectForKey:SPFavoriteSSLCACertFileLocationEnabledKey] intValue] : NSOffState)];
	[self setSslCACertFileLocation:([fav objectForKey:SPFavoriteSSLCACertFileLocationKey] ? [fav objectForKey:SPFavoriteSSLCACertFileLocationKey] : @"")];

	// SSH details
	[self setSshHost:([fav objectForKey:SPFavoriteSSHHostKey] ? [fav objectForKey:SPFavoriteSSHHostKey] : @"")];
	[self setSshUser:([fav objectForKey:SPFavoriteSSHUserKey] ? [fav objectForKey:SPFavoriteSSHUserKey] : @"")];
	[self setSshKeyLocationEnabled:([fav objectForKey:SPFavoriteSSHKeyLocationEnabledKey] ? [[fav objectForKey:SPFavoriteSSHKeyLocationEnabledKey] intValue] : NSOffState)];
	[self setSshKeyLocation:([fav objectForKey:SPFavoriteSSHKeyLocationKey] ? [fav objectForKey:SPFavoriteSSHKeyLocationKey] : @"")];
	[self setSshPort:([fav objectForKey:SPFavoriteSSHPortKey] ? [fav objectForKey:SPFavoriteSSHPortKey] : @"")];

	// Trigger an interface update
	[self resizeTabViewToConnectionType:[self type] animating:(sender == self)];

	// Check whether the password exists in the keychain, and if so add it; also record the
	// keychain details so we can pass around only those details if the password doesn't change
	connectionKeychainItemName = [[keychain nameForFavoriteName:[fav objectForKey:SPFavoriteNameKey] id:[fav objectForKey:SPFavoriteIDKey]] retain];
	connectionKeychainItemAccount = [[keychain accountForUser:[fav objectForKey:SPFavoriteUserKey] host:(([self type] == SPSocketConnection) ? @"localhost" : [fav objectForKey:SPFavoriteHostKey]) database:[fav objectForKey:SPFavoriteDatabaseKey]] retain];

	[self setPassword:[keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount]];

	if (![[self password] length]) {
		[self setPassword:nil];
		SPClear(connectionKeychainItemName);
		SPClear(connectionKeychainItemAccount);
	}

	// Store the selected favorite ID for use with the document on connection
	if ([fav objectForKey:SPFavoriteIDKey]) [self setConnectionKeychainID:[[fav objectForKey:SPFavoriteIDKey] stringValue]];

	// And the same for the SSH password
	connectionSSHKeychainItemName = [[keychain nameForSSHForFavoriteName:[fav objectForKey:SPFavoriteNameKey] id:[fav objectForKey:SPFavoriteIDKey]] retain];
	connectionSSHKeychainItemAccount = [[keychain accountForSSHUser:[fav objectForKey:SPFavoriteSSHUserKey] sshHost:[fav objectForKey:SPFavoriteSSHHostKey]] retain];

	[self setSshPassword:[keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount]];

	if (![[self sshPassword] length]) {
		[self setSshPassword:nil];
		SPClear(connectionSSHKeychainItemName);
		SPClear(connectionSSHKeychainItemAccount);
	}

	[prefs setInteger:[[fav objectForKey:SPFavoriteIDKey] integerValue] forKey:SPLastFavoriteID];

	[self updateFavoriteNextKeyView];
#endif
}
	
/**
 * Set the next KeyView to password field if the password is empty
 */
- (void)updateFavoriteNextKeyView
{
#ifndef SP_CODA
	switch ([self type])
	{
		case SPTCPIPConnection:
			[favoritesOutlineView setNextKeyView:(![[standardPasswordField stringValue] length]) ? standardPasswordField : standardNameField];
			break;
		case SPSocketConnection:
			[favoritesOutlineView setNextKeyView:(![[socketPasswordField stringValue] length]) ? socketPasswordField : socketNameField];
			break;
		case SPSSHTunnelConnection:
			if (![[sshPasswordField stringValue] length]) {
				[favoritesOutlineView setNextKeyView:sshPasswordField];
			}
			else if (![[sshSSHPasswordField stringValue] length]) {
				[favoritesOutlineView setNextKeyView:sshSSHPasswordField];
			}
			else {
				[favoritesOutlineView setNextKeyView:sshNameField];
			}
			break;
	}
#endif
}

/**
 * Returns the selected favorite data dictionary or nil if nothing is selected.
 */
#ifndef SP_CODA
- (NSMutableDictionary *)selectedFavorite
{
	SPTreeNode *node = [self selectedFavoriteNode];
	
	return (![node isGroup]) ? [(SPFavoriteNode *)[node representedObject] nodeFavorite] : nil;
}

/**
 * Returns the selected favorite node or nil if nothing is selected.
 */
- (SPTreeNode *)selectedFavoriteNode
{
	NSArray *nodes = [self selectedFavoriteNodes];
	
	return (SPTreeNode *)[nodes objectOrNilAtIndex:0];
}

/**
 * Returns an array of selected favorite nodes.
 */
- (NSArray *)selectedFavoriteNodes
{
	NSMutableArray *nodes = [NSMutableArray array];
	NSIndexSet *indexes = [favoritesOutlineView selectedRowIndexes];

	[indexes enumerateIndexesUsingBlock:^(NSUInteger currentIndex, BOOL * _Nonnull stop) {
		[nodes addObject:[favoritesOutlineView itemAtRow:currentIndex]];
	}];

	return nodes;
}

/**
 * Saves the current connection favorite.
 */
- (IBAction)saveFavorite:(id)sender
{
	[self _saveCurrentDetailsCreatingNewFavorite:NO validateDetails:YES];
}

/**
 * Adds a new connection favorite.
 */
- (IBAction)addFavorite:(id)sender
{
	NSNumber *favoriteID = [self _createNewFavoriteID];
	
	NSArray *objects = @[
		NSLocalizedString(@"New Favorite", @"new favorite name"),
		@0,
		@"",
		@"",
		@"",
		@(-1),
		@"",
		@(NSOffState),
		@(NSOffState),
		@(NSOffState),
		@(NSOffState),
		@"",
		@"",
		@"",
		@(NSOffState),
		@"",
		@"",
		favoriteID
	];
	
	NSArray *keys = @[
		SPFavoriteNameKey,
		SPFavoriteTypeKey,
		SPFavoriteHostKey,
		SPFavoriteSocketKey,
		SPFavoriteUserKey,
		SPFavoriteColorIndexKey,
		SPFavoritePortKey,
		SPFavoriteUseSSLKey,
		SPFavoriteSSLKeyFileLocationEnabledKey,
		SPFavoriteSSLCertificateFileLocationEnabledKey,
		SPFavoriteSSLCACertFileLocationEnabledKey,
		SPFavoriteDatabaseKey,
		SPFavoriteSSHHostKey,
		SPFavoriteSSHUserKey,
		SPFavoriteSSHKeyLocationEnabledKey,
		SPFavoriteSSHKeyLocationKey,
		SPFavoriteSSHPortKey,
		SPFavoriteIDKey
	];

	// Create default favorite
	NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithObjects:objects forKeys:keys];

	SPTreeNode *selectedNode = [self selectedFavoriteNode];
	
	SPTreeNode *parent = ([selectedNode isGroup] && selectedNode != quickConnectItem) ? selectedNode : (SPTreeNode *)[selectedNode parentNode];
	
	SPTreeNode *node = [favoritesController addFavoriteNodeWithData:favorite asChildOfNode:parent];
	
	// Ensure the parent is expanded
	[favoritesOutlineView expandItem:parent];
	
	[self _sortFavorites];
	[self _selectNode:node];

	[[[SPAppDelegate preferenceController] generalPreferencePane] updateDefaultFavoritePopup];

	favoriteNameFieldWasAutogenerated = YES;

	[favoritesOutlineView editColumn:0 row:[favoritesOutlineView selectedRow] withEvent:nil select:YES];
}

/**
 * Adds the current details as a new connection favorite, selects it, and scrolls the selected
 * row to be visible.
 */
- (IBAction)addFavoriteUsingCurrentDetails:(id)sender
{
	[self _saveCurrentDetailsCreatingNewFavorite:YES validateDetails:YES];
}

/**
 * Adds a new group node to the favorites tree with a default name. Once added it is selected for editing.
 */
- (IBAction)addGroup:(id)sender
{
	SPTreeNode *selectedNode = [self selectedFavoriteNode];
	
	SPTreeNode *parent = ([selectedNode isGroup] && selectedNode != quickConnectItem) ? selectedNode : (SPTreeNode *)[selectedNode parentNode];

	// Ensure the parent is expanded
	[favoritesOutlineView expandItem:parent];
	
	SPTreeNode *node = [favoritesController addGroupNodeWithName:NSLocalizedString(@"New Folder", @"new folder placeholder name") asChildOfNode:parent];
	
	[self _reloadFavoritesViewData];
	[self _selectNode:node];
	
	[favoritesOutlineView editColumn:0 row:[favoritesOutlineView selectedRow] withEvent:nil select:YES];
}

/**
 * Removes the selected node.
 */
- (IBAction)removeNode:(id)sender
{
	if ([favoritesOutlineView numberOfSelectedRows] == 1) {
		
		BOOL suppressWarning = NO;
		SPTreeNode *node = [self selectedFavoriteNode];

		NSString *message = @"";
		NSString *informativeMessage = @"";
		
		if (![node isGroup]) {
			message            = [NSString stringWithFormat:NSLocalizedString(@"Delete favorite '%@'?", @"delete database message"), [[[node representedObject] nodeFavorite] objectForKey:SPFavoriteNameKey]];
			informativeMessage = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the favorite '%@'? This operation cannot be undone.", @"delete database informative message"), [[[node representedObject] nodeFavorite] objectForKey:SPFavoriteNameKey]];
		}
		else if ([[node childNodes] count] > 0) {
			message            = [NSString stringWithFormat:NSLocalizedString(@"Delete group '%@'?", @"delete database message"), [[node representedObject] nodeName]];
			informativeMessage = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the group '%@'? All groups and favorites within this group will also be deleted. This operation cannot be undone.", @"delete database informative message"), [[node representedObject] nodeName]];
		}
		else {
			suppressWarning = YES;
		}
		
		if (!suppressWarning) {
			NSAlert *alert = [NSAlert alertWithMessageText:message
			                                 defaultButton:NSLocalizedString(@"Delete", @"delete button")
			                               alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
			                                   otherButton:nil
			                     informativeTextWithFormat:@"%@", informativeMessage];
			
			NSArray *buttons = [alert buttons];
			
			// Change the alert's cancel button to have the key equivalent of return
			[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
			[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
			[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
			
			[alert setAlertStyle:NSCriticalAlertStyle];
			
			[alert beginSheetModalForWindow:[dbDocument parentWindow]
			                  modalDelegate:self
			                 didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
			                    contextInfo:SPRemoveNode];
		}
		else {
			[self _removeNode:node];
		}
	}
}

/**
 * Duplicates the selected connection favorite.
 */
- (IBAction)duplicateFavorite:(id)sender
{
	if ([favoritesOutlineView numberOfSelectedRows] == 1) {
		
		NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithDictionary:[self selectedFavorite]];
		
		NSNumber *favoriteID = [self _createNewFavoriteID];
		
		NSInteger duplicatedFavoriteType = [[favorite objectForKey:SPFavoriteTypeKey] integerValue];
		
		// Update the unique ID
		[favorite setObject:favoriteID forKey:SPFavoriteIDKey];
		
		// Alter the name for clarity
		[favorite setObject:[NSString stringWithFormat:NSLocalizedString(@"%@ Copy", @"Initial favourite name after duplicating a previous favourite"), [favorite objectForKey:SPFavoriteNameKey]] forKey:SPFavoriteNameKey];
		
		// Create new keychain items if appropriate
		if (password && [password length]) {
			NSString *oldKeychainName = [keychain nameForFavoriteName:[[self selectedFavorite] objectForKey:SPFavoriteNameKey] id:[[self selectedFavorite] objectForKey:SPFavoriteIDKey]];
			NSString *newKeychainName = [keychain nameForFavoriteName:[favorite objectForKey:SPFavoriteNameKey] id:[favorite objectForKey:SPFavoriteIDKey]];

			NSString *keychainAccount = [keychain accountForUser:[favorite objectForKey:SPFavoriteUserKey] host:((duplicatedFavoriteType == SPSocketConnection) ? @"localhost" : [favorite objectForKey:SPFavoriteHostKey]) database:[favorite objectForKey:SPFavoriteDatabaseKey]];

			NSString *favoritePassword = [keychain getPasswordForName:oldKeychainName account:keychainAccount];

			[keychain addPassword:favoritePassword forName:newKeychainName account:keychainAccount];

			favoritePassword = nil;
		}
		
		if (sshPassword && [sshPassword length]) {
			NSString *oldKeychainSSHName = [keychain nameForSSHForFavoriteName:[[self selectedFavorite] objectForKey:SPFavoriteNameKey] id:[[self selectedFavorite] objectForKey:SPFavoriteIDKey]];
			NSString *newKeychainSSHName = [keychain nameForSSHForFavoriteName:[favorite objectForKey:SPFavoriteNameKey] id:[favorite objectForKey:SPFavoriteIDKey]];

			NSString *keychainSSHAccount = [keychain accountForSSHUser:[favorite objectForKey:SPFavoriteSSHUserKey] sshHost:[favorite objectForKey:SPFavoriteSSHHostKey]];

			NSString *favoriteSSHPassword = [keychain getPasswordForName:oldKeychainSSHName account:keychainSSHAccount];

			[keychain addPassword:favoriteSSHPassword forName:newKeychainSSHName account:keychainSSHAccount];

			favoriteSSHPassword = nil;
		}
		
		SPTreeNode *selectedNode = [self selectedFavoriteNode];
		
		SPTreeNode *parent = ([selectedNode isGroup]) ? selectedNode : (SPTreeNode *)[selectedNode parentNode];
		
		SPTreeNode *node = [favoritesController addFavoriteNodeWithData:favorite asChildOfNode:parent];
		
		[self _reloadFavoritesViewData];
		[self _selectNode:node];
		
		[[[SPAppDelegate preferenceController] generalPreferencePane] updateDefaultFavoritePopup];
	}
}

/**
 * Switches the selected favorite/group to editing mode so it can be renamed.
 */
- (IBAction)renameNode:(id)sender
{
	if ([favoritesOutlineView numberOfSelectedRows] == 1) {
		[favoritesOutlineView editColumn:0 row:[favoritesOutlineView selectedRow] withEvent:nil select:YES];
	}
}

/**
 * Marks the selected favorite as the default.
 */
- (IBAction)makeSelectedFavoriteDefault:(id)sender
{
	NSInteger favoriteID = [[[self selectedFavorite] objectForKey:SPFavoriteIDKey] integerValue];
	
	[prefs setInteger:favoriteID forKey:SPDefaultFavorite];
}

- (void)selectQuickConnectItem
{
	return [self _selectNode:quickConnectItem];
}

#pragma mark -
#pragma mark Import/export favorites

/**
 * Displays an open panel, allowing the user to import their favorites.
 */
- (IBAction)importFavorites:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];

	[openPanel setAllowedFileTypes:@[@"plist"]];

	[openPanel beginSheetModalForWindow:[dbDocument parentWindow] completionHandler:^(NSInteger returnCode)
	{
		if (returnCode == NSOKButton) {
			SPFavoritesImporter *importer = [[SPFavoritesImporter alloc] init];

			[importer setDelegate:(NSObject<SPFavoritesImportProtocol> *)self];

			[importer importFavoritesFromFileAtPath:[[openPanel URL] path]];
		}
	}];
}

/**
 * Displays a save panel, allowing the user to export their favorites.
 */
- (IBAction)exportFavorites:(id)sender
{
	// additional empty selection check
	if(![[self selectedFavoriteNodes] count]) return;
	
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	
	// suggest the name of the favorite or a default name for multiple selection
	NSString *fileName = ([[self selectedFavoriteNodes] count] == 1)? [[(id<SPNamedNode>)[[self selectedFavoriteNode] representedObject] nodeName] stringByAppendingPathExtension:@"plist"] : nil;
	// This if() is so we can also catch nil due to favorite corruption (NSSavePanel will @throw if nil is passed in)
	if(!fileName) fileName = SPExportFavoritesFilename;

	[savePanel setAccessoryView:exportPanelAccessoryView];
	[savePanel setNameFieldStringValue:fileName];

	[savePanel beginSheetModalForWindow:[dbDocument parentWindow] completionHandler:^(NSInteger returnCode)
	{
		if (returnCode == NSOKButton) {
			SPFavoritesExporter *exporter = [[[SPFavoritesExporter alloc] init] autorelease];

			[exporter setDelegate:self];

			[exporter writeFavorites:[self selectedFavoriteNodes] toFile:[[savePanel URL] path]];
		 }
	 }];
}

#pragma mark -
#pragma mark Accessors

/**
 * Returns the main outline view instance.
 */
- (SPFavoritesOutlineView *)favoritesOutlineView
{
	return favoritesOutlineView;
}

#pragma mark -
#pragma mark Key Value Observing

/**
 * This method is called as part of Key Value Observing.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
}

#pragma mark -
#pragma mark Sheet methods

/**
 * Called when the user dismisses the remove node sheet.
 */
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	// Remove the current favorite/group node
	if ([contextInfo isEqualToString:SPRemoveNode]) {
		if (returnCode == NSAlertDefaultReturn) {
			[self _removeNode:[self selectedFavoriteNode]];
		}
	}
}

#endif

/**
 * Alert sheet callback method - invoked when the error sheet is closed.
 */
- (void)localhostErrorSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertAlternateReturn) {
		[self setType:SPSocketConnection];
		[self setHost:@""];
	} 
	else {
		[self setHost:@"127.0.0.1"];
	}
}

#pragma mark -
#pragma mark Private API

/**
 * Take the current details and either save them to the currently selected
 * favourite, or create a new connection favourite using them.
 * If creating a new favourite, also select it and ensure the selected
 * favourite is visible.
 */
- (void)_saveCurrentDetailsCreatingNewFavorite:(BOOL)createNewFavorite validateDetails:(BOOL)validateDetails
{
#ifndef SP_CODA
	// Complete any active editing
	if ([[connectionView window] firstResponder]) {
		[[connectionView window] endEditingFor:[[connectionView window] firstResponder]];
	}

	// Ensure that host is not empty if this is a TCP/IP or SSH connection
	if (validateDetails && ([self type] == SPTCPIPConnection || [self type] == SPSSHTunnelConnection) && ![[self host] length]) {
		SPOnewayAlertSheet(
			NSLocalizedString(@"Insufficient connection details", @"insufficient details message"),
			[dbDocument parentWindow],
			NSLocalizedString(@"Insufficient details provided to establish a connection. Please provide at least a host.", @"insufficient details informative message")
		);
		return;
	}
	
	// If SSH is enabled, ensure that the SSH host is not nil
	if (validateDetails && [self type] == SPSSHTunnelConnection && ![[self sshHost] length]) {
		SPOnewayAlertSheet(
			NSLocalizedString(@"Insufficient connection details", @"insufficient details message"),
			[dbDocument parentWindow],
			NSLocalizedString(@"Please enter the hostname for the SSH Tunnel, or disable the SSH Tunnel.", @"message of panel when ssh details are incomplete")
		);
		return;
	}

	// Ensure that a socket connection is not inadvertently used
	if (![self _checkHost]) return;


	// Set up the favourite, or get the mutable dictionary for the current favourite.
	NSMutableDictionary *theFavorite;
	if (createNewFavorite) {
		theFavorite = [NSMutableDictionary dictionary];
		[theFavorite setObject:[self _createNewFavoriteID] forKey:SPFavoriteIDKey];
	} else {
		if (!currentFavorite) {
			[NSException raise:NSInternalInconsistencyException format:@"Tried to save a current favourite with no currentFavorite"];
		}
		theFavorite = [self selectedFavorite];
	}
	
	void (^_setOrRemoveKey)(NSString *, id) = ^(NSString *key, id value) {
		if (value) {
			[theFavorite setObject:value forKey:key];
		} else {
			[theFavorite removeObjectForKey:key];
		}
	};

	// Set the name - either taking the provided name, or generating one.
	if ([[self name] length]) {
		[theFavorite setObject:[self name] forKey:SPFavoriteNameKey];
	} else {
		NSString *favoriteName = [self _generateNameForConnection];
		if (!favoriteName) {
			favoriteName = NSLocalizedString(@"Untitled", @"Name for an untitled connection");
		}
		[theFavorite setObject:favoriteName forKey:SPFavoriteNameKey];
	}

	// Set standard details for the connection
	[theFavorite setObject:[NSNumber numberWithInteger:[self type]] forKey:SPFavoriteTypeKey];
	_setOrRemoveKey(SPFavoriteHostKey, [self host]);
	_setOrRemoveKey(SPFavoriteSocketKey, [self socket]);
	_setOrRemoveKey(SPFavoriteUserKey, [self user]);
	_setOrRemoveKey(SPFavoritePortKey, [self port]);
	_setOrRemoveKey(SPFavoriteDatabaseKey, [self database]);
	[theFavorite setObject:[NSNumber numberWithInteger:[self colorIndex]] forKey:SPFavoriteColorIndexKey];
	// SSL details
	[theFavorite setObject:[NSNumber numberWithInteger:[self useSSL]] forKey:SPFavoriteUseSSLKey];
	[theFavorite setObject:[NSNumber numberWithInteger:[self sslKeyFileLocationEnabled]] forKey:SPFavoriteSSLKeyFileLocationEnabledKey];
	_setOrRemoveKey(SPFavoriteSSLKeyFileLocationKey, [self sslKeyFileLocation]);
	[theFavorite setObject:[NSNumber numberWithInteger:[self sslCertificateFileLocationEnabled]] forKey:SPFavoriteSSLCertificateFileLocationEnabledKey];
	_setOrRemoveKey(SPFavoriteSSLCertificateFileLocationKey, [self sslCertificateFileLocation]);
	[theFavorite setObject:[NSNumber numberWithInteger:[self sslCACertFileLocationEnabled]] forKey:SPFavoriteSSLCACertFileLocationEnabledKey];
	_setOrRemoveKey(SPFavoriteSSLCACertFileLocationKey, [self sslCACertFileLocation]);
	
	// SSH details
	_setOrRemoveKey(SPFavoriteSSHHostKey, [self sshHost]);
	_setOrRemoveKey(SPFavoriteSSHUserKey, [self sshUser]);
	_setOrRemoveKey(SPFavoriteSSHPortKey, [self sshPort]);
	[theFavorite setObject:[NSNumber numberWithInteger:[self sshKeyLocationEnabled]] forKey:SPFavoriteSSHKeyLocationEnabledKey];
	_setOrRemoveKey(SPFavoriteSSHKeyLocationKey, [self sshKeyLocation]);
	

	/*
	 * Password handling for the SQL connection
	 */
	NSString *oldKeychainName, *oldKeychainAccount, *newKeychainName, *newKeychainAccount;;
	NSString *oldHostnameForPassword = ([[currentFavorite objectForKey:SPFavoriteTypeKey] integerValue] == SPSocketConnection) ? @"localhost" : [currentFavorite objectForKey:SPFavoriteHostKey];
	NSString *newHostnameForPassword = ([self type] == SPSocketConnection) ? @"localhost" : [self host];

	// Grab the password for this connection
	// Add the password to keychain as appropriate
	NSString *sqlPassword = [self password];
	if (mySQLConnection && connectionKeychainItemName) {
		sqlPassword = [keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount];
	}

	// If creating a new favourite, always add the password to the keychain if it's set
	if (createNewFavorite && [sqlPassword length]) {
		[keychain addPassword:sqlPassword
		              forName:[keychain nameForFavoriteName:[theFavorite objectForKey:SPFavoriteNameKey] id:[theFavorite objectForKey:SPFavoriteIDKey]]
		              account:[keychain accountForUser:[self user] host:newHostnameForPassword database:[self database]]];
	}

	// If not creating a new favourite...
	if (!createNewFavorite) {

		// Get the old keychain name and account strings
		oldKeychainName = [keychain nameForFavoriteName:[currentFavorite objectForKey:SPFavoriteNameKey] id:[currentFavorite objectForKey:SPFavoriteIDKey]];
		oldKeychainAccount = [keychain accountForUser:[currentFavorite objectForKey:SPFavoriteUserKey] host:oldHostnameForPassword database:[currentFavorite objectForKey:SPFavoriteDatabaseKey]];
		
		// If there's no new password, remove the old item from the keychain
		if (![sqlPassword length]) {
			[keychain deletePasswordForName:oldKeychainName account:oldKeychainAccount];

		// Otherwise, set up the new keychain name and account strings and create or edit the item
		} else {
			newKeychainName = [keychain nameForFavoriteName:[theFavorite objectForKey:SPFavoriteNameKey] id:[theFavorite objectForKey:SPFavoriteIDKey]];
			newKeychainAccount = [keychain accountForUser:[self user] host:newHostnameForPassword database:[self database]];
			if ([keychain passwordExistsForName:oldKeychainName account:oldKeychainAccount]) {
				[keychain updateItemWithName:oldKeychainName account:oldKeychainAccount toName:newKeychainName account:newKeychainAccount password:sqlPassword];
			} else {
				[keychain addPassword:sqlPassword forName:newKeychainName account:newKeychainAccount];
			}
		}
	}
	sqlPassword = nil;

	/*
	 * Password handling for the SSH connection
	 */
	NSString *theSSHPassword = [self sshPassword];
	if (mySQLConnection && connectionSSHKeychainItemName) {
		theSSHPassword = [keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount];
	}

	// If creating a new favourite, always add the password if it's set
	if (createNewFavorite && [theSSHPassword length]) {
		[keychain addPassword:theSSHPassword
		              forName:[keychain nameForSSHForFavoriteName:[theFavorite objectForKey:SPFavoriteNameKey] id:[theFavorite objectForKey:SPFavoriteIDKey]]
		              account:[keychain accountForSSHUser:[self sshUser] sshHost:[self sshHost]]];
	}

	// If not creating a new favourite...
	if (!createNewFavorite) {

		// Get the old keychain name and account strings
		oldKeychainName = [keychain nameForSSHForFavoriteName:[currentFavorite objectForKey:SPFavoriteNameKey] id:[currentFavorite objectForKey:SPFavoriteIDKey]];
		oldKeychainAccount = [keychain accountForSSHUser:[currentFavorite objectForKey:SPFavoriteSSHUserKey] sshHost:[currentFavorite objectForKey:SPFavoriteSSHHostKey]];
		
		// If there's no new password, remove the old item from the keychain
		if (![theSSHPassword length]) {
			[keychain deletePasswordForName:oldKeychainName account:oldKeychainAccount];

		// Otherwise, set up the new keychain name and account strings and create or edit the item
		} else {
			newKeychainName = [keychain nameForSSHForFavoriteName:[theFavorite objectForKey:SPFavoriteNameKey] id:[theFavorite objectForKey:SPFavoriteIDKey]];
			newKeychainAccount = [keychain accountForSSHUser:[self sshUser] sshHost:[self sshHost]];
			if ([keychain passwordExistsForName:oldKeychainName account:oldKeychainAccount]) {
				[keychain updateItemWithName:oldKeychainName account:oldKeychainAccount toName:newKeychainName account:newKeychainAccount password:theSSHPassword];
			} else {
				[keychain addPassword:theSSHPassword forName:newKeychainName account:newKeychainAccount];
			}
		}
	}
	theSSHPassword = nil;

	/*
	 * Saving the connection
	 */

	// If creating the connection, add to the favourites tree.
	if (createNewFavorite) {
		SPTreeNode *selectedNode = [self selectedFavoriteNode];
		SPTreeNode *parentNode = nil;

		// If the current node is a group node, create the favorite as a child of it
		if ([selectedNode isGroup] && selectedNode != quickConnectItem) {
			parentNode = selectedNode;

		// Otherwise, create the new node as a sibling of the selected node if possible
		} else if ([selectedNode parentNode] && [selectedNode parentNode] != favoritesRoot) {
			parentNode = (SPTreeNode *)[selectedNode parentNode];
		}

		// Ensure the parent is expanded
		[favoritesOutlineView expandItem:parentNode];

		// Add the new node and select it
		SPTreeNode *newNode = [favoritesController addFavoriteNodeWithData:theFavorite asChildOfNode:parentNode];

		[self _sortFavorites];

		[self _selectNode:newNode];

		// Update the favorites popup button in the preferences
		[[[SPAppDelegate preferenceController] generalPreferencePane] updateDefaultFavoritePopup];

	// Otherwise, if editing the favourite, update it
	} else {
		[[[self selectedFavoriteNode] representedObject] setNodeFavorite:theFavorite];

		// Save the new data to disk
		[favoritesController saveFavorites];

		[self _stopEditingConnection];

		if (currentFavorite) SPClear(currentFavorite);
		currentFavorite = [theFavorite copy];

		[self _sortFavorites];
		[self _scrollToSelectedNode];
	}
	
	// after saving the favorite, the name is never autogenerated (ie. overridable), regardless of the value (#3015)
	favoriteNameFieldWasAutogenerated = NO;

	[[NSNotificationCenter defaultCenter] postNotificationName:SPConnectionFavoritesChangedNotification object:self];
#endif
}

/**
 * Check the host field and ensure it isn't set to 'localhost' for non-socket connections.
 */
- (BOOL)_checkHost
{
	if ([self type] != SPSocketConnection && [[self host] isEqualToString:@"localhost"]) {
		SPBeginAlertSheet(
			NSLocalizedString(@"You have entered 'localhost' for a non-socket connection", @"title of error when using 'localhost' for a network connection"),
			NSLocalizedString(@"Use 127.0.0.1", @"Use 127.0.0.1 button"), // Main button
			NSLocalizedString(@"Connect via socket", @"Connect via socket button"), // Alternate button
			nil, // Other button
			[dbDocument parentWindow], // Window to attach to
			self, // Modal delegate
			@selector(localhostErrorSheetDidEnd:returnCode:contextInfo:), // Did end selector
			NULL, // Contextual info for selectors
			NSLocalizedString(@"To MySQL, 'localhost' is a special host and means that a socket connection should be used.\n\nDid you mean to use a socket connection, or to connect to the local machine via a port?  If you meant to connect via a port, '127.0.0.1' should be used instead of 'localhost'.", @"message of error when using 'localhost' for a network connection")
		);
		return NO;
	}
	
	return YES;
}

/**
 * Sorts the connection favorites based on the selected criteria.
 */

#ifndef SP_CODA
- (void)_sortFavorites
{
	NSString *sortKey = SPFavoriteNameKey;

	switch (currentSortItem)
	{
		case SPFavoritesSortNameItem:
			sortKey = SPFavoriteNameKey;
			break;
		case SPFavoritesSortHostItem:
			sortKey = SPFavoriteHostKey;
			break;
		case SPFavoritesSortTypeItem:
			sortKey = SPFavoriteTypeKey;
			break;
		case SPFavoritesSortColorItem:
			sortKey = SPFavoriteColorIndexKey;
			break;
		case SPFavoritesSortUnsorted:
			return;
	}
	
	// Store a copy of the selected nodes for re-selection
	NSArray *preSortSelection = [self selectedFavoriteNodes];

	[self _sortTreeNode:[[favoritesRoot childNodes] objectAtIndex:0] usingKey:sortKey];

	[favoritesController saveFavorites];
	 
	[self _reloadFavoritesViewData];

	// Update the selection to account for sorted favourites
	NSMutableIndexSet *restoredSelection = [NSMutableIndexSet indexSet];
	for (SPTreeNode *eachNode in preSortSelection) {
		[restoredSelection addIndex:[favoritesOutlineView rowForItem:eachNode]];
	}
	[favoritesOutlineView selectRowIndexes:restoredSelection byExtendingSelection:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPConnectionFavoritesChangedNotification object:self];
}

/**
 * Sorts the supplied tree node using the supplied sort key.
 *
 * @param node The tree node to sort
 * @param key  The sort key to sort by
 */
- (void)_sortTreeNode:(SPTreeNode *)node usingKey:(NSString *)key
{	
	NSMutableArray *nodes = [[node mutableChildNodes] mutableCopy];
	
	// If this node only has one child and it's not another group node, don't bother proceeding
	if (([nodes count] == 1) && (![[nodes objectAtIndex:0] isGroup])) {
		[nodes release];
		return;
	}

	for (SPTreeNode *treeNode in nodes)
	{
		if ([treeNode isGroup]) {
			[self _sortTreeNode:treeNode usingKey:key];
		}
	}
	
	[nodes sortUsingFunction:_compareFavoritesUsingKey context:key];

	if (reverseFavoritesSort) [nodes reverse];

	[[node mutableChildNodes] setArray:nodes];
	
	[nodes release];
}

/**
 * Sort function used by NSMutableArray's sortUsingFunction:
 *
 * @param favorite1 The first of the favorites to compare (and determine sort order)
 * @param favorite2 The second of the favorites to compare
 * @param key       The sort key to perform the comparison by
 * 
 * @return An integer (NSComparisonResult) indicating the order of the comparison
 */
static NSComparisonResult _compareFavoritesUsingKey(id favorite1, id favorite2, void *key)
{
	NSString *dictKey = (NSString *)key;
	id value1, value2;
	
	BOOL isNamedComparison = [dictKey isEqualToString:SPFavoriteNameKey];
	// Group nodes can only be compared using their names.
	// If this is a named comparison or both nodes are group nodes use their
	// names. Otherwise let the group nodes win (ie. they will be placed at the
	// top ordered alphabetically for all other comparison keys)

	if ([favorite1 isGroup]) {
		if (isNamedComparison || [favorite2 isGroup]) {
			value1 = [[favorite1 representedObject] nodeName];
		} else {
			return NSOrderedAscending; // the left object is a group, the right is not -> left wins
		}
	} else {
		value1 = [[(SPFavoriteNode *)[(SPTreeNode *)favorite1 representedObject] nodeFavorite] objectForKey:dictKey];
	}

	if ([favorite2 isGroup]) {
		if (isNamedComparison || [favorite1 isGroup]) {
			value2 = [[favorite2 representedObject] nodeName];
		} else {
			return NSOrderedDescending; // the left object is not a group, the right is -> left loses
		}
	} else {
		value2 = [[(SPFavoriteNode *)[(SPTreeNode *)favorite2 representedObject] nodeFavorite] objectForKey:dictKey];
	}
	
	//if a value is undefined count it as "loser"
	if(!value1 && value2) return NSOrderedDescending;
	if(value1 && !value2) return NSOrderedAscending;
	if(!value1 && !value2) return NSOrderedSame;

	if ([value1 isKindOfClass:[NSString class]]) {
		return [value1 caseInsensitiveCompare:value2];
	}
	return [value1 compare:value2];
}

/**
 * Updates the favorite's host when the type changes.
 */

- (void)_favoriteTypeDidChange
{
	NSDictionary *favorite = [self selectedFavorite];

	// If either socket or host is localhost, clear.
	if ((previousType != SPSocketConnection) && [[favorite objectForKey:SPFavoriteHostKey] isEqualToString:@"localhost"]) {
		[self setHost:@""];
	}

	// Update the name for newly added favorites if not already touched by the user, by triggering a KVO update
	if (![[self name] length] || favoriteNameFieldWasAutogenerated) {
		NSString *favoriteName = [self _generateNameForConnection];
		if (favoriteName) {
			[self setName:favoriteName];
		}
	}
}

/**
 * Convenience method for reloading the outline view, expanding the root item and scrolling to the selected item.
 */
- (void)_reloadFavoritesViewData
{	
	[favoritesOutlineView reloadData];
	[favoritesOutlineView expandItem:[[favoritesRoot childNodes] objectAtIndex:0] expandChildren:NO];
	
	[self _scrollToSelectedNode];
}

/**
 * Update the first responder status on password fields if they are empty and
 * some host details are set, usually as a response to favourite selection changes.
 */
- (void)_updateFavoriteFirstResponder
{
	// Skip auto-selection changes if there is no user set
	if (![[self user] length]) return;

	switch ([self type]) 
	{
		case SPTCPIPConnection:
			if (![[standardPasswordField stringValue] length]) {
				[[dbDocument parentWindow] makeFirstResponder:standardPasswordField];
			}
			break;
		case SPSocketConnection:
			if (![[socketPasswordField stringValue] length]) {
				[[dbDocument parentWindow] makeFirstResponder:socketPasswordField];
			}
			break;
		case SPSSHTunnelConnection:
			if (![[sshPasswordField stringValue] length]) {
				[[dbDocument parentWindow] makeFirstResponder:sshPasswordField];
			}
			break;
	}
}

/**
 * Restores the connection interface to its original state.
 */
- (void)_restoreConnectionInterface
{
	// Must be performed on the main thread
	if (![NSThread isMainThread]) return [[self onMainThread] _restoreConnectionInterface];

	// Reset the window title
	[dbDocument updateWindowTitle:self];
	[[dbDocument parentTabViewItem] setLabel:[dbDocument displayName]];
	
	// Stop the current tab's progress indicator
	[dbDocument setIsProcessing:NO];

	// Reset the UI
	[helpButton setHidden:NO];
	[helpButton display];
	[connectButton setTitle:NSLocalizedString(@"Connect", @"connect button")];
	[connectButton setEnabled:YES];
	[connectButton display];
	[testConnectButton setEnabled:YES];
	[progressIndicator stopAnimation:self];
	[progressIndicator display];
	[progressIndicatorText setHidden:YES];
	[progressIndicatorText display];
	[dbDocument setTitlebarStatus:@""];

	// If not testing a connection, Update the password fields, restoring passwords that may have
	// been bulleted out during connection
	if (!isTestingConnection) {
		if (connectionKeychainItemName) {
			[self setPassword:[keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount]];
		}
		if (connectionSSHKeychainItemName) {
			[self setSshPassword:[keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount]];
		}
	}

	// Re-enable favorites table view
	[favoritesOutlineView setEnabled:YES];
	[favoritesOutlineView display];

	// Revert the connect button back to its original selector
	[connectButton setAction:@selector(initiateConnection:)];
}

/**
 * Selected the supplied node in the favorites outline view.
 *
 * @param node The node to select
 */
- (void)_selectNode:(SPTreeNode *)node
{
	[favoritesOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[favoritesOutlineView rowForItem:node]] byExtendingSelection:NO];
	[self _scrollToSelectedNode];
}

/**
 * Scroll to the currently selected node.
 */
- (void)_scrollToSelectedNode
{
	// Don't scroll if no node is currently selected
	if ([favoritesOutlineView selectedRow] == -1) return;

	[favoritesOutlineView scrollRowToVisible:[favoritesOutlineView selectedRow]];
}

/**
 * Removes the supplied tree node.
 *
 * @param node The node to remove
 */
- (void)_removeNode:(SPTreeNode *)node
{
	[self _removeAllPasswordsForNode:node];

	[favoritesController removeFavoriteNode:node];
	
	[self _reloadFavoritesViewData];

	// Select Quick Connect item to prevent empty selection
	[self selectQuickConnectItem];
	
	[connectionResizeContainer setHidden:NO];
	[connectionInstructionsTextField setStringValue:NSLocalizedString(@"Enter connection details below, or choose a favorite", @"enter connection details label")];
	
	[[[SPAppDelegate preferenceController] generalPreferencePane] updateDefaultFavoritePopup];
}

/**
 * Removes all passwords for the supplied tree node and any child nodes.
 *
 * @param node The node to remove all passwords within and for.
 */
- (void)_removeAllPasswordsForNode:(SPTreeNode *)node
{

	// If the supplied node is a group node, remove all passwords for any children
	if ([node isGroup]) {
		for (SPTreeNode *childNode in [node childNodes]) {
			[self _removeAllPasswordsForNode:childNode];
		}
		return;
	}

	// Otherwise, remove details for the supplied node.

		NSDictionary *favorite = [[node representedObject] nodeFavorite];
		
		// Get selected favorite's details
		NSString *favoriteName     = [favorite objectForKey:SPFavoriteNameKey];
		NSString *favoriteUser     = [favorite objectForKey:SPFavoriteUserKey];
		NSString *favoriteHost     = [favorite objectForKey:SPFavoriteHostKey];
		NSString *favoriteDatabase = [favorite objectForKey:SPFavoriteDatabaseKey];
		NSString *favoriteSSHUser  = [favorite objectForKey:SPFavoriteSSHUserKey];
		NSString *favoriteSSHHost  = [favorite objectForKey:SPFavoriteSSHHostKey];
		NSString *favoriteID       = [favorite objectForKey:SPFavoriteIDKey];

		// Remove passwords from the Keychain
		[keychain deletePasswordForName:[keychain nameForFavoriteName:favoriteName id:favoriteID]
		                        account:[keychain accountForUser:favoriteUser host:((type == SPSocketConnection) ? @"localhost" : favoriteHost) database:favoriteDatabase]];
		[keychain deletePasswordForName:[keychain nameForSSHForFavoriteName:favoriteName id:favoriteID]
		                        account:[keychain accountForSSHUser:favoriteSSHUser sshHost:favoriteSSHHost]];

		// Reset last used favorite
		if ([[favorite objectForKey:SPFavoriteIDKey] integerValue] == [prefs integerForKey:SPLastFavoriteID]) {
			[prefs setInteger:0 forKey:SPLastFavoriteID];
		}

		// If required, reset the default favorite
		if ([[favorite objectForKey:SPFavoriteIDKey] integerValue] == [prefs integerForKey:SPDefaultFavorite]) {
			[prefs setInteger:[prefs integerForKey:SPLastFavoriteID] forKey:SPDefaultFavorite];
		}
	}

/**
 * Creates a new favorite ID based on the UNIX epoch time.
 */
- (NSNumber *)_createNewFavoriteID
{
	return [NSNumber numberWithInteger:[[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] hash]];
}

/**
 * Returns the favorite node for the conection favorite with the supplied ID.
 */
- (SPTreeNode *)_favoriteNodeForFavoriteID:(NSInteger)favoriteID
{	
	SPTreeNode *favoriteNode = nil;

	if (!favoritesRoot) return favoriteNode;

	if (!favoriteID) return quickConnectItem;

	for (SPTreeNode *node in [favoritesRoot allChildLeafs]) 
	{
		if ([[[[node representedObject] nodeFavorite] objectForKey:SPFavoriteIDKey] integerValue] == favoriteID) {
			favoriteNode = node;
		}
	}

	return favoriteNode;
}
#endif

/**
 * Strips any invalid characters form the supplied string. Invalid is defined as any characters that should
 * not be allowed to be enetered on the connection screen.
 */
- (NSString *)_stripInvalidCharactersFromString:(NSString *)subject
{
	NSString *result = [subject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	return [result stringByReplacingOccurrencesOfString:@"\n" withString:@""];
}

#ifndef SP_CODA
/**
 * Generate a name for the current connection based on any other populated details.
 * Currently uses the host and database fields.
 * If a name cannot be generated because there are insufficient other details, returns nil.
 */
- (NSString *)_generateNameForConnection
{
	NSString *aName;
	
	if ([self type] != SPSocketConnection && ![[self host] length]) {
		return nil;
	}
		
	aName = ([self type] == SPSocketConnection) ? @"localhost" : [self host];
	
	if ([[self database] length]) {
		aName = [NSString stringWithFormat:@"%@/%@", aName, [self database]];
	}

	return aName;
}

		
/**
 * If editing is not already active, mark editing as starting, triggering UI updates
 * to match.
 */
- (void)_startEditingConnection
{
	// If not connecting, hide the connection status text to reflect changes
	if (!isConnecting) {
		[progressIndicatorText setHidden:YES];
	}

	if (isEditingConnection) return;

	// Fade and move the edit button area in
	[editButtonsView setAlphaValue:0.0f];
	[editButtonsView setHidden:NO];
	[editButtonsView setFrameOrigin:NSMakePoint([editButtonsView frame].origin.x, [editButtonsView frame].origin.y - 30)];
	// The animation is started async because there is a bug/oddity with layer-backed views and animating frameOrigin (at least in 10.13):
	// If both calls to -setFrameOrigin: are in the same method, CA would only animate the difference between those calls (which is 0 here).
	// This works fine when not using layers, but then there is another issue with the progress indicator (#2903)
	SPMainLoopAsync(^{
		[NSAnimationContext beginGrouping];
		[[editButtonsView animator] setFrameOrigin:NSMakePoint([editButtonsView frame].origin.x, [editButtonsView frame].origin.y + 30)];
		[[editButtonsView animator] setAlphaValue:1.0f];
		[NSAnimationContext endGrouping];
	});

	// Update the "Save" button state as appropriate
	[saveFavoriteButton setEnabled:([self selectedFavorite] != nil)];

	// Show the area to allow saving the changes
	[self setIsEditingConnection:YES];
	[favoritesOutlineView setNeedsDisplayInRect:[favoritesOutlineView rectOfRow:[favoritesOutlineView selectedRow]]];
}

/**
 * If editing is active, mark editing as complete, triggering UI updates to match.
 */
- (void)_stopEditingConnection
{
	if (!isEditingConnection) return;

	[self setIsEditingConnection:NO];

	[editButtonsView setHidden:YES];
	[progressIndicatorText setHidden:YES];
	[favoritesOutlineView display];
}
#endif

- (void)_documentWillClose:(NSNotification *)notification
{
	cancellingConnection = YES;
	dbDocument = nil;

	if (mySQLConnection) {
		[mySQLConnection setDelegate:nil];
		[NSThread detachNewThreadWithName:SPCtxt(@"SPConnectionController close background disconnect", dbDocument) target:mySQLConnection selector:@selector(disconnect) object:nil];
		[mySQLConnection autorelease];
		mySQLConnection = nil;
	}
	
	if (sshTunnel) [sshTunnel setConnectionStateChangeSelector:nil delegate:nil], SPClear(sshTunnel);
}

#pragma mark - SPConnectionHandler

/**
 * Set up the MySQL connection, either through a successful tunnel or directly in the background.
 */
- (void)initiateMySQLConnection
{
#ifndef SP_CODA
	if (isTestingConnection) {
		if (sshTunnel) {
			[progressIndicatorText setStringValue:NSLocalizedString(@"Testing MySQL...", @"MySQL connection test very short status message")];
		}
		else {
			[progressIndicatorText setStringValue:NSLocalizedString(@"Testing connection...", @"Connection test very short status message")];
		}
	}
	else if (sshTunnel) {
		[progressIndicatorText setStringValue:NSLocalizedString(@"MySQL connecting...", @"MySQL connecting very short status message")];
	}
	else {
		[progressIndicatorText setStringValue:NSLocalizedString(@"Connecting...", @"Generic connecting very short status message")];
	}

	[progressIndicatorText display];

	[connectButton setTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[connectButton setAction:@selector(cancelConnection:)];
	[connectButton setEnabled:YES];
	[connectButton display];
#endif

	[NSThread detachNewThreadWithName:SPCtxt(@"SPConnectionController MySQL connection task", dbDocument)
	                           target:self
	                         selector:@selector(initiateMySQLConnectionInBackground)
	                           object:nil];
}

/**
 * Initiates the core of the MySQL connection process on a background thread.
 */
- (void)initiateMySQLConnectionInBackground
{
	@autoreleasepool {
		mySQLConnection = [[SPMySQLConnection alloc] init];

		// Set up shared details
		[mySQLConnection setUsername:[self user]];

		// Initialise to socket if appropriate.
		if ([self type] == SPSocketConnection) {
			[mySQLConnection setUseSocket:YES];
			[mySQLConnection setSocketPath:[self socket]];

			// Otherwise, initialise to host, using tunnel if appropriate
		}
		else {
			[mySQLConnection setUseSocket:NO];

			if ([self type] == SPSSHTunnelConnection) {
				[mySQLConnection setHost:@"127.0.0.1"];

				[mySQLConnection setPort:[sshTunnel localPort]];
				[mySQLConnection setProxy:sshTunnel];
			}
			else {
				[mySQLConnection setHost:[self host]];

				if ([[self port] length]) [mySQLConnection setPort:[[self port] integerValue]];
			}
		}

		// Only set the password if there is no Keychain item set and the connection is not being tested.
		// The connection will otherwise ask the delegate for passwords in the Keychain.
		if ((!connectionKeychainItemName || isTestingConnection) && [self password]) {
			[mySQLConnection setPassword:[self password]];
		}

		// Enable SSL if set
		if ([self useSSL]) {
			[mySQLConnection setUseSSL:YES];

			if ([self sslKeyFileLocationEnabled]) {
				[mySQLConnection setSslKeyFilePath:[self sslKeyFileLocation]];
			}

			if ([self sslCertificateFileLocationEnabled]) {
				[mySQLConnection setSslCertificatePath:[self sslCertificateFileLocation]];
			}

			if ([self sslCACertFileLocationEnabled]) {
				[mySQLConnection setSslCACertificatePath:[self sslCACertFileLocation]];
			}

			NSString *userSSLCipherList = [prefs stringForKey:SPSSLCipherListKey];
			if(userSSLCipherList) {
				//strip out disabled ciphers (e.g. in "foo:bar:--:baz")
				NSRange markerPos = [userSSLCipherList rangeOfRegex:@":?--"];
				if(markerPos.location != NSNotFound) {
					userSSLCipherList = [userSSLCipherList substringToIndex:markerPos.location];
				}
				[mySQLConnection setSslCipherList:userSSLCipherList];
			}
		}

		if(![self useCompression]) [mySQLConnection removeClientFlags:SPMySQLClientFlagCompression];

		// Connection delegate must be set before actual connection attempt is made
		[mySQLConnection setDelegate:dbDocument];

		// Set whether or not we should enable delegate logging according to the prefs
		[mySQLConnection setDelegateQueryLogging:[prefs boolForKey:SPConsoleEnableLogging]];

		// Set options from preferences
		[mySQLConnection setTimeout:[[prefs objectForKey:SPConnectionTimeoutValue] integerValue]];
		[mySQLConnection setUseKeepAlive:[[prefs objectForKey:SPUseKeepAlive] boolValue]];
		[mySQLConnection setKeepAliveInterval:[[prefs objectForKey:SPKeepAliveInterval] floatValue]];

		// Connect
		[mySQLConnection connect];

		if (![mySQLConnection isConnected]) {
			if (sshTunnel && !cancellingConnection) {

				// This is a race condition we cannot fix "properly":
				// For meaningful error handling we need to also consider the debug output from the SSH connection.
				// The SSH debug output might be sligthly delayed though (flush, delegates, ...) or
				// there might not even by any output at all (when it is purely a libmysql issue).
				// TL;DR: No guaranteed events we could wait for, just trying our luck.
				[NSThread sleepForTimeInterval:0.1]; // 100ms

				// If the state is connection refused, attempt the MySQL connection again with the host using the hostfield value.
				if ([sshTunnel state] == SPMySQLProxyForwardingFailed) {
					if ([sshTunnel localPortFallback]) {
						[mySQLConnection setPort:[sshTunnel localPortFallback]];
						[mySQLConnection connect];

						if (![mySQLConnection isConnected]) {
							[NSThread sleepForTimeInterval:0.1]; //100ms
						}
					}
				}
			}

			if (![mySQLConnection isConnected]) {
				if (!cancellingConnection) {
					NSString *errorMessage;
					if (sshTunnel && [sshTunnel state] == SPMySQLProxyForwardingFailed) {
						errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to host %@ because the port connection via SSH was refused.\n\nPlease ensure that your MySQL host is set up to allow TCP/IP connections (no --skip-networking) and is configured to allow connections from the host you are tunnelling via.\n\nYou may also want to check the port is correct and that you have the necessary privileges.\n\nChecking the error detail will show the SSH debug log which may provide more details.\n\nMySQL said: %@", @"message of panel when SSH port forwarding failed"), [self host], [mySQLConnection lastErrorMessage]];
						[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"SSH port forwarding failed", @"title when ssh tunnel port forwarding failed") errorMessage:errorMessage detail:[sshTunnel debugMessages] rawErrorText:[mySQLConnection lastErrorMessage]];
					}
					else if ([mySQLConnection lastErrorID] == 1045) { // "Access denied" error
						errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to host %@ because access was denied.\n\nDouble-check your username and password and ensure that access from your current location is permitted.\n\nMySQL said: %@", @"message of panel when connection to host failed due to access denied error"), [self host], [mySQLConnection lastErrorMessage]];
						[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"Access denied!", @"connection failed due to access denied title") errorMessage:errorMessage detail:nil rawErrorText:[mySQLConnection lastErrorMessage]];
					}
					else if ([self type] == SPSocketConnection && (![self socket] || ![[self socket] length]) && ![mySQLConnection socketPath]) {
						errorMessage = [NSString stringWithFormat:NSLocalizedString(@"The socket file could not be found in any common location. Please supply the correct socket location.\n\nMySQL said: %@", @"message of panel when connection to socket failed because optional socket could not be found"), [mySQLConnection lastErrorMessage]];
						[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"Socket not found!", @"socket not found title") errorMessage:errorMessage detail:nil rawErrorText:[mySQLConnection lastErrorMessage]];
					}
					else if ([self type] == SPSocketConnection) {
						errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to connect via the socket, or the request timed out.\n\nDouble-check that the socket path is correct and that you have the necessary privileges, and that the server is running.\n\nMySQL said: %@", @"message of panel when connection to host failed"), [mySQLConnection lastErrorMessage]];
						[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"Socket connection failed!", @"socket connection failed title") errorMessage:errorMessage detail:nil rawErrorText:[mySQLConnection lastErrorMessage]];
					}
					else {
						errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to host %@, or the request timed out.\n\nBe sure that the address is correct and that you have the necessary privileges, or try increasing the connection timeout (currently %ld seconds).\n\nMySQL said: %@", @"message of panel when connection to host failed"), [self host], (long)[[prefs objectForKey:SPConnectionTimeoutValue] integerValue], [mySQLConnection lastErrorMessage]];
						[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"Connection failed!", @"connection failed title") errorMessage:errorMessage detail:nil rawErrorText:[mySQLConnection lastErrorMessage]];
					}
				}

				// Tidy up
				isConnecting = NO;

				if (sshTunnel) [sshTunnel disconnect], SPClear(sshTunnel);

				SPClear(mySQLConnection);
#ifndef SP_CODA
				if (!cancellingConnection) [self _restoreConnectionInterface];
#endif

				return;
			}
		}

		if ([self database] && ![[self database] isEqualToString:@""]) {
			if (![mySQLConnection selectDatabase:[self database]]) {
				if (!isTestingConnection) {
					[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"Could not select database", @"message when database selection failed") errorMessage:[NSString stringWithFormat:NSLocalizedString(@"Connected to host, but unable to connect to database %@.\n\nBe sure that the database exists and that you have the necessary privileges.\n\nMySQL said: %@", @"message of panel when connection to db failed"), [self database], [mySQLConnection lastErrorMessage]] detail:nil rawErrorText:[mySQLConnection lastErrorMessage]];
				}

				// Tidy up
				isConnecting = NO;

				if (sshTunnel) SPClear(sshTunnel);

				SPClear(mySQLConnection);
				[self _restoreConnectionInterface];
				if (isTestingConnection) {
					[self _showConnectionTestResult:NSLocalizedString(@"Invalid database", @"Invalid database very short status message")];
				}

				return;
			}
		}

		// Connection established
		[self performSelectorOnMainThread:@selector(mySQLConnectionEstablished) withObject:nil waitUntilDone:NO];
	}
}

/**
 * Initiate the SSH connection process.
 * This should only be called as part of initiateConnection:, and will indirectly
 * call initiateMySQLConnection if it's successful.
 */
- (void)initiateSSHTunnelConnection
{
	if (isTestingConnection) {
		[progressIndicatorText setStringValue:NSLocalizedString(@"Testing SSH...", @"SSH testing very short status message")];
	} else {
		[progressIndicatorText setStringValue:NSLocalizedString(@"SSH connecting...", @"SSH connecting very short status message")];
	}
	[progressIndicatorText display];

	[connectButton setTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[connectButton setAction:@selector(cancelConnection:)];
	[connectButton setEnabled:YES];
	[connectButton display];

	// Trim whitespace and newlines from the SSH host field before attempting to connect
	[self setSshHost:[[self sshHost] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];

	// Set up the tunnel details
	sshTunnel = [[SPSSHTunnel alloc] initToHost:[self sshHost] port:[[self sshPort] integerValue] login:[self sshUser] tunnellingToPort:([[self port] length]?[[self port] integerValue]:3306) onHost:[self host]];
	[sshTunnel setParentWindow:[dbDocument parentWindow]];

	// Add keychain or plaintext password as appropriate - note the checks in initiateConnection.
	if (connectionSSHKeychainItemName && !isTestingConnection) {
		[sshTunnel setPasswordKeychainName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount];
	} else if (sshPassword) {
		[sshTunnel setPassword:[self sshPassword]];
	}

	// Set the public key path if appropriate
	if (sshKeyLocationEnabled && sshKeyLocation) {
		[sshTunnel setKeyFilePath:sshKeyLocation];
	}

	// Set the callback function on the tunnel
	[sshTunnel setConnectionStateChangeSelector:@selector(sshTunnelCallback:) delegate:self];

	// Ask the tunnel to connect.  This will call the callback below on success or failure, passing
	// itself as an argument - retain count should be one at this point.
	[sshTunnel connect];
}

/**
 * Called on the main thread once the MySQL connection is established on the background thread. Either the
 * connection was cancelled or it was successful.
 */
- (void)mySQLConnectionEstablished
{
	isConnecting = NO;

	// If the user is only testing the connection, kill the connection
	// once established and reset the UI.  Also catch connection cancels.
	if (isTestingConnection || cancellingConnection) {

		// Clean up any connections remaining, and reset the UI
		[self cancelConnection:self];

		if (isTestingConnection) {
			[self _showConnectionTestResult:NSLocalizedString(@"Connection succeeded", @"Connection success very short status message")];
		}

		return;
	}

#ifndef SP_CODA
	[progressIndicatorText setStringValue:NSLocalizedString(@"Connected", @"connection established message")];
	[progressIndicatorText display];
#endif

	// Stop the current tab's progress indicator
	[dbDocument setIsProcessing:NO];

	// Successful connection!
#ifndef SP_CODA
	[connectButton setEnabled:NO];
	[connectButton display];
	[progressIndicator stopAnimation:self];
	[progressIndicatorText setHidden:YES];
#endif

	// If SSL was enabled, check it was established correctly
	if (useSSL && ([self type] == SPTCPIPConnection || [self type] == SPSocketConnection)) {
		if (![mySQLConnection isConnectedViaSSL]) {
			SPOnewayAlertSheet(
				NSLocalizedString(@"SSL connection not established", @"SSL requested but not used title"),
				[dbDocument parentWindow],
				NSLocalizedString(@"You requested that the connection should be established using SSL, but MySQL made the connection without SSL.\n\nThis may be because the server does not support SSL connections, or has SSL disabled; or insufficient details were supplied to establish an SSL connection.\n\nThis connection is not encrypted.", @"SSL connection requested but not established error detail")
			);
		}
		else {
#ifndef SP_CODA
			[dbDocument setStatusIconToImageWithName:@"titlebarlock"];
#endif
		}
	}

#ifndef SP_CODA
	// Re-enable favorites table view
	[favoritesOutlineView setEnabled:YES];
	[favoritesOutlineView display];
#endif

	// Release the tunnel if set - will now be retained by the connection
	if (sshTunnel) SPClear(sshTunnel);

	// Pass the connection to the document and clean up the interface
	[self addConnectionToDocument];
}

/**
 * A callback function for the SSH Tunnel setup process - will be called on a connection
 * state change, allowing connection to fail or proceed as appropriate.  If successful,
 * will call initiateMySQLConnection.
 */
- (void)sshTunnelCallback:(SPSSHTunnel *)theTunnel
{
	if (cancellingConnection) return;

	NSInteger newState = [theTunnel state];

	// If the user cancelled the password prompt dialog, continue with no further action.
	if ([theTunnel passwordPromptCancelled]) {
		[self _restoreConnectionInterface];

		return;
	}

	if (newState == SPMySQLProxyIdle) {

#ifndef SP_CODA
		[dbDocument setTitlebarStatus:NSLocalizedString(@"SSH Disconnected", @"SSH disconnected titlebar marker")];
#endif

		[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"SSH connection failed!", @"SSH connection failed title")
		                                errorMessage:[theTunnel lastError]
		                                      detail:[sshTunnel debugMessages]
		                                rawErrorText:[theTunnel lastError]];
	}
	else if (newState == SPMySQLProxyConnected) {
#ifndef SP_CODA
		[dbDocument setTitlebarStatus:NSLocalizedString(@"SSH Connected", @"SSH connected titlebar marker")];
#endif

		[self initiateMySQLConnection];
	}
	else {
#ifndef SP_CODA
		[dbDocument setTitlebarStatus:NSLocalizedString(@"SSH Connecting…", @"SSH connecting titlebar marker")];
#endif
	}
}

/**
 * Add the connection to the parent document and restore the
 * interface, allowing the application to run as normal.
 */
- (void)addConnectionToDocument
{
#ifndef SP_CODA
	// Hide the connection view and restore the main view
	[connectionView removeFromSuperviewWithoutNeedingDisplay];
	[databaseConnectionView setHidden:NO];

	// Restore the toolbar icons
	NSArray *toolbarItems = [[[dbDocument parentWindow] toolbar] items];

	for (NSUInteger i = 0; i < [toolbarItems count]; i++) [[toolbarItems objectAtIndex:i] setEnabled:YES];
#endif

	// Pass the connection to the table document, allowing it to set
	// up the other classes and the rest of the interface.
	[dbDocument setConnection:mySQLConnection];
}

/**
 * Ends a connection attempt by stopping the connection animation and
 * displaying a specified error message.
 */
- (void)failConnectionWithTitle:(NSString *)theTitle errorMessage:(NSString *)theErrorMessage detail:(NSString *)errorDetail rawErrorText:(NSString *)rawErrorText
{
	BOOL isSSHTunnelBindError = NO;

#ifndef SP_CODA
	[self _restoreConnectionInterface];
#endif

	// Release as appropriate
	if (sshTunnel) {
		[sshTunnel disconnect], SPClear(sshTunnel);

		// If the SSH tunnel connection failed because the port it was trying to bind to was already in use take note
		// of it so we can give the user the option of connecting via standard connection and use the existing tunnel.
		if ([rawErrorText rangeOfString:@"bind"].location != NSNotFound) {
			isSSHTunnelBindError = YES;
		}
	}

	if (errorDetail) [errorDetailText setString:errorDetail];

	// Inform the delegate that the connection attempt failed
	if (delegate && [delegate respondsToSelector:@selector(connectionControllerConnectAttemptFailed:)]) {
		[[(id)delegate onMainThread] connectionControllerConnectAttemptFailed:self];
	}

	// Only display the connection error message if there is a window visible
	if ([[dbDocument parentWindow] isVisible]) {
		SPBeginAlertSheet(theTitle, NSLocalizedString(@"OK", @"OK button"), (errorDetail) ? NSLocalizedString(@"Show Detail", @"Show detail button") : nil, (isSSHTunnelBindError) ? NSLocalizedString(@"Use Standard Connection", @"use standard connection button") : nil, [dbDocument parentWindow], self, @selector(connectionFailureSheetDidEnd:returnCode:contextInfo:), @"connect", theErrorMessage);
	}
}

/**
 * Alert sheet callback method - invoked when an error sheet is closed.
 */
- (void)connectionFailureSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertAlternateReturn) {
		[errorDetailText setFont:[NSFont userFontOfSize:12]];
		[errorDetailText setAlignment:NSLeftTextAlignment];
		[errorDetailWindow makeKeyAndOrderFront:self];
	}

	// Currently only SSH port bind errors offer a 3rd option in the error dialog, but if this ever changes
	// this will definitely need to be updated.
	else if (returnCode == NSAlertOtherReturn) {

		// Extract the local port number that SSH attempted to bind to from the debug output
		NSString *tunnelPort = [[[errorDetailText string] componentsMatchedByRegex:@"LOCALHOST:([0-9]+)" capture:1L] lastObject];

		// Change the connection type to standard TCP/IP
		[self setType:SPTCPIPConnection];

		// Change connection details
		[self setPort:tunnelPort];
		[self setHost:SPLocalhostAddress];

#ifndef SP_CODA
		// Change to standard TCP/IP connection view
		[self resizeTabViewToConnectionType:SPTCPIPConnection animating:YES];
#endif

		// Initiate the connection after a half second delay to give the connection view a chance to resize
		[self performSelector:@selector(initiateConnection:) withObject:self afterDelay:0.5];
	}
}

#pragma mark - SPConnectionHandlerPrivateAPI

/**
 * Display a connection test error or success message
 */
- (void)_showConnectionTestResult:(NSString *)resultString
{
	if (![NSThread isMainThread]) {
		[[self onMainThread] _showConnectionTestResult:resultString];
	}

	[helpButton setHidden:NO];
	[progressIndicator stopAnimation:self];
	[progressIndicatorText setStringValue:resultString];
	[progressIndicatorText setHidden:NO];
}

#pragma mark - SPConnectionControllerDelegate

#pragma mark SplitView delegate methods

#ifndef SP_CODA

/**
 * When the split view is resized, trigger a resize in the hidden table
 * width as well, to keep the connection view and connected view in sync.
 */
- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
	if (initComplete) {
		[databaseConnectionView setPosition:[[[connectionSplitView subviews] objectAtIndex:0] frame].size.width ofDividerAtIndex:0];
	}
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
	return 145.f;
}

#endif

#pragma mark -
#pragma mark Outline view delegate methods

#ifndef SP_CODA

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	return ([[(SPTreeNode *)item parentNode] parentNode] == nil);
}

- (void)outlineViewSelectionIsChanging:(NSNotification *)notification
{
	if (isEditingConnection) {
		[self _stopEditingConnection];

		[[notification object] setNeedsDisplay:YES];
	}
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	NSInteger selected = [favoritesOutlineView numberOfSelectedRows];

	if (isEditingConnection) {
		[self _stopEditingConnection];
		[[notification object] setNeedsDisplay:YES];
	}

	if (selected == 1) {
		[self updateFavoriteSelection:self];

		favoriteNameFieldWasAutogenerated = NO;
		[connectionResizeContainer setHidden:NO];
		[connectionInstructionsTextField setStringValue:NSLocalizedString(@"Enter connection details below, or choose a favorite", @"enter connection details label")];
	}
	else if (selected > 1) {
		[connectionResizeContainer setHidden:YES];
		[connectionInstructionsTextField setStringValue:NSLocalizedString(@"Please choose a favorite", @"please choose a favorite connection view label")];
	}
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if (item == quickConnectItem) {
		return (NSCell *)quickConnectCell;
	}

	return [tableColumn dataCellForRow:[outlineView rowForItem:item]];
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	SPTreeNode              *node         = (SPTreeNode *)item;
	SPFavoriteTextFieldCell *favoriteCell = (SPFavoriteTextFieldCell *)cell;

	// Draw entries with the small system font by default
	[cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];

	// Set an image as appropriate; the quick connect image for that entry, no image for other
	// top-level items, the folder image for group nodes, or the database image for other nodes.
	if (![[node parentNode] parentNode]) {
		if (node == quickConnectItem) {
			if ([outlineView rowForItem:item] == [outlineView selectedRow]) {
				[favoriteCell setImage:[NSImage imageNamed:SPQuickConnectImageWhite]];
			}
			else {
				[favoriteCell setImage:[NSImage imageNamed:SPQuickConnectImage]];
			}
		}
		else {
			[favoriteCell setImage:nil];
		}
		[favoriteCell setLabelColor:nil];
	}
	else {
		if ([node isGroup]) {
			[favoriteCell setImage:folderImage];
			[favoriteCell setLabelColor:nil];
		}
		else {
			[favoriteCell setImage:[NSImage imageNamed:SPDatabaseImage]];
			NSColor *bgColor = nil;
			NSNumber *colorIndexObj = [[[node representedObject] nodeFavorite] objectForKey:SPFavoriteColorIndexKey];
			if(colorIndexObj != nil) {
				bgColor = [[SPFavoriteColorSupport sharedInstance] colorForIndex:[colorIndexObj integerValue]];
			}
			[favoriteCell setLabelColor:bgColor];
		}
	}

	// If a favourite item is being edited, draw the text in bold to show state
	if (isEditingConnection && ![node isGroup] && [outlineView rowForItem:item] == [outlineView selectedRow]) {
		NSMutableAttributedString *editedCellString = [[cell attributedStringValue] mutableCopy];
		[editedCellString addAttribute:NSForegroundColorAttributeName value:[NSColor colorWithDeviceWhite:0.25f alpha:1.f] range:NSMakeRange(0, [editedCellString length])];
		[cell setAttributedStringValue:editedCellString];
		[editedCellString release];
	}
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	if (item == quickConnectItem) {
		return 24.f;
	}

	return ([[item parentNode] parentNode]) ? 17.f : 22.f;
}

- (NSString *)outlineView:(NSOutlineView *)outlineView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn item:(id)item mouseLocation:(NSPoint)mouseLocation
{
	NSString *toolTip = nil;

	SPTreeNode *node = (SPTreeNode *)item;

	if (![node isGroup]) {

		NSString *favoriteName = [[[node representedObject] nodeFavorite] objectForKey:SPFavoriteNameKey];
		NSString *favoriteHostname = [[[node representedObject] nodeFavorite] objectForKey:SPFavoriteHostKey];

		toolTip = ([favoriteHostname length]) ? [NSString stringWithFormat:@"%@ (%@)", favoriteName, favoriteHostname] : favoriteName;
	}

	// Only display a tooltip for group nodes that are a descendant of the root node
	else if ([[node parentNode] parentNode]) {

		NSUInteger favCount = 0;
		NSUInteger groupCount = 0;

		for (SPTreeNode *eachNode in [node childNodes])
		{
			if ([eachNode isGroup]) {
				groupCount++;
			}
			else {
				favCount++;
			}
		}

		NSMutableArray *tooltipParts = [NSMutableArray arrayWithCapacity:2];

		if (favCount || !groupCount) {
			[tooltipParts addObject:[NSString stringWithFormat:((favCount == 1) ? NSLocalizedString(@"%d favorite", @"favorite singular label (%d == 1)") : NSLocalizedString(@"%d favorites", @"favorites plural label (%d != 1)")), favCount]];
		}

		if (groupCount) {
			[tooltipParts addObject:[NSString stringWithFormat:((groupCount == 1) ? NSLocalizedString(@"%d group", @"favorite group singular label (%d == 1)") : NSLocalizedString(@"%d groups", @"favorite groups plural label (%d != 1)")), groupCount]];
		}

		toolTip = [NSString stringWithFormat:@"%@ - %@", [[node representedObject] nodeName], [tooltipParts componentsJoinedByString:@", "]];
	}

	return toolTip;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	// If this is a top level item, only allow the "Quick Connect" item to be selectable
	if (![[item parentNode] parentNode]) {
		return item == quickConnectItem;
	}

	// Otherwise allow all items to be selectable
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return (item != quickConnectItem && ![item isLeaf]);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item
{
	return ([[item parentNode] parentNode] != nil);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item
{
	return ([[item parentNode] parentNode] != nil);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	NSEvent *event = [NSApp currentEvent];
	BOOL shiftTabbedIn = ([event type] == NSKeyDown && [[event characters] length] && [[event characters] characterAtIndex:0] == NSBackTabCharacter);

	if (shiftTabbedIn && [(SPFavoritesOutlineView *)outlineView justGainedFocus]) {
		return NO;
	}

	return item != quickConnectItem;
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
	[self _setNodeIsExpanded:NO fromNotification:notification];
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
	[self _setNodeIsExpanded:YES fromNotification:notification];
}

#endif

#pragma mark -
#pragma mark Outline view drag & drop

#ifndef SP_CODA

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	// Prevent a drag which includes the outline title group from taking place
	for (id item in items)
	{
		if (![[item parentNode] parentNode]) return NO;
	}

	// If the user is in the process of changing a node's name, trigger a save and prevent dragging.
	if (isEditingItemName) {
		[favoritesController saveFavorites];

		[self _reloadFavoritesViewData];

		isEditingItemName = NO;

		return NO;
	}

	[pboard declareTypes:@[SPFavoritesPasteboardDragType] owner:self];

	BOOL result = [pboard setData:[NSData data] forType:SPFavoritesPasteboardDragType];

	draggedNodes = items;

	return result;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)childIndex
{
	NSDragOperation result = NSDragOperationNone;

	// Prevent the top level or the quick connect item from being a target
	if (!item || item == quickConnectItem) return result;

	// Prevent dropping favorites on other favorites (non-groups)
	if ((childIndex == NSOutlineViewDropOnItemIndex) && (![item isGroup])) return result;

	// Ensure that none of the dragged nodes are being dragged into children of themselves; if they are,
	// prevent the drag.
	id itemToCheck = item;

	do {
		if ([draggedNodes containsObject:itemToCheck]) {
			return result;
		}
	}
	while ((itemToCheck = [itemToCheck parentNode]));

	if ([info draggingSource] == outlineView) {
		[outlineView setDropItem:item dropChildIndex:childIndex];

		result = NSDragOperationMove;
	}

	return result;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)childIndex
{
	BOOL acceptedDrop = NO;

	if ((!item) || ([info draggingSource] != outlineView)) return acceptedDrop;

	SPTreeNode *node = item ? item : [[[[favoritesRoot childNodes] objectAtIndex:0] childNodes] objectAtIndex:0];

	// Cache the selected nodes for selection restoration afterwards
	NSArray *preDragSelection = [self selectedFavoriteNodes];

	// Disable all automatic sorting
	currentSortItem = -1;
	reverseFavoritesSort = NO;

	[prefs setInteger:currentSortItem forKey:SPFavoritesSortedBy];
	[prefs setBool:NO forKey:SPFavoritesSortedInReverse];

	// Uncheck sort by menu items
	for (NSMenuItem *menuItem in [[favoritesSortByMenuItem submenu] itemArray])
	{
		[menuItem setState:NSOffState];
	}

	if (![draggedNodes count]) return acceptedDrop;

	if ([node isGroup]) {
		if (childIndex == NSOutlineViewDropOnItemIndex) {
			childIndex = 0;
		}
		[outlineView expandItem:node];
	}
	else {
		if (childIndex == NSOutlineViewDropOnItemIndex) {
			childIndex = 0;
		}
	}

	if (![[node representedObject] nodeName]) {
		node = [[favoritesRoot childNodes] objectAtIndex:0];
	}

	NSMutableArray *childNodeArray = [node mutableChildNodes];

	for (SPTreeNode *treeNode in draggedNodes)
	{
		// Remove the node from its old location
		NSInteger oldIndex = [childNodeArray indexOfObject:treeNode];
		NSInteger newIndex = childIndex;

		if (oldIndex != NSNotFound) {

			[childNodeArray removeObjectAtIndex:oldIndex];

			if (childIndex > oldIndex) {
				newIndex--;
			}
		}
		else {
			[[[treeNode parentNode] mutableChildNodes] removeObject:treeNode];
		}

		[childNodeArray insertObject:treeNode atIndex:newIndex];

		newIndex++;
	}

	[favoritesController saveFavorites];

	[self _reloadFavoritesViewData];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPConnectionFavoritesChangedNotification object:self];

	[[[SPAppDelegate preferenceController] generalPreferencePane] updateDefaultFavoritePopup];

	// Update the selection to account for rearranged faourites
	NSMutableIndexSet *restoredSelection = [NSMutableIndexSet indexSet];

	for (SPTreeNode *eachNode in preDragSelection)
	{
		[restoredSelection addIndex:[favoritesOutlineView rowForItem:eachNode]];
	}

	[favoritesOutlineView selectRowIndexes:restoredSelection byExtendingSelection:NO];

	acceptedDrop = YES;

	return acceptedDrop;
}

#endif

#pragma mark -
#pragma mark Textfield delegate methods

#ifndef SP_CODA

/**
 * React to control text changes in the connection interface
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	id field = [notification object];

	// Ignore changes in the outline view edit fields
	if ([field isKindOfClass:[NSOutlineView class]]) {
		return;
	}

	// If a 'name' field was edited, and is now of zero length, trigger a replacement
	// with a standard suggestion
	if (((field == standardNameField) || (field == socketNameField) || (field == sshNameField)) && [self selectedFavoriteNode]) {
		if (![[self _stripInvalidCharactersFromString:[field stringValue]] length]) {
			[self controlTextDidEndEditing:notification];
		}
	}

	[self _startEditingConnection];

	if (favoriteNameFieldWasAutogenerated && (field != standardNameField && field != socketNameField && field != sshNameField)) {
		[self setName:[self _generateNameForConnection]];
	}
}

/**
 * React to the end of control text changes in the connection interface.
 */
- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	id field = [notification object];

	// Handle updates to the 'name' field of the selected favourite.  The favourite name should
	// have leading or trailing spaces removed at the end of editing, and if it's left empty,
	// should have a default name set.
	if (((field == standardNameField) || (field == socketNameField) || (field == sshNameField)) && [self selectedFavoriteNode]) {

		NSString *favoriteName = [self _stripInvalidCharactersFromString:[field stringValue]];

		if (![favoriteName length]) {
			favoriteName = [self _generateNameForConnection];

			if (favoriteName) {
				[self setName:favoriteName];
			}

			// Enable user@host update in reaction to other UI changes
			favoriteNameFieldWasAutogenerated = YES;
		}
		else if (![[field stringValue] isEqualToString:[self _generateNameForConnection]]) {
			favoriteNameFieldWasAutogenerated = NO;
			[self setName:favoriteName];
		}
	}

	// When a host field finishes editing, ensure that it hasn't been set to "localhost" to
	// ensure that socket connections don't inadvertently occur.
	if (field == standardSQLHostField || field == sshSQLHostField) {
		[self _checkHost];
	}
}

#endif

#pragma mark -
#pragma mark Tab bar delegate methods

#ifndef SP_CODA

/**
 * Trigger a resize action whenever the tab view changes. The connection
 * detail forms are held within container views, which are of a fixed width;
 * the tabview and buttons are contained within a resizable view which
 * is set to dimensions based on the container views, allowing the view
 * to be sized according to the detail type.
 */
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	NSInteger selectedTabView = [tabView indexOfTabViewItem:tabViewItem];

	if (selectedTabView == previousType) return;

	[self _startEditingConnection];

	[self resizeTabViewToConnectionType:selectedTabView animating:YES];

	// Update the host as appropriate
	if ((selectedTabView != SPSocketConnection) && [[self host] isEqualToString:@"localhost"]) {
		[self setHost:@""];
	}

	previousType = selectedTabView;

	[self _favoriteTypeDidChange];
}

#endif

#pragma mark -
#pragma mark Color Selector delegate

- (void)colorSelectorDidChange:(SPColorSelectorView *)sel
{
	[self _startEditingConnection];
}

#pragma mark -
#pragma mark Scroll view notifications

#ifndef SP_CODA

/**
 * As the scrollview resizes, keep the details centered within it if
 * the detail frame is larger than the scrollview size; otherwise, pin
 * the detail frame to the top of the scrollview.
 */
- (void)scrollViewFrameChanged:(NSNotification *)aNotification
{
	NSRect scrollViewFrame = [connectionDetailsScrollView frame];
	NSRect scrollDocumentFrame = [[connectionDetailsScrollView documentView] frame];
	NSRect connectionDetailsFrame = [connectionResizeContainer frame];

	// Scroll view is smaller than contents - keep positioned at top.
	if (scrollViewFrame.size.height < connectionDetailsFrame.size.height + 10) {
		if (connectionDetailsFrame.origin.y != 0) {
			connectionDetailsFrame.origin.y = 0;
			[connectionResizeContainer setFrame:connectionDetailsFrame];
			scrollDocumentFrame.size.height = connectionDetailsFrame.size.height + 10;
			[[connectionDetailsScrollView documentView] setFrame:scrollDocumentFrame];
		}
	}
	// Otherwise, center
	else {
		connectionDetailsFrame.origin.y = (scrollViewFrame.size.height - connectionDetailsFrame.size.height)/3;
		// the division may lead to values that are not valid for the current screen size (e.g. non-integer values on a
		// @1x non-retina screen). The OS works something out when not using layer-backed views, but in the latter
		// case the result will look like garbage if we don't fix this.
		if(isOSAtLeast10_7) {
			connectionDetailsFrame = [connectionDetailsScrollView backingAlignedRect:connectionDetailsFrame options:NSAlignAllEdgesNearest];
		}
		else {
			// This code is taken from Apple's "BlurryView" example code.
			connectionDetailsFrame = [[connectionDetailsScrollView superview] convertRectToBase:connectionDetailsFrame];
			connectionDetailsFrame.origin.y = round(connectionDetailsFrame.origin.y);
			connectionDetailsFrame = [[connectionDetailsScrollView superview] convertRectFromBase:connectionDetailsFrame];
		}
		[connectionResizeContainer setFrame:connectionDetailsFrame];
		scrollDocumentFrame.size.height = scrollViewFrame.size.height;
		[[connectionDetailsScrollView documentView] setFrame:scrollDocumentFrame];
	}
}

#endif

#pragma mark -
#pragma mark Menu Validation

#ifndef SP_CODA

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];

	SPTreeNode *node = [self selectedFavoriteNode];
	NSInteger selectedRows = [favoritesOutlineView numberOfSelectedRows];

	if ((action == @selector(sortFavorites:)) || (action == @selector(reverseSortFavorites:))) {

		if ([[favoritesRoot allChildLeafs] count] < 2) return NO;

		// Loop all the items in the sort by menu only checking the currently selected one
		for (NSMenuItem *item in [[menuItem menu] itemArray])
		{
			[item setState:([[menuItem menu] indexOfItem:item] == currentSortItem)];
		}

		// Check or uncheck the reverse sort item
		if (action == @selector(reverseSortFavorites:)) {
			[menuItem setState:reverseFavoritesSort];
		}

		return YES;
	}

	// import does not depend on a selection
	if(action == @selector(importFavorites:)) return YES;

	if (node == quickConnectItem) return NO;

	// Remove/rename the selected node
	if (action == @selector(removeNode:) || action == @selector(renameNode:)) {
		return selectedRows == 1;
	}

	// Duplicate and make the selected favorite the default
	if (action == @selector(duplicateFavorite:)) {
		return ((selectedRows == 1) && (![node isGroup]));
	}

	// Make selected favorite the default
	if (action == @selector(makeSelectedFavoriteDefault:)) {
		NSInteger favoriteID = [[[self selectedFavorite] objectForKey:SPFavoriteIDKey] integerValue];

		return ((selectedRows == 1) && (![node isGroup]) && (favoriteID != [prefs integerForKey:SPDefaultFavorite]));
	}

	// Favorites export
	if (action == @selector(exportFavorites:)) {

		if ([[favoritesRoot allChildLeafs] count] == 0 || selectedRows == 0) {
			return NO;
		}
		else if (selectedRows > 1) {
			[menuItem setTitle:NSLocalizedString(@"Export Selected...", @"export selected favorites menu item")];
		}
	}

	return YES;
}

#endif

#pragma mark -
#pragma mark Favorites import/export delegate methods

#ifndef SP_CODA

/**
 * Called by the favorites importer when the imported data is available.
 */
- (void)favoritesImportData:(NSArray *)data
{
	SPTreeNode *newNode;
	NSMutableArray *importedNodes = [NSMutableArray array];
	NSMutableIndexSet *importedIndexSet = [NSMutableIndexSet indexSet];

	// Add each of the imported favorites to the root node
	for (NSMutableDictionary *favorite in data)
	{
		newNode = [favoritesController addFavoriteNodeWithData:favorite asChildOfNode:nil];
		[importedNodes addObject:newNode];
	}

	if (currentSortItem > SPFavoritesSortUnsorted) {
		[self _sortFavorites];
	}

	[self _reloadFavoritesViewData];

	// Select the new nodes and scroll into view
	for (SPTreeNode *eachNode in importedNodes)
	{
		[importedIndexSet addIndex:[favoritesOutlineView rowForItem:eachNode]];
	}

	[favoritesOutlineView selectRowIndexes:importedIndexSet byExtendingSelection:NO];

	[self _scrollToSelectedNode];
}

/**
 * Called by the favorites importer when the import completes.
 */
- (void)favoritesImportCompletedWithError:(NSError *)error
{
	if (error) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Favorites import error", @"favorites import error message")
		                                 defaultButton:NSLocalizedString(@"OK", @"OK")
		                               alternateButton:nil
		                                   otherButton:nil
		                     informativeTextWithFormat:NSLocalizedString(@"The following error occurred during the import process:\n\n%@", @"favorites import error informative message"), [error localizedDescription]];

		[alert beginSheetModalForWindow:[dbDocument parentWindow]
		                  modalDelegate:nil
		                 didEndSelector:NULL
		                    contextInfo:NULL];
	}
}

#endif

#pragma mark -
#pragma mark Private API

#ifndef SP_CODA

/**
 * Sets the expanded state of the node from the supplied outline view notification.
 *
 * @param expanded     The state of the node
 * @param notification The notification genrated from the state change
 */
- (void)_setNodeIsExpanded:(BOOL)expanded fromNotification:(NSNotification *)notification
{
	SPGroupNode *node = [[[notification userInfo] valueForKey:@"NSObject"] representedObject];

	[node setNodeIsExpanded:expanded];
}

#endif

#pragma mark - SPConnectionControllerInitializer

/**
 * Initialise the connection controller, linking it to the parent document and setting up the parent window.
 */
- (id)initWithDocument:(SPDatabaseDocument *)document
{
	if ((self = [super init])) {

		// Weak reference
		dbDocument = document;

#ifndef SP_CODA
		databaseConnectionSuperview = [dbDocument databaseView];
#warning Private ivar accessed from outside (#2978)
		databaseConnectionView = [dbDocument valueForKey:@"contentViewSplitter"];
#endif

		// Keychain references
		connectionKeychainItemName = nil;
		connectionKeychainItemAccount = nil;
		connectionSSHKeychainItemName = nil;
		connectionSSHKeychainItemAccount = nil;

		initComplete = NO;
		isEditingItemName = NO;
		isConnecting = NO;
		isTestingConnection = NO;
		sshTunnel = nil;
		mySQLConnection = nil;
		cancellingConnection = NO;
		favoriteNameFieldWasAutogenerated = NO;

		[self loadNib];

		NSArray *colorList = [[SPFavoriteColorSupport sharedInstance] userColorList];
		[sshColorField setColorList:colorList];
		[sshColorField      bind:@"selectedTag" toObject:self withKeyPath:@"colorIndex" options:nil];
		[standardColorField setColorList:colorList];
		[standardColorField bind:@"selectedTag" toObject:self withKeyPath:@"colorIndex" options:nil];
		[socketColorField setColorList:colorList];
		[socketColorField   bind:@"selectedTag" toObject:self withKeyPath:@"colorIndex" options:nil];

		[self registerForNotifications];

#ifndef SP_CODA
		// Hide the main view and position and display the connection view
		[databaseConnectionView setHidden:YES];
		[connectionView setFrame:[databaseConnectionView frame]];
		[databaseConnectionSuperview addSubview:connectionView];

		// Set up the splitview
		[connectionSplitView setMinSize:80.f ofSubviewAtIndex:0];
		[connectionSplitView setMinSize:445.f ofSubviewAtIndex:1];

		// Generic folder image for use in the outline view's groups
		folderImage = [[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)] retain];
		[folderImage setSize:NSMakeSize(16, 16)];

		// Set up a keychain instance and preferences reference, and create the initial favorites list
		keychain = [[SPKeychain alloc] init];
		prefs = [[NSUserDefaults standardUserDefaults] retain];

		// Create a reference to the favorites controller, forcing the data to be loaded from disk
		// and the tree to be constructed.
		favoritesController = [SPFavoritesController sharedFavoritesController];

		// Tree references
		favoritesRoot = [favoritesController favoritesTree];
		currentFavorite = nil;

		// Create the "Quick Connect" placeholder group
		quickConnectItem = [[SPTreeNode treeNodeWithRepresentedObject:[SPGroupNode groupNodeWithName:[NSLocalizedString(@"Quick Connect", @"Quick connect item label") uppercaseString]]] retain];
		[quickConnectItem setIsGroup:YES];

		// Create a NSOutlineView cell for the Quick Connect group
		quickConnectCell = [[SPFavoriteTextFieldCell alloc] init];
		[quickConnectCell setDrawsDividerUnderCell:YES];
		[quickConnectCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];

		// Update the UI
		[self _reloadFavoritesViewData];
		[self setUpFavoritesOutlineView];
		[self _restoreOutlineViewStateNode:favoritesRoot];

		// Set up the selected favourite, and scroll after a small delay to fix animation delay on Lion
		[self setUpSelectedConnectionFavorite];
		if ([favoritesOutlineView selectedRow] != -1) {
			[self performSelector:@selector(_scrollToSelectedNode) withObject:nil afterDelay:0.0];
		}

		// Set sort items
		currentSortItem = (SPFavoritesSortItem)[prefs integerForKey:SPFavoritesSortedBy];
		reverseFavoritesSort = [prefs boolForKey:SPFavoritesSortedInReverse];
#endif

		initComplete = YES;
	}

	return self;
}

/**
 * Loads the connection controllers UI nib.
 */
- (void)loadNib
{
#ifndef SP_CODA

	// Load the connection nib, keeping references to the top-level objects for later release
	nibObjectsToRelease = [[NSMutableArray alloc] init];

	NSArray *connectionViewTopLevelObjects = nil;
	NSNib *nibLoader = [[NSNib alloc] initWithNibNamed:SPConnectionViewNibName bundle:[NSBundle mainBundle]];

	[nibLoader instantiateNibWithOwner:self topLevelObjects:&connectionViewTopLevelObjects];
	[nibObjectsToRelease addObjectsFromArray:connectionViewTopLevelObjects];
	[nibLoader release];

#endif
}

/**
 * Registers for various notifications.
 */
- (void)registerForNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(_documentWillClose:)
	                                             name:SPDocumentWillCloseNotification
	                                           object:dbDocument];

#ifndef SP_CODA
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(scrollViewFrameChanged:)
	                                             name:NSViewFrameDidChangeNotification
	                                           object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(_processFavoritesDataChange:)
	                                             name:SPConnectionFavoritesChangedNotification
	                                           object:nil];

	// Registered to be notified of changes to connection information
	[self addObserver:self
	       forKeyPath:SPFavoriteTypeKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteNameKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteHostKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteUserKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteColorIndexKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteDatabaseKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteSocketKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoritePortKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteUseSSLKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteSSHHostKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteSSHUserKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteSSHPortKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteSSHKeyLocationEnabledKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteSSHKeyLocationKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteSSLKeyFileLocationEnabledKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteSSLKeyFileLocationKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteSSLCertificateFileLocationEnabledKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteSSLCertificateFileLocationKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteSSLCACertFileLocationEnabledKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];

	[self addObserver:self
	       forKeyPath:SPFavoriteSSLCACertFileLocationKey
	          options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
	          context:NULL];
#endif
}

/**
 * Performs any set up necessary for the favorities outline view.
 */
- (void)setUpFavoritesOutlineView
{
	// Register double click action for the favorites outline view (double click favorite to connect)
	[favoritesOutlineView setTarget:self];
	[favoritesOutlineView setDoubleAction:@selector(nodeDoubleClicked:)];

	// Register drag types for the favorites outline view
	[favoritesOutlineView registerForDraggedTypes:@[SPFavoritesPasteboardDragType]];
	[favoritesOutlineView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
}

/**
 * Sets up the selected connection favorite according to the user's preferences.
 */
- (void)setUpSelectedConnectionFavorite
{
#ifndef SP_CODA
	SPTreeNode *favorite = [self _favoriteNodeForFavoriteID:[prefs integerForKey:[prefs boolForKey:SPSelectLastFavoriteUsed] ? SPLastFavoriteID : SPDefaultFavorite]];

	if (favorite) {

		if (favorite == quickConnectItem) {
			[self _selectNode:favorite];
		}
		else {
			NSNumber *typeNumber = [[[favorite representedObject] nodeFavorite] objectForKey:SPFavoriteTypeKey];
			previousType = typeNumber ? [typeNumber integerValue] : SPTCPIPConnection;

			[self _selectNode:favorite];
			[self resizeTabViewToConnectionType:[[[[favorite representedObject] nodeFavorite] objectForKey:SPFavoriteTypeKey] integerValue] animating:NO];
		}

		[self _scrollToSelectedNode];
	}
	else {
		previousType = SPTCPIPConnection;

		[self resizeTabViewToConnectionType:SPTCPIPConnection animating:NO];
	}
#endif
}

#pragma mark -
#pragma mark Private API

/**
 * Responds to notifications that the favorites root has changed,
 * and updates the interface to match.
 */
- (void)_processFavoritesDataChange:(NSNotification *)aNotification
{
#ifndef SP_CODA
	// Check the supplied notification for the sender; if the sender
	// was this object, ignore it
	if ([aNotification object] == self) return;

	NSArray *selectedFavoriteNodes = [self selectedFavoriteNodes];

	[self _reloadFavoritesViewData];

	NSMutableIndexSet *selectionIndexes = [NSMutableIndexSet indexSet];

	for (SPTreeNode *eachNode in selectedFavoriteNodes)
	{
		NSInteger anIndex = [favoritesOutlineView rowForItem:eachNode];

		if (anIndex == -1) continue;

		[selectionIndexes addIndex:anIndex];
	}

	[favoritesOutlineView selectRowIndexes:selectionIndexes byExtendingSelection:NO];
#endif
}

/**
 * Restores the outline views group nodes expansion state.
 *
 * @param node The node to traverse
 */
#ifndef SP_CODA
- (void)_restoreOutlineViewStateNode:(SPTreeNode *)node
{
	if ([node isGroup]) {
		if ([[node representedObject] nodeIsExpanded]) {
			[favoritesOutlineView expandItem:node];
		}
		else {
			[favoritesOutlineView collapseItem:node];
		}

		for (SPTreeNode *childNode in [node childNodes])
		{
			if ([childNode isGroup]) {
				[self _restoreOutlineViewStateNode:childNode];
			}
		}
	}
}
#endif

#pragma mark - SPConnectionControllerDataSource

#ifndef SP_CODA

/**
 * Return the number of children for the specified item in the favourites tree.
 * Note that to support the "Quick Connect" entry, the returned count is amended
 * for the top level.
 */
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	SPTreeNode *node = (item == nil ? favoritesRoot : (SPTreeNode *)item);

	// If at the root, return the count plus one for the "Quick Connect" entry
	if (!item) {
		return [[node childNodes] count] + 1;
	}

	return [[node childNodes] count];
}

/**
 * Return the branch at the specified index of a supplied tree level.
 * Note that to support the "Quick Connect" entry, children of the top level
 * have their offsets amended.
 */
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)childIndex ofItem:(id)item
{
	// For the top level of the tree, return the "Quick Connect" child for position zero;
	// amend all other positions to compensate for the faked position.
	if (!item) {
		if (childIndex == 0) {
			return quickConnectItem;
		}

		childIndex--;
	}

	SPTreeNode *node = (item == nil ? favoritesRoot : (SPTreeNode *)item);

	return NSArrayObjectAtIndex([node childNodes], childIndex);
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	SPTreeNode *node = (SPTreeNode *)item;

	return (![node isGroup]) ? [[[node representedObject] nodeFavorite] objectForKey:SPFavoriteNameKey] : [[node representedObject] nodeName];
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	NSString *newName = [object stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	if ([newName length]) {

		// Get the node that was renamed
		SPTreeNode *node = [self selectedFavoriteNode];

		if (![node isGroup]) {

			// Updating the name triggers a KVO update
			[self setName:newName];
			[self _saveCurrentDetailsCreatingNewFavorite:NO validateDetails:NO];
		}
		else {
			[[node representedObject] setNodeName:newName];

			[favoritesController saveFavorites];

			[self _reloadFavoritesViewData];
		}
	}
}

#endif

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	// Unregister observers
#ifndef SP_CODA
	[self removeObserver:self forKeyPath:SPFavoriteTypeKey];
	[self removeObserver:self forKeyPath:SPFavoriteNameKey];
	[self removeObserver:self forKeyPath:SPFavoriteHostKey];
	[self removeObserver:self forKeyPath:SPFavoriteUserKey];
	[self removeObserver:self forKeyPath:SPFavoriteColorIndexKey];
	[self removeObserver:self forKeyPath:SPFavoriteDatabaseKey];
	[self removeObserver:self forKeyPath:SPFavoriteSocketKey];
	[self removeObserver:self forKeyPath:SPFavoritePortKey];
	[self removeObserver:self forKeyPath:SPFavoriteUseSSLKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSHHostKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSHUserKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSHPortKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSHKeyLocationEnabledKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSHKeyLocationKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSLKeyFileLocationEnabledKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSLKeyFileLocationKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSLCertificateFileLocationEnabledKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSLCertificateFileLocationKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSLCACertFileLocationEnabledKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSLCACertFileLocationKey];
#endif
	
#ifndef SP_CODA
	SPClear(keychain);
#endif
	SPClear(prefs);

#ifndef SP_CODA
	SPClear(folderImage);
	SPClear(quickConnectItem);
	SPClear(quickConnectCell);
#endif
    
	for (id retainedObject in nibObjectsToRelease) [retainedObject release];

	SPClear(nibObjectsToRelease);

	[self setConnectionKeychainID:nil];
	if (connectionKeychainItemName)       SPClear(connectionKeychainItemName);
	if (connectionKeychainItemAccount)    SPClear(connectionKeychainItemAccount);
	if (connectionSSHKeychainItemName)    SPClear(connectionSSHKeychainItemName);
	if (connectionSSHKeychainItemAccount) SPClear(connectionSSHKeychainItemAccount);

#ifndef SP_CODA
	if (currentFavorite) SPClear(currentFavorite);
#endif
	
	[super dealloc];
}

#ifndef SP_CODA

/**
 * Called by the favorites exporter when the export completes.
 */
- (void)favoritesExportCompletedWithError:(NSError *)error
{
	if (error) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Favorites export error", @"favorites export error message")
		                                 defaultButton:NSLocalizedString(@"OK", @"OK")
		                               alternateButton:nil
		                                   otherButton:nil
		                     informativeTextWithFormat:NSLocalizedString(@"The following error occurred during the export process:\n\n%@", @"favorites export error informative message"), [error localizedDescription]];

		[alert beginSheetModalForWindow:[dbDocument parentWindow]
		                  modalDelegate:self
		                 didEndSelector:NULL
		                    contextInfo:NULL];
	}
}
#endif

@end

#pragma mark -

BOOL FindLinesInFile(NSData *fileData,const void *first,size_t first_len,const void *second,size_t second_len)
{
	__block BOOL firstMatch = NO;
	__block BOOL secondMatch = NO;
	[fileData enumerateLinesBreakingAt:SPLineTerminatorAny withBlock:^(NSRange line, BOOL *stop) {
		if(!firstMatch) {
			if(line.length != first_len) return;
			if(memcmp(first, ([fileData bytes]+line.location), first_len) == 0) {
				firstMatch = YES;
			}
		}
		else {
			if(line.length != second_len) return;
			if(memcmp(second, ([fileData bytes]+line.location), second_len) == 0) {
				secondMatch = YES;
				*stop = YES;
			}
		}
	}];
	
	return (firstMatch && secondMatch);
}

//
//  $Id$
//
//  SPConnectionControllerDataChangeHandler.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on August 13, 2012.
//  Copyright (c) 2012 Stuart Connolly. All rights reserved.
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

#import "SPConnectionControllerDataChangeHandler.h"
#import "SPFavoritesController.h"
#import "SPKeychain.h"

static NSString *SPFavoritesNextNodeKey = @"SPFavoritesNextNode";
static NSString *SPFavoritesCurrentNodeChangesKey = @"SPFavoritesCurrentNodeChanges";

@interface SPConnectionController ()

- (void)_selectNode:(SPTreeNode *)node;
- (void)_applyFavoriteChanges:(NSDictionary *)changes;
- (void)_createNewFavoriteWithDetails:(NSDictionary *)details;
- (void)_applyFavoriteChanges:(NSDictionary *)changes toFavorite:(NSDictionary *)favorite;
- (void)_updatePasswordsForFavorite:(NSDictionary *)favorite withChanges:(NSDictionary *)changes;

- (NSString *)_stripInvalidCharactersFromString:(NSString *)subject;

@end

@implementation SPConnectionController (SPConnectionControllerDataChangeHandler)

/**
 * Determines whether or not the connection details have changed between those in the UI 
 * or the selected favorite, if any.
 *
 * @note This method also handles newly entered connection (details), but only if enough detail
 *       has been entered for it to be saved.
 *
 * @return A dictionary of changes (key = favorite key, value = favorite value).
 */
/*- (NSDictionary *)determineFavoriteDataChanges
{
	NSMutableDictionary *changes = [NSMutableDictionary dictionary];
	NSMutableDictionary *fieldMapping = [[NSMutableDictionary alloc] init];
	
	[fieldMapping setObject:[self name] forKey:SPFavoriteNameKey];
	[fieldMapping setObject:[self user] forKey:SPFavoriteUserKey];
	[fieldMapping setObject:[self database] forKey:SPFavoriteDatabaseKey];
	
	NSMutableDictionary *favorite = [self selectedFavorite];
	
	if (type == SPTCPIPConnection) {
		[fieldMapping setObject:[self host] forKey:SPFavoriteHostKey];
		[fieldMapping setObject:[self port] forKey:SPFavoritePortKey];
	}
	else if (type == SPSocketConnection) {
		[fieldMapping setObject:[self socket] forKey:SPFavoriteSocketKey];
	}
	else if (type == SPSSHTunnelConnection) {
		[fieldMapping setObject:[self host] forKey:SPFavoriteHostKey];
		[fieldMapping setObject:[self port] forKey:SPFavoritePortKey];
		[fieldMapping setObject:[self sshHost] forKey:SPFavoriteSSHHostKey];
		[fieldMapping setObject:[self sshUser] forKey:SPFavoriteSSHUserKey];
		[fieldMapping setObject:[self sshPort] forKey:SPFavoriteSSHPortKey];
	}
	
	if (type == SPTCPIPConnection || type == SPSocketConnection) {
		[fieldMapping setObject:[NSNumber numberWithInteger:[self useSSL]] forKey:SPFavoriteUseSSLKey];
		
		if ([favorite objectForKey:SPFavoriteSSLKeyFileLocationKey]) {
			[fieldMapping setObject:[self sslKeyFileLocation] forKey:SPFavoriteSSLKeyFileLocationKey];
		}
		
		if ([favorite objectForKey:SPFavoriteSSLCertificateFileLocationKey]) {
			[fieldMapping setObject:[self sslCertificateFileLocation] forKey:SPFavoriteSSLCertificateFileLocationKey];
		}
		
		if ([favorite objectForKey:SPFavoriteSSLCACertFileLocationKey]) {
			[fieldMapping setObject:[self sslCACertFileLocation] forKey:SPFavoriteSSLCACertFileLocationKey];
		}
	}
	
	if (!favorite) {
		for (NSString *key in [fieldMapping allKeys])
		{
			id fieldValue = [fieldMapping objectForKey:key];
			
			if (([fieldValue isKindOfClass:[NSString class]] && [fieldValue length]) || [fieldValue isKindOfClass:[NSNumber class]]) {
				[changes setObject:fieldValue forKey:key];
			}
		}
		
		// For new favorites add the type so we know what to save it as
		if ([changes count]) {
			[changes setObject:[NSNumber numberWithUnsignedInteger:[self type]] forKey:SPFavoriteTypeKey];
		}
	}
	else {
		for (NSString *key in [fieldMapping allKeys])
		{
			id object = [fieldMapping objectForKey:key];
			
			if ([object isKindOfClass:[NSString class]]) {
				if (![object isEqualToString:[favorite objectForKey:key]]) {
					[changes setObject:[fieldMapping objectForKey:key] forKey:key];
				}
			}
			else if ([object isKindOfClass:[NSNumber class]]) {
				if (![object isEqualTo:[favorite objectForKey:key]]) {
					[changes setObject:[fieldMapping objectForKey:key] forKey:key];
				}
			}
		}
	}
	
	[fieldMapping release];
	
	return changes;
}*/

/**
 * Prompts the user about any usaved favorite changes they have made.
 *
 * @param changes A dictionary representing the changes that have been made
 * @param node    The node that the user selected to trigger the unsaved changes warning.
 */
/*- (void)promptToSaveFavoriteChanges:(NSDictionary *)changes whenSelectingNode:(SPFavoriteNode *)node
{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Save changes to favorite?", @"save favorite changes message")
									 defaultButton:NSLocalizedString(@"Save", @"save button")
								   alternateButton:NSLocalizedString(@"Don't Save", @"don't save button")
									   otherButton:NSLocalizedString(@"Cancel", @"cancel button")
						 informativeTextWithFormat:NSLocalizedString(@"If you don't save the changes, they will be lost", @"save favorite changes informative message")];	
	
	[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\e"];
	[[[alert buttons] objectAtIndex:2] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[[alert buttons] objectAtIndex:2] setKeyEquivalent:@"d"];
	
	NSDictionary *data = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects:node, changes, nil] 
													   forKeys:[NSArray arrayWithObjects:SPFavoritesNextNodeKey, SPFavoritesCurrentNodeChangesKey, nil]];
	
	
	[alert beginSheetModalForWindow:[dbDocument parentWindow] 
					  modalDelegate:self
					 didEndSelector:@selector(_unsavedFavoriteChangesSheetDidEnd:returnCode:contextInfo:)
						contextInfo:data];
}*/

#pragma mark -
#pragma mark Private API

/**
 * Unasaved favorites changes warning callback.
 */
/*- (void)_unsavedFavoriteChangesSheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSDictionary *)contextInfo
{
	SPTreeNode *nextNode = [contextInfo objectForKey:SPFavoritesNextNodeKey];
	
	if (returnCode == NSAlertDefaultReturn) {				
		[self _applyFavoriteChanges:[contextInfo objectForKey:SPFavoritesCurrentNodeChangesKey] toFavorite:[self selectedFavorite]];
		
		[self _selectNode:nextNode];
	}
	// Don't save changes, just select the intended node
	else if (returnCode == NSAlertAlternateReturn) {
		[self _selectNode:nextNode];
	}
	
	[contextInfo release];
}*/

- (void)_applyFavoriteChanges:(NSDictionary *)changes toFavorite:(NSMutableDictionary *)favorite
{
	// Update passwords before we apply the changes so we know what to update
	if ([changes count]) {
		[self _updatePasswordsForFavorite:favorite withChanges:changes];
	}
	
	for (NSString *key in [changes allKeys]) 
	{
		id object = [changes objectForKey:key];
		
		if ([object isKindOfClass:[NSString class]]) {
			object = [self _stripInvalidCharactersFromString:object];
		}
		
		[favorite setObject:object forKey:key];
	}
	
	[favoritesController saveFavorites];
}

- (void)_updatePasswordsForFavorite:(NSDictionary *)favorite withChanges:(NSDictionary *)changes
{
	/*NSString *passwordValue;
	NSString *oldKeychainName, *newKeychainName;
	NSString *oldKeychainAccount, *newKeychainAccount;
	NSString *oldHostnameForPassword = ([[favorite objectForKey:SPFavoriteTypeKey] integerValue] == SPSocketConnection) ? @"localhost" : [favorite objectForKey:SPFavoriteHostKey];
	NSString *newHostnameForPassword = ([[changes objectForKey:SPFavoriteTypeKey] integerValue] == SPSocketConnection) ? @"localhost" : [changes objectForKey:SPFavoriteHostKey];
	
	// SQL passwords are indexed by name, host, user and database. If any of these
	// have changed, or a standard password field has, alter the keychain item to match.
	if (![[favorite objectForKey:SPFavoriteNameKey] isEqualToString:[changes objectForKey:SPFavoriteNameKey]] ||
		![oldHostnameForPassword isEqualToString:newHostnameForPassword] ||
		![[favorite objectForKey:SPFavoriteUserKey] isEqualToString:[changes objectForKey:SPFavoriteUserKey]] ||
		![[favorite objectForKey:SPFavoriteDatabaseKey] isEqualToString:[changes objectForKey:SPFavoriteDatabaseKey]])
	{
		// Determine the correct password field to read the password from, defaulting to standard
		if (control == socketPasswordField) {
			passwordValue = [socketPasswordField stringValue];
		} 
		else if (control == sshPasswordField) {
			passwordValue = [sshPasswordField stringValue];
		} 
		else {
			passwordValue = [standardPasswordField stringValue];
		}
		
		// Get the old keychain name and account strings
		oldKeychainName = [keychain nameForFavoriteName:[oldFavorite objectForKey:SPFavoriteNameKey] id:[newFavorite objectForKey:SPFavoriteIDKey]];
		oldKeychainAccount = [keychain accountForUser:[oldFavorite objectForKey:SPFavoriteUserKey] host:oldHostnameForPassword database:[oldFavorite objectForKey:SPFavoriteDatabaseKey]];
		
		// If there's no new password, remove the old item from the keychain
		if (![passwordValue length]) {
			[keychain deletePasswordForName:oldKeychainName account:oldKeychainAccount];
			
			// Otherwise, set up the new keychain name and account strings and create or edit the item
		} else {
			newKeychainName = [keychain nameForFavoriteName:[newFavorite objectForKey:SPFavoriteNameKey] id:[newFavorite objectForKey:SPFavoriteIDKey]];
			newKeychainAccount = [keychain accountForUser:[newFavorite objectForKey:SPFavoriteUserKey] host:newHostnameForPassword database:[newFavorite objectForKey:SPFavoriteDatabaseKey]];
			if ([keychain passwordExistsForName:oldKeychainName account:oldKeychainAccount]) {
				[keychain updateItemWithName:oldKeychainName account:oldKeychainAccount toName:newKeychainName account:newKeychainAccount password:passwordValue];
			} else {
				[keychain addPassword:passwordValue forName:newKeychainName account:newKeychainAccount];
			}
		}
		
		// Synch password changes
		[standardPasswordField setStringValue:passwordValue?passwordValue:@""];
		[socketPasswordField setStringValue:passwordValue?passwordValue:@""];
		[sshPasswordField setStringValue:passwordValue?passwordValue:@""];
		
		passwordValue = @"";
	}
	
	// If SSH account/password details have changed, update the keychain to match
	if (![[oldFavorite objectForKey:SPFavoriteNameKey] isEqualToString:[newFavorite objectForKey:SPFavoriteNameKey]] ||
		![[oldFavorite objectForKey:SPFavoriteSSHHostKey] isEqualToString:[newFavorite objectForKey:SPFavoriteSSHHostKey]] ||
		![[oldFavorite objectForKey:SPFavoriteSSHUserKey] isEqualToString:[newFavorite objectForKey:SPFavoriteSSHUserKey]] ||
		control == sshSSHPasswordField) 
	{
		// Get the old keychain name and account strings
		oldKeychainName = [keychain nameForSSHForFavoriteName:[oldFavorite objectForKey:SPFavoriteNameKey] id:[newFavorite objectForKey:SPFavoriteIDKey]];
		oldKeychainAccount = [keychain accountForSSHUser:[oldFavorite objectForKey:SPFavoriteSSHUserKey] sshHost:[oldFavorite objectForKey:SPFavoriteSSHHostKey]];
		
		// If there's no new password, delete the keychain item
		if (![[sshSSHPasswordField stringValue] length]) {
			[keychain deletePasswordForName:oldKeychainName account:oldKeychainAccount];
			
			// Otherwise, set up the new keychain name and account strings and create or update the keychain item
		} else {
			newKeychainName = [keychain nameForSSHForFavoriteName:[newFavorite objectForKey:SPFavoriteNameKey] id:[newFavorite objectForKey:SPFavoriteIDKey]];
			newKeychainAccount = [keychain accountForSSHUser:[newFavorite objectForKey:SPFavoriteSSHUserKey] sshHost:[newFavorite objectForKey:SPFavoriteSSHHostKey]];
			if ([keychain passwordExistsForName:oldKeychainName account:oldKeychainAccount]) {
				[keychain updateItemWithName:oldKeychainName account:oldKeychainAccount toName:newKeychainName account:newKeychainAccount password:[sshSSHPasswordField stringValue]];
			} else {
				[keychain addPassword:[sshSSHPasswordField stringValue] forName:newKeychainName account:newKeychainAccount];
			}
		}
	}*/
}

@end

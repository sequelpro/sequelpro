//
//  SPNetworkPreferencePane.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 31, 2010.
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

#import "SPNetworkPreferencePane.h"

static NSString *SPSSLCipherListMarkerItem = @"--";
static NSString *SPSSLCipherPboardTypeName = @"SSLCipherPboardType";

@interface SPNetworkPreferencePane ()
- (void)updateHiddenFiles;
- (void)loadSSLCiphers;
- (void)storeSSLCiphers;
+ (NSArray *)defaultSSLCipherList;
@end

@implementation SPNetworkPreferencePane

- (instancetype)init
{
	self = [super init];
	if (self) {
		sslCiphers = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	SPClear(sslCiphers);
	[super dealloc];
}

#pragma mark -
#pragma mark Preference pane protocol methods

- (NSView *)preferencePaneView
{
	return [self view];
}

- (NSImage *)preferencePaneIcon
{
	return [NSImage imageNamed:@"toolbar-preferences-network"];
}

- (NSString *)preferencePaneName
{
	return NSLocalizedString(@"Network", @"network preference pane name");
}

- (NSString *)preferencePaneIdentifier
{
	return SPPreferenceToolbarNetwork;
}

- (NSString *)preferencePaneToolTip
{
	return NSLocalizedString(@"Network Preferences", @"network preference pane tooltip");
}

- (BOOL)preferencePaneAllowsResizing
{
	return NO;
}

- (void)preferencePaneWillBeShown
{
	[self loadSSLCiphers];
	if(![[sslCipherView registeredDraggedTypes] containsObject:SPSSLCipherPboardTypeName])
		[sslCipherView registerForDraggedTypes:@[SPSSLCipherPboardTypeName]];
}

#pragma mark -
#pragma mark Custom SSH client methods

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if([SPHiddenKeyFileVisibilityKey isEqualTo:keyPath]) {
		[self updateHiddenFiles];
	}
}

- (void)updateHiddenFiles
{
	[_currentFilePanel setShowsHiddenFiles:[prefs boolForKey:SPHiddenKeyFileVisibilityKey]];
}

- (IBAction)pickSSHClientViaFileBrowser:(id)sender
{
	_currentFilePanel = [NSOpenPanel openPanel];
	[_currentFilePanel setCanChooseFiles:YES];
	[_currentFilePanel setCanChooseDirectories:NO];
	[_currentFilePanel setAllowsMultipleSelection:NO];
	[_currentFilePanel setAccessoryView:hiddenFileView];
	[_currentFilePanel setResolvesAliases:NO];
	[self updateHiddenFiles];
	
	[prefs addObserver:self
			forKeyPath:SPHiddenKeyFileVisibilityKey
	           options:NSKeyValueObservingOptionNew
			   context:NULL];
	
	[_currentFilePanel beginSheetModalForWindow:[_currentAlert window] completionHandler:^(NSInteger result) {
		if(result == NSFileHandlingPanelOKButton) [sshClientPath setStringValue:[[_currentFilePanel URL] path]];
		
		[prefs removeObserver:self forKeyPath:SPHiddenKeyFileVisibilityKey];
		
		_currentFilePanel = nil;
	}];
}

- (IBAction)pickSSHClient:(id)sender
{
	//take value from user defaults
	NSString *oldPath = [prefs stringForKey:SPSSHClientPath];
	if([oldPath length]) [sshClientPath setStringValue:oldPath];
	
	// set up dialog
	_currentAlert = [[NSAlert alloc] init]; //needs to be ivar so we can attach the OpenPanel later
	[_currentAlert setAccessoryView:sshClientPickerView];
	[_currentAlert setAlertStyle:NSWarningAlertStyle];
	[_currentAlert setMessageText:NSLocalizedString(@"Unsupported configuration!",@"Preferences : Network : Custom SSH client : warning dialog title")];
	[_currentAlert setInformativeText:NSLocalizedString(@"Sequel Pro only supports and is tested with the default OpenSSH client versions included with Mac OS X. Using different clients might cause connection issues, security risks or not work at all.\n\nPlease be aware, that we cannot provide support for such configurations.",@"Preferences : Network : Custom SSH client : warning dialog message")];
	[_currentAlert addButtonWithTitle:NSLocalizedString(@"OK",@"Preferences : Network : Custom SSH client : warning dialog : accept button")];
	[_currentAlert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Preferences : Network : Custom SSH client : warning dialog : cancel button")];
	
	if([_currentAlert runModal] == NSAlertFirstButtonReturn) {
		//store new value to user defaults
		NSString *newPath = [sshClientPath stringValue];
		if(![newPath length])
			[prefs removeObjectForKey:SPSSHClientPath];
		else
			[prefs setObject:newPath forKey:SPSSHClientPath];
	}
	
	SPClear(_currentAlert);
}

#pragma mark -
#pragma mark SSL cipher list methods

- (void)loadSSLCiphers
{
	NSArray *supportedCiphers = [SPNetworkPreferencePane defaultSSLCipherList];
	[sslCiphers removeAllObjects];

	NSString *userCipherString = [prefs stringForKey:SPSSLCipherListKey];
	if(userCipherString) {
		//expand user list
		NSArray *userCipherList = [userCipherString componentsSeparatedByString:@":"];
		
		//compare the users list to the valid list and only copy over valid items
		for (NSString *userCipher in userCipherList) {
			if (![supportedCiphers containsObject:userCipher] || [sslCiphers containsObject:userCipher]) {
				SPLog(@"Unknown ssl cipher in users' list: %@",userCipher);
				continue;
			}
			[sslCiphers addObject:userCipher];
		}
		
		//now we do the reverse and add valid ciphers that are not yet in the users list.
		//We'll just assume the ones not in the users' list are newer and therefore better and add
		//them at the top
		NSUInteger shift = 0;
		for (NSString *validCipher in supportedCiphers) {
			if(![sslCiphers containsObject:validCipher]) {
				[sslCiphers insertObject:validCipher atIndex:shift++];
			}
		}
	}
	else {
		//no user prefs configured, so we'll just go with the defaults
		[sslCiphers addObjectsFromArray:supportedCiphers];
	}
	
	//reload UI
	[sslCipherView deselectAll:nil];
	[sslCipherView reloadData];
}

- (void)storeSSLCiphers
{
	NSString *flattedList = [sslCiphers componentsJoinedByString:@":"];
	[prefs setObject:flattedList forKey:SPSSLCipherListKey];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [sslCiphers count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSString *value = [sslCiphers objectAtIndex:rowIndex];
	if ([value isEqualTo:SPSSLCipherListMarkerItem]) {
		return NSLocalizedString(@"Disabled Cipher Suites", @"Preferences : Network : SSL Chiper suites : List seperator");
	}
	return value;
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row
{
	return ([[sslCiphers objectAtIndex:row] isEqualTo:SPSSLCipherListMarkerItem]);
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	return ![self tableView:tableView isGroupRow:row];
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
	if(row < 0) return NO; //why is that even a signed int when all "indexes" are unsigned!?
	
	NSPasteboard *pboard = [info draggingPasteboard];
	NSArray *draggedItems = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:SPSSLCipherPboardTypeName]];
	
	NSUInteger nextInsert = row;
	for (NSString *item in draggedItems) {
		NSUInteger oldPos = [sslCiphers indexOfObject:item];
		[sslCiphers removeObjectAtIndex:oldPos];
		
		if(oldPos < (NSUInteger)row) {
			// readjust position because we removed an object further up in the list, shifting all following indexes down by 1
			nextInsert--;
		}
		
		[sslCiphers insertObject:item atIndex:nextInsert++];
	}
	
	NSMutableIndexSet *newSelection = [NSMutableIndexSet indexSet];
	for (NSString *item in draggedItems) {
		[newSelection addIndex:[sslCiphers indexOfObject:item]];
	}
	
	[self storeSSLCiphers];
	[sslCipherView selectRowIndexes:newSelection byExtendingSelection:NO];
	
	return YES;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	//cannot drop something on another item in the list, only between them
	return (operation == NSTableViewDropOn)? NSDragOperationNone : NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	//the marker cannot be actively reordered
	if ([rowIndexes containsIndex:[sslCiphers indexOfObject:SPSSLCipherListMarkerItem]])
		return NO;
	
	//put the names of the items on the pasteboard. easier to work with than indexes...
	NSMutableArray *items = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
	[rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		[items addObject:[sslCiphers objectAtIndex:idx]];
	}];
	
	NSData *arch = [NSKeyedArchiver archivedDataWithRootObject:items];
	[pboard declareTypes:@[SPSSLCipherPboardTypeName] owner:self];
	[pboard setData:arch forType:SPSSLCipherPboardTypeName];
	return YES;
}

- (IBAction)resetCipherList:(id)sender
{
	//remove the user pref and reset the GUI
	[prefs removeObjectForKey:SPSSLCipherListKey];
	[self loadSSLCiphers];
}

+ (NSArray *)defaultSSLCipherList
{
	//this is the default list as hardcoded in SPMySQLConnection.m
	//Sadly there is no way to make MySQL give us the list of runtime-supported ciphers.
	return @[@"DHE-RSA-AES256-SHA",
			 @"AES256-SHA",
			 @"DHE-RSA-AES128-SHA",
			 @"AES128-SHA",
			 @"AES256-RMD",
			 @"AES128-RMD",
			 @"DES-CBC3-RMD",
			 @"DHE-RSA-AES256-RMD",
			 @"DHE-RSA-AES128-RMD",
			 @"DHE-RSA-DES-CBC3-RMD",
			 @"RC4-SHA",
			 @"RC4-MD5",
			 @"DES-CBC3-SHA",
			 @"DES-CBC-SHA",
			 @"EDH-RSA-DES-CBC3-SHA",
			 @"EDH-RSA-DES-CBC-SHA",
			 SPSSLCipherListMarkerItem, //marker. disabled items below here
			 @"EDH-DSS-DES-CBC-SHA",
			 @"EDH-DSS-DES-CBC3-SHA",
			 @"DHE-DSS-AES128-SHA",
			 @"DHE-DSS-AES256-SHA",
			 @"DHE-DSS-DES-CBC3-RMD",
			 @"DHE-DSS-AES128-RMD",
			 @"DHE-DSS-AES256-RMD"];
}

@end

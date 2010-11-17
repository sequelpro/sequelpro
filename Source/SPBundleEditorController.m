//
//  $Id$
//
//  SPBundleEditorController.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on November 12, 2010
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

#import "SPBundleEditorController.h"


@implementation SPBundleEditorController

/**
 * Initialisation
 */
- (id)init
{

	if ((self = [super initWithWindowNibName:@"BundleEditor"])) {
		commandBundleArray = nil;
		draggedFilePath = nil;
		bundlePath = [[[NSFileManager defaultManager] applicationSupportDirectoryForSubDirectory:SPBundleSupportFolder createIfNotExists:NO error:nil] retain];
	}
	
	return self;

}

- (void)dealloc
{
	if(commandBundleArray) [commandBundleArray release], commandBundleArray = nil;
	if(bundlePath) [bundlePath release], bundlePath = nil;
	[super dealloc];
}

#pragma mark -


- (IBAction)inputPopuButtonChanged:(id)sender
{
	
}

- (IBAction)duplicateCommandBundle:(id)sender
{
	if ([commandsTableView numberOfSelectedRows] == 1)
		[self addCommandBundle:self];
	else
		NSBeep();
}

- (IBAction)addCommandBundle:(id)sender
{
	NSMutableDictionary *bundle;
	NSUInteger insertIndex;

	// Store pending changes in Query
	[[self window] makeFirstResponder:nameTextField];

	// Duplicate a selected favorite if sender == self
	if (sender == self) {
		NSDictionary *currentDict = [commandBundleArray objectAtIndex:[commandsTableView selectedRow]];
		bundle = [NSMutableDictionary dictionaryWithDictionary:currentDict];
		[bundle setObject:[NSString stringWithFormat:@"%@_Copy", [bundle objectForKey:@"bundleName"]] forKey:@"bundleName"];
	}
	// Add a new favorite
	else {
		bundle = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"New Bundle", @"New Name", @"", nil] 
						forKeys:[NSArray arrayWithObjects:@"bundleName", @"name", @"command", nil]];
	}
	if ([commandsTableView numberOfSelectedRows] > 0) {
		insertIndex = [[commandsTableView selectedRowIndexes] lastIndex]+1;
		[commandBundleArray insertObject:bundle atIndex:insertIndex];
	} 
	else {
		[commandBundleArray addObject:bundle];
		insertIndex = [commandBundleArray count] - 1;
	}

	[commandBundleArrayController rearrangeObjects];
	[commandsTableView reloadData];

	[commandsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
	
	[commandsTableView scrollRowToVisible:[commandsTableView selectedRow]];

	[removeButton setEnabled:([commandsTableView numberOfSelectedRows] > 0)];
	[[self window] makeFirstResponder:commandsTableView];

}

- (IBAction)removeCommandBundle:(id)sender
{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Remove selected Bundles?", @"remove selected bundles message") 
									 defaultButton:NSLocalizedString(@"Remove", @"remove button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to remove all selected Bundles? This action cannot be undone.", @"remove all selected bundles informative message")];

	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"r"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeSelectedBundles"];
}

- (IBAction)revealCommandBundleInFinder:(id)sender
{
	if([commandsTableView numberOfSelectedRows] != 1) return;
	[[NSWorkspace sharedWorkspace] selectFile:[NSString stringWithFormat:@"%@/%@.%@/%@", 
		bundlePath, [[commandBundleArray objectAtIndex:[commandsTableView selectedRow]] objectForKey:@"bundleName"], SPUserBundleFileExtension, SPBundleFileName] inFileViewerRootedAtPath:nil];
}

- (IBAction)showHelp:(id)sender
{
	// [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NSLocalizedString(@"http://www.sequelpro.com/docs/Bundles", @"Localized help page for bundles - do not localize if no translated webpage is available")]];
}

- (IBAction)showWindow:(id)sender
{

	// Suppress parsing if window is already opened
	if([[self window] isVisible]) return;

	// Order out window
	[super showWindow:sender];

	// Re-init commandBundleArray
	if(commandBundleArray) [commandBundleArray release], commandBundleArray = nil;
	commandBundleArray = [[NSMutableArray alloc] init];

	// Load all installed bundle items
	if(bundlePath) {
		NSError *error = nil;
		NSArray *foundBundles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundlePath error:&error];
		if (foundBundles && [foundBundles count]) {
			for(NSString* bundle in foundBundles) {
				if(![[[bundle pathExtension] lowercaseString] isEqualToString:[SPUserBundleFileExtension lowercaseString]]) continue;

				NSError *readError = nil;
				NSString *convError = nil;
				NSPropertyListFormat format;
				NSDictionary *cmdData = nil;
				NSString *infoPath = [NSString stringWithFormat:@"%@/%@/%@", bundlePath, bundle, SPBundleFileName];
				NSData *pData = [NSData dataWithContentsOfFile:infoPath options:NSUncachedRead error:&readError];

				cmdData = [[NSPropertyListSerialization propertyListFromData:pData 
						mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

				if(!cmdData || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
					NSLog(@"“%@/%@” file couldn't be read.", bundle, SPBundleFileName);
					NSBeep();
					if (cmdData) [cmdData release];
				} else {
					if([cmdData objectForKey:SPBundleFileNameKey] && [[cmdData objectForKey:SPBundleFileNameKey] length] && [cmdData objectForKey:SPBundleFileScopeKey])
					{
						NSMutableDictionary *bundleCommand = [NSMutableDictionary dictionary];
						[bundleCommand addEntriesFromDictionary:cmdData];
						[bundleCommand setObject:[bundle stringByDeletingPathExtension] forKey:@"bundleName"];

						NSArray *scopes = [[cmdData objectForKey:SPBundleFileScopeKey] componentsSeparatedByString:@" "];
						for(NSString *scope in scopes) {
							[bundleCommand setObject:[NSNumber numberWithInt:1] forKey:scope];
						}


						[commandBundleArray addObject:bundleCommand];
					}
					if (cmdData) [cmdData release];
				}
			}
		}
	}

	[commandBundleArrayController setContent:commandBundleArray];
	[commandsTableView reloadData];

}

- (IBAction)saveAndCloseWindow:(id)sender
{

	// Commit all pending edits
	if([commandBundleArrayController commitEditing]) {
		NSLog(@"%@", commandBundleArray);
		[[self window] performClose:self];
	}
}

- (BOOL)saveBundle:(NSDictionary*)bundle atPath:(NSString*)aPath
{

	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDir = NO;

	// If passed aPath is nil construct the path from bundle's bundleName.
	// aPath is mainly used for dragging a bundle from table view.
	if(aPath == nil) {
		if(![bundle objectForKey:@"bundleName"] || ![[bundle objectForKey:@"bundleName"] length]) {
			return NO;
		}
		aPath = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, [bundle objectForKey:@"bundleName"], SPUserBundleFileExtension];
	}

	// Create spBundle folder if it doesn't exist
	if(![fm fileExistsAtPath:aPath isDirectory:&isDir]) {
		if(![fm createDirectoryAtPath:aPath withIntermediateDirectories:YES attributes:nil error:nil])
			return NO;
		isDir = YES;
	}
	
	// If aPath exists but it's not a folder bails
	if(!isDir) return NO;

	// The command.plist file path
	NSString *cmdFilePath = [NSString stringWithFormat:@"%@/%@", aPath, SPBundleFileName];

	NSMutableDictionary *saveDict = [NSMutableDictionary dictionary];
	[saveDict addEntriesFromDictionary:bundle];

	// Build scope key
	NSMutableString *scopes = [NSMutableString string];
	if([bundle objectForKey:SPBundleScopeQueryEditor]) {
		if([scopes length]) [scopes appendString:@" "];
		[scopes appendString:SPBundleScopeQueryEditor];
	}
	if([bundle objectForKey:SPBundleScopeInputField]) {
		if([scopes length]) [scopes appendString:@" "];
		[scopes appendString:SPBundleScopeInputField];
	}
	if([bundle objectForKey:SPBundleScopeDataTable]) {
		if([scopes length]) [scopes appendString:@" "];
		[scopes appendString:SPBundleScopeDataTable];
	}
	[saveDict setObject:scopes forKey:SPBundleFileScopeKey];

	// Remove unnecessary keys
	[saveDict removeObjectsForKeys:[NSArray arrayWithObjects:
		@"bundleName",
		SPBundleScopeQueryEditor,
		SPBundleScopeInputField,
		SPBundleScopeDataTable,
		nil]];

	// Remove a given old command.plist file
	[fm removeItemAtPath:cmdFilePath error:nil];
	[saveDict writeToFile:cmdFilePath atomically:YES];

	return YES;

}

#pragma mark -
#pragma mark NSWindow delegate

- (void)windowWillClose:(NSNotification *)notification
{
	// Release commandBundleArray if window will close to save memory
	if(commandBundleArray) [commandBundleArray release], commandBundleArray = nil;

	// Remove temporary drag file if any
	if(draggedFilePath) {
		[[NSFileManager defaultManager] removeItemAtPath:draggedFilePath error:nil];
		[draggedFilePath release];
		draggedFilePath = nil;
	}

	return YES;
}

#pragma mark -
#pragma mark TableView datasource methods

/**
 * Returns the number of query commandBundleArray.
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [commandBundleArray count];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return YES;
}

/**
 * Returns the value for the requested table column and row index.
 */
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	if([[aTableColumn identifier] isEqualToString:@"name"]) {
		if(![[commandBundleArray objectAtIndex:rowIndex] objectForKey:@"name"]) return @"...";
		return [[commandBundleArray objectAtIndex:rowIndex] objectForKey:@"bundleName"];
	}
	return @"";
}

/*
 * Save favorite names if inline edited (suppress empty names)
 */
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	if([[aTableColumn identifier] isEqualToString:@"name"]) {
		if([anObject isKindOfClass:[NSString class]] && [(NSString *)anObject length]) {
			[[commandBundleArray objectAtIndex:rowIndex] setObject:anObject forKey:@"bundleName"];
		}
	}

	[commandsTableView reloadData];
}

/**
 * Sheet did end method
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{

	if([contextInfo isEqualToString:@"removeSelectedBundles"]) {
		if (returnCode == NSAlertDefaultReturn) {
			NSIndexSet *indexes = [commandsTableView selectedRowIndexes];

			// get last index
			NSUInteger currentIndex = [indexes lastIndex];

			while (currentIndex != NSNotFound) {
				[commandBundleArray removeObjectAtIndex:currentIndex];
				// get next index (beginning from the end)
				currentIndex = [indexes indexLessThanIndex:currentIndex];
			}

			[commandBundleArrayController rearrangeObjects];
			[commandsTableView reloadData];

			// Set focus to table view to avoid an unstable state
			[[self window] makeFirstResponder:commandsTableView];

			[removeButton setEnabled:([commandsTableView numberOfSelectedRows] > 0)];
		}
	}

}

#pragma mark -
#pragma mark Menu validation

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{

	SEL action = [menuItem action];
	
	if ( (action == @selector(duplicateCommandBundle:)) 
		|| (action == @selector(revealCommandBundleInFinder:))
		) 
	{
		return ([commandsTableView numberOfSelectedRows] == 1);
	}
	else if ( (action == @selector(removeCommandBundle:)) )
	{
		return ([commandsTableView numberOfSelectedRows] > 0);
	}

	return YES;

}

#pragma mark -
#pragma mark TableView drag & drop delegate methods

/**
 * Allow for drag-n-drop out of the application as a copy
 */
- (NSUInteger)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationMove;
}


/**
 * Drag a table row item as spBundle
 */
- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard*)aPboard
{

	if([commandsTableView numberOfSelectedRows] != 1 || [rows count] != 1) return NO;

	// Remove old temporary drag file if any
	if(draggedFilePath) {
		[[NSFileManager defaultManager] removeItemAtPath:draggedFilePath error:nil];
		[draggedFilePath release];
		draggedFilePath = nil;
	}

	NSImage *dragImage;
	NSPoint dragPosition;

	NSDictionary *bundleDict = [commandBundleArray objectAtIndex:[rows firstIndex]];
	NSString *bundleFileName = [bundleDict objectForKey:@"bundleName"];
	draggedFilePath = [[NSString stringWithFormat:@"/tmp/%@.%@", bundleFileName, SPUserBundleFileExtension] retain];

	// Write temporary bundle data to disk but do not save the dict to Bundles folder
	if(![self saveBundle:bundleDict atPath:draggedFilePath]) return NO;

	// Write data to the pasteboard
	NSArray *fileList = [NSArray arrayWithObjects:draggedFilePath, nil];
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[pboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil];
	[pboard setPropertyList:fileList forType:NSFilenamesPboardType];

	// Start the drag operation
	dragImage = [[NSWorkspace sharedWorkspace] iconForFile:draggedFilePath];
	dragPosition = [[[self window] contentView] convertPoint:[[NSApp currentEvent] locationInWindow] fromView:nil];
	dragPosition.x -= 32;
	dragPosition.y -= 32;
	[[self window] dragImage:dragImage at:dragPosition offset:NSZeroSize
		event:[NSApp currentEvent] pasteboard:pboard source:[self window] slideBack:YES];

	return YES;

}

@end

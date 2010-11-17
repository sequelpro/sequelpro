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

		commandBundleArray = [[NSMutableArray alloc] init];

	}
	
	return self;

}

- (void)dealloc
{
	[commandBundleArray release];
	[super dealloc];
}

- (void)awakeFromNib
{
	NSString *bundlePath = [[NSFileManager defaultManager] applicationSupportDirectoryForSubDirectory:SPBundleSupportFolder createIfNotExists:NO error:nil];

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
						[commandBundleArray addObject:bundleCommand];
					}
					if (cmdData) [cmdData release];
				}
			}
		}
	}
}

- (IBAction)scopeButtonChanged:(id)sender
{
	
}

- (IBAction)inputPopuButtonChanged:(id)sender
{
	
}

- (IBAction)duplicateCommandBundle:(id)sender
{
	
}

- (IBAction)addCommandBundle:(id)sender
{
	
}

- (IBAction)removeCommandBundle:(id)sender
{
	
}

- (IBAction)revealCommandBundleInFinder:(id)sender
{
	
}

- (IBAction)showHelp:(id)sender
{
	
}

- (BOOL)windowShouldClose:(id)sender
{
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

/*
 * Changes in the name text field will be saved in data source directly
 * to update the table view accordingly
 */
- (void)controlTextDidChange:(NSNotification *)notification
{

	// Do nothing if no favorite is selected
	if([commandsTableView numberOfSelectedRows] < 1) return;

	id object = [notification object];

	if(object == nameTextField) {
		[[commandBundleArray objectAtIndex:[commandsTableView selectedRow]] setObject:[nameTextField stringValue] forKey:@"name"];
		[commandsTableView reloadData];
	} 

}

#pragma mark -
#pragma mark Menu validation

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{

	return YES;

}

@end

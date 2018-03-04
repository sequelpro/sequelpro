//
//  SPCharsetCollationHelper.h
//  sequel-pro
//
//  Created by Max Lohrmann on March 20, 2013.
//  Copyright (c) 2013 Max Lohrmann. All rights reserved.
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

#import "SPCharsetCollationHelper.h"

#import "SPServerSupport.h"
#import "SPDatabaseData.h"

@interface SPCharsetCollationHelper ()

- (void)charsetButtonClicked:(id)sender;
- (void)collationButtonClicked:(id)sender;
- (void)refreshCharsets;
- (void)refreshCollations;

@end


@implementation SPCharsetCollationHelper

@synthesize databaseData;
@synthesize serverSupport;
@synthesize promoteUTF8;
@synthesize defaultCharset;
@synthesize defaultCollation;
@synthesize selectedCharset;
@synthesize selectedCollation;
@synthesize defaultCharsetFormatString;
@synthesize defaultCollationFormatString;
@synthesize _oldCharset;

- (id)initWithCharsetButton:(NSPopUpButton *)aCharsetButton CollationButton:(NSPopUpButton *)aCollationButton
{
	NSAssert((aCharsetButton != nil),@"aCharsetButton != nil");
	NSAssert((aCollationButton != nil),@"aCollationButton != nil");
	
	self = [super init];
	if (self != nil) {
		[self setPromoteUTF8:YES];
		[self setDefaultCharsetFormatString:NSLocalizedString(@"Default (%@)",@"Charset Dropdown : Default item ($1 = charset name)")];
		[self setDefaultCollationFormatString:NSLocalizedString(@"Default (%@)",@"Collation Dropdown : Default collation for given charset ($1 = collation name)")];
		charsetButton = aCharsetButton;
		collationButton = aCollationButton;
		//connect the charset button with ourselves
		[charsetButton setTarget:self];
		[charsetButton setAction:@selector(charsetButtonClicked:)];
		//connect the collation button with ourselves
		[collationButton setTarget:self];
		[collationButton setAction:@selector(collationButtonClicked:)];
	}
	return self;
}

- (void)charsetButtonClicked:(id)sender {
	if(!_enabled)
		return;
	
	//update selectedCharset
	if(defaultCharset && [charsetButton indexOfSelectedItem] == 0) {
		//this is the default item, which means nil for selectedCollation
		[self setSelectedCharset:nil];
	}
	else {
		//this is an actual item
		NSString *charsetId = [[charsetButton selectedItem] representedObject];
		[self setSelectedCharset:charsetId];
	}
	
	//update collations if there actually was a change in charset
	if((selectedCharset == nil && _oldCharset == nil) || (selectedCharset && [selectedCharset isEqualToString:_oldCharset])) {
		//same charset. (NOP - just for readability of the if statement)
	}
	else {
		//reset the selected collation. that was only valid as long as the same charset was selected
		[self setSelectedCollation:nil];
		[self refreshCollations];
		[self set_oldCharset:selectedCharset];
	}

}

- (void)collationButtonClicked:(id)sender {
	if(!_enabled)
		return;
	
	//update selectedCollation
	if([collationButton indexOfSelectedItem] == 0) {
		//this is the default item, which means nil for selectedCollation
		[self setSelectedCollation:nil];
	}
	else {
		//this is an actual item
		[self setSelectedCollation:[collationButton titleOfSelectedItem]];
	}
	
}

- (void)refreshCharsets {
	//reset
	[charsetButton removeAllItems];

	// Retrieve the server-supported encodings and add them to the menu
	NSArray *encodings  = [databaseData getDatabaseCharacterSetEncodings];
	
	[charsetButton setEnabled:NO];
	
	NSMenuItem *selectedRef = nil;
	
	if (([encodings count] > 0) && [serverSupport supportsPost41CharacterSetHandling]) {
		
		NSUInteger utf8encounters = 0;
		
		for (NSDictionary *encoding in encodings) 
		{
			NSString *charsetId     = [encoding objectForKey:@"CHARACTER_SET_NAME"];
			NSString *description   = [encoding objectForKey:@"DESCRIPTION"];
			NSString *menuItemTitle = (![description length]) ? charsetId : [NSString stringWithFormat:@"%@ (%@)", description, charsetId];
			
			NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:menuItemTitle action:NULL keyEquivalent:@""];
			[menuItem setRepresentedObject:charsetId];
			
			//store the menu item that we want to select (we'll do that when the list is stable)
			if(selectedCharset && [charsetId isEqualToString:selectedCharset])
				selectedRef = menuItem;
			
			// If an UTF8 entry has been encountered, promote it to the top of the list
			if (promoteUTF8 && [charsetId hasPrefix:@"utf8"]) {
				[[charsetButton menu] insertItem:[menuItem autorelease] atIndex:(utf8encounters++)];
			}
			else {
				[[charsetButton menu] addItem:[menuItem autorelease]];
			}
				
		}
		
		//only add a separator if there actually are more items other than utf8 (might not be true for mysql forks)
		if(utf8encounters && [encodings count] > utf8encounters)
			[[charsetButton menu] insertItem:[NSMenuItem separatorItem] atIndex:utf8encounters];
		
		[charsetButton setEnabled:YES];
	}
	
	// Populate the table encoding popup button with a default menu item (if set)
	// This is down here so it is put even before the utf8 item.
	if(defaultCharset) {
		NSMenuItem *defaultItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:defaultCharsetFormatString,defaultCharset] action:NULL keyEquivalent:@""];
		[defaultItem setRepresentedObject:defaultCharset];
		[[charsetButton menu] insertItem:[defaultItem autorelease] atIndex:0];
		if([encodings count] > 0)
			[[charsetButton menu] insertItem:[NSMenuItem separatorItem] atIndex: 1];
	}

	//inserting items can have strange effects on the lists selectedItem, so we reset that.
	[charsetButton selectItemAtIndex:0];
	
	//honor selectedCharset
	if(selectedRef)
		[charsetButton selectItem:selectedRef];
	
	//reload the collations for the selected charset
	[self refreshCollations];
}

- (void)refreshCollations {
	NSString *fmtStrDefaultId      = NSLocalizedString(@"Default (%@)",@"Collation Dropdown : Default ($1 = collation name)");
	NSString *fmtStrDefaultUnknown = NSLocalizedString(@"Default",@"Collation Dropdown : Default (unknown)"); // MySQL < 4.1.0
	
	//throw out all items
	[collationButton removeAllItems];
	//we'll enable that later if the user can actually change the selection.
	[collationButton setEnabled:NO];
	
	//add the unknown default item - we will remove that once we have a real default,
	//which can come from two sources:
	//  a) it was explicitly set in defaultCollation (only applies when defaultCharset == selectedCharset)
	//  b) the server told us which was the default
	//if neither works (old mysql / forks ?) we at least have the dummy default.
	[collationButton addItemWithTitle:fmtStrDefaultUnknown];
	
	//if the server actually has support for charsets & collations we will now get a list of all collations
	//for the current charset. Even if the default charset is kept by the user he can change the default collation
	//so we search in that case, too.
	if(![serverSupport supportsPost41CharacterSetHandling])
		return;
	
	//get the charset id
	NSString *charsetId = [[charsetButton selectedItem] representedObject];
	BOOL charsetIsInherited = ([self selectedCharset] == nil);

	//now let's get the list of collations for the selected charset id
	NSArray *applicableCollations = [databaseData getDatabaseCollationsForEncoding:charsetId];
	
	//got something?
	if (![applicableCollations count])
		return;
	
	//add a separator
	[[collationButton menu] addItem:[NSMenuItem separatorItem]];

	// there are two kinds of default collations:
	// - the inherited default (which is only used if NEITHER charset NOR collation is explicitly set), and
	// - the charset default (which is used if charset is explicitly set, but collation is not)
	//   - that even applies if the selectedCharset is the same as the defaultCharset!
	if(charsetIsInherited) {
		// implies [charsetId isEqualToString:defaultCharset]
		NSString *userInheritedCollateTitle = [NSString stringWithFormat:defaultCollationFormatString,defaultCollation];
		//remove the dummy default item.
		[collationButton removeItemAtIndex:0];
		//add it to the top of the list
		[collationButton insertItemWithTitle:userInheritedCollateTitle atIndex:0];
	}
	
	//add the real items
	for (NSDictionary *collation in applicableCollations) 
	{
		NSString *collationName = [collation objectForKey:@"COLLATION_NAME"];
		[collationButton addItemWithTitle:collationName];
		
		//is this the default collation for this charset and charset was given explicitly (ie. breaking inheritance)?
		if(!charsetIsInherited && [[collation objectForKey:@"IS_DEFAULT"] isEqualToString:@"Yes"]) {
			NSString *defaultCollateTitle = [NSString stringWithFormat:fmtStrDefaultId,collationName];
			//remove the dummy default item.
			[collationButton removeItemAtIndex:0];
			//add it to the top of the list
			[collationButton insertItemWithTitle:defaultCollateTitle atIndex:0];
		}
	}
	//reset selection to first item (it may have moved when adding the default item)
	[collationButton selectItemAtIndex:0];
	
	//honor selectedCollation
	if(selectedCollation)
		[collationButton selectItemWithTitle:selectedCollation];
	
	//yay, now there is actually something not the Default item, so we can enable the button
	[collationButton setEnabled:YES];
}

- (BOOL)enabled {
	return _enabled;
}

- (void)setEnabled:(BOOL)value {
	
	if(value == YES) {
		NSAssert((databaseData != nil),@"No valid SPDatabaseData object given!");
		NSAssert((serverSupport != nil),@"No valid SPServerSupport object given!");
		[self set_oldCharset:selectedCharset]; //initialise to the initial selected charset
		[self refreshCharsets];
	}
	_enabled = value;
}

@end

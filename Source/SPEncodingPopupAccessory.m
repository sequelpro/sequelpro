//
//  $Id$
//
//  SPEncodingPopupAccessory.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on August 22, 2009
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

#import "SPEncodingPopupAccessory.h"

@implementation SPEncodingPopupAccessory

+ (NSView *)encodingAccessory:(NSUInteger)encoding includeDefaultEntry:(BOOL)includeDefaultItem encodingPopUp:(NSPopUpButton **)popup {
	SPEncodingPopupAccessory *owner = [[[SPEncodingPopupAccessory alloc] init] autorelease];
	// Rather than caching, load the accessory view everytime, as it might appear in multiple panels simultaneously.
	if (![NSBundle loadNibNamed:@"EncodingPopupView" owner:owner])  {
		NSLog(@"Failed to load EncodingPopupView.nib");
		return nil;
	}
	if (popup) *popup = owner->encodingPopUp;
	[[self class] setupPopUp:owner->encodingPopUp selectedEncoding:encoding withDefaultEntry:includeDefaultItem];
	return [owner->encodingAccessoryView autorelease];
}

/**
 * Sort using the equivalent Mac encoding as the major key. 
 * Secondary key is the actual encoding value, which works well enough. 
 * We treat Unicode encodings as special case, putting them at top of the list.
 */
static int encodingCompare(const void *firstPtr, const void *secondPtr) {

	CFStringEncoding first = *(CFStringEncoding *)firstPtr;
	CFStringEncoding second = *(CFStringEncoding *)secondPtr;
	CFStringEncoding macEncodingForFirst = CFStringGetMostCompatibleMacStringEncoding(first);
	CFStringEncoding macEncodingForSecond = CFStringGetMostCompatibleMacStringEncoding(second);

	// Should really never happen
	if (first == second) return 0;

	if (macEncodingForFirst == kCFStringEncodingUnicode || macEncodingForSecond == kCFStringEncodingUnicode) {
		if (macEncodingForSecond == macEncodingForFirst) 
			// Both Unicode; compare second order
			return (first > second) ? 1 : -1;
		// First is Unicode
		return (macEncodingForFirst == kCFStringEncodingUnicode) ? -1 : 1;
	}

	if ((macEncodingForFirst > macEncodingForSecond) || ((macEncodingForFirst == macEncodingForSecond) && (first > second)))
		return 1;

	return -1;
}

/**
 * Returns the actual enabled list of encodings for open/save files.
 */
+ (NSArray *)enabledEncodings
{
	static NSMutableArray *allEncodings = nil;

	// Build list of encodings, sorted, and including only those with human readable names
	if (!allEncodings) {
		const CFStringEncoding *cfEncodings = CFStringGetListOfAvailableEncodings();
		CFStringEncoding *tmp;
		NSInteger cnt, num = 0;
		while (cfEncodings[num] != kCFStringEncodingInvalidId) num++;
		tmp = malloc(sizeof(CFStringEncoding) * num);
		memcpy(tmp, cfEncodings, sizeof(CFStringEncoding) * num);
		qsort(tmp, num, sizeof(CFStringEncoding), encodingCompare);
		allEncodings = [[NSMutableArray alloc] init];
		for (cnt = 0; cnt < num; cnt++) {
			NSStringEncoding nsEncoding = CFStringConvertEncodingToNSStringEncoding(tmp[cnt]);
			if (nsEncoding && [NSString localizedNameOfStringEncoding:nsEncoding])
				[allEncodings addObject:[NSNumber numberWithUnsignedInteger:nsEncoding]];
		}
		free(tmp);
	}
	return allEncodings;
}

/**
 * This method initializes the provided popup with list of encodings; 
 * it also sets up the selected encoding as indicated and if includeDefaultItem is YES. 
 * Otherwise the tags are set to the NSStringEncoding value for the encoding.
 */
+ (void)setupPopUp:(NSPopUpButton *)popup selectedEncoding:(NSUInteger)selectedEncoding withDefaultEntry:(BOOL)includeDefaultItem
{
	NSArray *encs = [self enabledEncodings];
	NSUInteger cnt, numEncodings, itemToSelect = 0;

	// Put the encodings in the popup
	[popup removeAllItems];

	// Make sure the initial selected encoding appears in the list
	if (!includeDefaultItem && (selectedEncoding != NoStringEncoding) && ![encs containsObject:[NSNumber numberWithUnsignedInteger:selectedEncoding]]) encs = [encs arrayByAddingObject:[NSNumber numberWithUnsignedInteger:selectedEncoding]];

	numEncodings = [encs count];

	// Fill with encodings
	for (cnt = 0; cnt < numEncodings; cnt++) {
		NSStringEncoding enc = [[encs objectAtIndex:cnt] unsignedIntegerValue];
		[popup addItemWithTitle:[NSString localizedNameOfStringEncoding:enc]];
		[[popup lastItem] setTag:enc];
		[[popup lastItem] setEnabled:YES];
		if (enc == selectedEncoding) itemToSelect = [popup numberOfItems] - 1;
	}

	[popup selectItemAtIndex:itemToSelect];
}

@end

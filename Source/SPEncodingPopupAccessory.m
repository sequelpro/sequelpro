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
 * Returns the actual enabled list of encodings for open/save SQL files.
 */
+ (NSArray *)enabledEncodings
{
	static const NSInteger plainTextFileStringEncodingsSupported[] = {
		kCFStringEncodingUTF8, 
		kCFStringEncodingUTF16, 
		kCFStringEncodingUTF16BE, 
		kCFStringEncodingUTF16LE, 
		kCFStringEncodingUTF32, 
		kCFStringEncodingWindowsLatin1, 
		kCFStringEncodingISOLatin1, 
		kCFStringEncodingWindowsLatin2, 
		kCFStringEncodingISOLatin2, 
		kCFStringEncodingISOLatin3, 
		kCFStringEncodingISOLatin4, 
		kCFStringEncodingWindowsLatin5, 
		kCFStringEncodingKOI8_R, 
		kCFStringEncodingKOI8_U, 
		kCFStringEncodingMacRoman, 
		kCFStringEncodingMacJapanese, 
		kCFStringEncodingShiftJIS, 
		kCFStringEncodingEUC_JP, 
		kCFStringEncodingISO_2022_JP, 
		kCFStringEncodingMacChineseTrad, 
		kCFStringEncodingMacChineseSimp, 
		kCFStringEncodingBig5, 
		kCFStringEncodingGB_18030_2000, 
		kCFStringEncodingEUC_CN, 
		kCFStringEncodingEUC_TW, 
		kCFStringEncodingMacKorean, 
		kCFStringEncodingEUC_KR, 
		-1
		};
		NSStringEncoding encoding;
		NSInteger cnt = 0;
		NSMutableArray *encs = [NSMutableArray array];
		while (plainTextFileStringEncodingsSupported[cnt] != -1)
			if ((encoding = CFStringConvertEncodingToNSStringEncoding(plainTextFileStringEncodingsSupported[cnt++])) != kCFStringEncodingInvalidId)
				[encs addObject:[NSNumber numberWithUnsignedInteger:encoding]];

		return encs;
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

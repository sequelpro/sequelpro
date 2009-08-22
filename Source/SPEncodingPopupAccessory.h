//
//  $Id$
//
//  SPEncodingPopupAccessory.h
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

#import <Cocoa/Cocoa.h>

enum {
	NoStringEncoding = 0xFFFFFFFF
};

@interface SPEncodingPopupAccessory : NSObject {
@public
	IBOutlet NSPopUpButton *encodingPopUp;
	IBOutlet NSView *encodingAccessoryView;
}

+ (NSArray *)enabledEncodings;
+ (NSView *)encodingAccessory:(NSUInteger)encoding includeDefaultEntry:(BOOL)includeDefaultItem encodingPopUp:(NSPopUpButton **)popup;
+ (void)setupPopUp:(NSPopUpButton *)popup selectedEncoding:(NSUInteger)selectedEncoding withDefaultEntry:(BOOL)includeDefaultItem;

@end

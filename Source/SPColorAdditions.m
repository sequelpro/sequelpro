//
//  $Id$
//
//  SPColorAdditions.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on August 16, 2010
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

#import "SPColorAdditions.h"


@implementation NSColor (SPColorAdditions)

/*
 * Convert self by using the NSCalibratedRGBColorSpace color space in a NSString
 * #RRGGBBAA or if the alpha value is zero to #RRGGBB
 */
- (NSString *)rgbHexString
{

	CGFloat red, green, blue, alpha;
	NSString *redHexValue, *greenHexValue, *blueHexValue, *alphaHexValue;
	NSColor *aColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

	if(aColor) {
		[aColor getRed:&red green:&green blue:&blue alpha:&alpha];
		redHexValue   = [NSString stringWithFormat:@"%02X", (NSInteger)(red * 255.0f)];
		greenHexValue = [NSString stringWithFormat:@"%02X", (NSInteger)(green * 255.0f)];
		blueHexValue  = [NSString stringWithFormat:@"%02X", (NSInteger)(blue * 255.0f)];
		alphaHexValue = [NSString stringWithFormat:@"%02X", (NSInteger)(alpha * 255.0f)];
		if([alphaHexValue isEqualToString:@"FF"]) alphaHexValue = @"";
		return [NSString stringWithFormat:@"#%@%@%@%@", redHexValue, greenHexValue, blueHexValue, alphaHexValue];
	}

	return @"";

}

+ (NSColor *)colorWithRGBHexString:(NSString *)hexString
{
	return [self colorWithRGBHexString:hexString ignoreAlpha:NO];
}

+ (NSColor *)colorWithRGBHexString:(NSString *)hexString ignoreAlpha:(BOOL)ignoreAlpha
{
	NSCharacterSet *hexCharSet = [NSCharacterSet characterSetWithCharactersInString:@"1234567890abcdefABCDEF"];
	NSString *initHexString = ( [hexString hasPrefix:@"#"] ) ? [hexString substringFromIndex:1] : hexString;
	if(ignoreAlpha && [initHexString length] == 8)
		initHexString = [initHexString substringToIndex:6];
	NSScanner *scanner = [NSScanner scannerWithString:initHexString];
	NSString *code = nil;

	[scanner scanCharactersFromSet:hexCharSet intoString:&code];

	if( [code length] == 8 ) { // decode colors like #ffee33aa
		NSUInteger color = 0;
		scanner = [NSScanner scannerWithString:code];
		if( ! [scanner scanHexInt:&color] ) return nil;
		return [self colorWithCalibratedRed:( ( ( color >> 24 ) & 0xff ) / 255. ) green:( ( ( color >> 16 ) & 0xff ) / 255. ) blue:( ( ( color >> 8) & 0xff ) / 255. ) alpha:( ( color & 0xff ) / 255. )];
	}
	else if( [code length] == 6 ) { // decode colors like #ffee33
		NSUInteger color = 0;
		scanner = [NSScanner scannerWithString:code];
		if( ! [scanner scanHexInt:&color] ) return nil;
		return [self colorWithCalibratedRed:( ( ( color >> 16 ) & 0xff ) / 255. ) green:( ( ( color >> 8 ) & 0xff ) / 255. ) blue:( ( color & 0xff ) / 255. ) alpha:1.];
	}
	else if( [code length] == 3 ) {  // decode short-hand colors like #fe3
		NSUInteger color = 0;
		scanner = [NSScanner scannerWithString:code];
		if( ! [scanner scanHexInt:&color] ) return nil;
		return [self colorWithCalibratedRed:( ( ( ( ( color >> 8 ) & 0xf ) << 4 ) | ( ( color >> 8 ) & 0xf ) ) / 255. ) green:( ( ( ( ( color >> 4 ) & 0xf ) << 4 ) | ( ( color >> 4 ) & 0xf ) ) / 255. ) blue:( ( ( ( color & 0xf ) << 4 ) | ( color & 0xf ) ) / 255. ) alpha:1.];
	}

	return nil;
}

@end

//
//  SPColorAdditions.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on August 16, 2010.
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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

#import "SPColorAdditions.h"

@implementation NSColor (SPColorAdditions)

/**
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
		redHexValue   = [NSString stringWithFormat:@"%02lX", (long)(red * 255.0f)];
		greenHexValue = [NSString stringWithFormat:@"%02lX", (long)(green * 255.0f)];
		blueHexValue  = [NSString stringWithFormat:@"%02lX", (long)(blue * 255.0f)];
		alphaHexValue = [NSString stringWithFormat:@"%02lX", (long)(alpha * 255.0f)];
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
		unsigned int color = 0;
		scanner = [NSScanner scannerWithString:code];
		if( ! [scanner scanHexInt:&color] ) return nil;
		return [self colorWithCalibratedRed:( ( ( color >> 24 ) & 0xff ) / 255.f ) green:( ( ( color >> 16 ) & 0xff ) / 255.f ) blue:( ( ( color >> 8) & 0xff ) / 255.f ) alpha:( ( color & 0xff ) / 255.f )];
	}
	else if( [code length] == 6 ) { // decode colors like #ffee33
		unsigned int color = 0;
		scanner = [NSScanner scannerWithString:code];
		if( ! [scanner scanHexInt:&color] ) return nil;
		return [self colorWithCalibratedRed:( ( ( color >> 16 ) & 0xff ) / 255.f ) green:( ( ( color >> 8 ) & 0xff ) / 255.f ) blue:( ( color & 0xff ) / 255.f ) alpha:1.f];
	}
	else if( [code length] == 3 ) {  // decode short-hand colors like #fe3
		unsigned int color = 0;
		scanner = [NSScanner scannerWithString:code];
		if( ! [scanner scanHexInt:&color] ) return nil;
		return [self colorWithCalibratedRed:( ( ( ( ( color >> 8 ) & 0xf ) << 4 ) | ( ( color >> 8 ) & 0xf ) ) / 255.f ) green:( ( ( ( ( color >> 4 ) & 0xf ) << 4 ) | ( ( color >> 4 ) & 0xf ) ) / 255.f ) blue:( ( ( ( color & 0xf ) << 4 ) | ( color & 0xf ) ) / 255.f ) alpha:1.f];
	}

	return nil;
}

@end

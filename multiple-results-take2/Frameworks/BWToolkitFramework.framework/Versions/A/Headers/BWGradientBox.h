//
//  BWGradientBox.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>

@interface BWGradientBox : NSView 
{
	NSColor *fillStartingColor, *fillEndingColor, *fillColor;
	NSColor *topBorderColor, *bottomBorderColor;
	float topInsetAlpha, bottomInsetAlpha;
	
	BOOL hasTopBorder, hasBottomBorder, hasGradient, hasFillColor;
}

@property (nonatomic, retain) NSColor *fillStartingColor, *fillEndingColor, *fillColor, *topBorderColor, *bottomBorderColor;
@property float topInsetAlpha, bottomInsetAlpha;
@property BOOL hasTopBorder, hasBottomBorder, hasGradient, hasFillColor;

@end

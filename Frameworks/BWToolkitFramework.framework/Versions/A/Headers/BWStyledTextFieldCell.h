//
//  BWStyledTextFieldCell.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>

@interface BWStyledTextFieldCell : NSTextFieldCell 
{
	BOOL shadowIsBelow, hasShadow, hasGradient;
	NSColor *shadowColor, *startingColor, *endingColor, *solidColor;
	
	NSShadow *shadow;
	NSMutableDictionary *previousAttributes;
}

@property BOOL shadowIsBelow, hasShadow, hasGradient;
@property (nonatomic, retain) NSColor *shadowColor, *startingColor, *endingColor, *solidColor;

@end

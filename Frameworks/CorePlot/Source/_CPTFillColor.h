#import "CPTFill.h"

@interface _CPTFillColor : CPTFill<NSCopying, NSCoding, NSSecureCoding>

/// @name Initialization
/// @{
-(nonnull instancetype)initWithColor:(nonnull CPTColor *)aColor NS_DESIGNATED_INITIALIZER;
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder NS_DESIGNATED_INITIALIZER;
/// @}

/// @name Drawing
/// @{
-(void)fillRect:(CGRect)rect inContext:(nonnull CGContextRef)context;
-(void)fillPathInContext:(nonnull CGContextRef)context;
/// @}

@end

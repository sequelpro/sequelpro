#import "CPTFill.h"

@class CPTImage;

@interface _CPTFillImage : CPTFill<NSCopying, NSCoding, NSSecureCoding>

/// @name Initialization
/// @{
-(nonnull instancetype)initWithImage:(nonnull CPTImage *)anImage NS_DESIGNATED_INITIALIZER;
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder NS_DESIGNATED_INITIALIZER;
/// @}

/// @name Drawing
/// @{
-(void)fillRect:(CGRect)rect inContext:(nonnull CGContextRef)context;
-(void)fillPathInContext:(nonnull CGContextRef)context;
/// @}

@end

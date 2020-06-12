#import "CPTDecimalNumberValueTransformer.h"
#import "NSNumberExtensions.h"

/**
 *  @brief A Cocoa Bindings value transformer for NSDecimalNumber objects.
 **/
@implementation CPTDecimalNumberValueTransformer

/**
 *  @brief Indicates that the receiver can reverse a transformation.
 *  @return @YES, the transformation is reversible.
 **/
+(BOOL)allowsReverseTransformation
{
    return YES;
}

/**
 *  @brief The class of the value returned for a forward transformation.
 *  @return Transformed values will be instances of NSNumber.
 **/
+(nonnull Class)transformedValueClass
{
    return [NSNumber class];
}

/// @cond

-(nullable id)transformedValue:(nullable id)value
{
    return [value copy];
}

-(nullable id)reverseTransformedValue:(nullable id)value
{
    return [value decimalNumber];
}

/// @endcond

@end

#import "NSNumberExtensions.h"

@implementation NSNumber(CPTExtensions)

/** @brief Creates and returns an NSNumber object containing a given value, treating it as a @ref CGFloat.
 *  @param number The value for the new number.
 *  @return An NSNumber object containing value, treating it as a @ref CGFloat.
 **/
+(nonnull instancetype)numberWithCGFloat:(CGFloat)number
{
    return @(number);
}

/** @brief Returns the value of the receiver as a @ref CGFloat.
 *  @return The value of the receiver as a @ref CGFloat.
 **/
-(CGFloat)cgFloatValue
{
#if CGFLOAT_IS_DOUBLE
    return self.doubleValue;
#else
    return [self floatValue];
#endif
}

/** @brief Returns an NSNumber object initialized to contain a given value, treated as a @ref CGFloat.
 *  @param number The value for the new number.
 *  @return An NSNumber object containing value, treating it as a @ref CGFloat.
 **/
-(nonnull instancetype)initWithCGFloat:(CGFloat)number
{
#if CGFLOAT_IS_DOUBLE
    return [self initWithDouble:number];
#else
    return [self initWithFloat:number];
#endif
}

/** @brief Returns the value of the receiver as an NSDecimalNumber.
 *  @return The value of the receiver as an NSDecimalNumber.
 **/
-(nonnull NSDecimalNumber *)decimalNumber
{
    if ( [self isMemberOfClass:[NSDecimalNumber class]] ) {
        return (NSDecimalNumber *)self;
    }
    return [NSDecimalNumber decimalNumberWithDecimal:self.decimalValue];
}

@end

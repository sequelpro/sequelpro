#import "NSDecimalNumberExtensions.h"

@implementation NSDecimalNumber(CPTExtensions)

/** @brief Returns the value of the receiver as an NSDecimalNumber.
 *  @return The value of the receiver as an NSDecimalNumber.
 **/
-(nonnull NSDecimalNumber *)decimalNumber
{
    return [self copy];
}

@end

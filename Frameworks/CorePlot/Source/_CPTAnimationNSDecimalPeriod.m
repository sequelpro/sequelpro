#import "_CPTAnimationNSDecimalPeriod.h"

#import "CPTUtilities.h"

/// @cond
@interface _CPTAnimationNSDecimalPeriod()

NSDecimal CPTCurrentDecimalValue(id __nonnull boundObject, SEL __nonnull boundGetter);

@end
/// @endcond

#pragma mark -

@implementation _CPTAnimationNSDecimalPeriod

NSDecimal CPTCurrentDecimalValue(id __nonnull boundObject, SEL __nonnull boundGetter)
{
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[boundObject methodSignatureForSelector:boundGetter]];

    invocation.target   = boundObject;
    invocation.selector = boundGetter;

    [invocation invoke];

    NSDecimal value;
    [invocation getReturnValue:&value];

    return value;
}

-(void)setStartValueFromObject:(nonnull id)boundObject propertyGetter:(nonnull SEL)boundGetter
{
    NSDecimal start = CPTCurrentDecimalValue(boundObject, boundGetter);

    self.startValue = [NSDecimalNumber decimalNumberWithDecimal:start];
}

-(BOOL)canStartWithValueFromObject:(nonnull id)boundObject propertyGetter:(nonnull SEL)boundGetter
{
    if ( !self.startValue ) {
        [self setStartValueFromObject:boundObject propertyGetter:boundGetter];
    }

    NSDecimal current = CPTCurrentDecimalValue(boundObject, boundGetter);
    NSDecimal start   = ((NSDecimalNumber *)self.startValue).decimalValue;
    NSDecimal end     = ((NSDecimalNumber *)self.endValue).decimalValue;

    return (CPTDecimalGreaterThanOrEqualTo(current, start) && CPTDecimalLessThanOrEqualTo(current, end)) ||
           (CPTDecimalGreaterThanOrEqualTo(current, end) && CPTDecimalLessThanOrEqualTo(current, start));
}

-(nonnull NSValue *)tweenedValueForProgress:(CGFloat)progress
{
    NSDecimal start = ((NSDecimalNumber *)self.startValue).decimalValue;
    NSDecimal end   = ((NSDecimalNumber *)self.endValue).decimalValue;

    NSDecimal length       = CPTDecimalSubtract(end, start);
    NSDecimal tweenedValue = CPTDecimalAdd(start, CPTDecimalMultiply(CPTDecimalFromCGFloat(progress), length));

    return [NSDecimalNumber decimalNumberWithDecimal:tweenedValue];
}

@end

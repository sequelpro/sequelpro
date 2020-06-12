#import "_CPTAnimationCGFloatPeriod.h"

#import "NSNumberExtensions.h"

/// @cond
@interface _CPTAnimationCGFloatPeriod()

CGFloat CPTCurrentFloatValue(id __nonnull boundObject, SEL __nonnull boundGetter);

@end
/// @endcond

#pragma mark -

@implementation _CPTAnimationCGFloatPeriod

CGFloat CPTCurrentFloatValue(id __nonnull boundObject, SEL __nonnull boundGetter)
{
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[boundObject methodSignatureForSelector:boundGetter]];

    invocation.target   = boundObject;
    invocation.selector = boundGetter;

    [invocation invoke];

    CGFloat value;
    [invocation getReturnValue:&value];

    return value;
}

-(void)setStartValueFromObject:(nonnull id)boundObject propertyGetter:(nonnull SEL)boundGetter
{
    self.startValue = @(CPTCurrentFloatValue(boundObject, boundGetter));
}

-(BOOL)canStartWithValueFromObject:(nonnull id)boundObject propertyGetter:(nonnull SEL)boundGetter
{
    CGFloat current = CPTCurrentFloatValue(boundObject, boundGetter);
    CGFloat start;
    CGFloat end;

    if ( !self.startValue ) {
        [self setStartValueFromObject:boundObject propertyGetter:boundGetter];
    }

    [self.startValue getValue:&start];
    [self.endValue getValue:&end];

    return ((current >= start) && (current <= end)) || ((current >= end) && (current <= start));
}

-(nonnull NSValue *)tweenedValueForProgress:(CGFloat)progress
{
    CGFloat start;
    CGFloat end;

    [self.startValue getValue:&start];
    [self.endValue getValue:&end];

    CGFloat tweenedValue = start + progress * (end - start);

    return @(tweenedValue);
}

@end

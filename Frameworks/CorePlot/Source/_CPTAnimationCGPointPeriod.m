#import "_CPTAnimationCGPointPeriod.h"

/// @cond
@interface _CPTAnimationCGPointPeriod()

CGPoint CPTCurrentPointValue(id __nonnull boundObject, SEL __nonnull boundGetter);

@end
/// @endcond

#pragma mark -

@implementation _CPTAnimationCGPointPeriod

CGPoint CPTCurrentPointValue(id __nonnull boundObject, SEL __nonnull boundGetter)
{
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[boundObject methodSignatureForSelector:boundGetter]];

    invocation.target   = boundObject;
    invocation.selector = boundGetter;

    [invocation invoke];

    CGPoint value;
    [invocation getReturnValue:&value];

    return value;
}

-(void)setStartValueFromObject:(nonnull id)boundObject propertyGetter:(nonnull SEL)boundGetter
{
    CGPoint start = CPTCurrentPointValue(boundObject, boundGetter);

    self.startValue = [NSValue valueWithBytes:&start objCType:@encode(CGPoint)];
}

-(BOOL)canStartWithValueFromObject:(nonnull id)boundObject propertyGetter:(nonnull SEL)boundGetter
{
    CGPoint current = CPTCurrentPointValue(boundObject, boundGetter);
    CGPoint start;
    CGPoint end;

    if ( !self.startValue ) {
        [self setStartValueFromObject:boundObject propertyGetter:boundGetter];
    }

    [self.startValue getValue:&start];
    [self.endValue getValue:&end];

    return (((current.x >= start.x) && (current.x <= end.x)) || ((current.x >= end.x) && (current.x <= start.x))) &&
           (((current.y >= start.y) && (current.y <= end.y)) || ((current.y >= end.y) && (current.y <= start.y)));
}

-(nonnull NSValue *)tweenedValueForProgress:(CGFloat)progress
{
    CGPoint start;
    CGPoint end;

    [self.startValue getValue:&start];
    [self.endValue getValue:&end];

    CGFloat tweenedXValue = start.x + progress * (end.x - start.x);
    CGFloat tweenedYValue = start.y + progress * (end.y - start.y);

    CGPoint tweenedPoint = CGPointMake(tweenedXValue, tweenedYValue);

    return [NSValue valueWithBytes:&tweenedPoint objCType:@encode(CGPoint)];
}

@end

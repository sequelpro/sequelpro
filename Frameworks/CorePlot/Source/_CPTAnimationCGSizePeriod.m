#import "_CPTAnimationCGSizePeriod.h"

/// @cond
@interface _CPTAnimationCGSizePeriod()

CGSize CPTCurrentSizeValue(id __nonnull boundObject, SEL __nonnull boundGetter);

@end
/// @endcond

#pragma mark -

@implementation _CPTAnimationCGSizePeriod

CGSize CPTCurrentSizeValue(id __nonnull boundObject, SEL __nonnull boundGetter)
{
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[boundObject methodSignatureForSelector:boundGetter]];

    invocation.target   = boundObject;
    invocation.selector = boundGetter;

    [invocation invoke];

    CGSize value;
    [invocation getReturnValue:&value];

    return value;
}

-(void)setStartValueFromObject:(nonnull id)boundObject propertyGetter:(nonnull SEL)boundGetter
{
    CGSize start = CPTCurrentSizeValue(boundObject, boundGetter);

    self.startValue = [NSValue valueWithBytes:&start objCType:@encode(CGSize)];
}

-(BOOL)canStartWithValueFromObject:(nonnull id)boundObject propertyGetter:(nonnull SEL)boundGetter
{
    CGSize current = CPTCurrentSizeValue(boundObject, boundGetter);
    CGSize start;
    CGSize end;

    if ( !self.startValue ) {
        [self setStartValueFromObject:boundObject propertyGetter:boundGetter];
    }

    [self.startValue getValue:&start];
    [self.endValue getValue:&end];

    return (((current.width >= start.width) && (current.width <= end.width)) || ((current.width >= end.width) && (current.width <= start.width))) &&
           (((current.height >= start.height) && (current.height <= end.height)) || ((current.height >= end.height) && (current.height <= start.height)));
}

-(nonnull NSValue *)tweenedValueForProgress:(CGFloat)progress
{
    CGSize start;
    CGSize end;

    [self.startValue getValue:&start];
    [self.endValue getValue:&end];

    CGFloat tweenedWidth  = start.width + progress * (end.width - start.width);
    CGFloat tweenedHeight = start.height + progress * (end.height - start.height);

    CGSize tweenedSize = CGSizeMake(tweenedWidth, tweenedHeight);

    return [NSValue valueWithBytes:&tweenedSize objCType:@encode(CGSize)];
}

@end

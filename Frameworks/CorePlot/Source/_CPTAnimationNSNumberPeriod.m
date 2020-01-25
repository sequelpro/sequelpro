#import "_CPTAnimationNSNumberPeriod.h"

#import "CPTUtilities.h"

@implementation _CPTAnimationNSNumberPeriod

-(void)setStartValueFromObject:(id)boundObject propertyGetter:(SEL)boundGetter
{
    typedef NSNumber *(*GetterType)(id, SEL);
    GetterType getterMethod = (GetterType)[boundObject methodForSelector:boundGetter];

    self.startValue = getterMethod(boundObject, boundGetter);
}

-(BOOL)canStartWithValueFromObject:(id)boundObject propertyGetter:(SEL)boundGetter
{
    if ( !self.startValue ) {
        [self setStartValueFromObject:boundObject propertyGetter:boundGetter];
    }

    typedef NSNumber *(*GetterType)(id, SEL);
    GetterType getterMethod = (GetterType)[boundObject methodForSelector:boundGetter];

    NSNumber *current = getterMethod(boundObject, boundGetter);
    NSNumber *start   = (NSNumber *)self.startValue;
    NSNumber *end     = (NSNumber *)self.endValue;

    Class decimalClass = [NSDecimalNumber class];

    if ( [start isKindOfClass:decimalClass] || [end isKindOfClass:decimalClass] ) {
        NSDecimal currentDecimal = current.decimalValue;
        NSDecimal startDecimal   = start.decimalValue;
        NSDecimal endDecimal     = end.decimalValue;

        return (CPTDecimalGreaterThanOrEqualTo(currentDecimal, startDecimal) && CPTDecimalLessThanOrEqualTo(currentDecimal, endDecimal)) ||
               (CPTDecimalGreaterThanOrEqualTo(currentDecimal, endDecimal) && CPTDecimalLessThanOrEqualTo(currentDecimal, startDecimal));
    }
    else {
        double currentDouble = current.doubleValue;
        double startDouble   = start.doubleValue;
        double endDouble     = end.doubleValue;

        return ((currentDouble >= startDouble) && (currentDouble <= endDouble)) ||
               ((currentDouble >= endDouble) && (currentDouble <= startDouble));
    }
}

-(NSValue *)tweenedValueForProgress:(CGFloat)progress
{
    NSNumber *start = (NSNumber *)self.startValue;
    NSNumber *end   = (NSNumber *)self.endValue;

    Class decimalClass = [NSDecimalNumber class];

    if ( [start isKindOfClass:decimalClass] || [end isKindOfClass:decimalClass] ) {
        NSDecimal startDecimal = start.decimalValue;
        NSDecimal endDecimal   = end.decimalValue;

        NSDecimal length       = CPTDecimalSubtract(endDecimal, startDecimal);
        NSDecimal tweenedValue = CPTDecimalAdd(startDecimal, CPTDecimalMultiply(CPTDecimalFromCGFloat(progress), length));

        return [NSDecimalNumber decimalNumberWithDecimal:tweenedValue];
    }
    else {
        double startDouble = start.doubleValue;
        double endDouble   = end.doubleValue;

        double tweenedValue = startDouble + (double)progress * (endDouble - startDouble);

        return @(tweenedValue);
    }
}

@end

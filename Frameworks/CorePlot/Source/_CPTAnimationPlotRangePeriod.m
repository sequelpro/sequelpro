#import "_CPTAnimationPlotRangePeriod.h"

#import "CPTPlotRange.h"
#import "CPTUtilities.h"

@implementation _CPTAnimationPlotRangePeriod

-(void)setStartValueFromObject:(nonnull id)boundObject propertyGetter:(nonnull SEL)boundGetter
{
    typedef NSValue *(*GetterType)(id, SEL);
    GetterType getterMethod = (GetterType)[boundObject methodForSelector:boundGetter];

    self.startValue = getterMethod(boundObject, boundGetter);
}

-(BOOL)canStartWithValueFromObject:(nonnull id)boundObject propertyGetter:(nonnull SEL)boundGetter
{
    if ( !self.startValue ) {
        [self setStartValueFromObject:boundObject propertyGetter:boundGetter];
    }

    typedef CPTPlotRange *(*GetterType)(id, SEL);
    GetterType getterMethod = (GetterType)[boundObject methodForSelector:boundGetter];

    CPTPlotRange *current = getterMethod(boundObject, boundGetter);
    CPTPlotRange *start   = (CPTPlotRange *)self.startValue;
    CPTPlotRange *end     = (CPTPlotRange *)self.endValue;

    NSDecimal currentLoc = current.locationDecimal;
    NSDecimal startLoc   = start.locationDecimal;
    NSDecimal endLoc     = end.locationDecimal;

    return (CPTDecimalGreaterThanOrEqualTo(currentLoc, startLoc) && CPTDecimalLessThanOrEqualTo(currentLoc, endLoc)) ||
           (CPTDecimalGreaterThanOrEqualTo(currentLoc, endLoc) && CPTDecimalLessThanOrEqualTo(currentLoc, startLoc));
}

-(nonnull NSValue *)tweenedValueForProgress:(CGFloat)progress
{
    CPTPlotRange *start = (CPTPlotRange *)self.startValue;
    CPTPlotRange *end   = (CPTPlotRange *)self.endValue;

    NSDecimal progressDecimal = CPTDecimalFromCGFloat(progress);

    NSDecimal locationDiff    = CPTDecimalSubtract(end.locationDecimal, start.locationDecimal);
    NSDecimal tweenedLocation = CPTDecimalAdd(start.locationDecimal, CPTDecimalMultiply(progressDecimal, locationDiff));

    NSDecimal lengthDiff    = CPTDecimalSubtract(end.lengthDecimal, start.lengthDecimal);
    NSDecimal tweenedLength = CPTDecimalAdd(start.lengthDecimal, CPTDecimalMultiply(progressDecimal, lengthDiff));

    return (NSValue *)[CPTPlotRange plotRangeWithLocationDecimal:tweenedLocation lengthDecimal:tweenedLength];
}

@end

#import "_CPTSlateTheme.h"

#import "CPTBorderedLayer.h"
#import "CPTColor.h"
#import "CPTFill.h"
#import "CPTGradient.h"
#import "CPTMutableLineStyle.h"
#import "CPTMutableTextStyle.h"
#import "CPTPlotAreaFrame.h"
#import "CPTUtilities.h"
#import "CPTXYAxis.h"
#import "CPTXYAxisSet.h"
#import "CPTXYGraph.h"

CPTThemeName const kCPTSlateTheme = @"Slate";

#pragma mark -

/**
 *  @brief Creates a CPTXYGraph instance with colors that match the default iPhone navigation bar, toolbar buttons, and table views.
 **/
@implementation _CPTSlateTheme

+(void)load
{
    [self registerTheme:self];
}

+(nonnull NSString *)name
{
    return kCPTSlateTheme;
}

#pragma mark -

-(void)applyThemeToBackground:(nonnull CPTGraph *)graph
{
    CPTGradient *gradient = [CPTGradient gradientWithBeginningColor:[CPTColor colorWithComponentRed:CPTFloat(0.43) green:CPTFloat(0.51) blue:CPTFloat(0.63) alpha:CPTFloat(1.0)]
                                                        endingColor:[CPTColor colorWithComponentRed:CPTFloat(0.70) green:CPTFloat(0.73) blue:CPTFloat(0.80) alpha:CPTFloat(1.0)]];

    gradient.angle = CPTFloat(90.0);

    graph.fill = [CPTFill fillWithGradient:gradient];
}

-(void)applyThemeToPlotArea:(nonnull CPTPlotAreaFrame *)plotAreaFrame
{
    CPTGradient *gradient = [CPTGradient gradientWithBeginningColor:[CPTColor colorWithComponentRed:CPTFloat(0.43) green:CPTFloat(0.51) blue:CPTFloat(0.63) alpha:CPTFloat(1.0)]
                                                        endingColor:[CPTColor colorWithComponentRed:CPTFloat(0.70) green:CPTFloat(0.73) blue:CPTFloat(0.80) alpha:CPTFloat(1.0)]];

    gradient.angle     = CPTFloat(90.0);
    plotAreaFrame.fill = [CPTFill fillWithGradient:gradient];

    CPTMutableLineStyle *borderLineStyle = [CPTMutableLineStyle lineStyle];
    borderLineStyle.lineColor = [CPTColor colorWithGenericGray:CPTFloat(0.2)];
    borderLineStyle.lineWidth = CPTFloat(1.0);

    plotAreaFrame.borderLineStyle = borderLineStyle;
    plotAreaFrame.cornerRadius    = CPTFloat(5.0);
}

-(void)applyThemeToAxisSet:(nonnull CPTAxisSet *)axisSet
{
    CPTMutableLineStyle *majorLineStyle = [CPTMutableLineStyle lineStyle];

    majorLineStyle.lineCap   = kCGLineCapSquare;
    majorLineStyle.lineColor = [CPTColor colorWithComponentRed:CPTFloat(0.0) green:CPTFloat(0.25) blue:CPTFloat(0.50) alpha:CPTFloat(1.0)];
    majorLineStyle.lineWidth = CPTFloat(2.0);

    CPTMutableLineStyle *minorLineStyle = [CPTMutableLineStyle lineStyle];
    minorLineStyle.lineCap   = kCGLineCapSquare;
    minorLineStyle.lineColor = [CPTColor blackColor];
    minorLineStyle.lineWidth = CPTFloat(1.0);

    CPTMutableTextStyle *blackTextStyle = [[CPTMutableTextStyle alloc] init];
    blackTextStyle.color    = [CPTColor blackColor];
    blackTextStyle.fontSize = CPTFloat(14.0);

    CPTMutableTextStyle *minorTickBlackTextStyle = [[CPTMutableTextStyle alloc] init];
    minorTickBlackTextStyle.color    = [CPTColor blackColor];
    minorTickBlackTextStyle.fontSize = CPTFloat(12.0);

    for ( CPTXYAxis *axis in axisSet.axes ) {
        axis.labelingPolicy          = CPTAxisLabelingPolicyFixedInterval;
        axis.majorIntervalLength     = @0.5;
        axis.orthogonalPosition      = @0.0;
        axis.tickDirection           = CPTSignNone;
        axis.minorTicksPerInterval   = 4;
        axis.majorTickLineStyle      = majorLineStyle;
        axis.minorTickLineStyle      = minorLineStyle;
        axis.axisLineStyle           = majorLineStyle;
        axis.majorTickLength         = CPTFloat(7.0);
        axis.minorTickLength         = CPTFloat(5.0);
        axis.labelTextStyle          = blackTextStyle;
        axis.minorTickLabelTextStyle = minorTickBlackTextStyle;
        axis.titleTextStyle          = blackTextStyle;
    }
}

#pragma mark -
#pragma mark NSCoding Methods

-(nonnull Class)classForCoder
{
    return [CPTTheme class];
}

@end

#import "_CPTPlainBlackTheme.h"

#import "CPTBorderedLayer.h"
#import "CPTColor.h"
#import "CPTFill.h"
#import "CPTMutableLineStyle.h"
#import "CPTMutableTextStyle.h"
#import "CPTPlotAreaFrame.h"
#import "CPTUtilities.h"
#import "CPTXYAxis.h"
#import "CPTXYAxisSet.h"
#import "CPTXYGraph.h"

CPTThemeName const kCPTPlainBlackTheme = @"Plain Black";

/**
 *  @brief Creates a CPTXYGraph instance formatted with black backgrounds and white lines.
 **/
@implementation _CPTPlainBlackTheme

+(void)load
{
    [self registerTheme:self];
}

+(nonnull NSString *)name
{
    return kCPTPlainBlackTheme;
}

#pragma mark -

-(void)applyThemeToBackground:(nonnull CPTGraph *)graph
{
    graph.fill = [CPTFill fillWithColor:[CPTColor blackColor]];
}

-(void)applyThemeToPlotArea:(nonnull CPTPlotAreaFrame *)plotAreaFrame
{
    plotAreaFrame.fill = [CPTFill fillWithColor:[CPTColor blackColor]];

    CPTMutableLineStyle *borderLineStyle = [CPTMutableLineStyle lineStyle];
    borderLineStyle.lineColor = [CPTColor whiteColor];
    borderLineStyle.lineWidth = CPTFloat(1.0);

    plotAreaFrame.borderLineStyle = borderLineStyle;
    plotAreaFrame.cornerRadius    = CPTFloat(0.0);
}

-(void)applyThemeToAxisSet:(nonnull CPTAxisSet *)axisSet
{
    CPTMutableLineStyle *majorLineStyle = [CPTMutableLineStyle lineStyle];

    majorLineStyle.lineCap   = kCGLineCapRound;
    majorLineStyle.lineColor = [CPTColor whiteColor];
    majorLineStyle.lineWidth = CPTFloat(3.0);

    CPTMutableLineStyle *minorLineStyle = [CPTMutableLineStyle lineStyle];
    minorLineStyle.lineColor = [CPTColor whiteColor];
    minorLineStyle.lineWidth = CPTFloat(3.0);

    CPTMutableTextStyle *whiteTextStyle = [[CPTMutableTextStyle alloc] init];
    whiteTextStyle.color    = [CPTColor whiteColor];
    whiteTextStyle.fontSize = CPTFloat(14.0);

    CPTMutableTextStyle *minorTickWhiteTextStyle = [[CPTMutableTextStyle alloc] init];
    minorTickWhiteTextStyle.color    = [CPTColor whiteColor];
    minorTickWhiteTextStyle.fontSize = CPTFloat(12.0);

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
        axis.labelTextStyle          = whiteTextStyle;
        axis.minorTickLabelTextStyle = whiteTextStyle;
        axis.titleTextStyle          = whiteTextStyle;
    }
}

#pragma mark -
#pragma mark NSCoding Methods

-(nonnull Class)classForCoder
{
    return [CPTTheme class];
}

@end

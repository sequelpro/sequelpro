#import "_CPTXYTheme.h"

#import "CPTPlotRange.h"
#import "CPTUtilities.h"
#import "CPTXYGraph.h"
#import "CPTXYPlotSpace.h"

/**
 *  @brief Creates a CPTXYGraph instance formatted with padding of 60 on each side and X and Y plot ranges of +/- 1.
 **/
@implementation _CPTXYTheme

/// @name Initialization
/// @{

-(nonnull instancetype)init
{
    if ((self = [super init])) {
        self.graphClass = [CPTXYGraph class];
    }
    return self;
}

/// @}

-(nullable id)newGraph
{
    CPTXYGraph *graph;

    if ( self.graphClass ) {
        graph = [[self.graphClass alloc] initWithFrame:CPTRectMake(0.0, 0.0, 200.0, 200.0)];
    }
    else {
        graph = [[CPTXYGraph alloc] initWithFrame:CPTRectMake(0.0, 0.0, 200.0, 200.0)];
    }
    graph.paddingLeft   = CPTFloat(60.0);
    graph.paddingTop    = CPTFloat(60.0);
    graph.paddingRight  = CPTFloat(60.0);
    graph.paddingBottom = CPTFloat(60.0);

    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:@(-1.0) length:@1.0];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:@(-1.0) length:@1.0];

    [self applyThemeToGraph:graph];

    return graph;
}

#pragma mark -
#pragma mark NSCoding Methods

-(nonnull Class)classForCoder
{
    return [CPTTheme class];
}

@end

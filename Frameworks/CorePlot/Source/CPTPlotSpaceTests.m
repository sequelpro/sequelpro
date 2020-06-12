#import "CPTPlotSpaceTests.h"

#import "CPTPlotSpace.h"
#import "CPTXYGraph.h"

@implementation CPTPlotSpaceTests

@synthesize graph;

-(void)setUp
{
    self.graph               = [[CPTXYGraph alloc] initWithFrame:CPTRectMake(0.0, 0.0, 100.0, 50.0)];
    self.graph.paddingLeft   = 0.0;
    self.graph.paddingRight  = 0.0;
    self.graph.paddingTop    = 0.0;
    self.graph.paddingBottom = 0.0;

    [self.graph layoutIfNeeded];
}

-(void)tearDown
{
    self.graph = nil;
}

#pragma mark -
#pragma mark NSCoding Methods

-(void)testKeyedArchivingRoundTrip
{
    CPTPlotSpace *plotSpace = self.graph.defaultPlotSpace;

    plotSpace.identifier = @"test plot space";

    CPTPlotSpace *newPlotSpace = [self archiveRoundTrip:plotSpace];

    XCTAssertEqualObjects(plotSpace.identifier, newPlotSpace.identifier, @"identifier not equal");
    XCTAssertEqual(plotSpace.allowsUserInteraction, newPlotSpace.allowsUserInteraction, @"allowsUserInteraction not equal");
}

@end

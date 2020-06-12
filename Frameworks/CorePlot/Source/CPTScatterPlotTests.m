#import "CPTScatterPlotTests.h"

#import "CPTPlotRange.h"
#import "CPTScatterPlot.h"
#import "CPTXYPlotSpace.h"

@interface CPTScatterPlot(Testing)

-(void)calculatePointsToDraw:(nonnull BOOL *)pointDrawFlags forPlotSpace:(nonnull CPTXYPlotSpace *)xyPlotSpace includeVisiblePointsOnly:(BOOL)visibleOnly numberOfPoints:(NSUInteger)dataCount;
-(void)setXValues:(nullable CPTNumberArray *)newValues;
-(void)setYValues:(nullable CPTNumberArray *)newValues;

@end

@implementation CPTScatterPlotTests

@synthesize plot;
@synthesize plotSpace;

-(void)setUp
{
    CPTNumberArray *yValues = @[@0.5, @0.5, @0.5, @0.5, @0.5];

    self.plot = [CPTScatterPlot new];
    [self.plot setYValues:yValues];
    self.plot.cachePrecision = CPTPlotCachePrecisionDouble;

    CPTPlotRange *xPlotRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@1.0];
    CPTPlotRange *yPlotRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@1.0];
    self.plotSpace        = [[CPTXYPlotSpace alloc] init];
    self.plotSpace.xRange = xPlotRange;
    self.plotSpace.yRange = yPlotRange;
}

-(void)tearDown
{
    self.plot      = nil;
    self.plotSpace = nil;
}

-(void)testCalculatePointsToDrawAllInRange
{
    CPTNumberArray *inRangeValues = @[@0.1, @0.2, @0.15, @0.6, @0.9];

    BOOL *drawFlags = calloc(inRangeValues.count, sizeof(BOOL));

    CPTXYPlotSpace *thePlotSpace = self.plotSpace;

    [self.plot setXValues:inRangeValues];
    [self.plot calculatePointsToDraw:drawFlags forPlotSpace:thePlotSpace includeVisiblePointsOnly:NO numberOfPoints:inRangeValues.count];

    for ( NSUInteger i = 0; i < inRangeValues.count; i++ ) {
        XCTAssertTrue(drawFlags[i], @"Test that in range points are drawn (%@).", inRangeValues[i]);
    }

    free(drawFlags);
}

-(void)testCalculatePointsToDrawAllInRangeVisibleOnly
{
    CPTNumberArray *inRangeValues = @[@0.1, @0.2, @0.15, @0.6, @0.9];

    BOOL *drawFlags = calloc(inRangeValues.count, sizeof(BOOL));

    CPTXYPlotSpace *thePlotSpace = self.plotSpace;

    [self.plot setXValues:inRangeValues];
    [self.plot calculatePointsToDraw:drawFlags forPlotSpace:thePlotSpace includeVisiblePointsOnly:YES numberOfPoints:inRangeValues.count];

    for ( NSUInteger i = 0; i < inRangeValues.count; i++ ) {
        XCTAssertTrue(drawFlags[i], @"Test that in range points are drawn (%@).", inRangeValues[i]);
    }

    free(drawFlags);
}

-(void)testCalculatePointsToDrawNoneInRange
{
    CPTNumberArray *inRangeValues = @[@(-0.1), @(-0.2), @(-0.15), @(-0.6), @(-0.9)];

    BOOL *drawFlags = calloc(inRangeValues.count, sizeof(BOOL));

    CPTXYPlotSpace *thePlotSpace = self.plotSpace;

    [self.plot setXValues:inRangeValues];
    [self.plot calculatePointsToDraw:drawFlags forPlotSpace:thePlotSpace includeVisiblePointsOnly:NO numberOfPoints:inRangeValues.count];

    for ( NSUInteger i = 0; i < inRangeValues.count; i++ ) {
        XCTAssertFalse(drawFlags[i], @"Test that out of range points are not drawn (%@).", inRangeValues[i]);
    }

    free(drawFlags);
}

-(void)testCalculatePointsToDrawNoneInRangeVisibleOnly
{
    CPTNumberArray *inRangeValues = @[@(-0.1), @(-0.2), @(-0.15), @(-0.6), @(-0.9)];

    BOOL *drawFlags = calloc(inRangeValues.count, sizeof(BOOL));

    CPTXYPlotSpace *thePlotSpace = self.plotSpace;

    [self.plot setXValues:inRangeValues];
    [self.plot calculatePointsToDraw:drawFlags forPlotSpace:thePlotSpace includeVisiblePointsOnly:YES numberOfPoints:inRangeValues.count];

    for ( NSUInteger i = 0; i < inRangeValues.count; i++ ) {
        XCTAssertFalse(drawFlags[i], @"Test that out of range points are not drawn (%@).", inRangeValues[i]);
    }

    free(drawFlags);
}

-(void)testCalculatePointsToDrawNoneInRangeDifferentRegions
{
    CPTNumberArray *inRangeValues = @[@(-0.1), @2, @(-0.15), @3, @(-0.9)];

    BOOL *drawFlags = calloc(inRangeValues.count, sizeof(BOOL));

    CPTXYPlotSpace *thePlotSpace = self.plotSpace;

    [self.plot setXValues:inRangeValues];
    [self.plot calculatePointsToDraw:drawFlags forPlotSpace:thePlotSpace includeVisiblePointsOnly:NO numberOfPoints:inRangeValues.count];

    for ( NSUInteger i = 0; i < inRangeValues.count; i++ ) {
        XCTAssertTrue(drawFlags[i], @"Test that out of range points in different regions get included (%@).", inRangeValues[i]);
    }

    free(drawFlags);
}

-(void)testCalculatePointsToDrawNoneInRangeDifferentRegionsVisibleOnly
{
    CPTNumberArray *inRangeValues = @[@(-0.1), @2, @(-0.15), @3, @(-0.9)];

    BOOL *drawFlags = calloc(inRangeValues.count, sizeof(BOOL));

    CPTXYPlotSpace *thePlotSpace = self.plotSpace;

    [self.plot setXValues:inRangeValues];
    [self.plot calculatePointsToDraw:drawFlags forPlotSpace:thePlotSpace includeVisiblePointsOnly:YES numberOfPoints:inRangeValues.count];

    for ( NSUInteger i = 0; i < inRangeValues.count; i++ ) {
        XCTAssertFalse(drawFlags[i], @"Test that out of range points in different regions get included (%@).", inRangeValues[i]);
    }

    free(drawFlags);
}

-(void)testCalculatePointsToDrawSomeInRange
{
    CPTNumberArray *inRangeValues = @[@(-0.1), @0.1, @0.2, @1.2, @1.5];
    BOOL expected[5]              = { YES, YES, YES, YES, NO };

    BOOL *drawFlags = calloc(inRangeValues.count, sizeof(BOOL));

    CPTXYPlotSpace *thePlotSpace = self.plotSpace;

    [self.plot setXValues:inRangeValues];
    [self.plot calculatePointsToDraw:drawFlags forPlotSpace:thePlotSpace includeVisiblePointsOnly:NO numberOfPoints:inRangeValues.count];
    for ( NSUInteger i = 0; i < inRangeValues.count; i++ ) {
        if ( expected[i] ) {
            XCTAssertTrue(drawFlags[i], @"Test that correct points included when some are in range, others out (%@).", inRangeValues[i]);
        }
        else {
            XCTAssertFalse(drawFlags[i], @"Test that correct points included when some are in range, others out (%@).", inRangeValues[i]);
        }
    }

    free(drawFlags);
}

-(void)testCalculatePointsToDrawSomeInRangeVisibleOnly
{
    CPTNumberArray *inRangeValues = @[@(-0.1), @0.1, @0.2, @1.2, @1.5];

    BOOL *drawFlags = calloc(inRangeValues.count, sizeof(BOOL));

    CPTXYPlotSpace *thePlotSpace = self.plotSpace;

    [self.plot setXValues:inRangeValues];
    [self.plot calculatePointsToDraw:drawFlags forPlotSpace:thePlotSpace includeVisiblePointsOnly:YES numberOfPoints:inRangeValues.count];

    for ( NSUInteger i = 0; i < inRangeValues.count; i++ ) {
        if ( [self.plotSpace.xRange compareToNumber:inRangeValues[i]] == CPTPlotRangeComparisonResultNumberInRange ) {
            XCTAssertTrue(drawFlags[i], @"Test that correct points included when some are in range, others out (%@).", inRangeValues[i]);
        }
        else {
            XCTAssertFalse(drawFlags[i], @"Test that correct points included when some are in range, others out (%@).", inRangeValues[i]);
        }
    }

    free(drawFlags);
}

-(void)testCalculatePointsToDrawSomeInRangeCrossing
{
    CPTNumberArray *inRangeValues = @[@(-0.1), @1.1, @0.9, @(-0.1), @(-0.2)];

    BOOL *drawFlags = calloc(inRangeValues.count, sizeof(BOOL));
    BOOL *expected  = calloc(inRangeValues.count, sizeof(BOOL));

    for ( NSUInteger i = 0; i < inRangeValues.count - 1; i++ ) {
        expected[i] = YES;
    }
    expected[inRangeValues.count] = NO;

    CPTXYPlotSpace *thePlotSpace = self.plotSpace;

    [self.plot setXValues:inRangeValues];
    [self.plot calculatePointsToDraw:drawFlags forPlotSpace:thePlotSpace includeVisiblePointsOnly:NO numberOfPoints:inRangeValues.count];

    for ( NSUInteger i = 0; i < inRangeValues.count; i++ ) {
        if ( expected[i] ) {
            XCTAssertTrue(drawFlags[i], @"Test that correct points included when some are in range, others out, crossing range (%@).", inRangeValues[i]);
        }
        else {
            XCTAssertFalse(drawFlags[i], @"Test that correct points included when some are in range, others out, crossing range (%@).", inRangeValues[i]);
        }
    }

    free(drawFlags);
    free(expected);
}

-(void)testCalculatePointsToDrawSomeInRangeCrossingVisibleOnly
{
    CPTNumberArray *inRangeValues = @[@(-0.1), @1.1, @0.9, @(-0.1), @(-0.2)];

    BOOL *drawFlags = calloc(inRangeValues.count, sizeof(BOOL));

    CPTXYPlotSpace *thePlotSpace = self.plotSpace;

    [self.plot setXValues:inRangeValues];
    [self.plot calculatePointsToDraw:drawFlags forPlotSpace:thePlotSpace includeVisiblePointsOnly:YES numberOfPoints:inRangeValues.count];

    for ( NSUInteger i = 0; i < inRangeValues.count; i++ ) {
        if ( [self.plotSpace.xRange compareToNumber:inRangeValues[i]] == CPTPlotRangeComparisonResultNumberInRange ) {
            XCTAssertTrue(drawFlags[i], @"Test that correct points included when some are in range, others out, crossing range (%@).", inRangeValues[i]);
        }
        else {
            XCTAssertFalse(drawFlags[i], @"Test that correct points included when some are in range, others out, crossing range (%@).", inRangeValues[i]);
        }
    }

    free(drawFlags);
}

@end

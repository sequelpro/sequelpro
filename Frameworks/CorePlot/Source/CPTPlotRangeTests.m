#import "CPTPlotRangeTests.h"

#import "CPTMutablePlotRange.h"
#import "CPTUtilities.h"

@interface CPTPlotRangeTests()

-(void)checkRangeWithLocation:(double)loc length:(double)len;

@end

#pragma mark -

@implementation CPTPlotRangeTests

@synthesize plotRange;

-(void)setUp
{
    self.plotRange = [CPTMutablePlotRange plotRangeWithLocation:@1.0 length:@2.0];
}

-(void)tearDown
{
    self.plotRange = nil;
}

#pragma mark -
#pragma mark Checking Ranges

-(void)testContains
{
    XCTAssertFalse([self.plotRange contains:CPTDecimalFromDouble(0.999)], @"Test contains:0.999");
    XCTAssertTrue([self.plotRange contains:CPTDecimalFromDouble(1.0)], @"Test contains:1.0");
    XCTAssertTrue([self.plotRange contains:CPTDecimalFromDouble(2.0)], @"Test contains:2.0");
    XCTAssertTrue([self.plotRange contains:CPTDecimalFromDouble(3.0)], @"Test contains:3.0");
    XCTAssertFalse([self.plotRange contains:CPTDecimalFromDouble(3.001)], @"Test contains:3.001");
}

-(void)testContainsInfinite
{
    self.plotRange.lengthDouble = HUGE_VAL;

    XCTAssertFalse([self.plotRange contains:CPTDecimalFromDouble(0.999)], @"Test contains:0.999");
    XCTAssertTrue([self.plotRange contains:CPTDecimalFromDouble(1.0)], @"Test contains:1.0");
    XCTAssertTrue([self.plotRange contains:CPTDecimalFromDouble(2.0)], @"Test contains:2.0");
    XCTAssertTrue([self.plotRange contains:CPTDecimalFromDouble(3.0)], @"Test contains:3.0");
    XCTAssertTrue([self.plotRange contains:CPTDecimalFromDouble(3.001)], @"Test contains:3.001");
}

-(void)testContainsNegative
{
    self.plotRange.lengthDouble = -2.0;

    XCTAssertFalse([self.plotRange contains:CPTDecimalFromDouble(-1.001)], @"Test contains:-1.001");
    XCTAssertTrue([self.plotRange contains:CPTDecimalFromDouble(-1.0)], @"Test contains:-1.0");
    XCTAssertTrue([self.plotRange contains:CPTDecimalFromDouble(0.0)], @"Test contains:0.0");
    XCTAssertTrue([self.plotRange contains:CPTDecimalFromDouble(1.0)], @"Test contains:1.0");
    XCTAssertFalse([self.plotRange contains:CPTDecimalFromDouble(1.001)], @"Test contains:1.001");
}

-(void)testContainsNegativeInfinite
{
    self.plotRange.lengthDouble = -HUGE_VAL;

    XCTAssertTrue([self.plotRange contains:CPTDecimalFromDouble(-1.001)], @"Test contains:-1.001");
    XCTAssertTrue([self.plotRange contains:CPTDecimalFromDouble(-1.0)], @"Test contains:-1.0");
    XCTAssertTrue([self.plotRange contains:CPTDecimalFromDouble(0.0)], @"Test contains:0.0");
    XCTAssertTrue([self.plotRange contains:CPTDecimalFromDouble(1.0)], @"Test contains:1.0");
    XCTAssertFalse([self.plotRange contains:CPTDecimalFromDouble(1.001)], @"Test contains:1.001");
}

-(void)testContainsDouble
{
    XCTAssertFalse([self.plotRange containsDouble:0.999], @"Test contains:0.999");
    XCTAssertTrue([self.plotRange containsDouble:1.0], @"Test contains:1.0");
    XCTAssertTrue([self.plotRange containsDouble:2.0], @"Test contains:2.0");
    XCTAssertTrue([self.plotRange containsDouble:3.0], @"Test contains:3.0");
    XCTAssertFalse([self.plotRange containsDouble:3.001], @"Test contains:3.001");
}

-(void)testContainsDoubleInfinite
{
    self.plotRange.lengthDouble = HUGE_VAL;

    XCTAssertFalse([self.plotRange containsDouble:0.999], @"Test contains:0.999");
    XCTAssertTrue([self.plotRange containsDouble:1.0], @"Test contains:1.0");
    XCTAssertTrue([self.plotRange containsDouble:2.0], @"Test contains:2.0");
    XCTAssertTrue([self.plotRange containsDouble:3.0], @"Test contains:3.0");
    XCTAssertTrue([self.plotRange containsDouble:3.001], @"Test contains:3.001");
}

-(void)testContainsNumber
{
    XCTAssertFalse([self.plotRange containsNumber:@(0.999)], @"Test contains:0.999");
    XCTAssertTrue([self.plotRange containsNumber:[NSDecimalNumber one]], @"Test contains:1.0");
    XCTAssertTrue([self.plotRange containsNumber:@(2.0)], @"Test contains:2.0");
    XCTAssertTrue([self.plotRange containsNumber:@(3.0)], @"Test contains:3.0");
    XCTAssertFalse([self.plotRange containsNumber:@(3.001)], @"Test contains:3.001");
}

-(void)testContainsNumberInfinite
{
    self.plotRange.lengthDouble = HUGE_VAL;

    XCTAssertFalse([self.plotRange containsNumber:@(0.999)], @"Test contains:0.999");
    XCTAssertTrue([self.plotRange containsNumber:[NSDecimalNumber one]], @"Test contains:1.0");
    XCTAssertTrue([self.plotRange containsNumber:@(2.0)], @"Test contains:2.0");
    XCTAssertTrue([self.plotRange containsNumber:@(3.0)], @"Test contains:3.0");
    XCTAssertTrue([self.plotRange containsNumber:@(3.001)], @"Test contains:3.001");
}

-(void)testContainsDoubleNegative
{
    self.plotRange.lengthDouble = -2.0;

    XCTAssertFalse([self.plotRange containsDouble:-1.001], @"Test contains:-1.001");
    XCTAssertTrue([self.plotRange containsDouble:-1.0], @"Test contains:-1.0");
    XCTAssertTrue([self.plotRange containsDouble:0.0], @"Test contains:0.0");
    XCTAssertTrue([self.plotRange containsDouble:1.0], @"Test contains:1.0");
    XCTAssertFalse([self.plotRange containsDouble:1.001], @"Test contains:1.001");
}

-(void)testContainsDoubleNegativeInfinite
{
    self.plotRange.lengthDouble = -HUGE_VAL;

    XCTAssertTrue([self.plotRange containsDouble:-1.001], @"Test contains:-1.001");
    XCTAssertTrue([self.plotRange containsDouble:-1.0], @"Test contains:-1.0");
    XCTAssertTrue([self.plotRange containsDouble:0.0], @"Test contains:0.0");
    XCTAssertTrue([self.plotRange containsDouble:1.0], @"Test contains:1.0");
    XCTAssertFalse([self.plotRange containsDouble:1.001], @"Test contains:1.001");
}

-(void)testContainsRange
{
    CPTPlotRange *otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0];

    XCTAssertFalse([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);

    otherRange = [CPTPlotRange plotRangeWithLocation:@1.0 length:@2.0];
    XCTAssertTrue([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);

    otherRange = [CPTPlotRange plotRangeWithLocation:@2.0 length:@1.0];
    XCTAssertTrue([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);

    otherRange = [CPTPlotRange plotRangeWithLocation:@2.0 length:@4.0];
    XCTAssertFalse([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);

    otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@2.0];
    XCTAssertFalse([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
}

-(void)testContainsRangeInfinite
{
    self.plotRange.lengthDouble = HUGE_VAL;

    CPTPlotRange *otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0];

    XCTAssertFalse([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);

    otherRange = [CPTPlotRange plotRangeWithLocation:@1.0 length:@2.0];
    XCTAssertTrue([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);

    otherRange = [CPTPlotRange plotRangeWithLocation:@2.0 length:@1.0];
    XCTAssertTrue([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);

    otherRange = [CPTPlotRange plotRangeWithLocation:@2.0 length:@4.0];
    XCTAssertTrue([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);

    otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@2.0];
    XCTAssertFalse([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
}

-(void)testContainsRangeNegativeInfinite
{
    self.plotRange.lengthDouble = -HUGE_VAL;

    CPTPlotRange *otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0];

    XCTAssertFalse([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);

    otherRange = [CPTPlotRange plotRangeWithLocation:@1.0 length:@(-2.0)];
    XCTAssertTrue([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);

    otherRange = [CPTPlotRange plotRangeWithLocation:@2.0 length:@(-1.0)];
    XCTAssertFalse([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);

    otherRange = [CPTPlotRange plotRangeWithLocation:@2.0 length:@4.0];
    XCTAssertFalse([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);

    otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@(-2.0)];
    XCTAssertTrue([self.plotRange containsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
}

#pragma mark -
#pragma mark Union

-(void)testUnionRange
{
    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0]];
    [self checkRangeWithLocation:0.0 length:4.0];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@1.0]];
    [self checkRangeWithLocation:-1.0 length:5.0];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@2.0]];
    [self checkRangeWithLocation:-1.0 length:8.0];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@(-4.0)]];
    [self checkRangeWithLocation:-4.0 length:11.0];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@(-4.0)]];
    [self checkRangeWithLocation:-5.0 length:12.0];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@(-4.0)]];
    [self checkRangeWithLocation:-5.0 length:12.0];
}

-(void)testUnionRangeInfinite
{
    self.plotRange.lengthDouble = HUGE_VAL;

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0]];
    [self checkRangeWithLocation:0.0 length:HUGE_VAL];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@1.0]];
    [self checkRangeWithLocation:-1.0 length:HUGE_VAL];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@2.0]];
    [self checkRangeWithLocation:-1.0 length:HUGE_VAL];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@(-4.0)]];
    [self checkRangeWithLocation:-4.0 length:HUGE_VAL];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@(-4.0)]];
    [self checkRangeWithLocation:-5.0 length:HUGE_VAL];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@(HUGE_VAL)]];
    [self checkRangeWithLocation:-5.0 length:HUGE_VAL];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@(-HUGE_VAL)]];
    [self checkRangeWithLocation:-HUGE_VAL length:HUGE_VAL];
}

-(void)testUnionRangeNegative
{
    self.plotRange.lengthDouble = -2.0;

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0]];
    [self checkRangeWithLocation:4.0 length:-5.0];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@1.0]];
    [self checkRangeWithLocation:4.0 length:-5.0];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@2.0]];
    [self checkRangeWithLocation:7.0 length:-8.0];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@(-4.0)]];
    [self checkRangeWithLocation:7.0 length:-11.0];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@(-4.0)]];
    [self checkRangeWithLocation:7.0 length:-12.0];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@(-4.0)]];
    [self checkRangeWithLocation:7.0 length:-12.0];
}

-(void)testUnionRangeNegativeInfinite
{
    self.plotRange.lengthDouble = -HUGE_VAL;

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0]];
    [self checkRangeWithLocation:4.0 length:-HUGE_VAL];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@1.0]];
    [self checkRangeWithLocation:4.0 length:-HUGE_VAL];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@2.0]];
    [self checkRangeWithLocation:7.0 length:-HUGE_VAL];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@(-4.0)]];
    [self checkRangeWithLocation:7.0 length:-HUGE_VAL];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@(-4.0)]];
    [self checkRangeWithLocation:7.0 length:-HUGE_VAL];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@10.0 length:@(-HUGE_VAL)]];
    [self checkRangeWithLocation:10.0 length:-HUGE_VAL];

    [self.plotRange unionPlotRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@(HUGE_VAL)]];
    [self checkRangeWithLocation:-HUGE_VAL length:HUGE_VAL];
}

#pragma mark -
#pragma mark Intersection

-(void)testIntersectRange
{
    CPTPlotRange *otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0];

    XCTAssertTrue([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:1.0 length:2.0];

    otherRange = [CPTPlotRange plotRangeWithLocation:@1.0 length:@1.0];
    XCTAssertTrue([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:1.0 length:1.0];

    otherRange = [CPTPlotRange plotRangeWithLocation:@(-1.0) length:@1.0];
    XCTAssertFalse([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:(double)NAN length:(double)NAN];
}

-(void)testIntersectRange2
{
    CPTPlotRange *otherRange = [CPTPlotRange plotRangeWithLocation:@4.0 length:@(-4.0)];

    XCTAssertTrue([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:1.0 length:2.0];

    otherRange = [CPTPlotRange plotRangeWithLocation:@2.0 length:@(-1.0)];
    XCTAssertTrue([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:1.0 length:1.0];

    otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@(-4.0)];
    XCTAssertFalse([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:(double)NAN length:(double)NAN];
}

-(void)testIntersectRangeNegative
{
    self.plotRange.lengthDouble = -2.0;

    CPTPlotRange *otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0];
    XCTAssertTrue([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:1.0 length:-1.0];

    otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@1.0];
    XCTAssertTrue([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:1.0 length:-1.0];

    otherRange = [CPTPlotRange plotRangeWithLocation:@5.0 length:@2.0];
    XCTAssertFalse([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:(double)NAN length:(double)NAN];
}

-(void)testIntersectRangeNegative2
{
    self.plotRange.lengthDouble = -2.0;

    CPTPlotRange *otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@(-4.0)];
    XCTAssertTrue([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:0.0 length:-1.0];

    otherRange = [CPTPlotRange plotRangeWithLocation:@2.0 length:@(-4.0)];
    XCTAssertTrue([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:0.0 length:-1.0];

    otherRange = [CPTPlotRange plotRangeWithLocation:@5.0 length:@(-4.0)];
    XCTAssertFalse([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:(double)NAN length:(double)NAN];
}

-(void)testIntersectRangeInfinite1
{
    self.plotRange.lengthDouble = HUGE_VAL;

    CPTPlotRange *otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0];
    XCTAssertTrue([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:1.0 length:3.0];
}

-(void)testIntersectRangeInfinite2
{
    self.plotRange.lengthDouble = HUGE_VAL;

    CPTPlotRange *otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@(HUGE_VAL)];
    XCTAssertTrue([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:1.0 length:HUGE_VAL];
}

-(void)testIntersectRangeInfinite3
{
    self.plotRange.lengthDouble = HUGE_VAL;

    CPTPlotRange *otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@(-4.0)];
    XCTAssertFalse([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:(double)NAN length:(double)NAN];
}

-(void)testIntersectRangeNegativeInfinite1
{
    self.plotRange.lengthDouble = -HUGE_VAL;

    CPTPlotRange *otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0];
    XCTAssertTrue([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:1.0 length:-1.0];
}

-(void)testIntersectRangeNegativeInfinite2
{
    self.plotRange.lengthDouble = -HUGE_VAL;

    CPTPlotRange *otherRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@(-HUGE_VAL)];
    XCTAssertTrue([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:0.0 length:-HUGE_VAL];
}

-(void)testIntersectRangeNegativeInfinite3
{
    self.plotRange.lengthDouble = -HUGE_VAL;

    CPTPlotRange *otherRange = [CPTPlotRange plotRangeWithLocation:@10.0 length:@(-4.0)];
    XCTAssertFalse([self.plotRange intersectsRange:otherRange], @"otherRange was {%g, %g}", otherRange.locationDouble, otherRange.lengthDouble);
    [self.plotRange intersectionPlotRange:otherRange];
    [self checkRangeWithLocation:(double)NAN length:(double)NAN];
}

#pragma mark -
#pragma mark Shifting Ranges

-(void)testShiftLocation
{
    [self.plotRange shiftLocationToFitInRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0]];
    [self checkRangeWithLocation:1.0 length:2.0];

    [self.plotRange shiftLocationToFitInRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@1.0]];
    [self checkRangeWithLocation:0.0 length:2.0];

    [self.plotRange shiftLocationToFitInRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@2.0]];
    [self checkRangeWithLocation:5.0 length:2.0];

    [self.plotRange shiftLocationToFitInRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@(-4.0)]];
    [self checkRangeWithLocation:0.0 length:2.0];

    [self.plotRange shiftLocationToFitInRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@(-4.0)]];
    [self checkRangeWithLocation:-1.0 length:2.0];

    [self.plotRange shiftLocationToFitInRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@(-4.0)]];
    [self checkRangeWithLocation:1.0 length:2.0];
}

-(void)testShiftLocationNegative
{
    self.plotRange.lengthDouble = -2.0;

    [self.plotRange shiftLocationToFitInRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0]];
    [self checkRangeWithLocation:1.0 length:-2.0];

    [self.plotRange shiftLocationToFitInRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@1.0]];
    [self checkRangeWithLocation:0.0 length:-2.0];

    [self.plotRange shiftLocationToFitInRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@2.0]];
    [self checkRangeWithLocation:5.0 length:-2.0];

    [self.plotRange shiftLocationToFitInRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@(-4.0)]];
    [self checkRangeWithLocation:0.0 length:-2.0];

    [self.plotRange shiftLocationToFitInRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@(-4.0)]];
    [self checkRangeWithLocation:-1.0 length:-2.0];

    [self.plotRange shiftLocationToFitInRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@(-4.0)]];
    [self checkRangeWithLocation:1.0 length:-2.0];
}

-(void)testShiftEnd
{
    [self.plotRange shiftEndToFitInRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0]];
    [self checkRangeWithLocation:1.0 length:2.0];

    [self.plotRange shiftEndToFitInRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@1.0]];
    [self checkRangeWithLocation:-2.0 length:2.0];

    [self.plotRange shiftEndToFitInRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@2.0]];
    [self checkRangeWithLocation:3.0 length:2.0];

    [self.plotRange shiftEndToFitInRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@(-4.0)]];
    [self checkRangeWithLocation:-2.0 length:2.0];

    [self.plotRange shiftEndToFitInRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@(-4.0)]];
    [self checkRangeWithLocation:-3.0 length:2.0];

    [self.plotRange shiftEndToFitInRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@(-4.0)]];
    [self checkRangeWithLocation:-1.0 length:2.0];
}

-(void)testShiftEndNegative
{
    self.plotRange.lengthDouble = -2.0;

    [self.plotRange shiftEndToFitInRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@4.0]];
    [self checkRangeWithLocation:2.0 length:-2.0];

    [self.plotRange shiftEndToFitInRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@1.0]];
    [self checkRangeWithLocation:2.0 length:-2.0];

    [self.plotRange shiftEndToFitInRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@2.0]];
    [self checkRangeWithLocation:7.0 length:-2.0];

    [self.plotRange shiftEndToFitInRange:[CPTPlotRange plotRangeWithLocation:@0.0 length:@(-4.0)]];
    [self checkRangeWithLocation:2.0 length:-2.0];

    [self.plotRange shiftEndToFitInRange:[CPTPlotRange plotRangeWithLocation:@(-1.0) length:@(-4.0)]];
    [self checkRangeWithLocation:1.0 length:-2.0];

    [self.plotRange shiftEndToFitInRange:[CPTPlotRange plotRangeWithLocation:@5.0 length:@(-4.0)]];
    [self checkRangeWithLocation:3.0 length:-2.0];
}

#pragma mark -
#pragma mark Expand Range

-(void)testExpandRangeHalf
{
    [self.plotRange expandRangeByFactor:@0.5];
    [self checkRangeWithLocation:1.5 length:1.0];
}

-(void)testExpandRangeSame
{
    [self.plotRange expandRangeByFactor:@1.0];
    [self checkRangeWithLocation:1.0 length:2.0];
}

-(void)testExpandRangeDouble
{
    [self.plotRange expandRangeByFactor:@2.0];
    [self checkRangeWithLocation:0.0 length:4.0];
}

-(void)testExpandRangeHalfNegative
{
    self.plotRange.lengthDouble = -2.0;

    [self.plotRange expandRangeByFactor:@0.5];
    [self checkRangeWithLocation:0.5 length:-1.0];
}

-(void)testExpandRangeSameNegative
{
    self.plotRange.lengthDouble = -2.0;

    [self.plotRange expandRangeByFactor:@1.0];
    [self checkRangeWithLocation:1.0 length:-2.0];
}

-(void)testExpandRangeDoubleNegative
{
    self.plotRange.lengthDouble = -2.0;

    [self.plotRange expandRangeByFactor:@2.0];
    [self checkRangeWithLocation:2.0 length:-4.0];
}

#pragma mark -
#pragma mark Comparing Ranges

-(void)testCompareToDecimal
{
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(0.999)], CPTPlotRangeComparisonResultNumberBelowRange, @"Test compareTo:0.999");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(1.0)], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:1.0");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(2.0)], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:2.0");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(3.0)], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:3.0");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(3.001)], CPTPlotRangeComparisonResultNumberAboveRange, @"Test compareTo:3.001");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalNaN()], CPTPlotRangeComparisonResultNumberUndefined, @"Test compareTo:NAN");
}

-(void)testCompareToDecimalInfinite
{
    self.plotRange.lengthDouble = HUGE_VAL;

    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(0.999)], CPTPlotRangeComparisonResultNumberBelowRange, @"Test compareTo:0.999");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(1.0)], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:1.0");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(2.0)], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:2.0");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(3.0)], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:3.0");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(3.001)], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:3.001");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalNaN()], CPTPlotRangeComparisonResultNumberUndefined, @"Test compareTo:NAN");
}

-(void)testCompareToDecimalNegative
{
    self.plotRange.lengthDouble = -2.0;

    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(-1.001)], CPTPlotRangeComparisonResultNumberBelowRange, @"Test compareTo:-1.001");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(-1.0)], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:-1.0");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(0.0)], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:0.0");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(1.0)], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:1.0");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(1.001)], CPTPlotRangeComparisonResultNumberAboveRange, @"Test compareTo:1.001");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalNaN()], CPTPlotRangeComparisonResultNumberUndefined, @"Test compareTo:NAN");
}

-(void)testCompareToDecimalNegativeInfinite
{
    self.plotRange.lengthDouble = -HUGE_VAL;

    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(-1.001)], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:-1.001");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(-1.0)], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:-1.0");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(0.0)], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:0.0");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(1.0)], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:1.0");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalFromDouble(1.001)], CPTPlotRangeComparisonResultNumberAboveRange, @"Test compareTo:1.001");
    XCTAssertEqual([self.plotRange compareToDecimal:CPTDecimalNaN()], CPTPlotRangeComparisonResultNumberUndefined, @"Test compareTo:NAN");
}

-(void)testCompareToDouble
{
    XCTAssertEqual([self.plotRange compareToDouble:0.999], CPTPlotRangeComparisonResultNumberBelowRange, @"Test compareTo:0.999");
    XCTAssertEqual([self.plotRange compareToDouble:1.0], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:1.0");
    XCTAssertEqual([self.plotRange compareToDouble:2.0], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:2.0");
    XCTAssertEqual([self.plotRange compareToDouble:3.0], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:3.0");
    XCTAssertEqual([self.plotRange compareToDouble:3.001], CPTPlotRangeComparisonResultNumberAboveRange, @"Test compareTo:3.001");
    XCTAssertEqual([self.plotRange compareToDouble:HUGE_VAL], CPTPlotRangeComparisonResultNumberAboveRange, @"Test compareTo:+INF");
    XCTAssertEqual([self.plotRange compareToDouble:-HUGE_VAL], CPTPlotRangeComparisonResultNumberBelowRange, @"Test compareTo:-INF");
    XCTAssertEqual([self.plotRange compareToDouble:(double)NAN], CPTPlotRangeComparisonResultNumberUndefined, @"Test compareTo:NAN");
}

-(void)testCompareToDoubleInfinite
{
    self.plotRange.lengthDouble = HUGE_VAL;

    XCTAssertEqual([self.plotRange compareToDouble:0.999], CPTPlotRangeComparisonResultNumberBelowRange, @"Test compareTo:0.999");
    XCTAssertEqual([self.plotRange compareToDouble:1.0], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:1.0");
    XCTAssertEqual([self.plotRange compareToDouble:2.0], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:2.0");
    XCTAssertEqual([self.plotRange compareToDouble:3.0], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:3.0");
    XCTAssertEqual([self.plotRange compareToDouble:3.001], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:3.001");
    XCTAssertEqual([self.plotRange compareToDouble:HUGE_VAL], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:+INF");
    XCTAssertEqual([self.plotRange compareToDouble:-HUGE_VAL], CPTPlotRangeComparisonResultNumberBelowRange, @"Test compareTo:-INF");
    XCTAssertEqual([self.plotRange compareToDouble:(double)NAN], CPTPlotRangeComparisonResultNumberUndefined, @"Test compareTo:NAN");
}

-(void)testCompareToDoubleNegative
{
    self.plotRange.lengthDouble = -2.0;

    XCTAssertEqual([self.plotRange compareToDouble:-1.001], CPTPlotRangeComparisonResultNumberBelowRange, @"Test compareTo:-1.001");
    XCTAssertEqual([self.plotRange compareToDouble:-1.0], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:-1.0");
    XCTAssertEqual([self.plotRange compareToDouble:0.0], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:0.0");
    XCTAssertEqual([self.plotRange compareToDouble:1.0], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:1.0");
    XCTAssertEqual([self.plotRange compareToDouble:1.001], CPTPlotRangeComparisonResultNumberAboveRange, @"Test compareTo:1.001");
    XCTAssertEqual([self.plotRange compareToDouble:HUGE_VAL], CPTPlotRangeComparisonResultNumberAboveRange, @"Test compareTo:+INF");
    XCTAssertEqual([self.plotRange compareToDouble:-HUGE_VAL], CPTPlotRangeComparisonResultNumberBelowRange, @"Test compareTo:-INF");
    XCTAssertEqual([self.plotRange compareToDouble:(double)NAN], CPTPlotRangeComparisonResultNumberUndefined, @"Test compareTo:NAN");
}

-(void)testCompareToDoubleNegativeInfinite
{
    self.plotRange.lengthDouble = -HUGE_VAL;

    XCTAssertEqual([self.plotRange compareToDouble:-1.001], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:-1.001");
    XCTAssertEqual([self.plotRange compareToDouble:-1.0], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:-1.0");
    XCTAssertEqual([self.plotRange compareToDouble:0.0], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:0.0");
    XCTAssertEqual([self.plotRange compareToDouble:1.0], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:1.0");
    XCTAssertEqual([self.plotRange compareToDouble:1.001], CPTPlotRangeComparisonResultNumberAboveRange, @"Test compareTo:1.001");
    XCTAssertEqual([self.plotRange compareToDouble:HUGE_VAL], CPTPlotRangeComparisonResultNumberAboveRange, @"Test compareTo:+INF");
    XCTAssertEqual([self.plotRange compareToDouble:-HUGE_VAL], CPTPlotRangeComparisonResultNumberInRange, @"Test compareTo:-INF");
    XCTAssertEqual([self.plotRange compareToDouble:(double)NAN], CPTPlotRangeComparisonResultNumberUndefined, @"Test compareTo:NAN");
}

#pragma mark -
#pragma mark NSCoding Methods

-(void)testKeyedArchivingRoundTrip
{
    CPTPlotRange *newRange = [self archiveRoundTrip:self.plotRange];

    XCTAssertTrue([self.plotRange isEqualToRange:newRange], @"Ranges equal");
}

#pragma mark -
#pragma mark Private Methods

-(void)checkRangeWithLocation:(double)loc length:(double)len
{
    NSString *errMessage;

    NSDecimal newLocation = self.plotRange.locationDecimal;

    errMessage = [NSString stringWithFormat:@"expected location = %g, was %@", loc, NSDecimalString(&newLocation, nil)];
    XCTAssertTrue(CPTDecimalEquals(newLocation, CPTDecimalFromDouble(loc)), @"%@", errMessage);

    NSDecimal newLength = self.plotRange.lengthDecimal;
    errMessage = [NSString stringWithFormat:@"expected location = %g, was %@", loc, NSDecimalString(&newLength, nil)];
    XCTAssertTrue(CPTDecimalEquals(newLength, CPTDecimalFromDouble(len)), @"%@", errMessage);
}

@end

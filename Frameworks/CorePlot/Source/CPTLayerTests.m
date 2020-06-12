#import "CPTLayerTests.h"

#import "CPTLayer.h"
#import "CPTUtilities.h"
#import "NSNumberExtensions.h"

static const CGFloat precision = CPTFloat(1.0e-6);

@interface CPTLayerTests()

-(void)testPositionsWithScale:(CGFloat)scale anchorPoint:(CGPoint)anchor expected:(CPTNumberArray *)expected;

@end

#pragma mark -

@implementation CPTLayerTests

@synthesize layer;
@synthesize positions;

#pragma mark -
#pragma mark Setup

-(void)setUp
{
    // starting layer positions for each test
    self.positions = @[@10.49999, @10.5, @10.50001, @10.99999, @11.0, @11.00001];

    CPTLayer *newLayer = [[CPTLayer alloc] initWithFrame:CPTRectMake(0.0, 0.0, 99.0, 99.0)];

    self.layer = newLayer;
}

-(void)tearDown
{
}

#pragma mark - Pixel alignment @1x

-(void)testPixelAlign1xLeft
{
    CPTNumberArray *expected = @[@10.0, @10.0, @11.0, @11.0, @11.0, @11.0];

    [self testPositionsWithScale:CPTFloat(1.0)
                     anchorPoint:CGPointZero
                        expected:expected];
}

-(void)testPixelAlign1xLeftMiddle
{
    CPTNumberArray *expected = @[@10.75, @10.75, @10.75, @10.75, @10.75, @10.75];

    [self testPositionsWithScale:CPTFloat(1.0)
                     anchorPoint:CPTPointMake(0.25, 0.25)
                        expected:expected];
}

-(void)testPixelAlign1xMiddle
{
    CPTNumberArray *expected = @[@10.5, @10.5, @10.5, @10.5, @10.5, @11.5];

    [self testPositionsWithScale:CPTFloat(1.0)
                     anchorPoint:CPTPointMake(0.5, 0.5)
                        expected:expected];
}

-(void)testPixelAlign1xRightMiddle
{
    CPTNumberArray *expected = @[@10.25, @10.25, @10.25, @11.25, @11.25, @11.25];

    [self testPositionsWithScale:CPTFloat(1.0)
                     anchorPoint:CPTPointMake(0.75, 0.75)
                        expected:expected];
}

-(void)testPixelAlign1xRight
{
    CPTNumberArray *expected = @[@10.0, @10.0, @11.0, @11.0, @11.0, @11.0];

    [self testPositionsWithScale:CPTFloat(1.0)
                     anchorPoint:CPTPointMake(1.0, 1.0)
                        expected:expected];
}

#pragma mark - Pixel alignment @2x

-(void)testPixelAlign2xLeft
{
    CPTNumberArray *expected = @[@10.5, @10.5, @10.5, @11.0, @11.0, @11.0];

    [self testPositionsWithScale:CPTFloat(2.0)
                     anchorPoint:CGPointZero
                        expected:expected];
}

-(void)testPixelAlign2xLeftMiddle
{
    CPTNumberArray *expected = @[@10.25, @10.25, @10.75, @10.75, @10.75, @11.25];

    [self testPositionsWithScale:CPTFloat(2.0)
                     anchorPoint:CPTPointMake(0.25, 0.25)
                        expected:expected];
}

-(void)testPixelAlign2xMiddle
{
    CPTNumberArray *expected = @[@10.5, @10.5, @10.5, @11.0, @11.0, @11.0];

    [self testPositionsWithScale:CPTFloat(2.0)
                     anchorPoint:CPTPointMake(0.5, 0.5)
                        expected:expected];
}

-(void)testPixelAlign2xRightMiddle
{
    CPTNumberArray *expected = @[@10.25, @10.25, @10.75, @10.75, @10.75, @11.25];

    [self testPositionsWithScale:CPTFloat(2.0)
                     anchorPoint:CPTPointMake(0.75, 0.75)
                        expected:expected];
}

-(void)testPixelAlign2xRight
{
    CPTNumberArray *expected = @[@10.5, @10.5, @10.5, @11.0, @11.0, @11.0];

    [self testPositionsWithScale:CPTFloat(2.0)
                     anchorPoint:CPTPointMake(1.0, 1.0)
                        expected:expected];
}

#pragma mark - Utility methods

-(void)testPositionsWithScale:(CGFloat)scale anchorPoint:(CGPoint)anchor expected:(CPTNumberArray *)expectedValues
{
    NSUInteger positionCount = self.positions.count;

    NSParameterAssert(expectedValues.count == positionCount);

    self.layer.contentsScale = scale;
    self.layer.anchorPoint   = anchor;

    for ( NSUInteger i = 0; i < positionCount; i++ ) {
        CGFloat position      = ((NSNumber *)((self.positions)[i])).cgFloatValue;
        CGPoint layerPosition = CGPointMake(position, position);
        self.layer.position = layerPosition;

        [self.layer pixelAlign];

        CGPoint alignedPoint = self.layer.position;
        CGFloat expected     = ((NSNumber *)(expectedValues[i])).cgFloatValue;

        NSString *errMessage;
        errMessage = [NSString stringWithFormat:@"pixelAlign at x = %g with scale %g and anchor %@", (double)position, (double)scale, CPTStringFromPoint(anchor)];
        XCTAssertEqualWithAccuracy(alignedPoint.x, expected, precision, @"%@", errMessage);

        errMessage = [NSString stringWithFormat:@"pixelAlign at y = %g with scale %g and anchor %@", (double)position, (double)scale, CPTStringFromPoint(anchor)];
        XCTAssertEqualWithAccuracy(alignedPoint.y, expected, precision, @"%@", errMessage);
    }
}

@end

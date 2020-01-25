#import "CPTLineStyleTests.h"

#import "CPTLineStyle.h"

@implementation CPTLineStyleTests

#pragma mark -
#pragma mark NSCoding Methods

-(void)testKeyedArchivingRoundTrip
{
    CPTLineStyle *lineStyle = [CPTLineStyle lineStyle];

    CPTLineStyle *newLineStyle = [self archiveRoundTrip:lineStyle];

    XCTAssertEqual(newLineStyle.lineCap, lineStyle.lineCap, @"Line cap not equal");
    XCTAssertEqual(newLineStyle.lineJoin, lineStyle.lineJoin, @"Line join not equal");
    XCTAssertEqual(newLineStyle.miterLimit, lineStyle.miterLimit, @"Miter limit not equal");
    XCTAssertEqual(newLineStyle.lineWidth, lineStyle.lineWidth, @"Line width not equal");
    XCTAssertEqualObjects(newLineStyle.dashPattern, lineStyle.dashPattern, @"Dash pattern not equal");
    XCTAssertEqual(newLineStyle.patternPhase, lineStyle.patternPhase, @"Pattern phase not equal");
    XCTAssertEqualObjects(newLineStyle.lineColor, lineStyle.lineColor, @"Line colors not equal");
}

@end

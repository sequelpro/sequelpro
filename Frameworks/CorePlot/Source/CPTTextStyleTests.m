#import "CPTTextStyleTests.h"

#import "CPTColor.h"
#import "CPTDefinitions.h"
#import "CPTTextStyle.h"

@implementation CPTTextStyleTests

-(void)testDefaults
{
    CPTTextStyle *textStyle = [CPTTextStyle textStyle];

    XCTAssertEqualObjects(@"Helvetica", textStyle.fontName, @"Default font name is not Helvetica");
    XCTAssertEqual(CPTFloat(12.0), textStyle.fontSize, @"Default font size is not 12.0");
    XCTAssertEqualObjects([CPTColor blackColor], textStyle.color, @"Default color is not [CPTColor blackColor]");
}

#pragma mark -
#pragma mark NSCoding Methods

-(void)testKeyedArchivingRoundTrip
{
    CPTTextStyle *textStyle = [CPTTextStyle textStyle];

    CPTTextStyle *newTextStyle = [self archiveRoundTrip:textStyle];

    XCTAssertEqualObjects(newTextStyle.fontName, textStyle.fontName, @"Font names not equal");
    XCTAssertEqual(newTextStyle.fontSize, textStyle.fontSize, @"Font sizes not equal");
    XCTAssertEqualObjects(newTextStyle.color, textStyle.color, @"Font colors not equal");
    XCTAssertEqual(newTextStyle.textAlignment, textStyle.textAlignment, @"Text alignments not equal");
}

@end

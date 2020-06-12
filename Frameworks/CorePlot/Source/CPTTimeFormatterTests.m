#import "CPTTimeFormatterTests.h"

#import "CPTTimeFormatter.h"

@implementation CPTTimeFormatterTests

#pragma mark -
#pragma mark NSCoding Methods

-(void)testKeyedArchivingRoundTrip
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];

    NSDate *refDate = [dateFormatter dateFromString:@"12:00 Oct 29, 2009"];

    dateFormatter.dateStyle = NSDateFormatterShortStyle;

    CPTTimeFormatter *timeFormatter = [[CPTTimeFormatter alloc] initWithDateFormatter:dateFormatter];
    timeFormatter.referenceDate = refDate;

    CPTTimeFormatter *newTimeFormatter = [self archiveRoundTrip:timeFormatter];

    XCTAssertEqualObjects(timeFormatter.dateFormatter.dateFormat, newTimeFormatter.dateFormatter.dateFormat, @"Date formatter not equal");
    XCTAssertEqualObjects(timeFormatter.referenceDate, newTimeFormatter.referenceDate, @"Reference date not equal");
}

@end

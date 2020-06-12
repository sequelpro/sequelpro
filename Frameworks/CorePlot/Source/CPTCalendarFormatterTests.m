#import "CPTCalendarFormatterTests.h"

#import "CPTCalendarFormatter.h"

@implementation CPTCalendarFormatterTests

#pragma mark -
#pragma mark NSCoding Methods

-(void)testKeyedArchivingRoundTrip
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];

    NSDate *refDate = [dateFormatter dateFromString:@"12:00 Oct 29, 2009"];

    dateFormatter.dateStyle = NSDateFormatterShortStyle;

    CPTCalendarFormatter *calendarFormatter = [[CPTCalendarFormatter alloc] initWithDateFormatter:dateFormatter];
    calendarFormatter.referenceDate = refDate;

    CPTCalendarFormatter *newCalendarFormatter = [self archiveRoundTrip:calendarFormatter];

    XCTAssertEqualObjects(calendarFormatter.dateFormatter.dateFormat, newCalendarFormatter.dateFormatter.dateFormat, @"Date formatter not equal");
    XCTAssertEqualObjects(calendarFormatter.referenceDate, newCalendarFormatter.referenceDate, @"Reference date not equal");
    XCTAssertEqualObjects(calendarFormatter.referenceCalendar, newCalendarFormatter.referenceCalendar, @"Reference calendar not equal");
    XCTAssertEqual(calendarFormatter.referenceCalendarUnit, newCalendarFormatter.referenceCalendarUnit, @"Reference calendar unit not equal");
}

@end

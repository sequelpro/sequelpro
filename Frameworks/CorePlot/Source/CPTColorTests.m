#import "CPTColorTests.h"

#import "CPTColor.h"

@implementation CPTColorTests

#pragma mark -
#pragma mark NSCoding Methods

-(void)testKeyedArchivingRoundTrip
{
    CPTColor *color = [CPTColor redColor];

    CPTColor *newColor = [self archiveRoundTrip:color];

    XCTAssertEqualObjects(color, newColor, @"Colors not equal");

#if TARGET_OS_OSX
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    // Workaround since @available macro is not there
    if ( [NSColor respondsToSelector:@selector(systemRedColor)] ) {
        color = [CPTColor colorWithNSColor:[NSColor systemRedColor]];

        newColor = [self archiveRoundTrip:color];

        XCTAssertEqualObjects(color, newColor, @"Colors not equal");
    }
#pragma clang diagnostic pop
#endif
}

@end

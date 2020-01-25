#import "CPTGradientTests.h"

#import "CPTGradient.h"

@implementation CPTGradientTests

#pragma mark -
#pragma mark NSCoding Methods

-(void)testKeyedArchivingRoundTrip
{
    CPTGradient *gradient = [CPTGradient rainbowGradient];

    CPTGradient *newGradient = [self archiveRoundTrip:gradient];

    XCTAssertEqualObjects(gradient, newGradient, @"Gradients not equal");
}

@end

#import <XCTest/XCTest.h>

@interface CPTTestCase : XCTestCase

-(nullable id)archiveRoundTrip:(nonnull id)object toClass:(nonnull Class)archiveClass;
-(nullable id)archiveRoundTrip:(nonnull id)object;

@end

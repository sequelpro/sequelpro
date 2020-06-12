#import "CPTImageTests.h"

#import "CPTImage.h"

@implementation CPTImageTests

#pragma mark -
#pragma mark NSCoding Methods

-(void)testKeyedArchivingRoundTrip
{
    const size_t width  = 100;
    const size_t height = 100;

    size_t bytesPerRow = (4 * width + 15) & ~15ul;

#if TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
#else
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
#endif
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, bytesPerRow, colorSpace, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    CGImageRef cgImage   = CGBitmapContextCreateImage(context);

    CPTImage *image = [CPTImage imageWithCGImage:cgImage];

    image.tiled                 = YES;
    image.tileAnchoredToContext = YES;

    CGColorSpaceRelease(colorSpace);
    CGImageRelease(cgImage);

    CPTImage *newImage = [self archiveRoundTrip:image];

    XCTAssertEqualObjects(image, newImage, @"Images not equal");
}

@end

#import "CPTPlatformSpecificFunctions.h"

#import "CPTExceptions.h"

#pragma mark -
#pragma mark Context management

void CPTPushCGContext(__nonnull CGContextRef newContext)
{
    UIGraphicsPushContext(newContext);
}

void CPTPopCGContext(void)
{
    UIGraphicsPopContext();
}

#pragma mark -
#pragma mark Debugging

CPTNativeImage *__nonnull CPTQuickLookImage(CGRect rect, __nonnull CPTQuickLookImageBlock renderBlock)
{
    UIGraphicsBeginImageContextWithOptions(rect.size, YES, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextTranslateCTM(context, 0, rect.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    CGContextSetRGBFillColor(context, CPTFloat(0xf6 / 255.0), CPTFloat(0xf5 / 255.0), CPTFloat(0xf6 / 255.0), 1.0);
    CGContextFillRect(context, rect);

    renderBlock(context, 1.0, rect);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

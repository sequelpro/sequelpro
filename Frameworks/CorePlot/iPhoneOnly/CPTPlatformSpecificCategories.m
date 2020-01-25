#import "CPTPlatformSpecificCategories.h"

#import "CPTPlatformSpecificFunctions.h"
#import "tgmath.h"

#pragma mark - CPTLayer

@implementation CPTLayer(CPTPlatformSpecificLayerExtensions)

/** @brief Gets an image of the layer contents.
 *  @return A native image representation of the layer content.
 **/
-(nullable CPTNativeImage *)imageOfLayer
{
    CGSize boundsSize = self.bounds.size;

    UIGraphicsBeginImageContextWithOptions(boundsSize, self.opaque, CPTFloat(0.0));

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextSetAllowsAntialiasing(context, true);

    CGContextTranslateCTM(context, CPTFloat(0.0), boundsSize.height);
    CGContextScaleCTM(context, CPTFloat(1.0), CPTFloat(-1.0));

    [self layoutAndRenderInContext:context];
    CPTNativeImage *layerImage = UIGraphicsGetImageFromCurrentImageContext();
    CGContextSetAllowsAntialiasing(context, false);

    CGContextRestoreGState(context);
    UIGraphicsEndImageContext();

    return layerImage;
}

@end

#pragma mark - NSNumber

@implementation NSNumber(CPTPlatformSpecificNumberExtensions)

/** @brief Returns a Boolean value that indicates whether the receiver is less than another given number.
 *  @param other The other number to compare to the receiver.
 *  @return @YES if the receiver is less than other, otherwise @NO.
 **/
-(BOOL)isLessThan:(nonnull NSNumber *)other
{
    return [self compare:other] == NSOrderedAscending;
}

/** @brief Returns a Boolean value that indicates whether the receiver is less than or equal to another given number.
 *  @param other The other number to compare to the receiver.
 *  @return @YES if the receiver is less than or equal to other, otherwise @NO.
 **/
-(BOOL)isLessThanOrEqualTo:(nonnull NSNumber *)other
{
    return [self compare:other] == NSOrderedSame || [self compare:other] == NSOrderedAscending;
}

/** @brief Returns a Boolean value that indicates whether the receiver is greater than another given number.
 *  @param other The other number to compare to the receiver.
 *  @return @YES if the receiver is greater than other, otherwise @NO.
 **/
-(BOOL)isGreaterThan:(nonnull NSNumber *)other
{
    return [self compare:other] == NSOrderedDescending;
}

/** @brief Returns a Boolean value that indicates whether the receiver is greater than or equal to another given number.
 *  @param other The other number to compare to the receiver.
 *  @return @YES if the receiver is greater than or equal to other, otherwise @NO.
 **/
-(BOOL)isGreaterThanOrEqualTo:(nonnull NSNumber *)other
{
    return [self compare:other] == NSOrderedSame || [self compare:other] == NSOrderedDescending;
}

@end

#pragma mark - NSAttributedString

@implementation NSAttributedString(CPTPlatformSpecificAttributedStringExtensions)

/** @brief Draws the styled text into the given graphics context.
 *  @param rect The bounding rectangle in which to draw the text.
 *  @param context The graphics context to draw into.
 *  @since Available on iOS 6.0 and later. Does nothing on earlier versions.
 **/
-(void)drawInRect:(CGRect)rect inContext:(nonnull CGContextRef)context
{
    if ( [self respondsToSelector:@selector(drawInRect:)] ) {
        CPTPushCGContext(context);

        [self drawWithRect:rect
                   options:CPTStringDrawingOptions
                   context:nil];

        CPTPopCGContext();
    }
}

/**
 *  @brief Computes the size of the styled text when drawn rounded up to the nearest whole number in each dimension.
 **/
-(CGSize)sizeAsDrawn
{
    CGRect rect = [self boundingRectWithSize:CPTSizeMake(10000.0, 10000.0)
                                     options:CPTStringDrawingOptions
                                     context:nil];

    CGSize textSize = rect.size;

    textSize.width  = ceil(textSize.width);
    textSize.height = ceil(textSize.height);

    return textSize;
}

@end

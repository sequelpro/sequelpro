#import "CPTFill.h"

#import "_CPTFillColor.h"
#import "_CPTFillGradient.h"
#import "_CPTFillImage.h"
#import "CPTColor.h"
#import "CPTGradient.h"
#import "CPTImage.h"
#import "CPTPlatformSpecificFunctions.h"

/** @brief Draws area fills.
 *
 *  CPTFill instances can be used to fill drawing areas with colors (including patterns),
 *  gradients, and images. Drawing methods are provided to fill rectangular areas and
 *  arbitrary drawing paths.
 **/

@implementation CPTFill

#pragma mark -
#pragma mark Init/Dealloc

/** @brief Creates and returns a new CPTFill instance initialized with a given color.
 *  @param aColor The color.
 *  @return A new CPTFill instance initialized with the given color.
 **/
+(nonnull instancetype)fillWithColor:(nonnull CPTColor *)aColor
{
    return [[_CPTFillColor alloc] initWithColor:aColor];
}

/** @brief Creates and returns a new CPTFill instance initialized with a given gradient.
 *  @param aGradient The gradient.
 *  @return A new CPTFill instance initialized with the given gradient.
 **/
+(nonnull instancetype)fillWithGradient:(nonnull CPTGradient *)aGradient
{
    return [[_CPTFillGradient alloc] initWithGradient:aGradient];
}

/** @brief Creates and returns a new CPTFill instance initialized with a given image.
 *  @param anImage The image.
 *  @return A new CPTFill instance initialized with the given image.
 **/
+(nonnull instancetype)fillWithImage:(nonnull CPTImage *)anImage
{
    return [[_CPTFillImage alloc] initWithImage:anImage];
}

/** @brief Initializes a newly allocated CPTFill object with the provided color.
 *  @param aColor The color.
 *  @return The initialized CPTFill object.
 **/
-(nonnull instancetype)initWithColor:(nonnull CPTColor *)aColor
{
    self = [[_CPTFillColor alloc] initWithColor:aColor];

    return self;
}

/** @brief Initializes a newly allocated CPTFill object with the provided gradient.
 *  @param aGradient The gradient.
 *  @return The initialized CPTFill object.
 **/
-(nonnull instancetype)initWithGradient:(nonnull CPTGradient *)aGradient
{
    self = [[_CPTFillGradient alloc] initWithGradient:aGradient];

    return self;
}

/** @brief Initializes a newly allocated CPTFill object with the provided image.
 *  @param anImage The image.
 *  @return The initialized CPTFill object.
 **/
-(nonnull instancetype)initWithImage:(nonnull CPTImage *)anImage
{
    self = [[_CPTFillImage alloc] initWithImage:anImage];

    return self;
}

#pragma mark -
#pragma mark NSCopying Methods

/// @cond

-(nonnull id)copyWithZone:(nullable NSZone *__unused)zone
{
    // do nothing--implemented in subclasses
    return nil;
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *__unused)coder
{
    // do nothing--implemented in subclasses
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    id fill = [coder decodeObjectOfClass:[CPTColor class]
                                  forKey:@"_CPTFillColor.fillColor"];

    if ( fill ) {
        return [self initWithColor:fill];
    }

    id gradient = [coder decodeObjectOfClass:[CPTGradient class]
                                      forKey:@"_CPTFillGradient.fillGradient"];
    if ( gradient ) {
        return [self initWithGradient:gradient];
    }

    id image = [coder decodeObjectOfClass:[CPTImage class]
                                   forKey:@"_CPTFillImage.fillImage"];
    if ( image ) {
        return [self initWithImage:image];
    }

    return nil;
}

/// @endcond

#pragma mark -
#pragma mark NSSecureCoding Methods

/// @cond

+(BOOL)supportsSecureCoding
{
    return YES;
}

/// @endcond

@end

#pragma mark -

@implementation CPTFill(AbstractMethods)

/** @property BOOL opaque
 *  @brief If @YES, the fill is completely opaque.
 */
@dynamic opaque;

/** @property nullable CGColorRef cgColor
 *  @brief Returns a @ref CGColorRef describing the fill if the fill can be represented as a color, @NULL otherwise.
 */
@dynamic cgColor;

#pragma mark -
#pragma mark Opacity

/// @cond

-(BOOL)isOpaque
{
    // do nothing--subclasses override to describe the fill opacity
    return NO;
}

/// @endcond

#pragma mark -
#pragma mark Color

-(nullable CGColorRef)cgColor
{
    // do nothing--subclasses override to describe the color
    return NULL;
}

#pragma mark -
#pragma mark Drawing

/** @brief Draws the gradient into the given graphics context inside the provided rectangle.
 *  @param rect The rectangle to draw into.
 *  @param context The graphics context to draw into.
 **/
-(void)fillRect:(CGRect __unused)rect inContext:(nonnull CGContextRef __unused)context
{
    // do nothing--subclasses override to do drawing here
}

/** @brief Draws the gradient into the given graphics context clipped to the current drawing path.
 *  @param context The graphics context to draw into.
 **/
-(void)fillPathInContext:(nonnull CGContextRef __unused)context
{
    // do nothing--subclasses override to do drawing here
}

#pragma mark -
#pragma mark Debugging

/// @cond

-(nullable id)debugQuickLookObject
{
    const CGRect rect = CGRectMake(0.0, 0.0, 100.0, 100.0);

    return CPTQuickLookImage(rect, ^(CGContextRef context, CGFloat __unused scale, CGRect bounds) {
        [self fillRect:bounds inContext:context];
    });
}

/// @endcond

@end

#import "_CPTFillColor.h"

#import "CPTColor.h"

/// @cond
@interface _CPTFillColor()

@property (nonatomic, readwrite, copy, nonnull) CPTColor *fillColor;

@end

/// @endcond

/** @brief Draws CPTColor area fills.
 *
 *  Drawing methods are provided to fill rectangular areas and arbitrary drawing paths.
 **/

@implementation _CPTFillColor

/** @property nonnull CPTColor *fillColor
 *  @brief The fill color.
 **/
@synthesize fillColor;

#pragma mark -
#pragma mark Init/Dealloc

/** @brief Initializes a newly allocated _CPTFillColor object with the provided color.
 *  @param aColor The color.
 *  @return The initialized _CPTFillColor object.
 **/
-(nonnull instancetype)initWithColor:(nonnull CPTColor *)aColor
{
    if ((self = [super init])) {
        fillColor = aColor;
    }
    return self;
}

#pragma mark -
#pragma mark Drawing

/** @brief Draws the color into the given graphics context inside the provided rectangle.
 *  @param rect The rectangle to draw into.
 *  @param context The graphics context to draw into.
 **/
-(void)fillRect:(CGRect)rect inContext:(nonnull CGContextRef)context
{
    CGContextSaveGState(context);
    CGContextSetFillColorWithColor(context, self.fillColor.cgColor);
    CGContextFillRect(context, rect);
    CGContextRestoreGState(context);
}

/** @brief Draws the color into the given graphics context clipped to the current drawing path.
 *  @param context The graphics context to draw into.
 **/
-(void)fillPathInContext:(nonnull CGContextRef)context
{
    CGContextSaveGState(context);
    CGContextSetFillColorWithColor(context, self.fillColor.cgColor);
    CGContextFillPath(context);
    CGContextRestoreGState(context);
}

#pragma mark -
#pragma mark Opacity

-(BOOL)isOpaque
{
    return self.fillColor.opaque;
}

#pragma mark -
#pragma mark Color

-(CGColorRef)cgColor
{
    return self.fillColor.cgColor;
}

#pragma mark -
#pragma mark NSCopying Methods

/// @cond

-(nonnull id)copyWithZone:(nullable NSZone *)zone
{
    _CPTFillColor *copy = [[[self class] allocWithZone:zone] init];

    copy.fillColor = self.fillColor;

    return copy;
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(nonnull Class)classForCoder
{
    return [CPTFill class];
}

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [coder encodeObject:self.fillColor forKey:@"_CPTFillColor.fillColor"];
}

/// @endcond

/** @brief Returns an object initialized from data in a given unarchiver.
 *  @param coder An unarchiver object.
 *  @return An object initialized from data in a given unarchiver.
 */
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super init])) {
        CPTColor *color = [coder decodeObjectOfClass:[CPTColor class]
                                              forKey:@"_CPTFillColor.fillColor"];

        if ( color ) {
            fillColor = color;
        }
        else {
            self = nil;
        }
    }
    return self;
}

#pragma mark -
#pragma mark NSSecureCoding Methods

/// @cond

+(BOOL)supportsSecureCoding
{
    return YES;
}

/// @endcond

@end

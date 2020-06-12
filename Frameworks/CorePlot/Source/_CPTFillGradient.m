#import "_CPTFillGradient.h"

#import "CPTGradient.h"

/// @cond
@interface _CPTFillGradient()

@property (nonatomic, readwrite, copy, nonnull) CPTGradient *fillGradient;

@end

/// @endcond

/** @brief Draws CPTGradient area fills.
 *
 *  Drawing methods are provided to fill rectangular areas and arbitrary drawing paths.
 **/

@implementation _CPTFillGradient

/** @property nonnull CPTGradient *fillGradient
 *  @brief The fill gradient.
 **/
@synthesize fillGradient;

#pragma mark -
#pragma mark Init/Dealloc

/** @brief Initializes a newly allocated _CPTFillGradient object with the provided gradient.
 *  @param aGradient The gradient.
 *  @return The initialized _CPTFillGradient object.
 **/
-(nonnull instancetype)initWithGradient:(nonnull CPTGradient *)aGradient
{
    if ((self = [super init])) {
        fillGradient = aGradient;
    }
    return self;
}

#pragma mark -
#pragma mark Drawing

/** @brief Draws the gradient into the given graphics context inside the provided rectangle.
 *  @param rect The rectangle to draw into.
 *  @param context The graphics context to draw into.
 **/
-(void)fillRect:(CGRect)rect inContext:(nonnull CGContextRef)context
{
    [self.fillGradient fillRect:rect inContext:context];
}

/** @brief Draws the gradient into the given graphics context clipped to the current drawing path.
 *  @param context The graphics context to draw into.
 **/
-(void)fillPathInContext:(nonnull CGContextRef)context
{
    [self.fillGradient fillPathInContext:context];
}

#pragma mark -
#pragma mark Opacity

-(BOOL)isOpaque
{
    return self.fillGradient.opaque;
}

#pragma mark -
#pragma mark NSCopying Methods

/// @cond

-(nonnull id)copyWithZone:(nullable NSZone *)zone
{
    _CPTFillGradient *copy = [[[self class] allocWithZone:zone] init];

    copy.fillGradient = self.fillGradient;

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
    [coder encodeObject:self.fillGradient forKey:@"_CPTFillGradient.fillGradient"];
}

/// @endcond

/** @brief Returns an object initialized from data in a given unarchiver.
 *  @param coder An unarchiver object.
 *  @return An object initialized from data in a given unarchiver.
 */
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super init])) {
        CPTGradient *gradient = [coder decodeObjectOfClass:[CPTGradient class]
                                                    forKey:@"_CPTFillGradient.fillGradient"];

        if ( gradient ) {
            fillGradient = gradient;
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

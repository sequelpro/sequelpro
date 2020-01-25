#import "_CPTConstraintsRelative.h"

#import "NSCoderExtensions.h"
#import <tgmath.h>

/// @cond
@interface _CPTConstraintsRelative()

@property (nonatomic, readwrite) CGFloat offset;

@end

/// @endcond

#pragma mark -

/** @brief Implements a one-dimensional constrained position within a given numeric range.
 *
 *  Supports fixed distance from either end of the range and a proportional fraction of the range.
 **/
@implementation _CPTConstraintsRelative

@synthesize offset;

#pragma mark -
#pragma mark Init/Dealloc

/** @brief Initializes a newly allocated CPTConstraints instance initialized with a proportional offset relative to the bounds.
 *
 *  For example, an offset of @num{0.0} will return a position equal to the lower bound, @num{1.0} will return the upper bound,
 *  and @num{0.5} will return a point midway between the two bounds.
 *
 *  @param newOffset The offset.
 *  @return The initialized CPTConstraints object.
 **/
-(nonnull instancetype)initWithRelativeOffset:(CGFloat)newOffset
{
    if ((self = [super init])) {
        offset = newOffset;
    }

    return self;
}

#pragma mark -
#pragma mark Comparison

-(BOOL)isEqualToConstraint:(nullable CPTConstraints *)otherConstraint
{
    if ( [self class] != [otherConstraint class] ) {
        return NO;
    }
    return self.offset == ((_CPTConstraintsRelative *)otherConstraint).offset;
}

#pragma mark -
#pragma mark Positioning

/** @brief Compute the position given a range of values.
 *  @param lowerBound The lower bound; must be less than or equal to the upperBound.
 *  @param upperBound The upper bound; must be greater than or equal to the lowerBound.
 *  @return The calculated position.
 **/
-(CGFloat)positionForLowerBound:(CGFloat)lowerBound upperBound:(CGFloat)upperBound
{
    NSAssert(lowerBound <= upperBound, @"lowerBound must be less than or equal to upperBound");

    CGFloat position = fma(upperBound - lowerBound, self.offset, lowerBound);

    return position;
}

#pragma mark -
#pragma mark NSCopying Methods

/// @cond

-(nonnull id)copyWithZone:(nullable NSZone *)zone
{
    _CPTConstraintsRelative *copy = [[[self class] allocWithZone:zone] init];

    copy.offset = self.offset;

    return copy;
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(nonnull Class)classForCoder
{
    return [CPTConstraints class];
}

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [coder encodeCGFloat:self.offset forKey:@"_CPTConstraintsRelative.offset"];
}

/// @endcond

/** @brief Returns an object initialized from data in a given unarchiver.
 *  @param coder An unarchiver object.
 *  @return An object initialized from data in a given unarchiver.
 */
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super init])) {
        offset = [coder decodeCGFloatForKey:@"_CPTConstraintsRelative.offset"];
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

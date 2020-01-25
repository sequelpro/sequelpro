#import "_CPTConstraintsFixed.h"

#import "NSCoderExtensions.h"

/// @cond
@interface _CPTConstraintsFixed()

@property (nonatomic, readwrite) CGFloat offset;
@property (nonatomic, readwrite) BOOL isFixedToLower;

@end

/// @endcond

#pragma mark -

/** @brief Implements a one-dimensional constrained position within a given numeric range.
 *
 *  Supports fixed distance from either end of the range and a proportional fraction of the range.
 **/
@implementation _CPTConstraintsFixed

@synthesize offset;
@synthesize isFixedToLower;

#pragma mark -
#pragma mark Init/Dealloc

/** @brief Initializes a newly allocated CPTConstraints instance initialized with a fixed offset from the lower bound.
 *  @param newOffset The offset.
 *  @return The initialized CPTConstraints object.
 **/
-(nonnull instancetype)initWithLowerOffset:(CGFloat)newOffset
{
    if ((self = [super init])) {
        offset         = newOffset;
        isFixedToLower = YES;
    }

    return self;
}

/** @brief Initializes a newly allocated CPTConstraints instance initialized with a fixed offset from the upper bound.
 *  @param newOffset The offset.
 *  @return The initialized CPTConstraints object.
 **/
-(nonnull instancetype)initWithUpperOffset:(CGFloat)newOffset
{
    if ((self = [super init])) {
        offset         = newOffset;
        isFixedToLower = NO;
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
    return (self.offset == ((_CPTConstraintsFixed *)otherConstraint).offset) &&
           (self.isFixedToLower == ((_CPTConstraintsFixed *)otherConstraint).isFixedToLower);
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

    CGFloat position;

    if ( self.isFixedToLower ) {
        position = lowerBound + self.offset;
    }
    else {
        position = upperBound - self.offset;
    }

    return position;
}

#pragma mark -
#pragma mark NSCopying Methods

/// @cond

-(nonnull id)copyWithZone:(nullable NSZone *)zone
{
    _CPTConstraintsFixed *copy = [[[self class] allocWithZone:zone] init];

    copy.offset         = self.offset;
    copy.isFixedToLower = self.isFixedToLower;

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
    [coder encodeCGFloat:self.offset forKey:@"_CPTConstraintsFixed.offset"];
    [coder encodeBool:self.isFixedToLower forKey:@"_CPTConstraintsFixed.isFixedToLower"];
}

/// @endcond

/** @brief Returns an object initialized from data in a given unarchiver.
 *  @param coder An unarchiver object.
 *  @return An object initialized from data in a given unarchiver.
 */
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super init])) {
        offset         = [coder decodeCGFloatForKey:@"_CPTConstraintsFixed.offset"];
        isFixedToLower = [coder decodeBoolForKey:@"_CPTConstraintsFixed.isFixedToLower"];
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

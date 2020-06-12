#import "CPTLimitBand.h"

#import "CPTFill.h"
#import "CPTPlotRange.h"

/**
 *  @brief Defines a range and fill used to highlight a band of data.
 **/
@implementation CPTLimitBand

/** @property nullable CPTPlotRange *range
 *  @brief The data range for the band.
 **/
@synthesize range;

/** @property nullable CPTFill *fill
 *  @brief The fill used to draw the band.
 **/
@synthesize fill;

#pragma mark -
#pragma mark Init/Dealloc

/** @brief Creates and returns a new CPTLimitBand instance initialized with the provided range and fill.
 *  @param newRange The range of the band.
 *  @param newFill The fill used to draw the interior of the band.
 *  @return A new CPTLimitBand instance initialized with the provided range and fill.
 **/
+(nonnull instancetype)limitBandWithRange:(nullable CPTPlotRange *)newRange fill:(nullable CPTFill *)newFill
{
    return [[self alloc] initWithRange:newRange fill:newFill];
}

/** @brief Initializes a newly allocated CPTLimitBand object with the provided range and fill.
 *  @param newRange The range of the band.
 *  @param newFill The fill used to draw the interior of the band.
 *  @return The initialized CPTLimitBand object.
 **/
-(nonnull instancetype)initWithRange:(nullable CPTPlotRange *)newRange fill:(nullable CPTFill *)newFill
{
    if ((self = [super init])) {
        range = newRange;
        fill  = newFill;
    }
    return self;
}

/// @cond

-(nonnull instancetype)init
{
    return [self initWithRange:nil fill:nil];
}

/// @endcond

#pragma mark -
#pragma mark NSCopying Methods

/// @cond

-(nonnull id)copyWithZone:(nullable NSZone *)zone
{
    CPTLimitBand *newBand = [[CPTLimitBand allocWithZone:zone] init];

    if ( newBand ) {
        newBand.range = self.range;
        newBand.fill  = self.fill;
    }
    return newBand;
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)encoder
{
    [encoder encodeObject:self.range forKey:@"CPTLimitBand.range"];
    [encoder encodeObject:self.fill forKey:@"CPTLimitBand.fill"];
}

/// @endcond

/** @brief Returns an object initialized from data in a given unarchiver.
 *  @param decoder An unarchiver object.
 *  @return An object initialized from data in a given unarchiver.
 */
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder
{
    if ((self = [super init])) {
        range = [decoder decodeObjectOfClass:[CPTPlotRange class]
                                      forKey:@"CPTLimitBand.range"];
        fill = [decoder decodeObjectOfClass:[CPTFill class]
                                     forKey:@"CPTLimitBand.fill"];
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

#pragma mark -
#pragma mark Description

/// @cond

-(nullable NSString *)description
{
    return [NSString stringWithFormat:@"<%@ with range: %@ and fill: %@>", super.description, self.range, self.fill];
}

/// @endcond

@end

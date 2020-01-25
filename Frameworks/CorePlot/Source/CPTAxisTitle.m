#import "CPTAxisTitle.h"

#import "CPTLayer.h"
#import "CPTUtilities.h"
#import <tgmath.h>

/** @brief An axis title.
 *
 *  The title can be text-based or can be the content of any CPTLayer provided by the user.
 **/
@implementation CPTAxisTitle

#pragma mark -
#pragma mark Init/Dealloc

/// @cond

-(nonnull instancetype)initWithContentLayer:(nonnull CPTLayer *)layer
{
    if ( layer ) {
        if ((self = [super initWithContentLayer:layer])) {
            self.rotation = CPTNAN;
        }
    }
    else {
        self = nil;
    }
    return self;
}

/// @endcond

#pragma mark -
#pragma mark Label comparison

/// @name Comparison
/// @{

/** @brief Returns a boolean value that indicates whether the received is equal to the given object.
 *  Axis titles are equal if they have the same @ref tickLocation, @ref rotation, and @ref contentLayer.
 *  @param object The object to be compared with the receiver.
 *  @return @YES if @par{object} is equal to the receiver, @NO otherwise.
 **/
-(BOOL)isEqual:(nullable id)object
{
    if ( self == object ) {
        return YES;
    }
    else if ( [object isKindOfClass:[self class]] ) {
        CPTAxisTitle *otherTitle = object;

        if ((self.rotation != otherTitle.rotation) || (self.offset != otherTitle.offset)) {
            return NO;
        }
        if ( ![self.contentLayer isEqual:otherTitle] ) {
            return NO;
        }

        NSNumber *location = ((CPTAxisLabel *)object).tickLocation;

        if ( location ) {
            return [self.tickLocation isEqualToNumber:location];
        }
        else {
            return NO;
        }
    }
    else {
        return NO;
    }
}

/// @}

/// @cond

-(NSUInteger)hash
{
    NSUInteger hashValue = 0;

    // Equal objects must hash the same.
    double tickLocationAsDouble = self.tickLocation.doubleValue;

    if ( !isnan(tickLocationAsDouble)) {
        hashValue = (NSUInteger)lrint(fmod(ABS(tickLocationAsDouble), (double)NSUIntegerMax));
    }
    hashValue += (NSUInteger)lrint(fmod(ABS(self.rotation), (double)NSUIntegerMax));
    hashValue += (NSUInteger)lrint(fmod(ABS(self.offset), (double)NSUIntegerMax));

    return hashValue;
}

/// @endcond

@end

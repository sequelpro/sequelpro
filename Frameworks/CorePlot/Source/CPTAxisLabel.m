#import "CPTAxisLabel.h"

#import "CPTLayer.h"
#import "CPTMutableTextStyle.h"
#import "CPTTextLayer.h"
#import "CPTUtilities.h"
#import "NSCoderExtensions.h"
#import <tgmath.h>

/** @brief An axis label.
 *
 *  The label can be text-based or can be the content of any CPTLayer provided by the user.
 **/
@implementation CPTAxisLabel

/** @property nullable CPTLayer *contentLayer
 *  @brief The label content.
 **/
@synthesize contentLayer;

/** @property CGFloat offset
 *  @brief The offset distance between the axis and label.
 **/
@synthesize offset;

/** @property CGFloat rotation
 *  @brief The rotation of the label in radians.
 **/
@synthesize rotation;

/** @property CPTAlignment alignment;
 *  @brief The alignment of the axis label with respect to the tick mark.
 **/
@synthesize alignment;

/** @property nonnull NSNumber *tickLocation
 *  @brief The data coordinate of the tick location.
 **/
@synthesize tickLocation;

#pragma mark -
#pragma mark Init/Dealloc

/** @brief Initializes a newly allocated text-based CPTAxisLabel object with the provided text and style.
 *
 *  @param newText The label text.
 *  @param newStyle The text style for the label.
 *  @return The initialized CPTAxisLabel object.
 **/
-(nonnull instancetype)initWithText:(nullable NSString *)newText textStyle:(nullable CPTTextStyle *)newStyle
{
    CPTTextLayer *newLayer = [[CPTTextLayer alloc] initWithText:newText style:newStyle];

    self = [self initWithContentLayer:newLayer];

    return self;
}

/** @brief Initializes a newly allocated CPTAxisLabel object with the provided layer. This is the designated initializer.
 *
 *  @param layer The label content.
 *  @return The initialized CPTAxisLabel object.
 **/
-(nonnull instancetype)initWithContentLayer:(nonnull CPTLayer *)layer
{
    if ((self = [super init])) {
        contentLayer = layer;
        offset       = CPTFloat(20.0);
        rotation     = CPTFloat(0.0);
        alignment    = CPTAlignmentCenter;
        tickLocation = @0.0;
    }

    return self;
}

/// @cond

-(nonnull instancetype)init
{
    return [self initWithText:nil textStyle:nil];
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [coder encodeObject:self.contentLayer forKey:@"CPTAxisLabel.contentLayer"];
    [coder encodeCGFloat:self.offset forKey:@"CPTAxisLabel.offset"];
    [coder encodeCGFloat:self.rotation forKey:@"CPTAxisLabel.rotation"];
    [coder encodeInteger:self.alignment forKey:@"CPTAxisLabel.alignment"];
    [coder encodeObject:self.tickLocation forKey:@"CPTAxisLabel.tickLocation"];
}

/// @endcond

/** @brief Returns an object initialized from data in a given unarchiver.
 *  @param coder An unarchiver object.
 *  @return An object initialized from data in a given unarchiver.
 */
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super init])) {
        contentLayer = [coder decodeObjectOfClass:[CPTLayer class]
                                           forKey:@"CPTAxisLabel.contentLayer"];
        offset    = [coder decodeCGFloatForKey:@"CPTAxisLabel.offset"];
        rotation  = [coder decodeCGFloatForKey:@"CPTAxisLabel.rotation"];
        alignment = (CPTAlignment)[coder decodeIntegerForKey:@"CPTAxisLabel.alignment"];
        NSNumber *location = [coder decodeObjectOfClass:[NSNumber class]
                                                 forKey:@"CPTAxisLabel.tickLocation"];
        tickLocation = location ? location : @0.0;
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
#pragma mark Layout

/** @brief Positions the axis label relative to the given point.
 *  The algorithm for positioning is different when the rotation property is non-zero.
 *  When zero, the anchor point is positioned along the closest side of the label.
 *  When non-zero, the anchor point is left at the center. This has consequences for
 *  the value taken by the offset.
 *  @param point The view point.
 *  @param coordinate The coordinate in which the label is being position. Orthogonal to the axis coordinate.
 *  @param direction The offset direction.
 **/
-(void)positionRelativeToViewPoint:(CGPoint)point forCoordinate:(CPTCoordinate)coordinate inDirection:(CPTSign)direction
{
    CPTLayer *content = self.contentLayer;

    if ( !content ) {
        return;
    }

    CGPoint newPosition = point;
    CGFloat *value      = (coordinate == CPTCoordinateX ? &(newPosition.x) : &(newPosition.y));
    CGFloat angle       = CPTFloat(0.0);

    CGFloat labelRotation = self.rotation;
    if ( isnan(labelRotation)) {
        labelRotation = (coordinate == CPTCoordinateX ? CPTFloat(M_PI_2) : CPTFloat(0.0));
    }
    content.transform = CATransform3DMakeRotation(labelRotation, CPTFloat(0.0), CPTFloat(0.0), CPTFloat(1.0));
    CGRect contentFrame = content.frame;

    // Position the anchor point along the closest edge.
    BOOL validDirection = NO;

    switch ( direction ) {
        case CPTSignNone:
        case CPTSignNegative:
            validDirection = YES;

            *value -= self.offset;

            switch ( coordinate ) {
                case CPTCoordinateX:
                    angle = CPTFloat(M_PI);

                    switch ( self.alignment ) {
                        case CPTAlignmentBottom:
                            newPosition.y += contentFrame.size.height / CPTFloat(2.0);
                            break;

                        case CPTAlignmentTop:
                            newPosition.y -= contentFrame.size.height / CPTFloat(2.0);
                            break;

                        default: // middle
                                 // no adjustment
                            break;
                    }
                    break;

                case CPTCoordinateY:
                    angle = CPTFloat(-M_PI_2);

                    switch ( self.alignment ) {
                        case CPTAlignmentLeft:
                            newPosition.x += contentFrame.size.width / CPTFloat(2.0);
                            break;

                        case CPTAlignmentRight:
                            newPosition.x -= contentFrame.size.width / CPTFloat(2.0);
                            break;

                        default: // center
                                 // no adjustment
                            break;
                    }
                    break;

                default:
                    [NSException raise:NSInvalidArgumentException format:@"Invalid coordinate in positionRelativeToViewPoint:forCoordinate:inDirection:"];
                    break;
            }
            break;

        case CPTSignPositive:
            validDirection = YES;

            *value += self.offset;

            switch ( coordinate ) {
                case CPTCoordinateX:
                    // angle = 0.0;

                    switch ( self.alignment ) {
                        case CPTAlignmentBottom:
                            newPosition.y += contentFrame.size.height / CPTFloat(2.0);
                            break;

                        case CPTAlignmentTop:
                            newPosition.y -= contentFrame.size.height / CPTFloat(2.0);
                            break;

                        default: // middle
                                 // no adjustment
                            break;
                    }
                    break;

                case CPTCoordinateY:
                    angle = CPTFloat(M_PI_2);

                    switch ( self.alignment ) {
                        case CPTAlignmentLeft:
                            newPosition.x += contentFrame.size.width / CPTFloat(2.0);
                            break;

                        case CPTAlignmentRight:
                            newPosition.x -= contentFrame.size.width / CPTFloat(2.0);
                            break;

                        default: // center
                                 // no adjustment
                            break;
                    }
                    break;

                default:
                    [NSException raise:NSInvalidArgumentException format:@"Invalid coordinate in positionRelativeToViewPoint:forCoordinate:inDirection:"];
                    break;
            }
            break;
    }

    if ( !validDirection ) {
        [NSException raise:NSInvalidArgumentException format:@"Invalid direction in positionRelativeToViewPoint:forCoordinate:inDirection:"];
    }

    angle += CPTFloat(M_PI);
    angle -= labelRotation;
    CGFloat newAnchorX = cos(angle);
    CGFloat newAnchorY = sin(angle);

    if ( ABS(newAnchorX) <= ABS(newAnchorY)) {
        newAnchorX /= ABS(newAnchorY);
        newAnchorY  = signbit(newAnchorY) ? CPTFloat(-1.0) : CPTFloat(1.0);
    }
    else {
        newAnchorY /= ABS(newAnchorX);
        newAnchorX  = signbit(newAnchorX) ? CPTFloat(-1.0) : CPTFloat(1.0);
    }
    CGPoint anchor = CPTPointMake((newAnchorX + CPTFloat(1.0)) / CPTFloat(2.0), (newAnchorY + CPTFloat(1.0)) / CPTFloat(2.0));

    content.anchorPoint = anchor;
    content.position    = newPosition;
    [content pixelAlign];
}

/** @brief Positions the axis label between two given points.
 *  @param firstPoint The first view point.
 *  @param secondPoint The second view point.
 *  @param coordinate The axis coordinate.
 *  @param direction The offset direction.
 **/
-(void)positionBetweenViewPoint:(CGPoint)firstPoint andViewPoint:(CGPoint)secondPoint forCoordinate:(CPTCoordinate)coordinate inDirection:(CPTSign)direction
{
    [self positionRelativeToViewPoint:CPTPointMake((firstPoint.x + secondPoint.x) / CPTFloat(2.0), (firstPoint.y + secondPoint.y) / CPTFloat(2.0))
                        forCoordinate:coordinate
                          inDirection:direction];
}

#pragma mark -
#pragma mark Description

/// @cond

-(nullable NSString *)description
{
    return [NSString stringWithFormat:@"<%@ {%@}>", super.description, self.contentLayer];
}

/// @endcond

#pragma mark -
#pragma mark Label comparison

/// @name Comparison
/// @{

/** @brief Returns a boolean value that indicates whether the received is equal to the given object.
 *  Axis labels are equal if they have the same @ref tickLocation.
 *  @param object The object to be compared with the receiver.
 *  @return @YES if @par{object} is equal to the receiver, @NO otherwise.
 **/
-(BOOL)isEqual:(nullable id)object
{
    if ( self == object ) {
        return YES;
    }
    else if ( [object isKindOfClass:[self class]] ) {
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

    return hashValue;
}

/// @endcond

@end

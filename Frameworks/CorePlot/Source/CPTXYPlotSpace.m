#import "CPTXYPlotSpace.h"

#import "CPTAnimation.h"
#import "CPTAnimationOperation.h"
#import "CPTAnimationPeriod.h"
#import "CPTAxisSet.h"
#import "CPTDebugQuickLook.h"
#import "CPTExceptions.h"
#import "CPTGraph.h"
#import "CPTGraphHostingView.h"
#import "CPTMutablePlotRange.h"
#import "CPTPlot.h"
#import "CPTPlotArea.h"
#import "CPTPlotAreaFrame.h"
#import "CPTUtilities.h"
#import "NSCoderExtensions.h"
#import <tgmath.h>

/// @cond
typedef NSMutableArray<CPTAnimationOperation *> CPTMutableAnimationArray;

@interface CPTXYPlotSpace()

-(CGFloat)viewCoordinateForViewLength:(NSDecimal)viewLength linearPlotRange:(nonnull CPTPlotRange *)range plotCoordinateValue:(NSDecimal)plotCoord;
-(CGFloat)viewCoordinateForViewLength:(CGFloat)viewLength linearPlotRange:(nonnull CPTPlotRange *)range doublePrecisionPlotCoordinateValue:(double)plotCoord;

-(CGFloat)viewCoordinateForViewLength:(CGFloat)viewLength logPlotRange:(nonnull CPTPlotRange *)range doublePrecisionPlotCoordinateValue:(double)plotCoord;

-(CGFloat)viewCoordinateForViewLength:(CGFloat)viewLength logModulusPlotRange:(nonnull CPTPlotRange *)range doublePrecisionPlotCoordinateValue:(double)plotCoord;

-(NSDecimal)plotCoordinateForViewLength:(NSDecimal)viewLength linearPlotRange:(nonnull CPTPlotRange *)range boundsLength:(NSDecimal)boundsLength;
-(double)doublePrecisionPlotCoordinateForViewLength:(CGFloat)viewLength linearPlotRange:(nonnull CPTPlotRange *)range boundsLength:(CGFloat)boundsLength;

-(double)doublePrecisionPlotCoordinateForViewLength:(CGFloat)viewLength logPlotRange:(nonnull CPTPlotRange *)range boundsLength:(CGFloat)boundsLength;

-(double)doublePrecisionPlotCoordinateForViewLength:(CGFloat)viewLength logModulusPlotRange:(nonnull CPTPlotRange *)range boundsLength:(CGFloat)boundsLength;

-(nonnull CPTPlotRange *)constrainRange:(nonnull CPTPlotRange *)existingRange toGlobalRange:(nullable CPTPlotRange *)globalRange;
-(void)animateRangeForCoordinate:(CPTCoordinate)coordinate shift:(NSDecimal)shift momentumTime:(CGFloat)momentumTime speed:(CGFloat)speed acceleration:(CGFloat)acceleration;
-(nullable CPTPlotRange *)shiftRange:(nonnull CPTPlotRange *)oldRange by:(NSDecimal)shift usingMomentum:(BOOL)momentum inGlobalRange:(nullable CPTPlotRange *)globalRange withDisplacement:(CGFloat *)displacement;

-(CGFloat)viewCoordinateForRange:(nullable CPTPlotRange *)range coordinate:(CPTCoordinate)coordinate direction:(BOOL)direction;

CGFloat CPTFirstPositiveRoot(CGFloat a, CGFloat b, CGFloat c);

@property (nonatomic, readwrite) BOOL isDragging;
@property (nonatomic, readwrite) CGPoint lastDragPoint;
@property (nonatomic, readwrite) CGPoint lastDisplacement;
@property (nonatomic, readwrite) NSTimeInterval lastDragTime;
@property (nonatomic, readwrite) NSTimeInterval lastDeltaTime;
@property (nonatomic, readwrite, retain, nonnull) CPTMutableAnimationArray *animations;

@end

/// @endcond

#pragma mark -

/**
 *  @brief A plot space using a two-dimensional cartesian coordinate system.
 *
 *  The @ref xRange and @ref yRange determine the mapping between data coordinates
 *  and the screen coordinates in the plot area. The @quote{end} of a range is
 *  the location plus its length. Note that the length of a plot range can be negative, so
 *  the end point can have a lesser value than the starting location.
 *
 *  The global ranges constrain the values of the @ref xRange and @ref yRange.
 *  Whenever the global range is set (non-@nil), the corresponding plot
 *  range will be adjusted so that it fits in the global range. When a new
 *  range is set to the plot range, it will be adjusted as needed to fit
 *  in the global range. This is useful for constraining scrolling, for
 *  instance.
 **/
@implementation CPTXYPlotSpace

/** @property nonnull CPTPlotRange *xRange
 *  @brief The range of the x coordinate. Defaults to a range with @link CPTPlotRange::location location @endlink zero (@num{0})
 *  and a @link CPTPlotRange::length length @endlink of one (@num{1}).
 *
 *  The @link CPTPlotRange::location location @endlink of the @ref xRange
 *  defines the data coordinate associated with the left edge of the plot area.
 *  Similarly, the @link CPTPlotRange::end end @endlink of the @ref xRange
 *  defines the data coordinate associated with the right edge of the plot area.
 **/
@synthesize xRange;

/** @property nonnull CPTPlotRange *yRange
 *  @brief The range of the y coordinate. Defaults to a range with @link CPTPlotRange::location location @endlink zero (@num{0})
 *  and a @link CPTPlotRange::length length @endlink of one (@num{1}).
 *
 *  The @link CPTPlotRange::location location @endlink of the @ref yRange
 *  defines the data coordinate associated with the bottom edge of the plot area.
 *  Similarly, the @link CPTPlotRange::end end @endlink of the @ref yRange
 *  defines the data coordinate associated with the top edge of the plot area.
 **/
@synthesize yRange;

/** @property nullable CPTPlotRange *globalXRange
 *  @brief The global range of the x coordinate to which the @ref xRange is constrained.
 *
 *  If non-@nil, the @ref xRange and any changes to it will
 *  be adjusted so that it always fits within the @ref globalXRange.
 *  If @nil (the default), there is no constraint on x.
 **/
@synthesize globalXRange;

/** @property nullable CPTPlotRange *globalYRange
 *  @brief The global range of the y coordinate to which the @ref yRange is constrained.
 *
 *  If non-@nil, the @ref yRange and any changes to it will
 *  be adjusted so that it always fits within the @ref globalYRange.
 *  If @nil (the default), there is no constraint on y.
 **/
@synthesize globalYRange;

/** @property CPTScaleType xScaleType
 *  @brief The scale type of the x coordinate. Defaults to #CPTScaleTypeLinear.
 **/
@synthesize xScaleType;

/** @property CPTScaleType yScaleType
 *  @brief The scale type of the y coordinate. Defaults to #CPTScaleTypeLinear.
 **/
@synthesize yScaleType;

/** @property BOOL allowsMomentum
 *  @brief If @YES, plot space scrolling in any direction slows down gradually rather than stopping abruptly. Defaults to @NO.
 **/
@dynamic allowsMomentum;

/** @property BOOL allowsMomentumX
 *  @brief If @YES, plot space scrolling in the x-direction slows down gradually rather than stopping abruptly. Defaults to @NO.
 **/
@synthesize allowsMomentumX;

/** @property BOOL allowsMomentumY
 *  @brief If @YES, plot space scrolling in the y-direction slows down gradually rather than stopping abruptly. Defaults to @NO.
 **/
@synthesize allowsMomentumY;

/** @property CPTAnimationCurve momentumAnimationCurve
 *  @brief The animation curve used to stop the motion of the plot ranges when scrolling with momentum. Defaults to #CPTAnimationCurveQuadraticOut.
 **/
@synthesize momentumAnimationCurve;

/** @property CPTAnimationCurve bounceAnimationCurve
 *  @brief The animation curve used to return the plot range back to the global range after scrolling. Defaults to #CPTAnimationCurveQuadraticOut.
 **/
@synthesize bounceAnimationCurve;

/** @property CGFloat momentumAcceleration
 *  @brief Deceleration in pixels/second^2 for momentum scrolling. Defaults to @num{2000.0}.
 **/
@synthesize momentumAcceleration;

/** @property CGFloat bounceAcceleration
 *  @brief Bounce-back acceleration in pixels/second^2 when scrolled past the global range. Defaults to @num{3000.0}.
 **/
@synthesize bounceAcceleration;

/** @property CGFloat minimumDisplacementToDrag
 *  @brief The minimum distance the interaction point must move before the event is considered a drag. Defaults to @num{2.0}.
 **/
@synthesize minimumDisplacementToDrag;

@dynamic isDragging;
@synthesize lastDragPoint;
@synthesize lastDisplacement;
@synthesize lastDragTime;
@synthesize lastDeltaTime;
@synthesize animations;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTXYPlotSpace object.
 *
 *  The initialized object will have the following properties:
 *  - @ref xRange = [@num{0}, @num{1}]
 *  - @ref yRange = [@num{0}, @num{1}]
 *  - @ref globalXRange = @nil
 *  - @ref globalYRange = @nil
 *  - @ref xScaleType = #CPTScaleTypeLinear
 *  - @ref yScaleType = #CPTScaleTypeLinear
 *  - @ref allowsMomentum = @NO
 *  - @ref allowsMomentumX = @NO
 *  - @ref allowsMomentumY = @NO
 *  - @ref momentumAnimationCurve = #CPTAnimationCurveQuadraticOut
 *  - @ref bounceAnimationCurve = #CPTAnimationCurveQuadraticOut
 *  - @ref momentumAcceleration = @num{2000.0}
 *  - @ref bounceAcceleration = @num{3000.0}
 *  - @ref minimumDisplacementToDrag = @num{2.0}
 *
 *  @return The initialized object.
 **/
-(nonnull instancetype)init
{
    if ((self = [super init])) {
        xRange           = [[CPTPlotRange alloc] initWithLocation:@0.0 length:@1.0];
        yRange           = [[CPTPlotRange alloc] initWithLocation:@0.0 length:@1.0];
        globalXRange     = nil;
        globalYRange     = nil;
        xScaleType       = CPTScaleTypeLinear;
        yScaleType       = CPTScaleTypeLinear;
        lastDragPoint    = CGPointZero;
        lastDisplacement = CGPointZero;
        lastDragTime     = 0.0;
        lastDeltaTime    = 0.0;
        animations       = [[NSMutableArray alloc] init];

        allowsMomentumX           = NO;
        allowsMomentumY           = NO;
        momentumAnimationCurve    = CPTAnimationCurveQuadraticOut;
        bounceAnimationCurve      = CPTAnimationCurveQuadraticOut;
        momentumAcceleration      = 2000.0;
        bounceAcceleration        = 3000.0;
        minimumDisplacementToDrag = 2.0;
    }
    return self;
}

/// @}

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeObject:self.xRange forKey:@"CPTXYPlotSpace.xRange"];
    [coder encodeObject:self.yRange forKey:@"CPTXYPlotSpace.yRange"];
    [coder encodeObject:self.globalXRange forKey:@"CPTXYPlotSpace.globalXRange"];
    [coder encodeObject:self.globalYRange forKey:@"CPTXYPlotSpace.globalYRange"];
    [coder encodeInteger:self.xScaleType forKey:@"CPTXYPlotSpace.xScaleType"];
    [coder encodeInteger:self.yScaleType forKey:@"CPTXYPlotSpace.yScaleType"];
    [coder encodeBool:self.allowsMomentumX forKey:@"CPTXYPlotSpace.allowsMomentumX"];
    [coder encodeBool:self.allowsMomentumY forKey:@"CPTXYPlotSpace.allowsMomentumY"];
    [coder encodeInteger:self.momentumAnimationCurve forKey:@"CPTXYPlotSpace.momentumAnimationCurve"];
    [coder encodeInteger:self.bounceAnimationCurve forKey:@"CPTXYPlotSpace.bounceAnimationCurve"];
    [coder encodeCGFloat:self.momentumAcceleration forKey:@"CPTXYPlotSpace.momentumAcceleration"];
    [coder encodeCGFloat:self.bounceAcceleration forKey:@"CPTXYPlotSpace.bounceAcceleration"];
    [coder encodeCGFloat:self.minimumDisplacementToDrag forKey:@"CPTXYPlotSpace.minimumDisplacementToDrag"];

    // No need to archive these properties:
    // lastDragPoint
    // lastDisplacement
    // lastDragTime
    // lastDeltaTime
    // animations
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        CPTPlotRange *range = [coder decodeObjectOfClass:[CPTPlotRange class]
                                                  forKey:@"CPTXYPlotSpace.xRange"];
        if ( range ) {
            xRange = [range copy];
        }
        range = [coder decodeObjectOfClass:[CPTPlotRange class]
                                    forKey:@"CPTXYPlotSpace.yRange"];
        if ( range ) {
            yRange = [range copy];
        }
        globalXRange = [[coder decodeObjectOfClass:[CPTPlotRange class]
                                            forKey:@"CPTXYPlotSpace.globalXRange"] copy];
        globalYRange = [[coder decodeObjectOfClass:[CPTPlotRange class]
                                            forKey:@"CPTXYPlotSpace.globalYRange"] copy];
        xScaleType = (CPTScaleType)[coder decodeIntegerForKey:@"CPTXYPlotSpace.xScaleType"];
        yScaleType = (CPTScaleType)[coder decodeIntegerForKey:@"CPTXYPlotSpace.yScaleType"];

        if ( [coder containsValueForKey:@"CPTXYPlotSpace.allowsMomentum"] ) {
            self.allowsMomentum = [coder decodeBoolForKey:@"CPTXYPlotSpace.allowsMomentum"];
        }
        else {
            allowsMomentumX = [coder decodeBoolForKey:@"CPTXYPlotSpace.allowsMomentumX"];
            allowsMomentumY = [coder decodeBoolForKey:@"CPTXYPlotSpace.allowsMomentumY"];
        }
        momentumAnimationCurve    = (CPTAnimationCurve)[coder decodeIntegerForKey:@"CPTXYPlotSpace.momentumAnimationCurve"];
        bounceAnimationCurve      = (CPTAnimationCurve)[coder decodeIntegerForKey:@"CPTXYPlotSpace.bounceAnimationCurve"];
        momentumAcceleration      = [coder decodeCGFloatForKey:@"CPTXYPlotSpace.momentumAcceleration"];
        bounceAcceleration        = [coder decodeCGFloatForKey:@"CPTXYPlotSpace.bounceAcceleration"];
        minimumDisplacementToDrag = [coder decodeCGFloatForKey:@"CPTXYPlotSpace.minimumDisplacementToDrag"];

        lastDragPoint    = CGPointZero;
        lastDisplacement = CGPointZero;
        lastDragTime     = 0.0;
        lastDeltaTime    = 0.0;
        animations       = [[NSMutableArray alloc] init];
    }
    return self;
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

#pragma mark -
#pragma mark Ranges

/// @cond

-(void)setPlotRange:(nonnull CPTPlotRange *)newRange forCoordinate:(CPTCoordinate)coordinate
{
    switch ( coordinate ) {
        case CPTCoordinateX:
            self.xRange = newRange;
            break;

        case CPTCoordinateY:
            self.yRange = newRange;
            break;

        default:
            // invalid coordinate--do nothing
            break;
    }
}

-(nullable CPTPlotRange *)plotRangeForCoordinate:(CPTCoordinate)coordinate
{
    CPTPlotRange *theRange = nil;

    switch ( coordinate ) {
        case CPTCoordinateX:
            theRange = self.xRange;
            break;

        case CPTCoordinateY:
            theRange = self.yRange;
            break;

        default:
            // invalid coordinate
            break;
    }

    return theRange;
}

-(void)setScaleType:(CPTScaleType)newType forCoordinate:(CPTCoordinate)coordinate
{
    switch ( coordinate ) {
        case CPTCoordinateX:
            self.xScaleType = newType;
            break;

        case CPTCoordinateY:
            self.yScaleType = newType;
            break;

        default:
            // invalid coordinate--do nothing
            break;
    }
}

-(CPTScaleType)scaleTypeForCoordinate:(CPTCoordinate)coordinate
{
    CPTScaleType theScaleType = CPTScaleTypeLinear;

    switch ( coordinate ) {
        case CPTCoordinateX:
            theScaleType = self.xScaleType;
            break;

        case CPTCoordinateY:
            theScaleType = self.yScaleType;
            break;

        default:
            // invalid coordinate
            break;
    }

    return theScaleType;
}

-(void)setXRange:(nonnull CPTPlotRange *)range
{
    NSParameterAssert(range);

    if ( ![range isEqualToRange:xRange] ) {
        CPTPlotRange *constrainedRange;

        if ( self.allowsMomentumX ) {
            constrainedRange = range;
        }
        else {
            constrainedRange = [self constrainRange:range toGlobalRange:self.globalXRange];
        }

        id<CPTPlotSpaceDelegate> theDelegate = self.delegate;
        if ( [theDelegate respondsToSelector:@selector(plotSpace:willChangePlotRangeTo:forCoordinate:)] ) {
            constrainedRange = [theDelegate plotSpace:self willChangePlotRangeTo:constrainedRange forCoordinate:CPTCoordinateX];
        }

        if ( ![constrainedRange isEqualToRange:xRange] ) {
            CGFloat displacement = self.lastDisplacement.x;
            BOOL isScrolling     = NO;

            if ( xRange && constrainedRange ) {
                isScrolling = !CPTDecimalEquals(constrainedRange.locationDecimal, xRange.locationDecimal) && CPTDecimalEquals(constrainedRange.lengthDecimal, xRange.lengthDecimal);

                if ( isScrolling && (displacement == CPTFloat(0.0))) {
                    CPTGraph *theGraph    = self.graph;
                    CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;

                    if ( plotArea ) {
                        NSDecimal rangeLength = constrainedRange.lengthDecimal;

                        if ( !CPTDecimalEquals(rangeLength, CPTDecimalFromInteger(0))) {
                            NSDecimal diff = CPTDecimalDivide(CPTDecimalSubtract(constrainedRange.locationDecimal, xRange.locationDecimal), rangeLength);

                            displacement = plotArea.bounds.size.width * CPTDecimalCGFloatValue(diff);
                        }
                    }
                }
            }

            xRange = [constrainedRange copy];

            [[NSNotificationCenter defaultCenter] postNotificationName:CPTPlotSpaceCoordinateMappingDidChangeNotification
                                                                object:self
                                                              userInfo:@{ CPTPlotSpaceCoordinateKey: @(CPTCoordinateX),
                                                                          CPTPlotSpaceScrollingKey: @(isScrolling),
                                                                          CPTPlotSpaceDisplacementKey: @(displacement) }
            ];

            if ( [theDelegate respondsToSelector:@selector(plotSpace:didChangePlotRangeForCoordinate:)] ) {
                [theDelegate plotSpace:self didChangePlotRangeForCoordinate:CPTCoordinateX];
            }

            CPTGraph *theGraph = self.graph;
            if ( theGraph ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:CPTGraphNeedsRedrawNotification
                                                                    object:theGraph];
            }
        }
    }
}

-(void)setYRange:(nonnull CPTPlotRange *)range
{
    NSParameterAssert(range);

    if ( ![range isEqualToRange:yRange] ) {
        CPTPlotRange *constrainedRange;

        if ( self.allowsMomentumY ) {
            constrainedRange = range;
        }
        else {
            constrainedRange = [self constrainRange:range toGlobalRange:self.globalYRange];
        }

        id<CPTPlotSpaceDelegate> theDelegate = self.delegate;
        if ( [theDelegate respondsToSelector:@selector(plotSpace:willChangePlotRangeTo:forCoordinate:)] ) {
            constrainedRange = [theDelegate plotSpace:self willChangePlotRangeTo:constrainedRange forCoordinate:CPTCoordinateY];
        }

        if ( ![constrainedRange isEqualToRange:yRange] ) {
            CGFloat displacement = self.lastDisplacement.y;
            BOOL isScrolling     = NO;

            if ( yRange && constrainedRange ) {
                isScrolling = !CPTDecimalEquals(constrainedRange.locationDecimal, yRange.locationDecimal) && CPTDecimalEquals(constrainedRange.lengthDecimal, yRange.lengthDecimal);

                if ( isScrolling && (displacement == CPTFloat(0.0))) {
                    CPTGraph *theGraph    = self.graph;
                    CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;

                    if ( plotArea ) {
                        NSDecimal rangeLength = constrainedRange.lengthDecimal;

                        if ( !CPTDecimalEquals(rangeLength, CPTDecimalFromInteger(0))) {
                            NSDecimal diff = CPTDecimalDivide(CPTDecimalSubtract(constrainedRange.locationDecimal, yRange.locationDecimal), rangeLength);

                            displacement = plotArea.bounds.size.height * CPTDecimalCGFloatValue(diff);
                        }
                    }
                }
            }

            yRange = [constrainedRange copy];

            [[NSNotificationCenter defaultCenter] postNotificationName:CPTPlotSpaceCoordinateMappingDidChangeNotification
                                                                object:self
                                                              userInfo:@{ CPTPlotSpaceCoordinateKey: @(CPTCoordinateY),
                                                                          CPTPlotSpaceScrollingKey: @(isScrolling),
                                                                          CPTPlotSpaceDisplacementKey: @(displacement) }
            ];

            if ( [theDelegate respondsToSelector:@selector(plotSpace:didChangePlotRangeForCoordinate:)] ) {
                [theDelegate plotSpace:self didChangePlotRangeForCoordinate:CPTCoordinateY];
            }

            CPTGraph *theGraph = self.graph;
            if ( theGraph ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:CPTGraphNeedsRedrawNotification
                                                                    object:theGraph];
            }
        }
    }
}

-(nonnull CPTPlotRange *)constrainRange:(nonnull CPTPlotRange *)existingRange toGlobalRange:(nullable CPTPlotRange *)globalRange
{
    if ( !globalRange ) {
        return existingRange;
    }
    if ( !existingRange ) {
        return nil;
    }

    CPTPlotRange *theGlobalRange = globalRange;

    if ( CPTDecimalGreaterThanOrEqualTo(existingRange.lengthDecimal, theGlobalRange.lengthDecimal)) {
        return [theGlobalRange copy];
    }
    else {
        CPTMutablePlotRange *newRange = [existingRange mutableCopy];
        [newRange shiftEndToFitInRange:theGlobalRange];
        [newRange shiftLocationToFitInRange:theGlobalRange];
        return newRange;
    }
}

-(void)animateRangeForCoordinate:(CPTCoordinate)coordinate shift:(NSDecimal)shift momentumTime:(CGFloat)momentumTime speed:(CGFloat)speed acceleration:(CGFloat)acceleration
{
    CPTMutableAnimationArray *animationArray = self.animations;
    CPTAnimationOperation *op;

    NSString *property        = nil;
    CPTPlotRange *oldRange    = nil;
    CPTPlotRange *globalRange = nil;

    switch ( coordinate ) {
        case CPTCoordinateX:
            property    = @"xRange";
            oldRange    = self.xRange;
            globalRange = self.globalXRange;
            break;

        case CPTCoordinateY:
            property    = @"yRange";
            oldRange    = self.yRange;
            globalRange = self.globalYRange;
            break;

        default:
            property = @"";
            oldRange = [CPTPlotRange plotRangeWithLocation:@0.0 length:@0];
            break;
    }

    CPTMutablePlotRange *newRange = [oldRange mutableCopy];

    CGFloat bounceDelay = CPTFloat(0.0);
    NSDecimal zero      = CPTDecimalFromInteger(0);
    BOOL hasShift       = !CPTDecimalEquals(shift, zero);

    if ( hasShift ) {
        newRange.locationDecimal = CPTDecimalAdd(newRange.locationDecimal, shift);

        op = [CPTAnimation animate:self
                          property:property
                     fromPlotRange:oldRange
                       toPlotRange:newRange
                          duration:momentumTime
                    animationCurve:self.momentumAnimationCurve
                          delegate:self];
        [animationArray addObject:op];

        bounceDelay = momentumTime;
    }

    if ( globalRange ) {
        CPTPlotRange *constrainedRange = [self constrainRange:newRange toGlobalRange:globalRange];

        if ( ![newRange isEqualToRange:constrainedRange] && ![globalRange containsRange:newRange] ) {
            BOOL direction = (CPTDecimalGreaterThan(shift, zero) && CPTDecimalGreaterThan(oldRange.lengthDecimal, zero)) ||
                             (CPTDecimalLessThan(shift, zero) && CPTDecimalLessThan(oldRange.lengthDecimal, zero));

            // decelerate at the global range
            if ( hasShift ) {
                CGFloat brakingDelay = CPTNAN;

                if ( [globalRange containsRange:oldRange] ) {
                    // momentum started inside the global range; coast until we hit the global range
                    CGFloat globalPoint = [self viewCoordinateForRange:globalRange coordinate:coordinate direction:direction];
                    CGFloat oldPoint    = [self viewCoordinateForRange:oldRange coordinate:coordinate direction:direction];

                    CGFloat brakingOffset = globalPoint - oldPoint;
                    brakingDelay = CPTFirstPositiveRoot(acceleration, speed, brakingOffset);

                    if ( !isnan(brakingDelay)) {
                        speed -= brakingDelay * acceleration;

                        // slow down quickly
                        while ( momentumTime > CPTFloat(0.1)) {
                            acceleration *= CPTFloat(2.0);
                            momentumTime  = speed / (CPTFloat(2.0) * acceleration);
                        }

                        CGFloat distanceTraveled = speed * momentumTime - CPTFloat(0.5) * acceleration * momentumTime * momentumTime;
                        CGFloat brakingLength    = globalPoint - distanceTraveled;

                        CGPoint brakingPoint = CGPointZero;
                        switch ( coordinate ) {
                            case CPTCoordinateX:
                                brakingPoint = CPTPointMake(brakingLength, 0.0);
                                break;

                            case CPTCoordinateY:
                                brakingPoint = CPTPointMake(0.0, brakingLength);
                                break;

                            default:
                                break;
                        }

                        NSDecimal newPoint[2];
                        [self plotPoint:newPoint numberOfCoordinates:2 forPlotAreaViewPoint:brakingPoint];

                        NSDecimal brakingShift = CPTDecimalSubtract(newPoint[coordinate], direction ? globalRange.endDecimal : globalRange.locationDecimal);

                        [newRange shiftEndToFitInRange:globalRange];
                        [newRange shiftLocationToFitInRange:globalRange];
                        newRange.locationDecimal = CPTDecimalAdd(newRange.locationDecimal, brakingShift);
                    }
                }
                else {
                    // momentum started outside the global range
                    brakingDelay = CPTFloat(0.0);

                    // slow down quickly
                    while ( momentumTime > CPTFloat(0.1)) {
                        momentumTime *= CPTFloat(0.5);

                        shift = CPTDecimalDivide(shift, CPTDecimalFromInteger(2));
                    }

                    newRange = [oldRange mutableCopy];

                    newRange.locationDecimal = CPTDecimalAdd(newRange.locationDecimal, shift);
                }

                if ( !isnan(brakingDelay)) {
                    op = [CPTAnimation animate:self
                                      property:property
                                 fromPlotRange:constrainedRange
                                   toPlotRange:newRange
                                      duration:momentumTime
                                     withDelay:brakingDelay
                                animationCurve:self.momentumAnimationCurve
                                      delegate:self];
                    [animationArray addObject:op];

                    bounceDelay = momentumTime + brakingDelay;
                }
            }

            // bounce back to the global range
            CGFloat newPoint         = [self viewCoordinateForRange:newRange coordinate:coordinate direction:!direction];
            CGFloat constrainedPoint = [self viewCoordinateForRange:constrainedRange coordinate:coordinate direction:!direction];

            CGFloat offset = constrainedPoint - newPoint;

            CGFloat bounceTime = sqrt(ABS(offset) / self.bounceAcceleration);

            op = [CPTAnimation animate:self
                              property:property
                         fromPlotRange:newRange
                           toPlotRange:constrainedRange
                              duration:bounceTime
                             withDelay:bounceDelay
                        animationCurve:self.bounceAnimationCurve
                              delegate:self];
            [animationArray addObject:op];
        }
    }
}

-(CGFloat)viewCoordinateForRange:(nullable CPTPlotRange *)range coordinate:(CPTCoordinate)coordinate direction:(BOOL)direction
{
    CPTCoordinate orthogonalCoordinate = CPTOrthogonalCoordinate(coordinate);

    NSDecimal point[2];

    point[coordinate]           = (direction ? range.maxLimitDecimal : range.minLimitDecimal);
    point[orthogonalCoordinate] = CPTDecimalFromInteger(1);

    CGPoint viewPoint       = [self plotAreaViewPointForPlotPoint:point numberOfCoordinates:2];
    CGFloat pointCoordinate = CPTNAN;

    switch ( coordinate ) {
        case CPTCoordinateX:
            pointCoordinate = viewPoint.x;
            break;

        case CPTCoordinateY:
            pointCoordinate = viewPoint.y;
            break;

        default:
            break;
    }

    return pointCoordinate;
}

// return NAN if no positive roots
CGFloat CPTFirstPositiveRoot(CGFloat a, CGFloat b, CGFloat c)
{
    CGFloat root = CPTNAN;

    CGFloat discriminant = sqrt(b * b - CPTFloat(4.0) * a * c);

    CGFloat root1 = (-b + discriminant) / (CPTFloat(2.0) * a);
    CGFloat root2 = (-b - discriminant) / (CPTFloat(2.0) * a);

    if ( !isnan(root1) && !isnan(root2)) {
        if ( root1 >= CPTFloat(0.0)) {
            root = root1;
        }
        if ((root2 >= CPTFloat(0.0)) && (isnan(root) || (root2 < root))) {
            root = root2;
        }
    }

    return root;
}

-(void)setGlobalXRange:(nullable CPTPlotRange *)newRange
{
    if ( ![newRange isEqualToRange:globalXRange] ) {
        globalXRange = [newRange copy];
        self.xRange  = [self constrainRange:self.xRange toGlobalRange:globalXRange];
    }
}

-(void)setGlobalYRange:(nullable CPTPlotRange *)newRange
{
    if ( ![newRange isEqualToRange:globalYRange] ) {
        globalYRange = [newRange copy];
        self.yRange  = [self constrainRange:self.yRange toGlobalRange:globalYRange];
    }
}

-(void)scaleToFitPlots:(nullable CPTPlotArray *)plots
{
    if ( plots.count == 0 ) {
        return;
    }

    // Determine union of ranges
    CPTMutablePlotRange *unionXRange = nil;
    CPTMutablePlotRange *unionYRange = nil;
    for ( CPTPlot *plot in plots ) {
        CPTPlotRange *currentXRange = [plot plotRangeForCoordinate:CPTCoordinateX];
        CPTPlotRange *currentYRange = [plot plotRangeForCoordinate:CPTCoordinateY];
        if ( !unionXRange ) {
            unionXRange = [currentXRange mutableCopy];
        }
        if ( !unionYRange ) {
            unionYRange = [currentYRange mutableCopy];
        }
        [unionXRange unionPlotRange:currentXRange];
        [unionYRange unionPlotRange:currentYRange];
    }

    // Set range
    NSDecimal zero = CPTDecimalFromInteger(0);
    if ( unionXRange ) {
        if ( CPTDecimalEquals(unionXRange.lengthDecimal, zero)) {
            [unionXRange unionPlotRange:self.xRange];
        }
        self.xRange = unionXRange;
    }
    if ( unionYRange ) {
        if ( CPTDecimalEquals(unionYRange.lengthDecimal, zero)) {
            [unionYRange unionPlotRange:self.yRange];
        }
        self.yRange = unionYRange;
    }
}

-(void)scaleToFitEntirePlots:(nullable CPTPlotArray *)plots
{
    if ( plots.count == 0 ) {
        return;
    }

    // Determine union of ranges
    CPTMutablePlotRange *unionXRange = nil;
    CPTMutablePlotRange *unionYRange = nil;
    for ( CPTPlot *plot in plots ) {
        CPTPlotRange *currentXRange = [plot plotRangeEnclosingCoordinate:CPTCoordinateX];
        CPTPlotRange *currentYRange = [plot plotRangeEnclosingCoordinate:CPTCoordinateY];
        if ( !unionXRange ) {
            unionXRange = [currentXRange mutableCopy];
        }
        if ( !unionYRange ) {
            unionYRange = [currentYRange mutableCopy];
        }
        [unionXRange unionPlotRange:currentXRange];
        [unionYRange unionPlotRange:currentYRange];
    }

    // Set range
    NSDecimal zero = CPTDecimalFromInteger(0);
    if ( unionXRange ) {
        if ( CPTDecimalEquals(unionXRange.lengthDecimal, zero)) {
            [unionXRange unionPlotRange:self.xRange];
        }
        self.xRange = unionXRange;
    }
    if ( unionYRange ) {
        if ( CPTDecimalEquals(unionYRange.lengthDecimal, zero)) {
            [unionYRange unionPlotRange:self.yRange];
        }
        self.yRange = unionYRange;
    }
}

-(void)setXScaleType:(CPTScaleType)newScaleType
{
    if ( newScaleType != xScaleType ) {
        xScaleType = newScaleType;

        [[NSNotificationCenter defaultCenter] postNotificationName:CPTPlotSpaceCoordinateMappingDidChangeNotification
                                                            object:self
                                                          userInfo:@{ CPTPlotSpaceCoordinateKey: @(CPTCoordinateX) }
        ];

        CPTGraph *theGraph = self.graph;
        if ( theGraph ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:CPTGraphNeedsRedrawNotification
                                                                object:theGraph];
        }
    }
}

-(void)setYScaleType:(CPTScaleType)newScaleType
{
    if ( newScaleType != yScaleType ) {
        yScaleType = newScaleType;

        [[NSNotificationCenter defaultCenter] postNotificationName:CPTPlotSpaceCoordinateMappingDidChangeNotification
                                                            object:self
                                                          userInfo:@{ CPTPlotSpaceCoordinateKey: @(CPTCoordinateY) }
        ];

        CPTGraph *theGraph = self.graph;
        if ( theGraph ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:CPTGraphNeedsRedrawNotification
                                                                object:theGraph];
        }
    }
}

/// @endcond

#pragma mark -
#pragma mark Point Conversion (private utilities)

/// @cond

// Linear
-(CGFloat)viewCoordinateForViewLength:(NSDecimal)viewLength linearPlotRange:(nonnull CPTPlotRange *)range plotCoordinateValue:(NSDecimal)plotCoord
{
    if ( !range ) {
        return CPTFloat(0.0);
    }

    NSDecimal factor = CPTDecimalDivide(CPTDecimalSubtract(plotCoord, range.locationDecimal), range.lengthDecimal);
    if ( NSDecimalIsNotANumber(&factor)) {
        factor = CPTDecimalFromInteger(0);
    }

    NSDecimal viewCoordinate = CPTDecimalMultiply(viewLength, factor);

    return CPTDecimalCGFloatValue(viewCoordinate);
}

-(CGFloat)viewCoordinateForViewLength:(CGFloat)viewLength linearPlotRange:(nonnull CPTPlotRange *)range doublePrecisionPlotCoordinateValue:(double)plotCoord
{
    if ( !range || (range.lengthDouble == 0.0)) {
        return CPTFloat(0.0);
    }
    return viewLength * (CGFloat)((plotCoord - range.locationDouble) / range.lengthDouble);
}

-(NSDecimal)plotCoordinateForViewLength:(NSDecimal)viewLength linearPlotRange:(nonnull CPTPlotRange *)range boundsLength:(NSDecimal)boundsLength
{
    const NSDecimal zero = CPTDecimalFromInteger(0);

    if ( CPTDecimalEquals(boundsLength, zero)) {
        return zero;
    }

    NSDecimal location = range.locationDecimal;
    NSDecimal length   = range.lengthDecimal;

    NSDecimal coordinate;
    NSDecimalDivide(&coordinate, &viewLength, &boundsLength, NSRoundPlain);
    NSDecimalMultiply(&coordinate, &coordinate, &length, NSRoundPlain);
    NSDecimalAdd(&coordinate, &coordinate, &location, NSRoundPlain);

    return coordinate;
}

-(double)doublePrecisionPlotCoordinateForViewLength:(CGFloat)viewLength linearPlotRange:(nonnull CPTPlotRange *)range boundsLength:(CGFloat)boundsLength
{
    if ( boundsLength == CPTFloat(0.0)) {
        return 0.0;
    }

    double coordinate = (double)viewLength / (double)boundsLength;
    coordinate *= range.lengthDouble;
    coordinate += range.locationDouble;

    return coordinate;
}

// Log (only one version since there are no transcendental functions for NSDecimal)
-(CGFloat)viewCoordinateForViewLength:(CGFloat)viewLength logPlotRange:(nonnull CPTPlotRange *)range doublePrecisionPlotCoordinateValue:(double)plotCoord
{
    if ((range.minLimitDouble <= 0.0) || (range.maxLimitDouble <= 0.0) || (plotCoord <= 0.0)) {
        return CPTFloat(0.0);
    }

    double logLoc   = log10(range.locationDouble);
    double logCoord = log10(plotCoord);
    double logEnd   = log10(range.endDouble);

    return viewLength * (CGFloat)((logCoord - logLoc) / (logEnd - logLoc));
}

-(double)doublePrecisionPlotCoordinateForViewLength:(CGFloat)viewLength logPlotRange:(nonnull CPTPlotRange *)range boundsLength:(CGFloat)boundsLength
{
    if ( boundsLength == CPTFloat(0.0)) {
        return 0.0;
    }

    double logLoc = log10(range.locationDouble);
    double logEnd = log10(range.endDouble);

    double coordinate = (double)viewLength * (logEnd - logLoc) / (double)boundsLength + logLoc;

    return pow(10.0, coordinate);
}

// Log-modulus (only one version since there are no transcendental functions for NSDecimal)
-(CGFloat)viewCoordinateForViewLength:(CGFloat)viewLength logModulusPlotRange:(nonnull CPTPlotRange *)range doublePrecisionPlotCoordinateValue:(double)plotCoord
{
    if ( !range ) {
        return CPTFloat(0.0);
    }

    double logLoc   = CPTLogModulus(range.locationDouble);
    double logCoord = CPTLogModulus(plotCoord);
    double logEnd   = CPTLogModulus(range.endDouble);

    return viewLength * (CGFloat)((logCoord - logLoc) / (logEnd - logLoc));
}

-(double)doublePrecisionPlotCoordinateForViewLength:(CGFloat)viewLength logModulusPlotRange:(nonnull CPTPlotRange *)range boundsLength:(CGFloat)boundsLength
{
    if ( boundsLength == CPTFloat(0.0)) {
        return 0.0;
    }

    double logLoc     = CPTLogModulus(range.locationDouble);
    double logEnd     = CPTLogModulus(range.endDouble);
    double coordinate = (double)viewLength * (logEnd - logLoc) / (double)boundsLength + logLoc;

    return CPTInverseLogModulus(coordinate);
}

/// @endcond

#pragma mark -
#pragma mark Point Conversion

/// @cond

-(NSUInteger)numberOfCoordinates
{
    return 2;
}

// Plot area view point for plot point
-(CGPoint)plotAreaViewPointForPlotPoint:(nonnull CPTNumberArray *)plotPoint
{
    CGPoint viewPoint = [super plotAreaViewPointForPlotPoint:plotPoint];

    CGSize layerSize;
    CPTGraph *theGraph    = self.graph;
    CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;

    if ( plotArea ) {
        layerSize = plotArea.bounds.size;
    }
    else {
        return viewPoint;
    }

    switch ( self.xScaleType ) {
        case CPTScaleTypeLinear:
        case CPTScaleTypeCategory:
            viewPoint.x = [self viewCoordinateForViewLength:plotArea.widthDecimal linearPlotRange:self.xRange plotCoordinateValue:plotPoint[CPTCoordinateX].decimalValue];
            break;

        case CPTScaleTypeLog:
        {
            viewPoint.x = [self viewCoordinateForViewLength:layerSize.width logPlotRange:self.xRange doublePrecisionPlotCoordinateValue:plotPoint[CPTCoordinateX].doubleValue];
        }
        break;

        case CPTScaleTypeLogModulus:
        {
            viewPoint.x = [self viewCoordinateForViewLength:layerSize.width logModulusPlotRange:self.xRange doublePrecisionPlotCoordinateValue:plotPoint[CPTCoordinateX].doubleValue];
        }
        break;

        default:
            [NSException raise:CPTException format:@"Scale type not supported in CPTXYPlotSpace"];
    }

    switch ( self.yScaleType ) {
        case CPTScaleTypeLinear:
        case CPTScaleTypeCategory:
            viewPoint.y = [self viewCoordinateForViewLength:plotArea.heightDecimal linearPlotRange:self.yRange plotCoordinateValue:plotPoint[CPTCoordinateY].decimalValue];
            break;

        case CPTScaleTypeLog:
        {
            viewPoint.y = [self viewCoordinateForViewLength:layerSize.height logPlotRange:self.yRange doublePrecisionPlotCoordinateValue:plotPoint[CPTCoordinateY].doubleValue];
        }
        break;

        case CPTScaleTypeLogModulus:
        {
            viewPoint.y = [self viewCoordinateForViewLength:layerSize.height logModulusPlotRange:self.yRange doublePrecisionPlotCoordinateValue:plotPoint[CPTCoordinateY].doubleValue];
        }
        break;

        default:
            [NSException raise:CPTException format:@"Scale type not supported in CPTXYPlotSpace"];
    }

    return viewPoint;
}

-(CGPoint)plotAreaViewPointForPlotPoint:(nonnull NSDecimal *)plotPoint numberOfCoordinates:(NSUInteger)count
{
    CGPoint viewPoint = [super plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:count];

    CGSize layerSize;
    CPTGraph *theGraph    = self.graph;
    CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;

    if ( plotArea ) {
        layerSize = plotArea.bounds.size;
    }
    else {
        return viewPoint;
    }

    switch ( self.xScaleType ) {
        case CPTScaleTypeLinear:
        case CPTScaleTypeCategory:
            viewPoint.x = [self viewCoordinateForViewLength:plotArea.widthDecimal linearPlotRange:self.xRange plotCoordinateValue:plotPoint[CPTCoordinateX]];
            break;

        case CPTScaleTypeLog:
        {
            double x = CPTDecimalDoubleValue(plotPoint[CPTCoordinateX]);
            viewPoint.x = [self viewCoordinateForViewLength:layerSize.width logPlotRange:self.xRange doublePrecisionPlotCoordinateValue:x];
        }
        break;

        case CPTScaleTypeLogModulus:
        {
            double x = CPTDecimalDoubleValue(plotPoint[CPTCoordinateX]);
            viewPoint.x = [self viewCoordinateForViewLength:layerSize.width logModulusPlotRange:self.xRange doublePrecisionPlotCoordinateValue:x];
        }
        break;

        default:
            [NSException raise:CPTException format:@"Scale type not supported in CPTXYPlotSpace"];
    }

    switch ( self.yScaleType ) {
        case CPTScaleTypeLinear:
        case CPTScaleTypeCategory:
            viewPoint.y = [self viewCoordinateForViewLength:plotArea.heightDecimal linearPlotRange:self.yRange plotCoordinateValue:plotPoint[CPTCoordinateY]];
            break;

        case CPTScaleTypeLog:
        {
            double y = CPTDecimalDoubleValue(plotPoint[CPTCoordinateY]);
            viewPoint.y = [self viewCoordinateForViewLength:layerSize.height logPlotRange:self.yRange doublePrecisionPlotCoordinateValue:y];
        }
        break;

        case CPTScaleTypeLogModulus:
        {
            double y = CPTDecimalDoubleValue(plotPoint[CPTCoordinateY]);
            viewPoint.y = [self viewCoordinateForViewLength:layerSize.height logModulusPlotRange:self.yRange doublePrecisionPlotCoordinateValue:y];
        }
        break;

        default:
            [NSException raise:CPTException format:@"Scale type not supported in CPTXYPlotSpace"];
    }

    return viewPoint;
}

-(CGPoint)plotAreaViewPointForDoublePrecisionPlotPoint:(nonnull double *)plotPoint numberOfCoordinates:(NSUInteger)count
{
    CGPoint viewPoint = [super plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:count];

    CGSize layerSize;
    CPTGraph *theGraph    = self.graph;
    CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;

    if ( plotArea ) {
        layerSize = plotArea.bounds.size;
    }
    else {
        return viewPoint;
    }

    switch ( self.xScaleType ) {
        case CPTScaleTypeLinear:
        case CPTScaleTypeCategory:
            viewPoint.x = [self viewCoordinateForViewLength:layerSize.width linearPlotRange:self.xRange doublePrecisionPlotCoordinateValue:plotPoint[CPTCoordinateX]];
            break;

        case CPTScaleTypeLog:
            viewPoint.x = [self viewCoordinateForViewLength:layerSize.width logPlotRange:self.xRange doublePrecisionPlotCoordinateValue:plotPoint[CPTCoordinateX]];
            break;

        case CPTScaleTypeLogModulus:
            viewPoint.x = [self viewCoordinateForViewLength:layerSize.width logModulusPlotRange:self.xRange doublePrecisionPlotCoordinateValue:plotPoint[CPTCoordinateX]];
            break;

        default:
            [NSException raise:CPTException format:@"Scale type not supported in CPTXYPlotSpace"];
    }

    switch ( self.yScaleType ) {
        case CPTScaleTypeLinear:
        case CPTScaleTypeCategory:
            viewPoint.y = [self viewCoordinateForViewLength:layerSize.height linearPlotRange:self.yRange doublePrecisionPlotCoordinateValue:plotPoint[CPTCoordinateY]];
            break;

        case CPTScaleTypeLog:
            viewPoint.y = [self viewCoordinateForViewLength:layerSize.height logPlotRange:self.yRange doublePrecisionPlotCoordinateValue:plotPoint[CPTCoordinateY]];
            break;

        case CPTScaleTypeLogModulus:
            viewPoint.y = [self viewCoordinateForViewLength:layerSize.height logModulusPlotRange:self.yRange doublePrecisionPlotCoordinateValue:plotPoint[CPTCoordinateY]];
            break;

        default:
            [NSException raise:CPTException format:@"Scale type not supported in CPTXYPlotSpace"];
    }

    return viewPoint;
}

// Plot point for view point
-(nullable CPTNumberArray *)plotPointForPlotAreaViewPoint:(CGPoint)point
{
    CPTMutableNumberArray *plotPoint = [[super plotPointForPlotAreaViewPoint:point] mutableCopy];

    CGSize boundsSize;
    CPTGraph *theGraph    = self.graph;
    CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;

    if ( plotArea ) {
        boundsSize = plotArea.bounds.size;
    }
    else {
        return @[@0, @0];
    }

    if ( !plotPoint ) {
        plotPoint = [NSMutableArray arrayWithCapacity:self.numberOfCoordinates];
    }

    switch ( self.xScaleType ) {
        case CPTScaleTypeLinear:
        case CPTScaleTypeCategory:
            plotPoint[CPTCoordinateX] = [NSDecimalNumber decimalNumberWithDecimal:[self plotCoordinateForViewLength:CPTDecimalFromCGFloat(point.x)
                                                                                                    linearPlotRange:self.xRange
                                                                                                       boundsLength:plotArea.widthDecimal]];
            break;

        case CPTScaleTypeLog:
            plotPoint[CPTCoordinateX] = @([self doublePrecisionPlotCoordinateForViewLength:point.x logPlotRange:self.xRange boundsLength:boundsSize.width]);
            break;

        case CPTScaleTypeLogModulus:
            plotPoint[CPTCoordinateX] = @([self doublePrecisionPlotCoordinateForViewLength:point.x logModulusPlotRange:self.xRange boundsLength:boundsSize.width]);
            break;

        default:
            [NSException raise:CPTException format:@"Scale type not supported in CPTXYPlotSpace"];
    }

    switch ( self.yScaleType ) {
        case CPTScaleTypeLinear:
        case CPTScaleTypeCategory:
            plotPoint[CPTCoordinateY] = [NSDecimalNumber decimalNumberWithDecimal:[self plotCoordinateForViewLength:CPTDecimalFromCGFloat(point.y)
                                                                                                    linearPlotRange:self.yRange
                                                                                                       boundsLength:plotArea.heightDecimal]];
            break;

        case CPTScaleTypeLog:
            plotPoint[CPTCoordinateY] = @([self doublePrecisionPlotCoordinateForViewLength:point.y logPlotRange:self.yRange boundsLength:boundsSize.height]);
            break;

        case CPTScaleTypeLogModulus:
            plotPoint[CPTCoordinateY] = @([self doublePrecisionPlotCoordinateForViewLength:point.y logModulusPlotRange:self.yRange boundsLength:boundsSize.height]);
            break;

        default:
            [NSException raise:CPTException format:@"Scale type not supported in CPTXYPlotSpace"];
    }

    return plotPoint;
}

-(void)plotPoint:(nonnull NSDecimal *)plotPoint numberOfCoordinates:(NSUInteger)count forPlotAreaViewPoint:(CGPoint)point
{
    [super plotPoint:plotPoint numberOfCoordinates:count forPlotAreaViewPoint:point];

    CGSize boundsSize;
    CPTGraph *theGraph    = self.graph;
    CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;

    if ( plotArea ) {
        boundsSize = plotArea.bounds.size;
    }
    else {
        NSDecimal zero = CPTDecimalFromInteger(0);
        plotPoint[CPTCoordinateX] = zero;
        plotPoint[CPTCoordinateY] = zero;
        return;
    }

    switch ( self.xScaleType ) {
        case CPTScaleTypeLinear:
        case CPTScaleTypeCategory:
            plotPoint[CPTCoordinateX] = [self plotCoordinateForViewLength:CPTDecimalFromCGFloat(point.x) linearPlotRange:self.xRange boundsLength:plotArea.widthDecimal];
            break;

        case CPTScaleTypeLog:
            plotPoint[CPTCoordinateX] = CPTDecimalFromDouble([self doublePrecisionPlotCoordinateForViewLength:point.x logPlotRange:self.xRange boundsLength:boundsSize.width]);
            break;

        case CPTScaleTypeLogModulus:
            plotPoint[CPTCoordinateX] = CPTDecimalFromDouble([self doublePrecisionPlotCoordinateForViewLength:point.x logModulusPlotRange:self.xRange boundsLength:boundsSize.width]);
            break;

        default:
            [NSException raise:CPTException format:@"Scale type not supported in CPTXYPlotSpace"];
    }

    switch ( self.yScaleType ) {
        case CPTScaleTypeLinear:
        case CPTScaleTypeCategory:
            plotPoint[CPTCoordinateY] = [self plotCoordinateForViewLength:CPTDecimalFromCGFloat(point.y) linearPlotRange:self.yRange boundsLength:plotArea.heightDecimal];
            break;

        case CPTScaleTypeLog:
            plotPoint[CPTCoordinateY] = CPTDecimalFromDouble([self doublePrecisionPlotCoordinateForViewLength:point.y logPlotRange:self.yRange boundsLength:boundsSize.height]);
            break;

        case CPTScaleTypeLogModulus:
            plotPoint[CPTCoordinateY] = CPTDecimalFromDouble([self doublePrecisionPlotCoordinateForViewLength:point.y logModulusPlotRange:self.yRange boundsLength:boundsSize.height]);
            break;

        default:
            [NSException raise:CPTException format:@"Scale type not supported in CPTXYPlotSpace"];
    }
}

-(void)doublePrecisionPlotPoint:(nonnull double *)plotPoint numberOfCoordinates:(NSUInteger)count forPlotAreaViewPoint:(CGPoint)point
{
    [super doublePrecisionPlotPoint:plotPoint numberOfCoordinates:count forPlotAreaViewPoint:point];

    CGSize boundsSize;
    CPTGraph *theGraph    = self.graph;
    CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;

    if ( plotArea ) {
        boundsSize = plotArea.bounds.size;
    }
    else {
        plotPoint[CPTCoordinateX] = 0.0;
        plotPoint[CPTCoordinateY] = 0.0;
        return;
    }

    switch ( self.xScaleType ) {
        case CPTScaleTypeLinear:
        case CPTScaleTypeCategory:
            plotPoint[CPTCoordinateX] = [self doublePrecisionPlotCoordinateForViewLength:point.x linearPlotRange:self.xRange boundsLength:boundsSize.width];
            break;

        case CPTScaleTypeLog:
            plotPoint[CPTCoordinateX] = [self doublePrecisionPlotCoordinateForViewLength:point.x logPlotRange:self.xRange boundsLength:boundsSize.width];
            break;

        case CPTScaleTypeLogModulus:
            plotPoint[CPTCoordinateX] = [self doublePrecisionPlotCoordinateForViewLength:point.x logModulusPlotRange:self.xRange boundsLength:boundsSize.width];
            break;

        default:
            [NSException raise:CPTException format:@"Scale type not supported in CPTXYPlotSpace"];
    }

    switch ( self.yScaleType ) {
        case CPTScaleTypeLinear:
        case CPTScaleTypeCategory:
            plotPoint[CPTCoordinateY] = [self doublePrecisionPlotCoordinateForViewLength:point.y linearPlotRange:self.yRange boundsLength:boundsSize.height];
            break;

        case CPTScaleTypeLog:
            plotPoint[CPTCoordinateY] = [self doublePrecisionPlotCoordinateForViewLength:point.y logPlotRange:self.yRange boundsLength:boundsSize.height];
            break;

        case CPTScaleTypeLogModulus:
            plotPoint[CPTCoordinateY] = [self doublePrecisionPlotCoordinateForViewLength:point.y logModulusPlotRange:self.yRange boundsLength:boundsSize.height];
            break;

        default:
            [NSException raise:CPTException format:@"Scale type not supported in CPTXYPlotSpace"];
    }
}

// Plot area view point for event
-(CGPoint)plotAreaViewPointForEvent:(nonnull CPTNativeEvent *)event
{
    CGPoint plotAreaViewPoint = CGPointZero;

    CPTGraph *theGraph                  = self.graph;
    CPTGraphHostingView *theHostingView = theGraph.hostingView;
    CPTPlotArea *thePlotArea            = theGraph.plotAreaFrame.plotArea;

    if ( theHostingView && thePlotArea ) {
#if TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
        CGPoint interactionPoint = [[[event touchesForView:theHostingView] anyObject] locationInView:theHostingView];
        if ( theHostingView.collapsesLayers ) {
            interactionPoint.y = theHostingView.frame.size.height - interactionPoint.y;
            plotAreaViewPoint  = [theGraph convertPoint:interactionPoint toLayer:thePlotArea];
        }
        else {
            plotAreaViewPoint = [theHostingView.layer convertPoint:interactionPoint toLayer:thePlotArea];
        }
#else
        CGPoint interactionPoint = NSPointToCGPoint([theHostingView convertPoint:event.locationInWindow fromView:nil]);
        plotAreaViewPoint = [theHostingView.layer convertPoint:interactionPoint toLayer:thePlotArea];
#endif
    }

    return plotAreaViewPoint;
}

// Plot point for event
-(nullable CPTNumberArray *)plotPointForEvent:(nonnull CPTNativeEvent *)event
{
    return [self plotPointForPlotAreaViewPoint:[self plotAreaViewPointForEvent:event]];
}

-(void)plotPoint:(nonnull NSDecimal *)plotPoint numberOfCoordinates:(NSUInteger)count forEvent:(nonnull CPTNativeEvent *)event
{
    [self plotPoint:plotPoint numberOfCoordinates:count forPlotAreaViewPoint:[self plotAreaViewPointForEvent:event]];
}

-(void)doublePrecisionPlotPoint:(nonnull double *)plotPoint numberOfCoordinates:(NSUInteger)count forEvent:(nonnull CPTNativeEvent *)event
{
    [self doublePrecisionPlotPoint:plotPoint numberOfCoordinates:count forPlotAreaViewPoint:[self plotAreaViewPointForEvent:event]];
}

/// @endcond

#pragma mark -
#pragma mark Scaling

/// @cond

-(void)scaleBy:(CGFloat)interactionScale aboutPoint:(CGPoint)plotAreaPoint
{
    CPTGraph *theGraph    = self.graph;
    CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;

    if ( !plotArea || (interactionScale <= CPTFloat(1.e-6))) {
        return;
    }
    if ( ![plotArea containsPoint:plotAreaPoint] ) {
        return;
    }

    // Ask the delegate if it is OK
    id<CPTPlotSpaceDelegate> theDelegate = self.delegate;

    BOOL shouldScale = YES;
    if ( [theDelegate respondsToSelector:@selector(plotSpace:shouldScaleBy:aboutPoint:)] ) {
        shouldScale = [theDelegate plotSpace:self shouldScaleBy:interactionScale aboutPoint:plotAreaPoint];
    }
    if ( !shouldScale ) {
        return;
    }

    // Determine point in plot coordinates
    NSDecimal const decimalScale = CPTDecimalFromCGFloat(interactionScale);
    NSDecimal plotInteractionPoint[2];
    [self plotPoint:plotInteractionPoint numberOfCoordinates:2 forPlotAreaViewPoint:plotAreaPoint];

    // Cache old ranges
    CPTPlotRange *oldRangeX = self.xRange;
    CPTPlotRange *oldRangeY = self.yRange;

    // Lengths are scaled by the pinch gesture inverse proportional
    NSDecimal newLengthX = CPTDecimalDivide(oldRangeX.lengthDecimal, decimalScale);
    NSDecimal newLengthY = CPTDecimalDivide(oldRangeY.lengthDecimal, decimalScale);

    // New locations
    NSDecimal newLocationX;
    if ( CPTDecimalGreaterThanOrEqualTo(oldRangeX.lengthDecimal, CPTDecimalFromInteger(0))) {
        NSDecimal oldFirstLengthX = CPTDecimalSubtract(plotInteractionPoint[CPTCoordinateX], oldRangeX.minLimitDecimal); // x - minX
        NSDecimal newFirstLengthX = CPTDecimalDivide(oldFirstLengthX, decimalScale);                                     // (x - minX) / scale
        newLocationX = CPTDecimalSubtract(plotInteractionPoint[CPTCoordinateX], newFirstLengthX);
    }
    else {
        NSDecimal oldSecondLengthX = CPTDecimalSubtract(oldRangeX.maxLimitDecimal, plotInteractionPoint[0]); // maxX - x
        NSDecimal newSecondLengthX = CPTDecimalDivide(oldSecondLengthX, decimalScale);                       // (maxX - x) / scale
        newLocationX = CPTDecimalAdd(plotInteractionPoint[CPTCoordinateX], newSecondLengthX);
    }

    NSDecimal newLocationY;
    if ( CPTDecimalGreaterThanOrEqualTo(oldRangeY.lengthDecimal, CPTDecimalFromInteger(0))) {
        NSDecimal oldFirstLengthY = CPTDecimalSubtract(plotInteractionPoint[CPTCoordinateY], oldRangeY.minLimitDecimal); // y - minY
        NSDecimal newFirstLengthY = CPTDecimalDivide(oldFirstLengthY, decimalScale);                                     // (y - minY) / scale
        newLocationY = CPTDecimalSubtract(plotInteractionPoint[CPTCoordinateY], newFirstLengthY);
    }
    else {
        NSDecimal oldSecondLengthY = CPTDecimalSubtract(oldRangeY.maxLimitDecimal, plotInteractionPoint[1]); // maxY - y
        NSDecimal newSecondLengthY = CPTDecimalDivide(oldSecondLengthY, decimalScale);                       // (maxY - y) / scale
        newLocationY = CPTDecimalAdd(plotInteractionPoint[CPTCoordinateY], newSecondLengthY);
    }

    // New ranges
    CPTPlotRange *newRangeX = [[CPTPlotRange alloc] initWithLocationDecimal:newLocationX lengthDecimal:newLengthX];
    CPTPlotRange *newRangeY = [[CPTPlotRange alloc] initWithLocationDecimal:newLocationY lengthDecimal:newLengthY];

    BOOL oldMomentum = self.allowsMomentumX;
    self.allowsMomentumX = NO;
    self.xRange          = newRangeX;
    self.allowsMomentumX = oldMomentum;

    oldMomentum          = self.allowsMomentumY;
    self.allowsMomentumY = NO;
    self.yRange          = newRangeY;
    self.allowsMomentumY = oldMomentum;
}

/// @endcond

#pragma mark -
#pragma mark Interaction

/// @name User Interaction
/// @{

/**
 *  @brief Informs the receiver that the user has
 *  @if MacOnly pressed the mouse button. @endif
 *  @if iOSOnly touched the screen. @endif
 *
 *
 *  If the receiver has a @ref delegate and the delegate handles the event,
 *  this method always returns @YES.
 *  If @ref allowsUserInteraction is @NO
 *  or the graph does not have a @link CPTPlotAreaFrame::plotArea plotArea @endlink layer,
 *  this method always returns @NO.
 *  Otherwise, if the @par{interactionPoint} is within the bounds of the
 *  @link CPTPlotAreaFrame::plotArea plotArea @endlink, a drag operation starts and
 *  this method returns @YES.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceDownEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    self.isDragging = NO;

    BOOL handledByDelegate = [super pointingDeviceDownEvent:event atPoint:interactionPoint];
    if ( handledByDelegate ) {
        return YES;
    }

    CPTGraph *theGraph    = self.graph;
    CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;
    if ( !self.allowsUserInteraction || !plotArea ) {
        return NO;
    }

    CGPoint pointInPlotArea = [theGraph convertPoint:interactionPoint toLayer:plotArea];
    if ( [plotArea containsPoint:pointInPlotArea] ) {
        // Handle event
        self.lastDragPoint    = pointInPlotArea;
        self.lastDisplacement = CGPointZero;
        self.lastDragTime     = event.timestamp;
        self.lastDeltaTime    = 0.0;

        // Clear any previous animations
        CPTMutableAnimationArray *animationArray = self.animations;
        for ( CPTAnimationOperation *op in animationArray ) {
            [[CPTAnimation sharedInstance] removeAnimationOperation:op];
        }
        [animationArray removeAllObjects];

        return YES;
    }

    return NO;
}

/**
 *  @brief Informs the receiver that the user has
 *  @if MacOnly released the mouse button. @endif
 *  @if iOSOnly lifted their finger off the screen. @endif
 *
 *
 *  If the receiver has a @ref delegate and the delegate handles the event,
 *  this method always returns @YES.
 *  If @ref allowsUserInteraction is @NO
 *  or the graph does not have a @link CPTPlotAreaFrame::plotArea plotArea @endlink layer,
 *  this method always returns @NO.
 *  Otherwise, if a drag operation is in progress, it ends and
 *  this method returns @YES.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceUpEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    BOOL handledByDelegate = [super pointingDeviceUpEvent:event atPoint:interactionPoint];

    if ( handledByDelegate ) {
        return YES;
    }

    CPTGraph *theGraph    = self.graph;
    CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;
    if ( !self.allowsUserInteraction || !plotArea ) {
        return NO;
    }

    if ( self.isDragging ) {
        self.isDragging = NO;

        CGFloat acceleration = CPTFloat(0.0);
        CGFloat speed        = CPTFloat(0.0);
        CGFloat momentumTime = CPTFloat(0.0);

        NSDecimal shiftX = CPTDecimalFromInteger(0);
        NSDecimal shiftY = CPTDecimalFromInteger(0);

        CGFloat scaleX = CPTFloat(0.0);
        CGFloat scaleY = CPTFloat(0.0);

        if ( self.allowsMomentum ) {
            NSTimeInterval deltaT     = event.timestamp - self.lastDragTime;
            NSTimeInterval lastDeltaT = self.lastDeltaTime;

            if ((deltaT > 0.0) && (deltaT < 0.05) && (lastDeltaT > 0.0)) {
                CGPoint pointInPlotArea = [theGraph convertPoint:interactionPoint toLayer:plotArea];
                CGPoint displacement    = self.lastDisplacement;

                acceleration = self.momentumAcceleration;
                speed        = sqrt(displacement.x * displacement.x + displacement.y * displacement.y) / CPTFloat(lastDeltaT);
                momentumTime = speed / (CPTFloat(2.0) * acceleration);
                CGFloat distanceTraveled = speed * momentumTime - CPTFloat(0.5) * acceleration * momentumTime * momentumTime;
                distanceTraveled = MAX(distanceTraveled, CPTFloat(0.0));

                CGFloat theta = atan2(displacement.y, displacement.x);
                scaleX = cos(theta);
                scaleY = sin(theta);

                NSDecimal lastPoint[2], newPoint[2];
                [self plotPoint:lastPoint numberOfCoordinates:2 forPlotAreaViewPoint:pointInPlotArea];
                [self plotPoint:newPoint numberOfCoordinates:2 forPlotAreaViewPoint:CGPointMake(pointInPlotArea.x + distanceTraveled * scaleX,
                                                                                                pointInPlotArea.y + distanceTraveled * scaleY)];

                if ( self.allowsMomentumX ) {
                    shiftX = CPTDecimalSubtract(lastPoint[CPTCoordinateX], newPoint[CPTCoordinateX]);
                }
                if ( self.allowsMomentumY ) {
                    shiftY = CPTDecimalSubtract(lastPoint[CPTCoordinateY], newPoint[CPTCoordinateY]);
                }
            }
        }

        // X range
        [self animateRangeForCoordinate:CPTCoordinateX
                                  shift:shiftX
                           momentumTime:momentumTime
                                  speed:speed * scaleX
                           acceleration:acceleration * scaleX];

        // Y range
        [self animateRangeForCoordinate:CPTCoordinateY
                                  shift:shiftY
                           momentumTime:momentumTime
                                  speed:speed * scaleY
                           acceleration:acceleration * scaleY];

        return YES;
    }

    return NO;
}

/**
 *  @brief Informs the receiver that the user has moved
 *  @if MacOnly the mouse with the button pressed. @endif
 *  @if iOSOnly their finger while touching the screen. @endif
 *
 *
 *  If the receiver has a @ref delegate and the delegate handles the event,
 *  this method always returns @YES.
 *  If @ref allowsUserInteraction is @NO
 *  or the graph does not have a @link CPTPlotAreaFrame::plotArea plotArea @endlink layer,
 *  this method always returns @NO.
 *  Otherwise, if a drag operation commences or is in progress, the @ref xRange
 *  and @ref yRange are shifted to follow the drag and
 *  this method returns @YES.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceDraggedEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    BOOL handledByDelegate = [super pointingDeviceDraggedEvent:event atPoint:interactionPoint];

    if ( handledByDelegate ) {
        return YES;
    }

    CPTGraph *theGraph    = self.graph;
    CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;
    if ( !self.allowsUserInteraction || !plotArea ) {
        return NO;
    }

    CGPoint lastDraggedPoint = self.lastDragPoint;
    CGPoint pointInPlotArea  = [theGraph convertPoint:interactionPoint toLayer:plotArea];
    CGPoint displacement     = CPTPointMake(pointInPlotArea.x - lastDraggedPoint.x, pointInPlotArea.y - lastDraggedPoint.y);

    if ( !self.isDragging ) {
        // Have we started dragging, i.e., has the interactionPoint moved sufficiently to indicate a drag has started?
        CGFloat displacedBy = sqrt(displacement.x * displacement.x + displacement.y * displacement.y);
        self.isDragging = (displacedBy > self.minimumDisplacementToDrag);
    }

    if ( self.isDragging ) {
        CGPoint pointToUse = pointInPlotArea;

        id<CPTPlotSpaceDelegate> theDelegate = self.delegate;

        // Allow delegate to override
        if ( [theDelegate respondsToSelector:@selector(plotSpace:willDisplaceBy:)] ) {
            displacement = [theDelegate plotSpace:self willDisplaceBy:displacement];
            pointToUse   = CPTPointMake(lastDraggedPoint.x + displacement.x, lastDraggedPoint.y + displacement.y);
        }

        NSDecimal lastPoint[2], newPoint[2];
        [self plotPoint:lastPoint numberOfCoordinates:2 forPlotAreaViewPoint:lastDraggedPoint];
        [self plotPoint:newPoint numberOfCoordinates:2 forPlotAreaViewPoint:pointToUse];

        // X range
        NSDecimal shiftX        = CPTDecimalSubtract(lastPoint[CPTCoordinateX], newPoint[CPTCoordinateX]);
        CPTPlotRange *newRangeX = [self shiftRange:self.xRange
                                                by:shiftX
                                     usingMomentum:self.allowsMomentumX
                                     inGlobalRange:self.globalXRange
                                  withDisplacement:&displacement.x];

        // Y range
        NSDecimal shiftY        = CPTDecimalSubtract(lastPoint[CPTCoordinateY], newPoint[CPTCoordinateY]);
        CPTPlotRange *newRangeY = [self shiftRange:self.yRange
                                                by:shiftY
                                     usingMomentum:self.allowsMomentumY
                                     inGlobalRange:self.globalYRange
                                  withDisplacement:&displacement.y];

        self.lastDragPoint    = pointInPlotArea;
        self.lastDisplacement = displacement;

        NSTimeInterval currentTime = event.timestamp;
        self.lastDeltaTime = currentTime - self.lastDragTime;
        self.lastDragTime  = currentTime;

        self.xRange = newRangeX;
        self.yRange = newRangeY;

        return YES;
    }

    return NO;
}

/// @cond

-(nullable CPTPlotRange *)shiftRange:(nonnull CPTPlotRange *)oldRange by:(NSDecimal)shift usingMomentum:(BOOL)momentum inGlobalRange:(nullable CPTPlotRange *)globalRange withDisplacement:(CGFloat *)displacement
{
    CPTMutablePlotRange *newRange = [oldRange mutableCopy];

    newRange.locationDecimal = CPTDecimalAdd(newRange.locationDecimal, shift);

    if ( globalRange ) {
        CPTPlotRange *constrainedRange = [self constrainRange:newRange toGlobalRange:globalRange];

        if ( momentum ) {
            if ( ![newRange isEqualToRange:constrainedRange] ) {
                // reduce the shift as we get farther outside the global range
                NSDecimal rangeLength = newRange.lengthDecimal;

                if ( !CPTDecimalEquals(rangeLength, CPTDecimalFromInteger(0))) {
                    NSDecimal diff = CPTDecimalDivide(CPTDecimalSubtract(constrainedRange.locationDecimal, newRange.locationDecimal), rangeLength);
                    diff = CPTDecimalMax(CPTDecimalMin(CPTDecimalMultiply(diff, CPTDecimalFromDouble(2.5)), CPTDecimalFromInteger(1)), CPTDecimalFromInteger(-1));

                    newRange.locationDecimal = CPTDecimalSubtract(newRange.locationDecimal, CPTDecimalMultiply(shift, CPTDecimalAbs(diff)));

                    *displacement = *displacement * (CPTFloat(1.0) - ABS(CPTDecimalCGFloatValue(diff)));
                }
            }
        }
        else {
            newRange = (CPTMutablePlotRange *)constrainedRange;
        }
    }

    return newRange;
}

/// @endcond

#if TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
#else

/**
 *  @brief Informs the receiver that the user has moved the scroll wheel.
 *
 *
 *  If the receiver does not have a @ref delegate,
 *  this method always returns @NO. Otherwise, the
 *  @link CPTPlotSpaceDelegate::plotSpace:shouldHandleScrollWheelEvent:fromPoint:toPoint: -plotSpace:shouldHandleScrollWheelEvent:fromPoint:toPoint: @endlink
 *  delegate method is called. If it returns @NO, this method returns @YES
 *  to indicate that the event has been handled and no further processing should occur.
 *
 *  @param event The OS event.
 *  @param fromPoint The starting coordinates of the interaction.
 *  @param toPoint The ending coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)scrollWheelEvent:(nonnull CPTNativeEvent *)event fromPoint:(CGPoint)fromPoint toPoint:(CGPoint)toPoint
{
    BOOL handledByDelegate = [super scrollWheelEvent:event fromPoint:fromPoint toPoint:toPoint];

    if ( handledByDelegate ) {
        return YES;
    }

    CPTGraph *theGraph    = self.graph;
    CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;
    if ( !self.allowsUserInteraction || !plotArea ) {
        return NO;
    }

    CGPoint fromPointInPlotArea = [theGraph convertPoint:fromPoint toLayer:plotArea];
    CGPoint toPointInPlotArea   = [theGraph convertPoint:toPoint toLayer:plotArea];
    CGPoint displacement        = CPTPointMake(toPointInPlotArea.x - fromPointInPlotArea.x, toPointInPlotArea.y - fromPointInPlotArea.y);
    CGPoint pointToUse          = toPointInPlotArea;

    id<CPTPlotSpaceDelegate> theDelegate = self.delegate;

    // Allow delegate to override
    if ( [theDelegate respondsToSelector:@selector(plotSpace:willDisplaceBy:)] ) {
        displacement = [theDelegate plotSpace:self willDisplaceBy:displacement];
        pointToUse   = CPTPointMake(fromPointInPlotArea.x + displacement.x, fromPointInPlotArea.y + displacement.y);
    }

    NSDecimal lastPoint[2], newPoint[2];
    [self plotPoint:lastPoint numberOfCoordinates:2 forPlotAreaViewPoint:fromPointInPlotArea];
    [self plotPoint:newPoint numberOfCoordinates:2 forPlotAreaViewPoint:pointToUse];

    // X range
    NSDecimal shiftX        = CPTDecimalSubtract(lastPoint[CPTCoordinateX], newPoint[CPTCoordinateX]);
    CPTPlotRange *newRangeX = [self shiftRange:self.xRange
                                            by:shiftX
                                 usingMomentum:NO
                                 inGlobalRange:self.globalXRange
                              withDisplacement:&displacement.x];

    // Y range
    NSDecimal shiftY        = CPTDecimalSubtract(lastPoint[CPTCoordinateY], newPoint[CPTCoordinateY]);
    CPTPlotRange *newRangeY = [self shiftRange:self.yRange
                                            by:shiftY
                                 usingMomentum:NO
                                 inGlobalRange:self.globalYRange
                              withDisplacement:&displacement.y];

    self.xRange = newRangeX;
    self.yRange = newRangeY;

    return YES;
}

#endif

/**
 *  @brief Reset the dragging state and cancel any active animations.
 **/
-(void)cancelAnimations
{
    self.isDragging = NO;
    for ( CPTAnimationOperation *op in self.animations ) {
        [[CPTAnimation sharedInstance] removeAnimationOperation:op];
    }
}

/// @}

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setAllowsMomentum:(BOOL)newMomentum
{
    self.allowsMomentumX = newMomentum;
    self.allowsMomentumY = newMomentum;
}

-(BOOL)allowsMomentum
{
    return self.allowsMomentumX || self.allowsMomentumY;
}

/// @endcond

#pragma mark -
#pragma mark Animation Delegate

/// @cond

-(void)animationDidFinish:(nonnull CPTAnimationOperation *)operation
{
    [self.animations removeObjectIdenticalTo:operation];
}

/// @endcond

#pragma mark -
#pragma mark Debugging

/// @cond

-(nullable id)debugQuickLookObject
{
    // Plot space
    NSString *plotAreaDesc = [super debugQuickLookObject];

    // X-range
    NSString *xScaleTypeDesc = nil;

    switch ( self.xScaleType ) {
        case CPTScaleTypeLinear:
            xScaleTypeDesc = @"CPTScaleTypeLinear";
            break;

        case CPTScaleTypeLog:
            xScaleTypeDesc = @"CPTScaleTypeLog";
            break;

        case CPTScaleTypeLogModulus:
            xScaleTypeDesc = @"CPTScaleTypeLogModulus";
            break;

        case CPTScaleTypeAngular:
            xScaleTypeDesc = @"CPTScaleTypeAngular";
            break;

        case CPTScaleTypeDateTime:
            xScaleTypeDesc = @"CPTScaleTypeDateTime";
            break;

        case CPTScaleTypeCategory:
            xScaleTypeDesc = @"CPTScaleTypeCategory";
            break;
    }

    NSString *xRangeDesc = [NSString stringWithFormat:@"xRange:\n%@\nglobalXRange:\n%@\nxScaleType: %@",
                            [self.xRange debugQuickLookObject],
                            [self.globalXRange debugQuickLookObject],
                            xScaleTypeDesc];

    // Y-range
    NSString *yScaleTypeDesc = nil;

    switch ( self.yScaleType ) {
        case CPTScaleTypeLinear:
            yScaleTypeDesc = @"CPTScaleTypeLinear";
            break;

        case CPTScaleTypeLog:
            yScaleTypeDesc = @"CPTScaleTypeLog";
            break;

        case CPTScaleTypeLogModulus:
            yScaleTypeDesc = @"CPTScaleTypeLogModulus";
            break;

        case CPTScaleTypeAngular:
            yScaleTypeDesc = @"CPTScaleTypeAngular";
            break;

        case CPTScaleTypeDateTime:
            yScaleTypeDesc = @"CPTScaleTypeDateTime";
            break;

        case CPTScaleTypeCategory:
            yScaleTypeDesc = @"CPTScaleTypeCategory";
            break;
    }

    NSString *yRangeDesc = [NSString stringWithFormat:@"yRange:\n%@\nglobalYRange:\n%@\nyScaleType: %@",
                            [self.yRange debugQuickLookObject],
                            [self.globalYRange debugQuickLookObject],
                            yScaleTypeDesc];

    return [NSString stringWithFormat:@"%@\n\nX:\n%@\n\nY:\n%@", plotAreaDesc, xRangeDesc, yRangeDesc];
}

/// @endcond

@end

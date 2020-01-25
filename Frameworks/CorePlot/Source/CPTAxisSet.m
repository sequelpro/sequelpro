#import "CPTAxisSet.h"

#import "CPTGraph.h"
#import "CPTLineStyle.h"
#import "CPTPlotArea.h"

/**
 *  @brief A container layer for the set of axes for a graph.
 **/
@implementation CPTAxisSet

/** @property nullable CPTAxisArray *axes
 *  @brief The axes in the axis set.
 **/
@synthesize axes;

/** @property nullable CPTLineStyle *borderLineStyle
 *  @brief The line style for the layer border.
 *  If @nil, the border is not drawn.
 **/
@synthesize borderLineStyle;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTAxisSet object with the provided frame rectangle.
 *
 *  This is the designated initializer. The initialized layer will have the following properties:
 *  - @ref axes = empty array
 *  - @ref borderLineStyle = @nil
 *  - @ref needsDisplayOnBoundsChange = @YES
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTAxisSet object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame
{
    if ((self = [super initWithFrame:newFrame])) {
        axes            = @[];
        borderLineStyle = nil;

        self.needsDisplayOnBoundsChange = YES;
    }
    return self;
}

/// @}

/// @cond

-(nonnull instancetype)initWithLayer:(nonnull id)layer
{
    if ((self = [super initWithLayer:layer])) {
        CPTAxisSet *theLayer = (CPTAxisSet *)layer;

        axes            = theLayer->axes;
        borderLineStyle = theLayer->borderLineStyle;
    }
    return self;
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeObject:self.axes forKey:@"CPTAxisSet.axes"];
    [coder encodeObject:self.borderLineStyle forKey:@"CPTAxisSet.borderLineStyle"];
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        axes = [[coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [CPTAxis class]]]
                                      forKey:@"CPTAxisSet.axes"] copy];
        borderLineStyle = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                               forKey:@"CPTAxisSet.borderLineStyle"] copy];
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
#pragma mark Drawing

/// @cond

-(void)display
{
    if ( self.borderLineStyle ) {
        [super display];
    }
}

/// @endcond

#pragma mark -
#pragma mark Labeling

/**
 *  @brief Updates the axis labels for each axis in the axis set.
 **/
-(void)relabelAxes
{
    CPTAxisArray *theAxes = self.axes;

    [theAxes makeObjectsPerformSelector:@selector(setNeedsLayout)];
    [theAxes makeObjectsPerformSelector:@selector(setNeedsRelabel)];
}

#pragma mark -
#pragma mark Axes

/**
 *  @brief Returns the first, second, third, etc. axis with the given coordinate value.
 *
 *  For example, to find the second x-axis, use a @par{coordinate} of #CPTCoordinateX
 *  and @par{idx} of @num{1}.
 *
 *  @param coordinate The axis coordinate.
 *  @param idx The zero-based index.
 *  @return The axis matching the given coordinate and index, or @nil if no match is found.
 **/
-(nullable CPTAxis *)axisForCoordinate:(CPTCoordinate)coordinate atIndex:(NSUInteger)idx
{
    CPTAxis *foundAxis = nil;
    NSUInteger count   = 0;

    for ( CPTAxis *axis in self.axes ) {
        if ( axis.coordinate == coordinate ) {
            if ( count == idx ) {
                foundAxis = axis;
                break;
            }
            else {
                count++;
            }
        }
    }

    return foundAxis;
}

#pragma mark -
#pragma mark Responder Chain and User interaction

/// @name User Interaction
/// @{

/**
 *  @brief Informs the receiver that the user has
 *  @if MacOnly pressed the mouse button. @endif
 *  @if iOSOnly started touching the screen. @endif
 *
 *
 *  The event will be passed to each axis belonging to the receiver in turn. This method
 *  returns @YES if any of its axes handle the event.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceDownEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    for ( CPTAxis *axis in self.axes ) {
        if ( [axis pointingDeviceDownEvent:event atPoint:interactionPoint] ) {
            return YES;
        }
    }

    return [super pointingDeviceDownEvent:event atPoint:interactionPoint];
}

/**
 *  @brief Informs the receiver that the user has
 *  @if MacOnly released the mouse button. @endif
 *  @if iOSOnly ended touching the screen. @endif
 *
 *
 *  The event will be passed to each axis belonging to the receiver in turn. This method
 *  returns @YES if any of its axes handle the event.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceUpEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    for ( CPTAxis *axis in self.axes ) {
        if ( [axis pointingDeviceUpEvent:event atPoint:interactionPoint] ) {
            return YES;
        }
    }

    return [super pointingDeviceUpEvent:event atPoint:interactionPoint];
}

/// @}

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setAxes:(nullable CPTAxisArray *)newAxes
{
    if ( newAxes != axes ) {
        for ( CPTAxis *axis in axes ) {
            [axis removeFromSuperlayer];
            axis.plotArea = nil;
            axis.graph    = nil;
        }
        axes = newAxes;
        CPTPlotArea *plotArea = (CPTPlotArea *)self.superlayer;
        CPTGraph *theGraph    = plotArea.graph;
        for ( CPTAxis *axis in axes ) {
            [self addSublayer:axis];
            axis.plotArea = plotArea;
            axis.graph    = theGraph;
        }
        [self setNeedsLayout];
        [self setNeedsDisplay];
    }
}

-(void)setBorderLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    if ( newLineStyle != borderLineStyle ) {
        borderLineStyle = [newLineStyle copy];
        [self setNeedsLayout];
        [self setNeedsDisplay];
    }
}

/// @endcond

@end

#import "CPTPlotAreaFrame.h"

#import "CPTAxisSet.h"
#import "CPTPlotArea.h"
#import "CPTPlotGroup.h"

/// @cond
@interface CPTPlotAreaFrame()

@property (nonatomic, readwrite, strong, nullable) CPTPlotArea *plotArea;

@end

/// @endcond

#pragma mark -

/**
 *  @brief A layer drawn on top of the graph layer and behind all plot elements.
 *
 *  All graph elements, except for titles, legends, and other annotations
 *  attached directly to the graph itself are clipped to the plot area frame.
 **/
@implementation CPTPlotAreaFrame

/** @property nullable CPTPlotArea *plotArea
 *  @brief The plot area.
 **/
@synthesize plotArea;

/** @property nullable CPTAxisSet *axisSet
 *  @brief The axis set.
 **/
@dynamic axisSet;

/** @property nullable CPTPlotGroup *plotGroup
 *  @brief The plot group.
 **/
@dynamic plotGroup;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTPlotAreaFrame object with the provided frame rectangle.
 *
 *  This is the designated initializer. The initialized layer will have the following properties:
 *  - @ref plotArea = a new CPTPlotArea with the same frame rectangle
 *  - @ref masksToBorder = @YES
 *  - @ref needsDisplayOnBoundsChange = @YES
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTPlotAreaFrame object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame
{
    if ((self = [super initWithFrame:newFrame])) {
        plotArea = nil;

        CPTPlotArea *newPlotArea = [[CPTPlotArea alloc] initWithFrame:newFrame];
        self.plotArea = newPlotArea;

        self.masksToBorder              = YES;
        self.needsDisplayOnBoundsChange = YES;
    }
    return self;
}

/// @}

/// @cond

-(nonnull instancetype)initWithLayer:(nonnull id)layer
{
    if ((self = [super initWithLayer:layer])) {
        CPTPlotAreaFrame *theLayer = (CPTPlotAreaFrame *)layer;

        plotArea = theLayer->plotArea;
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

    [coder encodeObject:self.plotArea forKey:@"CPTPlotAreaFrame.plotArea"];
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        plotArea = [coder decodeObjectOfClass:[CPTPlotArea class]
                                       forKey:@"CPTPlotAreaFrame.plotArea"];
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
#pragma mark Event Handling

/// @name User Interaction
/// @{

/**
 *  @brief Informs the receiver that the user has
 *  @if MacOnly pressed the mouse button. @endif
 *  @if iOSOnly touched the screen. @endif
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceDownEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    if ( [self.plotArea pointingDeviceDownEvent:event atPoint:interactionPoint] ) {
        return YES;
    }
    else {
        return [super pointingDeviceDownEvent:event atPoint:interactionPoint];
    }
}

/**
 *  @brief Informs the receiver that the user has
 *  @if MacOnly released the mouse button. @endif
 *  @if iOSOnly lifted their finger off the screen. @endif
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceUpEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    if ( [self.plotArea pointingDeviceUpEvent:event atPoint:interactionPoint] ) {
        return YES;
    }
    else {
        return [super pointingDeviceUpEvent:event atPoint:interactionPoint];
    }
}

/**
 *  @brief Informs the receiver that the user has moved
 *  @if MacOnly the mouse with the button pressed. @endif
 *  @if iOSOnly their finger while touching the screen. @endif
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceDraggedEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    if ( [self.plotArea pointingDeviceDraggedEvent:event atPoint:interactionPoint] ) {
        return YES;
    }
    else {
        return [super pointingDeviceDraggedEvent:event atPoint:interactionPoint];
    }
}

/**
 *  @brief Informs the receiver that tracking of
 *  @if MacOnly mouse moves @endif
 *  @if iOSOnly touches @endif
 *  has been cancelled for any reason.
 *
 *  @param event The OS event.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceCancelledEvent:(nonnull CPTNativeEvent *)event
{
    if ( [self.plotArea pointingDeviceCancelledEvent:event] ) {
        return YES;
    }
    else {
        return [super pointingDeviceCancelledEvent:event];
    }
}

/// @}

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setPlotArea:(nullable CPTPlotArea *)newPlotArea
{
    if ( newPlotArea != plotArea ) {
        [plotArea removeFromSuperlayer];
        plotArea = newPlotArea;

        if ( newPlotArea ) {
            CPTPlotArea *theArea = newPlotArea;

            [self insertSublayer:theArea atIndex:0];
            theArea.graph = self.graph;
        }

        [self setNeedsLayout];
    }
}

-(nullable CPTAxisSet *)axisSet
{
    return self.plotArea.axisSet;
}

-(void)setAxisSet:(nullable CPTAxisSet *)newAxisSet
{
    self.plotArea.axisSet = newAxisSet;
}

-(nullable CPTPlotGroup *)plotGroup
{
    return self.plotArea.plotGroup;
}

-(void)setPlotGroup:(nullable CPTPlotGroup *)newPlotGroup
{
    self.plotArea.plotGroup = newPlotGroup;
}

-(void)setGraph:(nullable CPTGraph *)newGraph
{
    if ( newGraph != self.graph ) {
        super.graph = newGraph;

        self.plotArea.graph = newGraph;
    }
}

/// @endcond

@end

#import "CPTPlotArea.h"

#import "CPTAxis.h"
#import "CPTAxisLabelGroup.h"
#import "CPTAxisSet.h"
#import "CPTFill.h"
#import "CPTGridLineGroup.h"
#import "CPTLineStyle.h"
#import "CPTPlotGroup.h"
#import "CPTUtilities.h"

static const size_t kCPTNumberOfLayers = 6; // number of primary layers to arrange

/// @cond
@interface CPTPlotArea()

@property (nonatomic, readwrite, assign, nonnull) CPTGraphLayerType *bottomUpLayerOrder;
@property (nonatomic, readwrite, assign, getter = isUpdatingLayers) BOOL updatingLayers;
@property (nonatomic, readwrite) CGPoint touchedPoint;
@property (nonatomic, readwrite) NSDecimal widthDecimal;
@property (nonatomic, readwrite) NSDecimal heightDecimal;

-(void)updateLayerOrder;
-(unsigned)indexForLayerType:(CPTGraphLayerType)layerType;

@end

/// @endcond

#pragma mark -

/** @brief A layer representing the actual plotting area of a graph.
 *
 *  All plots are drawn inside this area while axes, titles, and borders may fall outside.
 *  The layers are arranged so that the graph elements are drawn in the following order:
 *  -# Background fill
 *  -# Minor grid lines
 *  -# Major grid lines
 *  -# Background border
 *  -# Axis lines with major and minor tick marks
 *  -# Plots
 *  -# Axis labels
 *  -# Axis titles
 **/
@implementation CPTPlotArea

/** @property nullable CPTGridLineGroup *minorGridLineGroup
 *  @brief The parent layer for all minor grid lines.
 **/
@synthesize minorGridLineGroup;

/** @property nullable CPTGridLineGroup *majorGridLineGroup
 *  @brief The parent layer for all major grid lines.
 **/
@synthesize majorGridLineGroup;

/** @property nullable CPTAxisSet *axisSet
 *  @brief The axis set.
 **/
@synthesize axisSet;

/** @property nullable CPTPlotGroup *plotGroup
 *  @brief The plot group.
 **/
@synthesize plotGroup;

/** @property nullable CPTAxisLabelGroup *axisLabelGroup
 *  @brief The parent layer for all axis labels.
 **/
@synthesize axisLabelGroup;

/** @property nullable CPTAxisLabelGroup *axisTitleGroup
 *  @brief The parent layer for all axis titles.
 **/
@synthesize axisTitleGroup;

/** @property nullable  CPTNumberArray *topDownLayerOrder
 *  @brief An array of graph layers to be drawn in an order other than the default.
 *
 *  The array should reference the layers using the constants defined in #CPTGraphLayerType.
 *  Layers should be specified in order starting from the top layer.
 *  Only the layers drawn out of the default order need be specified; all others will
 *  automatically be placed at the bottom of the view in their default order.
 *
 *  If this property is @nil, the layers will be drawn in the default order (bottom to top):
 *  -# Minor grid lines
 *  -# Major grid lines
 *  -# Axis lines, including the tick marks
 *  -# Plots
 *  -# Axis labels
 *  -# Axis titles
 *
 *  Example usage:
 *  @code
 *  [graph setTopDownLayerOrder:@[
 *      @(CPTGraphLayerTypePlots),
 *      @(CPTGraphLayerTypeAxisLabels),
 *      @(CPTGraphLayerTypeMajorGridLines)];
 *  @endcode
 **/
@synthesize topDownLayerOrder;

/** @property nullable CPTLineStyle *borderLineStyle
 *  @brief The line style for the layer border.
 *  If @nil, the border is not drawn.
 **/
@dynamic borderLineStyle;

/** @property nullable CPTFill *fill
 *  @brief The fill for the layer background.
 *  If @nil, the layer background is not filled.
 **/
@synthesize fill;

/** @property NSDecimal widthDecimal
 *  @brief The width of the @ref bounds as an @ref NSDecimal value.
 **/
@synthesize widthDecimal;

/** @property NSDecimal heightDecimal
 *  @brief The height of the @ref bounds as an @ref NSDecimal value.
 **/
@synthesize heightDecimal;

// Private properties
@synthesize bottomUpLayerOrder;
@synthesize updatingLayers;
@synthesize touchedPoint;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTPlotArea object with the provided frame rectangle.
 *
 *  This is the designated initializer. The initialized layer will have the following properties:
 *  - @ref minorGridLineGroup = @nil
 *  - @ref majorGridLineGroup = @nil
 *  - @ref axisSet = @nil
 *  - @ref plotGroup = @nil
 *  - @ref axisLabelGroup = @nil
 *  - @ref axisTitleGroup = @nil
 *  - @ref fill = @nil
 *  - @ref topDownLayerOrder = @nil
 *  - @ref plotGroup = a new CPTPlotGroup with the same frame rectangle
 *  - @ref needsDisplayOnBoundsChange = @YES
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTPlotArea object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame
{
    if ((self = [super initWithFrame:newFrame])) {
        minorGridLineGroup = nil;
        majorGridLineGroup = nil;
        axisSet            = nil;
        plotGroup          = nil;
        axisLabelGroup     = nil;
        axisTitleGroup     = nil;
        fill               = nil;
        touchedPoint       = CPTPointMake(NAN, NAN);
        topDownLayerOrder  = nil;
        bottomUpLayerOrder = calloc(kCPTNumberOfLayers, sizeof(CPTGraphLayerType));
        [self updateLayerOrder];

        CPTPlotGroup *newPlotGroup = [[CPTPlotGroup alloc] initWithFrame:newFrame];
        self.plotGroup = newPlotGroup;

        CGSize boundsSize = self.bounds.size;
        widthDecimal  = CPTDecimalFromCGFloat(boundsSize.width);
        heightDecimal = CPTDecimalFromCGFloat(boundsSize.height);

        self.needsDisplayOnBoundsChange = YES;
    }
    return self;
}

/// @}

/// @cond

-(nonnull instancetype)initWithLayer:(nonnull id)layer
{
    if ((self = [super initWithLayer:layer])) {
        CPTPlotArea *theLayer = (CPTPlotArea *)layer;

        minorGridLineGroup = theLayer->minorGridLineGroup;
        majorGridLineGroup = theLayer->majorGridLineGroup;
        axisSet            = theLayer->axisSet;
        plotGroup          = theLayer->plotGroup;
        axisLabelGroup     = theLayer->axisLabelGroup;
        axisTitleGroup     = theLayer->axisTitleGroup;
        fill               = theLayer->fill;
        touchedPoint       = theLayer->touchedPoint;
        topDownLayerOrder  = theLayer->topDownLayerOrder;
        bottomUpLayerOrder = calloc(kCPTNumberOfLayers, sizeof(CPTGraphLayerType));
        memcpy(bottomUpLayerOrder, theLayer->bottomUpLayerOrder, kCPTNumberOfLayers * sizeof(CPTGraphLayerType));
        widthDecimal  = theLayer->widthDecimal;
        heightDecimal = theLayer->heightDecimal;
    }
    return self;
}

-(void)dealloc
{
    free(bottomUpLayerOrder);
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeObject:self.minorGridLineGroup forKey:@"CPTPlotArea.minorGridLineGroup"];
    [coder encodeObject:self.majorGridLineGroup forKey:@"CPTPlotArea.majorGridLineGroup"];
    [coder encodeObject:self.axisSet forKey:@"CPTPlotArea.axisSet"];
    [coder encodeObject:self.plotGroup forKey:@"CPTPlotArea.plotGroup"];
    [coder encodeObject:self.axisLabelGroup forKey:@"CPTPlotArea.axisLabelGroup"];
    [coder encodeObject:self.axisTitleGroup forKey:@"CPTPlotArea.axisTitleGroup"];
    [coder encodeObject:self.fill forKey:@"CPTPlotArea.fill"];
    [coder encodeObject:self.topDownLayerOrder forKey:@"CPTPlotArea.topDownLayerOrder"];

    // No need to archive these properties:
    // bottomUpLayerOrder
    // updatingLayers
    // touchedPoint
    // widthDecimal
    // heightDecimal
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        minorGridLineGroup = [coder decodeObjectOfClass:[CPTGridLineGroup class]
                                                 forKey:@"CPTPlotArea.minorGridLineGroup"];
        majorGridLineGroup = [coder decodeObjectOfClass:[CPTGridLineGroup class]
                                                 forKey:@"CPTPlotArea.majorGridLineGroup"];
        axisSet = [coder decodeObjectOfClass:[CPTAxisSet class]
                                      forKey:@"CPTPlotArea.axisSet"];
        plotGroup = [coder decodeObjectOfClass:[CPTPlotGroup class]
                                        forKey:@"CPTPlotArea.plotGroup"];
        axisLabelGroup = [coder decodeObjectOfClass:[CPTAxisLabelGroup class]
                                             forKey:@"CPTPlotArea.axisLabelGroup"];
        axisTitleGroup = [coder decodeObjectOfClass:[CPTAxisLabelGroup class]
                                             forKey:@"CPTPlotArea.axisTitleGroup"];
        fill = [[coder decodeObjectOfClass:[CPTFill class]
                                    forKey:@"CPTPlotArea.fill"] copy];
        topDownLayerOrder = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSNumber class]]]
                                                  forKey:@"CPTPlotArea.topDownLayerOrder"];

        bottomUpLayerOrder = calloc(kCPTNumberOfLayers, sizeof(CPTGraphLayerType));
        [self updateLayerOrder];

        touchedPoint = CPTPointMake(NAN, NAN);

        CGSize boundsSize = self.bounds.size;
        widthDecimal  = CPTDecimalFromCGFloat(boundsSize.width);
        heightDecimal = CPTDecimalFromCGFloat(boundsSize.height);
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

-(void)renderAsVectorInContext:(nonnull CGContextRef)context
{
    if ( self.hidden ) {
        return;
    }

    [super renderAsVectorInContext:context];

    BOOL useMask = self.masksToBounds;
    self.masksToBounds = YES;
    CGContextSaveGState(context);

    CGPathRef maskPath = self.maskingPath;
    if ( maskPath ) {
        CGContextBeginPath(context);
        CGContextAddPath(context, maskPath);
        CGContextClip(context);
    }

    [self.fill fillRect:self.bounds inContext:context];

    CPTAxisArray *theAxes = self.axisSet.axes;

    for ( CPTAxis *axis in theAxes ) {
        [axis drawBackgroundBandsInContext:context];
    }
    for ( CPTAxis *axis in theAxes ) {
        [axis drawBackgroundLimitsInContext:context];
    }

    CGContextRestoreGState(context);
    self.masksToBounds = useMask;
}

/// @endcond

#pragma mark -
#pragma mark Layout

/// @name Layout
/// @{

/**
 *  @brief Updates the layout of all sublayers. Sublayers fill the super layer&rsquo;s bounds
 *  except for the @ref plotGroup, which will fill the receiver&rsquo;s bounds.
 *
 *  This is where we do our custom replacement for the Mac-only layout manager and autoresizing mask.
 *  Subclasses should override this method to provide a different layout of their own sublayers.
 **/
-(void)layoutSublayers
{
    [super layoutSublayers];

    CPTAxisSet *myAxisSet = self.axisSet;
    BOOL axisSetHasBorder = (myAxisSet.borderLineStyle != nil);

    CALayer *superlayer   = self.superlayer;
    CGRect sublayerBounds = [self convertRect:superlayer.bounds fromLayer:superlayer];
    sublayerBounds.origin = CGPointZero;
    CGPoint sublayerPosition = [self convertPoint:self.bounds.origin toLayer:superlayer];
    sublayerPosition = CPTPointMake(-sublayerPosition.x, -sublayerPosition.y);
    CGRect sublayerFrame = CPTRectMake(sublayerPosition.x, sublayerPosition.y, sublayerBounds.size.width, sublayerBounds.size.height);

    self.minorGridLineGroup.frame = sublayerFrame;
    self.majorGridLineGroup.frame = sublayerFrame;
    if ( axisSetHasBorder ) {
        self.axisSet.frame = sublayerFrame;
    }

    // make the plot group the same size as the plot area to clip the plots
    CPTPlotGroup *thePlotGroup = self.plotGroup;
    if ( thePlotGroup ) {
        CGSize selfBoundsSize = self.bounds.size;
        thePlotGroup.frame = CPTRectMake(0.0, 0.0, selfBoundsSize.width, selfBoundsSize.height);
    }

    // the label and title groups never have anything to draw; make them as small as possible to save memory
    sublayerFrame             = CPTRectMake(sublayerPosition.x, sublayerPosition.y, 0.0, 0.0);
    self.axisLabelGroup.frame = sublayerFrame;
    self.axisTitleGroup.frame = sublayerFrame;
    if ( !axisSetHasBorder ) {
        myAxisSet.frame = sublayerFrame;
        [myAxisSet layoutSublayers];
    }
}

/// @}

/// @cond

-(nullable CPTSublayerSet *)sublayersExcludedFromAutomaticLayout
{
    CPTGridLineGroup *minorGrid = self.minorGridLineGroup;
    CPTGridLineGroup *majorGrid = self.majorGridLineGroup;
    CPTAxisSet *theAxisSet      = self.axisSet;
    CPTPlotGroup *thePlotGroup  = self.plotGroup;
    CPTAxisLabelGroup *labels   = self.axisLabelGroup;
    CPTAxisLabelGroup *titles   = self.axisTitleGroup;

    if ( minorGrid || majorGrid || theAxisSet || thePlotGroup || labels || titles ) {
        CPTMutableSublayerSet *excludedSublayers = [super.sublayersExcludedFromAutomaticLayout mutableCopy];
        if ( !excludedSublayers ) {
            excludedSublayers = [NSMutableSet set];
        }

        if ( minorGrid ) {
            [excludedSublayers addObject:minorGrid];
        }
        if ( majorGrid ) {
            [excludedSublayers addObject:majorGrid];
        }
        if ( theAxisSet ) {
            [excludedSublayers addObject:theAxisSet];
        }
        if ( thePlotGroup ) {
            [excludedSublayers addObject:thePlotGroup];
        }
        if ( labels ) {
            [excludedSublayers addObject:labels];
        }
        if ( titles ) {
            [excludedSublayers addObject:titles];
        }

        return excludedSublayers;
    }
    else {
        return super.sublayersExcludedFromAutomaticLayout;
    }
}

/// @endcond

#pragma mark -
#pragma mark Layer ordering

/// @cond

-(void)updateLayerOrder
{
    CPTGraphLayerType *buLayerOrder = self.bottomUpLayerOrder;

    for ( size_t i = 0; i < kCPTNumberOfLayers; i++ ) {
        *(buLayerOrder++) = (CPTGraphLayerType)i;
    }

    CPTNumberArray *tdLayerOrder = self.topDownLayerOrder;
    if ( tdLayerOrder ) {
        buLayerOrder = self.bottomUpLayerOrder;

        for ( NSUInteger layerIndex = 0; layerIndex < tdLayerOrder.count; layerIndex++ ) {
            CPTGraphLayerType layerType = (CPTGraphLayerType)tdLayerOrder[layerIndex].intValue;
            NSUInteger i                = kCPTNumberOfLayers - layerIndex - 1;
            while ( buLayerOrder[i] != layerType ) {
                if ( i == 0 ) {
                    break;
                }
                i--;
            }
            while ( i < kCPTNumberOfLayers - layerIndex - 1 ) {
                buLayerOrder[i] = buLayerOrder[i + 1];
                i++;
            }
            buLayerOrder[kCPTNumberOfLayers - layerIndex - 1] = layerType;
        }
    }

    // force the layer hierarchy to update
    self.updatingLayers     = YES;
    self.minorGridLineGroup = self.minorGridLineGroup;
    self.majorGridLineGroup = self.majorGridLineGroup;
    self.axisSet            = self.axisSet;
    self.plotGroup          = self.plotGroup;
    self.axisLabelGroup     = self.axisLabelGroup;
    self.axisTitleGroup     = self.axisTitleGroup;
    self.updatingLayers     = NO;
}

-(unsigned)indexForLayerType:(CPTGraphLayerType)layerType
{
    CPTGraphLayerType *buLayerOrder = self.bottomUpLayerOrder;
    unsigned idx                    = 0;

    for ( size_t i = 0; i < kCPTNumberOfLayers; i++ ) {
        if ( buLayerOrder[i] == layerType ) {
            break;
        }
        switch ( buLayerOrder[i] ) {
            case CPTGraphLayerTypeMinorGridLines:
                if ( self.minorGridLineGroup ) {
                    idx++;
                }
                break;

            case CPTGraphLayerTypeMajorGridLines:
                if ( self.majorGridLineGroup ) {
                    idx++;
                }
                break;

            case CPTGraphLayerTypeAxisLines:
                if ( self.axisSet ) {
                    idx++;
                }
                break;

            case CPTGraphLayerTypePlots:
                if ( self.plotGroup ) {
                    idx++;
                }
                break;

            case CPTGraphLayerTypeAxisLabels:
                if ( self.axisLabelGroup ) {
                    idx++;
                }
                break;

            case CPTGraphLayerTypeAxisTitles:
                if ( self.axisTitleGroup ) {
                    idx++;
                }
                break;
        }
    }
    return idx;
}

/// @endcond

#pragma mark -
#pragma mark Axis set layer management

/** @brief Checks for the presence of the specified layer group and adds or removes it as needed.
 *  @param layerType The layer type being updated.
 **/
-(void)updateAxisSetLayersForType:(CPTGraphLayerType)layerType
{
    BOOL needsLayer        = NO;
    CPTAxisSet *theAxisSet = self.axisSet;

    for ( CPTAxis *axis in theAxisSet.axes ) {
        switch ( layerType ) {
            case CPTGraphLayerTypeMinorGridLines:
                if ( axis.minorGridLineStyle ) {
                    needsLayer = YES;
                }
                break;

            case CPTGraphLayerTypeMajorGridLines:
                if ( axis.majorGridLineStyle ) {
                    needsLayer = YES;
                }
                break;

            case CPTGraphLayerTypeAxisLabels:
                if ( axis.axisLabels.count > 0 ) {
                    needsLayer = YES;
                }
                break;

            case CPTGraphLayerTypeAxisTitles:
                if ( axis.axisTitle ) {
                    needsLayer = YES;
                }
                break;

            default:
                break;
        }
    }

    if ( needsLayer ) {
        [self setAxisSetLayersForType:layerType];
    }
    else {
        switch ( layerType ) {
            case CPTGraphLayerTypeMinorGridLines:
                self.minorGridLineGroup = nil;
                break;

            case CPTGraphLayerTypeMajorGridLines:
                self.majorGridLineGroup = nil;
                break;

            case CPTGraphLayerTypeAxisLabels:
                self.axisLabelGroup = nil;
                break;

            case CPTGraphLayerTypeAxisTitles:
                self.axisTitleGroup = nil;
                break;

            default:
                break;
        }
    }
}

/** @brief Ensures that a group layer is set for the given layer type.
 *  @param layerType The layer type being updated.
 **/
-(void)setAxisSetLayersForType:(CPTGraphLayerType)layerType
{
    switch ( layerType ) {
        case CPTGraphLayerTypeMinorGridLines:
            if ( !self.minorGridLineGroup ) {
                CPTGridLineGroup *newGridLineGroup = [[CPTGridLineGroup alloc] initWithFrame:self.bounds];
                self.minorGridLineGroup = newGridLineGroup;
            }
            break;

        case CPTGraphLayerTypeMajorGridLines:
            if ( !self.majorGridLineGroup ) {
                CPTGridLineGroup *newGridLineGroup = [[CPTGridLineGroup alloc] initWithFrame:self.bounds];
                self.majorGridLineGroup = newGridLineGroup;
            }
            break;

        case CPTGraphLayerTypeAxisLabels:
            if ( !self.axisLabelGroup ) {
                CPTAxisLabelGroup *newAxisLabelGroup = [[CPTAxisLabelGroup alloc] initWithFrame:self.bounds];
                self.axisLabelGroup = newAxisLabelGroup;
            }
            break;

        case CPTGraphLayerTypeAxisTitles:
            if ( !self.axisTitleGroup ) {
                CPTAxisLabelGroup *newAxisTitleGroup = [[CPTAxisLabelGroup alloc] initWithFrame:self.bounds];
                self.axisTitleGroup = newAxisTitleGroup;
            }
            break;

        default:
            break;
    }
}

/** @brief Computes the sublayer index for the given layer type and axis.
 *  @param axis The axis of interest.
 *  @param layerType The layer type being updated.
 *  @return The sublayer index for the given layer type.
 **/
-(unsigned)sublayerIndexForAxis:(nonnull CPTAxis *)axis layerType:(CPTGraphLayerType)layerType
{
    unsigned idx = 0;

    for ( CPTAxis *currentAxis in self.axisSet.axes ) {
        if ( currentAxis == axis ) {
            break;
        }

        switch ( layerType ) {
            case CPTGraphLayerTypeMinorGridLines:
                if ( currentAxis.minorGridLineStyle ) {
                    idx++;
                }
                break;

            case CPTGraphLayerTypeMajorGridLines:
                if ( currentAxis.majorGridLineStyle ) {
                    idx++;
                }
                break;

            case CPTGraphLayerTypeAxisLabels:
                if ( currentAxis.axisLabels.count > 0 ) {
                    idx++;
                }
                break;

            case CPTGraphLayerTypeAxisTitles:
                if ( currentAxis.axisTitle ) {
                    idx++;
                }
                break;

            default:
                break;
        }
    }

    return idx;
}

#pragma mark -
#pragma mark Event Handling

/// @name User Interaction
/// @{

/**
 *  @brief Informs the receiver that the user has
 *  @if MacOnly pressed the mouse button. @endif
 *  @if iOSOnly touched the screen. @endif
 *
 *
 *  If this plot area has a delegate that responds to the
 *  @link CPTPlotAreaDelegate::plotAreaTouchDown: -plotAreaTouchDown: @endlink and/or
 *  @link CPTPlotAreaDelegate::plotAreaTouchDown:withEvent: -plotAreaTouchDown:withEvent: @endlink
 *  methods, the delegate method will be called and this method returns @YES if the @par{interactionPoint} is within the
 *  plot area bounds.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceDownEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    CPTGraph *theGraph = self.graph;

    if ( !theGraph || self.hidden ) {
        return NO;
    }

    id<CPTPlotAreaDelegate> theDelegate = (id<CPTPlotAreaDelegate>)self.delegate;
    if ( [theDelegate respondsToSelector:@selector(plotAreaTouchDown:)] ||
         [theDelegate respondsToSelector:@selector(plotAreaTouchDown:withEvent:)] ||
         [theDelegate respondsToSelector:@selector(plotAreaWasSelected:)] ||
         [theDelegate respondsToSelector:@selector(plotAreaWasSelected:withEvent:)] ) {
        // Inform delegate if a point was hit
        CGPoint plotAreaPoint = [theGraph convertPoint:interactionPoint toLayer:self];

        if ( CGRectContainsPoint(self.bounds, plotAreaPoint)) {
            self.touchedPoint = plotAreaPoint;

            if ( [theDelegate respondsToSelector:@selector(plotAreaTouchDown:)] ) {
                [theDelegate plotAreaTouchDown:self];
            }
            if ( [theDelegate respondsToSelector:@selector(plotAreaTouchDown:withEvent:)] ) {
                [theDelegate plotAreaTouchDown:self withEvent:event];
            }

            return NO; // don't block other events in the responder chain
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
 *  If this plot area has a delegate that responds to the
 *  @link CPTPlotAreaDelegate::plotAreaTouchUp: -plotAreaTouchUp: @endlink,
 *  @link CPTPlotAreaDelegate::plotAreaTouchUp:withEvent: -plotAreaTouchUp:withEvent: @endlink,
 *  @link CPTPlotAreaDelegate::plotAreaWasSelected: -plotAreaWasSelected: @endlink, and/or
 *  @link CPTPlotAreaDelegate::plotAreaWasSelected:withEvent: -plotAreaWasSelected:withEvent: @endlink
 *  methods, the delegate method will be called and this method returns @YES if the @par{interactionPoint} is within the
 *  plot area bounds.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceUpEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    CPTGraph *theGraph = self.graph;

    if ( !theGraph || self.hidden ) {
        return NO;
    }

    CGPoint lastPoint = self.touchedPoint;
    self.touchedPoint = CPTPointMake(NAN, NAN);

    id<CPTPlotAreaDelegate> theDelegate = (id<CPTPlotAreaDelegate>)self.delegate;
    if ( [theDelegate respondsToSelector:@selector(plotAreaTouchUp:)] ||
         [theDelegate respondsToSelector:@selector(plotAreaTouchUp:withEvent:)] ||
         [theDelegate respondsToSelector:@selector(plotAreaWasSelected:)] ||
         [theDelegate respondsToSelector:@selector(plotAreaWasSelected:withEvent:)] ) {
        // Inform delegate if a point was hit
        CGPoint plotAreaPoint = [theGraph convertPoint:interactionPoint toLayer:self];

        if ( CGRectContainsPoint(self.bounds, plotAreaPoint)) {
            CGVector offset = CGVectorMake(plotAreaPoint.x - lastPoint.x, plotAreaPoint.y - lastPoint.y);
            if ((offset.dx * offset.dx + offset.dy * offset.dy) <= CPTFloat(25.0)) {
                if ( [theDelegate respondsToSelector:@selector(plotAreaTouchUp:)] ) {
                    [theDelegate plotAreaTouchUp:self];
                }

                if ( [theDelegate respondsToSelector:@selector(plotAreaTouchUp:withEvent:)] ) {
                    [theDelegate plotAreaTouchUp:self withEvent:event];
                }

                if ( [theDelegate respondsToSelector:@selector(plotAreaWasSelected:)] ) {
                    [theDelegate plotAreaWasSelected:self];
                }

                if ( [theDelegate respondsToSelector:@selector(plotAreaWasSelected:withEvent:)] ) {
                    [theDelegate plotAreaWasSelected:self withEvent:event];
                }

                return NO; // don't block other events in the responder chain
            }
        }
    }

    return [super pointingDeviceUpEvent:event atPoint:interactionPoint];
}

/// @}

#pragma mark -
#pragma mark Accessors

/// @cond

-(nullable CPTLineStyle *)borderLineStyle
{
    return self.axisSet.borderLineStyle;
}

-(void)setBorderLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    self.axisSet.borderLineStyle = newLineStyle;
}

-(void)setFill:(nullable CPTFill *)newFill
{
    if ( newFill != fill ) {
        fill = [newFill copy];
        [self setNeedsDisplay];
    }
}

-(void)setMinorGridLineGroup:(nullable CPTGridLineGroup *)newGridLines
{
    if ((newGridLines != minorGridLineGroup) || self.isUpdatingLayers ) {
        [minorGridLineGroup removeFromSuperlayer];
        minorGridLineGroup = newGridLines;
        if ( newGridLines ) {
            CPTGridLineGroup *gridLines = newGridLines;

            gridLines.plotArea = self;
            gridLines.major    = NO;
            [self insertSublayer:gridLines atIndex:[self indexForLayerType:CPTGraphLayerTypeMinorGridLines]];
        }
        [self setNeedsLayout];
    }
}

-(void)setMajorGridLineGroup:(nullable CPTGridLineGroup *)newGridLines
{
    if ((newGridLines != majorGridLineGroup) || self.isUpdatingLayers ) {
        [majorGridLineGroup removeFromSuperlayer];
        majorGridLineGroup = newGridLines;
        if ( newGridLines ) {
            CPTGridLineGroup *gridLines = newGridLines;

            gridLines.plotArea = self;
            gridLines.major    = YES;
            [self insertSublayer:gridLines atIndex:[self indexForLayerType:CPTGraphLayerTypeMajorGridLines]];
        }
        [self setNeedsLayout];
    }
}

-(void)setAxisSet:(nullable CPTAxisSet *)newAxisSet
{
    if ((newAxisSet != axisSet) || self.isUpdatingLayers ) {
        [axisSet removeFromSuperlayer];
        for ( CPTAxis *axis in axisSet.axes ) {
            axis.plotArea = nil;
        }

        axisSet = newAxisSet;
        [self updateAxisSetLayersForType:CPTGraphLayerTypeMajorGridLines];
        [self updateAxisSetLayersForType:CPTGraphLayerTypeMinorGridLines];
        [self updateAxisSetLayersForType:CPTGraphLayerTypeAxisLabels];
        [self updateAxisSetLayersForType:CPTGraphLayerTypeAxisTitles];

        if ( newAxisSet ) {
            CPTGraph *theGraph     = self.graph;
            CPTAxisSet *theAxisSet = newAxisSet;

            [self insertSublayer:theAxisSet atIndex:[self indexForLayerType:CPTGraphLayerTypeAxisLines]];
            for ( CPTAxis *axis in theAxisSet.axes ) {
                axis.plotArea = self;
                axis.graph    = theGraph;
            }
        }
        [self setNeedsLayout];
    }
}

-(void)setPlotGroup:(nullable CPTPlotGroup *)newPlotGroup
{
    if ((newPlotGroup != plotGroup) || self.isUpdatingLayers ) {
        [plotGroup removeFromSuperlayer];
        plotGroup = newPlotGroup;
        if ( newPlotGroup ) {
            CPTPlotGroup *group = newPlotGroup;

            [self insertSublayer:group atIndex:[self indexForLayerType:CPTGraphLayerTypePlots]];
        }
        [self setNeedsLayout];
    }
}

-(void)setAxisLabelGroup:(nullable CPTAxisLabelGroup *)newAxisLabelGroup
{
    if ((newAxisLabelGroup != axisLabelGroup) || self.isUpdatingLayers ) {
        [axisLabelGroup removeFromSuperlayer];
        axisLabelGroup = newAxisLabelGroup;
        if ( newAxisLabelGroup ) {
            CPTAxisLabelGroup *group = newAxisLabelGroup;

            [self insertSublayer:group atIndex:[self indexForLayerType:CPTGraphLayerTypeAxisLabels]];
        }
        [self setNeedsLayout];
    }
}

-(void)setAxisTitleGroup:(nullable CPTAxisLabelGroup *)newAxisTitleGroup
{
    if ((newAxisTitleGroup != axisTitleGroup) || self.isUpdatingLayers ) {
        [axisTitleGroup removeFromSuperlayer];
        axisTitleGroup = newAxisTitleGroup;
        if ( newAxisTitleGroup ) {
            CPTAxisLabelGroup *group = newAxisTitleGroup;

            [self insertSublayer:group atIndex:[self indexForLayerType:CPTGraphLayerTypeAxisTitles]];
        }
        [self setNeedsLayout];
    }
}

-(void)setTopDownLayerOrder:(nullable CPTNumberArray *)newArray
{
    if ( newArray != topDownLayerOrder ) {
        topDownLayerOrder = newArray;
        [self updateLayerOrder];
    }
}

-(void)setGraph:(nullable CPTGraph *)newGraph
{
    if ( newGraph != self.graph ) {
        super.graph = newGraph;

        for ( CPTAxis *axis in self.axisSet.axes ) {
            axis.graph = newGraph;
        }
    }
}

-(void)setBounds:(CGRect)newBounds
{
    if ( !CGRectEqualToRect(self.bounds, newBounds)) {
        self.widthDecimal  = CPTDecimalFromCGFloat(newBounds.size.width);
        self.heightDecimal = CPTDecimalFromCGFloat(newBounds.size.height);

        super.bounds = newBounds;
    }
}

/// @endcond

@end

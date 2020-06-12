#import "CPTXYAxisSet.h"

#import "CPTLineStyle.h"
#import "CPTPathExtensions.h"
#import "CPTUtilities.h"
#import "CPTXYAxis.h"

/**
 *  @brief A set of cartesian (X-Y) axes.
 **/
@implementation CPTXYAxisSet

/** @property nullable CPTXYAxis *xAxis
 *  @brief The x-axis.
 **/
@dynamic xAxis;

/** @property nullable CPTXYAxis *yAxis
 *  @brief The y-axis.
 **/
@dynamic yAxis;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTXYAxisSet object with the provided frame rectangle.
 *
 *  This is the designated initializer. The @ref axes array
 *  will contain two new axes with the following properties:
 *
 *  <table>
 *  <tr><td>@bold{Axis}</td><td>@link CPTAxis::coordinate coordinate @endlink</td><td>@link CPTAxis::tickDirection tickDirection @endlink</td></tr>
 *  <tr><td>@ref xAxis</td><td>#CPTCoordinateX</td><td>#CPTSignNegative</td></tr>
 *  <tr><td>@ref yAxis</td><td>#CPTCoordinateY</td><td>#CPTSignNegative</td></tr>
 *  </table>
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTXYAxisSet object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame
{
    if ((self = [super initWithFrame:newFrame])) {
        CPTXYAxis *xAxis = [[CPTXYAxis alloc] initWithFrame:newFrame];
        xAxis.coordinate    = CPTCoordinateX;
        xAxis.tickDirection = CPTSignNegative;

        CPTXYAxis *yAxis = [[CPTXYAxis alloc] initWithFrame:newFrame];
        yAxis.coordinate    = CPTCoordinateY;
        yAxis.tickDirection = CPTSignNegative;

        self.axes = @[xAxis, yAxis];
    }
    return self;
}

/// @}

#pragma mark -
#pragma mark Drawing

/// @cond

-(void)renderAsVectorInContext:(nonnull CGContextRef)context
{
    if ( self.hidden ) {
        return;
    }

    CPTLineStyle *theLineStyle = self.borderLineStyle;
    if ( theLineStyle ) {
        [super renderAsVectorInContext:context];

        CALayer *superlayer = self.superlayer;
        CGRect borderRect   = CPTAlignRectToUserSpace(context, [self convertRect:superlayer.bounds fromLayer:superlayer]);

        [theLineStyle setLineStyleInContext:context];

        CGFloat radius = superlayer.cornerRadius;

        if ( radius > CPTFloat(0.0)) {
            CGContextBeginPath(context);
            CPTAddRoundedRectPath(context, borderRect, radius);

            [theLineStyle strokePathInContext:context];
        }
        else {
            [theLineStyle strokeRect:borderRect inContext:context];
        }
    }
}

/// @endcond

#pragma mark -
#pragma mark Layout

/// @name Layout
/// @{

/**
 *  @brief Updates the layout of all sublayers. Sublayers (the axes) fill the plot area frame&rsquo;s bounds.
 *
 *  This is where we do our custom replacement for the Mac-only layout manager and autoresizing mask.
 *  Subclasses should override this method to provide a different layout of their own sublayers.
 **/
-(void)layoutSublayers
{
    // If we have a border, the default layout will work. Otherwise, the axis set layer has zero size
    // and we need to calculate the correct size for the axis layers.
    if ( self.borderLineStyle ) {
        [super layoutSublayers];
    }
    else {
        CALayer *plotAreaFrame = self.superlayer.superlayer;
        CGRect sublayerBounds  = [self convertRect:plotAreaFrame.bounds fromLayer:plotAreaFrame];
        sublayerBounds.origin = CGPointZero;
        CGPoint sublayerPosition = [self convertPoint:self.bounds.origin toLayer:plotAreaFrame];
        sublayerPosition = CGPointMake(-sublayerPosition.x, -sublayerPosition.y);
        CGRect subLayerFrame = CGRectMake(sublayerPosition.x, sublayerPosition.y, sublayerBounds.size.width, sublayerBounds.size.height);

        CPTSublayerSet *excludedSublayers = self.sublayersExcludedFromAutomaticLayout;
        Class layerClass                  = [CPTLayer class];
        for ( CALayer *subLayer in self.sublayers ) {
            if ( [subLayer isKindOfClass:layerClass] && ![excludedSublayers containsObject:subLayer] ) {
                subLayer.frame = subLayerFrame;
            }
        }
    }
}

/// @}

#pragma mark -
#pragma mark Accessors

/// @cond

-(nullable CPTXYAxis *)xAxis
{
    return (CPTXYAxis *)[self axisForCoordinate:CPTCoordinateX atIndex:0];
}

-(nullable CPTXYAxis *)yAxis
{
    return (CPTXYAxis *)[self axisForCoordinate:CPTCoordinateY atIndex:0];
}

/// @endcond

@end

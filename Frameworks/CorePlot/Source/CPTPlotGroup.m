#import "CPTPlotGroup.h"

#import "CPTPlot.h"

/**
 *  @brief Defines the coordinate system of a plot.
 **/
@implementation CPTPlotGroup

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        // support old archives
        if ( [coder containsValueForKey:@"CPTPlotGroup.identifier"] ) {
            self.identifier = [coder decodeObjectOfClass:[NSObject class]
                                                  forKey:@"CPTPlotGroup.identifier"];
        }
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
#pragma mark Organizing Plots

/** @brief Add a plot to this plot group.
 *  @param plot The plot.
 **/
-(void)addPlot:(nonnull CPTPlot *)plot
{
    NSParameterAssert(plot);

    [self addSublayer:plot];
}

/** @brief Add a plot to this plot group at the given index.
 *  @param plot The plot.
 *  @param idx The index at which to insert the plot. This value must not be greater than the count of elements in the sublayer array.
 **/
-(void)insertPlot:(nonnull CPTPlot *)plot atIndex:(NSUInteger)idx
{
    NSParameterAssert(plot);
    NSParameterAssert(idx <= [[self sublayers] count]);

    [self insertSublayer:plot atIndex:(unsigned)idx];
}

/** @brief Remove a plot from this plot group.
 *  @param plot The plot to remove.
 **/
-(void)removePlot:(nullable CPTPlot *)plot
{
    if ( self == plot.superlayer ) {
        [plot removeFromSuperlayer];
    }
}

#pragma mark -
#pragma mark Drawing

/// @cond

-(void)display
{
    // nothing to draw
}

-(void)renderAsVectorInContext:(nonnull CGContextRef __unused)context
{
    // nothing to draw
}

/// @endcond

@end

#import "CPTGridLineGroup.h"

#import "CPTAxis.h"
#import "CPTAxisSet.h"
#import "CPTPlotArea.h"

/** @brief A group of grid line layers.
 *
 *  When using separate axis layers, this layer serves as the common superlayer for the grid line layers.
 *  Otherwise, this layer handles the drawing for the grid lines. It supports mixing the two modes;
 *  some axes can use separate grid line layers while others are handled by the grid line group.
 **/
@implementation CPTGridLineGroup

/** @property nullable CPTPlotArea *plotArea
 *  @brief The plot area that this grid line group belongs to.
 **/
@synthesize plotArea;

/** @property BOOL major
 *  @brief If @YES, draw the major grid lines, else draw the minor grid lines.
 **/
@synthesize major;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTGridLineGroup object with the provided frame rectangle.
 *
 *  This is the designated initializer. The initialized layer will have the following properties:
 *  - @ref plotArea = @nil
 *  - @ref major = @NO
 *  - @ref needsDisplayOnBoundsChange = @YES
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTGridLineGroup object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame
{
    if ((self = [super initWithFrame:newFrame])) {
        plotArea = nil;
        major    = NO;

        self.needsDisplayOnBoundsChange = YES;
    }
    return self;
}

/// @}

/// @cond

-(nonnull instancetype)initWithLayer:(nonnull id)layer
{
    if ((self = [super initWithLayer:layer])) {
        CPTGridLineGroup *theLayer = (CPTGridLineGroup *)layer;

        plotArea = theLayer->plotArea;
        major    = theLayer->major;
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

    [coder encodeConditionalObject:self.plotArea forKey:@"CPTGridLineGroup.plotArea"];
    [coder encodeBool:self.major forKey:@"CPTGridLineGroup.major"];
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        plotArea = [coder decodeObjectOfClass:[CPTPlotArea class]
                                       forKey:@"CPTGridLineGroup.plotArea"];
        major = [coder decodeBoolForKey:@"CPTGridLineGroup.major"];
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

    CPTPlotArea *thePlotArea = self.plotArea;
    for ( CPTAxis *axis in thePlotArea.axisSet.axes ) {
        if ( !axis.separateLayers ) {
            [axis drawGridLinesInContext:context isMajor:self.major];
        }
    }
}

/// @endcond

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setPlotArea:(nullable CPTPlotArea *)newPlotArea
{
    if ( newPlotArea != plotArea ) {
        plotArea = newPlotArea;

        if ( newPlotArea ) {
            [self setNeedsDisplay];
        }
    }
}

/// @endcond

@end

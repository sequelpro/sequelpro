#import "CPTXYGraph.h"

#import "CPTXYAxis.h"
#import "CPTXYAxisSet.h"
#import "CPTXYPlotSpace.h"

/// @cond
@interface CPTXYGraph()

@property (nonatomic, readwrite, assign) CPTScaleType xScaleType;
@property (nonatomic, readwrite, assign) CPTScaleType yScaleType;

@end

/// @endcond

#pragma mark -

/**
 *  @brief A graph using a cartesian (X-Y) plot space.
 **/
@implementation CPTXYGraph

/** @internal
 *  @property CPTScaleType xScaleType
 *  @brief The scale type for the x-axis.
 **/
@synthesize xScaleType;

/** @internal
 *  @property CPTScaleType yScaleType
 *  @brief The scale type for the y-axis.
 **/
@synthesize yScaleType;

#pragma mark -
#pragma mark Init/Dealloc

/** @brief Initializes a newly allocated CPTXYGraph object with the provided frame rectangle and scale types.
 *
 *  This is the designated initializer.
 *
 *  @param newFrame The frame rectangle.
 *  @param newXScaleType The scale type for the x-axis.
 *  @param newYScaleType The scale type for the y-axis.
 *  @return The initialized CPTXYGraph object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame xScaleType:(CPTScaleType)newXScaleType yScaleType:(CPTScaleType)newYScaleType
{
    if ((self = [super initWithFrame:newFrame])) {
        xScaleType = newXScaleType;
        yScaleType = newYScaleType;
    }
    return self;
}

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTXYGraph object with the provided frame rectangle.
 *
 *  The initialized layer will have the following properties:
 *  - @link CPTXYPlotSpace::xScaleType xScaleType @endlink = #CPTScaleTypeLinear
 *  - @link CPTXYPlotSpace::yScaleType yScaleType @endlink = #CPTScaleTypeLinear
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTXYGraph object.
 *  @see @link CPTXYGraph::initWithFrame:xScaleType:yScaleType: -initWithFrame:xScaleType:yScaleType: @endlink
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame
{
    return [self initWithFrame:newFrame xScaleType:CPTScaleTypeLinear yScaleType:CPTScaleTypeLinear];
}

/// @}

/// @cond

-(nonnull instancetype)initWithLayer:(nonnull id)layer
{
    if ((self = [super initWithLayer:layer])) {
        CPTXYGraph *theLayer = (CPTXYGraph *)layer;

        xScaleType = theLayer->xScaleType;
        yScaleType = theLayer->yScaleType;
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

    [coder encodeInteger:self.xScaleType forKey:@"CPTXYGraph.xScaleType"];
    [coder encodeInteger:self.yScaleType forKey:@"CPTXYGraph.yScaleType"];
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        xScaleType = (CPTScaleType)[coder decodeIntegerForKey:@"CPTXYGraph.xScaleType"];
        yScaleType = (CPTScaleType)[coder decodeIntegerForKey:@"CPTXYGraph.yScaleType"];
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
#pragma mark Factory Methods

/// @cond

-(nullable CPTPlotSpace *)newPlotSpace
{
    CPTXYPlotSpace *space = [[CPTXYPlotSpace alloc] init];

    space.xScaleType = self.xScaleType;
    space.yScaleType = self.yScaleType;
    return space;
}

-(nullable CPTAxisSet *)newAxisSet
{
    CPTXYAxisSet *newAxisSet = [[CPTXYAxisSet alloc] initWithFrame:self.bounds];

    newAxisSet.xAxis.plotSpace = self.defaultPlotSpace;
    newAxisSet.yAxis.plotSpace = self.defaultPlotSpace;
    return newAxisSet;
}

/// @endcond

@end

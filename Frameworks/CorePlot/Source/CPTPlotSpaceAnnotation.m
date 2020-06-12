#import "CPTPlotSpaceAnnotation.h"

#import "CPTExceptions.h"
#import "CPTPlotArea.h"
#import "CPTPlotAreaFrame.h"
#import "CPTPlotSpace.h"

/// @cond

@interface CPTPlotSpaceAnnotation()

@property (nonatomic, readwrite, nonnull) NSDecimal *decimalAnchor;
@property (nonatomic, readwrite) NSUInteger anchorCount;

-(void)setContentNeedsLayout;

@end

/// @endcond

#pragma mark -

/** @brief Positions a content layer relative to some anchor point in a plot space.
 *
 *  Plot space annotations are positioned relative to a plot space. This allows the
 *  annotation content layer to move with the plot when the plot space changes.
 *  This is useful for applications such as labels attached to specific data points on a plot.
 **/
@implementation CPTPlotSpaceAnnotation

/** @property nullable CPTNumberArray *anchorPlotPoint
 *  @brief An array of NSDecimalNumber objects giving the anchor plot coordinates.
 **/
@synthesize anchorPlotPoint;

/** @property nonnull CPTPlotSpace *plotSpace
 *  @brief The plot space which the anchor is defined in.
 **/
@synthesize plotSpace;

@synthesize decimalAnchor;
@synthesize anchorCount;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTPlotSpaceAnnotation object.
 *
 *  This is the designated initializer. The initialized layer will be anchored to
 *  a point in plot coordinates.
 *
 *  @param newPlotSpace The plot space which the anchor is defined in. Must be non-@nil.
 *  @param newPlotPoint An array of NSDecimalNumber objects giving the anchor plot coordinates.
 *  @return The initialized CPTPlotSpaceAnnotation object.
 **/
-(nonnull instancetype)initWithPlotSpace:(nonnull CPTPlotSpace *)newPlotSpace anchorPlotPoint:(nullable CPTNumberArray *)newPlotPoint
{
    NSParameterAssert(newPlotSpace);

    if ((self = [super init])) {
        plotSpace            = newPlotSpace;
        self.anchorPlotPoint = newPlotPoint;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(setContentNeedsLayout)
                                                     name:CPTPlotSpaceCoordinateMappingDidChangeNotification
                                                   object:plotSpace];
    }
    return self;
}

/// @}

/// @cond

// plotSpace is required
-(nonnull instancetype)init
{
    [NSException raise:CPTException format:@"%@ must be initialized with a plot space.", NSStringFromClass([self class])];
    return [self initWithPlotSpace:[[CPTPlotSpace alloc] init] anchorPlotPoint:nil];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    free(decimalAnchor);
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeObject:self.anchorPlotPoint forKey:@"CPTPlotSpaceAnnotation.anchorPlotPoint"];
    [coder encodeConditionalObject:self.plotSpace forKey:@"CPTPlotSpaceAnnotation.plotSpace"];
}

/// @endcond

/** @brief Returns an object initialized from data in a given unarchiver.
 *  @param coder An unarchiver object.
 *  @return An object initialized from data in a given unarchiver.
 */
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        self.anchorPlotPoint = [[coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSNumber class]]]
                                                      forKey:@"CPTPlotSpaceAnnotation.anchorPlotPoint"] copy];

        CPTPlotSpace *thePlotSpace = [coder decodeObjectOfClass:[CPTPlotSpace class]
                                                         forKey:@"CPTPlotSpaceAnnotation.plotSpace"];
        if ( thePlotSpace ) {
            plotSpace = thePlotSpace;

            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(setContentNeedsLayout)
                                                         name:CPTPlotSpaceCoordinateMappingDidChangeNotification
                                                       object:plotSpace];
        }
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

/// @cond

-(void)setContentNeedsLayout
{
    [self.contentLayer.superlayer setNeedsLayout];
}

-(void)positionContentLayer
{
    CPTLayer *content = self.contentLayer;

    if ( content ) {
        CPTLayer *hostLayer = self.annotationHostLayer;
        if ( hostLayer ) {
            CPTNumberArray *plotAnchor = self.anchorPlotPoint;
            if ( plotAnchor ) {
                // Get plot area point
                CPTPlotSpace *thePlotSpace      = self.plotSpace;
                CGPoint plotAreaViewAnchorPoint = [thePlotSpace plotAreaViewPointForPlotPoint:self.decimalAnchor numberOfCoordinates:self.anchorCount];

                CGPoint newPosition;
                CPTGraph *theGraph    = thePlotSpace.graph;
                CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;
                if ( plotArea ) {
                    newPosition = [plotArea convertPoint:plotAreaViewAnchorPoint toLayer:hostLayer];
                }
                else {
                    newPosition = CGPointZero;
                }
                CGPoint offset = self.displacement;
                newPosition.x += offset.x;
                newPosition.y += offset.y;

                content.anchorPoint = self.contentAnchorPoint;
                content.position    = newPosition;
                content.transform   = CATransform3DMakeRotation(self.rotation, CPTFloat(0.0), CPTFloat(0.0), CPTFloat(1.0));
                [content pixelAlign];
            }
        }
    }
}

/// @endcond

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setAnchorPlotPoint:(nullable CPTNumberArray *)newPlotPoint
{
    if ( anchorPlotPoint != newPlotPoint ) {
        anchorPlotPoint = [newPlotPoint copy];

        self.anchorCount = anchorPlotPoint.count;

        NSDecimal *decimalPoint = calloc(self.anchorCount, sizeof(NSDecimal));
        for ( NSUInteger i = 0; i < self.anchorCount; i++ ) {
            decimalPoint[i] = anchorPlotPoint[i].decimalValue;
        }
        self.decimalAnchor = decimalPoint;

        [self setContentNeedsLayout];
    }
}

-(void)setDecimalAnchor:(nonnull NSDecimal *)newAnchor
{
    if ( decimalAnchor != newAnchor ) {
        free(decimalAnchor);
        decimalAnchor = newAnchor;
    }
}

/// @endcond

@end

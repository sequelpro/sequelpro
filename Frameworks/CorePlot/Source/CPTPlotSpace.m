#import "CPTPlotSpace.h"

#import "CPTGraph.h"
#import "CPTMutablePlotRange.h"
#import "CPTUtilities.h"

CPTPlotSpaceCoordinateMapping const CPTPlotSpaceCoordinateMappingDidChangeNotification = @"CPTPlotSpaceCoordinateMappingDidChangeNotification";

CPTPlotSpaceInfoKey const CPTPlotSpaceCoordinateKey   = @"CPTPlotSpaceCoordinateKey";
CPTPlotSpaceInfoKey const CPTPlotSpaceScrollingKey    = @"CPTPlotSpaceScrollingKey";
CPTPlotSpaceInfoKey const CPTPlotSpaceDisplacementKey = @"CPTPlotSpaceDisplacementKey";

/// @cond

typedef NSMutableOrderedSet<NSString *> CPTMutableCategorySet;

@interface CPTPlotSpace()

@property (nonatomic, readwrite, strong, nullable) NSMutableDictionary<NSNumber *, CPTMutableCategorySet *> *categoryNames;

@property (nonatomic, readwrite) BOOL isDragging;

-(nonnull CPTMutableCategorySet *)orderedSetForCoordinate:(CPTCoordinate)coordinate;

@end

/// @endcond

#pragma mark -

/**
 *  @brief Defines the coordinate system of a plot.
 *
 *  A plot space determines the mapping between data coordinates
 *  and device coordinates in the plot area.
 **/
@implementation CPTPlotSpace

/** @property nullable id<NSCopying, NSCoding, NSObject> identifier
 *  @brief An object used to identify the plot in collections.
 **/
@synthesize identifier;

/** @property BOOL allowsUserInteraction
 *  @brief Determines whether user can interactively change plot range and/or zoom.
 **/
@synthesize allowsUserInteraction;

/** @property BOOL isDragging
 *  @brief Returns @YES when the user is actively dragging the plot space.
 **/
@synthesize isDragging;

/** @property nullable CPTGraph *graph
 *  @brief The graph of the space.
 **/
@synthesize graph;

/** @property nullable id<CPTPlotSpaceDelegate> delegate
 *  @brief The plot space delegate.
 **/
@synthesize delegate;

/** @property NSUInteger numberOfCoordinates
 *  @brief The number of coordinate values that determine a point in the plot space.
 **/
@dynamic numberOfCoordinates;

/** @internal
 *  @property nullable NSMutableDictionary<NSNumber *, NSString *> *categoryNames
 *  @brief The names of the data categories for each coordinate with a #CPTScaleTypeCategory scale type.
 *  The keys are the CPTCoordinate enumeration values and the values are arrays of strings.
 **/
@synthesize categoryNames;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTPlotSpace object.
 *
 *  The initialized object will have the following properties:
 *  - @ref identifier = @nil
 *  - @ref allowsUserInteraction = @NO
 *  - @ref isDragging = @NO
 *  - @ref graph = @nil
 *  - @ref delegate = @nil
 *
 *  @return The initialized object.
 **/
-(nonnull instancetype)init
{
    if ((self = [super init])) {
        identifier            = nil;
        allowsUserInteraction = NO;
        isDragging            = NO;
        graph                 = nil;
        delegate              = nil;
        categoryNames         = nil;
    }
    return self;
}

/// @}

/// @cond

-(void)dealloc
{
    delegate = nil;
    graph    = nil;
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [coder encodeConditionalObject:self.graph forKey:@"CPTPlotSpace.graph"];
    [coder encodeObject:self.identifier forKey:@"CPTPlotSpace.identifier"];
    id<CPTPlotSpaceDelegate> theDelegate = self.delegate;
    if ( [theDelegate conformsToProtocol:@protocol(NSCoding)] ) {
        [coder encodeConditionalObject:theDelegate forKey:@"CPTPlotSpace.delegate"];
    }
    [coder encodeBool:self.allowsUserInteraction forKey:@"CPTPlotSpace.allowsUserInteraction"];
    [coder encodeObject:self.categoryNames forKey:@"CPTPlotSpace.categoryNames"];

    // No need to archive these properties:
    // isDragging
}

/// @endcond

/** @brief Returns an object initialized from data in a given unarchiver.
 *  @param coder An unarchiver object.
 *  @return An object initialized from data in a given unarchiver.
 */
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super init])) {
        graph = [coder decodeObjectOfClass:[CPTGraph class]
                                    forKey:@"CPTPlotSpace.graph"];
        identifier = [[coder decodeObjectOfClass:[NSObject class]
                                          forKey:@"CPTPlotSpace.identifier"] copy];
        delegate = [coder decodeObjectOfClass:[NSObject class]
                                       forKey:@"CPTPlotSpace.delegate"];
        allowsUserInteraction = [coder decodeBoolForKey:@"CPTPlotSpace.allowsUserInteraction"];
        categoryNames         = [[coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSDictionary class], [NSString class], [NSNumber class]]]
                                                       forKey:@"CPTPlotSpace.categoryNames"] mutableCopy];

        isDragging = NO;
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
#pragma mark Categorical Data

/// @cond

/** @internal
 *  @brief Gets the ordered set of categories for the given coordinate, creating it if necessary.
 *  @param coordinate The axis coordinate.
 *  @return The ordered set of categories for the given coordinate.
 */
-(nonnull CPTMutableCategorySet *)orderedSetForCoordinate:(CPTCoordinate)coordinate
{
    NSMutableDictionary<NSNumber *, CPTMutableCategorySet *> *names = self.categoryNames;

    if ( !names ) {
        names = [[NSMutableDictionary alloc] init];

        self.categoryNames = names;
    }

    NSNumber *cacheKey = @(coordinate);

    CPTMutableCategorySet *categories = names[cacheKey];

    if ( !categories ) {
        categories = [[NSMutableOrderedSet alloc] init];

        names[cacheKey] = categories;
    }

    return categories;
}

/// @endcond

/**
 *  @brief Add a new category name for the given coordinate.
 *
 *  Category names must be unique for each coordinate. Adding the same name more than once has no effect.
 *
 *  @param category The category name.
 *  @param coordinate The axis coordinate.
 */
-(void)addCategory:(nonnull NSString *)category forCoordinate:(CPTCoordinate)coordinate
{
    NSParameterAssert(category);

    CPTMutableCategorySet *categories = [self orderedSetForCoordinate:coordinate];

    [categories addObject:category];
}

/**
 *  @brief Removes the named category for the given coordinate.
 *  @param category The category name.
 *  @param coordinate The axis coordinate.
 */
-(void)removeCategory:(nonnull NSString *)category forCoordinate:(CPTCoordinate)coordinate
{
    NSParameterAssert(category);

    CPTMutableCategorySet *categories = [self orderedSetForCoordinate:coordinate];

    [categories removeObject:category];
}

/**
 *  @brief Add a new category name for the given coordinate at the given index in the list of category names.
 *
 *  Category names must be unique for each coordinate. Adding the same name more than once has no effect.
 *
 *  @param category The category name.
 *  @param coordinate The axis coordinate.
 *  @param idx The index in the list of category names.
 */
-(void)insertCategory:(nonnull NSString *)category forCoordinate:(CPTCoordinate)coordinate atIndex:(NSUInteger)idx
{
    NSParameterAssert(category);

    CPTMutableCategorySet *categories = [self orderedSetForCoordinate:coordinate];

    NSParameterAssert(idx <= categories.count);

    [categories insertObject:category atIndex:idx];
}

/**
 *  @brief Replace all category names for the given coordinate with the names in the supplied array.
 *  @param newCategories An array of category names.
 *  @param coordinate The axis coordinate.
 */
-(void)setCategories:(nullable CPTStringArray *)newCategories forCoordinate:(CPTCoordinate)coordinate
{
    NSMutableDictionary<NSNumber *, CPTMutableCategorySet *> *names = self.categoryNames;

    if ( !names ) {
        names = [[NSMutableDictionary alloc] init];

        self.categoryNames = names;
    }

    NSNumber *cacheKey = @(coordinate);

    if ( [newCategories isKindOfClass:[NSArray class]] ) {
        CPTStringArray *categories = newCategories;

        names[cacheKey] = [NSMutableOrderedSet orderedSetWithArray:categories];
    }
    else {
        [names removeObjectForKey:cacheKey];
    }
}

/**
 *  @brief Remove all categories for every coordinate.
 */
-(void)removeAllCategories
{
    self.categoryNames = nil;
}

/**
 *  @brief Returns a list of all category names for the given coordinate.
 *  @param coordinate The axis coordinate.
 *  @return An array of category names.
 */
-(nonnull CPTStringArray *)categoriesForCoordinate:(CPTCoordinate)coordinate
{
    CPTMutableCategorySet *categories = [self orderedSetForCoordinate:coordinate];

    return categories.array;
}

/**
 *  @brief Returns the category name for the given coordinate at the given index in the list of category names.
 *  @param coordinate The axis coordinate.
 *  @param idx The index in the list of category names.
 *  @return The category name.
 */
-(nullable NSString *)categoryForCoordinate:(CPTCoordinate)coordinate atIndex:(NSUInteger)idx
{
    CPTMutableCategorySet *categories = [self orderedSetForCoordinate:coordinate];

    NSParameterAssert(idx < categories.count);

    return categories[idx];
}

/**
 *  @brief Returns the index of the given category name in the list of category names for the given coordinate.
 *  @param category The category name.
 *  @param coordinate The axis coordinate.
 *  @return The category index.
 */
-(NSUInteger)indexOfCategory:(nonnull NSString *)category forCoordinate:(CPTCoordinate)coordinate
{
    NSParameterAssert(category);

    CPTMutableCategorySet *categories = [self orderedSetForCoordinate:coordinate];

    return [categories indexOfObject:category];
}

#pragma mark -
#pragma mark Responder Chain and User interaction

/// @name User Interaction
/// @{

/**
 *  @brief Informs the receiver that the user has
 *  @if MacOnly pressed the mouse button. @endif
 *  @if iOSOnly touched the screen. @endif
 *
 *
 *  If the receiver does not have a @ref delegate,
 *  this method always returns @NO. Otherwise, the
 *  @link CPTPlotSpaceDelegate::plotSpace:shouldHandlePointingDeviceDownEvent:atPoint: -plotSpace:shouldHandlePointingDeviceDownEvent:atPoint: @endlink
 *  delegate method is called. If it returns @NO, this method returns @YES
 *  to indicate that the event has been handled and no further processing should occur.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceDownEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    BOOL handledByDelegate = NO;

    id<CPTPlotSpaceDelegate> theDelegate = self.delegate;

    if ( [theDelegate respondsToSelector:@selector(plotSpace:shouldHandlePointingDeviceDownEvent:atPoint:)] ) {
        handledByDelegate = ![theDelegate plotSpace:self shouldHandlePointingDeviceDownEvent:event atPoint:interactionPoint];
    }
    return handledByDelegate;
}

/**
 *  @brief Informs the receiver that the user has
 *  @if MacOnly released the mouse button. @endif
 *  @if iOSOnly lifted their finger off the screen. @endif
 *
 *
 *  If the receiver does not have a @link CPTPlotSpace::delegate delegate @endlink,
 *  this method always returns @NO. Otherwise, the
 *  @link CPTPlotSpaceDelegate::plotSpace:shouldHandlePointingDeviceUpEvent:atPoint: -plotSpace:shouldHandlePointingDeviceUpEvent:atPoint: @endlink
 *  delegate method is called. If it returns @NO, this method returns @YES
 *  to indicate that the event has been handled and no further processing should occur.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceUpEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    BOOL handledByDelegate = NO;

    id<CPTPlotSpaceDelegate> theDelegate = self.delegate;

    if ( [theDelegate respondsToSelector:@selector(plotSpace:shouldHandlePointingDeviceUpEvent:atPoint:)] ) {
        handledByDelegate = ![theDelegate plotSpace:self shouldHandlePointingDeviceUpEvent:event atPoint:interactionPoint];
    }
    return handledByDelegate;
}

/**
 *  @brief Informs the receiver that the user has moved
 *  @if MacOnly the mouse with the button pressed. @endif
 *  @if iOSOnly their finger while touching the screen. @endif
 *
 *
 *  If the receiver does not have a @ref delegate,
 *  this method always returns @NO. Otherwise, the
 *  @link CPTPlotSpaceDelegate::plotSpace:shouldHandlePointingDeviceDraggedEvent:atPoint: -plotSpace:shouldHandlePointingDeviceDraggedEvent:atPoint: @endlink
 *  delegate method is called. If it returns @NO, this method returns @YES
 *  to indicate that the event has been handled and no further processing should occur.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceDraggedEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    BOOL handledByDelegate = NO;

    id<CPTPlotSpaceDelegate> theDelegate = self.delegate;

    if ( [theDelegate respondsToSelector:@selector(plotSpace:shouldHandlePointingDeviceDraggedEvent:atPoint:)] ) {
        handledByDelegate = ![theDelegate plotSpace:self shouldHandlePointingDeviceDraggedEvent:event atPoint:interactionPoint];
    }
    return handledByDelegate;
}

/**
 *  @brief Informs the receiver that tracking of
 *  @if MacOnly mouse moves @endif
 *  @if iOSOnly touches @endif
 *  has been cancelled for any reason.
 *
 *
 *  If the receiver does not have a @ref delegate,
 *  this method always returns @NO. Otherwise, the
 *  @link CPTPlotSpaceDelegate::plotSpace:shouldHandlePointingDeviceCancelledEvent: -plotSpace:shouldHandlePointingDeviceCancelledEvent: @endlink
 *  delegate method is called. If it returns @NO, this method returns @YES
 *  to indicate that the event has been handled and no further processing should occur.
 *
 *  @param event The OS event.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceCancelledEvent:(nonnull CPTNativeEvent *)event
{
    BOOL handledByDelegate = NO;

    id<CPTPlotSpaceDelegate> theDelegate = self.delegate;

    if ( [theDelegate respondsToSelector:@selector(plotSpace:shouldHandlePointingDeviceCancelledEvent:)] ) {
        handledByDelegate = ![theDelegate plotSpace:self shouldHandlePointingDeviceCancelledEvent:event];
    }
    return handledByDelegate;
}

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
    BOOL handledByDelegate = NO;

    id<CPTPlotSpaceDelegate> theDelegate = self.delegate;

    if ( [theDelegate respondsToSelector:@selector(plotSpace:shouldHandleScrollWheelEvent:fromPoint:toPoint:)] ) {
        handledByDelegate = ![theDelegate plotSpace:self shouldHandleScrollWheelEvent:event fromPoint:fromPoint toPoint:toPoint];
    }
    return handledByDelegate;
}

#endif

/// @}

@end

#pragma mark -

@implementation CPTPlotSpace(AbstractMethods)

/// @cond

-(NSUInteger)numberOfCoordinates
{
    return 0;
}

/// @endcond

/** @brief Converts a data point to plot area drawing coordinates.
 *  @param plotPoint An array of data point coordinates (as NSNumber values).
 *  @return The drawing coordinates of the data point.
 **/
-(CGPoint)plotAreaViewPointForPlotPoint:(nonnull CPTNumberArray *cpt_unused)plotPoint
{
    NSParameterAssert(plotPoint.count == self.numberOfCoordinates);

    return CGPointZero;
}

/** @brief Converts a data point to plot area drawing coordinates.
 *  @param plotPoint A c-style array of data point coordinates (as NSDecimal structs).
 *  @param count The number of coordinate values in the @par{plotPoint} array.
 *  @return The drawing coordinates of the data point.
 **/
-(CGPoint)plotAreaViewPointForPlotPoint:(nonnull NSDecimal *__unused)plotPoint numberOfCoordinates:(NSUInteger cpt_unused)count
{
    NSParameterAssert(count == self.numberOfCoordinates);

    return CGPointZero;
}

/** @brief Converts a data point to plot area drawing coordinates.
 *  @param plotPoint A c-style array of data point coordinates (as @double values).
 *  @param count The number of coordinate values in the @par{plotPoint} array.
 *  @return The drawing coordinates of the data point.
 **/
-(CGPoint)plotAreaViewPointForDoublePrecisionPlotPoint:(nonnull double *__unused)plotPoint numberOfCoordinates:(NSUInteger cpt_unused)count
{
    NSParameterAssert(count == self.numberOfCoordinates);

    return CGPointZero;
}

/** @brief Converts a point given in plot area drawing coordinates to the data coordinate space.
 *  @param point The drawing coordinates of the data point.
 *  @return An array of data point coordinates (as NSNumber values).
 **/
-(nullable CPTNumberArray *)plotPointForPlotAreaViewPoint:(CGPoint __unused)point
{
    return nil;
}

/** @brief Converts a point given in plot area drawing coordinates to the data coordinate space.
 *  @param plotPoint A c-style array of data point coordinates (as NSDecimal structs).
 *  @param count The number of coordinate values in the @par{plotPoint} array.
 *  @param point The drawing coordinates of the data point.
 **/
-(void)plotPoint:(nonnull NSDecimal *__unused)plotPoint numberOfCoordinates:(NSUInteger cpt_unused)count forPlotAreaViewPoint:(CGPoint __unused)point
{
    NSParameterAssert(count == self.numberOfCoordinates);
}

/** @brief Converts a point given in drawing coordinates to the data coordinate space.
 *  @param plotPoint A c-style array of data point coordinates (as @double values).
 *  @param count The number of coordinate values in the @par{plotPoint} array.
 *  @param point The drawing coordinates of the data point.
 **/
-(void)doublePrecisionPlotPoint:(nonnull double *__unused)plotPoint numberOfCoordinates:(NSUInteger cpt_unused)count forPlotAreaViewPoint:(CGPoint __unused)point
{
    NSParameterAssert(count == self.numberOfCoordinates);
}

/** @brief Converts the interaction point of an OS event to plot area drawing coordinates.
 *  @param event The event.
 *  @return The drawing coordinates of the point.
 **/
-(CGPoint)plotAreaViewPointForEvent:(nonnull CPTNativeEvent *__unused)event
{
    return CGPointZero;
}

/** @brief Converts the interaction point of an OS event to the data coordinate space.
 *  @param event The event.
 *  @return An array of data point coordinates (as NSNumber values).
 **/
-(nullable CPTNumberArray *)plotPointForEvent:(nonnull CPTNativeEvent *__unused)event
{
    return nil;
}

/** @brief Converts the interaction point of an OS event to the data coordinate space.
 *  @param plotPoint A c-style array of data point coordinates (as NSDecimal structs).
 *  @param count The number of coordinate values in the @par{plotPoint} array.
 *  @param event The event.
 **/
-(void)plotPoint:(nonnull NSDecimal *__unused)plotPoint numberOfCoordinates:(NSUInteger cpt_unused)count forEvent:(nonnull CPTNativeEvent *__unused)event
{
    NSParameterAssert(count == self.numberOfCoordinates);
}

/** @brief Converts the interaction point of an OS event to the data coordinate space.
 *  @param plotPoint A c-style array of data point coordinates (as @double values).
 *  @param count The number of coordinate values in the @par{plotPoint} array.
 *  @param event The event.
 **/
-(void)doublePrecisionPlotPoint:(nonnull double *__unused)plotPoint numberOfCoordinates:(NSUInteger cpt_unused)count forEvent:(nonnull CPTNativeEvent *__unused)event
{
    NSParameterAssert(count == self.numberOfCoordinates);
}

/** @brief Sets the range of values for a given coordinate.
 *  @param newRange The new plot range.
 *  @param coordinate The axis coordinate.
 **/
-(void)setPlotRange:(nonnull CPTPlotRange *__unused)newRange forCoordinate:(CPTCoordinate __unused)coordinate
{
}

/** @brief Gets the range of values for a given coordinate.
 *  @param coordinate The axis coordinate.
 *  @return The range of values.
 **/
-(nullable CPTPlotRange *)plotRangeForCoordinate:(CPTCoordinate __unused)coordinate
{
    return nil;
}

/** @brief Sets the scale type for a given coordinate.
 *  @param newType The new scale type.
 *  @param coordinate The axis coordinate.
 **/
-(void)setScaleType:(CPTScaleType __unused)newType forCoordinate:(CPTCoordinate __unused)coordinate
{
}

/** @brief Gets the scale type for a given coordinate.
 *  @param coordinate The axis coordinate.
 *  @return The scale type.
 **/
-(CPTScaleType)scaleTypeForCoordinate:(CPTCoordinate __unused)coordinate
{
    return CPTScaleTypeLinear;
}

/** @brief Scales the plot ranges so that the plots just fit in the visible space.
 *  @param plots An array of the plots that have to fit in the visible area.
 **/
-(void)scaleToFitPlots:(nullable CPTPlotArray *__unused)plots
{
}

/** @brief Scales the plot range for the given coordinate so that the plots just fit in the visible space.
 *  @param plots An array of the plots that have to fit in the visible area.
 *  @param coordinate The axis coordinate.
 **/
-(void)scaleToFitPlots:(nullable CPTPlotArray *)plots forCoordinate:(CPTCoordinate)coordinate
{
    if ( plots.count == 0 ) {
        return;
    }

    // Determine union of ranges
    CPTMutablePlotRange *unionRange = nil;
    for ( CPTPlot *plot in plots ) {
        CPTPlotRange *currentRange = [plot plotRangeForCoordinate:coordinate];
        if ( !unionRange ) {
            unionRange = [currentRange mutableCopy];
        }
        [unionRange unionPlotRange:currentRange];
    }

    // Set range
    if ( unionRange ) {
        if ( CPTDecimalEquals(unionRange.lengthDecimal, CPTDecimalFromInteger(0))) {
            [unionRange unionPlotRange:[self plotRangeForCoordinate:coordinate]];
        }
        [self setPlotRange:unionRange forCoordinate:coordinate];
    }
}

/** @brief Scales the plot ranges so that the plots just fit in the visible space.
 *  @param plots An array of the plots that have to fit in the visible area.
 **/
-(void)scaleToFitEntirePlots:(nullable CPTPlotArray *__unused)plots
{
}

/** @brief Scales the plot range for the given coordinate so that the plots just fit in the visible space.
 *  @param plots An array of the plots that have to fit in the visible area.
 *  @param coordinate The axis coordinate.
 **/
-(void)scaleToFitEntirePlots:(nullable CPTPlotArray *)plots forCoordinate:(CPTCoordinate)coordinate
{
    if ( plots.count == 0 ) {
        return;
    }

    // Determine union of ranges
    CPTMutablePlotRange *unionRange = nil;
    for ( CPTPlot *plot in plots ) {
        CPTPlotRange *currentRange = [plot plotRangeForCoordinate:coordinate];
        if ( !unionRange ) {
            unionRange = [currentRange mutableCopy];
        }
        [unionRange unionPlotRange:currentRange];
    }

    // Set range
    if ( unionRange ) {
        if ( CPTDecimalEquals(unionRange.lengthDecimal, CPTDecimalFromInteger(0))) {
            [unionRange unionPlotRange:[self plotRangeForCoordinate:coordinate]];
        }
        [self setPlotRange:unionRange forCoordinate:coordinate];
    }
}

/** @brief Zooms the plot space equally in each dimension.
 *  @param interactionScale The scaling factor. One (@num{1}) gives no scaling.
 *  @param interactionPoint The plot area view point about which the scaling occurs.
 **/
-(void)scaleBy:(CGFloat __unused)interactionScale aboutPoint:(CGPoint __unused)interactionPoint
{
}

#pragma mark -
#pragma mark Debugging

/// @cond

-(nullable id)debugQuickLookObject
{
    return [NSString stringWithFormat:@"Identifier: %@\nallowsUserInteraction: %@",
            self.identifier,
            self.allowsUserInteraction ? @"YES" : @"NO"];
}

/// @endcond

@end

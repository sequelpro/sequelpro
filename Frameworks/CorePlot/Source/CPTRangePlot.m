#import "CPTRangePlot.h"

#import "CPTExceptions.h"
#import "CPTFill.h"
#import "CPTLegend.h"
#import "CPTLineStyle.h"
#import "CPTMutableNumericData.h"
#import "CPTPathExtensions.h"
#import "CPTPlotArea.h"
#import "CPTPlotRange.h"
#import "CPTPlotSpace.h"
#import "CPTPlotSpaceAnnotation.h"
#import "CPTUtilities.h"
#import "CPTXYPlotSpace.h"
#import "NSCoderExtensions.h"
#import "NSNumberExtensions.h"
#import "tgmath.h"

/** @defgroup plotAnimationRangePlot Range Plot
 *  @brief Range plot properties that can be animated using Core Animation.
 *  @ingroup plotAnimation
 **/

/** @if MacOnly
 *  @defgroup plotBindingsRangePlot Range Plot Bindings
 *  @brief Binding identifiers for range plots.
 *  @ingroup plotBindings
 *  @endif
 **/

CPTRangePlotBinding const CPTRangePlotBindingXValues       = @"xValues";       ///< X values.
CPTRangePlotBinding const CPTRangePlotBindingYValues       = @"yValues";       ///< Y values.
CPTRangePlotBinding const CPTRangePlotBindingHighValues    = @"highValues";    ///< High values.
CPTRangePlotBinding const CPTRangePlotBindingLowValues     = @"lowValues";     ///< Low values.
CPTRangePlotBinding const CPTRangePlotBindingLeftValues    = @"leftValues";    ///< Left price values.
CPTRangePlotBinding const CPTRangePlotBindingRightValues   = @"rightValues";   ///< Right price values.
CPTRangePlotBinding const CPTRangePlotBindingBarLineStyles = @"barLineStyles"; ///< Bar line styles.
CPTRangePlotBinding const CPTRangePlotBindingBarWidths     = @"barWidths";     ///< Bar widths.

/// @cond
struct CGPointError {
    CGFloat x;
    CGFloat y;
    CGFloat high;
    CGFloat low;
    CGFloat left;
    CGFloat right;
};
typedef struct CGPointError CGPointError;

@interface CPTRangePlot()

@property (nonatomic, readwrite, copy, nullable) CPTNumberArray *xValues;
@property (nonatomic, readwrite, copy, nullable) CPTNumberArray *yValues;
@property (nonatomic, readwrite, copy, nullable) CPTMutableNumericData *highValues;
@property (nonatomic, readwrite, copy, nullable) CPTMutableNumericData *lowValues;
@property (nonatomic, readwrite, copy, nullable) CPTMutableNumericData *leftValues;
@property (nonatomic, readwrite, copy, nullable) CPTMutableNumericData *rightValues;
@property (nonatomic, readwrite, copy, nullable) CPTLineStyleArray *barLineStyles;
@property (nonatomic, readwrite, copy, nullable) CPTLineStyleArray *barWidths;
@property (nonatomic, readwrite, assign) NSUInteger pointingDeviceDownIndex;

-(void)calculatePointsToDraw:(nonnull BOOL *)pointDrawFlags numberOfPoints:(NSUInteger)dataCount forPlotSpace:(nonnull CPTXYPlotSpace *)xyPlotSpace;
-(void)calculateViewPoints:(nonnull CGPointError *)viewPoints withDrawPointFlags:(nonnull BOOL *)drawPointFlags numberOfPoints:(NSUInteger)dataCount;
-(void)alignViewPointsToUserSpace:(nonnull CGPointError *)viewPoints withContext:(nonnull CGContextRef)context drawPointFlags:(nonnull BOOL *)drawPointFlag numberOfPoints:(NSUInteger)dataCounts;
-(NSInteger)extremeDrawnPointIndexForFlags:(nonnull BOOL *)pointDrawFlags numberOfPoints:(NSUInteger)dataCount extremeNumIsLowerBound:(BOOL)isLowerBound;

-(void)drawRangeInContext:(nonnull CGContextRef)context lineStyle:(nonnull CPTLineStyle *)lineStyle viewPoint:(CGPointError *)viewPoint halfGapSize:(CGSize)halfGapSize halfBarWidth:(CGFloat)halfBarWidth alignPoints:(BOOL)alignPoints;
-(CPTLineStyle *)barLineStyleForIndex:(NSUInteger)idx;
-(nonnull NSNumber *)barWidthForIndex:(NSUInteger)idx;

@end

/// @endcond

#pragma mark -

/** @brief A plot class representing a range of values in one coordinate,
 *  such as typically used to show errors.
 *  A range plot can show bars (error bars), or an area fill, or both.
 *  @see See @ref plotAnimationRangePlot "Range Plot" for a list of animatable properties.
 *  @if MacOnly
 *  @see See @ref plotBindingsRangePlot "Range Plot Bindings" for a list of supported binding identifiers.
 *  @endif
 **/
@implementation CPTRangePlot

@dynamic xValues;
@dynamic yValues;
@dynamic highValues;
@dynamic lowValues;
@dynamic leftValues;
@dynamic rightValues;
@dynamic barLineStyles;
@dynamic barWidths;

/** @property CPTRangePlotFillDirection fillDirection
 *  @brief Fill the range in a horizontal or vertical direction.
 *  Default is CPTRangePlotFillHorizontal.
 **/
@synthesize fillDirection;

/** @property CPTFill *areaFill
 *  @brief The fill used to render the area.
 *  Set to @nil to have no fill. Default is @nil.
 **/
@synthesize areaFill;

/** @property CPTLineStyle *areaBorderLineStyle
 *  @brief The line style of the border line around the area fill.
 *  Set to @nil to have no border line. Default is @nil.
 **/
@synthesize areaBorderLineStyle;

/** @property CPTLineStyle *barLineStyle
 *  @brief The line style of the range bars.
 *  Set to @nil to have no bars. Default is a black line style.
 **/
@synthesize barLineStyle;

/** @property CGFloat barWidth
 *  @brief Width of the lateral sections of the bars.
 *  @ingroup plotAnimationRangePlot
 **/
@synthesize barWidth;

/** @property CGFloat gapHeight
 *  @brief Height of the central gap.
 *  Set to zero to have no gap.
 *  @ingroup plotAnimationRangePlot
 **/
@synthesize gapHeight;

/** @property CGFloat gapWidth
 *  @brief Width of the central gap.
 *  Set to zero to have no gap.
 *  @ingroup plotAnimationRangePlot
 **/
@synthesize gapWidth;

/** @internal
 *  @property NSUInteger pointingDeviceDownIndex
 *  @brief The index that was selected on the pointing device down event.
 **/
@synthesize pointingDeviceDownIndex;

#pragma mark -
#pragma mark Init/Dealloc

/// @cond

#if TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
#else
+(void)initialize
{
    if ( self == [CPTRangePlot class] ) {
        [self exposeBinding:CPTRangePlotBindingXValues];
        [self exposeBinding:CPTRangePlotBindingYValues];
        [self exposeBinding:CPTRangePlotBindingHighValues];
        [self exposeBinding:CPTRangePlotBindingLowValues];
        [self exposeBinding:CPTRangePlotBindingLeftValues];
        [self exposeBinding:CPTRangePlotBindingRightValues];
        [self exposeBinding:CPTRangePlotBindingBarLineStyles];
        [self exposeBinding:CPTRangePlotBindingBarWidths];
    }
}

#endif

/// @endcond

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTRangePlot object with the provided frame rectangle.
 *
 *  This is the designated initializer. The initialized layer will have the following properties:
 *  - @ref barLineStyle = default line style
 *  - @ref fillDirection = CPTRangePlotFillHorizontal
 *  - @ref areaFill = @nil
 *  - @ref areaBorderLineStyle = @nil
 *  - @ref barWidth = 0.0
 *  - @ref gapHeight = 0.0
 *  - @ref gapWidth = 0.0
 *  - @ref labelField = #CPTRangePlotFieldX
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTRangePlot object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame
{
    if ((self = [super initWithFrame:newFrame])) {
        barLineStyle        = [[CPTLineStyle alloc] init];
        fillDirection       = CPTRangePlotFillHorizontal;
        areaFill            = nil;
        areaBorderLineStyle = nil;
        barWidth            = CPTFloat(0.0);
        gapHeight           = CPTFloat(0.0);
        gapWidth            = CPTFloat(0.0);

        pointingDeviceDownIndex = NSNotFound;

        self.labelField = CPTRangePlotFieldX;
    }
    return self;
}

/// @}

/// @cond

-(nonnull instancetype)initWithLayer:(nonnull id)layer
{
    if ((self = [super initWithLayer:layer])) {
        CPTRangePlot *theLayer = (CPTRangePlot *)layer;

        barLineStyle        = theLayer->barLineStyle;
        fillDirection       = theLayer->fillDirection;
        areaFill            = theLayer->areaFill;
        areaBorderLineStyle = theLayer->areaBorderLineStyle;
        barWidth            = theLayer->barWidth;
        gapHeight           = theLayer->gapHeight;
        gapWidth            = theLayer->gapWidth;

        pointingDeviceDownIndex = NSNotFound;
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

    [coder encodeObject:self.barLineStyle forKey:@"CPTRangePlot.barLineStyle"];
    [coder encodeCGFloat:self.barWidth forKey:@"CPTRangePlot.barWidth"];
    [coder encodeCGFloat:self.gapHeight forKey:@"CPTRangePlot.gapHeight"];
    [coder encodeCGFloat:self.gapWidth forKey:@"CPTRangePlot.gapWidth"];
    [coder encodeInteger:self.fillDirection forKey:@"CPTRangePlot.fillDirection"];
    [coder encodeObject:self.areaFill forKey:@"CPTRangePlot.areaFill"];
    [coder encodeObject:self.areaBorderLineStyle forKey:@"CPTRangePlot.areaBorderLineStyle"];

    // No need to archive these properties:
    // pointingDeviceDownIndex
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        barLineStyle = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                            forKey:@"CPTRangePlot.barLineStyle"] copy];
        barWidth      = [coder decodeCGFloatForKey:@"CPTRangePlot.barWidth"];
        gapHeight     = [coder decodeCGFloatForKey:@"CPTRangePlot.gapHeight"];
        gapWidth      = [coder decodeCGFloatForKey:@"CPTRangePlot.gapWidth"];
        fillDirection = [coder decodeIntegerForKey:@"CPTRangePlot.fillDirection"];
        areaFill      = [[coder decodeObjectOfClass:[CPTFill class]
                                             forKey:@"CPTRangePlot.areaFill"] copy];
        areaBorderLineStyle = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                                   forKey:@"CPTRangePlot.areaBorderLineStyle"] copy];

        pointingDeviceDownIndex = NSNotFound;
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
#pragma mark Determining Which Points to Draw

/// @cond

-(void)calculatePointsToDraw:(nonnull BOOL *)pointDrawFlags numberOfPoints:(NSUInteger)dataCount forPlotSpace:(nonnull CPTXYPlotSpace *)xyPlotSpace
{
    if ( dataCount == 0 ) {
        return;
    }

    if ( self.areaFill ) {
        // show all points to preserve the area fill
        for ( NSUInteger i = 0; i < dataCount; i++ ) {
            pointDrawFlags[i] = YES;
        }
    }
    else {
        CPTPlotRangeComparisonResult *xRangeFlags = calloc(dataCount, sizeof(CPTPlotRangeComparisonResult));
        CPTPlotRangeComparisonResult *yRangeFlags = calloc(dataCount, sizeof(CPTPlotRangeComparisonResult));
        BOOL *nanFlags                            = calloc(dataCount, sizeof(BOOL));

        CPTPlotRange *xRange = xyPlotSpace.xRange;
        CPTPlotRange *yRange = xyPlotSpace.yRange;

        // Determine where each point lies in relation to range
        if ( self.doublePrecisionCache ) {
            const double *xBytes = (const double *)[self cachedNumbersForField:CPTRangePlotFieldX].data.bytes;
            const double *yBytes = (const double *)[self cachedNumbersForField:CPTRangePlotFieldY].data.bytes;

            dispatch_apply(dataCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
                const double x = xBytes[i];
                const double y = yBytes[i];

                xRangeFlags[i] = [xRange compareToDouble:x];
                yRangeFlags[i] = [yRange compareToDouble:y];
                nanFlags[i]    = isnan(x) || isnan(y);
            });
        }
        else {
            const NSDecimal *xBytes = (const NSDecimal *)[self cachedNumbersForField:CPTRangePlotFieldX].data.bytes;
            const NSDecimal *yBytes = (const NSDecimal *)[self cachedNumbersForField:CPTRangePlotFieldY].data.bytes;

            dispatch_apply(dataCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
                const NSDecimal x = xBytes[i];
                const NSDecimal y = yBytes[i];

                xRangeFlags[i] = [xRange compareToDecimal:x];
                yRangeFlags[i] = [yRange compareToDecimal:y];
                nanFlags[i]    = NSDecimalIsNotANumber(&x);
            });
        }

        for ( NSUInteger i = 0; i < dataCount; i++ ) {
            BOOL drawPoint = (xRangeFlags[i] == CPTPlotRangeComparisonResultNumberInRange) &&
                             (yRangeFlags[i] == CPTPlotRangeComparisonResultNumberInRange) &&
                             !nanFlags[i];

            pointDrawFlags[i] = drawPoint;
        }

        free(xRangeFlags);
        free(yRangeFlags);
        free(nanFlags);
    }
}

-(void)calculateViewPoints:(nonnull CGPointError *)viewPoints withDrawPointFlags:(nonnull BOOL *)drawPointFlags numberOfPoints:(NSUInteger)dataCount
{
    CPTPlotSpace *thePlotSpace = self.plotSpace;

    // Calculate points
    if ( self.doublePrecisionCache ) {
        const double *xBytes     = (const double *)[self cachedNumbersForField:CPTRangePlotFieldX].data.bytes;
        const double *yBytes     = (const double *)[self cachedNumbersForField:CPTRangePlotFieldY].data.bytes;
        const double *highBytes  = (const double *)[self cachedNumbersForField:CPTRangePlotFieldHigh].data.bytes;
        const double *lowBytes   = (const double *)[self cachedNumbersForField:CPTRangePlotFieldLow].data.bytes;
        const double *leftBytes  = (const double *)[self cachedNumbersForField:CPTRangePlotFieldLeft].data.bytes;
        const double *rightBytes = (const double *)[self cachedNumbersForField:CPTRangePlotFieldRight].data.bytes;

        dispatch_apply(dataCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
            const double x     = xBytes[i];
            const double y     = yBytes[i];
            const double high  = highBytes[i];
            const double low   = lowBytes[i];
            const double left  = leftBytes[i];
            const double right = rightBytes[i];
            if ( !drawPointFlags[i] || isnan(x) || isnan(y)) {
                viewPoints[i].x = CPTNAN; // depending coordinates
                viewPoints[i].y = CPTNAN;
            }
            else {
                double plotPoint[2];
                plotPoint[CPTCoordinateX] = x;
                plotPoint[CPTCoordinateY] = y;
                CGPoint pos               = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
                viewPoints[i].x           = pos.x;
                viewPoints[i].y           = pos.y;

                plotPoint[CPTCoordinateX] = x;
                plotPoint[CPTCoordinateY] = y + high;
                pos                       = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
                viewPoints[i].high        = pos.y;

                plotPoint[CPTCoordinateX] = x;
                plotPoint[CPTCoordinateY] = y - low;
                pos                       = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
                viewPoints[i].low         = pos.y;

                plotPoint[CPTCoordinateX] = x - left;
                plotPoint[CPTCoordinateY] = y;
                pos                       = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
                viewPoints[i].left        = pos.x;

                plotPoint[CPTCoordinateX] = x + right;
                plotPoint[CPTCoordinateY] = y;
                pos                       = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
                viewPoints[i].right       = pos.x;
            }
        });
    }
    else {
        const NSDecimal *xBytes     = (const NSDecimal *)[self cachedNumbersForField:CPTRangePlotFieldX].data.bytes;
        const NSDecimal *yBytes     = (const NSDecimal *)[self cachedNumbersForField:CPTRangePlotFieldY].data.bytes;
        const NSDecimal *highBytes  = (const NSDecimal *)[self cachedNumbersForField:CPTRangePlotFieldHigh].data.bytes;
        const NSDecimal *lowBytes   = (const NSDecimal *)[self cachedNumbersForField:CPTRangePlotFieldLow].data.bytes;
        const NSDecimal *leftBytes  = (const NSDecimal *)[self cachedNumbersForField:CPTRangePlotFieldLeft].data.bytes;
        const NSDecimal *rightBytes = (const NSDecimal *)[self cachedNumbersForField:CPTRangePlotFieldRight].data.bytes;

        dispatch_apply(dataCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
            const NSDecimal x     = xBytes[i];
            const NSDecimal y     = yBytes[i];
            const NSDecimal high  = highBytes[i];
            const NSDecimal low   = lowBytes[i];
            const NSDecimal left  = leftBytes[i];
            const NSDecimal right = rightBytes[i];

            if ( !drawPointFlags[i] || NSDecimalIsNotANumber(&x) || NSDecimalIsNotANumber(&y)) {
                viewPoints[i].x = CPTNAN; // depending coordinates
                viewPoints[i].y = CPTNAN;
            }
            else {
                NSDecimal plotPoint[2];
                plotPoint[CPTCoordinateX] = x;
                plotPoint[CPTCoordinateY] = y;
                CGPoint pos               = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
                viewPoints[i].x           = pos.x;
                viewPoints[i].y           = pos.y;

                if ( !NSDecimalIsNotANumber(&high)) {
                    plotPoint[CPTCoordinateX] = x;
                    NSDecimal yh;
                    NSDecimalAdd(&yh, &y, &high, NSRoundPlain);
                    plotPoint[CPTCoordinateY] = yh;
                    pos                       = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
                    viewPoints[i].high        = pos.y;
                }
                else {
                    viewPoints[i].high = CPTNAN;
                }

                if ( !NSDecimalIsNotANumber(&low)) {
                    plotPoint[CPTCoordinateX] = x;
                    NSDecimal yl;
                    NSDecimalSubtract(&yl, &y, &low, NSRoundPlain);
                    plotPoint[CPTCoordinateY] = yl;
                    pos                       = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
                    viewPoints[i].low         = pos.y;
                }
                else {
                    viewPoints[i].low = CPTNAN;
                }

                if ( !NSDecimalIsNotANumber(&left)) {
                    NSDecimal xl;
                    NSDecimalSubtract(&xl, &x, &left, NSRoundPlain);
                    plotPoint[CPTCoordinateX] = xl;
                    plotPoint[CPTCoordinateY] = y;
                    pos                       = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
                    viewPoints[i].left        = pos.x;
                }
                else {
                    viewPoints[i].left = CPTNAN;
                }
                if ( !NSDecimalIsNotANumber(&right)) {
                    NSDecimal xr;
                    NSDecimalAdd(&xr, &x, &right, NSRoundPlain);
                    plotPoint[CPTCoordinateX] = xr;
                    plotPoint[CPTCoordinateY] = y;
                    pos                       = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
                    viewPoints[i].right       = pos.x;
                }
                else {
                    viewPoints[i].right = CPTNAN;
                }
            }
        });
    }
}

-(void)alignViewPointsToUserSpace:(nonnull CGPointError *)viewPoints withContext:(nonnull CGContextRef)context drawPointFlags:(nonnull BOOL *)drawPointFlags numberOfPoints:(NSUInteger)dataCount
{
    // Align to device pixels if there is a data line.
    // Otherwise, align to view space, so fills are sharp at edges.
    if ( self.barLineStyle.lineWidth > CPTFloat(0.0)) {
        dispatch_apply(dataCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
            if ( drawPointFlags[i] ) {
                CGFloat x       = viewPoints[i].x;
                CGFloat y       = viewPoints[i].y;
                CGPoint pos     = CPTAlignPointToUserSpace(context, CPTPointMake(viewPoints[i].x, viewPoints[i].y));
                viewPoints[i].x = pos.x;
                viewPoints[i].y = pos.y;

                pos                 = CPTAlignPointToUserSpace(context, CPTPointMake(x, viewPoints[i].high));
                viewPoints[i].high  = pos.y;
                pos                 = CPTAlignPointToUserSpace(context, CPTPointMake(x, viewPoints[i].low));
                viewPoints[i].low   = pos.y;
                pos                 = CPTAlignPointToUserSpace(context, CPTPointMake(viewPoints[i].left, y));
                viewPoints[i].left  = pos.x;
                pos                 = CPTAlignPointToUserSpace(context, CPTPointMake(viewPoints[i].right, y));
                viewPoints[i].right = pos.x;
            }
        });
    }
    else {
        dispatch_apply(dataCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
            if ( drawPointFlags[i] ) {
                CGFloat x       = viewPoints[i].x;
                CGFloat y       = viewPoints[i].y;
                CGPoint pos     = CPTAlignIntegralPointToUserSpace(context, CPTPointMake(viewPoints[i].x, viewPoints[i].y));
                viewPoints[i].x = pos.x;
                viewPoints[i].y = pos.y;

                pos                 = CPTAlignIntegralPointToUserSpace(context, CPTPointMake(x, viewPoints[i].high));
                viewPoints[i].high  = pos.y;
                pos                 = CPTAlignIntegralPointToUserSpace(context, CPTPointMake(x, viewPoints[i].low));
                viewPoints[i].low   = pos.y;
                pos                 = CPTAlignIntegralPointToUserSpace(context, CPTPointMake(viewPoints[i].left, y));
                viewPoints[i].left  = pos.x;
                pos                 = CPTAlignIntegralPointToUserSpace(context, CPTPointMake(viewPoints[i].right, y));
                viewPoints[i].right = pos.x;
            }
        });
    }
}

-(NSInteger)extremeDrawnPointIndexForFlags:(nonnull BOOL *)pointDrawFlags numberOfPoints:(NSUInteger)dataCount extremeNumIsLowerBound:(BOOL)isLowerBound
{
    NSInteger result = NSNotFound;
    NSInteger delta  = (isLowerBound ? 1 : -1);

    if ( dataCount > 0 ) {
        NSUInteger initialIndex = (isLowerBound ? 0 : dataCount - 1);
        for ( NSInteger i = (NSInteger)initialIndex; i < (NSInteger)dataCount; i += delta ) {
            if ( pointDrawFlags[i] ) {
                result = i;
                break;
            }
            if ((delta < 0) && (i == 0)) {
                break;
            }
        }
    }
    return result;
}

/// @endcond

#pragma mark -
#pragma mark Data Loading

/// @cond

-(void)reloadDataInIndexRange:(NSRange)indexRange
{
    [super reloadDataInIndexRange:indexRange];

    // Bar line styles
    [self reloadBarLineStylesInIndexRange:indexRange];

    // Bar widths
    [self reloadBarWidthsInIndexRange:indexRange];
}

-(void)reloadPlotDataInIndexRange:(NSRange)indexRange
{
    [super reloadPlotDataInIndexRange:indexRange];

    if ( ![self loadNumbersForAllFieldsFromDataSourceInRecordIndexRange:indexRange] ) {
        id<CPTRangePlotDataSource> theDataSource = (id<CPTRangePlotDataSource>)self.dataSource;

        if ( theDataSource ) {
            id newXValues = [self numbersFromDataSourceForField:CPTRangePlotFieldX recordIndexRange:indexRange];
            [self cacheNumbers:newXValues forField:CPTRangePlotFieldX atRecordIndex:indexRange.location];
            id newYValues = [self numbersFromDataSourceForField:CPTRangePlotFieldY recordIndexRange:indexRange];
            [self cacheNumbers:newYValues forField:CPTRangePlotFieldY atRecordIndex:indexRange.location];
            id newHighValues = [self numbersFromDataSourceForField:CPTRangePlotFieldHigh recordIndexRange:indexRange];
            [self cacheNumbers:newHighValues forField:CPTRangePlotFieldHigh atRecordIndex:indexRange.location];
            id newLowValues = [self numbersFromDataSourceForField:CPTRangePlotFieldLow recordIndexRange:indexRange];
            [self cacheNumbers:newLowValues forField:CPTRangePlotFieldLow atRecordIndex:indexRange.location];
            id newLeftValues = [self numbersFromDataSourceForField:CPTRangePlotFieldLeft recordIndexRange:indexRange];
            [self cacheNumbers:newLeftValues forField:CPTRangePlotFieldLeft atRecordIndex:indexRange.location];
            id newRightValues = [self numbersFromDataSourceForField:CPTRangePlotFieldRight recordIndexRange:indexRange];
            [self cacheNumbers:newRightValues forField:CPTRangePlotFieldRight atRecordIndex:indexRange.location];
        }
        else {
            self.xValues     = nil;
            self.yValues     = nil;
            self.highValues  = nil;
            self.lowValues   = nil;
            self.leftValues  = nil;
            self.rightValues = nil;
        }
    }
}

/// @endcond

/**
 *  @brief Reload all bar line styles from the data source immediately.
 **/
-(void)reloadBarLineStyles
{
    [self reloadBarLineStylesInIndexRange:NSMakeRange(0, self.cachedDataCount)];
}

/** @brief Reload bar line styles in the given index range from the data source immediately.
 *  @param indexRange The index range to load.
 **/
-(void)reloadBarLineStylesInIndexRange:(NSRange)indexRange
{
    id<CPTRangePlotDataSource> theDataSource = (id<CPTRangePlotDataSource>)self.dataSource;

    BOOL needsLegendUpdate = NO;

    if ( [theDataSource respondsToSelector:@selector(barLineStylesForRangePlot:recordIndexRange:)] ) {
        needsLegendUpdate = YES;

        [self cacheArray:[theDataSource barLineStylesForRangePlot:self recordIndexRange:indexRange]
                  forKey:CPTRangePlotBindingBarLineStyles
           atRecordIndex:indexRange.location];
    }
    else if ( [theDataSource respondsToSelector:@selector(barLineStyleForRangePlot:recordIndex:)] ) {
        needsLegendUpdate = YES;

        id nilObject                    = [CPTPlot nilData];
        CPTMutableLineStyleArray *array = [[NSMutableArray alloc] initWithCapacity:indexRange.length];
        NSUInteger maxIndex             = NSMaxRange(indexRange);

        for ( NSUInteger idx = indexRange.location; idx < maxIndex; idx++ ) {
            CPTLineStyle *dataSourceLineStyle = [theDataSource barLineStyleForRangePlot:self recordIndex:idx];
            if ( dataSourceLineStyle ) {
                [array addObject:dataSourceLineStyle];
            }
            else {
                [array addObject:nilObject];
            }
        }

        [self cacheArray:array forKey:CPTRangePlotBindingBarLineStyles atRecordIndex:indexRange.location];
    }

    // Legend
    if ( needsLegendUpdate ) {
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }

    [self setNeedsDisplay];
}

/**
 *  @brief Reload all bar widths from the data source immediately.
 **/
-(void)reloadBarWidths
{
    [self reloadBarWidthsInIndexRange:NSMakeRange(0, self.cachedDataCount)];
}

/** @brief Reload bar widths in the given index range from the data source immediately.
 *  @param indexRange The index range to load.
 **/
-(void)reloadBarWidthsInIndexRange:(NSRange)indexRange
{
    id<CPTRangePlotDataSource> theDataSource = (id<CPTRangePlotDataSource>)self.dataSource;

    if ( [theDataSource respondsToSelector:@selector(barWidthsForRangePlot:recordIndexRange:)] ) {
        [self cacheArray:[theDataSource barWidthsForRangePlot:self recordIndexRange:indexRange]
                  forKey:CPTRangePlotBindingBarWidths
           atRecordIndex:indexRange.location];
    }
    else if ( [theDataSource respondsToSelector:@selector(barWidthForRangePlot:recordIndex:)] ) {
        id nilObject                 = [CPTPlot nilData];
        CPTMutableNumberArray *array = [[NSMutableArray alloc] initWithCapacity:indexRange.length];
        NSUInteger maxIndex          = NSMaxRange(indexRange);

        for ( NSUInteger idx = indexRange.location; idx < maxIndex; idx++ ) {
            NSNumber *width = [theDataSource barWidthForRangePlot:self recordIndex:idx];
            if ( width ) {
                [array addObject:width];
            }
            else {
                [array addObject:nilObject];
            }
        }

        [self cacheArray:array
                  forKey:CPTRangePlotBindingBarWidths
           atRecordIndex:indexRange.location];
    }

    [self setNeedsDisplay];
}

#pragma mark -
#pragma mark Drawing

/// @cond

-(void)renderAsVectorInContext:(nonnull CGContextRef)context
{
    if ( self.hidden ) {
        return;
    }

    CPTMutableNumericData *xValueData = [self cachedNumbersForField:CPTRangePlotFieldX];
    CPTMutableNumericData *yValueData = [self cachedNumbersForField:CPTRangePlotFieldY];

    if ((xValueData == nil) || (yValueData == nil)) {
        return;
    }
    NSUInteger dataCount = self.cachedDataCount;
    if ( dataCount == 0 ) {
        return;
    }
    if ( xValueData.numberOfSamples != yValueData.numberOfSamples ) {
        [NSException raise:CPTException format:@"Number of x and y values do not match"];
    }

    [super renderAsVectorInContext:context];

    // Calculate view points, and align to user space
    CGPointError *viewPoints = calloc(dataCount, sizeof(CGPointError));
    BOOL *drawPointFlags     = calloc(dataCount, sizeof(BOOL));

    CPTXYPlotSpace *thePlotSpace = (CPTXYPlotSpace *)self.plotSpace;
    [self calculatePointsToDraw:drawPointFlags numberOfPoints:dataCount forPlotSpace:thePlotSpace];
    [self calculateViewPoints:viewPoints withDrawPointFlags:drawPointFlags numberOfPoints:dataCount];
    if ( self.alignsPointsToPixels ) {
        [self alignViewPointsToUserSpace:viewPoints withContext:context drawPointFlags:drawPointFlags numberOfPoints:dataCount];
    }

    // Get extreme points
    NSInteger lastDrawnPointIndex  = [self extremeDrawnPointIndexForFlags:drawPointFlags numberOfPoints:dataCount extremeNumIsLowerBound:NO];
    NSInteger firstDrawnPointIndex = [self extremeDrawnPointIndexForFlags:drawPointFlags numberOfPoints:dataCount extremeNumIsLowerBound:YES];

    if ( firstDrawnPointIndex != NSNotFound ) {
        if ( self.areaFill ) {
            CGMutablePathRef fillPath = CGPathCreateMutable();

            switch ( self.fillDirection ) {
                case CPTRangePlotFillHorizontal:
                    // First do the top points
                    for ( NSUInteger i = (NSUInteger)firstDrawnPointIndex; i <= (NSUInteger)lastDrawnPointIndex; i++ ) {
                        CGFloat x = viewPoints[i].x;
                        CGFloat y = viewPoints[i].high;
                        if ( isnan(y)) {
                            y = viewPoints[i].y;
                        }

                        if ( !isnan(x) && !isnan(y)) {
                            if ( i == (NSUInteger)firstDrawnPointIndex ) {
                                CGPathMoveToPoint(fillPath, NULL, x, y);
                            }
                            else {
                                CGPathAddLineToPoint(fillPath, NULL, x, y);
                            }
                        }
                    }

                    // Then reverse over bottom points
                    for ( NSUInteger j = (NSUInteger)lastDrawnPointIndex; j >= (NSUInteger)firstDrawnPointIndex; j-- ) {
                        CGFloat x = viewPoints[j].x;
                        CGFloat y = viewPoints[j].low;
                        if ( isnan(y)) {
                            y = viewPoints[j].y;
                        }

                        if ( !isnan(x) && !isnan(y)) {
                            CGPathAddLineToPoint(fillPath, NULL, x, y);
                        }
                        if ( j == (NSUInteger)firstDrawnPointIndex ) {
                            // This could be done a bit more elegant
                            break;
                        }
                    }
                    break;

                case CPTRangePlotFillVertical:
                    // First do the left points
                    for ( NSUInteger i = (NSUInteger)firstDrawnPointIndex; i <= (NSUInteger)lastDrawnPointIndex; i++ ) {
                        CGFloat x = viewPoints[i].left;
                        CGFloat y = viewPoints[i].y;
                        if ( isnan(x)) {
                            y = viewPoints[i].x;
                        }

                        if ( !isnan(x) && !isnan(y)) {
                            if ( i == (NSUInteger)firstDrawnPointIndex ) {
                                CGPathMoveToPoint(fillPath, NULL, x, y);
                            }
                            else {
                                CGPathAddLineToPoint(fillPath, NULL, x, y);
                            }
                        }
                    }

                    // Then reverse over right points
                    for ( NSUInteger j = (NSUInteger)lastDrawnPointIndex; j >= (NSUInteger)firstDrawnPointIndex; j-- ) {
                        CGFloat x = viewPoints[j].right;
                        CGFloat y = viewPoints[j].y;
                        if ( isnan(x)) {
                            y = viewPoints[j].x;
                        }

                        if ( !isnan(x) && !isnan(y)) {
                            CGPathAddLineToPoint(fillPath, NULL, x, y);
                        }
                        if ( j == (NSUInteger)firstDrawnPointIndex ) {
                            // This could be done a bit more elegant
                            break;
                        }
                    }
                    break;
            }

            // Close the path to have a closed loop
            CGPathCloseSubpath(fillPath);

            CGContextBeginPath(context);
            CGContextAddPath(context, fillPath);

            [self.areaFill fillPathInContext:context];

            CPTLineStyle *lineStyle = self.areaBorderLineStyle;
            if ( lineStyle ) {
                CGContextBeginPath(context);
                CGContextAddPath(context, fillPath);

                [lineStyle setLineStyleInContext:context];
                [lineStyle strokePathInContext:context];
            }

            CGPathRelease(fillPath);
        }

        CGSize halfGapSize = CPTSizeMake(self.gapWidth * CPTFloat(0.5), self.gapHeight * CPTFloat(0.5));
        BOOL alignPoints   = self.alignsPointsToPixels;

        for ( NSUInteger i = (NSUInteger)firstDrawnPointIndex; i <= (NSUInteger)lastDrawnPointIndex; i++ ) {
            CGFloat halfBarWidth = [self barWidthForIndex:i].cgFloatValue * CPTFloat(0.5);

            [self drawRangeInContext:context
                           lineStyle:[self barLineStyleForIndex:i]
                           viewPoint:&viewPoints[i]
                         halfGapSize:halfGapSize
                        halfBarWidth:halfBarWidth
                         alignPoints:alignPoints];
        }
    }

    free(viewPoints);
    free(drawPointFlags);
}

-(void)drawRangeInContext:(nonnull CGContextRef)context
                lineStyle:(nonnull CPTLineStyle *)lineStyle
                viewPoint:(nonnull CGPointError *)viewPoint
              halfGapSize:(CGSize)halfGapSize
             halfBarWidth:(CGFloat)halfBarWidth
              alignPoints:(BOOL)alignPoints
{
    if ( [lineStyle isKindOfClass:[CPTLineStyle class]] && !isnan(viewPoint->x) && !isnan(viewPoint->y)) {
        CPTAlignPointFunction alignmentFunction = CPTAlignPointToUserSpace;

        CGFloat lineWidth = lineStyle.lineWidth;
        if ((self.contentsScale > CPTFloat(1.0)) && (round(lineWidth) == lineWidth)) {
            alignmentFunction = CPTAlignIntegralPointToUserSpace;
        }

        CGMutablePathRef path = CGPathCreateMutable();

        // centre-high
        if ( !isnan(viewPoint->high)) {
            CGPoint alignedHighPoint = CPTPointMake(viewPoint->x, viewPoint->y + halfGapSize.height);
            CGPoint alignedLowPoint  = CPTPointMake(viewPoint->x, viewPoint->high);
            if ( alignPoints ) {
                alignedHighPoint = alignmentFunction(context, alignedHighPoint);
                alignedLowPoint  = alignmentFunction(context, alignedLowPoint);
            }
            CGPathMoveToPoint(path, NULL, alignedHighPoint.x, alignedHighPoint.y);
            CGPathAddLineToPoint(path, NULL, alignedLowPoint.x, alignedLowPoint.y);
        }

        // centre-low
        if ( !isnan(viewPoint->low)) {
            CGPoint alignedHighPoint = CPTPointMake(viewPoint->x, viewPoint->y - halfGapSize.height);
            CGPoint alignedLowPoint  = CPTPointMake(viewPoint->x, viewPoint->low);
            if ( alignPoints ) {
                alignedHighPoint = alignmentFunction(context, alignedHighPoint);
                alignedLowPoint  = alignmentFunction(context, alignedLowPoint);
            }
            CGPathMoveToPoint(path, NULL, alignedHighPoint.x, alignedHighPoint.y);
            CGPathAddLineToPoint(path, NULL, alignedLowPoint.x, alignedLowPoint.y);
        }

        // top bar
        if ( !isnan(viewPoint->high)) {
            CGPoint alignedHighPoint = CPTPointMake(viewPoint->x - halfBarWidth, viewPoint->high);
            CGPoint alignedLowPoint  = CPTPointMake(viewPoint->x + halfBarWidth, viewPoint->high);
            if ( alignPoints ) {
                alignedHighPoint = alignmentFunction(context, alignedHighPoint);
                alignedLowPoint  = alignmentFunction(context, alignedLowPoint);
            }
            CGPathMoveToPoint(path, NULL, alignedHighPoint.x, alignedHighPoint.y);
            CGPathAddLineToPoint(path, NULL, alignedLowPoint.x, alignedLowPoint.y);
        }

        // bottom bar
        if ( !isnan(viewPoint->low)) {
            CGPoint alignedHighPoint = CPTPointMake(viewPoint->x - halfBarWidth, viewPoint->low);
            CGPoint alignedLowPoint  = CPTPointMake(viewPoint->x + halfBarWidth, viewPoint->low);
            if ( alignPoints ) {
                alignedHighPoint = alignmentFunction(context, alignedHighPoint);
                alignedLowPoint  = alignmentFunction(context, alignedLowPoint);
            }
            CGPathMoveToPoint(path, NULL, alignedHighPoint.x, alignedHighPoint.y);
            CGPathAddLineToPoint(path, NULL, alignedLowPoint.x, alignedLowPoint.y);
        }

        // centre-left
        if ( !isnan(viewPoint->left)) {
            CGPoint alignedHighPoint = CPTPointMake(viewPoint->x - halfGapSize.width, viewPoint->y);
            CGPoint alignedLowPoint  = CPTPointMake(viewPoint->left, viewPoint->y);
            if ( alignPoints ) {
                alignedHighPoint = alignmentFunction(context, alignedHighPoint);
                alignedLowPoint  = alignmentFunction(context, alignedLowPoint);
            }
            CGPathMoveToPoint(path, NULL, alignedHighPoint.x, alignedHighPoint.y);
            CGPathAddLineToPoint(path, NULL, alignedLowPoint.x, alignedLowPoint.y);
        }

        // centre-right
        if ( !isnan(viewPoint->right)) {
            CGPoint alignedHighPoint = CPTPointMake(viewPoint->x + halfGapSize.width, viewPoint->y);
            CGPoint alignedLowPoint  = CPTPointMake(viewPoint->right, viewPoint->y);
            if ( alignPoints ) {
                alignedHighPoint = alignmentFunction(context, alignedHighPoint);
                alignedLowPoint  = alignmentFunction(context, alignedLowPoint);
            }
            CGPathMoveToPoint(path, NULL, alignedHighPoint.x, alignedHighPoint.y);
            CGPathAddLineToPoint(path, NULL, alignedLowPoint.x, alignedLowPoint.y);
        }

        // left bar
        if ( !isnan(viewPoint->left)) {
            CGPoint alignedHighPoint = CPTPointMake(viewPoint->left, viewPoint->y - halfBarWidth);
            CGPoint alignedLowPoint  = CPTPointMake(viewPoint->left, viewPoint->y + halfBarWidth);
            if ( alignPoints ) {
                alignedHighPoint = alignmentFunction(context, alignedHighPoint);
                alignedLowPoint  = alignmentFunction(context, alignedLowPoint);
            }
            CGPathMoveToPoint(path, NULL, alignedHighPoint.x, alignedHighPoint.y);
            CGPathAddLineToPoint(path, NULL, alignedLowPoint.x, alignedLowPoint.y);
        }

        // right bar
        if ( !isnan(viewPoint->right)) {
            CGPoint alignedHighPoint = CPTPointMake(viewPoint->right, viewPoint->y - halfBarWidth);
            CGPoint alignedLowPoint  = CPTPointMake(viewPoint->right, viewPoint->y + halfBarWidth);
            if ( alignPoints ) {
                alignedHighPoint = alignmentFunction(context, alignedHighPoint);
                alignedLowPoint  = alignmentFunction(context, alignedLowPoint);
            }
            CGPathMoveToPoint(path, NULL, alignedHighPoint.x, alignedHighPoint.y);
            CGPathAddLineToPoint(path, NULL, alignedLowPoint.x, alignedLowPoint.y);
        }

        CGContextBeginPath(context);
        CGContextAddPath(context, path);
        [lineStyle setLineStyleInContext:context];
        [lineStyle strokePathInContext:context];
        CGPathRelease(path);
    }
}

-(void)drawSwatchForLegend:(nonnull CPTLegend *)legend atIndex:(NSUInteger)idx inRect:(CGRect)rect inContext:(nonnull CGContextRef)context
{
    [super drawSwatchForLegend:legend atIndex:idx inRect:rect inContext:context];

    if ( self.drawLegendSwatchDecoration ) {
        CPTFill *theFill = self.areaFill;

        if ( theFill ) {
            CGContextBeginPath(context);
            CPTAddRoundedRectPath(context, CPTAlignIntegralRectToUserSpace(context, rect), legend.swatchCornerRadius);
            [theFill fillPathInContext:context];

            CPTLineStyle *lineStyle = self.areaBorderLineStyle;
            if ( lineStyle ) {
                CPTAddRoundedRectPath(context, CPTAlignIntegralRectToUserSpace(context, rect), legend.swatchCornerRadius);

                [lineStyle setLineStyleInContext:context];
                [lineStyle strokePathInContext:context];
            }
        }

        CPTLineStyle *theBarLineStyle = [self barLineStyleForIndex:idx];

        if ( [theBarLineStyle isKindOfClass:[CPTLineStyle class]] ) {
            CGPointError viewPoint;
            viewPoint.x     = CGRectGetMidX(rect);
            viewPoint.y     = CGRectGetMidY(rect);
            viewPoint.high  = CGRectGetMaxY(rect);
            viewPoint.low   = CGRectGetMinY(rect);
            viewPoint.left  = CGRectGetMinX(rect);
            viewPoint.right = CGRectGetMaxX(rect);

            [self drawRangeInContext:context
                           lineStyle:theBarLineStyle
                           viewPoint:&viewPoint
                         halfGapSize:CPTSizeMake(MIN(self.gapWidth, rect.size.width / CPTFloat(2.0)) * CPTFloat(0.5), MIN(self.gapHeight, rect.size.height / CPTFloat(2.0)) * CPTFloat(0.5))
                        halfBarWidth:MIN(MIN(self.barWidth, rect.size.width), rect.size.height) * CPTFloat(0.5)
                         alignPoints:YES];
        }
    }
}

-(nullable CPTLineStyle *)barLineStyleForIndex:(NSUInteger)idx
{
    CPTLineStyle *theBarLineStyle = [self cachedValueForKey:CPTRangePlotBindingBarLineStyles recordIndex:idx];

    if ((theBarLineStyle == nil) || (theBarLineStyle == [CPTPlot nilData])) {
        theBarLineStyle = self.barLineStyle;
    }

    return theBarLineStyle;
}

-(nonnull NSNumber *)barWidthForIndex:(NSUInteger)idx
{
    NSNumber *theBarWidth = [self cachedValueForKey:CPTRangePlotBindingBarWidths recordIndex:idx];

    if ((theBarWidth == nil) || (theBarWidth == [CPTPlot nilData])) {
        theBarWidth = @(self.barWidth);
    }

    return theBarWidth;
}

/// @endcond

#pragma mark -
#pragma mark Animation

/// @cond

+(BOOL)needsDisplayForKey:(nonnull NSString *)aKey
{
    static NSSet<NSString *> *keys   = nil;
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^{
        keys = [NSSet setWithArray:@[@"barWidth",
                                     @"gapHeight",
                                     @"gapWidth"]];
    });

    if ( [keys containsObject:aKey] ) {
        return YES;
    }
    else {
        return [super needsDisplayForKey:aKey];
    }
}

/// @endcond

#pragma mark -
#pragma mark Fields

/// @cond

-(NSUInteger)numberOfFields
{
    return 6;
}

-(nonnull CPTNumberArray *)fieldIdentifiers
{
    return @[@(CPTRangePlotFieldX),
             @(CPTRangePlotFieldY),
             @(CPTRangePlotFieldHigh),
             @(CPTRangePlotFieldLow),
             @(CPTRangePlotFieldLeft),
             @(CPTRangePlotFieldRight)];
}

-(nonnull CPTNumberArray *)fieldIdentifiersForCoordinate:(CPTCoordinate)coord
{
    CPTNumberArray *result = nil;

    switch ( coord ) {
        case CPTCoordinateX:
            result = @[@(CPTRangePlotFieldX)];
        break;

        case CPTCoordinateY:
            result = @[@(CPTRangePlotFieldY)];
        break;

        default:
            [NSException raise:CPTException format:@"Invalid coordinate passed to fieldIdentifiersForCoordinate:"];
            break;
    }
    return result;
}

-(CPTCoordinate)coordinateForFieldIdentifier:(NSUInteger)field
{
    CPTCoordinate coordinate = CPTCoordinateNone;

    switch ( field ) {
        case CPTRangePlotFieldX:
        case CPTRangePlotFieldLeft:
        case CPTRangePlotFieldRight:
            coordinate = CPTCoordinateX;
            break;

        case CPTRangePlotFieldY:
        case CPTRangePlotFieldHigh:
        case CPTRangePlotFieldLow:
            coordinate = CPTCoordinateY;
            break;

        default:
            break;
    }

    return coordinate;
}

/// @endcond

#pragma mark -
#pragma mark Data Labels

/// @cond

-(void)positionLabelAnnotation:(nonnull CPTPlotSpaceAnnotation *)label forIndex:(NSUInteger)idx
{
    NSNumber *xValue = [self cachedNumberForField:CPTRangePlotFieldX recordIndex:idx];
    NSNumber *yValue = [self cachedNumberForField:CPTRangePlotFieldY recordIndex:idx];

    BOOL positiveDirection = YES;
    CPTPlotRange *yRange   = [self.plotSpace plotRangeForCoordinate:CPTCoordinateY];

    if ( CPTDecimalLessThan(yRange.lengthDecimal, CPTDecimalFromInteger(0))) {
        positiveDirection = !positiveDirection;
    }

    label.anchorPlotPoint     = @[xValue, yValue];
    label.contentLayer.hidden = self.hidden || isnan([xValue doubleValue]) || isnan([yValue doubleValue]);

    if ( positiveDirection ) {
        label.displacement = CPTPointMake(0.0, self.labelOffset);
    }
    else {
        label.displacement = CPTPointMake(0.0, -self.labelOffset);
    }
}

/// @endcond

#pragma mark -
#pragma mark Responder Chain and User Interaction

/// @cond

-(NSUInteger)dataIndexFromInteractionPoint:(CGPoint)point
{
    NSUInteger dataCount     = self.cachedDataCount;
    CGPointError *viewPoints = calloc(dataCount, sizeof(CGPointError));
    BOOL *drawPointFlags     = calloc(dataCount, sizeof(BOOL));

    [self calculatePointsToDraw:drawPointFlags numberOfPoints:dataCount forPlotSpace:(CPTXYPlotSpace *)self.plotSpace];
    [self calculateViewPoints:viewPoints withDrawPointFlags:drawPointFlags numberOfPoints:dataCount];

    NSInteger result = [self extremeDrawnPointIndexForFlags:drawPointFlags numberOfPoints:dataCount extremeNumIsLowerBound:YES];
    if ( result != NSNotFound ) {
        CGPointError lastViewPoint;
        CGFloat minimumDistanceSquared = CPTNAN;
        for ( NSUInteger i = (NSUInteger)result; i < dataCount; ++i ) {
            if ( drawPointFlags[i] ) {
                lastViewPoint = viewPoints[i];
                CGPoint lastPoint       = CPTPointMake(lastViewPoint.x, lastViewPoint.y);
                CGFloat distanceSquared = squareOfDistanceBetweenPoints(point, lastPoint);
                if ( isnan(minimumDistanceSquared) || (distanceSquared < minimumDistanceSquared)) {
                    minimumDistanceSquared = distanceSquared;
                    result                 = (NSInteger)i;
                }
            }
        }
        if ( result != NSNotFound ) {
            lastViewPoint = viewPoints[result];

            if ( !isnan(lastViewPoint.left) && (point.x < lastViewPoint.left)) {
                result = NSNotFound;
            }
            if ( !isnan(lastViewPoint.right) && (point.x > lastViewPoint.right)) {
                result = NSNotFound;
            }
            if ( !isnan(lastViewPoint.high) && (point.y > lastViewPoint.high)) {
                result = NSNotFound;
            }
            if ( !isnan(lastViewPoint.low) && (point.y < lastViewPoint.low)) {
                result = NSNotFound;
            }
        }
    }

    free(viewPoints);
    free(drawPointFlags);

    return (NSUInteger)result;
}

/// @endcond

/// @name User Interaction
/// @{

/**
 *  @brief Informs the receiver that the user has
 *  @if MacOnly pressed the mouse button. @endif
 *  @if iOSOnly started touching the screen. @endif
 *
 *
 *  If this plot has a delegate that responds to the
 *  @link CPTRangePlotDelegate::rangePlot:rangeTouchDownAtRecordIndex: -rangePlot:rangeTouchDownAtRecordIndex: @endlink or
 *  @link CPTRangePlotDelegate::rangePlot:rangeTouchDownAtRecordIndex:withEvent: -rangePlot:rangeTouchDownAtRecordIndex:withEvent: @endlink
 *  methods, the @par{interactionPoint} is compared with each bar in index order.
 *  The delegate method will be called and this method returns @YES for the first
 *  index where the @par{interactionPoint} is inside a bar.
 *  This method returns @NO if the @par{interactionPoint} is outside all of the bars.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceDownEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    CPTGraph *theGraph       = self.graph;
    CPTPlotArea *thePlotArea = self.plotArea;

    if ( !theGraph || !thePlotArea || self.hidden ) {
        return NO;
    }

    id<CPTRangePlotDelegate> theDelegate = (id<CPTRangePlotDelegate>)self.delegate;
    if ( [theDelegate respondsToSelector:@selector(rangePlot:rangeTouchDownAtRecordIndex:)] ||
         [theDelegate respondsToSelector:@selector(rangePlot:rangeTouchDownAtRecordIndex:withEvent:)] ||
         [theDelegate respondsToSelector:@selector(rangePlot:rangeWasSelectedAtRecordIndex:)] ||
         [theDelegate respondsToSelector:@selector(rangePlot:rangeWasSelectedAtRecordIndex:withEvent:)] ) {
        // Inform delegate if a point was hit
        CGPoint plotAreaPoint = [theGraph convertPoint:interactionPoint toLayer:thePlotArea];
        NSUInteger idx        = [self dataIndexFromInteractionPoint:plotAreaPoint];
        self.pointingDeviceDownIndex = idx;

        if ( idx != NSNotFound ) {
            BOOL handled = NO;

            if ( [theDelegate respondsToSelector:@selector(rangePlot:rangeTouchDownAtRecordIndex:)] ) {
                handled = YES;
                [theDelegate rangePlot:self rangeTouchDownAtRecordIndex:idx];
            }

            if ( [theDelegate respondsToSelector:@selector(rangePlot:rangeTouchDownAtRecordIndex:withEvent:)] ) {
                handled = YES;
                [theDelegate rangePlot:self rangeTouchDownAtRecordIndex:idx withEvent:event];
            }

            if ( handled ) {
                return YES;
            }
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
 *  If this plot has a delegate that responds to the
 *  @link CPTRangePlotDelegate::rangePlot:rangeTouchUpAtRecordIndex: -rangePlot:rangeTouchUpAtRecordIndex: @endlink and/or
 *  @link CPTRangePlotDelegate::rangePlot:rangeTouchUpAtRecordIndex:withEvent: -rangePlot:rangeTouchUpAtRecordIndex:withEvent: @endlink
 *  methods, the @par{interactionPoint} is compared with each bar in index order.
 *  The delegate method will be called and this method returns @YES for the first
 *  index where the @par{interactionPoint} is inside a bar.
 *  This method returns @NO if the @par{interactionPoint} is outside all of the bars.
 *
 *  If the bar being released is the same as the one that was pressed (see
 *  @link CPTRangePlot::pointingDeviceDownEvent:atPoint: -pointingDeviceDownEvent:atPoint: @endlink), if the delegate responds to the
 *  @link CPTRangePlotDelegate::rangePlot:rangeWasSelectedAtRecordIndex: -rangePlot:rangeWasSelectedAtRecordIndex: @endlink and/or
 *  @link CPTRangePlotDelegate::rangePlot:rangeWasSelectedAtRecordIndex:withEvent: -rangePlot:rangeWasSelectedAtRecordIndex:withEvent: @endlink
 *  methods, these will be called.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceUpEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    NSUInteger selectedDownIndex = self.pointingDeviceDownIndex;

    self.pointingDeviceDownIndex = NSNotFound;

    CPTGraph *theGraph       = self.graph;
    CPTPlotArea *thePlotArea = self.plotArea;

    if ( !theGraph || !thePlotArea || self.hidden ) {
        return NO;
    }

    id<CPTRangePlotDelegate> theDelegate = (id<CPTRangePlotDelegate>)self.delegate;
    if ( [theDelegate respondsToSelector:@selector(rangePlot:rangeTouchUpAtRecordIndex:)] ||
         [theDelegate respondsToSelector:@selector(rangePlot:rangeTouchUpAtRecordIndex:withEvent:)] ||
         [theDelegate respondsToSelector:@selector(rangePlot:rangeWasSelectedAtRecordIndex:)] ||
         [theDelegate respondsToSelector:@selector(rangePlot:rangeWasSelectedAtRecordIndex:withEvent:)] ) {
        // Inform delegate if a point was hit
        CGPoint plotAreaPoint = [theGraph convertPoint:interactionPoint toLayer:thePlotArea];
        NSUInteger idx        = [self dataIndexFromInteractionPoint:plotAreaPoint];

        if ( idx != NSNotFound ) {
            BOOL handled = NO;

            if ( [theDelegate respondsToSelector:@selector(rangePlot:rangeTouchUpAtRecordIndex:)] ) {
                handled = YES;
                [theDelegate rangePlot:self rangeTouchUpAtRecordIndex:idx];
            }

            if ( [theDelegate respondsToSelector:@selector(rangePlot:rangeTouchUpAtRecordIndex:withEvent:)] ) {
                handled = YES;
                [theDelegate rangePlot:self rangeTouchUpAtRecordIndex:idx withEvent:event];
            }

            if ( idx == selectedDownIndex ) {
                if ( [theDelegate respondsToSelector:@selector(rangePlot:rangeWasSelectedAtRecordIndex:)] ) {
                    handled = YES;
                    [theDelegate rangePlot:self rangeWasSelectedAtRecordIndex:idx];
                }

                if ( [theDelegate respondsToSelector:@selector(rangePlot:rangeWasSelectedAtRecordIndex:withEvent:)] ) {
                    handled = YES;
                    [theDelegate rangePlot:self rangeWasSelectedAtRecordIndex:idx withEvent:event];
                }
            }

            if ( handled ) {
                return YES;
            }
        }
    }

    return [super pointingDeviceUpEvent:event atPoint:interactionPoint];
}

/// @}

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setBarLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    if ( barLineStyle != newLineStyle ) {
        barLineStyle = [newLineStyle copy];
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(void)setAreaFill:(nullable CPTFill *)newFill
{
    if ( newFill != areaFill ) {
        areaFill = [newFill copy];
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(void)setAreaBorderLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    if ( areaBorderLineStyle != newLineStyle ) {
        areaBorderLineStyle = [newLineStyle copy];
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(void)setBarWidth:(CGFloat)newBarWidth
{
    if ( barWidth != newBarWidth ) {
        barWidth = newBarWidth;
        [self setNeedsDisplay];
    }
}

-(void)setGapHeight:(CGFloat)newGapHeight
{
    if ( gapHeight != newGapHeight ) {
        gapHeight = newGapHeight;
        [self setNeedsDisplay];
    }
}

-(void)setGapWidth:(CGFloat)newGapWidth
{
    if ( gapWidth != newGapWidth ) {
        gapWidth = newGapWidth;
        [self setNeedsDisplay];
    }
}

-(void)setXValues:(nullable CPTNumberArray *)newValues
{
    [self cacheNumbers:newValues forField:CPTRangePlotFieldX];
}

-(nullable CPTNumberArray *)xValues
{
    return [[self cachedNumbersForField:CPTRangePlotFieldX] sampleArray];
}

-(void)setYValues:(nullable CPTNumberArray *)newValues
{
    [self cacheNumbers:newValues forField:CPTRangePlotFieldY];
}

-(nullable CPTNumberArray *)yValues
{
    return [[self cachedNumbersForField:CPTRangePlotFieldY] sampleArray];
}

-(nullable CPTMutableNumericData *)highValues
{
    return [self cachedNumbersForField:CPTRangePlotFieldHigh];
}

-(void)setHighValues:(nullable CPTMutableNumericData *)newValues
{
    [self cacheNumbers:newValues forField:CPTRangePlotFieldHigh];
}

-(nullable CPTMutableNumericData *)lowValues
{
    return [self cachedNumbersForField:CPTRangePlotFieldLow];
}

-(void)setLowValues:(nullable CPTMutableNumericData *)newValues
{
    [self cacheNumbers:newValues forField:CPTRangePlotFieldLow];
}

-(nullable CPTMutableNumericData *)leftValues
{
    return [self cachedNumbersForField:CPTRangePlotFieldLeft];
}

-(void)setLeftValues:(nullable CPTMutableNumericData *)newValues
{
    [self cacheNumbers:newValues forField:CPTRangePlotFieldLeft];
}

-(nullable CPTMutableNumericData *)rightValues
{
    return [self cachedNumbersForField:CPTRangePlotFieldRight];
}

-(void)setRightValues:(nullable CPTMutableNumericData *)newValues
{
    [self cacheNumbers:newValues forField:CPTRangePlotFieldRight];
}

-(nullable CPTLineStyleArray *)barLineStyles
{
    return [self cachedArrayForKey:CPTRangePlotBindingBarLineStyles];
}

-(void)setBarLineStyles:(nullable CPTLineStyleArray *)newLineStyles
{
    [self cacheArray:newLineStyles forKey:CPTRangePlotBindingBarLineStyles];
    [self setNeedsDisplay];
}

/// @endcond

@end

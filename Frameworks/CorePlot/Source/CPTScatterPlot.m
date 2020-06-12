#import "CPTScatterPlot.h"

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
#import <tgmath.h>

/** @defgroup plotAnimationScatterPlot Scatter Plot
 *  @brief Scatter plot properties that can be animated using Core Animation.
 *  @ingroup plotAnimation
 **/

/** @if MacOnly
 *  @defgroup plotBindingsScatterPlot Scatter Plot Bindings
 *  @brief Binding identifiers for scatter plots.
 *  @ingroup plotBindings
 *  @endif
 **/

CPTScatterPlotBinding const CPTScatterPlotBindingXValues     = @"xValues";     ///< X values.
CPTScatterPlotBinding const CPTScatterPlotBindingYValues     = @"yValues";     ///< Y values.
CPTScatterPlotBinding const CPTScatterPlotBindingPlotSymbols = @"plotSymbols"; ///< Plot symbols.

/// @cond
@interface CPTScatterPlot()

@property (nonatomic, readwrite, copy, nullable) CPTNumberArray *xValues;
@property (nonatomic, readwrite, copy, nullable) CPTNumberArray *yValues;
@property (nonatomic, readwrite, strong, nullable) CPTPlotSymbolArray *plotSymbols;
@property (nonatomic, readwrite, assign) NSUInteger pointingDeviceDownIndex;
@property (nonatomic, readwrite, assign) BOOL pointingDeviceDownOnLine;
@property (nonatomic, readwrite, strong) CPTMutableLimitBandArray *mutableAreaFillBands;

-(void)calculatePointsToDraw:(nonnull BOOL *)pointDrawFlags forPlotSpace:(nonnull CPTXYPlotSpace *)xyPlotSpace includeVisiblePointsOnly:(BOOL)visibleOnly numberOfPoints:(NSUInteger)dataCount;
-(void)calculateViewPoints:(nonnull CGPoint *)viewPoints withDrawPointFlags:(nonnull BOOL *)drawPointFlags numberOfPoints:(NSUInteger)dataCount;
-(void)alignViewPointsToUserSpace:(nonnull CGPoint *)viewPoints withContext:(nonnull CGContextRef)context drawPointFlags:(nonnull BOOL *)drawPointFlags numberOfPoints:(NSUInteger)dataCount;

-(NSInteger)extremeDrawnPointIndexForFlags:(nonnull BOOL *)pointDrawFlags numberOfPoints:(NSUInteger)dataCount extremeNumIsLowerBound:(BOOL)isLowerBound;

-(nonnull CGPathRef)newDataLinePathForViewPoints:(nonnull CGPoint *)viewPoints indexRange:(NSRange)indexRange baselineYValue:(CGFloat)baselineYValue;
-(nonnull CGPathRef)newCurvedDataLinePathForViewPoints:(nonnull CGPoint *)viewPoints indexRange:(NSRange)indexRange baselineYValue:(CGFloat)baselineYValue;
-(void)computeBezierControlPoints:(nonnull CGPoint *)cp1 points2:(nonnull CGPoint *)cp2 forViewPoints:(nonnull CGPoint *)viewPoints indexRange:(NSRange)indexRange;
-(void)computeCatmullRomControlPoints:(nonnull CGPoint *)points points2:(nonnull CGPoint *)points2 withAlpha:(CGFloat)alpha forViewPoints:(nonnull CGPoint *)viewPoints indexRange:(NSRange)indexRange;
-(void)computeHermiteControlPoints:(nonnull CGPoint *)points points2:(nonnull CGPoint *)points2 forViewPoints:(nonnull CGPoint *)viewPoints indexRange:(NSRange)indexRange;
-(BOOL)monotonicViewPoints:(nonnull CGPoint *)viewPoints indexRange:(NSRange)indexRange;

@end

/// @endcond

#pragma mark -

/**
 *  @brief A two-dimensional scatter plot.
 *  @see See @ref plotAnimationScatterPlot "Scatter Plot" for a list of animatable properties.
 *  @if MacOnly
 *  @see See @ref plotBindingsScatterPlot "Scatter Plot Bindings" for a list of supported binding identifiers.
 *  @endif
 **/
@implementation CPTScatterPlot

@dynamic xValues;
@dynamic yValues;
@dynamic plotSymbols;

/** @property CPTScatterPlotInterpolation interpolation
 *  @brief The interpolation algorithm used for lines between data points.
 *  Default is #CPTScatterPlotInterpolationLinear.
 **/
@synthesize interpolation;

/** @property CPTScatterPlotHistogramOption histogramOption
 *  @brief The drawing style for a histogram plot line (@ref interpolation = #CPTScatterPlotInterpolationHistogram).
 *  Default is #CPTScatterPlotHistogramNormal.
 **/
@synthesize histogramOption;

/** @property CPTScatterPlotCurvedInterpolationOption curvedInterpolationOption
 *  @brief The interpolation method used to generate the curved plot line (@ref interpolation = #CPTScatterPlotInterpolationCurved)
 *  Default is #CPTScatterPlotCurvedInterpolationNormal
 **/
@synthesize curvedInterpolationOption;

/** @property CGFloat curvedInterpolationCustomAlpha
 *  @brief The custom alpha value used when the #CPTScatterPlotCurvedInterpolationCatmullCustomAlpha interpolation is selected.
 *  Default is @num{0.5}.
 *  @note Must be between @num{0.0} and @num{1.0}.
 **/
@synthesize curvedInterpolationCustomAlpha;

/** @property nullable CPTLineStyle *dataLineStyle
 *  @brief The line style for the data line.
 *  If @nil, the line is not drawn.
 **/
@synthesize dataLineStyle;

/** @property nullable CPTPlotSymbol *plotSymbol
 *  @brief The plot symbol drawn at each point if the data source does not provide symbols.
 *  If @nil, no symbol is drawn.
 **/
@synthesize plotSymbol;

/** @property nullable CPTFill *areaFill
 *  @brief The fill style for the area underneath the data line.
 *  If @nil, the area is not filled.
 **/
@synthesize areaFill;

/** @property nullable CPTFill *areaFill2
 *  @brief The fill style for the area above the data line.
 *  If @nil, the area is not filled.
 **/
@synthesize areaFill2;

/** @property nullable NSNumber *areaBaseValue
 *  @brief The Y coordinate of the straight boundary of the area fill.
 *  If not a number, the area is not filled.
 *
 *  Typically set to the minimum value of the Y range, but it can be any value that gives the desired appearance.
 *
 *  @ingroup plotBindingsScatterPlot
 **/
@synthesize areaBaseValue;

/** @property nullable NSNumber *areaBaseValue2
 *  @brief The Y coordinate of the straight boundary of the secondary area fill.
 *  If not a number, the area is not filled.
 *
 *  Typically set to the maximum value of the Y range, but it can be any value that gives the desired appearance.
 *
 *  @ingroup plotBindingsScatterPlot
 **/
@synthesize areaBaseValue2;

/** @property CGFloat plotSymbolMarginForHitDetection
 *  @brief A margin added to each side of a symbol when determining whether it has been hit.
 *
 *  Default is zero. The margin is set in plot area view coordinates.
 **/
@synthesize plotSymbolMarginForHitDetection;

/** @property nonnull CGPathRef newDataLinePath
 *  @brief The path used to draw the data line. The caller must release the returned path.
 **/
@dynamic newDataLinePath;

/** @property CGFloat plotLineMarginForHitDetection
 *  @brief A margin added to each side of a plot line when determining whether it has been hit.
 *
 *  Default is four points to each side of the line. The margin is set in plot area view coordinates.
 **/
@synthesize plotLineMarginForHitDetection;

/** @property BOOL allowSimultaneousSymbolAndPlotSelection
 *  @brief @YES if both symbol selection and line selection can happen on the same upEvent. If @NO
 *  then when an upEvent occurs on a symbol only the symbol will be selected, otherwise the line
 *  will be selected if the upEvent occured on the line.
 *
 *  Default is @NO.
 **/
@synthesize allowSimultaneousSymbolAndPlotSelection;

/** @internal
 *  @property NSUInteger pointingDeviceDownIndex
 *  @brief The index that was selected on the pointing device down event.
 **/
@synthesize pointingDeviceDownIndex;

/** @internal
 *  @property BOOL pointingDeviceDownOnLine
 *  @brief @YES if the pointing device down event occured on the plot line.
 **/
@synthesize pointingDeviceDownOnLine;

/** @property nullable CPTLimitBandArray *areaFillBands
 *  @brief An array of CPTLimitBand objects.
 *
 *  The limit bands are drawn between the plot line and areaBaseValue and on top of the areaFill.
 **/
@dynamic areaFillBands;

@synthesize mutableAreaFillBands;

#pragma mark -
#pragma mark Init/Dealloc

/// @cond

#if TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
#else
+(void)initialize
{
    if ( self == [CPTScatterPlot class] ) {
        [self exposeBinding:CPTScatterPlotBindingXValues];
        [self exposeBinding:CPTScatterPlotBindingYValues];
        [self exposeBinding:CPTScatterPlotBindingPlotSymbols];
    }
}

#endif

/// @endcond

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTScatterPlot object with the provided frame rectangle.
 *
 *  This is the designated initializer. The initialized layer will have the following properties:
 *  - @ref dataLineStyle = default line style
 *  - @ref plotSymbol = @nil
 *  - @ref areaFill = @nil
 *  - @ref areaFill2 = @nil
 *  - @ref areaBaseValue = @NAN
 *  - @ref areaBaseValue2 = @NAN
 *  - @ref plotSymbolMarginForHitDetection = @num{0.0}
 *  - @ref plotLineMarginForHitDetection = @num{4.0}
 *  - @ref allowSimultaneousSymbolAndPlotSelection = NO
 *  - @ref interpolation = #CPTScatterPlotInterpolationLinear
 *  - @ref histogramOption = #CPTScatterPlotHistogramNormal
 *  - @ref curvedInterpolationOption = #CPTScatterPlotCurvedInterpolationNormal
 *  - @ref curvedInterpolationCustomAlpha = @num{0.5}
 *  - @ref labelField = #CPTScatterPlotFieldY
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTScatterPlot object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame
{
    if ((self = [super initWithFrame:newFrame])) {
        dataLineStyle                   = [[CPTLineStyle alloc] init];
        plotSymbol                      = nil;
        areaFill                        = nil;
        areaFill2                       = nil;
        areaBaseValue                   = @(NAN);
        areaBaseValue2                  = @(NAN);
        plotSymbolMarginForHitDetection = CPTFloat(0.0);
        plotLineMarginForHitDetection   = CPTFloat(4.0);
        interpolation                   = CPTScatterPlotInterpolationLinear;
        histogramOption                 = CPTScatterPlotHistogramNormal;
        curvedInterpolationOption       = CPTScatterPlotCurvedInterpolationNormal;
        curvedInterpolationCustomAlpha  = CPTFloat(0.5);
        pointingDeviceDownIndex         = NSNotFound;
        pointingDeviceDownOnLine        = NO;
        mutableAreaFillBands            = nil;
        self.labelField                 = CPTScatterPlotFieldY;
    }
    return self;
}

/// @}

/// @cond

-(nonnull instancetype)initWithLayer:(nonnull id)layer
{
    if ((self = [super initWithLayer:layer])) {
        CPTScatterPlot *theLayer = (CPTScatterPlot *)layer;

        dataLineStyle                           = theLayer->dataLineStyle;
        plotSymbol                              = theLayer->plotSymbol;
        areaFill                                = theLayer->areaFill;
        areaFill2                               = theLayer->areaFill2;
        areaBaseValue                           = theLayer->areaBaseValue;
        areaBaseValue2                          = theLayer->areaBaseValue2;
        plotSymbolMarginForHitDetection         = theLayer->plotSymbolMarginForHitDetection;
        plotLineMarginForHitDetection           = theLayer->plotLineMarginForHitDetection;
        allowSimultaneousSymbolAndPlotSelection = theLayer->allowSimultaneousSymbolAndPlotSelection;
        interpolation                           = theLayer->interpolation;
        histogramOption                         = theLayer->histogramOption;
        curvedInterpolationOption               = theLayer->curvedInterpolationOption;
        curvedInterpolationCustomAlpha          = theLayer->curvedInterpolationCustomAlpha;
        mutableAreaFillBands                    = theLayer->mutableAreaFillBands;
        pointingDeviceDownIndex                 = NSNotFound;
        pointingDeviceDownOnLine                = NO;
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

    [coder encodeInteger:self.interpolation forKey:@"CPTScatterPlot.interpolation"];
    [coder encodeInteger:self.histogramOption forKey:@"CPTScatterPlot.histogramOption"];
    [coder encodeInteger:self.curvedInterpolationOption forKey:@"CPTScatterPlot.curvedInterpolationOption"];
    [coder encodeCGFloat:self.curvedInterpolationCustomAlpha forKey:@"CPTScatterPlot.curvedInterpolationCustomAlpha"];
    [coder encodeObject:self.dataLineStyle forKey:@"CPTScatterPlot.dataLineStyle"];
    [coder encodeObject:self.plotSymbol forKey:@"CPTScatterPlot.plotSymbol"];
    [coder encodeObject:self.areaFill forKey:@"CPTScatterPlot.areaFill"];
    [coder encodeObject:self.areaFill2 forKey:@"CPTScatterPlot.areaFill2"];
    [coder encodeObject:self.mutableAreaFillBands forKey:@"CPTScatterPlot.mutableAreaFillBands"];
    [coder encodeObject:self.areaBaseValue forKey:@"CPTScatterPlot.areaBaseValue"];
    [coder encodeObject:self.areaBaseValue2 forKey:@"CPTScatterPlot.areaBaseValue2"];
    [coder encodeCGFloat:self.plotSymbolMarginForHitDetection forKey:@"CPTScatterPlot.plotSymbolMarginForHitDetection"];
    [coder encodeCGFloat:self.plotLineMarginForHitDetection forKey:@"CPTScatterPlot.plotLineMarginForHitDetection"];
    [coder encodeBool:self.allowSimultaneousSymbolAndPlotSelection forKey:@"CPTScatterPlot.allowSimultaneousSymbolAndPlotSelection"];

    // No need to archive these properties:
    // pointingDeviceDownIndex
    // pointingDeviceDownOnLine
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        interpolation                  = (CPTScatterPlotInterpolation)[coder decodeIntegerForKey:@"CPTScatterPlot.interpolation"];
        histogramOption                = (CPTScatterPlotHistogramOption)[coder decodeIntegerForKey:@"CPTScatterPlot.histogramOption"];
        curvedInterpolationOption      = (CPTScatterPlotCurvedInterpolationOption)[coder decodeIntegerForKey:@"CPTScatterPlot.curvedInterpolationOption"];
        curvedInterpolationCustomAlpha = [coder decodeCGFloatForKey:@"CPTScatterPlot.curvedInterpolationCustomAlpha"];
        dataLineStyle                  = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                                              forKey:@"CPTScatterPlot.dataLineStyle"] copy];
        plotSymbol = [[coder decodeObjectOfClass:[CPTPlotSymbol class]
                                          forKey:@"CPTScatterPlot.plotSymbol"] copy];
        areaFill = [[coder decodeObjectOfClass:[CPTFill class]
                                        forKey:@"CPTScatterPlot.areaFill"] copy];
        areaFill2 = [[coder decodeObjectOfClass:[CPTFill class]
                                         forKey:@"CPTScatterPlot.areaFill2"] copy];
        mutableAreaFillBands = [[coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [CPTLimitBand class]]]
                                                      forKey:@"CPTScatterPlot.mutableAreaFillBands"] mutableCopy];
        areaBaseValue = [coder decodeObjectOfClass:[NSNumber class]
                                            forKey:@"CPTScatterPlot.areaBaseValue"];
        areaBaseValue2 = [coder decodeObjectOfClass:[NSNumber class]
                                             forKey:@"CPTScatterPlot.areaBaseValue2"];
        plotSymbolMarginForHitDetection         = [coder decodeCGFloatForKey:@"CPTScatterPlot.plotSymbolMarginForHitDetection"];
        plotLineMarginForHitDetection           = [coder decodeCGFloatForKey:@"CPTScatterPlot.plotLineMarginForHitDetection"];
        allowSimultaneousSymbolAndPlotSelection = [coder decodeBoolForKey:@"CPTScatterPlot.allowSimultaneousSymbolAndPlotSelection"];
        pointingDeviceDownIndex                 = NSNotFound;
        pointingDeviceDownOnLine                = NO;
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
#pragma mark Data Loading

/// @cond

-(void)reloadDataInIndexRange:(NSRange)indexRange
{
    [super reloadDataInIndexRange:indexRange];

    // Update plot symbols
    [self reloadPlotSymbolsInIndexRange:indexRange];
}

-(void)reloadPlotDataInIndexRange:(NSRange)indexRange
{
    [super reloadPlotDataInIndexRange:indexRange];

    if ( ![self loadNumbersForAllFieldsFromDataSourceInRecordIndexRange:indexRange] ) {
        id<CPTScatterPlotDataSource> theDataSource = (id<CPTScatterPlotDataSource>)self.dataSource;

        if ( theDataSource ) {
            id newXValues = [self numbersFromDataSourceForField:CPTScatterPlotFieldX recordIndexRange:indexRange];
            [self cacheNumbers:newXValues forField:CPTScatterPlotFieldX atRecordIndex:indexRange.location];
            id newYValues = [self numbersFromDataSourceForField:CPTScatterPlotFieldY recordIndexRange:indexRange];
            [self cacheNumbers:newYValues forField:CPTScatterPlotFieldY atRecordIndex:indexRange.location];
        }
    }
}

/// @endcond

/**
 *  @brief Reload all plot symbols from the data source immediately.
 **/
-(void)reloadPlotSymbols
{
    [self reloadPlotSymbolsInIndexRange:NSMakeRange(0, self.cachedDataCount)];
}

/** @brief Reload plot symbols in the given index range from the data source immediately.
 *  @param indexRange The index range to load.
 **/
-(void)reloadPlotSymbolsInIndexRange:(NSRange)indexRange
{
    id<CPTScatterPlotDataSource> theDataSource = (id<CPTScatterPlotDataSource>)self.dataSource;

    BOOL needsLegendUpdate = NO;

    if ( [theDataSource respondsToSelector:@selector(symbolsForScatterPlot:recordIndexRange:)] ) {
        needsLegendUpdate = YES;

        [self cacheArray:[theDataSource symbolsForScatterPlot:self recordIndexRange:indexRange]
                  forKey:CPTScatterPlotBindingPlotSymbols
           atRecordIndex:indexRange.location];
    }
    else if ( [theDataSource respondsToSelector:@selector(symbolForScatterPlot:recordIndex:)] ) {
        needsLegendUpdate = YES;

        id nilObject                     = [CPTPlot nilData];
        CPTMutablePlotSymbolArray *array = [[NSMutableArray alloc] initWithCapacity:indexRange.length];
        NSUInteger maxIndex              = NSMaxRange(indexRange);

        for ( NSUInteger idx = indexRange.location; idx < maxIndex; idx++ ) {
            CPTPlotSymbol *symbol = [theDataSource symbolForScatterPlot:self recordIndex:idx];
            if ( symbol ) {
                [array addObject:symbol];
            }
            else {
                [array addObject:nilObject];
            }
        }

        [self cacheArray:array forKey:CPTScatterPlotBindingPlotSymbols atRecordIndex:indexRange.location];
    }

    // Legend
    if ( needsLegendUpdate ) {
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }

    [self setNeedsDisplay];
}

#pragma mark -
#pragma mark Symbols

/** @brief Returns the plot symbol to use for a given index.
 *  @param idx The index of the record.
 *  @return The plot symbol to use, or @nil if no plot symbol should be drawn.
 **/
-(nullable CPTPlotSymbol *)plotSymbolForRecordIndex:(NSUInteger)idx
{
    CPTPlotSymbol *symbol = [self cachedValueForKey:CPTScatterPlotBindingPlotSymbols recordIndex:idx];

    if ((symbol == nil) || (symbol == [CPTPlot nilData])) {
        symbol = self.plotSymbol;
    }

    return symbol;
}

#pragma mark -
#pragma mark Determining Which Points to Draw

/// @cond

-(void)calculatePointsToDraw:(nonnull BOOL *)pointDrawFlags forPlotSpace:(nonnull CPTXYPlotSpace *)xyPlotSpace includeVisiblePointsOnly:(BOOL)visibleOnly numberOfPoints:(NSUInteger)dataCount
{
    if ( dataCount == 0 ) {
        return;
    }

    CPTLineStyle *lineStyle = self.dataLineStyle;

    if ( self.areaFill || self.areaFill2 || lineStyle.dashPattern || lineStyle.lineFill || (self.interpolation == CPTScatterPlotInterpolationCurved)) {
        // show all points to preserve the line dash and area fills
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
            const double *xBytes = (const double *)[self cachedNumbersForField:CPTScatterPlotFieldX].data.bytes;
            const double *yBytes = (const double *)[self cachedNumbersForField:CPTScatterPlotFieldY].data.bytes;

            dispatch_apply(dataCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
                const double x = xBytes[i];
                const double y = yBytes[i];

                CPTPlotRangeComparisonResult xFlag = [xRange compareToDouble:x];
                xRangeFlags[i]                     = xFlag;
                if ( xFlag != CPTPlotRangeComparisonResultNumberInRange ) {
                    yRangeFlags[i] = CPTPlotRangeComparisonResultNumberInRange; // if x is out of range, then y doesn't matter
                }
                else {
                    yRangeFlags[i] = [yRange compareToDouble:y];
                }
                nanFlags[i] = isnan(x) || isnan(y);
            });
        }
        else {
            // Determine where each point lies in relation to range
            const NSDecimal *xBytes = (const NSDecimal *)[self cachedNumbersForField:CPTScatterPlotFieldX].data.bytes;
            const NSDecimal *yBytes = (const NSDecimal *)[self cachedNumbersForField:CPTScatterPlotFieldY].data.bytes;

            dispatch_apply(dataCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
                const NSDecimal x = xBytes[i];
                const NSDecimal y = yBytes[i];

                CPTPlotRangeComparisonResult xFlag = [xRange compareToDecimal:x];
                xRangeFlags[i]                     = xFlag;
                if ( xFlag != CPTPlotRangeComparisonResultNumberInRange ) {
                    yRangeFlags[i] = CPTPlotRangeComparisonResultNumberInRange; // if x is out of range, then y doesn't matter
                }
                else {
                    yRangeFlags[i] = [yRange compareToDecimal:y];
                }

                nanFlags[i] = NSDecimalIsNotANumber(&x) || NSDecimalIsNotANumber(&y);
            });
        }

        // Ensure that whenever the path crosses over a region boundary, both points
        // are included. This ensures no lines are left out that shouldn't be.
        CPTScatterPlotInterpolation theInterpolation = self.interpolation;

        memset(pointDrawFlags, NO, dataCount * sizeof(BOOL));
        if ( dataCount > 0 ) {
            pointDrawFlags[0] = (xRangeFlags[0] == CPTPlotRangeComparisonResultNumberInRange &&
                                 yRangeFlags[0] == CPTPlotRangeComparisonResultNumberInRange &&
                                 !nanFlags[0]);
        }
        if ( visibleOnly ) {
            for ( NSUInteger i = 1; i < dataCount; i++ ) {
                if ((xRangeFlags[i] == CPTPlotRangeComparisonResultNumberInRange) &&
                    (yRangeFlags[i] == CPTPlotRangeComparisonResultNumberInRange) &&
                    !nanFlags[i] ) {
                    pointDrawFlags[i] = YES;
                }
            }
        }
        else {
            switch ( theInterpolation ) {
                case CPTScatterPlotInterpolationCurved:
                    // Keep 2 points outside of the visible area on each side to maintain the correct curvature of the line
                    if ( dataCount > 1 ) {
                        if ( !nanFlags[0] && !nanFlags[1] && ((xRangeFlags[0] != xRangeFlags[1]) || (yRangeFlags[0] != yRangeFlags[1]))) {
                            pointDrawFlags[0] = YES;
                            pointDrawFlags[1] = YES;
                        }
                        else if ((xRangeFlags[1] == CPTPlotRangeComparisonResultNumberInRange) &&
                                 (yRangeFlags[1] == CPTPlotRangeComparisonResultNumberInRange) &&
                                 !nanFlags[1] ) {
                            pointDrawFlags[1] = YES;
                        }
                    }

                    for ( NSUInteger i = 2; i < dataCount; i++ ) {
                        if ( !nanFlags[i - 2] && !nanFlags[i - 1] && !nanFlags[i] ) {
                            pointDrawFlags[i - 2] = YES;
                            pointDrawFlags[i - 1] = YES;
                            pointDrawFlags[i]     = YES;
                        }
                        else if ( !nanFlags[i - 1] && !nanFlags[i] && ((xRangeFlags[i - 1] != xRangeFlags[i]) || (yRangeFlags[i - 1] != yRangeFlags[i]))) {
                            pointDrawFlags[i - 2] = YES;
                            pointDrawFlags[i - 1] = YES;
                            pointDrawFlags[i]     = YES;
                        }
                        else if ((xRangeFlags[i] == CPTPlotRangeComparisonResultNumberInRange) &&
                                 (yRangeFlags[i] == CPTPlotRangeComparisonResultNumberInRange) &&
                                 !nanFlags[i] ) {
                            pointDrawFlags[i] = YES;
                        }
                    }
                    break;

                default:
                    // Keep 1 point outside of the visible area on each side
                    for ( NSUInteger i = 1; i < dataCount; i++ ) {
                        if ( !nanFlags[i - 1] && !nanFlags[i] && ((xRangeFlags[i - 1] != xRangeFlags[i]) || (yRangeFlags[i - 1] != yRangeFlags[i]))) {
                            pointDrawFlags[i - 1] = YES;
                            pointDrawFlags[i]     = YES;
                        }
                        else if ((xRangeFlags[i] == CPTPlotRangeComparisonResultNumberInRange) &&
                                 (yRangeFlags[i] == CPTPlotRangeComparisonResultNumberInRange) &&
                                 !nanFlags[i] ) {
                            pointDrawFlags[i] = YES;
                        }
                    }
                    break;
            }
        }

        free(xRangeFlags);
        free(yRangeFlags);
        free(nanFlags);
    }
}

-(void)calculateViewPoints:(nonnull CGPoint *)viewPoints withDrawPointFlags:(nonnull BOOL *)drawPointFlags numberOfPoints:(NSUInteger)dataCount
{
    CPTPlotSpace *thePlotSpace = self.plotSpace;

    // Calculate points
    if ( self.doublePrecisionCache ) {
        const double *xBytes = (const double *)[self cachedNumbersForField:CPTScatterPlotFieldX].data.bytes;
        const double *yBytes = (const double *)[self cachedNumbersForField:CPTScatterPlotFieldY].data.bytes;

        dispatch_apply(dataCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
            const double x = xBytes[i];
            const double y = yBytes[i];
            if ( !drawPointFlags[i] || isnan(x) || isnan(y)) {
                viewPoints[i] = CPTPointMake(NAN, NAN);
            }
            else {
                double plotPoint[2];
                plotPoint[CPTCoordinateX] = x;
                plotPoint[CPTCoordinateY] = y;

                viewPoints[i] = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
            }
        });
    }
    else {
        CPTMutableNumericData *xData = [self cachedNumbersForField:CPTScatterPlotFieldX];
        CPTMutableNumericData *yData = [self cachedNumbersForField:CPTScatterPlotFieldY];

        const NSDecimal *xBytes = (const NSDecimal *)xData.data.bytes;
        const NSDecimal *yBytes = (const NSDecimal *)yData.data.bytes;

        dispatch_apply(dataCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
            const NSDecimal x = xBytes[i];
            const NSDecimal y = yBytes[i];
            if ( !drawPointFlags[i] || NSDecimalIsNotANumber(&x) || NSDecimalIsNotANumber(&y)) {
                viewPoints[i] = CPTPointMake(NAN, NAN);
            }
            else {
                NSDecimal plotPoint[2];
                plotPoint[CPTCoordinateX] = x;
                plotPoint[CPTCoordinateY] = y;

                viewPoints[i] = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
            }
        });
    }
}

-(void)alignViewPointsToUserSpace:(nonnull CGPoint *)viewPoints withContext:(nonnull CGContextRef)context drawPointFlags:(nonnull BOOL *)drawPointFlags numberOfPoints:(NSUInteger)dataCount
{
    // Align to device pixels if there is a data line.
    // Otherwise, align to view space, so fills are sharp at edges.
    if ( self.dataLineStyle.lineWidth > CPTFloat(0.0)) {
        dispatch_apply(dataCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
            if ( drawPointFlags[i] ) {
                viewPoints[i] = CPTAlignPointToUserSpace(context, viewPoints[i]);
            }
        });
    }
    else {
        dispatch_apply(dataCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
            if ( drawPointFlags[i] ) {
                viewPoints[i] = CPTAlignIntegralPointToUserSpace(context, viewPoints[i]);
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
#pragma mark View Points

/// @cond

-(NSUInteger)dataIndexFromInteractionPoint:(CGPoint)point
{
    return [self indexOfVisiblePointClosestToPlotAreaPoint:point];
}

/// @endcond

/** @brief Returns the index of the closest visible point to the point passed in.
 *  @param viewPoint The reference point.
 *  @return The index of the closest point, or @ref NSNotFound if there is no visible point.
 **/
-(NSUInteger)indexOfVisiblePointClosestToPlotAreaPoint:(CGPoint)viewPoint
{
    NSUInteger dataCount = self.cachedDataCount;
    CGPoint *viewPoints  = calloc(dataCount, sizeof(CGPoint));
    BOOL *drawPointFlags = calloc(dataCount, sizeof(BOOL));

    [self calculatePointsToDraw:drawPointFlags forPlotSpace:(CPTXYPlotSpace *)self.plotSpace includeVisiblePointsOnly:YES numberOfPoints:dataCount];
    [self calculateViewPoints:viewPoints withDrawPointFlags:drawPointFlags numberOfPoints:dataCount];

    NSInteger result = [self extremeDrawnPointIndexForFlags:drawPointFlags numberOfPoints:dataCount extremeNumIsLowerBound:YES];
    if ( result != NSNotFound ) {
        CGFloat minimumDistanceSquared = CPTNAN;
        for ( NSUInteger i = (NSUInteger)result; i < dataCount; ++i ) {
            if ( drawPointFlags[i] ) {
                CGFloat distanceSquared = squareOfDistanceBetweenPoints(viewPoint, viewPoints[i]);
                if ( isnan(minimumDistanceSquared) || (distanceSquared < minimumDistanceSquared)) {
                    minimumDistanceSquared = distanceSquared;
                    result                 = (NSInteger)i;
                }
            }
        }
    }

    free(viewPoints);
    free(drawPointFlags);

    return (NSUInteger)result;
}

/** @brief Returns the plot area view point of a visible point.
 *  @param idx The index of the point.
 *  @return The view point of the visible point at the index passed.
 **/
-(CGPoint)plotAreaPointOfVisiblePointAtIndex:(NSUInteger)idx
{
    NSParameterAssert(idx < self.cachedDataCount);

    CPTXYPlotSpace *thePlotSpace = (CPTXYPlotSpace *)self.plotSpace;
    CGPoint viewPoint;

    if ( self.doublePrecisionCache ) {
        double plotPoint[2];
        plotPoint[CPTScatterPlotFieldX] = [self cachedDoubleForField:CPTScatterPlotFieldX recordIndex:idx];
        plotPoint[CPTScatterPlotFieldY] = [self cachedDoubleForField:CPTScatterPlotFieldY recordIndex:idx];

        viewPoint = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
    }
    else {
        NSDecimal plotPoint[2];
        plotPoint[CPTScatterPlotFieldX] = [self cachedDecimalForField:CPTScatterPlotFieldX recordIndex:idx];
        plotPoint[CPTScatterPlotFieldY] = [self cachedDecimalForField:CPTScatterPlotFieldY recordIndex:idx];

        viewPoint = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
    }

    return viewPoint;
}

#pragma mark -
#pragma mark Drawing

/// @cond

-(void)renderAsVectorInContext:(nonnull CGContextRef)context
{
    if ( self.hidden ) {
        return;
    }

    CPTMutableNumericData *xValueData = [self cachedNumbersForField:CPTScatterPlotFieldX];
    CPTMutableNumericData *yValueData = [self cachedNumbersForField:CPTScatterPlotFieldY];

    if ((xValueData == nil) || (yValueData == nil)) {
        return;
    }
    NSUInteger dataCount = self.cachedDataCount;
    if ( dataCount == 0 ) {
        return;
    }
    if ( !(self.dataLineStyle || self.areaFill || self.areaFill2 || self.plotSymbol || self.plotSymbols.count)) {
        return;
    }
    if ( xValueData.numberOfSamples != yValueData.numberOfSamples ) {
        [NSException raise:CPTException format:@"Number of x and y values do not match"];
    }

    [super renderAsVectorInContext:context];

    // Calculate view points, and align to user space
    CGPoint *viewPoints  = calloc(dataCount, sizeof(CGPoint));
    BOOL *drawPointFlags = calloc(dataCount, sizeof(BOOL));

    CPTXYPlotSpace *thePlotSpace = (CPTXYPlotSpace *)self.plotSpace;
    [self calculatePointsToDraw:drawPointFlags forPlotSpace:thePlotSpace includeVisiblePointsOnly:NO numberOfPoints:dataCount];
    [self calculateViewPoints:viewPoints withDrawPointFlags:drawPointFlags numberOfPoints:dataCount];

    BOOL pixelAlign = self.alignsPointsToPixels;
    if ( pixelAlign ) {
        [self alignViewPointsToUserSpace:viewPoints withContext:context drawPointFlags:drawPointFlags numberOfPoints:dataCount];
    }

    // Get extreme points
    NSInteger lastDrawnPointIndex  = [self extremeDrawnPointIndexForFlags:drawPointFlags numberOfPoints:dataCount extremeNumIsLowerBound:NO];
    NSInteger firstDrawnPointIndex = [self extremeDrawnPointIndexForFlags:drawPointFlags numberOfPoints:dataCount extremeNumIsLowerBound:YES];

    if ( firstDrawnPointIndex != NSNotFound ) {
        NSRange viewIndexRange = NSMakeRange((NSUInteger)firstDrawnPointIndex, (NSUInteger)(lastDrawnPointIndex - firstDrawnPointIndex + 1));

        CPTPlotArea *thePlotArea            = self.plotArea;
        CPTLineStyle *theLineStyle          = self.dataLineStyle;
        CPTMutableLimitBandArray *fillBands = self.mutableAreaFillBands;

        // Draw fills
        NSDecimal theAreaBaseValue;
        CPTFill *theFill = nil;

        for ( NSUInteger i = 0; i < 2; i++ ) {
            switch ( i ) {
                case 0:
                    theAreaBaseValue = self.areaBaseValue.decimalValue;
                    theFill          = self.areaFill;
                    break;

                case 1:
                    theAreaBaseValue = self.areaBaseValue2.decimalValue;
                    theFill          = self.areaFill2;
                    break;

                default:
                    theAreaBaseValue = CPTDecimalNaN();
                    break;
            }
            if ( !NSDecimalIsNotANumber(&theAreaBaseValue)) {
                if ( theFill || ((i == 0) && fillBands)) {
                    // clear the plot shadow if any--not needed for fills when the plot has a data line
                    if ( theLineStyle ) {
                        CGContextSaveGState(context);
                        CGContextSetShadowWithColor(context, CGSizeZero, CPTFloat(0.0), NULL);
                    }

                    NSNumber *xValue = [xValueData sampleValue:(NSUInteger)firstDrawnPointIndex];
                    NSDecimal plotPoint[2];
                    plotPoint[CPTCoordinateX] = xValue.decimalValue;
                    plotPoint[CPTCoordinateY] = theAreaBaseValue;
                    CGPoint baseLinePoint = [self convertPoint:[thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2] fromLayer:thePlotArea];
                    if ( pixelAlign ) {
                        baseLinePoint = CPTAlignIntegralPointToUserSpace(context, baseLinePoint);
                    }

                    CGPathRef dataLinePath = [self newDataLinePathForViewPoints:viewPoints indexRange:viewIndexRange baselineYValue:baseLinePoint.y];

                    if ( theFill ) {
                        CGContextBeginPath(context);
                        CGContextAddPath(context, dataLinePath);
                        [theFill fillPathInContext:context];
                    }

                    // Draw fill bands
                    if ((i == 0) && fillBands ) {
                        CGFloat height = CPTFloat(CGBitmapContextGetHeight(context));

                        for ( CPTLimitBand *band in fillBands ) {
                            CGContextSaveGState(context);

                            CPTPlotRange *bandRange = band.range;

                            plotPoint[CPTCoordinateX] = bandRange.minLimitDecimal;
                            CGPoint minPoint = [self convertPoint:[thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2] fromLayer:thePlotArea];

                            plotPoint[CPTCoordinateX] = bandRange.maxLimitDecimal;
                            CGPoint maxPoint = [self convertPoint:[thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2] fromLayer:thePlotArea];

                            if ( pixelAlign ) {
                                minPoint = CPTAlignIntegralPointToUserSpace(context, minPoint);
                                maxPoint = CPTAlignIntegralPointToUserSpace(context, maxPoint);
                            }

                            CGContextClipToRect(context, CGRectMake(minPoint.x, 0.0, maxPoint.x - minPoint.x, height));

                            CGContextBeginPath(context);
                            CGContextAddPath(context, dataLinePath);
                            [band.fill fillPathInContext:context];

                            CGContextRestoreGState(context);
                        }
                    }

                    CGPathRelease(dataLinePath);

                    if ( theLineStyle ) {
                        CGContextRestoreGState(context);
                    }
                }
            }
        }

        // Draw line
        if ( theLineStyle ) {
            CGPathRef dataLinePath = [self newDataLinePathForViewPoints:viewPoints indexRange:viewIndexRange baselineYValue:CPTNAN];

            // Give the delegate a chance to prepare for the drawing.
            id<CPTScatterPlotDelegate> theDelegate = (id<CPTScatterPlotDelegate>)self.delegate;
            if ( [theDelegate respondsToSelector:@selector(scatterPlot:prepareForDrawingPlotLine:inContext:)] ) {
                [theDelegate scatterPlot:self prepareForDrawingPlotLine:dataLinePath inContext:context];
            }

            CGContextBeginPath(context);
            CGContextAddPath(context, dataLinePath);
            [theLineStyle setLineStyleInContext:context];
            [theLineStyle strokePathInContext:context];
            CGPathRelease(dataLinePath);
        }

        // Draw plot symbols
        if ( self.plotSymbol || self.plotSymbols.count ) {
            Class symbolClass = [CPTPlotSymbol class];

            // clear the plot shadow if any--symbols draw their own shadows
            CGContextSetShadowWithColor(context, CGSizeZero, CPTFloat(0.0), NULL);

            if ( self.useFastRendering ) {
                CGFloat scale = self.contentsScale;
                for ( NSUInteger i = (NSUInteger)firstDrawnPointIndex; i <= (NSUInteger)lastDrawnPointIndex; i++ ) {
                    if ( drawPointFlags[i] ) {
                        CPTPlotSymbol *currentSymbol = [self plotSymbolForRecordIndex:i];
                        if ( [currentSymbol isKindOfClass:symbolClass] ) {
                            [currentSymbol renderInContext:context atPoint:viewPoints[i] scale:scale alignToPixels:pixelAlign];
                        }
                    }
                }
            }
            else {
                for ( NSUInteger i = (NSUInteger)firstDrawnPointIndex; i <= (NSUInteger)lastDrawnPointIndex; i++ ) {
                    if ( drawPointFlags[i] ) {
                        CPTPlotSymbol *currentSymbol = [self plotSymbolForRecordIndex:i];
                        if ( [currentSymbol isKindOfClass:symbolClass] ) {
                            [currentSymbol renderAsVectorInContext:context atPoint:viewPoints[i] scale:CPTFloat(1.0)];
                        }
                    }
                }
            }
        }
    }

    free(viewPoints);
    free(drawPointFlags);
}

-(nonnull CGPathRef)newDataLinePathForViewPoints:(nonnull CGPoint *)viewPoints indexRange:(NSRange)indexRange baselineYValue:(CGFloat)baselineYValue
{
    CPTScatterPlotInterpolation theInterpolation = self.interpolation;

    if ( theInterpolation == CPTScatterPlotInterpolationCurved ) {
        return [self newCurvedDataLinePathForViewPoints:viewPoints indexRange:indexRange baselineYValue:baselineYValue];
    }

    CGMutablePathRef dataLinePath  = CGPathCreateMutable();
    BOOL lastPointSkipped          = YES;
    CGPoint firstPoint             = CGPointZero;
    CGPoint lastPoint              = CGPointZero;
    NSUInteger lastDrawnPointIndex = NSMaxRange(indexRange);

    if ( lastDrawnPointIndex > 0 ) {
        lastDrawnPointIndex--;
    }

    for ( NSUInteger i = indexRange.location; i <= lastDrawnPointIndex; i++ ) {
        CGPoint viewPoint = viewPoints[i];

        if ( isnan(viewPoint.x) || isnan(viewPoint.y)) {
            if ( !lastPointSkipped ) {
                if ( !isnan(baselineYValue)) {
                    CGPathAddLineToPoint(dataLinePath, NULL, lastPoint.x, baselineYValue);
                    CGPathAddLineToPoint(dataLinePath, NULL, firstPoint.x, baselineYValue);
                    CGPathCloseSubpath(dataLinePath);
                }
                lastPointSkipped = YES;
            }
        }
        else {
            if ( lastPointSkipped ) {
                CGPathMoveToPoint(dataLinePath, NULL, viewPoint.x, viewPoint.y);
                lastPointSkipped = NO;
                firstPoint       = viewPoint;
            }
            else {
                switch ( theInterpolation ) {
                    case CPTScatterPlotInterpolationLinear:
                        CGPathAddLineToPoint(dataLinePath, NULL, viewPoint.x, viewPoint.y);
                        break;

                    case CPTScatterPlotInterpolationStepped:
                        CGPathAddLineToPoint(dataLinePath, NULL, viewPoint.x, lastPoint.y);
                        CGPathAddLineToPoint(dataLinePath, NULL, viewPoint.x, viewPoint.y);
                        break;

                    case CPTScatterPlotInterpolationHistogram:
                    {
                        CGFloat x = (lastPoint.x + viewPoint.x) / CPTFloat(2.0);
                        if ( CPTScatterPlotHistogramSkipFirst != self.histogramOption ) {
                            CGPathAddLineToPoint(dataLinePath, NULL, x, lastPoint.y);
                        }
                        if ( CPTScatterPlotHistogramSkipSecond != self.histogramOption ) {
                            CGPathAddLineToPoint(dataLinePath, NULL, x, viewPoint.y);
                        }
                        CGPathAddLineToPoint(dataLinePath, NULL, viewPoint.x, viewPoint.y);
                    }
                    break;

                    case CPTScatterPlotInterpolationCurved:
                        // Curved plot lines handled separately
                        break;
                }
            }
            lastPoint = viewPoint;
        }
    }

    if ( !lastPointSkipped && !isnan(baselineYValue)) {
        CGPathAddLineToPoint(dataLinePath, NULL, lastPoint.x, baselineYValue);
        CGPathAddLineToPoint(dataLinePath, NULL, firstPoint.x, baselineYValue);
        CGPathCloseSubpath(dataLinePath);
    }

    return dataLinePath;
}

-(nonnull CGPathRef)newCurvedDataLinePathForViewPoints:(nonnull CGPoint *)viewPoints indexRange:(NSRange)indexRange baselineYValue:(CGFloat)baselineYValue
{
    CGMutablePathRef dataLinePath  = CGPathCreateMutable();
    BOOL lastPointSkipped          = YES;
    CGPoint firstPoint             = CGPointZero;
    CGPoint lastPoint              = CGPointZero;
    NSUInteger firstIndex          = indexRange.location;
    NSUInteger lastDrawnPointIndex = NSMaxRange(indexRange);

    CPTScatterPlotCurvedInterpolationOption interpolationOption = self.curvedInterpolationOption;

    if ( lastDrawnPointIndex > 0 ) {
        CGPoint *controlPoints1 = calloc(lastDrawnPointIndex, sizeof(CGPoint));
        CGPoint *controlPoints2 = calloc(lastDrawnPointIndex, sizeof(CGPoint));

        lastDrawnPointIndex--;

        // Compute control points for each sub-range
        for ( NSUInteger i = indexRange.location; i <= lastDrawnPointIndex; i++ ) {
            CGPoint viewPoint = viewPoints[i];

            if ( isnan(viewPoint.x) || isnan(viewPoint.y)) {
                if ( !lastPointSkipped ) {
                    switch ( interpolationOption ) {
                        case CPTScatterPlotCurvedInterpolationNormal:
                            [self computeBezierControlPoints:controlPoints1
                                                     points2:controlPoints2
                                               forViewPoints:viewPoints
                                                  indexRange:NSMakeRange(firstIndex, i - firstIndex)];
                            break;

                        case CPTScatterPlotCurvedInterpolationCatmullRomUniform:
                            [self computeCatmullRomControlPoints:controlPoints1
                                                         points2:controlPoints2
                                                       withAlpha:CPTFloat(0.0)
                                                   forViewPoints:viewPoints
                                                      indexRange:NSMakeRange(firstIndex, i - firstIndex)];
                            break;

                        case CPTScatterPlotCurvedInterpolationCatmullRomCentripetal:
                            [self computeCatmullRomControlPoints:controlPoints1
                                                         points2:controlPoints2
                                                       withAlpha:CPTFloat(0.5)
                                                   forViewPoints:viewPoints
                                                      indexRange:NSMakeRange(firstIndex, i - firstIndex)];
                            break;

                        case CPTScatterPlotCurvedInterpolationCatmullRomChordal:
                            [self computeCatmullRomControlPoints:controlPoints1
                                                         points2:controlPoints2
                                                       withAlpha:CPTFloat(1.0)
                                                   forViewPoints:viewPoints
                                                      indexRange:NSMakeRange(firstIndex, i - firstIndex)];

                            break;

                        case CPTScatterPlotCurvedInterpolationHermiteCubic:
                            [self computeHermiteControlPoints:controlPoints1
                                                      points2:controlPoints2
                                                forViewPoints:viewPoints
                                                   indexRange:NSMakeRange(firstIndex, i - firstIndex)];
                            break;

                        case CPTScatterPlotCurvedInterpolationCatmullCustomAlpha:
                            [self computeCatmullRomControlPoints:controlPoints1
                                                         points2:controlPoints2
                                                       withAlpha:self.curvedInterpolationCustomAlpha
                                                   forViewPoints:viewPoints
                                                      indexRange:NSMakeRange(firstIndex, i - firstIndex)];
                            break;
                    }

                    lastPointSkipped = YES;
                }
            }
            else {
                if ( lastPointSkipped ) {
                    lastPointSkipped = NO;
                    firstIndex       = i;
                }
            }
        }

        if ( !lastPointSkipped ) {
            switch ( interpolationOption ) {
                case CPTScatterPlotCurvedInterpolationNormal:
                    [self computeBezierControlPoints:controlPoints1
                                             points2:controlPoints2
                                       forViewPoints:viewPoints
                                          indexRange:NSMakeRange(firstIndex, NSMaxRange(indexRange) - firstIndex)];
                    break;

                case CPTScatterPlotCurvedInterpolationCatmullRomUniform:
                    [self computeCatmullRomControlPoints:controlPoints1
                                                 points2:controlPoints2
                                               withAlpha:CPTFloat(0.0)
                                           forViewPoints:viewPoints
                                              indexRange:NSMakeRange(firstIndex, NSMaxRange(indexRange) - firstIndex)];

                    break;

                case CPTScatterPlotCurvedInterpolationCatmullRomCentripetal:
                    [self computeCatmullRomControlPoints:controlPoints1
                                                 points2:controlPoints2
                                               withAlpha:CPTFloat(0.5)
                                           forViewPoints:viewPoints
                                              indexRange:NSMakeRange(firstIndex, NSMaxRange(indexRange) - firstIndex)];
                    break;

                case CPTScatterPlotCurvedInterpolationCatmullRomChordal:
                    [self computeCatmullRomControlPoints:controlPoints1
                                                 points2:controlPoints2
                                               withAlpha:CPTFloat(1.0)
                                           forViewPoints:viewPoints
                                              indexRange:NSMakeRange(firstIndex, NSMaxRange(indexRange) - firstIndex)];

                    break;

                case CPTScatterPlotCurvedInterpolationHermiteCubic:
                    [self computeHermiteControlPoints:controlPoints1
                                              points2:controlPoints2
                                        forViewPoints:viewPoints
                                           indexRange:NSMakeRange(firstIndex, NSMaxRange(indexRange) - firstIndex)];
                    break;

                case CPTScatterPlotCurvedInterpolationCatmullCustomAlpha:
                    [self computeCatmullRomControlPoints:controlPoints1
                                                 points2:controlPoints2
                                               withAlpha:self.curvedInterpolationCustomAlpha
                                           forViewPoints:viewPoints
                                              indexRange:NSMakeRange(firstIndex, NSMaxRange(indexRange) - firstIndex)];
                    break;
            }
        }

        // Build the path
        lastPointSkipped = YES;
        for ( NSUInteger i = indexRange.location; i <= lastDrawnPointIndex; i++ ) {
            CGPoint viewPoint = viewPoints[i];

            if ( isnan(viewPoint.x) || isnan(viewPoint.y)) {
                if ( !lastPointSkipped ) {
                    if ( !isnan(baselineYValue)) {
                        CGPathAddLineToPoint(dataLinePath, NULL, lastPoint.x, baselineYValue);
                        CGPathAddLineToPoint(dataLinePath, NULL, firstPoint.x, baselineYValue);
                        CGPathCloseSubpath(dataLinePath);
                    }
                    lastPointSkipped = YES;
                }
            }
            else {
                if ( lastPointSkipped ) {
                    CGPathMoveToPoint(dataLinePath, NULL, viewPoint.x, viewPoint.y);
                    lastPointSkipped = NO;
                    firstPoint       = viewPoint;
                }
                else {
                    CGPoint cp1 = controlPoints1[i];
                    CGPoint cp2 = controlPoints2[i];

#ifdef DEBUG_CURVES
                    CGPoint currentPoint = CGPathGetCurrentPoint(dataLinePath);

                    // add the control points
                    CGPathMoveToPoint(dataLinePath, NULL, cp1.x - CPTFloat(5.0), cp1.y);
                    CGPathAddLineToPoint(dataLinePath, NULL, cp1.x + CPTFloat(5.0), cp1.y);
                    CGPathMoveToPoint(dataLinePath, NULL, cp1.x, cp1.y - CPTFloat(5.0));
                    CGPathAddLineToPoint(dataLinePath, NULL, cp1.x, cp1.y + CPTFloat(5.0));

                    CGPathMoveToPoint(dataLinePath, NULL, cp2.x - CPTFloat(3.5), cp2.y - CPTFloat(3.5));
                    CGPathAddLineToPoint(dataLinePath, NULL, cp2.x + CPTFloat(3.5), cp2.y + CPTFloat(3.5));
                    CGPathMoveToPoint(dataLinePath, NULL, cp2.x + CPTFloat(3.5), cp2.y - CPTFloat(3.5));
                    CGPathAddLineToPoint(dataLinePath, NULL, cp2.x - CPTFloat(3.5), cp2.y + CPTFloat(3.5));

                    // add a line connecting the control points
                    CGPathMoveToPoint(dataLinePath, NULL, cp1.x, cp1.y);
                    CGPathAddLineToPoint(dataLinePath, NULL, cp2.x, cp2.y);

                    CGPathMoveToPoint(dataLinePath, NULL, currentPoint.x, currentPoint.y);
#endif

                    CGPathAddCurveToPoint(dataLinePath, NULL, cp1.x, cp1.y, cp2.x, cp2.y, viewPoint.x, viewPoint.y);
                }
                lastPoint = viewPoint;
            }
        }

        if ( !lastPointSkipped && !isnan(baselineYValue)) {
            CGPathAddLineToPoint(dataLinePath, NULL, lastPoint.x, baselineYValue);
            CGPathAddLineToPoint(dataLinePath, NULL, firstPoint.x, baselineYValue);
            CGPathCloseSubpath(dataLinePath);
        }

        free(controlPoints1);
        free(controlPoints2);
    }

    return dataLinePath;
}

/** @brief Compute the control points using a catmull-rom spline.
 *  @param points A pointer to the array which should hold the first control points.
 *  @param points2 A pointer to the array which should hold the second control points.
 *  @param alpha The alpha value used for the catmull-rom interpolation.
 *  @param viewPoints A pointer to the array which holds all view points for which the interpolation should be calculated.
 *  @param indexRange The range in which the interpolation should occur.
 *  @warning The @par{indexRange} must be valid for all passed arrays otherwise this method crashes.
 **/
-(void)computeCatmullRomControlPoints:(nonnull CGPoint *)points points2:(nonnull CGPoint *)points2 withAlpha:(CGFloat)alpha forViewPoints:(nonnull CGPoint *)viewPoints indexRange:(NSRange)indexRange
{
    if ( indexRange.length >= 2 ) {
        NSUInteger startIndex   = indexRange.location;
        NSUInteger endIndex     = NSMaxRange(indexRange) - 1; // the index starts at zero
        NSUInteger segmentCount = endIndex - 1;               // there are n - 1 segments

        CGFloat epsilon = CPTFloat(1.0e-5); // the minimum point distance. below that no interpolation happens.

        for ( NSUInteger index = startIndex; index <= segmentCount; index++ ) {
            // calculate the control for the segment from index -> index + 1
            CGPoint p0, p1, p2, p3; // the view point

            // the internal points are always valid
            p1 = viewPoints[index];
            p2 = viewPoints[index + 1];
            // account for first and last segment
            if ( index == startIndex ) {
                p0 = p1;
            }
            else {
                p0 = viewPoints[index - 1];
            }
            if ( index == segmentCount ) {
                p3 = p2;
            }
            else {
                p3 = viewPoints[index + 2];
            }

            // distance between the points
            CGFloat d1 = hypot(p1.x - p0.x, p1.y - p0.y);
            CGFloat d2 = hypot(p2.x - p1.x, p2.y - p1.y);
            CGFloat d3 = hypot(p3.x - p2.x, p3.y - p2.y);
            // constants
            CGFloat d1_a  = pow(d1, alpha);           // d1^alpha
            CGFloat d2_a  = pow(d2, alpha);           // d2^alpha
            CGFloat d3_a  = pow(d3, alpha);           // d3^alpha
            CGFloat d1_2a = pow(d1_a, CPTFloat(2.0)); // d1^alpha^2 = d1^2*alpha
            CGFloat d2_2a = pow(d2_a, CPTFloat(2.0)); // d2^alpha^2 = d2^2*alpha
            CGFloat d3_2a = pow(d3_a, CPTFloat(2.0)); // d3^alpha^2 = d3^2*alpha

            // calculate the control points
            // see : http://www.cemyuksel.com/research/catmullrom_param/catmullrom.pdf under point 3.
            CGPoint cp1, cp2; // the calculated view points;
            if ( fabs(d1) <= epsilon ) {
                cp1 = p1;
            }
            else {
                CGFloat divisor = CPTFloat(3.0) * d1_a * (d1_a + d2_a);
                cp1 = CPTPointMake((p2.x * d1_2a - p0.x * d2_2a + (2 * d1_2a + 3 * d1_a * d2_a + d2_2a) * p1.x) / divisor,
                                   (p2.y * d1_2a - p0.y * d2_2a + (2 * d1_2a + 3 * d1_a * d2_a + d2_2a) * p1.y) / divisor
                                  );
            }

            if ( fabs(d3) <= epsilon ) {
                cp2 = p2;
            }
            else {
                CGFloat divisor = 3 * d3_a * (d3_a + d2_a);
                cp2 = CPTPointMake((d3_2a * p1.x - d2_2a * p3.x + (2 * d3_2a + 3 * d3_a * d2_a + d2_2a) * p2.x) / divisor,
                                   (d3_2a * p1.y - d2_2a * p3.y + (2 * d3_2a + 3 * d3_a * d2_a + d2_2a) * p2.y) / divisor);
            }

            points[index + 1]  = cp1;
            points2[index + 1] = cp2;
        }
    }
}

/** @brief Compute the control points using a hermite cubic spline.
 *
 *  If the view points are monotonically increasing or decreasing in both @par{x} and @par{y},
 *  the smoothed curve will be also.
 *
 *  @param points A pointer to the array which should hold the first control points.
 *  @param points2 A pointer to the array which should hold the second control points.
 *  @param viewPoints A pointer to the array which holds all view points for which the interpolation should be calculated.
 *  @param indexRange The range in which the interpolation should occur.
 *  @warning The @par{indexRange} must be valid for all passed arrays otherwise this method crashes.
 **/
-(void)computeHermiteControlPoints:(nonnull CGPoint *)points points2:(nonnull CGPoint *)points2 forViewPoints:(nonnull CGPoint *)viewPoints indexRange:(NSRange)indexRange
{
    // See https://en.wikipedia.org/wiki/Cubic_Hermite_spline and https://en.m.wikipedia.org/wiki/Monotone_cubic_interpolation for a discussion of algorithms used.
    if ( indexRange.length >= 2 ) {
        NSUInteger startIndex = indexRange.location;
        NSUInteger lastIndex  = NSMaxRange(indexRange) - 1; // last accessible element in view points

        BOOL monotonic = [self monotonicViewPoints:viewPoints indexRange:indexRange];

        for ( NSUInteger index = startIndex; index <= lastIndex; index++ ) {
            CGVector m;
            CGPoint p1 = viewPoints[index];

            if ( index == startIndex ) {
                CGPoint p2 = viewPoints[index + 1];

                m.dx = p2.x - p1.x;
                m.dy = p2.y - p1.y;
            }
            else if ( index == lastIndex ) {
                CGPoint p0 = viewPoints[index - 1];

                m.dx = p1.x - p0.x;
                m.dy = p1.y - p0.y;
            }
            else { // index > startIndex && index < numberOfPoints
                CGPoint p0 = viewPoints[index - 1];
                CGPoint p2 = viewPoints[index + 1];

                m.dx = p2.x - p0.x;
                m.dy = p2.y - p0.y;

                if ( monotonic ) {
                    if ( m.dx > CPTFloat(0.0)) {
                        m.dx = MIN(p2.x - p1.x, p1.x - p0.x);
                    }
                    else if ( m.dx < CPTFloat(0.0)) {
                        m.dx = MAX(p2.x - p1.x, p1.x - p0.x);
                    }

                    if ( m.dy > CPTFloat(0.0)) {
                        m.dy = MIN(p2.y - p1.y, p1.y - p0.y);
                    }
                    else if ( m.dy < CPTFloat(0.0)) {
                        m.dy = MAX(p2.y - p1.y, p1.y - p0.y);
                    }
                }
            }

            // get control points
            m.dx /= CPTFloat(6.0);
            m.dy /= CPTFloat(6.0);

            CGPoint rhsControlPoint = CPTPointMake(p1.x + m.dx, p1.y + m.dy);
            CGPoint lhsControlPoint = CPTPointMake(p1.x - m.dx, p1.y - m.dy);

            // We calculated the lhs & rhs control point. The rhs control point is the first control point for the curve to the next point. The lhs control point is the second control point for the curve to the current point.

            points2[index] = lhsControlPoint;
            if ( index + 1 <= lastIndex ) {
                points[index + 1] = rhsControlPoint;
            }
        }
    }
}

/** @brief Determine whether the plot points form a monotonic series.
 *  @param viewPoints A pointer to the array which holds all view points for which the interpolation should be calculated.
 *  @param indexRange The range in which the interpolation should occur.
 *  @return Returns @YES if the viewpoints are monotonically increasing or decreasing in both @par{x} and @par{y}.
 *  @warning The @par{indexRange} must be valid for all passed arrays otherwise this method crashes.
 **/
-(BOOL)monotonicViewPoints:(nonnull CGPoint *)viewPoints indexRange:(NSRange)indexRange
{
    if ( indexRange.length < 2 ) {
        return YES;
    }

    NSUInteger startIndex = indexRange.location;
    NSUInteger lastIndex  = NSMaxRange(indexRange) - 2;

    BOOL foundTrendX   = NO;
    BOOL foundTrendY   = NO;
    BOOL isIncreasingX = NO;
    BOOL isIncreasingY = NO;

    for ( NSUInteger index = startIndex; index <= lastIndex; index++ ) {
        CGPoint p1 = viewPoints[index];
        CGPoint p2 = viewPoints[index + 1];

        if ( !foundTrendX ) {
            if ( p2.x > p1.x ) {
                isIncreasingX = YES;
                foundTrendX   = YES;
            }
            else if ( p2.x < p1.x ) {
                foundTrendX = YES;
            }
        }

        if ( foundTrendX ) {
            if ( isIncreasingX ) {
                if ( p2.x < p1.x ) {
                    return NO;
                }
            }
            else {
                if ( p2.x > p1.x ) {
                    return NO;
                }
            }
        }

        if ( !foundTrendY ) {
            if ( p2.y > p1.y ) {
                isIncreasingY = YES;
                foundTrendY   = YES;
            }
            else if ( p2.y < p1.y ) {
                foundTrendY = YES;
            }
        }

        if ( foundTrendY ) {
            if ( isIncreasingY ) {
                if ( p2.y < p1.y ) {
                    return NO;
                }
            }
            else {
                if ( p2.y > p1.y ) {
                    return NO;
                }
            }
        }
    }

    return YES;
}

// Compute the control points using the algorithm described at http://www.particleincell.com/blog/2012/bezier-splines/
// cp1, cp2, and viewPoints should point to arrays of points with at least NSMaxRange(indexRange) elements each.
-(void)computeBezierControlPoints:(nonnull CGPoint *)cp1 points2:(nonnull CGPoint *)cp2 forViewPoints:(nonnull CGPoint *)viewPoints indexRange:(NSRange)indexRange
{
    if ( indexRange.length == 2 ) {
        NSUInteger rangeEnd = NSMaxRange(indexRange) - 1;
        cp1[rangeEnd] = viewPoints[indexRange.location];
        cp2[rangeEnd] = viewPoints[rangeEnd];
    }
    else if ( indexRange.length > 2 ) {
        NSUInteger n = indexRange.length - 1;

        // rhs vector
        CGPoint *a = calloc(n, sizeof(CGPoint));
        CGPoint *b = calloc(n, sizeof(CGPoint));
        CGPoint *c = calloc(n, sizeof(CGPoint));
        CGPoint *r = calloc(n, sizeof(CGPoint));

        // left most segment
        a[0] = CGPointZero;
        b[0] = CPTPointMake(2.0, 2.0);
        c[0] = CPTPointMake(1.0, 1.0);

        CGPoint pt0 = viewPoints[indexRange.location];
        CGPoint pt1 = viewPoints[indexRange.location + 1];
        r[0] = CGPointMake(pt0.x + CPTFloat(2.0) * pt1.x,
                           pt0.y + CPTFloat(2.0) * pt1.y);

        // internal segments
        for ( NSUInteger i = 1; i < n - 1; i++ ) {
            a[i] = CPTPointMake(1.0, 1.0);
            b[i] = CPTPointMake(4.0, 4.0);
            c[i] = CPTPointMake(1.0, 1.0);

            CGPoint pti  = viewPoints[indexRange.location + i];
            CGPoint pti1 = viewPoints[indexRange.location + i + 1];
            r[i] = CGPointMake(CPTFloat(4.0) * pti.x + CPTFloat(2.0) * pti1.x,
                               CPTFloat(4.0) * pti.y + CPTFloat(2.0) * pti1.y);
        }

        // right segment
        a[n - 1] = CPTPointMake(2.0, 2.0);
        b[n - 1] = CPTPointMake(7.0, 7.0);
        c[n - 1] = CGPointZero;

        CGPoint ptn1 = viewPoints[indexRange.location + n - 1];
        CGPoint ptn  = viewPoints[indexRange.location + n];
        r[n - 1] = CGPointMake(CPTFloat(8.0) * ptn1.x + ptn.x,
                               CPTFloat(8.0) * ptn1.y + ptn.y);

        // solve Ax=b with the Thomas algorithm (from Wikipedia)
        for ( NSUInteger i = 1; i < n; i++ ) {
            CGPoint m = CGPointMake(a[i].x / b[i - 1].x,
                                    a[i].y / b[i - 1].y);
            b[i] = CGPointMake(b[i].x - m.x * c[i - 1].x,
                               b[i].y - m.y * c[i - 1].y);
            r[i] = CGPointMake(r[i].x - m.x * r[i - 1].x,
                               r[i].y - m.y * r[i - 1].y);
        }

        cp1[indexRange.location + n] = CGPointMake(r[n - 1].x / b[n - 1].x,
                                                   r[n - 1].y / b[n - 1].y);
        for ( NSUInteger i = n - 2; i > 0; i-- ) {
            cp1[indexRange.location + i + 1] = CGPointMake((r[i].x - c[i].x * cp1[indexRange.location + i + 2].x) / b[i].x,
                                                           (r[i].y - c[i].y * cp1[indexRange.location + i + 2].y) / b[i].y);
        }
        cp1[indexRange.location + 1] = CGPointMake((r[0].x - c[0].x * cp1[indexRange.location + 2].x) / b[0].x,
                                                   (r[0].y - c[0].y * cp1[indexRange.location + 2].y) / b[0].y);

        // we have p1, now compute p2
        NSUInteger rangeEnd = NSMaxRange(indexRange) - 1;
        for ( NSUInteger i = indexRange.location + 1; i < rangeEnd; i++ ) {
            cp2[i] = CGPointMake(CPTFloat(2.0) * viewPoints[i].x - cp1[i + 1].x,
                                 CPTFloat(2.0) * viewPoints[i].y - cp1[i + 1].y);
        }

        cp2[rangeEnd] = CGPointMake(CPTFloat(0.5) * (viewPoints[rangeEnd].x + cp1[rangeEnd].x),
                                    CPTFloat(0.5) * (viewPoints[rangeEnd].y + cp1[rangeEnd].y));

        // clean up
        free(a);
        free(b);
        free(c);
        free(r);
    }
}

-(void)drawSwatchForLegend:(nonnull CPTLegend *)legend atIndex:(NSUInteger)idx inRect:(CGRect)rect inContext:(nonnull CGContextRef)context
{
    [super drawSwatchForLegend:legend atIndex:idx inRect:rect inContext:context];

    if ( self.drawLegendSwatchDecoration ) {
        CPTLineStyle *theLineStyle = self.dataLineStyle;

        if ( theLineStyle ) {
            [theLineStyle setLineStyleInContext:context];

            CGPoint alignedStartPoint = CPTAlignPointToUserSpace(context, CPTPointMake(CGRectGetMinX(rect), CGRectGetMidY(rect)));
            CGPoint alignedEndPoint   = CPTAlignPointToUserSpace(context, CPTPointMake(CGRectGetMaxX(rect), CGRectGetMidY(rect)));
            CGContextMoveToPoint(context, alignedStartPoint.x, alignedStartPoint.y);
            CGContextAddLineToPoint(context, alignedEndPoint.x, alignedEndPoint.y);

            [theLineStyle strokePathInContext:context];
        }

        CPTPlotSymbol *thePlotSymbol = self.plotSymbol;

        if ( thePlotSymbol ) {
            [thePlotSymbol renderInContext:context
                                   atPoint:CPTPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect))
                                     scale:self.contentsScale
                             alignToPixels:YES];
        }

        // if no line or plot symbol, use the area fills to draw the swatch
        if ( !theLineStyle && !thePlotSymbol ) {
            CPTFill *fill1 = self.areaFill;
            CPTFill *fill2 = self.areaFill2;

            if ( fill1 || fill2 ) {
                CGPathRef swatchPath = CPTCreateRoundedRectPath(CPTAlignIntegralRectToUserSpace(context, rect), legend.swatchCornerRadius);

                if ( fill1 && !fill2 ) {
                    CGContextBeginPath(context);
                    CGContextAddPath(context, swatchPath);
                    [fill1 fillPathInContext:context];
                }
                else if ( !fill1 && fill2 ) {
                    CGContextBeginPath(context);
                    CGContextAddPath(context, swatchPath);
                    [fill2 fillPathInContext:context];
                }
                else {
                    CGContextSaveGState(context);
                    CGContextAddPath(context, swatchPath);
                    CGContextClip(context);

                    if ( CPTDecimalGreaterThanOrEqualTo(self.areaBaseValue2.decimalValue, self.areaBaseValue.decimalValue)) {
                        [fill1 fillRect:CPTRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect), rect.size.width, rect.size.height / CPTFloat(2.0)) inContext:context];
                        [fill2 fillRect:CPTRectMake(CGRectGetMinX(rect), CGRectGetMidY(rect), rect.size.width, rect.size.height / CPTFloat(2.0)) inContext:context];
                    }
                    else {
                        [fill2 fillRect:CPTRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect), rect.size.width, rect.size.height / CPTFloat(2.0)) inContext:context];
                        [fill1 fillRect:CPTRectMake(CGRectGetMinX(rect), CGRectGetMidY(rect), rect.size.width, rect.size.height / CPTFloat(2.0)) inContext:context];
                    }

                    CGContextRestoreGState(context);
                }

                CGPathRelease(swatchPath);
            }
        }
    }
}

-(nonnull CGPathRef)newDataLinePath
{
    [self reloadDataIfNeeded];

    NSUInteger dataCount = self.cachedDataCount;
    if ( dataCount == 0 ) {
        return CGPathCreateMutable();
    }

    // Calculate view points
    CGPoint *viewPoints  = calloc(dataCount, sizeof(CGPoint));
    BOOL *drawPointFlags = calloc(dataCount, sizeof(BOOL));

    for ( NSUInteger i = 0; i < dataCount; i++ ) {
        drawPointFlags[i] = YES;
    }

    [self calculateViewPoints:viewPoints withDrawPointFlags:drawPointFlags numberOfPoints:dataCount];

    // Create the path
    CGPathRef dataLinePath = [self newDataLinePathForViewPoints:viewPoints
                                                     indexRange:NSMakeRange(0, dataCount)
                                                 baselineYValue:CPTNAN];

    free(viewPoints);
    free(drawPointFlags);

    return dataLinePath;
}

/// @endcond

#pragma mark -
#pragma mark Animation

/// @cond

+(BOOL)needsDisplayForKey:(nonnull NSString *)aKey
{
    static NSSet<NSString *> *keys = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        keys = [NSSet setWithArray:@[@"areaBaseValue",
                                     @"areaBaseValue2"]];
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
#pragma mark Data Ranges

/// @cond

-(nullable CPTPlotRange *)plotRangeEnclosingField:(NSUInteger)fieldEnum
{
    CPTPlotRange *range = [self plotRangeForField:fieldEnum];

    if ( self.interpolation == CPTScatterPlotInterpolationCurved ) {
        CPTPlotSpace *space = self.plotSpace;

        if ( space ) {
            CGPathRef dataLinePath = self.newDataLinePath;

            CGRect boundingBox = CGPathGetBoundingBox(dataLinePath);

            CGPathRelease(dataLinePath);

            CPTNumberArray *lowerLeft  = [space plotPointForPlotAreaViewPoint:boundingBox.origin];
            CPTNumberArray *upperRight = [space plotPointForPlotAreaViewPoint:CGPointMake(CGRectGetMaxX(boundingBox),
                                                                                          CGRectGetMaxY(boundingBox))];

            switch ( fieldEnum ) {
                case CPTScatterPlotFieldX:
                {
                    NSNumber *length = [NSDecimalNumber decimalNumberWithDecimal:
                                        CPTDecimalSubtract(upperRight[CPTCoordinateX].decimalValue,
                                                           lowerLeft[CPTCoordinateX].decimalValue)];
                    range = [CPTPlotRange plotRangeWithLocation:lowerLeft[CPTCoordinateX]
                                                         length:length];
                }
                break;

                case CPTScatterPlotFieldY:
                {
                    NSNumber *length = [NSDecimalNumber decimalNumberWithDecimal:
                                        CPTDecimalSubtract(upperRight[CPTCoordinateY].decimalValue,
                                                           lowerLeft[CPTCoordinateY].decimalValue)];
                    range = [CPTPlotRange plotRangeWithLocation:lowerLeft[CPTCoordinateY]
                                                         length:length];
                }
                break;

                default:
                    break;
            }
        }
    }

    return range;
}

/// @endcond

#pragma mark -
#pragma mark Fields

/// @cond

-(NSUInteger)numberOfFields
{
    return 2;
}

-(nonnull CPTNumberArray *)fieldIdentifiers
{
    return @[@(CPTScatterPlotFieldX), @(CPTScatterPlotFieldY)];
}

-(nonnull CPTNumberArray *)fieldIdentifiersForCoordinate:(CPTCoordinate)coord
{
    CPTNumberArray *result = nil;

    switch ( coord ) {
        case CPTCoordinateX:
            result = @[@(CPTScatterPlotFieldX)];
        break;

        case CPTCoordinateY:
            result = @[@(CPTScatterPlotFieldY)];
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
        case CPTScatterPlotFieldX:
            coordinate = CPTCoordinateX;
            break;

        case CPTScatterPlotFieldY:
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
    NSNumber *xValue = [self cachedNumberForField:CPTScatterPlotFieldX recordIndex:idx];
    NSNumber *yValue = [self cachedNumberForField:CPTScatterPlotFieldY recordIndex:idx];

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
#pragma mark Area Fill Bands

/** @brief Add an area fill limit band.
 *
 *  The band will be drawn on top of the @ref areaFill between the plot line and the @ref areaBaseValue.
 *
 *  @param limitBand The new limit band.
 **/
-(void)addAreaFillBand:(nullable CPTLimitBand *)limitBand
{
    if ( [limitBand isKindOfClass:[CPTLimitBand class]] ) {
        if ( !self.mutableAreaFillBands ) {
            self.mutableAreaFillBands = [NSMutableArray array];
        }

        CPTLimitBand *band = limitBand;
        [self.mutableAreaFillBands addObject:band];

        [self setNeedsDisplay];
    }
}

/** @brief Remove an area fill limit band.
 *  @param limitBand The limit band to be removed.
 **/
-(void)removeAreaFillBand:(nullable CPTLimitBand *)limitBand
{
    if ( limitBand ) {
        CPTMutableLimitBandArray *fillBands = self.mutableAreaFillBands;

        CPTLimitBand *band = limitBand;
        [fillBands removeObject:band];

        if ( fillBands.count == 0 ) {
            self.mutableAreaFillBands = nil;
        }

        [self setNeedsDisplay];
    }
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
 *  If this plot has a delegate that responds to the
 *  @link CPTScatterPlotDelegate::scatterPlot:plotSymbolTouchDownAtRecordIndex: -scatterPlot:plotSymbolTouchDownAtRecordIndex: @endlink or
 *  @link CPTScatterPlotDelegate::scatterPlot:plotSymbolTouchDownAtRecordIndex:withEvent: -scatterPlot:plotSymbolTouchDownAtRecordIndex:withEvent: @endlink or
 *  @link CPTScatterPlotDelegate::scatterPlot:plotSymbolWasSelectedAtRecordIndex: -scatterPlot:plotSymbolWasSelectedAtRecordIndex: @endlink or
 *  @link CPTScatterPlotDelegate::scatterPlot:plotSymbolWasSelectedAtRecordIndex:withEvent: -scatterPlot:plotSymbolWasSelectedAtRecordIndex:withEvent: @endlink
 *  methods, the data points are searched to find the index of the one closest to the @par{interactionPoint}.
 *  The 'touchDown' delegate method(s) will be called and this method will return @YES if the @par{interactionPoint} is within the
 *  @ref plotSymbolMarginForHitDetection of the closest data point.
 *  Then, if no plot symbol was hit or @ref allowSimultaneousSymbolAndPlotSelection is @YES and if this plot has
 *  a delegate that responds to the
 *  @link CPTScatterPlotDelegate::scatterPlotDataLineTouchDown: -scatterPlotDataLineTouchDown: @endlink or
 *  @link CPTScatterPlotDelegate::scatterPlot:dataLineTouchDownWithEvent: -scatterPlot:dataLineTouchDownWithEvent: @endlink or
 *  @link CPTScatterPlotDelegate::scatterPlotDataLineWasSelected: -scatterPlotDataLineWasSelected: @endlink or
 *  @link CPTScatterPlotDelegate::scatterPlot:dataLineWasSelectedWithEvent: -scatterPlot:dataLineWasSelectedWithEvent: @endlink
 *  methods and the @par{interactionPoint} falls within @ref plotLineMarginForHitDetection points of the plot line,
 *  then the 'dataLineTouchDown' delegate method(s) will be called and this method will return @YES.
 *  This method returns @NO if the @par{interactionPoint} is not within @ref plotSymbolMarginForHitDetection points of any of
 *  the data points or within @ref plotLineMarginForHitDetection points of the plot line.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceDownEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    self.pointingDeviceDownIndex  = NSNotFound;
    self.pointingDeviceDownOnLine = NO;

    CPTGraph *theGraph       = self.graph;
    CPTPlotArea *thePlotArea = self.plotArea;

    if ( !theGraph || !thePlotArea || self.hidden ) {
        return NO;
    }

    id<CPTScatterPlotDelegate> theDelegate = (id<CPTScatterPlotDelegate>)self.delegate;
    BOOL symbolTouchUpHandled              = NO;

    if ( [theDelegate respondsToSelector:@selector(scatterPlot:plotSymbolTouchDownAtRecordIndex:)] ||
         [theDelegate respondsToSelector:@selector(scatterPlot:plotSymbolTouchDownAtRecordIndex:withEvent:)] ||
         [theDelegate respondsToSelector:@selector(scatterPlot:plotSymbolWasSelectedAtRecordIndex:)] ||
         [theDelegate respondsToSelector:@selector(scatterPlot:plotSymbolWasSelectedAtRecordIndex:withEvent:)] ) {
        // Inform delegate if a point was hit
        CGPoint plotAreaPoint = [theGraph convertPoint:interactionPoint toLayer:thePlotArea];
        NSUInteger idx        = [self indexOfVisiblePointClosestToPlotAreaPoint:plotAreaPoint];

        if ( idx != NSNotFound ) {
            CGPoint center        = [self plotAreaPointOfVisiblePointAtIndex:idx];
            CPTPlotSymbol *symbol = [self plotSymbolForRecordIndex:idx];

            CGRect symbolRect = CGRectZero;
            if ( [symbol isKindOfClass:[CPTPlotSymbol class]] ) {
                symbolRect.size = symbol.size;
            }
            else {
                symbolRect.size = CGSizeZero;
            }
            CGFloat margin = self.plotSymbolMarginForHitDetection * CPTFloat(2.0);
            symbolRect.size.width  += margin;
            symbolRect.size.height += margin;
            symbolRect.origin       = CPTPointMake(center.x - CPTFloat(0.5) * CGRectGetWidth(symbolRect), center.y - CPTFloat(0.5) * CGRectGetHeight(symbolRect));

            if ( CGRectContainsPoint(symbolRect, plotAreaPoint)) {
                self.pointingDeviceDownIndex = idx;

                if ( [theDelegate respondsToSelector:@selector(scatterPlot:plotSymbolTouchDownAtRecordIndex:)] ) {
                    symbolTouchUpHandled = YES;
                    [theDelegate scatterPlot:self plotSymbolTouchDownAtRecordIndex:idx];
                }
                if ( [theDelegate respondsToSelector:@selector(scatterPlot:plotSymbolTouchDownAtRecordIndex:withEvent:)] ) {
                    symbolTouchUpHandled = YES;
                    [theDelegate scatterPlot:self plotSymbolTouchDownAtRecordIndex:idx withEvent:event];
                }
            }
        }
    }

    BOOL plotTouchUpHandled = NO;
    BOOL plotSelected       = NO;

    if ( self.dataLineStyle &&
         (!symbolTouchUpHandled || self.allowSimultaneousSymbolAndPlotSelection) &&
         ([theDelegate respondsToSelector:@selector(scatterPlotDataLineTouchDown:)] ||
          [theDelegate respondsToSelector:@selector(scatterPlot:dataLineTouchDownWithEvent:)] ||
          [theDelegate respondsToSelector:@selector(scatterPlotDataLineWasSelected:)] ||
          [theDelegate respondsToSelector:@selector(scatterPlot:dataLineWasSelectedWithEvent:)])) {
        plotSelected = [self plotWasLineHitByInteractionPoint:interactionPoint];
        if ( plotSelected ) {
            // Let the delegate know that the plot was selected.
            self.pointingDeviceDownOnLine = YES;

            if ( [theDelegate respondsToSelector:@selector(scatterPlotDataLineTouchDown:)] ) {
                plotTouchUpHandled = YES;
                [theDelegate scatterPlotDataLineTouchDown:self];
            }
            if ( [theDelegate respondsToSelector:@selector(scatterPlot:dataLineTouchDownWithEvent:)] ) {
                plotTouchUpHandled = YES;
                [theDelegate scatterPlot:self dataLineTouchDownWithEvent:event];
            }
        }
    }

    if ( symbolTouchUpHandled || plotTouchUpHandled ) {
        return YES;
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
 *  @link CPTScatterPlotDelegate::scatterPlot:plotSymbolTouchDownAtRecordIndex: -scatterPlot:plotSymbolTouchDownAtRecordIndex: @endlink or
 *  @link CPTScatterPlotDelegate::scatterPlot:plotSymbolTouchDownAtRecordIndex:withEvent: -scatterPlot:plotSymbolTouchDownAtRecordIndex:withEvent: @endlink or
 *  @link CPTScatterPlotDelegate::scatterPlot:plotSymbolWasSelectedAtRecordIndex: -scatterPlot:plotSymbolWasSelectedAtRecordIndex: @endlink or
 *  @link CPTScatterPlotDelegate::scatterPlot:plotSymbolWasSelectedAtRecordIndex:withEvent: -scatterPlot:plotSymbolWasSelectedAtRecordIndex:withEvent: @endlink
 *  methods, the data points are searched to find the index of the one closest to the @par{interactionPoint}.
 *  The 'touchDown' delegate method(s) will be called and this method will return @YES if the @par{interactionPoint} is within the
 *  @ref plotSymbolMarginForHitDetection of the closest data point.
 *  Then, if no plot symbol was hit or @ref allowSimultaneousSymbolAndPlotSelection is @YES and if this plot has
 *  a delegate that responds to the
 *  @link CPTScatterPlotDelegate::scatterPlotDataLineTouchUp: -scatterPlotDataLineTouchUp: @endlink or
 *  @link CPTScatterPlotDelegate::scatterPlot:dataLineTouchUpWithEvent: -scatterPlot:dataLineTouchUpWithEvent: @endlink or
 *  @link CPTScatterPlotDelegate::scatterPlotDataLineWasSelected: -scatterPlotDataLineWasSelected: @endlink or
 *  @link CPTScatterPlotDelegate::scatterPlot:dataLineWasSelectedWithEvent: -scatterPlot:dataLineWasSelectedWithEvent: @endlink
 *  methods and the @par{interactionPoint} falls within @ref plotLineMarginForHitDetection points of the plot line,
 *  then the 'dataLineTouchUp' delegate method(s) will be called and this method will return @YES.
 *  This method returns @NO if the @par{interactionPoint} is not within @ref plotSymbolMarginForHitDetection points of any of
 *  the data points or within @ref plotLineMarginForHitDetection points of the plot line.
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

    // Do not perform any selection if the plotSpace is bring dragged.
    if ( !theGraph || !thePlotArea || self.hidden || self.plotSpace.isDragging ) {
        return NO;
    }

    id<CPTScatterPlotDelegate> theDelegate = (id<CPTScatterPlotDelegate>)self.delegate;
    BOOL symbolSelectHandled               = NO;

    if ( [theDelegate respondsToSelector:@selector(scatterPlot:plotSymbolTouchUpAtRecordIndex:)] ||
         [theDelegate respondsToSelector:@selector(scatterPlot:plotSymbolTouchUpAtRecordIndex:withEvent:)] ||
         [theDelegate respondsToSelector:@selector(scatterPlot:plotSymbolWasSelectedAtRecordIndex:)] ||
         [theDelegate respondsToSelector:@selector(scatterPlot:plotSymbolWasSelectedAtRecordIndex:withEvent:)] ) {
        // Inform delegate if a point was hit
        CGPoint plotAreaPoint = [theGraph convertPoint:interactionPoint toLayer:thePlotArea];
        NSUInteger idx        = [self indexOfVisiblePointClosestToPlotAreaPoint:plotAreaPoint];

        if ( idx != NSNotFound ) {
            CGPoint center        = [self plotAreaPointOfVisiblePointAtIndex:idx];
            CPTPlotSymbol *symbol = [self plotSymbolForRecordIndex:idx];

            CGRect symbolRect = CGRectZero;
            if ( [symbol isKindOfClass:[CPTPlotSymbol class]] ) {
                symbolRect.size = symbol.size;
            }
            else {
                symbolRect.size = CGSizeZero;
            }
            CGFloat margin = self.plotSymbolMarginForHitDetection * CPTFloat(2.0);
            symbolRect.size.width  += margin;
            symbolRect.size.height += margin;
            symbolRect.origin       = CPTPointMake(center.x - CPTFloat(0.5) * CGRectGetWidth(symbolRect), center.y - CPTFloat(0.5) * CGRectGetHeight(symbolRect));

            if ( CGRectContainsPoint(symbolRect, plotAreaPoint)) {
                self.pointingDeviceDownIndex = idx;

                if ( [theDelegate respondsToSelector:@selector(scatterPlot:plotSymbolTouchUpAtRecordIndex:)] ) {
                    symbolSelectHandled = YES;
                    [theDelegate scatterPlot:self plotSymbolTouchUpAtRecordIndex:idx];
                }
                if ( [theDelegate respondsToSelector:@selector(scatterPlot:plotSymbolTouchUpAtRecordIndex:withEvent:)] ) {
                    symbolSelectHandled = YES;
                    [theDelegate scatterPlot:self plotSymbolTouchUpAtRecordIndex:idx withEvent:event];
                }

                if ( idx == selectedDownIndex ) {
                    if ( [theDelegate respondsToSelector:@selector(scatterPlot:plotSymbolWasSelectedAtRecordIndex:)] ) {
                        symbolSelectHandled = YES;
                        [theDelegate scatterPlot:self plotSymbolWasSelectedAtRecordIndex:idx];
                    }

                    if ( [theDelegate respondsToSelector:@selector(scatterPlot:plotSymbolWasSelectedAtRecordIndex:withEvent:)] ) {
                        symbolSelectHandled = YES;
                        [theDelegate scatterPlot:self plotSymbolWasSelectedAtRecordIndex:idx withEvent:event];
                    }
                }
            }
        }
    }

    BOOL plotSelectHandled = NO;
    BOOL plotSelected      = NO;

    if ( self.dataLineStyle &&
         (!symbolSelectHandled || self.allowSimultaneousSymbolAndPlotSelection) &&
         ([theDelegate respondsToSelector:@selector(scatterPlotDataLineTouchUp:)] ||
          [theDelegate respondsToSelector:@selector(scatterPlot:dataLineTouchUpWithEvent:)] ||
          [theDelegate respondsToSelector:@selector(scatterPlotDataLineWasSelected:)] ||
          [theDelegate respondsToSelector:@selector(scatterPlot:dataLineWasSelectedWithEvent:)])) {
        plotSelected = [self plotWasLineHitByInteractionPoint:interactionPoint];

        if ( plotSelected ) {
            if ( [theDelegate respondsToSelector:@selector(scatterPlotDataLineTouchUp:)] ) {
                symbolSelectHandled = YES;
                [theDelegate scatterPlotDataLineTouchUp:self];
            }
            if ( [theDelegate respondsToSelector:@selector(scatterPlot:dataLineTouchUpWithEvent:)] ) {
                symbolSelectHandled = YES;
                [theDelegate scatterPlot:self dataLineTouchUpWithEvent:event];
            }

            if ( self.pointingDeviceDownOnLine ) {
                // Let the delegate know that the plot was selected.
                if ( [theDelegate respondsToSelector:@selector(scatterPlotDataLineWasSelected:)] ) {
                    plotSelectHandled = YES;
                    [theDelegate scatterPlotDataLineWasSelected:self];
                }
                if ( [theDelegate respondsToSelector:@selector(scatterPlot:dataLineWasSelectedWithEvent:)] ) {
                    plotSelectHandled = YES;
                    [theDelegate scatterPlot:self dataLineWasSelectedWithEvent:event];
                }
            }
        }
    }

    if ( symbolSelectHandled || plotSelectHandled ) {
        return YES;
    }

    return [super pointingDeviceUpEvent:event atPoint:interactionPoint];
}

-(BOOL)plotWasLineHitByInteractionPoint:(CGPoint)interactionPoint
{
    BOOL plotLineHit = NO;

    // Create the detection path.
    CPTGraph *theGraph       = self.graph;
    CPTPlotArea *thePlotArea = self.plotArea;
    NSUInteger dataCount     = self.cachedDataCount;

    if ( theGraph && thePlotArea && !self.hidden && dataCount ) {
        CGPoint *viewPoints  = calloc(dataCount, sizeof(CGPoint));
        BOOL *drawPointFlags = calloc(dataCount, sizeof(BOOL));

        CPTXYPlotSpace *thePlotSpace = (CPTXYPlotSpace *)self.plotSpace;
        [self calculatePointsToDraw:drawPointFlags forPlotSpace:thePlotSpace includeVisiblePointsOnly:NO numberOfPoints:dataCount];
        [self calculateViewPoints:viewPoints withDrawPointFlags:drawPointFlags numberOfPoints:dataCount];
        NSInteger firstDrawnPointIndex = [self extremeDrawnPointIndexForFlags:drawPointFlags numberOfPoints:dataCount extremeNumIsLowerBound:YES];

        if ( firstDrawnPointIndex != NSNotFound ) {
            NSInteger lastDrawnPointIndex = [self extremeDrawnPointIndexForFlags:drawPointFlags numberOfPoints:dataCount extremeNumIsLowerBound:NO];

            NSRange viewIndexRange = NSMakeRange((NSUInteger)firstDrawnPointIndex, (NSUInteger)(lastDrawnPointIndex - firstDrawnPointIndex + 1));
            CGPathRef dataLinePath = [self newDataLinePathForViewPoints:viewPoints indexRange:viewIndexRange baselineYValue:CPTNAN];
            CGPathRef path         = CGPathCreateCopyByStrokingPath(dataLinePath,
                                                                    NULL,
                                                                    self.plotLineMarginForHitDetection * CPTFloat(2.0),
                                                                    kCGLineCapRound,
                                                                    kCGLineJoinRound,
                                                                    CPTFloat(3.0));

            CGPoint plotAreaPoint = [theGraph convertPoint:interactionPoint toLayer:thePlotArea];

            plotLineHit = CGPathContainsPoint(path, NULL, plotAreaPoint, false);
            CGPathRelease(dataLinePath);
            CGPathRelease(path);
        }

        free(viewPoints);
        free(drawPointFlags);
    }

    return plotLineHit;
}

/// @}

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setInterpolation:(CPTScatterPlotInterpolation)newInterpolation
{
    if ( newInterpolation != interpolation ) {
        interpolation = newInterpolation;
        [self setNeedsDisplay];
    }
}

-(void)setHistogramOption:(CPTScatterPlotHistogramOption)newHistogramOption
{
    if ( newHistogramOption != histogramOption ) {
        histogramOption = newHistogramOption;
        [self setNeedsDisplay];
    }
}

-(void)setCurvedInterpolationOption:(CPTScatterPlotCurvedInterpolationOption)newCurvedInterpolationOption
{
    if ( newCurvedInterpolationOption != curvedInterpolationOption ) {
        curvedInterpolationOption = newCurvedInterpolationOption;
        [self setNeedsDisplay];
    }
}

-(void)setCurvedInterpolationCustomAlpha:(CGFloat)newCurvedInterpolationCustomAlpha
{
    if ( newCurvedInterpolationCustomAlpha > CPTFloat(1.0)) {
        newCurvedInterpolationCustomAlpha = CPTFloat(1.0);
    }
    if ( newCurvedInterpolationCustomAlpha < CPTFloat(0.0)) {
        newCurvedInterpolationCustomAlpha = CPTFloat(0.0);
    }

    if ( newCurvedInterpolationCustomAlpha != curvedInterpolationCustomAlpha ) {
        curvedInterpolationCustomAlpha = newCurvedInterpolationCustomAlpha;
        [self setNeedsDisplay];
    }
}

-(void)setPlotSymbol:(nullable CPTPlotSymbol *)aSymbol
{
    if ( aSymbol != plotSymbol ) {
        plotSymbol = [aSymbol copy];
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(void)setDataLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    if ( dataLineStyle != newLineStyle ) {
        dataLineStyle = [newLineStyle copy];
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

-(void)setAreaFill2:(nullable CPTFill *)newFill
{
    if ( newFill != areaFill2 ) {
        areaFill2 = [newFill copy];
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(nullable CPTLimitBandArray *)areaFillBands
{
    return [self.mutableAreaFillBands copy];
}

-(void)setAreaBaseValue:(nullable NSNumber *)newAreaBaseValue
{
    BOOL needsUpdate = YES;

    if ( newAreaBaseValue ) {
        NSNumber *baseValue = newAreaBaseValue;
        needsUpdate = ![areaBaseValue isEqualToNumber:baseValue];
    }

    if ( needsUpdate ) {
        areaBaseValue = newAreaBaseValue;
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(void)setAreaBaseValue2:(nullable NSNumber *)newAreaBaseValue
{
    BOOL needsUpdate = YES;

    if ( newAreaBaseValue ) {
        NSNumber *baseValue = newAreaBaseValue;
        needsUpdate = ![areaBaseValue2 isEqualToNumber:baseValue];
    }

    if ( needsUpdate ) {
        areaBaseValue2 = newAreaBaseValue;
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(void)setXValues:(nullable CPTNumberArray *)newValues
{
    [self cacheNumbers:newValues forField:CPTScatterPlotFieldX];
}

-(nullable CPTNumberArray *)xValues
{
    return [[self cachedNumbersForField:CPTScatterPlotFieldX] sampleArray];
}

-(void)setYValues:(nullable CPTNumberArray *)newValues
{
    [self cacheNumbers:newValues forField:CPTScatterPlotFieldY];
}

-(nullable CPTNumberArray *)yValues
{
    return [[self cachedNumbersForField:CPTScatterPlotFieldY] sampleArray];
}

-(void)setPlotSymbols:(nullable CPTPlotSymbolArray *)newSymbols
{
    [self cacheArray:newSymbols forKey:CPTScatterPlotBindingPlotSymbols];
    [self setNeedsDisplay];
}

-(nullable CPTPlotSymbolArray *)plotSymbols
{
    return [self cachedArrayForKey:CPTScatterPlotBindingPlotSymbols];
}

/// @endcond

@end

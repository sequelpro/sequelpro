#import "CPTTradingRangePlot.h"

#import "CPTColor.h"
#import "CPTExceptions.h"
#import "CPTLegend.h"
#import "CPTLineStyle.h"
#import "CPTMutableNumericData.h"
#import "CPTPlotArea.h"
#import "CPTPlotRange.h"
#import "CPTPlotSpace.h"
#import "CPTPlotSpaceAnnotation.h"
#import "CPTUtilities.h"
#import "CPTXYPlotSpace.h"
#import "NSCoderExtensions.h"
#import "NSNumberExtensions.h"
#import "tgmath.h"

/** @defgroup plotAnimationTradingRangePlot Trading Range Plot
 *  @brief Trading range plot properties that can be animated using Core Animation.
 *  @ingroup plotAnimation
 **/

/** @if MacOnly
 *  @defgroup plotBindingsTradingRangePlot Trading Range Plot Bindings
 *  @brief Binding identifiers for trading range plots.
 *  @ingroup plotBindings
 *  @endif
 **/

CPTTradingRangePlotBinding const CPTTradingRangePlotBindingXValues            = @"xValues";            ///< X values.
CPTTradingRangePlotBinding const CPTTradingRangePlotBindingOpenValues         = @"openValues";         ///< Open price values.
CPTTradingRangePlotBinding const CPTTradingRangePlotBindingHighValues         = @"highValues";         ///< High price values.
CPTTradingRangePlotBinding const CPTTradingRangePlotBindingLowValues          = @"lowValues";          ///< Low price values.
CPTTradingRangePlotBinding const CPTTradingRangePlotBindingCloseValues        = @"closeValues";        ///< Close price values.
CPTTradingRangePlotBinding const CPTTradingRangePlotBindingIncreaseFills      = @"increaseFills";      ///< Fills used with a candlestick plot when close >= open.
CPTTradingRangePlotBinding const CPTTradingRangePlotBindingDecreaseFills      = @"decreaseFills";      ///< Fills used with a candlestick plot when close < open.
CPTTradingRangePlotBinding const CPTTradingRangePlotBindingLineStyles         = @"lineStyles";         ///< Line styles used to draw candlestick or OHLC symbols.
CPTTradingRangePlotBinding const CPTTradingRangePlotBindingIncreaseLineStyles = @"increaseLineStyles"; ///< Line styles used to outline candlestick symbols when close >= open.
CPTTradingRangePlotBinding const CPTTradingRangePlotBindingDecreaseLineStyles = @"decreaseLineStyles"; ///< Line styles used to outline candlestick symbols when close < open.
CPTTradingRangePlotBinding const CPTTradingRangePlotBindingBarWidths          = @"barWidths";          ///< Bar widths.

static const CPTCoordinate independentCoord = CPTCoordinateX;
static const CPTCoordinate dependentCoord   = CPTCoordinateY;

/// @cond
@interface CPTTradingRangePlot()

@property (nonatomic, readwrite, copy, nullable) CPTMutableNumericData *xValues;
@property (nonatomic, readwrite, copy, nullable) CPTMutableNumericData *openValues;
@property (nonatomic, readwrite, copy, nullable) CPTMutableNumericData *highValues;
@property (nonatomic, readwrite, copy, nullable) CPTMutableNumericData *lowValues;
@property (nonatomic, readwrite, copy, nullable) CPTMutableNumericData *closeValues;
@property (nonatomic, readwrite, copy, nullable) CPTFillArray *increaseFills;
@property (nonatomic, readwrite, copy, nullable) CPTFillArray *decreaseFills;
@property (nonatomic, readwrite, copy, nullable) CPTLineStyleArray *lineStyles;
@property (nonatomic, readwrite, copy, nullable) CPTLineStyleArray *increaseLineStyles;
@property (nonatomic, readwrite, copy, nullable) CPTLineStyleArray *decreaseLineStyles;
@property (nonatomic, readwrite, copy, nullable) CPTLineStyleArray *barWidths;
@property (nonatomic, readwrite, assign) NSUInteger pointingDeviceDownIndex;

-(void)drawCandleStickInContext:(nonnull CGContextRef)context atIndex:(NSUInteger)idx x:(CGFloat)x open:(CGFloat)openValue close:(CGFloat)closeValue high:(CGFloat)highValue low:(CGFloat)lowValue width:(CGFloat)width alignPoints:(BOOL)alignPoints;
-(void)drawOHLCInContext:(nonnull CGContextRef)context atIndex:(NSUInteger)idx x:(CGFloat)x open:(CGFloat)openValue close:(CGFloat)closeValue high:(CGFloat)highValue low:(CGFloat)lowValue alignPoints:(BOOL)alignPoints;

-(nullable CPTFill *)increaseFillForIndex:(NSUInteger)idx;
-(nullable CPTFill *)decreaseFillForIndex:(NSUInteger)idx;

-(nullable CPTLineStyle *)lineStyleForIndex:(NSUInteger)idx;
-(nullable CPTLineStyle *)increaseLineStyleForIndex:(NSUInteger)idx;
-(nullable CPTLineStyle *)decreaseLineStyleForIndex:(NSUInteger)idx;

-(nonnull NSNumber *)barWidthForIndex:(NSUInteger)idx;

@end

/// @endcond

#pragma mark -

/**
 *  @brief A trading range financial plot.
 *  @see See @ref plotAnimationTradingRangePlot "Trading Range Plot" for a list of animatable properties.
 *  @if MacOnly
 *  @see See @ref plotBindingsTradingRangePlot "Trading Range Plot Bindings" for a list of supported binding identifiers.
 *  @endif
 **/
@implementation CPTTradingRangePlot

@dynamic xValues;
@dynamic openValues;
@dynamic highValues;
@dynamic lowValues;
@dynamic closeValues;
@dynamic increaseFills;
@dynamic decreaseFills;
@dynamic lineStyles;
@dynamic increaseLineStyles;
@dynamic decreaseLineStyles;
@dynamic barWidths;

/** @property nullable CPTLineStyle *lineStyle
 *  @brief The line style used to draw candlestick or OHLC symbols.
 **/
@synthesize lineStyle;

/** @property nullable CPTLineStyle *increaseLineStyle
 *  @brief The line style used to outline candlestick symbols or draw OHLC symbols when close >= open.
 *  If @nil, will use @ref lineStyle instead.
 **/
@synthesize increaseLineStyle;

/** @property nullable CPTLineStyle *decreaseLineStyle
 *  @brief The line style used to outline candlestick symbols or draw OHLC symbols when close < open.
 *  If @nil, will use @ref lineStyle instead.
 **/
@synthesize decreaseLineStyle;

/** @property nullable CPTFill *increaseFill
 *  @brief The fill used with a candlestick plot when close >= open.
 **/
@synthesize increaseFill;

/** @property nullable CPTFill *decreaseFill
 *  @brief The fill used with a candlestick plot when close < open.
 **/
@synthesize decreaseFill;

/** @property CPTTradingRangePlotStyle plotStyle
 *  @brief The style of trading range plot drawn. The default is #CPTTradingRangePlotStyleOHLC.
 **/
@synthesize plotStyle;

/** @property CGFloat barWidth
 *  @brief The width of bars in candlestick plots (view coordinates).
 *  @ingroup plotAnimationTradingRangePlot
 **/
@synthesize barWidth;

/** @property CGFloat stickLength
 *  @brief The length of close and open sticks on OHLC plots (view coordinates).
 *  @ingroup plotAnimationTradingRangePlot
 **/
@synthesize stickLength;

/** @property CGFloat barCornerRadius
 *  @brief The corner radius used for candlestick plots.
 *  Defaults to @num{0.0}.
 *  @ingroup plotAnimationTradingRangePlot
 **/
@synthesize barCornerRadius;

/** @property BOOL showBarBorder
 *  @brief If @YES, the candlestick body will show a border.
 *  @ingroup plotAnimationTradingRangePlot
 **/
@synthesize showBarBorder;

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
    if ( self == [CPTTradingRangePlot class] ) {
        [self exposeBinding:CPTTradingRangePlotBindingXValues];
        [self exposeBinding:CPTTradingRangePlotBindingOpenValues];
        [self exposeBinding:CPTTradingRangePlotBindingHighValues];
        [self exposeBinding:CPTTradingRangePlotBindingLowValues];
        [self exposeBinding:CPTTradingRangePlotBindingCloseValues];
        [self exposeBinding:CPTTradingRangePlotBindingIncreaseFills];
        [self exposeBinding:CPTTradingRangePlotBindingDecreaseFills];
        [self exposeBinding:CPTTradingRangePlotBindingLineStyles];
        [self exposeBinding:CPTTradingRangePlotBindingIncreaseLineStyles];
        [self exposeBinding:CPTTradingRangePlotBindingDecreaseLineStyles];
        [self exposeBinding:CPTTradingRangePlotBindingBarWidths];
    }
}

#endif

/// @endcond

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTTradingRangePlot object with the provided frame rectangle.
 *
 *  This is the designated initializer. The initialized layer will have the following properties:
 *  - @ref plotStyle = #CPTTradingRangePlotStyleOHLC
 *  - @ref lineStyle = default line style
 *  - @ref increaseLineStyle = @nil
 *  - @ref decreaseLineStyle = @nil
 *  - @ref increaseFill = solid white fill
 *  - @ref decreaseFill = solid black fill
 *  - @ref barWidth = @num{5.0}
 *  - @ref stickLength = @num{3.0}
 *  - @ref barCornerRadius = @num{0.0}
 *  - @ref showBarBorder = @YES
 *  - @ref labelField = #CPTTradingRangePlotFieldClose
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTTradingRangePlot object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame
{
    if ((self = [super initWithFrame:newFrame])) {
        plotStyle         = CPTTradingRangePlotStyleOHLC;
        lineStyle         = [[CPTLineStyle alloc] init];
        increaseLineStyle = nil;
        decreaseLineStyle = nil;
        increaseFill      = [[CPTFill alloc] initWithColor:[CPTColor whiteColor]];
        decreaseFill      = [[CPTFill alloc] initWithColor:[CPTColor blackColor]];
        barWidth          = CPTFloat(5.0);
        stickLength       = CPTFloat(3.0);
        barCornerRadius   = CPTFloat(0.0);
        showBarBorder     = YES;

        pointingDeviceDownIndex = NSNotFound;

        self.labelField = CPTTradingRangePlotFieldClose;
    }
    return self;
}

/// @}

/// @cond

-(nonnull instancetype)initWithLayer:(nonnull id)layer
{
    if ((self = [super initWithLayer:layer])) {
        CPTTradingRangePlot *theLayer = (CPTTradingRangePlot *)layer;

        plotStyle         = theLayer->plotStyle;
        lineStyle         = theLayer->lineStyle;
        increaseLineStyle = theLayer->increaseLineStyle;
        decreaseLineStyle = theLayer->decreaseLineStyle;
        increaseFill      = theLayer->increaseFill;
        decreaseFill      = theLayer->decreaseFill;
        barWidth          = theLayer->barWidth;
        stickLength       = theLayer->stickLength;
        barCornerRadius   = theLayer->barCornerRadius;
        showBarBorder     = theLayer->showBarBorder;

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

    [coder encodeObject:self.lineStyle forKey:@"CPTTradingRangePlot.lineStyle"];
    [coder encodeObject:self.increaseLineStyle forKey:@"CPTTradingRangePlot.increaseLineStyle"];
    [coder encodeObject:self.decreaseLineStyle forKey:@"CPTTradingRangePlot.decreaseLineStyle"];
    [coder encodeObject:self.increaseFill forKey:@"CPTTradingRangePlot.increaseFill"];
    [coder encodeObject:self.decreaseFill forKey:@"CPTTradingRangePlot.decreaseFill"];
    [coder encodeInteger:self.plotStyle forKey:@"CPTTradingRangePlot.plotStyle"];
    [coder encodeCGFloat:self.barWidth forKey:@"CPTTradingRangePlot.barWidth"];
    [coder encodeCGFloat:self.stickLength forKey:@"CPTTradingRangePlot.stickLength"];
    [coder encodeCGFloat:self.barCornerRadius forKey:@"CPTTradingRangePlot.barCornerRadius"];
    [coder encodeBool:self.showBarBorder forKey:@"CPTTradingRangePlot.showBarBorder"];

    // No need to archive these properties:
    // pointingDeviceDownIndex
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        lineStyle = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                         forKey:@"CPTTradingRangePlot.lineStyle"] copy];
        increaseLineStyle = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                                 forKey:@"CPTTradingRangePlot.increaseLineStyle"] copy];
        decreaseLineStyle = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                                 forKey:@"CPTTradingRangePlot.decreaseLineStyle"] copy];
        increaseFill = [[coder decodeObjectOfClass:[CPTFill class]
                                            forKey:@"CPTTradingRangePlot.increaseFill"] copy];
        decreaseFill = [[coder decodeObjectOfClass:[CPTFill class]
                                            forKey:@"CPTTradingRangePlot.decreaseFill"] copy];
        plotStyle       = (CPTTradingRangePlotStyle)[coder decodeIntegerForKey:@"CPTTradingRangePlot.plotStyle"];
        barWidth        = [coder decodeCGFloatForKey:@"CPTTradingRangePlot.barWidth"];
        stickLength     = [coder decodeCGFloatForKey:@"CPTTradingRangePlot.stickLength"];
        barCornerRadius = [coder decodeCGFloatForKey:@"CPTTradingRangePlot.barCornerRadius"];
        showBarBorder   = [coder decodeBoolForKey:@"CPTTradingRangePlot.showBarBorder"];

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
#pragma mark Data Loading

/// @cond

-(void)reloadDataInIndexRange:(NSRange)indexRange
{
    [super reloadDataInIndexRange:indexRange];

    // Fills
    [self reloadBarFillsInIndexRange:indexRange];

    // Line styles
    [self reloadBarLineStylesInIndexRange:indexRange];

    // Bar widths
    [self reloadBarWidthsInIndexRange:indexRange];
}

-(void)reloadPlotDataInIndexRange:(NSRange)indexRange
{
    [super reloadPlotDataInIndexRange:indexRange];

    if ( ![self loadNumbersForAllFieldsFromDataSourceInRecordIndexRange:indexRange] ) {
        id<CPTTradingRangePlotDataSource> theDataSource = (id<CPTTradingRangePlotDataSource>)self.dataSource;

        if ( theDataSource ) {
            id newXValues = [self numbersFromDataSourceForField:CPTTradingRangePlotFieldX recordIndexRange:indexRange];
            [self cacheNumbers:newXValues forField:CPTTradingRangePlotFieldX atRecordIndex:indexRange.location];
            id newOpenValues = [self numbersFromDataSourceForField:CPTTradingRangePlotFieldOpen recordIndexRange:indexRange];
            [self cacheNumbers:newOpenValues forField:CPTTradingRangePlotFieldOpen atRecordIndex:indexRange.location];
            id newHighValues = [self numbersFromDataSourceForField:CPTTradingRangePlotFieldHigh recordIndexRange:indexRange];
            [self cacheNumbers:newHighValues forField:CPTTradingRangePlotFieldHigh atRecordIndex:indexRange.location];
            id newLowValues = [self numbersFromDataSourceForField:CPTTradingRangePlotFieldLow recordIndexRange:indexRange];
            [self cacheNumbers:newLowValues forField:CPTTradingRangePlotFieldLow atRecordIndex:indexRange.location];
            id newCloseValues = [self numbersFromDataSourceForField:CPTTradingRangePlotFieldClose recordIndexRange:indexRange];
            [self cacheNumbers:newCloseValues forField:CPTTradingRangePlotFieldClose atRecordIndex:indexRange.location];
        }
        else {
            self.xValues     = nil;
            self.openValues  = nil;
            self.highValues  = nil;
            self.lowValues   = nil;
            self.closeValues = nil;
        }
    }
}

/// @endcond

/**
 *  @brief Reload all bar fills from the data source immediately.
 **/
-(void)reloadBarFills
{
    [self reloadBarFillsInIndexRange:NSMakeRange(0, self.cachedDataCount)];
}

/** @brief Reload bar fills in the given index range from the data source immediately.
 *  @param indexRange The index range to load.
 **/
-(void)reloadBarFillsInIndexRange:(NSRange)indexRange
{
    id<CPTTradingRangePlotDataSource> theDataSource = (id<CPTTradingRangePlotDataSource>)self.dataSource;

    BOOL needsLegendUpdate = NO;

    // Increase fills
    if ( [theDataSource respondsToSelector:@selector(increaseFillsForTradingRangePlot:recordIndexRange:)] ) {
        needsLegendUpdate = YES;

        [self cacheArray:[theDataSource increaseFillsForTradingRangePlot:self recordIndexRange:indexRange]
                  forKey:CPTTradingRangePlotBindingIncreaseFills
           atRecordIndex:indexRange.location];
    }
    else if ( [theDataSource respondsToSelector:@selector(increaseFillForTradingRangePlot:recordIndex:)] ) {
        needsLegendUpdate = YES;

        id nilObject               = [CPTPlot nilData];
        CPTMutableFillArray *array = [[NSMutableArray alloc] initWithCapacity:indexRange.length];
        NSUInteger maxIndex        = NSMaxRange(indexRange);

        for ( NSUInteger idx = indexRange.location; idx < maxIndex; idx++ ) {
            CPTFill *dataSourceFill = [theDataSource increaseFillForTradingRangePlot:self recordIndex:idx];
            if ( dataSourceFill ) {
                [array addObject:dataSourceFill];
            }
            else {
                [array addObject:nilObject];
            }
        }

        [self cacheArray:array forKey:CPTTradingRangePlotBindingIncreaseFills atRecordIndex:indexRange.location];
    }

    // Decrease fills
    if ( [theDataSource respondsToSelector:@selector(decreaseFillsForTradingRangePlot:recordIndexRange:)] ) {
        needsLegendUpdate = YES;

        [self cacheArray:[theDataSource decreaseFillsForTradingRangePlot:self recordIndexRange:indexRange]
                  forKey:CPTTradingRangePlotBindingDecreaseFills
           atRecordIndex:indexRange.location];
    }
    else if ( [theDataSource respondsToSelector:@selector(decreaseFillForTradingRangePlot:recordIndex:)] ) {
        needsLegendUpdate = YES;

        id nilObject               = [CPTPlot nilData];
        CPTMutableFillArray *array = [[NSMutableArray alloc] initWithCapacity:indexRange.length];
        NSUInteger maxIndex        = NSMaxRange(indexRange);

        for ( NSUInteger idx = indexRange.location; idx < maxIndex; idx++ ) {
            CPTFill *dataSourceFill = [theDataSource decreaseFillForTradingRangePlot:self recordIndex:idx];
            if ( dataSourceFill ) {
                [array addObject:dataSourceFill];
            }
            else {
                [array addObject:nilObject];
            }
        }

        [self cacheArray:array forKey:CPTTradingRangePlotBindingDecreaseFills atRecordIndex:indexRange.location];
    }

    // Legend
    if ( needsLegendUpdate ) {
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }

    [self setNeedsDisplay];
}

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
    id<CPTTradingRangePlotDataSource> theDataSource = (id<CPTTradingRangePlotDataSource>)self.dataSource;

    BOOL needsLegendUpdate = NO;

    // Line style
    if ( [theDataSource respondsToSelector:@selector(lineStylesForTradingRangePlot:recordIndexRange:)] ) {
        needsLegendUpdate = YES;

        [self cacheArray:[theDataSource lineStylesForTradingRangePlot:self recordIndexRange:indexRange]
                  forKey:CPTTradingRangePlotBindingLineStyles
           atRecordIndex:indexRange.location];
    }
    else if ( [theDataSource respondsToSelector:@selector(lineStyleForTradingRangePlot:recordIndex:)] ) {
        needsLegendUpdate = YES;

        id nilObject                    = [CPTPlot nilData];
        CPTMutableLineStyleArray *array = [[NSMutableArray alloc] initWithCapacity:indexRange.length];
        NSUInteger maxIndex             = NSMaxRange(indexRange);

        for ( NSUInteger idx = indexRange.location; idx < maxIndex; idx++ ) {
            CPTLineStyle *dataSourceLineStyle = [theDataSource lineStyleForTradingRangePlot:self recordIndex:idx];
            if ( dataSourceLineStyle ) {
                [array addObject:dataSourceLineStyle];
            }
            else {
                [array addObject:nilObject];
            }
        }

        [self cacheArray:array forKey:CPTTradingRangePlotBindingLineStyles atRecordIndex:indexRange.location];
    }

    // Increase line style
    if ( [theDataSource respondsToSelector:@selector(increaseLineStylesForTradingRangePlot:recordIndexRange:)] ) {
        needsLegendUpdate = YES;

        [self cacheArray:[theDataSource increaseLineStylesForTradingRangePlot:self recordIndexRange:indexRange]
                  forKey:CPTTradingRangePlotBindingIncreaseLineStyles
           atRecordIndex:indexRange.location];
    }
    else if ( [theDataSource respondsToSelector:@selector(increaseLineStyleForTradingRangePlot:recordIndex:)] ) {
        needsLegendUpdate = YES;

        id nilObject                    = [CPTPlot nilData];
        CPTMutableLineStyleArray *array = [[NSMutableArray alloc] initWithCapacity:indexRange.length];
        NSUInteger maxIndex             = NSMaxRange(indexRange);

        for ( NSUInteger idx = indexRange.location; idx < maxIndex; idx++ ) {
            CPTLineStyle *dataSourceLineStyle = [theDataSource increaseLineStyleForTradingRangePlot:self recordIndex:idx];
            if ( dataSourceLineStyle ) {
                [array addObject:dataSourceLineStyle];
            }
            else {
                [array addObject:nilObject];
            }
        }

        [self cacheArray:array forKey:CPTTradingRangePlotBindingIncreaseLineStyles atRecordIndex:indexRange.location];
    }

    // Decrease line styles
    if ( [theDataSource respondsToSelector:@selector(decreaseLineStylesForTradingRangePlot:recordIndexRange:)] ) {
        needsLegendUpdate = YES;

        [self cacheArray:[theDataSource decreaseLineStylesForTradingRangePlot:self recordIndexRange:indexRange]
                  forKey:CPTTradingRangePlotBindingDecreaseLineStyles
           atRecordIndex:indexRange.location];
    }
    else if ( [theDataSource respondsToSelector:@selector(decreaseLineStyleForTradingRangePlot:recordIndex:)] ) {
        needsLegendUpdate = YES;

        id nilObject                    = [CPTPlot nilData];
        CPTMutableLineStyleArray *array = [[NSMutableArray alloc] initWithCapacity:indexRange.length];
        NSUInteger maxIndex             = NSMaxRange(indexRange);

        for ( NSUInteger idx = indexRange.location; idx < maxIndex; idx++ ) {
            CPTLineStyle *dataSourceLineStyle = [theDataSource decreaseLineStyleForTradingRangePlot:self recordIndex:idx];
            if ( dataSourceLineStyle ) {
                [array addObject:dataSourceLineStyle];
            }
            else {
                [array addObject:nilObject];
            }
        }

        [self cacheArray:array forKey:CPTTradingRangePlotBindingDecreaseLineStyles atRecordIndex:indexRange.location];
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
    id<CPTTradingRangePlotDataSource> theDataSource = (id<CPTTradingRangePlotDataSource>)self.dataSource;

    if ( [theDataSource respondsToSelector:@selector(barWidthsForTradingRangePlot:recordIndexRange:)] ) {
        [self cacheArray:[theDataSource barWidthsForTradingRangePlot:self recordIndexRange:indexRange]
                  forKey:CPTTradingRangePlotBindingBarWidths
           atRecordIndex:indexRange.location];
    }
    else if ( [theDataSource respondsToSelector:@selector(barWidthForTradingRangePlot:recordIndex:)] ) {
        id nilObject                 = [CPTPlot nilData];
        CPTMutableNumberArray *array = [[NSMutableArray alloc] initWithCapacity:indexRange.length];
        NSUInteger maxIndex          = NSMaxRange(indexRange);

        for ( NSUInteger idx = indexRange.location; idx < maxIndex; idx++ ) {
            NSNumber *width = [theDataSource barWidthForTradingRangePlot:self recordIndex:idx];
            if ( width ) {
                [array addObject:width];
            }
            else {
                [array addObject:nilObject];
            }
        }

        [self cacheArray:array
                  forKey:CPTTradingRangePlotBindingBarWidths
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

    CPTMutableNumericData *locations = [self cachedNumbersForField:CPTTradingRangePlotFieldX];
    CPTMutableNumericData *opens     = [self cachedNumbersForField:CPTTradingRangePlotFieldOpen];
    CPTMutableNumericData *highs     = [self cachedNumbersForField:CPTTradingRangePlotFieldHigh];
    CPTMutableNumericData *lows      = [self cachedNumbersForField:CPTTradingRangePlotFieldLow];
    CPTMutableNumericData *closes    = [self cachedNumbersForField:CPTTradingRangePlotFieldClose];

    NSUInteger sampleCount = locations.numberOfSamples;
    if ( sampleCount == 0 ) {
        return;
    }
    if ((opens == nil) || (highs == nil) || (lows == nil) || (closes == nil)) {
        return;
    }

    if ((opens.numberOfSamples != sampleCount) || (highs.numberOfSamples != sampleCount) || (lows.numberOfSamples != sampleCount) || (closes.numberOfSamples != sampleCount)) {
        [NSException raise:CPTException format:@"Mismatching number of data values in trading range plot"];
    }

    [super renderAsVectorInContext:context];

    CGPoint openPoint, highPoint, lowPoint, closePoint;

    CPTPlotSpace *thePlotSpace            = self.plotSpace;
    CPTTradingRangePlotStyle thePlotStyle = self.plotStyle;
    BOOL alignPoints                      = self.alignsPointsToPixels;

    CGContextBeginTransparencyLayer(context, NULL);

    if ( self.doublePrecisionCache ) {
        const double *locationBytes = (const double *)locations.data.bytes;
        const double *openBytes     = (const double *)opens.data.bytes;
        const double *highBytes     = (const double *)highs.data.bytes;
        const double *lowBytes      = (const double *)lows.data.bytes;
        const double *closeBytes    = (const double *)closes.data.bytes;

        for ( NSUInteger i = 0; i < sampleCount; i++ ) {
            double plotPoint[2];
            plotPoint[independentCoord] = *locationBytes++;
            if ( isnan(plotPoint[independentCoord])) {
                openBytes++;
                highBytes++;
                lowBytes++;
                closeBytes++;
                continue;
            }

            // open point
            plotPoint[dependentCoord] = *openBytes++;
            if ( isnan(plotPoint[dependentCoord])) {
                openPoint = CPTPointMake(NAN, NAN);
            }
            else {
                openPoint = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
            }

            // high point
            plotPoint[dependentCoord] = *highBytes++;
            if ( isnan(plotPoint[dependentCoord])) {
                highPoint = CPTPointMake(NAN, NAN);
            }
            else {
                highPoint = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
            }

            // low point
            plotPoint[dependentCoord] = *lowBytes++;
            if ( isnan(plotPoint[dependentCoord])) {
                lowPoint = CPTPointMake(NAN, NAN);
            }
            else {
                lowPoint = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
            }

            // close point
            plotPoint[dependentCoord] = *closeBytes++;
            if ( isnan(plotPoint[dependentCoord])) {
                closePoint = CPTPointMake(NAN, NAN);
            }
            else {
                closePoint = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
            }

            CGFloat xCoord = openPoint.x;
            if ( isnan(xCoord)) {
                xCoord = highPoint.x;
            }
            else if ( isnan(xCoord)) {
                xCoord = lowPoint.x;
            }
            else if ( isnan(xCoord)) {
                xCoord = closePoint.x;
            }

            if ( !isnan(xCoord)) {
                // Draw
                switch ( thePlotStyle ) {
                    case CPTTradingRangePlotStyleOHLC:
                        [self drawOHLCInContext:context
                                        atIndex:i
                                              x:xCoord
                                           open:openPoint.y
                                          close:closePoint.y
                                           high:highPoint.y
                                            low:lowPoint.y
                                    alignPoints:alignPoints];
                        break;

                    case CPTTradingRangePlotStyleCandleStick:
                        [self drawCandleStickInContext:context
                                               atIndex:i
                                                     x:xCoord
                                                  open:openPoint.y
                                                 close:closePoint.y
                                                  high:highPoint.y
                                                   low:lowPoint.y
                                                 width:[self barWidthForIndex:i].cgFloatValue
                                           alignPoints:alignPoints];
                        break;
                }
            }
        }
    }
    else {
        const NSDecimal *locationBytes = (const NSDecimal *)locations.data.bytes;
        const NSDecimal *openBytes     = (const NSDecimal *)opens.data.bytes;
        const NSDecimal *highBytes     = (const NSDecimal *)highs.data.bytes;
        const NSDecimal *lowBytes      = (const NSDecimal *)lows.data.bytes;
        const NSDecimal *closeBytes    = (const NSDecimal *)closes.data.bytes;

        for ( NSUInteger i = 0; i < sampleCount; i++ ) {
            NSDecimal plotPoint[2];
            plotPoint[independentCoord] = *locationBytes++;
            if ( NSDecimalIsNotANumber(&plotPoint[independentCoord])) {
                openBytes++;
                highBytes++;
                lowBytes++;
                closeBytes++;
                continue;
            }

            // open point
            plotPoint[dependentCoord] = *openBytes++;
            if ( NSDecimalIsNotANumber(&plotPoint[dependentCoord])) {
                openPoint = CPTPointMake(NAN, NAN);
            }
            else {
                openPoint = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
            }

            // high point
            plotPoint[dependentCoord] = *highBytes++;
            if ( NSDecimalIsNotANumber(&plotPoint[dependentCoord])) {
                highPoint = CPTPointMake(NAN, NAN);
            }
            else {
                highPoint = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
            }

            // low point
            plotPoint[dependentCoord] = *lowBytes++;
            if ( NSDecimalIsNotANumber(&plotPoint[dependentCoord])) {
                lowPoint = CPTPointMake(NAN, NAN);
            }
            else {
                lowPoint = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
            }

            // close point
            plotPoint[dependentCoord] = *closeBytes++;
            if ( NSDecimalIsNotANumber(&plotPoint[dependentCoord])) {
                closePoint = CPTPointMake(NAN, NAN);
            }
            else {
                closePoint = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
            }

            CGFloat xCoord = openPoint.x;
            if ( isnan(xCoord)) {
                xCoord = highPoint.x;
            }
            else if ( isnan(xCoord)) {
                xCoord = lowPoint.x;
            }
            else if ( isnan(xCoord)) {
                xCoord = closePoint.x;
            }

            if ( !isnan(xCoord)) {
                // Draw
                switch ( thePlotStyle ) {
                    case CPTTradingRangePlotStyleOHLC:
                        [self drawOHLCInContext:context
                                        atIndex:i
                                              x:xCoord
                                           open:openPoint.y
                                          close:closePoint.y
                                           high:highPoint.y
                                            low:lowPoint.y
                                    alignPoints:alignPoints];
                        break;

                    case CPTTradingRangePlotStyleCandleStick:
                        [self drawCandleStickInContext:context
                                               atIndex:i
                                                     x:xCoord
                                                  open:openPoint.y
                                                 close:closePoint.y
                                                  high:highPoint.y
                                                   low:lowPoint.y
                                                 width:[self barWidthForIndex:i].cgFloatValue
                                           alignPoints:alignPoints];
                        break;
                }
            }
        }
    }

    CGContextEndTransparencyLayer(context);
}

-(void)drawCandleStickInContext:(nonnull CGContextRef)context
                        atIndex:(NSUInteger)idx
                              x:(CGFloat)x
                           open:(CGFloat)openValue
                          close:(CGFloat)closeValue
                           high:(CGFloat)highValue
                            low:(CGFloat)lowValue
                          width:(CGFloat)width
                    alignPoints:(BOOL)alignPoints
{
    const CGFloat halfBarWidth = CPTFloat(0.5) * width;

    CPTFill *currentBarFill          = nil;
    CPTLineStyle *theBorderLineStyle = nil;

    if ( !isnan(openValue) && !isnan(closeValue)) {
        if ( openValue < closeValue ) {
            theBorderLineStyle = [self increaseLineStyleForIndex:idx];
            currentBarFill     = [self increaseFillForIndex:idx];
        }
        else if ( openValue > closeValue ) {
            theBorderLineStyle = [self decreaseLineStyleForIndex:idx];
            currentBarFill     = [self decreaseFillForIndex:idx];
        }
        else {
            theBorderLineStyle = [self lineStyleForIndex:idx];
            CPTColor *lineColor = theBorderLineStyle.lineColor;
            if ( lineColor ) {
                currentBarFill = [CPTFill fillWithColor:lineColor];
            }
        }
    }

    CPTAlignPointFunction alignmentFunction = CPTAlignPointToUserSpace;

    BOOL hasLineStyle = [theBorderLineStyle isKindOfClass:[CPTLineStyle class]];
    if ( hasLineStyle ) {
        [theBorderLineStyle setLineStyleInContext:context];

        CGFloat lineWidth = theBorderLineStyle.lineWidth;
        if ((self.contentsScale > CPTFloat(1.0)) && (round(lineWidth) == lineWidth)) {
            alignmentFunction = CPTAlignIntegralPointToUserSpace;
        }
    }

    // high - low only
    if ( hasLineStyle && !isnan(highValue) && !isnan(lowValue) && (isnan(openValue) || isnan(closeValue))) {
        CGPoint alignedHighPoint = CPTPointMake(x, highValue);
        CGPoint alignedLowPoint  = CPTPointMake(x, lowValue);
        if ( alignPoints ) {
            alignedHighPoint = alignmentFunction(context, alignedHighPoint);
            alignedLowPoint  = alignmentFunction(context, alignedLowPoint);
        }

        CGMutablePathRef path = CGPathCreateMutable();
        CGPathMoveToPoint(path, NULL, alignedHighPoint.x, alignedHighPoint.y);
        CGPathAddLineToPoint(path, NULL, alignedLowPoint.x, alignedLowPoint.y);

        CGContextBeginPath(context);
        CGContextAddPath(context, path);
        [theBorderLineStyle strokePathInContext:context];

        CGPathRelease(path);
    }

    // open-close
    if ( !isnan(openValue) && !isnan(closeValue)) {
        if ( currentBarFill || hasLineStyle ) {
            CGFloat radius = MIN(self.barCornerRadius, halfBarWidth);
            radius = MIN(radius, ABS(closeValue - openValue));

            CGPoint alignedPoint1 = CPTPointMake(x + halfBarWidth, openValue);
            CGPoint alignedPoint2 = CPTPointMake(x + halfBarWidth, closeValue);
            CGPoint alignedPoint3 = CPTPointMake(x, closeValue);
            CGPoint alignedPoint4 = CPTPointMake(x - halfBarWidth, closeValue);
            CGPoint alignedPoint5 = CPTPointMake(x - halfBarWidth, openValue);
            if ( alignPoints ) {
                if ( hasLineStyle && self.showBarBorder ) {
                    alignedPoint1 = alignmentFunction(context, alignedPoint1);
                    alignedPoint2 = alignmentFunction(context, alignedPoint2);
                    alignedPoint3 = alignmentFunction(context, alignedPoint3);
                    alignedPoint4 = alignmentFunction(context, alignedPoint4);
                    alignedPoint5 = alignmentFunction(context, alignedPoint5);
                }
                else {
                    alignedPoint1 = CPTAlignIntegralPointToUserSpace(context, alignedPoint1);
                    alignedPoint2 = CPTAlignIntegralPointToUserSpace(context, alignedPoint2);
                    alignedPoint3 = CPTAlignIntegralPointToUserSpace(context, alignedPoint3);
                    alignedPoint4 = CPTAlignIntegralPointToUserSpace(context, alignedPoint4);
                    alignedPoint5 = CPTAlignIntegralPointToUserSpace(context, alignedPoint5);
                }
            }

            if ( hasLineStyle && (openValue == closeValue)) {
                // #285 Draw a cross with open/close values marked
                const CGFloat halfLineWidth = CPTFloat(0.5) * theBorderLineStyle.lineWidth;

                alignedPoint1.y -= halfLineWidth;
                alignedPoint2.y += halfLineWidth;
                alignedPoint3.y += halfLineWidth;
                alignedPoint4.y += halfLineWidth;
                alignedPoint5.y -= halfLineWidth;
            }

            CGMutablePathRef path = CGPathCreateMutable();
            CGPathMoveToPoint(path, NULL, alignedPoint1.x, alignedPoint1.y);
            CGPathAddArcToPoint(path, NULL, alignedPoint2.x, alignedPoint2.y, alignedPoint3.x, alignedPoint3.y, radius);
            CGPathAddArcToPoint(path, NULL, alignedPoint4.x, alignedPoint4.y, alignedPoint5.x, alignedPoint5.y, radius);
            CGPathAddLineToPoint(path, NULL, alignedPoint5.x, alignedPoint5.y);
            CGPathCloseSubpath(path);

            if ( [currentBarFill isKindOfClass:[CPTFill class]] ) {
                CGContextBeginPath(context);
                CGContextAddPath(context, path);
                [currentBarFill fillPathInContext:context];
            }

            if ( hasLineStyle ) {
                if ( !self.showBarBorder ) {
                    CGPathRelease(path);
                    path = CGPathCreateMutable();
                }

                if ( !isnan(lowValue)) {
                    if ( lowValue < MIN(openValue, closeValue)) {
                        CGPoint alignedStartPoint = CPTPointMake(x, MIN(openValue, closeValue));
                        CGPoint alignedLowPoint   = CPTPointMake(x, lowValue);
                        if ( alignPoints ) {
                            alignedStartPoint = alignmentFunction(context, alignedStartPoint);
                            alignedLowPoint   = alignmentFunction(context, alignedLowPoint);
                        }

                        CGPathMoveToPoint(path, NULL, alignedStartPoint.x, alignedStartPoint.y);
                        CGPathAddLineToPoint(path, NULL, alignedLowPoint.x, alignedLowPoint.y);
                    }
                }
                if ( !isnan(highValue)) {
                    if ( highValue > MAX(openValue, closeValue)) {
                        CGPoint alignedStartPoint = CPTPointMake(x, MAX(openValue, closeValue));
                        CGPoint alignedHighPoint  = CPTPointMake(x, highValue);
                        if ( alignPoints ) {
                            alignedStartPoint = alignmentFunction(context, alignedStartPoint);
                            alignedHighPoint  = alignmentFunction(context, alignedHighPoint);
                        }

                        CGPathMoveToPoint(path, NULL, alignedStartPoint.x, alignedStartPoint.y);
                        CGPathAddLineToPoint(path, NULL, alignedHighPoint.x, alignedHighPoint.y);
                    }
                }
                CGContextBeginPath(context);
                CGContextAddPath(context, path);
                [theBorderLineStyle strokePathInContext:context];
            }

            CGPathRelease(path);
        }
    }
}

-(void)drawOHLCInContext:(nonnull CGContextRef)context
                 atIndex:(NSUInteger)idx
                       x:(CGFloat)x
                    open:(CGFloat)openValue
                   close:(CGFloat)closeValue
                    high:(CGFloat)highValue
                     low:(CGFloat)lowValue
             alignPoints:(BOOL)alignPoints
{
    CPTLineStyle *theLineStyle = [self lineStyleForIndex:idx];

    if ( !isnan(openValue) && !isnan(closeValue)) {
        if ( openValue < closeValue ) {
            CPTLineStyle *lineStyleForIncrease = [self increaseLineStyleForIndex:idx];
            if ( [lineStyleForIncrease isKindOfClass:[CPTLineStyle class]] ) {
                theLineStyle = lineStyleForIncrease;
            }
        }
        else if ( openValue > closeValue ) {
            CPTLineStyle *lineStyleForDecrease = [self decreaseLineStyleForIndex:idx];
            if ( [lineStyleForDecrease isKindOfClass:[CPTLineStyle class]] ) {
                theLineStyle = lineStyleForDecrease;
            }
        }
    }

    if ( [theLineStyle isKindOfClass:[CPTLineStyle class]] ) {
        CGFloat theStickLength = self.stickLength;
        CGMutablePathRef path  = CGPathCreateMutable();

        CPTAlignPointFunction alignmentFunction = CPTAlignPointToUserSpace;

        CGFloat lineWidth = theLineStyle.lineWidth;
        if ((self.contentsScale > CPTFloat(1.0)) && (round(lineWidth) == lineWidth)) {
            alignmentFunction = CPTAlignIntegralPointToUserSpace;
        }

        // high-low
        if ( !isnan(highValue) && !isnan(lowValue)) {
            CGPoint alignedHighPoint = CPTPointMake(x, highValue);
            CGPoint alignedLowPoint  = CPTPointMake(x, lowValue);
            if ( alignPoints ) {
                alignedHighPoint = alignmentFunction(context, alignedHighPoint);
                alignedLowPoint  = alignmentFunction(context, alignedLowPoint);
            }
            CGPathMoveToPoint(path, NULL, alignedHighPoint.x, alignedHighPoint.y);
            CGPathAddLineToPoint(path, NULL, alignedLowPoint.x, alignedLowPoint.y);
        }

        // open
        if ( !isnan(openValue)) {
            CGPoint alignedOpenStartPoint = CPTPointMake(x, openValue);
            CGPoint alignedOpenEndPoint   = CPTPointMake(x - theStickLength, openValue); // left side
            if ( alignPoints ) {
                alignedOpenStartPoint = alignmentFunction(context, alignedOpenStartPoint);
                alignedOpenEndPoint   = alignmentFunction(context, alignedOpenEndPoint);
            }
            CGPathMoveToPoint(path, NULL, alignedOpenStartPoint.x, alignedOpenStartPoint.y);
            CGPathAddLineToPoint(path, NULL, alignedOpenEndPoint.x, alignedOpenEndPoint.y);
        }

        // close
        if ( !isnan(closeValue)) {
            CGPoint alignedCloseStartPoint = CPTPointMake(x, closeValue);
            CGPoint alignedCloseEndPoint   = CPTPointMake(x + theStickLength, closeValue); // right side
            if ( alignPoints ) {
                alignedCloseStartPoint = alignmentFunction(context, alignedCloseStartPoint);
                alignedCloseEndPoint   = alignmentFunction(context, alignedCloseEndPoint);
            }
            CGPathMoveToPoint(path, NULL, alignedCloseStartPoint.x, alignedCloseStartPoint.y);
            CGPathAddLineToPoint(path, NULL, alignedCloseEndPoint.x, alignedCloseEndPoint.y);
        }

        CGContextBeginPath(context);
        CGContextAddPath(context, path);
        [theLineStyle setLineStyleInContext:context];
        [theLineStyle strokePathInContext:context];
        CGPathRelease(path);
    }
}

-(void)drawSwatchForLegend:(nonnull CPTLegend *)legend atIndex:(NSUInteger)idx inRect:(CGRect)rect inContext:(nonnull CGContextRef)context
{
    [super drawSwatchForLegend:legend atIndex:idx inRect:rect inContext:context];

    if ( self.drawLegendSwatchDecoration ) {
        [self.lineStyle setLineStyleInContext:context];

        switch ( self.plotStyle ) {
            case CPTTradingRangePlotStyleOHLC:
                [self drawOHLCInContext:context
                                atIndex:0
                                      x:CGRectGetMidX(rect)
                                   open:CGRectGetMinY(rect) + rect.size.height / CPTFloat(3.0)
                                  close:CGRectGetMinY(rect) + rect.size.height * (CGFloat)(2.0 / 3.0)
                                   high:CGRectGetMaxY(rect)
                                    low:CGRectGetMinY(rect)
                            alignPoints:YES];
                break;

            case CPTTradingRangePlotStyleCandleStick:
                [self drawCandleStickInContext:context
                                       atIndex:0
                                             x:CGRectGetMidX(rect)
                                          open:CGRectGetMinY(rect) + rect.size.height / CPTFloat(3.0)
                                         close:CGRectGetMinY(rect) + rect.size.height * (CGFloat)(2.0 / 3.0)
                                          high:CGRectGetMaxY(rect)
                                           low:CGRectGetMinY(rect)
                                         width:rect.size.width * CPTFloat(0.8)
                                   alignPoints:YES];
                break;
        }
    }
}

-(nullable CPTFill *)increaseFillForIndex:(NSUInteger)idx
{
    CPTFill *theFill = [self cachedValueForKey:CPTTradingRangePlotBindingIncreaseFills recordIndex:idx];

    if ((theFill == nil) || (theFill == [CPTPlot nilData])) {
        theFill = self.increaseFill;
    }

    return theFill;
}

-(nullable CPTFill *)decreaseFillForIndex:(NSUInteger)idx
{
    CPTFill *theFill = [self cachedValueForKey:CPTTradingRangePlotBindingDecreaseFills recordIndex:idx];

    if ((theFill == nil) || (theFill == [CPTPlot nilData])) {
        theFill = self.decreaseFill;
    }

    return theFill;
}

-(nullable CPTLineStyle *)lineStyleForIndex:(NSUInteger)idx
{
    CPTLineStyle *theLineStyle = [self cachedValueForKey:CPTTradingRangePlotBindingLineStyles recordIndex:idx];

    if ((theLineStyle == nil) || (theLineStyle == [CPTPlot nilData])) {
        theLineStyle = self.lineStyle;
    }

    return theLineStyle;
}

-(nullable CPTLineStyle *)increaseLineStyleForIndex:(NSUInteger)idx
{
    CPTLineStyle *theLineStyle = [self cachedValueForKey:CPTTradingRangePlotBindingIncreaseLineStyles recordIndex:idx];

    if ((theLineStyle == nil) || (theLineStyle == [CPTPlot nilData])) {
        theLineStyle = self.increaseLineStyle;
    }

    if ( theLineStyle == nil ) {
        theLineStyle = [self lineStyleForIndex:idx];
    }

    return theLineStyle;
}

-(nullable CPTLineStyle *)decreaseLineStyleForIndex:(NSUInteger)idx
{
    CPTLineStyle *theLineStyle = [self cachedValueForKey:CPTTradingRangePlotBindingDecreaseLineStyles recordIndex:idx];

    if ((theLineStyle == nil) || (theLineStyle == [CPTPlot nilData])) {
        theLineStyle = self.decreaseLineStyle;
    }

    if ( theLineStyle == nil ) {
        theLineStyle = [self lineStyleForIndex:idx];
    }

    return theLineStyle;
}

-(nonnull NSNumber *)barWidthForIndex:(NSUInteger)idx
{
    NSNumber *theBarWidth = [self cachedValueForKey:CPTTradingRangePlotBindingBarWidths recordIndex:idx];

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
                                     @"stickLength",
                                     @"barCornerRadius",
                                     @"showBarBorder"]];
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
    return 5;
}

-(nonnull CPTNumberArray *)fieldIdentifiers
{
    return @[@(CPTTradingRangePlotFieldX),
             @(CPTTradingRangePlotFieldOpen),
             @(CPTTradingRangePlotFieldClose),
             @(CPTTradingRangePlotFieldHigh),
             @(CPTTradingRangePlotFieldLow)];
}

-(nonnull CPTNumberArray *)fieldIdentifiersForCoordinate:(CPTCoordinate)coord
{
    CPTNumberArray *result = nil;

    switch ( coord ) {
        case CPTCoordinateX:
            result = @[@(CPTTradingRangePlotFieldX)];
        break;

        case CPTCoordinateY:
            result = @[@(CPTTradingRangePlotFieldOpen),
                       @(CPTTradingRangePlotFieldLow),
                       @(CPTTradingRangePlotFieldHigh),
                       @(CPTTradingRangePlotFieldClose)];
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
        case CPTTradingRangePlotFieldX:
            coordinate = CPTCoordinateX;
            break;

        case CPTTradingRangePlotFieldOpen:
        case CPTTradingRangePlotFieldLow:
        case CPTTradingRangePlotFieldHigh:
        case CPTTradingRangePlotFieldClose:
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
    BOOL positiveDirection = YES;
    CPTPlotRange *yRange   = [self.plotSpace plotRangeForCoordinate:CPTCoordinateY];

    if ( CPTDecimalLessThan(yRange.lengthDecimal, CPTDecimalFromInteger(0))) {
        positiveDirection = !positiveDirection;
    }

    NSNumber *xValue     = [self cachedNumberForField:CPTTradingRangePlotFieldX recordIndex:idx];
    NSNumber *openValue  = [self cachedNumberForField:CPTTradingRangePlotFieldOpen recordIndex:idx];
    NSNumber *closeValue = [self cachedNumberForField:CPTTradingRangePlotFieldClose recordIndex:idx];
    NSNumber *highValue  = [self cachedNumberForField:CPTTradingRangePlotFieldHigh recordIndex:idx];
    NSNumber *lowValue   = [self cachedNumberForField:CPTTradingRangePlotFieldLow recordIndex:idx];

    NSNumber *yValue;
    CPTNumberArray *yValues = @[openValue,
                                closeValue,
                                highValue,
                                lowValue];
    CPTNumberArray *yValuesSorted = [yValues sortedArrayUsingSelector:@selector(compare:)];
    if ( positiveDirection ) {
        yValue = yValuesSorted.lastObject;
    }
    else {
        yValue = yValuesSorted[0];
    }

    label.anchorPlotPoint = @[xValue, yValue];

    if ( positiveDirection ) {
        label.displacement = CPTPointMake(0.0, self.labelOffset);
    }
    else {
        label.displacement = CPTPointMake(0.0, -self.labelOffset);
    }

    label.contentLayer.hidden = self.hidden || isnan([xValue doubleValue]) || isnan([yValue doubleValue]);
}

/// @endcond

#pragma mark -
#pragma mark Responder Chain and User Interaction

/// @cond

-(NSUInteger)dataIndexFromInteractionPoint:(CGPoint)point
{
    NSUInteger dataCount = self.cachedDataCount;

    CPTMutableNumericData *locations = [self cachedNumbersForField:CPTTradingRangePlotFieldX];
    CPTMutableNumericData *opens     = [self cachedNumbersForField:CPTTradingRangePlotFieldOpen];
    CPTMutableNumericData *highs     = [self cachedNumbersForField:CPTTradingRangePlotFieldHigh];
    CPTMutableNumericData *lows      = [self cachedNumbersForField:CPTTradingRangePlotFieldLow];
    CPTMutableNumericData *closes    = [self cachedNumbersForField:CPTTradingRangePlotFieldClose];

    CPTXYPlotSpace *thePlotSpace = (CPTXYPlotSpace *)self.plotSpace;
    CPTPlotRange *xRange         = thePlotSpace.xRange;
    CPTPlotRange *yRange         = thePlotSpace.yRange;

    CGPoint openPoint, highPoint, lowPoint, closePoint;

    CGFloat lastViewX   = CPTFloat(0.0);
    CGFloat lastViewMin = CPTFloat(0.0);
    CGFloat lastViewMax = CPTFloat(0.0);

    NSUInteger result              = NSNotFound;
    CGFloat minimumDistanceSquared = CPTNAN;

    if ( self.doublePrecisionCache ) {
        const double *locationBytes = (const double *)locations.data.bytes;
        const double *openBytes     = (const double *)opens.data.bytes;
        const double *highBytes     = (const double *)highs.data.bytes;
        const double *lowBytes      = (const double *)lows.data.bytes;
        const double *closeBytes    = (const double *)closes.data.bytes;

        for ( NSUInteger i = 0; i < dataCount; i++ ) {
            double plotPoint[2];

            plotPoint[independentCoord] = *locationBytes++;
            if ( isnan(plotPoint[independentCoord]) || ![xRange containsDouble:plotPoint[independentCoord]] ) {
                openBytes++;
                highBytes++;
                lowBytes++;
                closeBytes++;
                continue;
            }

            // open point
            plotPoint[dependentCoord] = *openBytes++;
            if ( !isnan(plotPoint[dependentCoord]) && [yRange containsDouble:plotPoint[dependentCoord]] ) {
                openPoint = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
                CGFloat distanceSquared = squareOfDistanceBetweenPoints(point, openPoint);
                if ( isnan(minimumDistanceSquared) || (distanceSquared < minimumDistanceSquared)) {
                    minimumDistanceSquared = distanceSquared;
                    result                 = i;
                }
            }
            else {
                openPoint = CPTPointMake(NAN, NAN);
            }

            // high point
            plotPoint[dependentCoord] = *highBytes++;
            if ( !isnan(plotPoint[dependentCoord]) && [yRange containsDouble:plotPoint[dependentCoord]] ) {
                highPoint = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
                CGFloat distanceSquared = squareOfDistanceBetweenPoints(point, highPoint);
                if ( isnan(minimumDistanceSquared) || (distanceSquared < minimumDistanceSquared)) {
                    minimumDistanceSquared = distanceSquared;
                    result                 = i;
                }
            }
            else {
                highPoint = CPTPointMake(NAN, NAN);
            }

            // low point
            plotPoint[dependentCoord] = *lowBytes++;
            if ( !isnan(plotPoint[dependentCoord]) && [yRange containsDouble:plotPoint[dependentCoord]] ) {
                lowPoint = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
                CGFloat distanceSquared = squareOfDistanceBetweenPoints(point, lowPoint);
                if ( isnan(minimumDistanceSquared) || (distanceSquared < minimumDistanceSquared)) {
                    minimumDistanceSquared = distanceSquared;
                    result                 = i;
                }
            }
            else {
                lowPoint = CPTPointMake(NAN, NAN);
            }

            // close point
            plotPoint[dependentCoord] = *closeBytes++;
            if ( !isnan(plotPoint[dependentCoord]) && [yRange containsDouble:plotPoint[dependentCoord]] ) {
                closePoint = [thePlotSpace plotAreaViewPointForDoublePrecisionPlotPoint:plotPoint numberOfCoordinates:2];
                CGFloat distanceSquared = squareOfDistanceBetweenPoints(point, closePoint);
                if ( isnan(minimumDistanceSquared) || (distanceSquared < minimumDistanceSquared)) {
                    minimumDistanceSquared = distanceSquared;
                    result                 = i;
                }
            }
            else {
                closePoint = CPTPointMake(NAN, NAN);
            }

            if ( result == i ) {
                lastViewX = openPoint.x;
                if ( isnan(lastViewX)) {
                    lastViewX = highPoint.x;
                }
                else if ( isnan(lastViewX)) {
                    lastViewX = lowPoint.x;
                }
                else if ( isnan(lastViewX)) {
                    lastViewX = closePoint.x;
                }

                lastViewMin = MIN(MIN(openPoint.y, closePoint.y), MIN(highPoint.y, lowPoint.y));
                lastViewMax = MAX(MAX(openPoint.y, closePoint.y), MAX(highPoint.y, lowPoint.y));
            }
        }
    }
    else {
        const NSDecimal *locationBytes = (const NSDecimal *)locations.data.bytes;
        const NSDecimal *openBytes     = (const NSDecimal *)opens.data.bytes;
        const NSDecimal *highBytes     = (const NSDecimal *)highs.data.bytes;
        const NSDecimal *lowBytes      = (const NSDecimal *)lows.data.bytes;
        const NSDecimal *closeBytes    = (const NSDecimal *)closes.data.bytes;

        for ( NSUInteger i = 0; i < dataCount; i++ ) {
            NSDecimal plotPoint[2];
            plotPoint[dependentCoord] = CPTDecimalNaN();

            plotPoint[independentCoord] = *locationBytes++;
            if ( NSDecimalIsNotANumber(&plotPoint[independentCoord]) || ![xRange contains:plotPoint[independentCoord]] ) {
                openBytes++;
                highBytes++;
                lowBytes++;
                closeBytes++;
                continue;
            }

            // open point
            plotPoint[dependentCoord] = *openBytes++;
            if ( !NSDecimalIsNotANumber(&plotPoint[dependentCoord]) && [yRange contains:plotPoint[dependentCoord]] ) {
                openPoint = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
                CGFloat distanceSquared = squareOfDistanceBetweenPoints(point, openPoint);
                if ( isnan(minimumDistanceSquared) || (distanceSquared < minimumDistanceSquared)) {
                    minimumDistanceSquared = distanceSquared;
                    result                 = i;
                }
            }
            else {
                openPoint = CPTPointMake(NAN, NAN);
            }

            // high point
            plotPoint[dependentCoord] = *highBytes++;
            if ( !NSDecimalIsNotANumber(&plotPoint[dependentCoord]) && [yRange contains:plotPoint[dependentCoord]] ) {
                highPoint = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
                CGFloat distanceSquared = squareOfDistanceBetweenPoints(point, highPoint);
                if ( isnan(minimumDistanceSquared) || (distanceSquared < minimumDistanceSquared)) {
                    minimumDistanceSquared = distanceSquared;
                    result                 = i;
                }
            }
            else {
                highPoint = CPTPointMake(NAN, NAN);
            }

            // low point
            plotPoint[dependentCoord] = *lowBytes++;
            if ( !NSDecimalIsNotANumber(&plotPoint[dependentCoord]) && [yRange contains:plotPoint[dependentCoord]] ) {
                lowPoint = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
                CGFloat distanceSquared = squareOfDistanceBetweenPoints(point, lowPoint);
                if ( isnan(minimumDistanceSquared) || (distanceSquared < minimumDistanceSquared)) {
                    minimumDistanceSquared = distanceSquared;
                    result                 = i;
                }
            }
            else {
                lowPoint = CPTPointMake(NAN, NAN);
            }

            // close point
            plotPoint[dependentCoord] = *closeBytes++;
            if ( !NSDecimalIsNotANumber(&plotPoint[dependentCoord]) && [yRange contains:plotPoint[dependentCoord]] ) {
                closePoint = [thePlotSpace plotAreaViewPointForPlotPoint:plotPoint numberOfCoordinates:2];
                CGFloat distanceSquared = squareOfDistanceBetweenPoints(point, closePoint);
                if ( isnan(minimumDistanceSquared) || (distanceSquared < minimumDistanceSquared)) {
                    minimumDistanceSquared = distanceSquared;
                    result                 = i;
                }
            }
            else {
                closePoint = CPTPointMake(NAN, NAN);
            }

            if ( result == i ) {
                lastViewX = openPoint.x;
                if ( isnan(lastViewX)) {
                    lastViewX = highPoint.x;
                }
                else if ( isnan(lastViewX)) {
                    lastViewX = lowPoint.x;
                }
                else if ( isnan(lastViewX)) {
                    lastViewX = closePoint.x;
                }

                lastViewMin = MIN(MIN(openPoint.y, closePoint.y), MIN(highPoint.y, lowPoint.y));
                lastViewMax = MAX(MAX(openPoint.y, closePoint.y), MAX(highPoint.y, lowPoint.y));
            }
        }
    }

    if ( result != NSNotFound ) {
        CGFloat offset = CPTFloat(0.0);

        switch ( self.plotStyle ) {
            case CPTTradingRangePlotStyleOHLC:
                offset = self.stickLength;
                break;

            case CPTTradingRangePlotStyleCandleStick:
                offset = [self barWidthForIndex:result].cgFloatValue * CPTFloat(0.5);
                break;
        }

        if ((point.x < (lastViewX - offset)) || (point.x > (lastViewX + offset))) {
            result = NSNotFound;
        }
        if ((point.y < lastViewMin) || (point.y > lastViewMax)) {
            result = NSNotFound;
        }
    }

    return result;
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
 *  @link CPTTradingRangePlotDelegate::tradingRangePlot:barTouchDownAtRecordIndex: -tradingRangePlot:barTouchDownAtRecordIndex: @endlink or
 *  @link CPTTradingRangePlotDelegate::tradingRangePlot:barTouchDownAtRecordIndex:withEvent: -tradingRangePlot:barTouchDownAtRecordIndex:withEvent: @endlink
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

    id<CPTTradingRangePlotDelegate> theDelegate = (id<CPTTradingRangePlotDelegate>)self.delegate;
    if ( [theDelegate respondsToSelector:@selector(tradingRangePlot:barTouchDownAtRecordIndex:)] ||
         [theDelegate respondsToSelector:@selector(tradingRangePlot:barTouchDownAtRecordIndex:withEvent:)] ||
         [theDelegate respondsToSelector:@selector(tradingRangePlot:barWasSelectedAtRecordIndex:)] ||
         [theDelegate respondsToSelector:@selector(tradingRangePlot:barWasSelectedAtRecordIndex:withEvent:)] ) {
        // Inform delegate if a point was hit
        CGPoint plotAreaPoint = [theGraph convertPoint:interactionPoint toLayer:thePlotArea];
        NSUInteger idx        = [self dataIndexFromInteractionPoint:plotAreaPoint];
        self.pointingDeviceDownIndex = idx;

        if ( idx != NSNotFound ) {
            BOOL handled = NO;

            if ( [theDelegate respondsToSelector:@selector(tradingRangePlot:barTouchDownAtRecordIndex:)] ) {
                handled = YES;
                [theDelegate tradingRangePlot:self barTouchDownAtRecordIndex:idx];
            }

            if ( [theDelegate respondsToSelector:@selector(tradingRangePlot:barTouchDownAtRecordIndex:withEvent:)] ) {
                handled = YES;
                [theDelegate tradingRangePlot:self barTouchDownAtRecordIndex:idx withEvent:event];
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
 *  @link CPTTradingRangePlotDelegate::tradingRangePlot:barTouchUpAtRecordIndex: -tradingRangePlot:barTouchUpAtRecordIndex: @endlink and/or
 *  @link CPTTradingRangePlotDelegate::tradingRangePlot:barTouchUpAtRecordIndex:withEvent: -tradingRangePlot:barTouchUpAtRecordIndex:withEvent: @endlink
 *  methods, the @par{interactionPoint} is compared with each bar in index order.
 *  The delegate method will be called and this method returns @YES for the first
 *  index where the @par{interactionPoint} is inside a bar.
 *  This method returns @NO if the @par{interactionPoint} is outside all of the bars.
 *
 *  If the bar being released is the same as the one that was pressed (see
 *  @link CPTTradingRangePlot::pointingDeviceDownEvent:atPoint: -pointingDeviceDownEvent:atPoint: @endlink), if the delegate responds to the
 *  @link CPTTradingRangePlotDelegate::tradingRangePlot:barWasSelectedAtRecordIndex: -tradingRangePlot:barWasSelectedAtRecordIndex: @endlink and/or
 *  @link CPTTradingRangePlotDelegate::tradingRangePlot:barWasSelectedAtRecordIndex:withEvent: -tradingRangePlot:barWasSelectedAtRecordIndex:withEvent: @endlink
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

    id<CPTTradingRangePlotDelegate> theDelegate = (id<CPTTradingRangePlotDelegate>)self.delegate;
    if ( [theDelegate respondsToSelector:@selector(tradingRangePlot:barTouchUpAtRecordIndex:)] ||
         [theDelegate respondsToSelector:@selector(tradingRangePlot:barTouchUpAtRecordIndex:withEvent:)] ||
         [theDelegate respondsToSelector:@selector(tradingRangePlot:barWasSelectedAtRecordIndex:)] ||
         [theDelegate respondsToSelector:@selector(tradingRangePlot:barWasSelectedAtRecordIndex:withEvent:)] ) {
        // Inform delegate if a point was hit
        CGPoint plotAreaPoint = [theGraph convertPoint:interactionPoint toLayer:thePlotArea];
        NSUInteger idx        = [self dataIndexFromInteractionPoint:plotAreaPoint];

        if ( idx != NSNotFound ) {
            BOOL handled = NO;

            if ( [theDelegate respondsToSelector:@selector(tradingRangePlot:barTouchUpAtRecordIndex:)] ) {
                handled = YES;
                [theDelegate tradingRangePlot:self barTouchUpAtRecordIndex:idx];
            }

            if ( [theDelegate respondsToSelector:@selector(tradingRangePlot:barTouchUpAtRecordIndex:withEvent:)] ) {
                handled = YES;
                [theDelegate tradingRangePlot:self barTouchUpAtRecordIndex:idx withEvent:event];
            }

            if ( idx == selectedDownIndex ) {
                if ( [theDelegate respondsToSelector:@selector(tradingRangePlot:barWasSelectedAtRecordIndex:)] ) {
                    handled = YES;
                    [theDelegate tradingRangePlot:self barWasSelectedAtRecordIndex:idx];
                }

                if ( [theDelegate respondsToSelector:@selector(tradingRangePlot:barWasSelectedAtRecordIndex:withEvent:)] ) {
                    handled = YES;
                    [theDelegate tradingRangePlot:self barWasSelectedAtRecordIndex:idx withEvent:event];
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

-(void)setPlotStyle:(CPTTradingRangePlotStyle)newPlotStyle
{
    if ( plotStyle != newPlotStyle ) {
        plotStyle = newPlotStyle;
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(void)setLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    if ( lineStyle != newLineStyle ) {
        lineStyle = [newLineStyle copy];
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(void)setIncreaseLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    if ( increaseLineStyle != newLineStyle ) {
        increaseLineStyle = [newLineStyle copy];
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(void)setDecreaseLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    if ( decreaseLineStyle != newLineStyle ) {
        decreaseLineStyle = [newLineStyle copy];
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(void)setIncreaseFill:(nullable CPTFill *)newFill
{
    if ( increaseFill != newFill ) {
        increaseFill = [newFill copy];
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(void)setDecreaseFill:(nullable CPTFill *)newFill
{
    if ( decreaseFill != newFill ) {
        decreaseFill = [newFill copy];
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(void)setBarWidth:(CGFloat)newWidth
{
    if ( barWidth != newWidth ) {
        barWidth = newWidth;
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(void)setStickLength:(CGFloat)newLength
{
    if ( stickLength != newLength ) {
        stickLength = newLength;
        [self setNeedsDisplay];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPTLegendNeedsRedrawForPlotNotification object:self];
    }
}

-(void)setBarCornerRadius:(CGFloat)newBarCornerRadius
{
    if ( barCornerRadius != newBarCornerRadius ) {
        barCornerRadius = newBarCornerRadius;
        [self setNeedsDisplay];
    }
}

-(void)setShowBarBorder:(BOOL)newShowBarBorder
{
    if ( showBarBorder != newShowBarBorder ) {
        showBarBorder = newShowBarBorder;
        [self setNeedsDisplay];
    }
}

-(void)setXValues:(nullable CPTMutableNumericData *)newValues
{
    [self cacheNumbers:newValues forField:CPTTradingRangePlotFieldX];
}

-(nullable CPTMutableNumericData *)xValues
{
    return [self cachedNumbersForField:CPTTradingRangePlotFieldX];
}

-(nullable CPTMutableNumericData *)openValues
{
    return [self cachedNumbersForField:CPTTradingRangePlotFieldOpen];
}

-(void)setOpenValues:(nullable CPTMutableNumericData *)newValues
{
    [self cacheNumbers:newValues forField:CPTTradingRangePlotFieldOpen];
}

-(nullable CPTMutableNumericData *)highValues
{
    return [self cachedNumbersForField:CPTTradingRangePlotFieldHigh];
}

-(void)setHighValues:(nullable CPTMutableNumericData *)newValues
{
    [self cacheNumbers:newValues forField:CPTTradingRangePlotFieldHigh];
}

-(nullable CPTMutableNumericData *)lowValues
{
    return [self cachedNumbersForField:CPTTradingRangePlotFieldLow];
}

-(void)setLowValues:(nullable CPTMutableNumericData *)newValues
{
    [self cacheNumbers:newValues forField:CPTTradingRangePlotFieldLow];
}

-(nullable CPTMutableNumericData *)closeValues
{
    return [self cachedNumbersForField:CPTTradingRangePlotFieldClose];
}

-(void)setCloseValues:(nullable CPTMutableNumericData *)newValues
{
    [self cacheNumbers:newValues forField:CPTTradingRangePlotFieldClose];
}

-(nullable CPTFillArray *)increaseFills
{
    return [self cachedArrayForKey:CPTTradingRangePlotBindingIncreaseFills];
}

-(void)setIncreaseFills:(nullable CPTFillArray *)newFills
{
    [self cacheArray:newFills forKey:CPTTradingRangePlotBindingIncreaseFills];
    [self setNeedsDisplay];
}

-(nullable CPTFillArray *)decreaseFills
{
    return [self cachedArrayForKey:CPTTradingRangePlotBindingDecreaseFills];
}

-(void)setDecreaseFills:(nullable CPTFillArray *)newFills
{
    [self cacheArray:newFills forKey:CPTTradingRangePlotBindingDecreaseFills];
    [self setNeedsDisplay];
}

-(nullable CPTLineStyleArray *)lineStyles
{
    return [self cachedArrayForKey:CPTTradingRangePlotBindingLineStyles];
}

-(void)setLineStyles:(nullable CPTLineStyleArray *)newLineStyles
{
    [self cacheArray:newLineStyles forKey:CPTTradingRangePlotBindingLineStyles];
    [self setNeedsDisplay];
}

-(nullable CPTLineStyleArray *)increaseLineStyles
{
    return [self cachedArrayForKey:CPTTradingRangePlotBindingIncreaseLineStyles];
}

-(void)setIncreaseLineStyles:(nullable CPTLineStyleArray *)newLineStyles
{
    [self cacheArray:newLineStyles forKey:CPTTradingRangePlotBindingIncreaseLineStyles];
    [self setNeedsDisplay];
}

-(nullable CPTLineStyleArray *)decreaseLineStyles
{
    return [self cachedArrayForKey:CPTTradingRangePlotBindingDecreaseLineStyles];
}

-(void)setDecreaseLineStyles:(nullable CPTLineStyleArray *)newLineStyles
{
    [self cacheArray:newLineStyles forKey:CPTTradingRangePlotBindingDecreaseLineStyles];
    [self setNeedsDisplay];
}

/// @endcond

@end

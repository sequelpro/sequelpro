#import "CPTDefinitions.h"
#import "CPTLimitBand.h"
#import "CPTPlot.h"
#import "CPTPlotSymbol.h"

/// @file

@class CPTLineStyle;
@class CPTScatterPlot;
@class CPTFill;

/**
 *  @brief Scatter plot bindings.
 **/
typedef NSString *CPTScatterPlotBinding cpt_swift_struct;

/// @ingroup plotBindingsScatterPlot
/// @{
extern CPTScatterPlotBinding __nonnull const CPTScatterPlotBindingXValues;
extern CPTScatterPlotBinding __nonnull const CPTScatterPlotBindingYValues;
extern CPTScatterPlotBinding __nonnull const CPTScatterPlotBindingPlotSymbols;
/// @}

/**
 *  @brief Enumeration of scatter plot data source field types
 **/
typedef NS_ENUM (NSInteger, CPTScatterPlotField) {
    CPTScatterPlotFieldX, ///< X values.
    CPTScatterPlotFieldY  ///< Y values.
};

/**
 *  @brief Enumeration of scatter plot interpolation algorithms
 **/
typedef NS_ENUM (NSInteger, CPTScatterPlotInterpolation) {
    CPTScatterPlotInterpolationLinear,    ///< Linear interpolation.
    CPTScatterPlotInterpolationStepped,   ///< Steps beginning at data point.
    CPTScatterPlotInterpolationHistogram, ///< Steps centered at data point.
    CPTScatterPlotInterpolationCurved     ///< Curved interpolation.
};

/**
 *  @brief Enumration of scatter plot curved interpolation style options
 **/
typedef NS_ENUM (NSInteger, CPTScatterPlotCurvedInterpolationOption) {
    CPTScatterPlotCurvedInterpolationNormal,                ///< Standard Curved Interpolation (Bezier Curve)
    CPTScatterPlotCurvedInterpolationCatmullRomUniform,     ///< Catmull-Rom Spline Interpolation with alpha = @num{0.0}.
    CPTScatterPlotCurvedInterpolationCatmullRomCentripetal, ///< Catmull-Rom Spline Interpolation with alpha = @num{0.5}.
    CPTScatterPlotCurvedInterpolationCatmullRomChordal,     ///< Catmull-Rom Spline Interpolation with alpha = @num{1.0}.
    CPTScatterPlotCurvedInterpolationCatmullCustomAlpha,    ///< Catmull-Rom Spline Interpolation with a custom alpha value.
    CPTScatterPlotCurvedInterpolationHermiteCubic           ///< Hermite Cubic Spline Interpolation
};

/**
 *  @brief Enumeration of scatter plot histogram style options
 **/
typedef NS_ENUM (NSInteger, CPTScatterPlotHistogramOption) {
    CPTScatterPlotHistogramNormal,     ///< Standard histogram.
    CPTScatterPlotHistogramSkipFirst,  ///< Skip the first step of the histogram.
    CPTScatterPlotHistogramSkipSecond, ///< Skip the second step of the histogram.
    CPTScatterPlotHistogramOptionCount ///< The number of histogram options available.
};

#pragma mark -

/**
 *  @brief A scatter plot data source.
 **/
@protocol CPTScatterPlotDataSource<CPTPlotDataSource>

@optional

/// @name Plot Symbols
/// @{

/** @brief @optional Gets a range of plot symbols for the given scatter plot.
 *  @param plot The scatter plot.
 *  @param indexRange The range of the data indexes of interest.
 *  @return An array of plot symbols.
 **/
-(nullable CPTPlotSymbolArray *)symbolsForScatterPlot:(nonnull CPTScatterPlot *)plot recordIndexRange:(NSRange)indexRange;

/** @brief @optional Gets a single plot symbol for the given scatter plot.
 *  This method will not be called if
 *  @link CPTScatterPlotDataSource::symbolsForScatterPlot:recordIndexRange: -symbolsForScatterPlot:recordIndexRange: @endlink
 *  is also implemented in the datasource.
 *  @param plot The scatter plot.
 *  @param idx The data index of interest.
 *  @return The plot symbol to show for the point with the given index.
 **/
-(nullable CPTPlotSymbol *)symbolForScatterPlot:(nonnull CPTScatterPlot *)plot recordIndex:(NSUInteger)idx;

/// @}

@end

#pragma mark -

/**
 *  @brief Scatter plot delegate.
 **/
@protocol CPTScatterPlotDelegate<CPTPlotDelegate>

@optional

/// @name Data Point Selection
/// @{

/** @brief @optional Informs the delegate that a data point
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param plot The scatter plot.
 *  @param idx The index of the
 *  @if MacOnly clicked data point. @endif
 *  @if iOSOnly touched data point. @endif
 **/
-(void)scatterPlot:(nonnull CPTScatterPlot *)plot plotSymbolWasSelectedAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a data point
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param plot The scatter plot.
 *  @param idx The index of the
 *  @if MacOnly clicked data point. @endif
 *  @if iOSOnly touched data point. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)scatterPlot:(nonnull CPTScatterPlot *)plot plotSymbolWasSelectedAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a data point
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param plot The scatter plot.
 *  @param idx The index of the
 *  @if MacOnly clicked data point. @endif
 *  @if iOSOnly touched data point. @endif
 **/
-(void)scatterPlot:(nonnull CPTScatterPlot *)plot plotSymbolTouchDownAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a data point
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param plot The scatter plot.
 *  @param idx The index of the
 *  @if MacOnly clicked data point. @endif
 *  @if iOSOnly touched data point. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)scatterPlot:(nonnull CPTScatterPlot *)plot plotSymbolTouchDownAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a data point
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param plot The scatter plot.
 *  @param idx The index of the
 *  @if MacOnly clicked data point. @endif
 *  @if iOSOnly touched data point. @endif
 **/
-(void)scatterPlot:(nonnull CPTScatterPlot *)plot plotSymbolTouchUpAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a data point
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param plot The scatter plot.
 *  @param idx The index of the
 *  @if MacOnly clicked data point. @endif
 *  @if iOSOnly touched data point. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)scatterPlot:(nonnull CPTScatterPlot *)plot plotSymbolTouchUpAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/// @}

/// @name Data Line Selection
/// @{

/** @brief @optional Informs the delegate that
 *  @if MacOnly the mouse was both pressed and released on the plot line.@endif
 *  @if iOSOnly the plot line received both the touch down and up events. @endif
 *  @param plot The scatter plot.
 **/
-(void)scatterPlotDataLineWasSelected:(nonnull CPTScatterPlot *)plot;

/** @brief @optional Informs the delegate that
 *  @if MacOnly the mouse was both pressed and released on the plot line.@endif
 *  @if iOSOnly the plot line received both the touch down and up events. @endif
 *  @param plot The scatter plot.
 *  @param event The event that triggered the selection.
 **/
-(void)scatterPlot:(nonnull CPTScatterPlot *)plot dataLineWasSelectedWithEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that
 *  @if MacOnly the mouse was pressed @endif
 *  @if iOSOnly touch started @endif
 *  while over the plot line.
 *  @param plot The scatter plot.
 **/
-(void)scatterPlotDataLineTouchDown:(nonnull CPTScatterPlot *)plot;

/** @brief @optional Informs the delegate that
 *  @if MacOnly the mouse was pressed @endif
 *  @if iOSOnly touch started @endif
 *  while over the plot line.
 *  @param plot The scatter plot.
 *  @param event The event that triggered the selection.
 **/
-(void)scatterPlot:(nonnull CPTScatterPlot *)plot dataLineTouchDownWithEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that
 *  @if MacOnly the mouse was released @endif
 *  @if iOSOnly touch ended @endif
 *  while over the plot line.
 *  @param plot The scatter plot.
 **/
-(void)scatterPlotDataLineTouchUp:(nonnull CPTScatterPlot *)plot;

/** @brief @optional Informs the delegate that
 *  @if MacOnly the mouse was released @endif
 *  @if iOSOnly touch ended @endif
 *  while over the plot line.
 *  @param plot The scatter plot.
 *  @param event The event that triggered the selection.
 **/
-(void)scatterPlot:(nonnull CPTScatterPlot *)plot dataLineTouchUpWithEvent:(nonnull CPTNativeEvent *)event;

/// @}

/// @name Drawing
/// @{

/** @brief @optional Gives the delegate an opportunity to do something just before the
 *  plot line will be drawn. A common operation is to draw a selection indicator for the
 *  plot line. This is called after the plot fill has been drawn.
 *  @param plot The scatter plot.
 *  @param dataLinePath The CGPath describing the plot line that is about to be drawn.
 *  @param context The graphics context in which the plot line will be drawn.
 **/
-(void)scatterPlot:(nonnull CPTScatterPlot *)plot prepareForDrawingPlotLine:(nonnull CGPathRef)dataLinePath inContext:(nonnull CGContextRef)context;

/// @}

@end

#pragma mark -

@interface CPTScatterPlot : CPTPlot

/// @name Appearance
/// @{
@property (nonatomic, readwrite, strong, nullable) NSNumber *areaBaseValue;
@property (nonatomic, readwrite, strong, nullable) NSNumber *areaBaseValue2;
@property (nonatomic, readwrite, assign) CPTScatterPlotInterpolation interpolation;
@property (nonatomic, readwrite, assign) CPTScatterPlotHistogramOption histogramOption;
@property (nonatomic, readwrite, assign) CPTScatterPlotCurvedInterpolationOption curvedInterpolationOption;
@property (nonatomic, readwrite, assign) CGFloat curvedInterpolationCustomAlpha;
/// @}

/// @name Area Fill Bands
/// @{
@property (nonatomic, readonly, nullable) CPTLimitBandArray *areaFillBands;
/// @}

/// @name Drawing
/// @{
@property (nonatomic, readwrite, copy, nullable) CPTLineStyle *dataLineStyle;
@property (nonatomic, readwrite, copy, nullable) CPTPlotSymbol *plotSymbol;
@property (nonatomic, readwrite, copy, nullable) CPTFill *areaFill;
@property (nonatomic, readwrite, copy, nullable) CPTFill *areaFill2;
/// @}

/// @name Data Line
/// @{
@property (nonatomic, readonly, nonnull) CGPathRef newDataLinePath;
/// @}

/// @name User Interaction
/// @{
@property (nonatomic, readwrite, assign) CGFloat plotSymbolMarginForHitDetection;
@property (nonatomic, readwrite, assign) CGFloat plotLineMarginForHitDetection;
@property (nonatomic, readwrite, assign) BOOL allowSimultaneousSymbolAndPlotSelection;
/// @}

/// @name Visible Points
/// @{
-(NSUInteger)indexOfVisiblePointClosestToPlotAreaPoint:(CGPoint)viewPoint;
-(CGPoint)plotAreaPointOfVisiblePointAtIndex:(NSUInteger)idx;
/// @}

/// @name Plot Symbols
/// @{
-(nullable CPTPlotSymbol *)plotSymbolForRecordIndex:(NSUInteger)idx;
-(void)reloadPlotSymbols;
-(void)reloadPlotSymbolsInIndexRange:(NSRange)indexRange;
/// @}

/// @name Area Fill Bands
/// @{
-(void)addAreaFillBand:(nullable CPTLimitBand *)limitBand;
-(void)removeAreaFillBand:(nullable CPTLimitBand *)limitBand;
/// @}

@end

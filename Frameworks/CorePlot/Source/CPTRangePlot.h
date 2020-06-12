#import "CPTDefinitions.h"
#import "CPTLineStyle.h"
#import "CPTPlot.h"

@class CPTFill;
@class CPTRangePlot;

/**
 *  @brief Range plot bindings.
 **/
typedef NSString *CPTRangePlotBinding cpt_swift_struct;

/// @ingroup plotBindingsRangePlot
/// @{
extern CPTRangePlotBinding __nonnull const CPTRangePlotBindingXValues;
extern CPTRangePlotBinding __nonnull const CPTRangePlotBindingYValues;
extern CPTRangePlotBinding __nonnull const CPTRangePlotBindingHighValues;
extern CPTRangePlotBinding __nonnull const CPTRangePlotBindingLowValues;
extern CPTRangePlotBinding __nonnull const CPTRangePlotBindingLeftValues;
extern CPTRangePlotBinding __nonnull const CPTRangePlotBindingRightValues;
extern CPTRangePlotBinding __nonnull const CPTRangePlotBindingBarLineStyles;
extern CPTRangePlotBinding __nonnull const CPTRangePlotBindingBarWidths;
/// @}

/**
 *  @brief Enumeration of range plot data source field types
 **/
typedef NS_ENUM (NSInteger, CPTRangePlotField) {
    CPTRangePlotFieldX,    ///< X values.
    CPTRangePlotFieldY,    ///< Y values.
    CPTRangePlotFieldHigh, ///< relative High values.
    CPTRangePlotFieldLow,  ///< relative Low values.
    CPTRangePlotFieldLeft, ///< relative Left values.
    CPTRangePlotFieldRight ///< relative Right values.
};

/**
 *  @brief Enumeration of range plot data fill directions
 **/
typedef NS_ENUM (NSInteger, CPTRangePlotFillDirection) {
    CPTRangePlotFillHorizontal, ///< Fill between the high and low values in a horizontal direction.
    CPTRangePlotFillVertical    ///< Fill between the left and right values in a vertical direction.
};

#pragma mark -

/**
 *  @brief A range plot data source.
 **/
@protocol CPTRangePlotDataSource<CPTPlotDataSource>
@optional

/// @name Bar Style
/// @{

/** @brief @optional Gets a range of bar line styles for the given range plot.
 *  @param plot The range plot.
 *  @param indexRange The range of the data indexes of interest.
 *  @return An array of line styles.
 **/
-(nullable CPTLineStyleArray *)barLineStylesForRangePlot:(nonnull CPTRangePlot *)plot recordIndexRange:(NSRange)indexRange;

/** @brief @optional Gets a bar line style for the given range plot.
 *  This method will not be called if
 *  @link CPTRangePlotDataSource::barLineStylesForRangePlot:recordIndexRange: -barLineStylesForRangePlot:recordIndexRange: @endlink
 *  is also implemented in the datasource.
 *  @param plot The range plot.
 *  @param idx The data index of interest.
 *  @return The bar line style for the bar with the given index. If the data source returns @nil, the default line style is used.
 *  If the data source returns an NSNull object, no line is drawn.
 **/
-(nullable CPTLineStyle *)barLineStyleForRangePlot:(nonnull CPTRangePlot *)plot recordIndex:(NSUInteger)idx;

/** @brief @optional Gets an array of bar widths for the given range plot.
 *  @param plot The range plot.
 *  @param indexRange The range of the data indexes of interest.
 *  @return An array of bar widths.
 **/
-(nullable CPTNumberArray *)barWidthsForRangePlot:(nonnull CPTRangePlot *)barPlot recordIndexRange:(NSRange)indexRange;

/** @brief @optional Gets a bar width for the given range plot.
 *  This method will not be called if
 *  @link CPTRangePlotDataSource::barWidthForRangePlot:recordIndexRange: -barWidthForRangePlot:recordIndexRange: @endlink
 *  is also implemented in the datasource.
 *  @param plot The range plot.
 *  @param idx The data index of interest.
 *  @return The bar width for the bar with the given index. If the data source returns @nil, the default barWidth is used.
 **/
-(nullable NSNumber *)barWidthForRangePlot:(nonnull CPTRangePlot *)plot recordIndex:(NSUInteger)idx;

/// @}

@end

#pragma mark -

/**
 *  @brief Range plot delegate.
 **/
@protocol CPTRangePlotDelegate<CPTPlotDelegate>

@optional

/// @name Point Selection
/// @{

/** @brief @optional Informs the delegate that a bar
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param plot The range plot.
 *  @param idx The index of the
 *  @if MacOnly clicked bar. @endif
 *  @if iOSOnly touched bar. @endif
 **/
-(void)rangePlot:(nonnull CPTRangePlot *)plot rangeWasSelectedAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a bar
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param plot The range plot.
 *  @param idx The index of the
 *  @if MacOnly clicked bar. @endif
 *  @if iOSOnly touched bar. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)rangePlot:(nonnull CPTRangePlot *)plot rangeWasSelectedAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a bar
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param plot The range plot.
 *  @param idx The index of the
 *  @if MacOnly clicked bar. @endif
 *  @if iOSOnly touched bar. @endif
 **/
-(void)rangePlot:(nonnull CPTRangePlot *)plot rangeTouchDownAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a bar
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param plot The range plot.
 *  @param idx The index of the
 *  @if MacOnly clicked bar. @endif
 *  @if iOSOnly touched bar. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)rangePlot:(nonnull CPTRangePlot *)plot rangeTouchDownAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a bar
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param plot The range plot.
 *  @param idx The index of the
 *  @if MacOnly clicked bar. @endif
 *  @if iOSOnly touched bar. @endif
 **/
-(void)rangePlot:(nonnull CPTRangePlot *)plot rangeTouchUpAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a bar
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param plot The range plot.
 *  @param idx The index of the
 *  @if MacOnly clicked bar. @endif
 *  @if iOSOnly touched bar. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)rangePlot:(nonnull CPTRangePlot *)plot rangeTouchUpAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/// @}

@end

#pragma mark -

@interface CPTRangePlot : CPTPlot

/// @name Appearance
/// @{
@property (nonatomic, readwrite, copy, nullable) CPTLineStyle *barLineStyle;
@property (nonatomic, readwrite) CGFloat barWidth;
@property (nonatomic, readwrite) CGFloat gapHeight;
@property (nonatomic, readwrite) CGFloat gapWidth;
/// @}

/// @name Drawing
/// @{
@property (nonatomic, readwrite) CPTRangePlotFillDirection fillDirection;
@property (nonatomic, copy, nullable) CPTFill *areaFill;
@property (nonatomic, readwrite, copy, nullable) CPTLineStyle *areaBorderLineStyle;
/// @}

/// @name Bar Style
/// @{
-(void)reloadBarLineStyles;
-(void)reloadBarLineStylesInIndexRange:(NSRange)indexRange;
-(void)reloadBarWidths;
-(void)reloadBarWidthsInIndexRange:(NSRange)indexRange;
/// @}

@end

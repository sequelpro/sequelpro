#import "CPTDefinitions.h"
#import "CPTFill.h"
#import "CPTLineStyle.h"
#import "CPTPlot.h"

/// @file

@class CPTMutableNumericData;
@class CPTNumericData;
@class CPTPlotRange;
@class CPTColor;
@class CPTBarPlot;
@class CPTTextLayer;
@class CPTTextStyle;

/**
 *  @brief Bar plot bindings.
 **/
typedef NSString *CPTBarPlotBinding cpt_swift_struct;

/// @ingroup plotBindingsBarPlot
/// @{
extern CPTBarPlotBinding __nonnull const CPTBarPlotBindingBarLocations;
extern CPTBarPlotBinding __nonnull const CPTBarPlotBindingBarTips;
extern CPTBarPlotBinding __nonnull const CPTBarPlotBindingBarBases;
extern CPTBarPlotBinding __nonnull const CPTBarPlotBindingBarFills;
extern CPTBarPlotBinding __nonnull const CPTBarPlotBindingBarLineStyles;
extern CPTBarPlotBinding __nonnull const CPTBarPlotBindingBarWidths;
/// @}

/**
 *  @brief Enumeration of bar plot data source field types
 **/
typedef NS_ENUM (NSInteger, CPTBarPlotField) {
    CPTBarPlotFieldBarLocation, ///< Bar location on independent coordinate axis.
    CPTBarPlotFieldBarTip,      ///< Bar tip value.
    CPTBarPlotFieldBarBase      ///< Bar base (used only if @link CPTBarPlot::barBasesVary barBasesVary @endlink is YES).
};

#pragma mark -

/**
 *  @brief A bar plot data source.
 **/
@protocol CPTBarPlotDataSource<CPTPlotDataSource>
@optional

/// @name Bar Style
/// @{

/** @brief @optional Gets an array of bar fills for the given bar plot.
 *  @param barPlot The bar plot.
 *  @param indexRange The range of the data indexes of interest.
 *  @return An array of bar fills.
 **/
-(nullable CPTFillArray *)barFillsForBarPlot:(nonnull CPTBarPlot *)barPlot recordIndexRange:(NSRange)indexRange;

/** @brief @optional Gets a bar fill for the given bar plot.
 *  This method will not be called if
 *  @link CPTBarPlotDataSource::barFillsForBarPlot:recordIndexRange: -barFillsForBarPlot:recordIndexRange: @endlink
 *  is also implemented in the datasource.
 *  @param barPlot The bar plot.
 *  @param idx The data index of interest.
 *  @return The bar fill for the bar with the given index. If the data source returns @nil, the default fill is used.
 *  If the data source returns an NSNull object, no fill is drawn.
 **/
-(nullable CPTFill *)barFillForBarPlot:(nonnull CPTBarPlot *)barPlot recordIndex:(NSUInteger)idx;

/** @brief @optional Gets an array of bar line styles for the given bar plot.
 *  @param barPlot The bar plot.
 *  @param indexRange The range of the data indexes of interest.
 *  @return An array of line styles.
 **/
-(nullable CPTLineStyleArray *)barLineStylesForBarPlot:(nonnull CPTBarPlot *)barPlot recordIndexRange:(NSRange)indexRange;

/** @brief @optional Gets a bar line style for the given bar plot.
 *  This method will not be called if
 *  @link CPTBarPlotDataSource::barLineStylesForBarPlot:recordIndexRange: -barLineStylesForBarPlot:recordIndexRange: @endlink
 *  is also implemented in the datasource.
 *  @param barPlot The bar plot.
 *  @param idx The data index of interest.
 *  @return The bar line style for the bar with the given index. If the data source returns @nil, the default line style is used.
 *  If the data source returns an NSNull object, no line is drawn.
 **/
-(nullable CPTLineStyle *)barLineStyleForBarPlot:(nonnull CPTBarPlot *)barPlot recordIndex:(NSUInteger)idx;

/** @brief @optional Gets an array of bar widths for the given bar plot.
 *  @param barPlot The bar plot.
 *  @param indexRange The range of the data indexes of interest.
 *  @return An array of bar widths.
 **/
-(nullable CPTNumberArray *)barWidthsForBarPlot:(nonnull CPTBarPlot *)barPlot recordIndexRange:(NSRange)indexRange;

/** @brief @optional Gets a bar width for the given bar plot.
 *  This method will not be called if
 *  @link CPTBarPlotDataSource::barWidthsForBarPlot:recordIndexRange: -barWidthsForBarPlot:recordIndexRange: @endlink
 *  is also implemented in the datasource.
 *  @param barPlot The bar plot.
 *  @param idx The data index of interest.
 *  @return The bar width for the bar with the given index. If the data source returns @nil, the default barWidth is used.
 **/
-(nullable NSNumber *)barWidthForBarPlot:(nonnull CPTBarPlot *)barPlot recordIndex:(NSUInteger)idx;

/// @}

/// @name Legends
/// @{

/** @brief @optional Gets the legend title for the given bar plot bar.
 *  @param barPlot The bar plot.
 *  @param idx The data index of interest.
 *  @return The title text for the legend entry for the point with the given index.
 **/
-(nullable NSString *)legendTitleForBarPlot:(nonnull CPTBarPlot *)barPlot recordIndex:(NSUInteger)idx;

/** @brief @optional Gets the styled legend title for the given bar plot bar.
 *  @param barPlot The bar plot.
 *  @param idx The data index of interest.
 *  @return The styled title text for the legend entry for the point with the given index.
 **/
-(nullable NSAttributedString *)attributedLegendTitleForBarPlot:(nonnull CPTBarPlot *)barPlot recordIndex:(NSUInteger)idx;

/// @}
@end

#pragma mark -

/**
 *  @brief Bar plot delegate.
 **/
@protocol CPTBarPlotDelegate<CPTPlotDelegate>

@optional

/// @name Point Selection
/// @{

/** @brief @optional Informs the delegate that a bar
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param plot The bar plot.
 *  @param idx The index of the
 *
 *  @if MacOnly clicked bar. @endif
 *  @if iOSOnly touched bar. @endif
 **/
-(void)barPlot:(nonnull CPTBarPlot *)plot barWasSelectedAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a bar
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param plot The bar plot.
 *  @param idx The index of the
 *
 *  @if MacOnly clicked bar. @endif
 *  @if iOSOnly touched bar. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)barPlot:(nonnull CPTBarPlot *)plot barWasSelectedAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a bar
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param plot The bar plot.
 *  @param idx The index of the
 *  @if MacOnly clicked bar. @endif
 *  @if iOSOnly touched bar. @endif
 **/
-(void)barPlot:(nonnull CPTBarPlot *)plot barTouchDownAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a bar
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param plot The bar plot.
 *  @param idx The index of the
 *  @if MacOnly clicked bar. @endif
 *  @if iOSOnly touched bar. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)barPlot:(nonnull CPTBarPlot *)plot barTouchDownAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a bar
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param plot The bar plot.
 *  @param idx The index of the
 *  @if MacOnly clicked bar. @endif
 *  @if iOSOnly touched bar. @endif
 **/
-(void)barPlot:(nonnull CPTBarPlot *)plot barTouchUpAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a bar
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param plot The bar plot.
 *  @param idx The index of the
 *  @if MacOnly clicked bar. @endif
 *  @if iOSOnly touched bar. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)barPlot:(nonnull CPTBarPlot *)plot barTouchUpAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/// @}

@end

#pragma mark -

@interface CPTBarPlot : CPTPlot

/// @name Appearance
/// @{
@property (nonatomic, readwrite, assign) BOOL barWidthsAreInViewCoordinates;
@property (nonatomic, readwrite, strong, nonnull) NSNumber *barWidth;
@property (nonatomic, readwrite, strong, nonnull) NSNumber *barOffset;
@property (nonatomic, readwrite, assign) CGFloat barCornerRadius;
@property (nonatomic, readwrite, assign) CGFloat barBaseCornerRadius;
@property (nonatomic, readwrite, assign) BOOL barsAreHorizontal;
@property (nonatomic, readwrite, strong, nonnull) NSNumber *baseValue;
@property (nonatomic, readwrite, assign) BOOL barBasesVary;
@property (nonatomic, readwrite, copy, nullable) CPTPlotRange *plotRange;
/// @}

/// @name Drawing
/// @{
@property (nonatomic, readwrite, copy, nullable) CPTLineStyle *lineStyle;
@property (nonatomic, readwrite, copy, nullable) CPTFill *fill;
/// @}

/// @name Factory Methods
/// @{
+(nonnull instancetype)tubularBarPlotWithColor:(nonnull CPTColor *)color horizontalBars:(BOOL)horizontal;
/// @}

/// @name Data Ranges
/// @{
-(nullable CPTPlotRange *)plotRangeEnclosingBars;
/// @}

/// @name Bar Style
/// @{
-(void)reloadBarFills;
-(void)reloadBarFillsInIndexRange:(NSRange)indexRange;
-(void)reloadBarLineStyles;
-(void)reloadBarLineStylesInIndexRange:(NSRange)indexRange;
-(void)reloadBarWidths;
-(void)reloadBarWidthsInIndexRange:(NSRange)indexRange;
/// @}

@end

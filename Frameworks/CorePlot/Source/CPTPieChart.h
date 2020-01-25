#import "CPTDefinitions.h"
#import "CPTFill.h"
#import "CPTPlot.h"

/// @file

@class CPTColor;
@class CPTPieChart;
@class CPTTextLayer;
@class CPTLineStyle;

/**
 *  @brief Pie chart bindings.
 **/
typedef NSString *CPTPieChartBinding cpt_swift_struct;

/// @ingroup plotBindingsPieChart
/// @{
extern CPTPieChartBinding __nonnull const CPTPieChartBindingPieSliceWidthValues;
extern CPTPieChartBinding __nonnull const CPTPieChartBindingPieSliceFills;
extern CPTPieChartBinding __nonnull const CPTPieChartBindingPieSliceRadialOffsets;
/// @}

/**
 *  @brief Enumeration of pie chart data source field types.
 **/
typedef NS_ENUM (NSInteger, CPTPieChartField) {
    CPTPieChartFieldSliceWidth,           ///< Pie slice width.
    CPTPieChartFieldSliceWidthNormalized, ///< Pie slice width normalized [0, 1].
    CPTPieChartFieldSliceWidthSum         ///< Cumulative sum of pie slice widths.
};

/**
 *  @brief Enumeration of pie slice drawing directions.
 **/
typedef NS_CLOSED_ENUM(NSInteger, CPTPieDirection) {
    CPTPieDirectionClockwise,       ///< Pie slices are drawn in a clockwise direction.
    CPTPieDirectionCounterClockwise ///< Pie slices are drawn in a counter-clockwise direction.
};

#pragma mark -

/**
 *  @brief A pie chart data source.
 **/
@protocol CPTPieChartDataSource<CPTPlotDataSource>
@optional

/// @name Slice Style
/// @{

/** @brief @optional Gets a range of slice fills for the given pie chart.
 *  @param pieChart The pie chart.
 *  @param indexRange The range of the data indexes of interest.
 *  @return An array of pie slice fills.
 **/
-(nullable CPTFillArray *)sliceFillsForPieChart:(nonnull CPTPieChart *)pieChart recordIndexRange:(NSRange)indexRange;

/** @brief @optional Gets a fill for the given pie chart slice.
 *  This method will not be called if
 *  @link CPTPieChartDataSource::sliceFillsForPieChart:recordIndexRange: -sliceFillsForPieChart:recordIndexRange: @endlink
 *  is also implemented in the datasource.
 *  @param pieChart The pie chart.
 *  @param idx The data index of interest.
 *  @return The pie slice fill for the slice with the given index. If the datasource returns @nil, the default fill is used.
 *  If the data source returns an NSNull object, no fill is drawn.
 **/
-(nullable CPTFill *)sliceFillForPieChart:(nonnull CPTPieChart *)pieChart recordIndex:(NSUInteger)idx;

/// @}

/// @name Slice Layout
/// @{

/** @brief @optional Gets a range of slice offsets for the given pie chart.
 *  @param pieChart The pie chart.
 *  @param indexRange The range of the data indexes of interest.
 *  @return An array of radial offsets.
 **/
-(nullable CPTNumberArray *)radialOffsetsForPieChart:(nonnull CPTPieChart *)pieChart recordIndexRange:(NSRange)indexRange;

/** @brief @optional Offsets the slice radially from the center point. Can be used to @quote{explode} the chart.
 *  This method will not be called if
 *  @link CPTPieChartDataSource::radialOffsetsForPieChart:recordIndexRange: -radialOffsetsForPieChart:recordIndexRange: @endlink
 *  is also implemented in the datasource.
 *  @param pieChart The pie chart.
 *  @param idx The data index of interest.
 *  @return The radial offset in view coordinates. Zero is no offset.
 **/
-(CGFloat)radialOffsetForPieChart:(nonnull CPTPieChart *)pieChart recordIndex:(NSUInteger)idx;

/// @}

/// @name Legends
/// @{

/** @brief @optional Gets the legend title for the given pie chart slice.
 *  @param pieChart The pie chart.
 *  @param idx The data index of interest.
 *  @return The title text for the legend entry for the point with the given index.
 **/
-(nullable NSString *)legendTitleForPieChart:(nonnull CPTPieChart *)pieChart recordIndex:(NSUInteger)idx;

/** @brief @optional Gets the styled legend title for the given pie chart slice.
 *  @param pieChart The pie chart.
 *  @param idx The data index of interest.
 *  @return The styled title text for the legend entry for the point with the given index.
 **/
-(nullable NSAttributedString *)attributedLegendTitleForPieChart:(nonnull CPTPieChart *)pieChart recordIndex:(NSUInteger)idx;

/// @}
@end

#pragma mark -

/**
 *  @brief Pie chart delegate.
 **/
@protocol CPTPieChartDelegate<CPTPlotDelegate>

@optional

/// @name Slice Selection
/// @{

/** @brief @optional Informs the delegate that a pie slice
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param plot The pie chart.
 *  @param idx The index of the
 *  @if MacOnly clicked pie slice. @endif
 *  @if iOSOnly touched pie slice. @endif
 **/
-(void)pieChart:(nonnull CPTPieChart *)plot sliceWasSelectedAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a pie slice
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param plot The pie chart.
 *  @param idx The index of the
 *  @if MacOnly clicked pie slice. @endif
 *  @if iOSOnly touched pie slice. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)pieChart:(nonnull CPTPieChart *)plot sliceWasSelectedAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a pie slice
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param plot The pie chart.
 *  @param idx The index of the
 *  @if MacOnly clicked pie slice. @endif
 *  @if iOSOnly touched pie slice. @endif
 **/
-(void)pieChart:(nonnull CPTPieChart *)plot sliceTouchDownAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a pie slice
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param plot The pie chart.
 *  @param idx The index of the
 *  @if MacOnly clicked pie slice. @endif
 *  @if iOSOnly touched pie slice. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)pieChart:(nonnull CPTPieChart *)plot sliceTouchDownAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a pie slice
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param plot The pie chart.
 *  @param idx The index of the
 *  @if MacOnly clicked pie slice. @endif
 *  @if iOSOnly touched pie slice. @endif
 **/
-(void)pieChart:(nonnull CPTPieChart *)plot sliceTouchUpAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a pie slice
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param plot The pie chart.
 *  @param idx The index of the
 *  @if MacOnly clicked pie slice. @endif
 *  @if iOSOnly touched pie slice. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)pieChart:(nonnull CPTPieChart *)plot sliceTouchUpAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/// @}

@end

#pragma mark -

@interface CPTPieChart : CPTPlot

/// @name Appearance
/// @{
@property (nonatomic, readwrite) CGFloat pieRadius;
@property (nonatomic, readwrite) CGFloat pieInnerRadius;
@property (nonatomic, readwrite) CGFloat startAngle;
@property (nonatomic, readwrite) CGFloat endAngle;
@property (nonatomic, readwrite) CPTPieDirection sliceDirection;
@property (nonatomic, readwrite) CGPoint centerAnchor;
/// @}

/// @name Drawing
/// @{
@property (nonatomic, readwrite, copy, nullable) CPTLineStyle *borderLineStyle;
@property (nonatomic, readwrite, copy, nullable) CPTFill *overlayFill;
/// @}

/// @name Data Labels
/// @{
@property (nonatomic, readwrite, assign) BOOL labelRotationRelativeToRadius;
/// @}

/// @name Slice Style
/// @{
-(void)reloadSliceFills;
-(void)reloadSliceFillsInIndexRange:(NSRange)indexRange;
/// @}

/// @name Slice Layout
/// @{
-(void)reloadRadialOffsets;
-(void)reloadRadialOffsetsInIndexRange:(NSRange)indexRange;
/// @}

/// @name Information
/// @{
-(NSUInteger)pieSliceIndexAtAngle:(CGFloat)angle;
-(CGFloat)medianAngleForPieSliceIndex:(NSUInteger)idx;
/// @}

/// @name Factory Methods
/// @{
+(nonnull CPTColor *)defaultPieSliceColorForIndex:(NSUInteger)pieSliceIndex;
/// @}

@end

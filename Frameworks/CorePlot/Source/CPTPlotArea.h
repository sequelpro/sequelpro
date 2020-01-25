#import "CPTAnnotationHostLayer.h"
#import "CPTGraph.h"
#import "CPTLayer.h"

@class CPTAxis;
@class CPTAxisLabelGroup;
@class CPTAxisSet;
@class CPTGridLineGroup;
@class CPTPlotArea;
@class CPTPlotGroup;
@class CPTLineStyle;
@class CPTFill;

/**
 *  @brief Plot area delegate.
 **/
@protocol CPTPlotAreaDelegate<CPTLayerDelegate>

@optional

/// @name Plot Area Selection
/// @{

/** @brief @optional Informs the delegate that a plot area
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param plotArea The plot area.
 **/
-(void)plotAreaWasSelected:(nonnull CPTPlotArea *)plotArea;

/** @brief @optional Informs the delegate that a plot area
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param plotArea The plot area.
 *  @param event The event that triggered the selection.
 **/
-(void)plotAreaWasSelected:(nonnull CPTPlotArea *)plotArea withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a plot area
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param plotArea The plot area.
 **/
-(void)plotAreaTouchDown:(nonnull CPTPlotArea *)plotArea;

/** @brief @optional Informs the delegate that a plot area
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param plotArea The plot area.
 *  @param event The event that triggered the selection.
 **/
-(void)plotAreaTouchDown:(nonnull CPTPlotArea *)plotArea withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a plot area
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param plotArea The plot area.
 **/
-(void)plotAreaTouchUp:(nonnull CPTPlotArea *)plotArea;

/** @brief @optional Informs the delegate that a plot area
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param plotArea The plot area.
 *  @param event The event that triggered the selection.
 **/
-(void)plotAreaTouchUp:(nonnull CPTPlotArea *)plotArea withEvent:(nonnull CPTNativeEvent *)event;

/// @}

@end

#pragma mark -

@interface CPTPlotArea : CPTAnnotationHostLayer
/// @name Layers
/// @{
@property (nonatomic, readwrite, strong, nullable) CPTGridLineGroup *minorGridLineGroup;
@property (nonatomic, readwrite, strong, nullable) CPTGridLineGroup *majorGridLineGroup;
@property (nonatomic, readwrite, strong, nullable) CPTAxisSet *axisSet;
@property (nonatomic, readwrite, strong, nullable) CPTPlotGroup *plotGroup;
@property (nonatomic, readwrite, strong, nullable) CPTAxisLabelGroup *axisLabelGroup;
@property (nonatomic, readwrite, strong, nullable) CPTAxisLabelGroup *axisTitleGroup;
/// @}

/// @name Layer Ordering
/// @{
@property (nonatomic, readwrite, strong, nullable) CPTNumberArray *topDownLayerOrder;
/// @}

/// @name Decorations
/// @{
@property (nonatomic, readwrite, copy, nullable) CPTLineStyle *borderLineStyle;
@property (nonatomic, readwrite, copy, nullable) CPTFill *fill;
/// @}

/// @name Dimensions
/// @{
@property (nonatomic, readonly) NSDecimal widthDecimal;
@property (nonatomic, readonly) NSDecimal heightDecimal;
/// @}

/// @name Axis Set Layer Management
/// @{
-(void)updateAxisSetLayersForType:(CPTGraphLayerType)layerType;
-(void)setAxisSetLayersForType:(CPTGraphLayerType)layerType;
-(unsigned)sublayerIndexForAxis:(nonnull CPTAxis *)axis layerType:(CPTGraphLayerType)layerType;
/// @}

@end

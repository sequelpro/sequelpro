#import "CPTAxisLabel.h"
#import "CPTDefinitions.h"
#import "CPTFill.h"
#import "CPTLayer.h"
#import "CPTLimitBand.h"
#import "CPTPlotRange.h"
#import "CPTTextStyle.h"

/// @file

@class CPTAxis;
@class CPTAxisSet;
@class CPTAxisTitle;
@class CPTGridLines;
@class CPTLineCap;
@class CPTLineStyle;
@class CPTPlotSpace;
@class CPTPlotArea;
@class CPTShadow;

/**
 *  @brief Enumeration of labeling policies
 **/
typedef NS_ENUM (NSInteger, CPTAxisLabelingPolicy) {
    CPTAxisLabelingPolicyNone,              ///< No labels provided; user sets labels and tick locations.
    CPTAxisLabelingPolicyLocationsProvided, ///< User sets tick locations; axis makes labels.
    CPTAxisLabelingPolicyFixedInterval,     ///< Fixed interval labeling policy.
    CPTAxisLabelingPolicyAutomatic,         ///< Automatic labeling policy.
    CPTAxisLabelingPolicyEqualDivisions     ///< Divide the plot range into equal parts.
};

/**
 *  @brief An array of axes.
 **/
typedef NSArray<__kindof CPTAxis *> CPTAxisArray;

/**
 *  @brief A mutable array of axes.
 **/
typedef NSMutableArray<__kindof CPTAxis *> CPTMutableAxisArray;

#pragma mark -

/**
 *  @brief Axis labeling delegate.
 **/
@protocol CPTAxisDelegate<CPTLayerDelegate>

@optional

/// @name Labels
/// @{

/** @brief @optional Determines if the axis should relabel itself now.
 *  @param axis The axis.
 *  @return @YES if the axis should relabel now.
 **/
-(BOOL)axisShouldRelabel:(nonnull CPTAxis *)axis;

/** @brief @optional The method is called after the axis is relabeled to allow the delegate to perform any
 *  necessary cleanup or further labeling actions.
 *  @param axis The axis.
 **/
-(void)axisDidRelabel:(nonnull CPTAxis *)axis;

/** @brief @optional This method gives the delegate a chance to create custom labels for each tick.
 *  It can be used with any labeling policy. Returning @NO will cause the axis not
 *  to update the labels. It is then the delegate&rsquo;s responsibility to do this.
 *  @param axis The axis.
 *  @param locations The locations of the major ticks.
 *  @return @YES if the axis class should proceed with automatic labeling.
 **/
-(BOOL)axis:(nonnull CPTAxis *)axis shouldUpdateAxisLabelsAtLocations:(nonnull CPTNumberSet *)locations;

/** @brief @optional This method gives the delegate a chance to create custom labels for each minor tick.
 *  It can be used with any labeling policy. Returning @NO will cause the axis not
 *  to update the labels. It is then the delegate&rsquo;s responsibility to do this.
 *  @param axis The axis.
 *  @param locations The locations of the minor ticks.
 *  @return @YES if the axis class should proceed with automatic labeling.
 **/
-(BOOL)axis:(nonnull CPTAxis *)axis shouldUpdateMinorAxisLabelsAtLocations:(nonnull CPTNumberSet *)locations;

/// @}

/// @name Label Selection
/// @{

/** @brief @optional Informs the delegate that an axis label
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param axis The axis.
 *  @param label The selected axis label.
 **/
-(void)axis:(nonnull CPTAxis *)axis labelWasSelected:(nonnull CPTAxisLabel *)label;

/** @brief @optional Informs the delegate that an axis label
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param axis The axis.
 *  @param label The selected axis label.
 *  @param event The event that triggered the selection.
 **/
-(void)axis:(nonnull CPTAxis *)axis labelWasSelected:(nonnull CPTAxisLabel *)label withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a minor tick axis label
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param axis The axis.
 *  @param label The selected minor tick axis label.
 **/
-(void)axis:(nonnull CPTAxis *)axis minorTickLabelWasSelected:(nonnull CPTAxisLabel *)label;

/** @brief @optional Informs the delegate that a minor tick axis label
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param axis The axis.
 *  @param label The selected minor tick axis label.
 *  @param event The event that triggered the selection.
 **/
-(void)axis:(nonnull CPTAxis *)axis minorTickLabelWasSelected:(nonnull CPTAxisLabel *)label withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that an axis label
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param axis The axis.
 *  @param label The selected axis label.
 **/
-(void)axis:(nonnull CPTAxis *)axis labelTouchDown:(nonnull CPTAxisLabel *)label;

/** @brief @optional Informs the delegate that an axis label
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param axis The axis.
 *  @param label The selected axis label.
 *  @param event The event that triggered the selection.
 **/
-(void)axis:(nonnull CPTAxis *)axis labelTouchDown:(nonnull CPTAxisLabel *)label withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that an axis label
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param axis The axis.
 *  @param label The selected axis label.
 **/
-(void)axis:(nonnull CPTAxis *)axis labelTouchUp:(nonnull CPTAxisLabel *)label;

/** @brief @optional Informs the delegate that an axis label
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param axis The axis.
 *  @param label The selected axis label.
 *  @param event The event that triggered the selection.
 **/
-(void)axis:(nonnull CPTAxis *)axis labelTouchUp:(nonnull CPTAxisLabel *)label withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a minor tick axis label
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param axis The axis.
 *  @param label The selected minor tick axis label.
 **/
-(void)axis:(nonnull CPTAxis *)axis minorTickTouchDown:(nonnull CPTAxisLabel *)label;

/** @brief @optional Informs the delegate that a minor tick axis label
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param axis The axis.
 *  @param label The selected minor tick axis label.
 *  @param event The event that triggered the selection.
 **/
-(void)axis:(nonnull CPTAxis *)axis minorTickTouchDown:(nonnull CPTAxisLabel *)label withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a minor tick axis label
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param axis The axis.
 *  @param label The selected minor tick axis label.
 **/
-(void)axis:(nonnull CPTAxis *)axis minorTickTouchUp:(nonnull CPTAxisLabel *)label;

/** @brief @optional Informs the delegate that a minor tick axis label
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param axis The axis.
 *  @param label The selected minor tick axis label.
 *  @param event The event that triggered the selection.
 **/
-(void)axis:(nonnull CPTAxis *)axis minorTickTouchUp:(nonnull CPTAxisLabel *)label withEvent:(nonnull CPTNativeEvent *)event;

/// @}

@end

#pragma mark -

@interface CPTAxis : CPTLayer

/// @name Axis
/// @{
@property (nonatomic, readwrite, copy, nullable) CPTLineStyle *axisLineStyle;
@property (nonatomic, readwrite, assign) CPTCoordinate coordinate;
@property (nonatomic, readwrite, strong, nonnull) NSNumber *labelingOrigin;
@property (nonatomic, readwrite, assign) CPTSign tickDirection;
@property (nonatomic, readwrite, copy, nullable) CPTPlotRange *visibleRange;
@property (nonatomic, readwrite, copy, nullable) CPTPlotRange *visibleAxisRange;
@property (nonatomic, readwrite, copy, nullable) CPTLineCap *axisLineCapMin;
@property (nonatomic, readwrite, copy, nullable) CPTLineCap *axisLineCapMax;
/// @}

/// @name Title
/// @{
@property (nonatomic, readwrite, copy, nullable) CPTTextStyle *titleTextStyle;
@property (nonatomic, readwrite, strong, nullable) CPTAxisTitle *axisTitle;
@property (nonatomic, readwrite, assign) CGFloat titleOffset;
@property (nonatomic, readwrite, copy, nullable) NSString *title;
@property (nonatomic, readwrite, copy, nullable) NSAttributedString *attributedTitle;
@property (nonatomic, readwrite, assign) CGFloat titleRotation;
@property (nonatomic, readwrite, assign) CPTSign titleDirection;
@property (nonatomic, readwrite, strong, nullable) NSNumber *titleLocation;
@property (nonatomic, readonly, nonnull) NSNumber *defaultTitleLocation;
/// @}

/// @name Labels
/// @{
@property (nonatomic, readwrite, assign) CPTAxisLabelingPolicy labelingPolicy;
@property (nonatomic, readwrite, assign) CGFloat labelOffset;
@property (nonatomic, readwrite, assign) CGFloat minorTickLabelOffset;
@property (nonatomic, readwrite, assign) CGFloat labelRotation;
@property (nonatomic, readwrite, assign) CGFloat minorTickLabelRotation;
@property (nonatomic, readwrite, assign) CPTAlignment labelAlignment;
@property (nonatomic, readwrite, assign) CPTAlignment minorTickLabelAlignment;
@property (nonatomic, readwrite, copy, nullable) CPTTextStyle *labelTextStyle;
@property (nonatomic, readwrite, copy, nullable) CPTTextStyle *minorTickLabelTextStyle;
@property (nonatomic, readwrite, assign) CPTSign tickLabelDirection;
@property (nonatomic, readwrite, assign) CPTSign minorTickLabelDirection;
@property (nonatomic, readwrite, strong, nullable) NSFormatter *labelFormatter;
@property (nonatomic, readwrite, strong, nullable) NSFormatter *minorTickLabelFormatter;
@property (nonatomic, readwrite, strong, nullable) CPTAxisLabelSet *axisLabels;
@property (nonatomic, readwrite, strong, nullable) CPTAxisLabelSet *minorTickAxisLabels;
@property (nonatomic, readonly) BOOL needsRelabel;
@property (nonatomic, readwrite, strong, nullable) CPTPlotRangeArray *labelExclusionRanges;
@property (nonatomic, readwrite, strong, nullable) CPTShadow *labelShadow;
@property (nonatomic, readwrite, strong, nullable) CPTShadow *minorTickLabelShadow;
/// @}

/// @name Major Ticks
/// @{
@property (nonatomic, readwrite, strong, nullable) NSNumber *majorIntervalLength;
@property (nonatomic, readwrite, assign) CGFloat majorTickLength;
@property (nonatomic, readwrite, copy, nullable) CPTLineStyle *majorTickLineStyle;
@property (nonatomic, readwrite, strong, nullable) CPTNumberSet *majorTickLocations;
@property (nonatomic, readwrite, assign) NSUInteger preferredNumberOfMajorTicks;
/// @}

/// @name Minor Ticks
/// @{
@property (nonatomic, readwrite, assign) NSUInteger minorTicksPerInterval;
@property (nonatomic, readwrite, assign) CGFloat minorTickLength;
@property (nonatomic, readwrite, copy, nullable) CPTLineStyle *minorTickLineStyle;
@property (nonatomic, readwrite, strong, nullable) CPTNumberSet *minorTickLocations;
/// @}

/// @name Grid Lines
/// @{
@property (nonatomic, readwrite, copy, nullable) CPTLineStyle *majorGridLineStyle;
@property (nonatomic, readwrite, copy, nullable) CPTLineStyle *minorGridLineStyle;
@property (nonatomic, readwrite, copy, nullable) CPTPlotRange *gridLinesRange;
/// @}

/// @name Background Bands
/// @{
@property (nonatomic, readwrite, copy, nullable) CPTFillArray *alternatingBandFills;
@property (nonatomic, readwrite, strong, nullable) NSNumber *alternatingBandAnchor;
@property (nonatomic, readonly, nullable) CPTLimitBandArray *backgroundLimitBands;
/// @}

/// @name Plot Space
/// @{
@property (nonatomic, readwrite, strong, nullable) CPTPlotSpace *plotSpace;
/// @}

/// @name Layers
/// @{
@property (nonatomic, readwrite, assign) BOOL separateLayers;
@property (nonatomic, readwrite, cpt_weak_property, nullable) CPTPlotArea *plotArea;
@property (nonatomic, readonly, cpt_weak_property, nullable) CPTGridLines *minorGridLines;
@property (nonatomic, readonly, cpt_weak_property, nullable) CPTGridLines *majorGridLines;
@property (nonatomic, readonly, nullable) CPTAxisSet *axisSet;
/// @}

/// @name Title
/// @{
-(void)updateAxisTitle;
/// @}

/// @name Labels
/// @{
-(void)relabel;
-(void)setNeedsRelabel;
-(void)updateMajorTickLabels;
-(void)updateMinorTickLabels;
/// @}

/// @name Ticks
/// @{
-(nullable CPTNumberSet *)filteredMajorTickLocations:(nullable CPTNumberSet *)allLocations;
-(nullable CPTNumberSet *)filteredMinorTickLocations:(nullable CPTNumberSet *)allLocations;
/// @}

/// @name Background Bands
/// @{
-(void)addBackgroundLimitBand:(nullable CPTLimitBand *)limitBand;
-(void)removeBackgroundLimitBand:(nullable CPTLimitBand *)limitBand;
-(void)removeAllBackgroundLimitBands;
/// @}

@end

#pragma mark -

/** @category CPTAxis(AbstractMethods)
 *  @brief CPTAxis abstract methods—must be overridden by subclasses
 **/
@interface CPTAxis(AbstractMethods)

/// @name Coordinate Space Conversions
/// @{
-(CGPoint)viewPointForCoordinateValue:(nullable NSNumber *)coordinateValue;
/// @}

/// @name Grid Lines
/// @{
-(void)drawGridLinesInContext:(nonnull CGContextRef)context isMajor:(BOOL)major;
/// @}

/// @name Background Bands
/// @{
-(void)drawBackgroundBandsInContext:(nonnull CGContextRef)context;
-(void)drawBackgroundLimitsInContext:(nonnull CGContextRef)context;
/// @}

@end

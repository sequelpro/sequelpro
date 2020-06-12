#import "CPTAxis.h"

#import "CPTAxisLabelGroup.h"
#import "CPTAxisSet.h"
#import "CPTAxisTitle.h"
#import "CPTColor.h"
#import "CPTExceptions.h"
#import "CPTGradient.h"
#import "CPTGridLineGroup.h"
#import "CPTGridLines.h"
#import "CPTImage.h"
#import "CPTLineCap.h"
#import "CPTLineStyle.h"
#import "CPTMutablePlotRange.h"
#import "CPTPlotArea.h"
#import "CPTPlotSpace.h"
#import "CPTShadow.h"
#import "CPTTextLayer.h"
#import "CPTUtilities.h"
#import "NSCoderExtensions.h"

/** @defgroup axisAnimation Axes
 *  @brief Axis properties that can be animated using Core Animation.
 *  @if MacOnly
 *  @since Custom layer property animation is supported on macOS 10.6 and later.
 *  @endif
 *  @ingroup animation
 **/

/// @cond

@interface CPTAxis()

@property (nonatomic, readwrite, assign) BOOL needsRelabel;
@property (nonatomic, readwrite, cpt_weak_property, nullable) CPTGridLines *minorGridLines;
@property (nonatomic, readwrite, cpt_weak_property, nullable) CPTGridLines *majorGridLines;
@property (nonatomic, readwrite, cpt_weak_property, nullable) CPTAxisLabel *pointingDeviceDownLabel;
@property (nonatomic, readwrite, cpt_weak_property, nullable) CPTAxisLabel *pointingDeviceDownTickLabel;
@property (nonatomic, readwrite, assign) BOOL labelFormatterChanged;
@property (nonatomic, readwrite, assign) BOOL minorLabelFormatterChanged;
@property (nonatomic, readwrite, strong, nullable) CPTMutableLimitBandArray *mutableBackgroundLimitBands;
@property (nonatomic, readonly) CGFloat tickOffset;
@property (nonatomic, readwrite, assign) BOOL inTitleUpdate;
@property (nonatomic, readwrite, assign) BOOL labelsUpdated;

-(void)generateFixedIntervalMajorTickLocations:(CPTNumberSet *__nonnull __autoreleasing *)newMajorLocations minorTickLocations:(CPTNumberSet *__nonnull __autoreleasing *)newMinorLocations;
-(void)autoGenerateMajorTickLocations:(CPTNumberSet *__nonnull __autoreleasing *)newMajorLocations minorTickLocations:(CPTNumberSet *__nonnull __autoreleasing *)newMinorLocations;
-(void)generateEqualMajorTickLocations:(CPTNumberSet *__nonnull __autoreleasing *)newMajorLocations minorTickLocations:(CPTNumberSet *__nonnull __autoreleasing *)newMinorLocations;
-(nullable CPTNumberSet *)filteredTickLocations:(nullable CPTNumberSet *)allLocations;
-(void)updateAxisLabelsAtLocations:(nullable CPTNumberSet *)locations inRange:(nullable CPTPlotRange *)labeledRange useMajorAxisLabels:(BOOL)useMajorAxisLabels;
-(void)updateCustomTickLabels;
-(void)updateMajorTickLabelOffsets;
-(void)updateMinorTickLabelOffsets;

NSDecimal CPTNiceNum(NSDecimal x);
NSDecimal CPTNiceLength(NSDecimal length);

@end

/// @endcond

#pragma mark -

/**
 *  @brief An abstract axis class.
 *
 *  The figure below illustrates the relationship between the three plot range properties. If all are
 *  @nil, the axis and grid lines will extend the full width of the plot area.
 *  @image html "axis ranges.png" "Axis Ranges"
 *  @see See @ref axisAnimation "Axes" for a list of animatable properties.
 **/
@implementation CPTAxis

// Axis

/** @property nullable CPTLineStyle *axisLineStyle
 *  @brief The line style for the axis line.
 *  If @nil, the line is not drawn.
 **/
@synthesize axisLineStyle;

/** @property CPTCoordinate coordinate
 *  @brief The axis coordinate.
 **/
@synthesize coordinate;

/** @property nonnull NSNumber *labelingOrigin
 *  @brief The origin used for axis labels.
 *  The default value is @num{0}. It is only used when the axis labeling
 *  policy is #CPTAxisLabelingPolicyFixedInterval. The origin is
 *  a reference point used to being labeling. Labels are added
 *  at the origin, as well as at fixed intervals above and below
 *  the origin.
 **/
@synthesize labelingOrigin;

/** @property CPTSign tickDirection
 *  @brief The tick direction.
 *  The direction is given as the sign that ticks extend along
 *  the axis (e.g., positive or negative).
 **/
@synthesize tickDirection;

/** @property nullable CPTPlotRange *visibleRange
 *  @brief The plot range over which the axis and ticks are visible.
 *  Use this to restrict an axis and its grid lines to less than the full plot area width.
 *  Use the @ref visibleAxisRange to specify a separate range for the axis line, if needed.
 *  Set to @nil for no restriction.
 **/
@synthesize visibleRange;

/** @property nullable CPTPlotRange *visibleAxisRange;
 *  @brief The plot range over which the axis itself is visible.
 *  Use this to restrict an axis line to less than the full plot area width. This range is independent
 *  of the @ref visibleRange and overrides it for the axis line and line cap.
 *  Set to @nil to use the @ref visibleRange instead.
 **/
@synthesize visibleAxisRange;

/** @property nullable CPTLineCap *axisLineCapMin
 *  @brief The line cap for the end of the axis line with the minimum value.
 *  @see axisLineCapMax
 **/
@synthesize axisLineCapMin;

/** @property nullable CPTLineCap *axisLineCapMax
 *  @brief The line cap for the end of the axis line with the maximum value.
 *  @see axisLineCapMin
 **/
@synthesize axisLineCapMax;

// Title

/** @property nullable CPTTextStyle *titleTextStyle
 *  @brief The text style used to draw the axis title text.
 *
 *  Assigning a new value to this property also sets the value of the @ref attributedTitle property to @nil.
 **/
@synthesize titleTextStyle;

/** @property nullable CPTAxisTitle *axisTitle
 *  @brief The axis title.
 *  If @nil, no title is drawn.
 **/
@synthesize axisTitle;

/** @property CGFloat titleOffset
 *  @brief The offset distance between the axis title and the axis line.
 *  @ingroup axisAnimation
 **/
@synthesize titleOffset;

/** @property nullable NSString *title
 *  @brief A convenience property for setting the text title of the axis.
 *
 *  Assigning a new value to this property also sets the value of the @ref attributedTitle property to @nil.
 **/
@synthesize title;

/** @property nullable NSAttributedString *attributedTitle
 *  @brief A convenience property for setting the styled text title of the axis.
 *
 *  Assigning a new value to this property also sets the value of the @ref title property to the
 *  same string without formatting information. It also replaces the @ref titleTextStyle with
 *  a style matching the first position (location @num{0}) of the styled title.
 *  Default is @nil.
 **/
@synthesize attributedTitle;

/** @property CGFloat titleRotation
 *  @brief The rotation angle of the axis title in radians.
 *  If @NAN (the default), the title will be parallel to the axis.
 *  @ingroup axisAnimation
 **/
@synthesize titleRotation;

/** @property CPTSign titleDirection
 *  @brief The offset direction for the axis title.
 *  The direction is given as the sign that ticks extend along
 *  the axis (e.g., positive or negative). If the title direction
 *  is #CPTSignNone (the default), the title is offset in the
 *  direction indicated by the @ref tickDirection.
 **/
@synthesize titleDirection;

/** @property nullable NSNumber *titleLocation
 *  @brief The position along the axis where the axis title should be centered.
 *  If @NAN (the default), the @ref defaultTitleLocation will be used.
 **/
@synthesize titleLocation;

/** @property nonnull NSNumber *defaultTitleLocation
 *  @brief The position along the axis where the axis title should be centered
 *  if @ref titleLocation is @NAN.
 **/
@dynamic defaultTitleLocation;

// Plot space

/** @property nullable CPTPlotSpace *plotSpace
 *  @brief The plot space for the axis.
 **/
@synthesize plotSpace;

// Labels

/** @property CPTAxisLabelingPolicy labelingPolicy
 *  @brief The axis labeling policy.
 **/
@synthesize labelingPolicy;

/** @property CGFloat labelOffset
 *  @brief The offset distance between the tick marks and labels.
 *  @ingroup axisAnimation
 **/
@synthesize labelOffset;

/** @property CGFloat minorTickLabelOffset
 *  @brief The offset distance between the minor tick marks and labels.
 *  @ingroup axisAnimation
 **/
@synthesize minorTickLabelOffset;

/** @property CGFloat labelRotation
 *  @brief The rotation of the axis labels in radians.
 *  Set this property to @num{π/2} to have labels read up the screen, for example.
 *  @ingroup axisAnimation
 **/
@synthesize labelRotation;

/** @property CGFloat minorTickLabelRotation
 *  @brief The rotation of the axis minor tick labels in radians.
 *  Set this property to @num{π/2} to have labels read up the screen, for example.
 *  @ingroup axisAnimation
 **/
@synthesize minorTickLabelRotation;

/** @property CPTAlignment labelAlignment
 *  @brief The alignment of the axis label with respect to the tick mark.
 **/
@synthesize labelAlignment;

/** @property CPTAlignment minorTickLabelAlignment
 *  @brief The alignment of the axis label with respect to the tick mark.
 **/
@synthesize minorTickLabelAlignment;

/** @property nullable CPTTextStyle *labelTextStyle
 *  @brief The text style used to draw the label text.
 **/
@synthesize labelTextStyle;

/** @property nullable CPTTextStyle *minorTickLabelTextStyle
 *  @brief The text style used to draw the label text of minor tick labels.
 **/
@synthesize minorTickLabelTextStyle;

/** @property CPTSign tickLabelDirection
 *  @brief The offset direction for major tick labels.
 *  The direction is given as the sign that ticks extend along
 *  the axis (e.g., positive or negative). If the label direction
 *  is #CPTSignNone (the default), the labels are offset in the
 *  direction indicated by the @ref tickDirection.
 **/
@synthesize tickLabelDirection;

/** @property CPTSign minorTickLabelDirection
 *  @brief The offset direction for minor tick labels.
 *  The direction is given as the sign that ticks extend along
 *  the axis (e.g., positive or negative). If the label direction
 *  is #CPTSignNone (the default), the labels are offset in the
 *  direction indicated by the @ref tickDirection.
 **/
@synthesize minorTickLabelDirection;

/** @property nullable NSFormatter *labelFormatter
 *  @brief The number formatter used to format the label text.
 *  If you need a non-numerical label, such as a date, you can use a formatter than turns
 *  the numerical plot coordinate into a string (e.g., @quote{Jan 10, 2010}).
 *  The CPTCalendarFormatter and CPTTimeFormatter classes are useful for this purpose.
 **/
@synthesize labelFormatter;

/** @property nullable NSFormatter *minorTickLabelFormatter
 *  @brief The number formatter used to format the label text of minor ticks.
 *  If you need a non-numerical label, such as a date, you can use a formatter than turns
 *  the numerical plot coordinate into a string (e.g., @quote{Jan 10, 2010}).
 *  The CPTCalendarFormatter and CPTTimeFormatter classes are useful for this purpose.
 **/
@synthesize minorTickLabelFormatter;

@synthesize labelFormatterChanged;
@synthesize minorLabelFormatterChanged;
@dynamic tickOffset;

/** @property nullable CPTAxisLabelSet *axisLabels
 *  @brief The set of axis labels.
 **/
@synthesize axisLabels;

/** @property nullable CPTAxisLabelSet *minorTickAxisLabels
 *  @brief The set of minor tick axis labels.
 **/
@synthesize minorTickAxisLabels;

/** @property BOOL needsRelabel
 *  @brief If @YES, the axis needs to be relabeled before the layer content is drawn.
 **/
@synthesize needsRelabel;

/** @property nullable CPTPlotRangeArray *labelExclusionRanges
 *  @brief An array of CPTPlotRange objects. Any tick marks and labels falling inside any of the ranges in the array will not be drawn.
 **/
@synthesize labelExclusionRanges;

/** @property nullable CPTShadow *labelShadow
 *  @brief The shadow applied to each axis label.
 **/
@synthesize labelShadow;

/** @property nullable CPTShadow *minorTickLabelShadow
 *  @brief The shadow applied to each minor tick axis label.
 **/
@synthesize minorTickLabelShadow;

// Major ticks

/** @property nullable NSNumber *majorIntervalLength
 *  @brief The distance between major tick marks expressed in data coordinates.
 **/
@synthesize majorIntervalLength;

/** @property nullable CPTLineStyle *majorTickLineStyle
 *  @brief The line style for the major tick marks.
 *  If @nil, the major ticks are not drawn.
 **/
@synthesize majorTickLineStyle;

/** @property CGFloat majorTickLength
 *  @brief The length of the major tick marks.
 **/
@synthesize majorTickLength;

/** @property nullable CPTNumberSet *majorTickLocations
 *  @brief A set of axis coordinates for all major tick marks.
 **/
@synthesize majorTickLocations;

/** @property NSUInteger preferredNumberOfMajorTicks
 *  @brief The number of ticks that should be targeted when auto-generating positions.
 *  This property only applies when the #CPTAxisLabelingPolicyAutomatic or
 *  #CPTAxisLabelingPolicyEqualDivisions policies are in use.
 *  If zero (@num{0}) (the default), Core Plot will choose a reasonable number of ticks.
 **/
@synthesize preferredNumberOfMajorTicks;

// Minor ticks

/** @property NSUInteger minorTicksPerInterval
 *  @brief The number of minor tick marks drawn in each major tick interval.
 **/
@synthesize minorTicksPerInterval;

/** @property nullable CPTLineStyle *minorTickLineStyle
 *  @brief The line style for the minor tick marks.
 *  If @nil, the minor ticks are not drawn.
 **/
@synthesize minorTickLineStyle;

/** @property CGFloat minorTickLength
 *  @brief The length of the minor tick marks.
 **/
@synthesize minorTickLength;

/** @property nullable CPTNumberSet *minorTickLocations
 *  @brief A set of axis coordinates for all minor tick marks.
 **/
@synthesize minorTickLocations;

// Grid Lines

/** @property nullable CPTLineStyle *majorGridLineStyle
 *  @brief The line style for the major grid lines.
 *  If @nil, the major grid lines are not drawn.
 **/
@synthesize majorGridLineStyle;

/** @property nullable CPTLineStyle *minorGridLineStyle
 *  @brief The line style for the minor grid lines.
 *  If @nil, the minor grid lines are not drawn.
 **/
@synthesize minorGridLineStyle;

/** @property nullable CPTPlotRange *CPTPlotRange *gridLinesRange
 *  @brief The plot range over which the grid lines are visible.
 *  Note that this range applies to the orthogonal coordinate, not
 *  the axis coordinate itself.
 *  Set to @nil for no restriction.
 **/
@synthesize gridLinesRange;

// Background Bands

/** @property nullable CPTFillArray *alternatingBandFills
 *  @brief An array of two or more fills to be drawn between successive major tick marks.
 *
 *  When initializing the fills, provide an NSArray containing any combination of CPTFill,
 *  CPTColor, CPTGradient, and/or CPTImage objects. Blank (transparent) bands can be created
 *  by using an NSNull object in place of some of the CPTFill objects.
 **/
@synthesize alternatingBandFills;

/** @property nullable NSNumber *alternatingBandAnchor
 *  @brief The starting location of the first band fill.
 *
 *  If @nil (the default), the first fill is drawn between the bottom left corner of the plot area
 *  and the first major tick location inside the plot area. If the anchor falls between two
 *  major tick locations, the first band fill wiil be drawn between those locations.
 **/
@synthesize alternatingBandAnchor;

/** @property nullable CPTLimitBandArray *backgroundLimitBands
 *  @brief An array of CPTLimitBand objects.
 *
 *  The limit bands are drawn on top of the alternating band fills.
 **/
@dynamic backgroundLimitBands;

@synthesize mutableBackgroundLimitBands;

// Layers

/** @property BOOL separateLayers
 *  @brief Use separate layers for drawing grid lines?
 *
 *  If @NO, the default, the major and minor grid lines are drawn in layers shared with other axes.
 *  If @YES, the grid lines are drawn in their own layers.
 **/
@synthesize separateLayers;

/** @property nullable CPTPlotArea *plotArea
 *  @brief The plot area that the axis belongs to.
 **/
@synthesize plotArea;

/** @property nullable CPTGridLines *minorGridLines
 *  @brief The layer that draws the minor grid lines.
 **/
@synthesize minorGridLines;

/** @property nullable CPTGridLines *majorGridLines
 *  @brief The layer that draws the major grid lines.
 **/
@synthesize majorGridLines;

/** @property nullable CPTAxisSet *axisSet
 *  @brief The axis set that the axis belongs to.
 **/
@dynamic axisSet;

/** @internal
 *  @property nullable CPTAxisLabel *pointingDeviceDownLabel
 *  @brief The label that was selected on the pointing device down event.
 **/
@synthesize pointingDeviceDownLabel;

/** @internal
 *  @property nullable CPTAxisLabel *pointingDeviceDownTickLabel
 *  @brief The tick label that was selected on the pointing device down event.
 **/
@synthesize pointingDeviceDownTickLabel;

@synthesize inTitleUpdate;
@synthesize labelsUpdated;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTAxis object with the provided frame rectangle.
 *
 *  This is the designated initializer. The initialized layer will have the following properties:
 *  - @ref plotSpace = @nil
 *  - @ref majorTickLocations = empty set
 *  - @ref minorTickLocations = empty set
 *  - @ref preferredNumberOfMajorTicks = @num{0}
 *  - @ref minorTickLength = @num{3.0}
 *  - @ref majorTickLength = @num{5.0}
 *  - @ref labelOffset = @num{2.0}
 *  - @ref minorTickLabelOffset = @num{2.0}
 *  - @ref labelRotation= @num{0.0}
 *  - @ref minorTickLabelRotation= @num{0.0}
 *  - @ref labelAlignment = #CPTAlignmentCenter
 *  - @ref minorTickLabelAlignment = #CPTAlignmentCenter
 *  - @ref title = @nil
 *  - @ref attributedTitle = @nil
 *  - @ref titleOffset = @num{30.0}
 *  - @ref axisLineStyle = default line style
 *  - @ref majorTickLineStyle = default line style
 *  - @ref minorTickLineStyle = default line style
 *  - @ref tickLabelDirection = #CPTSignNone
 *  - @ref minorTickLabelDirection = #CPTSignNone
 *  - @ref majorGridLineStyle = @nil
 *  - @ref minorGridLineStyle= @nil
 *  - @ref axisLineCapMin = @nil
 *  - @ref axisLineCapMax = @nil
 *  - @ref labelingOrigin = @num{0}
 *  - @ref majorIntervalLength = @num{1}
 *  - @ref minorTicksPerInterval = @num{1}
 *  - @ref coordinate = #CPTCoordinateX
 *  - @ref labelingPolicy = #CPTAxisLabelingPolicyFixedInterval
 *  - @ref labelTextStyle = default text style
 *  - @ref labelFormatter = number formatter that displays one fraction digit and at least one integer digit
 *  - @ref minorTickLabelTextStyle = default text style
 *  - @ref minorTickLabelFormatter = @nil
 *  - @ref axisLabels = empty set
 *  - @ref minorTickAxisLabels = empty set
 *  - @ref tickDirection = #CPTSignNone
 *  - @ref axisTitle = @nil
 *  - @ref titleTextStyle = default text style
 *  - @ref titleRotation = @NAN
 *  - @ref titleDirection = #CPTSignNone
 *  - @ref titleLocation = @NAN
 *  - @ref needsRelabel = @YES
 *  - @ref labelExclusionRanges = @nil
 *  - @ref plotArea = @nil
 *  - @ref separateLayers = @NO
 *  - @ref labelShadow = @nil
 *  - @ref minorTickLabelShadow = @nil
 *  - @ref alternatingBandFills = @nil
 *  - @ref alternatingBandAnchor = @nil
 *  - @ref minorGridLines = @nil
 *  - @ref majorGridLines = @nil
 *  - @ref needsDisplayOnBoundsChange = @YES
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTAxis object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame
{
    if ((self = [super initWithFrame:newFrame])) {
        plotSpace                   = nil;
        majorTickLocations          = [NSSet set];
        minorTickLocations          = [NSSet set];
        preferredNumberOfMajorTicks = 0;
        minorTickLength             = CPTFloat(3.0);
        majorTickLength             = CPTFloat(5.0);
        labelOffset                 = CPTFloat(2.0);
        minorTickLabelOffset        = CPTFloat(2.0);
        labelRotation               = CPTFloat(0.0);
        minorTickLabelRotation      = CPTFloat(0.0);
        labelAlignment              = CPTAlignmentCenter;
        minorTickLabelAlignment     = CPTAlignmentCenter;
        title                       = nil;
        attributedTitle             = nil;
        titleOffset                 = CPTFloat(30.0);
        axisLineStyle               = [[CPTLineStyle alloc] init];
        majorTickLineStyle          = [[CPTLineStyle alloc] init];
        minorTickLineStyle          = [[CPTLineStyle alloc] init];
        tickLabelDirection          = CPTSignNone;
        minorTickLabelDirection     = CPTSignNone;
        majorGridLineStyle          = nil;
        minorGridLineStyle          = nil;
        axisLineCapMin              = nil;
        axisLineCapMax              = nil;
        labelingOrigin              = @0.0;
        majorIntervalLength         = @1.0;
        minorTicksPerInterval       = 1;
        coordinate                  = CPTCoordinateX;
        labelingPolicy              = CPTAxisLabelingPolicyFixedInterval;
        labelTextStyle              = [[CPTTextStyle alloc] init];

        NSNumberFormatter *newFormatter = [[NSNumberFormatter alloc] init];
        newFormatter.minimumIntegerDigits  = 1;
        newFormatter.maximumFractionDigits = 1;
        newFormatter.minimumFractionDigits = 1;

        labelFormatter              = newFormatter;
        minorTickLabelTextStyle     = [[CPTTextStyle alloc] init];
        minorTickLabelFormatter     = nil;
        labelFormatterChanged       = YES;
        minorLabelFormatterChanged  = NO;
        axisLabels                  = [NSSet set];
        minorTickAxisLabels         = [NSSet set];
        tickDirection               = CPTSignNone;
        axisTitle                   = nil;
        titleTextStyle              = [[CPTTextStyle alloc] init];
        titleRotation               = CPTNAN;
        titleLocation               = @(NAN);
        needsRelabel                = YES;
        labelExclusionRanges        = nil;
        plotArea                    = nil;
        separateLayers              = NO;
        labelShadow                 = nil;
        minorTickLabelShadow        = nil;
        visibleRange                = nil;
        visibleAxisRange            = nil;
        gridLinesRange              = nil;
        alternatingBandFills        = nil;
        alternatingBandAnchor       = nil;
        mutableBackgroundLimitBands = nil;
        minorGridLines              = nil;
        majorGridLines              = nil;
        pointingDeviceDownLabel     = nil;
        pointingDeviceDownTickLabel = nil;
        inTitleUpdate               = NO;
        labelsUpdated               = NO;

        self.needsDisplayOnBoundsChange = YES;
    }
    return self;
}

/// @}

/// @cond

-(nonnull instancetype)initWithLayer:(nonnull id)layer
{
    if ((self = [super initWithLayer:layer])) {
        CPTAxis *theLayer = (CPTAxis *)layer;

        plotSpace                   = theLayer->plotSpace;
        majorTickLocations          = theLayer->majorTickLocations;
        minorTickLocations          = theLayer->minorTickLocations;
        preferredNumberOfMajorTicks = theLayer->preferredNumberOfMajorTicks;
        minorTickLength             = theLayer->minorTickLength;
        majorTickLength             = theLayer->majorTickLength;
        labelOffset                 = theLayer->labelOffset;
        minorTickLabelOffset        = theLayer->labelOffset;
        labelRotation               = theLayer->labelRotation;
        minorTickLabelRotation      = theLayer->labelRotation;
        labelAlignment              = theLayer->labelAlignment;
        minorTickLabelAlignment     = theLayer->labelAlignment;
        title                       = theLayer->title;
        attributedTitle             = theLayer->attributedTitle;
        titleOffset                 = theLayer->titleOffset;
        axisLineStyle               = theLayer->axisLineStyle;
        majorTickLineStyle          = theLayer->majorTickLineStyle;
        minorTickLineStyle          = theLayer->minorTickLineStyle;
        tickLabelDirection          = theLayer->tickLabelDirection;
        minorTickLabelDirection     = theLayer->minorTickLabelDirection;
        majorGridLineStyle          = theLayer->majorGridLineStyle;
        minorGridLineStyle          = theLayer->minorGridLineStyle;
        axisLineCapMin              = theLayer->axisLineCapMin;
        axisLineCapMax              = theLayer->axisLineCapMax;
        labelingOrigin              = theLayer->labelingOrigin;
        majorIntervalLength         = theLayer->majorIntervalLength;
        minorTicksPerInterval       = theLayer->minorTicksPerInterval;
        coordinate                  = theLayer->coordinate;
        labelingPolicy              = theLayer->labelingPolicy;
        labelFormatter              = theLayer->labelFormatter;
        minorTickLabelFormatter     = theLayer->minorTickLabelFormatter;
        axisLabels                  = theLayer->axisLabels;
        minorTickAxisLabels         = theLayer->minorTickAxisLabels;
        tickDirection               = theLayer->tickDirection;
        labelTextStyle              = theLayer->labelTextStyle;
        minorTickLabelTextStyle     = theLayer->minorTickLabelTextStyle;
        axisTitle                   = theLayer->axisTitle;
        titleTextStyle              = theLayer->titleTextStyle;
        titleRotation               = theLayer->titleRotation;
        titleDirection              = theLayer->titleDirection;
        titleLocation               = theLayer->titleLocation;
        needsRelabel                = theLayer->needsRelabel;
        labelExclusionRanges        = theLayer->labelExclusionRanges;
        plotArea                    = theLayer->plotArea;
        separateLayers              = theLayer->separateLayers;
        labelShadow                 = theLayer->labelShadow;
        minorTickLabelShadow        = theLayer->minorTickLabelShadow;
        visibleRange                = theLayer->visibleRange;
        visibleAxisRange            = theLayer->visibleAxisRange;
        gridLinesRange              = theLayer->gridLinesRange;
        alternatingBandFills        = theLayer->alternatingBandFills;
        alternatingBandAnchor       = theLayer->alternatingBandAnchor;
        mutableBackgroundLimitBands = theLayer->mutableBackgroundLimitBands;
        minorGridLines              = theLayer->minorGridLines;
        majorGridLines              = theLayer->majorGridLines;
        pointingDeviceDownLabel     = theLayer->pointingDeviceDownLabel;
        pointingDeviceDownTickLabel = theLayer->pointingDeviceDownTickLabel;
        inTitleUpdate               = theLayer->inTitleUpdate;
        labelsUpdated               = theLayer->labelsUpdated;
    }
    return self;
}

-(void)dealloc
{
    plotArea       = nil;
    minorGridLines = nil;
    majorGridLines = nil;
    for ( CPTAxisLabel *label in axisLabels ) {
        [label.contentLayer removeFromSuperlayer];
    }
    [axisTitle.contentLayer removeFromSuperlayer];
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeInteger:self.coordinate forKey:@"CPTAxis.coordinate"];
    [coder encodeObject:self.plotSpace forKey:@"CPTAxis.plotSpace"];
    [coder encodeObject:self.majorTickLocations forKey:@"CPTAxis.majorTickLocations"];
    [coder encodeObject:self.minorTickLocations forKey:@"CPTAxis.minorTickLocations"];
    [coder encodeCGFloat:self.majorTickLength forKey:@"CPTAxis.majorTickLength"];
    [coder encodeCGFloat:self.minorTickLength forKey:@"CPTAxis.minorTickLength"];
    [coder encodeCGFloat:self.labelOffset forKey:@"CPTAxis.labelOffset"];
    [coder encodeCGFloat:self.minorTickLabelOffset forKey:@"CPTAxis.minorTickLabelOffset"];
    [coder encodeCGFloat:self.labelRotation forKey:@"CPTAxis.labelRotation"];
    [coder encodeCGFloat:self.minorTickLabelRotation forKey:@"CPTAxis.minorTickLabelRotation"];
    [coder encodeInteger:self.labelAlignment forKey:@"CPTAxis.labelAlignment"];
    [coder encodeInteger:self.minorTickLabelAlignment forKey:@"CPTAxis.minorTickLabelAlignment"];
    [coder encodeObject:self.axisLineStyle forKey:@"CPTAxis.axisLineStyle"];
    [coder encodeObject:self.majorTickLineStyle forKey:@"CPTAxis.majorTickLineStyle"];
    [coder encodeObject:self.minorTickLineStyle forKey:@"CPTAxis.minorTickLineStyle"];
    [coder encodeInteger:self.tickLabelDirection forKey:@"CPTAxis.tickLabelDirection"];
    [coder encodeInteger:self.minorTickLabelDirection forKey:@"CPTAxis.minorTickLabelDirection"];
    [coder encodeObject:self.majorGridLineStyle forKey:@"CPTAxis.majorGridLineStyle"];
    [coder encodeObject:self.minorGridLineStyle forKey:@"CPTAxis.minorGridLineStyle"];
    [coder encodeObject:self.axisLineCapMin forKey:@"CPTAxis.axisLineCapMin"];
    [coder encodeObject:self.axisLineCapMax forKey:@"CPTAxis.axisLineCapMax"];
    [coder encodeObject:self.labelingOrigin forKey:@"CPTAxis.labelingOrigin"];
    [coder encodeObject:self.majorIntervalLength forKey:@"CPTAxis.majorIntervalLength"];
    [coder encodeInteger:(NSInteger)self.minorTicksPerInterval forKey:@"CPTAxis.minorTicksPerInterval"];
    [coder encodeInteger:(NSInteger)self.preferredNumberOfMajorTicks forKey:@"CPTAxis.preferredNumberOfMajorTicks"];
    [coder encodeInteger:self.labelingPolicy forKey:@"CPTAxis.labelingPolicy"];
    [coder encodeObject:self.labelTextStyle forKey:@"CPTAxis.labelTextStyle"];
    [coder encodeObject:self.minorTickLabelTextStyle forKey:@"CPTAxis.minorTickLabelTextStyle"];
    [coder encodeObject:self.titleTextStyle forKey:@"CPTAxis.titleTextStyle"];
    [coder encodeObject:self.labelFormatter forKey:@"CPTAxis.labelFormatter"];
    [coder encodeObject:self.minorTickLabelFormatter forKey:@"CPTAxis.minorTickLabelFormatter"];
    [coder encodeBool:self.labelFormatterChanged forKey:@"CPTAxis.labelFormatterChanged"];
    [coder encodeBool:self.minorLabelFormatterChanged forKey:@"CPTAxis.minorLabelFormatterChanged"];
    [coder encodeObject:self.axisLabels forKey:@"CPTAxis.axisLabels"];
    [coder encodeObject:self.minorTickAxisLabels forKey:@"CPTAxis.minorTickAxisLabels"];
    [coder encodeObject:self.axisTitle forKey:@"CPTAxis.axisTitle"];
    [coder encodeObject:self.title forKey:@"CPTAxis.title"];
    [coder encodeObject:self.attributedTitle forKey:@"CPTAxis.attributedTitle"];
    [coder encodeCGFloat:self.titleOffset forKey:@"CPTAxis.titleOffset"];
    [coder encodeCGFloat:self.titleRotation forKey:@"CPTAxis.titleRotation"];
    [coder encodeInteger:self.titleDirection forKey:@"CPTAxis.titleDirection"];
    [coder encodeObject:self.titleLocation forKey:@"CPTAxis.titleLocation"];
    [coder encodeInteger:self.tickDirection forKey:@"CPTAxis.tickDirection"];
    [coder encodeBool:self.needsRelabel forKey:@"CPTAxis.needsRelabel"];
    [coder encodeObject:self.labelExclusionRanges forKey:@"CPTAxis.labelExclusionRanges"];
    [coder encodeObject:self.visibleRange forKey:@"CPTAxis.visibleRange"];
    [coder encodeObject:self.visibleAxisRange forKey:@"CPTAxis.visibleAxisRange"];
    [coder encodeObject:self.gridLinesRange forKey:@"CPTAxis.gridLinesRange"];
    [coder encodeObject:self.alternatingBandFills forKey:@"CPTAxis.alternatingBandFills"];
    [coder encodeObject:self.alternatingBandAnchor forKey:@"CPTAxis.alternatingBandAnchor"];
    [coder encodeObject:self.mutableBackgroundLimitBands forKey:@"CPTAxis.mutableBackgroundLimitBands"];
    [coder encodeBool:self.separateLayers forKey:@"CPTAxis.separateLayers"];
    [coder encodeObject:self.labelShadow forKey:@"CPTAxis.labelShadow"];
    [coder encodeObject:self.minorTickLabelShadow forKey:@"CPTAxis.minorTickLabelShadow"];
    [coder encodeConditionalObject:self.plotArea forKey:@"CPTAxis.plotArea"];
    [coder encodeConditionalObject:self.minorGridLines forKey:@"CPTAxis.minorGridLines"];
    [coder encodeConditionalObject:self.majorGridLines forKey:@"CPTAxis.majorGridLines"];

    // No need to archive these properties:
    // pointingDeviceDownLabel
    // pointingDeviceDownTickLabel
    // inTitleUpdate
    // labelsUpdated
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        coordinate = (CPTCoordinate)[coder decodeIntegerForKey:@"CPTAxis.coordinate"];
        plotSpace  = [coder decodeObjectOfClass:[CPTPlotSpace class]
                                         forKey:@"CPTAxis.plotSpace"];
        majorTickLocations = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSSet class], [NSNumber class]]]
                                                   forKey:@"CPTAxis.majorTickLocations"];
        minorTickLocations = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSSet class], [NSNumber class]]]
                                                   forKey:@"CPTAxis.minorTickLocations"];
        majorTickLength         = [coder decodeCGFloatForKey:@"CPTAxis.majorTickLength"];
        minorTickLength         = [coder decodeCGFloatForKey:@"CPTAxis.minorTickLength"];
        labelOffset             = [coder decodeCGFloatForKey:@"CPTAxis.labelOffset"];
        minorTickLabelOffset    = [coder decodeCGFloatForKey:@"CPTAxis.minorTickLabelOffset"];
        labelRotation           = [coder decodeCGFloatForKey:@"CPTAxis.labelRotation"];
        minorTickLabelRotation  = [coder decodeCGFloatForKey:@"CPTAxis.minorTickLabelRotation"];
        labelAlignment          = (CPTAlignment)[coder decodeIntegerForKey:@"CPTAxis.labelAlignment"];
        minorTickLabelAlignment = (CPTAlignment)[coder decodeIntegerForKey:@"CPTAxis.minorTickLabelAlignment"];
        axisLineStyle           = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                                       forKey:@"CPTAxis.axisLineStyle"] copy];
        majorTickLineStyle = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                                  forKey:@"CPTAxis.majorTickLineStyle"] copy];
        minorTickLineStyle = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                                  forKey:@"CPTAxis.minorTickLineStyle"] copy];
        tickLabelDirection      = (CPTSign)[coder decodeIntegerForKey:@"CPTAxis.tickLabelDirection"];
        minorTickLabelDirection = (CPTSign)[coder decodeIntegerForKey:@"CPTAxis.minorTickLabelDirection"];
        majorGridLineStyle      = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                                       forKey:@"CPTAxis.majorGridLineStyle"] copy];
        minorGridLineStyle = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                                  forKey:@"CPTAxis.minorGridLineStyle"] copy];
        axisLineCapMin = [[coder decodeObjectOfClass:[CPTLineCap class]
                                              forKey:@"CPTAxis.axisLineCapMin"] copy];
        axisLineCapMax = [[coder decodeObjectOfClass:[CPTLineCap class]
                                              forKey:@"CPTAxis.axisLineCapMax"] copy];
        NSNumber *origin = [coder decodeObjectOfClass:[NSNumber class]
                                               forKey:@"CPTAxis.labelingOrigin"];
        labelingOrigin      = origin ? origin : @0.0;
        majorIntervalLength = [coder decodeObjectOfClass:[NSNumber class]
                                                  forKey:@"CPTAxis.majorIntervalLength"];
        minorTicksPerInterval       = (NSUInteger)[coder decodeIntegerForKey:@"CPTAxis.minorTicksPerInterval"];
        preferredNumberOfMajorTicks = (NSUInteger)[coder decodeIntegerForKey:@"CPTAxis.preferredNumberOfMajorTicks"];
        labelingPolicy              = (CPTAxisLabelingPolicy)[coder decodeIntegerForKey:@"CPTAxis.labelingPolicy"];
        labelTextStyle              = [[coder decodeObjectOfClass:[CPTTextStyle class]
                                                           forKey:@"CPTAxis.labelTextStyle"] copy];
        minorTickLabelTextStyle = [[coder decodeObjectOfClass:[CPTTextStyle class]
                                                       forKey:@"CPTAxis.minorTickLabelTextStyle"] copy];
        titleTextStyle = [[coder decodeObjectOfClass:[CPTTextStyle class]
                                              forKey:@"CPTAxis.titleTextStyle"] copy];
        labelFormatter = [coder decodeObjectOfClass:[NSFormatter class]
                                             forKey:@"CPTAxis.labelFormatter"];
        minorTickLabelFormatter = [coder decodeObjectOfClass:[NSFormatter class]
                                                      forKey:@"CPTAxis.minorTickLabelFormatter"];
        labelFormatterChanged      = [coder decodeBoolForKey:@"CPTAxis.labelFormatterChanged"];
        minorLabelFormatterChanged = [coder decodeBoolForKey:@"CPTAxis.minorLabelFormatterChanged"];
        axisLabels                 = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSSet class], [CPTAxisLabel class]]]
                                                           forKey:@"CPTAxis.axisLabels"];
        minorTickAxisLabels = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSSet class], [CPTAxisLabel class]]]
                                                    forKey:@"CPTAxis.minorTickAxisLabels"];
        axisTitle = [coder decodeObjectOfClass:[NSString class]
                                        forKey:@"CPTAxis.axisTitle"];
        title = [[coder decodeObjectOfClass:[NSString class]
                                     forKey:@"CPTAxis.title"] copy];
        attributedTitle = [[coder decodeObjectOfClass:[NSAttributedString class]
                                               forKey:@"CPTAxis.attributedTitle"] copy];
        titleOffset    = [coder decodeCGFloatForKey:@"CPTAxis.titleOffset"];
        titleRotation  = [coder decodeCGFloatForKey:@"CPTAxis.titleRotation"];
        titleDirection = (CPTSign)[coder decodeIntegerForKey:@"CPTAxis.titleDirection"];
        titleLocation  = [coder decodeObjectOfClass:[NSNumber class]
                                             forKey:@"CPTAxis.titleLocation"];
        tickDirection        = (CPTSign)[coder decodeIntegerForKey:@"CPTAxis.tickDirection"];
        needsRelabel         = [coder decodeBoolForKey:@"CPTAxis.needsRelabel"];
        labelExclusionRanges = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [CPTPlotRange class]]]
                                                     forKey:@"CPTAxis.labelExclusionRanges"];
        visibleRange = [[coder decodeObjectOfClass:[CPTPlotRange class]
                                            forKey:@"CPTAxis.visibleRange"] copy];
        visibleAxisRange = [[coder decodeObjectOfClass:[CPTPlotRange class]
                                                forKey:@"CPTAxis.visibleAxisRange"] copy];
        gridLinesRange = [[coder decodeObjectOfClass:[CPTPlotRange class]
                                              forKey:@"CPTAxis.gridLinesRange"] copy];
        alternatingBandFills = [[coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [CPTFill class]]]
                                                      forKey:@"CPTAxis.alternatingBandFills"] copy];
        alternatingBandAnchor = [coder decodeObjectOfClass:[NSNumber class]
                                                    forKey:@"CPTAxis.alternatingBandAnchor"];
        mutableBackgroundLimitBands = [[coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [CPTLimitBand class]]]
                                                             forKey:@"CPTAxis.mutableBackgroundLimitBands"] mutableCopy];
        separateLayers = [coder decodeBoolForKey:@"CPTAxis.separateLayers"];
        labelShadow    = [coder decodeObjectOfClass:[CPTShadow class]
                                             forKey:@"CPTAxis.labelShadow"];
        minorTickLabelShadow = [coder decodeObjectOfClass:[CPTShadow class]
                                                   forKey:@"CPTAxis.minorTickLabelShadow"];
        plotArea = [coder decodeObjectOfClass:[CPTPlotArea class]
                                       forKey:@"CPTAxis.plotArea"];
        minorGridLines = [coder decodeObjectOfClass:[CPTGridLines class]
                                             forKey:@"CPTAxis.minorGridLines"];
        majorGridLines = [coder decodeObjectOfClass:[CPTGridLines class]
                                             forKey:@"CPTAxis.majorGridLines"];

        pointingDeviceDownLabel     = nil;
        pointingDeviceDownTickLabel = nil;

        inTitleUpdate = NO;
        labelsUpdated = NO;
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
#pragma mark Animation

/// @cond

+(BOOL)needsDisplayForKey:(nonnull NSString *)aKey
{
    static NSSet<NSString *> *keys   = nil;
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^{
        keys = [NSSet setWithArray:@[@"titleOffset",
                                     @"titleRotation",
                                     @"labelOffset",
                                     @"minorTickLabelOffset",
                                     @"labelRotation",
                                     @"minorTickLabelRotation"]];
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
#pragma mark Ticks

/// @cond

/**
 *  @internal
 *  @brief Generate major and minor tick locations using the fixed interval labeling policy.
 *  @param newMajorLocations A new NSSet containing the major tick locations.
 *  @param newMinorLocations A new NSSet containing the minor tick locations.
 */
-(void)generateFixedIntervalMajorTickLocations:(CPTNumberSet *__autoreleasing *)newMajorLocations minorTickLocations:(CPTNumberSet *__autoreleasing *)newMinorLocations
{
    CPTMutableNumberSet *majorLocations = [NSMutableSet set];
    CPTMutableNumberSet *minorLocations = [NSMutableSet set];

    NSDecimal zero          = CPTDecimalFromInteger(0);
    NSDecimal majorInterval = self.majorIntervalLength.decimalValue;

    if ( CPTDecimalGreaterThan(majorInterval, zero)) {
        CPTMutablePlotRange *range = [[self.plotSpace plotRangeForCoordinate:self.coordinate] mutableCopy];
        if ( range ) {
            CPTPlotRange *theVisibleRange = self.visibleRange;
            if ( theVisibleRange ) {
                [range intersectionPlotRange:theVisibleRange];
            }

            NSDecimal rangeMin = range.minLimitDecimal;
            NSDecimal rangeMax = range.maxLimitDecimal;

            NSDecimal minorInterval;
            NSUInteger minorTickCount = self.minorTicksPerInterval;
            if ( minorTickCount > 0 ) {
                minorInterval = CPTDecimalDivide(majorInterval, CPTDecimalFromUnsignedInteger(minorTickCount + 1));
            }
            else {
                minorInterval = zero;
            }

            // Set starting coord--should be the smallest value >= rangeMin that is a whole multiple of majorInterval away from the labelingOrigin
            NSDecimal origin = self.labelingOrigin.decimalValue;
            NSDecimal coord  = CPTDecimalDivide(CPTDecimalSubtract(rangeMin, origin), majorInterval);
            NSDecimalRound(&coord, &coord, 0, NSRoundUp);
            coord = CPTDecimalAdd(CPTDecimalMultiply(coord, majorInterval), origin);

            // Set minor ticks between the starting point and rangeMin
            if ( minorTickCount > 0 ) {
                NSDecimal minorCoord = CPTDecimalSubtract(coord, minorInterval);

                for ( NSUInteger minorTickIndex = 0; minorTickIndex < minorTickCount; minorTickIndex++ ) {
                    if ( CPTDecimalLessThan(minorCoord, rangeMin)) {
                        break;
                    }
                    [minorLocations addObject:[NSDecimalNumber decimalNumberWithDecimal:minorCoord]];
                    minorCoord = CPTDecimalSubtract(minorCoord, minorInterval);
                }
            }

            // Set tick locations
            while ( CPTDecimalLessThanOrEqualTo(coord, rangeMax)) {
                // Major tick
                [majorLocations addObject:[NSDecimalNumber decimalNumberWithDecimal:coord]];

                // Minor ticks
                if ( minorTickCount > 0 ) {
                    NSDecimal minorCoord = CPTDecimalAdd(coord, minorInterval);

                    for ( NSUInteger minorTickIndex = 0; minorTickIndex < minorTickCount; minorTickIndex++ ) {
                        if ( CPTDecimalGreaterThan(minorCoord, rangeMax)) {
                            break;
                        }
                        [minorLocations addObject:[NSDecimalNumber decimalNumberWithDecimal:minorCoord]];
                        minorCoord = CPTDecimalAdd(minorCoord, minorInterval);
                    }
                }

                coord = CPTDecimalAdd(coord, majorInterval);
            }
        }
    }

    *newMajorLocations = majorLocations;
    *newMinorLocations = minorLocations;
}

/**
 *  @internal
 *  @brief Generate major and minor tick locations using the automatic labeling policy.
 *  @param newMajorLocations A new NSSet containing the major tick locations.
 *  @param newMinorLocations A new NSSet containing the minor tick locations.
 */
-(void)autoGenerateMajorTickLocations:(CPTNumberSet *__autoreleasing *)newMajorLocations minorTickLocations:(CPTNumberSet *__autoreleasing *)newMinorLocations
{
    // Create sets for locations
    CPTMutableNumberSet *majorLocations = [NSMutableSet set];
    CPTMutableNumberSet *minorLocations = [NSMutableSet set];

    // Get plot range
    CPTMutablePlotRange *range    = [[self.plotSpace plotRangeForCoordinate:self.coordinate] mutableCopy];
    CPTPlotRange *theVisibleRange = self.visibleRange;

    if ( theVisibleRange ) {
        [range intersectionPlotRange:theVisibleRange];
    }

    // Validate scale type
    BOOL valid             = YES;
    CPTScaleType scaleType = [self.plotSpace scaleTypeForCoordinate:self.coordinate];

    switch ( scaleType ) {
        case CPTScaleTypeLinear:
            // supported scale type
            break;

        case CPTScaleTypeLog:
            // supported scale type--check range
            if ((range.minLimitDouble <= 0.0) || (range.maxLimitDouble <= 0.0)) {
                valid = NO;
            }
            break;

        case CPTScaleTypeLogModulus:
            // supported scale type
            break;

        default:
            // unsupported scale type--bail out
            valid = NO;
            break;
    }

    if ( !valid ) {
        *newMajorLocations = majorLocations;
        *newMinorLocations = minorLocations;
        return;
    }

    // Cache some values
    NSUInteger numTicks   = self.preferredNumberOfMajorTicks;
    NSUInteger minorTicks = self.minorTicksPerInterval + 1;
    double length         = fabs(range.lengthDouble);

    // Filter troublesome values and return empty sets
    if ((length != 0.0) && !isinf(length)) {
        switch ( scaleType ) {
            case CPTScaleTypeLinear:
            {
                // Determine interval value
                switch ( numTicks ) {
                    case 0:
                        numTicks = 5;
                        break;

                    case 1:
                        numTicks = 2;
                        break;

                    default:
                        // ok
                        break;
                }

                NSDecimal zero = CPTDecimalFromInteger(0);
                NSDecimal one  = CPTDecimalFromInteger(1);

                NSDecimal majorInterval;
                if ( numTicks == 2 ) {
                    majorInterval = CPTNiceLength(range.lengthDecimal);
                }
                else {
                    majorInterval = CPTDecimalDivide(range.lengthDecimal, CPTDecimalFromUnsignedInteger(numTicks - 1));
                    majorInterval = CPTNiceNum(majorInterval);
                }
                if ( CPTDecimalLessThan(majorInterval, zero)) {
                    majorInterval = CPTDecimalMultiply(majorInterval, CPTDecimalFromInteger(-1));
                }

                NSDecimal minorInterval;
                if ( minorTicks > 1 ) {
                    minorInterval = CPTDecimalDivide(majorInterval, CPTDecimalFromUnsignedInteger(minorTicks));
                }
                else {
                    minorInterval = zero;
                }

                // Calculate actual range limits
                NSDecimal minLimit = range.minLimitDecimal;
                NSDecimal maxLimit = range.maxLimitDecimal;

                // Determine the initial and final major indexes for the actual visible range
                NSDecimal initialIndex = CPTDecimalDivide(minLimit, majorInterval);
                NSDecimalRound(&initialIndex, &initialIndex, 0, NSRoundDown);

                NSDecimal finalIndex = CPTDecimalDivide(maxLimit, majorInterval);
                NSDecimalRound(&finalIndex, &finalIndex, 0, NSRoundUp);

                // Iterate through the indexes with visible ticks and build the locations sets
                for ( NSDecimal i = initialIndex; CPTDecimalLessThanOrEqualTo(i, finalIndex); i = CPTDecimalAdd(i, one)) {
                    NSDecimal pointLocation      = CPTDecimalMultiply(majorInterval, i);
                    NSDecimal minorPointLocation = pointLocation;

                    for ( NSUInteger j = 1; j < minorTicks; j++ ) {
                        minorPointLocation = CPTDecimalAdd(minorPointLocation, minorInterval);

                        if ( CPTDecimalLessThan(minorPointLocation, minLimit)) {
                            continue;
                        }
                        if ( CPTDecimalGreaterThan(minorPointLocation, maxLimit)) {
                            continue;
                        }
                        [minorLocations addObject:[NSDecimalNumber decimalNumberWithDecimal:minorPointLocation]];
                    }

                    if ( CPTDecimalLessThan(pointLocation, minLimit)) {
                        continue;
                    }
                    if ( CPTDecimalGreaterThan(pointLocation, maxLimit)) {
                        continue;
                    }
                    [majorLocations addObject:[NSDecimalNumber decimalNumberWithDecimal:pointLocation]];
                }
            }
            break;

            case CPTScaleTypeLog:
            {
                double minLimit = range.minLimitDouble;
                double maxLimit = range.maxLimitDouble;

                if ((minLimit > 0.0) && (maxLimit > 0.0)) {
                    // Determine interval value
                    length = log10(maxLimit / minLimit);

                    double interval     = signbit(length) ? -1.0 : 1.0;
                    double intervalStep = pow(10.0, fabs(interval));

                    // Determine minor interval
                    double minorInterval = intervalStep * 0.9 * pow(10.0, floor(log10(minLimit))) / minorTicks;

                    // Determine the initial and final major indexes for the actual visible range
                    NSInteger initialIndex = (NSInteger)lrint(floor(log10(minLimit / fabs(interval)))); // can be negative
                    NSInteger finalIndex   = (NSInteger)lrint(ceil(log10(maxLimit / fabs(interval))));  // can be negative

                    // Iterate through the indexes with visible ticks and build the locations sets
                    for ( NSInteger i = initialIndex; i <= finalIndex; i++ ) {
                        double pointLocation = pow(10.0, i * interval);
                        for ( NSUInteger j = 1; j < minorTicks; j++ ) {
                            double minorPointLocation = pointLocation + minorInterval * j;
                            if ( minorPointLocation < minLimit ) {
                                continue;
                            }
                            if ( minorPointLocation > maxLimit ) {
                                continue;
                            }
                            [minorLocations addObject:@(minorPointLocation)];
                        }
                        minorInterval *= intervalStep;

                        if ( pointLocation < minLimit ) {
                            continue;
                        }
                        if ( pointLocation > maxLimit ) {
                            continue;
                        }
                        [majorLocations addObject:@(pointLocation)];
                    }
                }
            }
            break;

            case CPTScaleTypeLogModulus:
            {
                double minLimit = range.minLimitDouble;
                double maxLimit = range.maxLimitDouble;

                // Determine interval value
                double modMinLimit = CPTLogModulus(minLimit);
                double modMaxLimit = CPTLogModulus(maxLimit);

                double multiplier = pow(10.0, floor(log10(length)));
                multiplier = (multiplier < 1.0) ? multiplier : 1.0;

                double intervalStep = 10.0;

                // Determine the initial and final major indexes for the actual visible range
                NSInteger initialIndex = (NSInteger)lrint(floor(modMinLimit / multiplier)); // can be negative
                NSInteger finalIndex   = (NSInteger)lrint(ceil(modMaxLimit / multiplier));  // can be negative

                if ( initialIndex < 0 ) {
                    // Determine minor interval
                    double minorInterval = intervalStep * 0.9 * multiplier / minorTicks;

                    for ( NSInteger i = MIN(0, finalIndex); i >= initialIndex; i-- ) {
                        double pointLocation;
                        double sign = -multiplier;

                        if ( multiplier < 1.0 ) {
                            pointLocation = sign * pow(10.0, fabs((double)i) - 1.0);
                        }
                        else {
                            pointLocation = sign * pow(10.0, fabs((double)i));
                        }

                        for ( NSUInteger j = 1; j < minorTicks; j++ ) {
                            double minorPointLocation = pointLocation + sign * minorInterval * j;
                            if ( minorPointLocation < minLimit ) {
                                continue;
                            }
                            if ( minorPointLocation > maxLimit ) {
                                continue;
                            }
                            [minorLocations addObject:@(minorPointLocation)];
                        }
                        minorInterval *= intervalStep;

                        if ( i == 0 ) {
                            pointLocation = 0.0;
                        }
                        if ( pointLocation < minLimit ) {
                            continue;
                        }
                        if ( pointLocation > maxLimit ) {
                            continue;
                        }
                        [majorLocations addObject:@(pointLocation)];
                    }
                }

                if ( finalIndex >= 0 ) {
                    // Determine minor interval
                    double minorInterval = intervalStep * 0.9 * multiplier / minorTicks;

                    for ( NSInteger i = MAX(0, initialIndex); i <= finalIndex; i++ ) {
                        double pointLocation;
                        double sign = multiplier;

                        if ( multiplier < 1.0 ) {
                            pointLocation = sign * pow(10.0, fabs((double)i) - 1.0);
                        }
                        else {
                            pointLocation = sign * pow(10.0, fabs((double)i));
                        }

                        for ( NSUInteger j = 1; j < minorTicks; j++ ) {
                            double minorPointLocation = pointLocation + sign * minorInterval * j;
                            if ( minorPointLocation < minLimit ) {
                                continue;
                            }
                            if ( minorPointLocation > maxLimit ) {
                                continue;
                            }
                            [minorLocations addObject:@(minorPointLocation)];
                        }
                        minorInterval *= intervalStep;

                        if ( i == 0 ) {
                            pointLocation = 0.0;
                        }
                        if ( pointLocation < minLimit ) {
                            continue;
                        }
                        if ( pointLocation > maxLimit ) {
                            continue;
                        }
                        [majorLocations addObject:@(pointLocation)];
                    }
                }
            }
            break;

            default:
                break;
        }
    }

    // Return tick locations sets
    *newMajorLocations = majorLocations;
    *newMinorLocations = minorLocations;
}

/**
 *  @internal
 *  @brief Generate major and minor tick locations using the equal divisions labeling policy.
 *  @param newMajorLocations A new NSSet containing the major tick locations.
 *  @param newMinorLocations A new NSSet containing the minor tick locations.
 */
-(void)generateEqualMajorTickLocations:(CPTNumberSet *__autoreleasing *)newMajorLocations minorTickLocations:(CPTNumberSet *__autoreleasing *)newMinorLocations
{
    CPTMutableNumberSet *majorLocations = [NSMutableSet set];
    CPTMutableNumberSet *minorLocations = [NSMutableSet set];

    CPTMutablePlotRange *range = [[self.plotSpace plotRangeForCoordinate:self.coordinate] mutableCopy];

    if ( range ) {
        CPTPlotRange *theVisibleRange = self.visibleRange;
        if ( theVisibleRange ) {
            [range intersectionPlotRange:theVisibleRange];
        }

        if ( range.lengthDouble != 0.0 ) {
            NSDecimal zero     = CPTDecimalFromInteger(0);
            NSDecimal rangeMin = range.minLimitDecimal;
            NSDecimal rangeMax = range.maxLimitDecimal;

            NSUInteger majorTickCount = self.preferredNumberOfMajorTicks;

            if ( majorTickCount < 2 ) {
                majorTickCount = 2;
            }
            NSDecimal majorInterval = CPTDecimalDivide(range.lengthDecimal, CPTDecimalFromUnsignedInteger(majorTickCount - 1));
            if ( CPTDecimalLessThan(majorInterval, zero)) {
                majorInterval = CPTDecimalMultiply(majorInterval, CPTDecimalFromInteger(-1));
            }

            NSDecimal minorInterval;
            NSUInteger minorTickCount = self.minorTicksPerInterval;
            if ( minorTickCount > 0 ) {
                minorInterval = CPTDecimalDivide(majorInterval, CPTDecimalFromUnsignedInteger(minorTickCount + 1));
            }
            else {
                minorInterval = zero;
            }

            NSDecimal coord = rangeMin;

            // Set tick locations
            while ( CPTDecimalLessThanOrEqualTo(coord, rangeMax)) {
                // Major tick
                [majorLocations addObject:[NSDecimalNumber decimalNumberWithDecimal:coord]];

                // Minor ticks
                if ( minorTickCount > 0 ) {
                    NSDecimal minorCoord = CPTDecimalAdd(coord, minorInterval);

                    for ( NSUInteger minorTickIndex = 0; minorTickIndex < minorTickCount; minorTickIndex++ ) {
                        if ( CPTDecimalGreaterThan(minorCoord, rangeMax)) {
                            break;
                        }
                        [minorLocations addObject:[NSDecimalNumber decimalNumberWithDecimal:minorCoord]];
                        minorCoord = CPTDecimalAdd(minorCoord, minorInterval);
                    }
                }

                coord = CPTDecimalAdd(coord, majorInterval);
            }
        }
    }

    *newMajorLocations = majorLocations;
    *newMinorLocations = minorLocations;
}

/**
 *  @internal
 *  @brief Determines a @quote{nice} number (a multiple of @num{2}, @num{5}, or @num{10}) near the given number.
 *  @param x The number to round.
 */
NSDecimal CPTNiceNum(NSDecimal x)
{
    NSDecimal zero = CPTDecimalFromInteger(0);

    if ( CPTDecimalEquals(x, zero)) {
        return zero;
    }

    NSDecimal minusOne = CPTDecimalFromInteger(-1);

    BOOL xIsNegative = CPTDecimalLessThan(x, zero);
    if ( xIsNegative ) {
        x = CPTDecimalMultiply(x, minusOne);
    }

    short exponent = (short)lrint(floor(log10(CPTDecimalDoubleValue(x))));

    NSDecimal fractionPart;
    NSDecimalMultiplyByPowerOf10(&fractionPart, &x, -exponent, NSRoundPlain);

    NSDecimal roundedFraction;

    if ( CPTDecimalLessThan(fractionPart, CPTDecimalFromDouble(1.5))) {
        roundedFraction = CPTDecimalFromInteger(1);
    }
    else if ( CPTDecimalLessThan(fractionPart, CPTDecimalFromInteger(3))) {
        roundedFraction = CPTDecimalFromInteger(2);
    }
    else if ( CPTDecimalLessThan(fractionPart, CPTDecimalFromInteger(7))) {
        roundedFraction = CPTDecimalFromInteger(5);
    }
    else {
        roundedFraction = CPTDecimalFromInteger(10);
    }

    if ( xIsNegative ) {
        roundedFraction = CPTDecimalMultiply(roundedFraction, minusOne);
    }

    NSDecimal roundedNumber;
    NSDecimalMultiplyByPowerOf10(&roundedNumber, &roundedFraction, exponent, NSRoundPlain);

    return roundedNumber;
}

/**
 *  @internal
 *  @brief Determines a @quote{nice} range length (a multiple of @num{2}, @num{5}, or @num{10}) less than or equal to the given length.
 *  @param length The length to round.
 */
NSDecimal CPTNiceLength(NSDecimal length)
{
    NSDecimal zero = CPTDecimalFromInteger(0);

    if ( CPTDecimalEquals(length, zero)) {
        return zero;
    }

    NSDecimal minusOne = CPTDecimalFromInteger(-1);

    BOOL isNegative = CPTDecimalLessThan(length, zero);
    if ( isNegative ) {
        length = CPTDecimalMultiply(length, minusOne);
    }

    NSDecimal roundedNumber;

    if ( CPTDecimalGreaterThan(length, CPTDecimalFromInteger(10))) {
        NSDecimalRound(&roundedNumber, &length, 0, NSRoundDown);
    }
    else {
        short exponent = (short)lrint(floor(log10(CPTDecimalDoubleValue(length)))) - 1;
        NSDecimalRound(&roundedNumber, &length, -exponent, NSRoundDown);
    }

    if ( isNegative ) {
        roundedNumber = CPTDecimalMultiply(roundedNumber, minusOne);
    }

    return roundedNumber;
}

/**
 *  @internal
 *  @brief Removes any tick locations falling inside the label exclusion ranges from a set of tick locations.
 *  @param allLocations A set of tick locations.
 *  @return The filtered set of tick locations.
 */
-(nullable CPTNumberSet *)filteredTickLocations:(nullable CPTNumberSet *)allLocations
{
    CPTPlotRangeArray *exclusionRanges = self.labelExclusionRanges;

    if ( exclusionRanges ) {
        CPTMutableNumberSet *filteredLocations = [allLocations mutableCopy];
        for ( CPTPlotRange *range in exclusionRanges ) {
            for ( NSNumber *location in allLocations ) {
                if ( [range containsNumber:location] ) {
                    [filteredLocations removeObject:location];
                }
            }
        }
        return filteredLocations;
    }
    else {
        return allLocations;
    }
}

/// @endcond

/** @brief Removes any major ticks falling inside the label exclusion ranges from the set of tick locations.
 *  @param allLocations A set of major tick locations.
 *  @return The filtered set.
 **/
-(nullable CPTNumberSet *)filteredMajorTickLocations:(nullable CPTNumberSet *)allLocations
{
    return [self filteredTickLocations:allLocations];
}

/** @brief Removes any minor ticks falling inside the label exclusion ranges from the set of tick locations.
 *  @param allLocations A set of minor tick locations.
 *  @return The filtered set.
 **/
-(nullable CPTNumberSet *)filteredMinorTickLocations:(nullable CPTNumberSet *)allLocations
{
    return [self filteredTickLocations:allLocations];
}

#pragma mark -
#pragma mark Labels

/// @cond

-(CGFloat)tickOffset
{
    CGFloat offset = CPTFloat(0.0);

    switch ( self.tickDirection ) {
        case CPTSignNone:
            offset += self.majorTickLength * CPTFloat(0.5);
            break;

        case CPTSignPositive:
        case CPTSignNegative:
            offset += self.majorTickLength;
            break;
    }

    return offset;
}

/**
 *  @internal
 *  @brief Updates the set of axis labels using the given locations.
 *  Existing axis label objects and content layers are reused where possible.
 *  @param locations A set of NSDecimalNumber label locations.
 *  @param labeledRange A plot range used to filter the generated labels. If @nil, no filtering is done.
 *  @param useMajorAxisLabels If @YES, label the major ticks, otherwise label the minor ticks.
 **/
-(void)updateAxisLabelsAtLocations:(nullable CPTNumberSet *)locations inRange:(nullable CPTPlotRange *)labeledRange useMajorAxisLabels:(BOOL)useMajorAxisLabels
{
    CPTAlignment theLabelAlignment;
    CPTSign theLabelDirection;
    CGFloat theLabelOffset;
    CGFloat theLabelRotation;
    CPTTextStyle *theLabelTextStyle;
    NSFormatter *theLabelFormatter;
    BOOL theLabelFormatterChanged;
    CPTShadow *theShadow;

    id<CPTAxisDelegate> theDelegate = (id<CPTAxisDelegate>)self.delegate;

    if ( useMajorAxisLabels ) {
        if ( locations.count > 0 ) {
            if ( [theDelegate respondsToSelector:@selector(axis:shouldUpdateAxisLabelsAtLocations:)] ) {
                CPTNumberSet *locationSet = locations;
                BOOL shouldContinue       = [theDelegate axis:self shouldUpdateAxisLabelsAtLocations:locationSet];
                if ( !shouldContinue ) {
                    return;
                }
            }
        }
        theLabelAlignment        = self.labelAlignment;
        theLabelDirection        = self.tickLabelDirection;
        theLabelOffset           = self.labelOffset;
        theLabelRotation         = self.labelRotation;
        theLabelTextStyle        = self.labelTextStyle;
        theLabelFormatter        = self.labelFormatter;
        theLabelFormatterChanged = self.labelFormatterChanged;
        theShadow                = self.labelShadow;
    }
    else {
        if ( locations.count > 0 ) {
            if ( [theDelegate respondsToSelector:@selector(axis:shouldUpdateMinorAxisLabelsAtLocations:)] ) {
                CPTNumberSet *locationSet = locations;
                BOOL shouldContinue       = [theDelegate axis:self shouldUpdateMinorAxisLabelsAtLocations:locationSet];
                if ( !shouldContinue ) {
                    return;
                }
            }
        }
        theLabelAlignment        = self.minorTickLabelAlignment;
        theLabelDirection        = self.minorTickLabelDirection;
        theLabelOffset           = self.minorTickLabelOffset;
        theLabelRotation         = self.minorTickLabelRotation;
        theLabelTextStyle        = self.minorTickLabelTextStyle;
        theLabelFormatter        = self.minorTickLabelFormatter;
        theLabelFormatterChanged = self.minorLabelFormatterChanged;
        theShadow                = self.minorTickLabelShadow;
    }

    if ((locations.count == 0) || !theLabelTextStyle || !theLabelFormatter ) {
        if ( useMajorAxisLabels ) {
            self.axisLabels = nil;
        }
        else {
            self.minorTickAxisLabels = nil;
        }
        return;
    }

    CPTDictionary *textAttributes = theLabelTextStyle.attributes;
    BOOL hasAttributedFormatter   = ([theLabelFormatter attributedStringForObjectValue:[NSDecimalNumber zero]
                                                                 withDefaultAttributes:textAttributes] != nil);

    CPTPlotSpace *thePlotSpace = self.plotSpace;
    CPTCoordinate myCoordinate = self.coordinate;
    BOOL hasCategories         = ([thePlotSpace scaleTypeForCoordinate:myCoordinate] == CPTScaleTypeCategory);

    CPTSign direction = self.tickDirection;

    if ( theLabelDirection == CPTSignNone ) {
        theLabelDirection = direction;
    }

    if ((direction == CPTSignNone) || (theLabelDirection == direction)) {
        theLabelOffset += self.tickOffset;
    }

    CPTPlotArea *thePlotArea = self.plotArea;
    [thePlotArea setAxisSetLayersForType:CPTGraphLayerTypeAxisLabels];

    CPTMutableAxisLabelSet *oldAxisLabels;
    if ( useMajorAxisLabels ) {
        oldAxisLabels = [self.axisLabels mutableCopy];
    }
    else {
        oldAxisLabels = [self.minorTickAxisLabels mutableCopy];
    }

    CPTMutableAxisLabelSet *newAxisLabels = [[NSMutableSet alloc] initWithCapacity:locations.count];
    CPTAxisLabel *blankLabel              = [[CPTAxisLabel alloc] initWithText:nil textStyle:nil];
    CPTAxisLabelGroup *axisLabelGroup     = thePlotArea.axisLabelGroup;
    CPTLayer *lastLayer                   = nil;

    for ( NSDecimalNumber *tickLocation in locations ) {
        if ( labeledRange && ![labeledRange containsNumber:tickLocation] ) {
            continue;
        }

        CPTAxisLabel *newAxisLabel;
        BOOL needsNewContentLayer = NO;

        // reuse axis labels where possible--will prevent flicker when updating layers
        blankLabel.tickLocation = tickLocation;
        CPTAxisLabel *oldAxisLabel = [oldAxisLabels member:blankLabel];

        if ( oldAxisLabel ) {
            newAxisLabel = oldAxisLabel;
        }
        else {
            newAxisLabel              = [[CPTAxisLabel alloc] initWithText:nil textStyle:nil];
            newAxisLabel.tickLocation = tickLocation;
            needsNewContentLayer      = YES;
        }

        newAxisLabel.rotation  = theLabelRotation;
        newAxisLabel.offset    = theLabelOffset;
        newAxisLabel.alignment = theLabelAlignment;

        if ( needsNewContentLayer || theLabelFormatterChanged ) {
            CPTTextLayer *newLabelLayer = nil;
            if ( hasCategories ) {
                NSString *labelString = [thePlotSpace categoryForCoordinate:myCoordinate atIndex:tickLocation.unsignedIntegerValue];
                if ( labelString ) {
                    newLabelLayer = [[CPTTextLayer alloc] initWithText:labelString style:theLabelTextStyle];
                }
            }
            else if ( hasAttributedFormatter ) {
                NSAttributedString *labelString = [theLabelFormatter attributedStringForObjectValue:tickLocation withDefaultAttributes:textAttributes];
                newLabelLayer = [[CPTTextLayer alloc] initWithAttributedText:labelString];
            }
            else {
                NSString *labelString = [theLabelFormatter stringForObjectValue:tickLocation];
                newLabelLayer = [[CPTTextLayer alloc] initWithText:labelString style:theLabelTextStyle];
            }
            [oldAxisLabel.contentLayer removeFromSuperlayer];
            if ( newLabelLayer ) {
                newAxisLabel.contentLayer = newLabelLayer;

                if ( lastLayer ) {
                    [axisLabelGroup insertSublayer:newLabelLayer below:lastLayer];
                }
                else {
                    [axisLabelGroup insertSublayer:newLabelLayer atIndex:[thePlotArea sublayerIndexForAxis:self layerType:CPTGraphLayerTypeAxisLabels]];
                }
            }
        }

        lastLayer        = newAxisLabel.contentLayer;
        lastLayer.shadow = theShadow;

        [newAxisLabels addObject:newAxisLabel];
    }

    // remove old labels that are not needed any more from the layer hierarchy
    [oldAxisLabels minusSet:newAxisLabels];
    for ( CPTAxisLabel *label in oldAxisLabels ) {
        [label.contentLayer removeFromSuperlayer];
    }

    self.labelsUpdated = YES;
    if ( useMajorAxisLabels ) {
        self.axisLabels            = newAxisLabels;
        self.labelFormatterChanged = NO;
    }
    else {
        self.minorTickAxisLabels        = newAxisLabels;
        self.minorLabelFormatterChanged = NO;
    }
    self.labelsUpdated = NO;
}

/// @endcond

/**
 *  @brief Marks the receiver as needing to update the labels before the content is next drawn.
 **/
-(void)setNeedsRelabel
{
    self.needsRelabel = YES;
}

/**
 *  @brief Updates the axis labels.
 **/
-(void)relabel
{
    if ( !self.needsRelabel ) {
        return;
    }
    if ( !self.plotSpace ) {
        return;
    }
    id<CPTAxisDelegate> theDelegate = (id<CPTAxisDelegate>)self.delegate;
    if ( [theDelegate respondsToSelector:@selector(axisShouldRelabel:)] && ![theDelegate axisShouldRelabel:self] ) {
        self.needsRelabel = NO;
        return;
    }

    CPTNumberSet *newMajorLocations = nil;
    CPTNumberSet *newMinorLocations = nil;

    switch ( self.labelingPolicy ) {
        case CPTAxisLabelingPolicyNone:
        case CPTAxisLabelingPolicyLocationsProvided:
            // Locations are set by user
            break;

        case CPTAxisLabelingPolicyFixedInterval:
            [self generateFixedIntervalMajorTickLocations:&newMajorLocations minorTickLocations:&newMinorLocations];
            break;

        case CPTAxisLabelingPolicyAutomatic:
            [self autoGenerateMajorTickLocations:&newMajorLocations minorTickLocations:&newMinorLocations];
            break;

        case CPTAxisLabelingPolicyEqualDivisions:
            [self generateEqualMajorTickLocations:&newMajorLocations minorTickLocations:&newMinorLocations];
            break;
    }

    switch ( self.labelingPolicy ) {
        case CPTAxisLabelingPolicyNone:
        case CPTAxisLabelingPolicyLocationsProvided:
            // Locations are set by user--no filtering required
            break;

        default:
            // Filter and set tick locations
            self.majorTickLocations = [self filteredMajorTickLocations:newMajorLocations];
            self.minorTickLocations = [self filteredMinorTickLocations:newMinorLocations];
    }

    // Label ticks
    switch ( self.labelingPolicy ) {
        case CPTAxisLabelingPolicyNone:
            [self updateCustomTickLabels];
            break;

        case CPTAxisLabelingPolicyLocationsProvided:
        {
            CPTMutablePlotRange *labeledRange = [[self.plotSpace plotRangeForCoordinate:self.coordinate] mutableCopy];
            CPTPlotRange *theVisibleRange     = self.visibleRange;
            if ( theVisibleRange ) {
                [labeledRange intersectionPlotRange:theVisibleRange];
            }

            [self updateAxisLabelsAtLocations:self.majorTickLocations
                                      inRange:labeledRange
                           useMajorAxisLabels:YES];

            [self updateAxisLabelsAtLocations:self.minorTickLocations
                                      inRange:labeledRange
                           useMajorAxisLabels:NO];
        }
        break;

        default:
            [self updateAxisLabelsAtLocations:self.majorTickLocations
                                      inRange:nil
                           useMajorAxisLabels:YES];

            [self updateAxisLabelsAtLocations:self.minorTickLocations
                                      inRange:nil
                           useMajorAxisLabels:NO];
            break;
    }

    self.needsRelabel = NO;
    if ( self.alternatingBandFills.count > 0 ) {
        CPTPlotArea *thePlotArea = self.plotArea;
        [thePlotArea setNeedsDisplay];
    }

    if ( [theDelegate respondsToSelector:@selector(axisDidRelabel:)] ) {
        [theDelegate axisDidRelabel:self];
    }
}

/// @cond

/**
 *  @internal
 *  @brief Updates the position of all custom labels, hiding the ones that are outside the visible range.
 */
-(void)updateCustomTickLabels
{
    CPTMutablePlotRange *range = [[self.plotSpace plotRangeForCoordinate:self.coordinate] mutableCopy];

    if ( range ) {
        CPTPlotRange *theVisibleRange = self.visibleRange;
        if ( theVisibleRange ) {
            [range intersectionPlotRange:theVisibleRange];
        }

        if ( range.lengthDouble != 0.0 ) {
            CPTCoordinate orthogonalCoordinate = CPTOrthogonalCoordinate(self.coordinate);

            CPTSign direction = self.tickLabelDirection;

            if ( direction == CPTSignNone ) {
                direction = self.tickDirection;
            }

            for ( CPTAxisLabel *label in self.axisLabels ) {
                BOOL visible = [range containsNumber:label.tickLocation];
                label.contentLayer.hidden = !visible;
                if ( visible ) {
                    CGPoint tickBasePoint = [self viewPointForCoordinateValue:label.tickLocation];
                    [label positionRelativeToViewPoint:tickBasePoint forCoordinate:orthogonalCoordinate inDirection:direction];
                }
            }

            for ( CPTAxisLabel *label in self.minorTickAxisLabels ) {
                BOOL visible = [range containsNumber:label.tickLocation];
                label.contentLayer.hidden = !visible;
                if ( visible ) {
                    CGPoint tickBasePoint = [self viewPointForCoordinateValue:label.tickLocation];
                    [label positionRelativeToViewPoint:tickBasePoint forCoordinate:orthogonalCoordinate inDirection:direction];
                }
            }
        }
    }
}

-(void)updateMajorTickLabelOffsets
{
    CPTSign direction      = self.tickDirection;
    CPTSign labelDirection = self.tickLabelDirection;

    if ( labelDirection == CPTSignNone ) {
        labelDirection = direction;
    }

    CGFloat majorOffset = self.labelOffset;

    if ((direction == CPTSignNone) || (labelDirection == direction)) {
        majorOffset += self.tickOffset;
    }

    for ( CPTAxisLabel *label in self.axisLabels ) {
        label.offset = majorOffset;
    }
}

-(void)updateMinorTickLabelOffsets
{
    CPTSign direction      = self.tickDirection;
    CPTSign labelDirection = self.minorTickLabelDirection;

    if ( labelDirection == CPTSignNone ) {
        labelDirection = direction;
    }

    CGFloat minorOffset = self.minorTickLabelOffset;

    if ((direction == CPTSignNone) || (labelDirection == direction)) {
        minorOffset += self.tickOffset;
    }

    for ( CPTAxisLabel *label in self.minorTickAxisLabels ) {
        label.offset = minorOffset;
    }
}

/// @endcond

/**
 *  @brief Update the major tick mark labels.
 **/
-(void)updateMajorTickLabels
{
    CPTCoordinate orthogonalCoordinate = CPTOrthogonalCoordinate(self.coordinate);

    CPTSign direction = self.tickLabelDirection;

    if ( direction == CPTSignNone ) {
        direction = self.tickDirection;
    }

    for ( CPTAxisLabel *label in self.axisLabels ) {
        CGPoint tickBasePoint = [self viewPointForCoordinateValue:label.tickLocation];
        [label positionRelativeToViewPoint:tickBasePoint forCoordinate:orthogonalCoordinate inDirection:direction];
    }
}

/**
 *  @brief Update the minor tick mark labels.
 **/
-(void)updateMinorTickLabels
{
    CPTCoordinate orthogonalCoordinate = CPTOrthogonalCoordinate(self.coordinate);

    CPTSign direction = self.minorTickLabelDirection;

    if ( direction == CPTSignNone ) {
        direction = self.tickDirection;
    }

    for ( CPTAxisLabel *label in self.minorTickAxisLabels ) {
        CGPoint tickBasePoint = [self viewPointForCoordinateValue:label.tickLocation];
        [label positionRelativeToViewPoint:tickBasePoint forCoordinate:orthogonalCoordinate inDirection:direction];
    }
}

#pragma mark -
#pragma mark Titles

-(nonnull NSNumber *)defaultTitleLocation
{
    return @(NAN);
}

/**
 *  @brief Update the axis title position.
 **/
-(void)updateAxisTitle
{
    CPTSign direction = self.titleDirection;

    if ( direction == CPTSignNone ) {
        direction = self.tickDirection;
    }

    [self.axisTitle positionRelativeToViewPoint:[self viewPointForCoordinateValue:self.titleLocation]
                                  forCoordinate:CPTOrthogonalCoordinate(self.coordinate)
                                    inDirection:direction];
}

#pragma mark -
#pragma mark Layout

/// @name Layout
/// @{

/**
 *  @brief Updates the layout of all sublayers. The axes are relabeled if needed and all axis labels are repositioned.
 *
 *  This is where we do our custom replacement for the Mac-only layout manager and autoresizing mask.
 *  Subclasses should override this method to provide a different layout of their own sublayers.
 **/
-(void)layoutSublayers
{
    if ( self.needsRelabel ) {
        [self relabel];
    }
    else {
        [self updateMajorTickLabels];
        [self updateMinorTickLabels];
    }
    [self updateAxisTitle];
}

/// @}

#pragma mark -
#pragma mark Background Bands

/** @brief Add a background limit band.
 *  @param limitBand The new limit band.
 **/
-(void)addBackgroundLimitBand:(nullable CPTLimitBand *)limitBand
{
    if ( limitBand ) {
        if ( !self.mutableBackgroundLimitBands ) {
            self.mutableBackgroundLimitBands = [NSMutableArray array];
        }

        CPTLimitBand *band = limitBand;
        [self.mutableBackgroundLimitBands addObject:band];

        CPTPlotArea *thePlotArea = self.plotArea;
        [thePlotArea setNeedsDisplay];
    }
}

/** @brief Remove a background limit band.
 *  @param limitBand The limit band to be removed.
 **/
-(void)removeBackgroundLimitBand:(nullable CPTLimitBand *)limitBand
{
    if ( limitBand ) {
        CPTLimitBand *band = limitBand;
        [self.mutableBackgroundLimitBands removeObject:band];

        CPTPlotArea *thePlotArea = self.plotArea;
        [thePlotArea setNeedsDisplay];
    }
}

/** @brief Remove all background limit bands.
**/
-(void)removeAllBackgroundLimitBands
{
    [self.mutableBackgroundLimitBands removeAllObjects];

    CPTPlotArea *thePlotArea = self.plotArea;
    [thePlotArea setNeedsDisplay];
}

#pragma mark -
#pragma mark Responder Chain and User Interaction

/// @name User Interaction
/// @{

/**
 *  @brief Informs the receiver that the user has
 *  @if MacOnly pressed the mouse button. @endif
 *  @if iOSOnly started touching the screen. @endif
 *
 *
 *  If this axis has a delegate that responds to either
 *  @link CPTAxisDelegate::axis:labelTouchDown: -axis:labelTouchDown: @endlink or
 *  @link CPTAxisDelegate::axis:labelTouchDown:withEvent: -axis:labelTouchDown:withEvent: @endlink
 *  methods, the axis labels are searched to find the one containing the @par{interactionPoint}.
 *  The delegate method will be called and this method returns @YES if the @par{interactionPoint} is within a label.
 *
 *  If this axis has a delegate that responds to either
 *  @link CPTAxisDelegate::axis:minorTickTouchDown: -axis:minorTickTouchDown: @endlink or
 *  @link CPTAxisDelegate::axis:minorTickTouchDown:withEvent: -axis:minorTickTouchDown:withEvent: @endlink
 *  methods, the minor tick axis labels are searched to find the one containing the @par{interactionPoint}.
 *  The delegate method will be called and this method returns @YES if the @par{interactionPoint} is within a label.
 *
 *  This method returns @NO if the @par{interactionPoint} is outside all of the labels.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceDownEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    CPTGraph *theGraph = self.graph;

    if ( !theGraph || self.hidden ) {
        return NO;
    }

    id<CPTAxisDelegate> theDelegate = (id<CPTAxisDelegate>)self.delegate;

    // Tick labels
    if ( [theDelegate respondsToSelector:@selector(axis:labelTouchDown:)] ||
         [theDelegate respondsToSelector:@selector(axis:labelTouchDown:withEvent:)] ||
         [theDelegate respondsToSelector:@selector(axis:labelWasSelected:)] ||
         [theDelegate respondsToSelector:@selector(axis:labelWasSelected:withEvent:)] ) {
        for ( CPTAxisLabel *label in self.axisLabels ) {
            CPTLayer *contentLayer = label.contentLayer;
            if ( contentLayer && !contentLayer.hidden ) {
                CGPoint labelPoint = [theGraph convertPoint:interactionPoint toLayer:contentLayer];

                if ( CGRectContainsPoint(contentLayer.bounds, labelPoint)) {
                    self.pointingDeviceDownLabel = label;
                    BOOL handled = NO;

                    if ( [theDelegate respondsToSelector:@selector(axis:labelTouchDown:)] ) {
                        handled = YES;
                        [theDelegate axis:self labelTouchDown:label];
                    }

                    if ( [theDelegate respondsToSelector:@selector(axis:labelTouchDown:withEvent:)] ) {
                        handled = YES;
                        [theDelegate axis:self labelTouchDown:label withEvent:event];
                    }

                    if ( handled ) {
                        return YES;
                    }
                }
            }
        }
    }

    // Minor tick labels
    if ( [theDelegate respondsToSelector:@selector(axis:minorTickTouchDown:)] ||
         [theDelegate respondsToSelector:@selector(axis:minorTickTouchDown:withEvent:)] ||
         [theDelegate respondsToSelector:@selector(axis:minorTickLabelWasSelected:)] ||
         [theDelegate respondsToSelector:@selector(axis:minorTickLabelWasSelected:withEvent:)] ) {
        for ( CPTAxisLabel *label in self.minorTickAxisLabels ) {
            CPTLayer *contentLayer = label.contentLayer;
            if ( contentLayer && !contentLayer.hidden ) {
                CGPoint labelPoint = [theGraph convertPoint:interactionPoint toLayer:contentLayer];

                if ( CGRectContainsPoint(contentLayer.bounds, labelPoint)) {
                    self.pointingDeviceDownTickLabel = label;
                    BOOL handled = NO;

                    if ( [theDelegate respondsToSelector:@selector(axis:minorTickTouchDown:)] ) {
                        handled = YES;
                        [theDelegate axis:self minorTickTouchDown:label];
                    }

                    if ( [theDelegate respondsToSelector:@selector(axis:minorTickTouchDown:withEvent:)] ) {
                        handled = YES;
                        [theDelegate axis:self minorTickTouchDown:label withEvent:event];
                    }

                    if ( handled ) {
                        return YES;
                    }
                }
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
 *  If this axis has a delegate that responds to
 *  @link CPTAxisDelegate::axis:labelTouchUp: -axis:labelTouchUp: @endlink,
 *  @link CPTAxisDelegate::axis:labelTouchUp:withEvent: -axis:labelTouchUp:withEvent: @endlink
 *  @link CPTAxisDelegate::axis:labelWasSelected: -axis:labelWasSelected: @endlink, and/or
 *  @link CPTAxisDelegate::axis:labelWasSelected:withEvent: -axis:labelWasSelected:withEvent: @endlink
 *  methods, the axis labels are searched to find the one containing the @par{interactionPoint}.
 *  The delegate method will be called and this method returns @YES if the @par{interactionPoint} is within a label.
 *
 *  If this axis has a delegate that responds to
 *  @link CPTAxisDelegate::axis:minorTickTouchUp: -axis:minorTickTouchUp: @endlink,
 *  @link CPTAxisDelegate::axis:minorTickTouchUp:withEvent: -axis:minorTickTouchUp:withEvent: @endlink
 *  @link CPTAxisDelegate::axis:minorTickLabelWasSelected: -axis:minorTickLabelWasSelected: @endlink, and/or
 *  @link CPTAxisDelegate::axis:minorTickLabelWasSelected:withEvent: -axis:minorTickLabelWasSelected:withEvent: @endlink
 *  methods, the minor tick axis labels are searched to find the one containing the @par{interactionPoint}.
 *  The delegate method will be called and this method returns @YES if the @par{interactionPoint} is within a label.
 *
 *  This method returns @NO if the @par{interactionPoint} is outside all of the labels.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceUpEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    CPTAxisLabel *selectedDownLabel     = self.pointingDeviceDownLabel;
    CPTAxisLabel *selectedDownTickLabel = self.pointingDeviceDownTickLabel;

    self.pointingDeviceDownLabel     = nil;
    self.pointingDeviceDownTickLabel = nil;

    CPTGraph *theGraph = self.graph;

    if ( !theGraph || self.hidden ) {
        return NO;
    }

    id<CPTAxisDelegate> theDelegate = (id<CPTAxisDelegate>)self.delegate;

    // Tick labels
    if ( [theDelegate respondsToSelector:@selector(axis:labelTouchUp:)] ||
         [theDelegate respondsToSelector:@selector(axis:labelTouchUp:withEvent:)] ||
         [theDelegate respondsToSelector:@selector(axis:labelWasSelected:)] ||
         [theDelegate respondsToSelector:@selector(axis:labelWasSelected:withEvent:)] ) {
        for ( CPTAxisLabel *label in self.axisLabels ) {
            CPTLayer *contentLayer = label.contentLayer;
            if ( contentLayer && !contentLayer.hidden ) {
                CGPoint labelPoint = [theGraph convertPoint:interactionPoint toLayer:contentLayer];

                if ( CGRectContainsPoint(contentLayer.bounds, labelPoint)) {
                    BOOL handled = NO;

                    if ( [theDelegate respondsToSelector:@selector(axis:labelTouchUp:)] ) {
                        handled = YES;
                        [theDelegate axis:self labelTouchUp:label];
                    }

                    if ( [theDelegate respondsToSelector:@selector(axis:labelTouchUp:withEvent:)] ) {
                        handled = YES;
                        [theDelegate axis:self labelTouchUp:label withEvent:event];
                    }

                    if ( label == selectedDownLabel ) {
                        if ( [theDelegate respondsToSelector:@selector(axis:labelWasSelected:)] ) {
                            handled = YES;
                            [theDelegate axis:self labelWasSelected:label];
                        }

                        if ( [theDelegate respondsToSelector:@selector(axis:labelWasSelected:withEvent:)] ) {
                            handled = YES;
                            [theDelegate axis:self labelWasSelected:label withEvent:event];
                        }
                    }

                    if ( handled ) {
                        return YES;
                    }
                }
            }
        }
    }

    // Minor tick labels
    if ( [theDelegate respondsToSelector:@selector(axis:minorTickTouchUp:)] ||
         [theDelegate respondsToSelector:@selector(axis:minorTickTouchUp:withEvent:)] ||
         [theDelegate respondsToSelector:@selector(axis:minorTickLabelWasSelected:)] ||
         [theDelegate respondsToSelector:@selector(axis:minorTickLabelWasSelected:withEvent:)] ) {
        for ( CPTAxisLabel *label in self.minorTickAxisLabels ) {
            CPTLayer *contentLayer = label.contentLayer;
            if ( contentLayer && !contentLayer.hidden ) {
                CGPoint labelPoint = [theGraph convertPoint:interactionPoint toLayer:contentLayer];

                if ( CGRectContainsPoint(contentLayer.bounds, labelPoint)) {
                    BOOL handled = NO;

                    if ( [theDelegate respondsToSelector:@selector(axis:minorTickTouchUp:)] ) {
                        handled = YES;
                        [theDelegate axis:self minorTickTouchUp:label];
                    }

                    if ( [theDelegate respondsToSelector:@selector(axis:minorTickTouchUp:withEvent:)] ) {
                        handled = YES;
                        [theDelegate axis:self minorTickTouchUp:label withEvent:event];
                    }

                    if ( label == selectedDownTickLabel ) {
                        if ( [theDelegate respondsToSelector:@selector(axis:minorTickLabelWasSelected:)] ) {
                            handled = YES;
                            [theDelegate axis:self minorTickLabelWasSelected:label];
                        }

                        if ( [theDelegate respondsToSelector:@selector(axis:minorTickLabelWasSelected:withEvent:)] ) {
                            handled = YES;
                            [theDelegate axis:self minorTickLabelWasSelected:label withEvent:event];
                        }
                    }

                    if ( handled ) {
                        return YES;
                    }
                }
            }
        }
    }

    return [super pointingDeviceUpEvent:event atPoint:interactionPoint];
}

/// @}

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setAxisLabels:(nullable CPTAxisLabelSet *)newLabels
{
    if ( newLabels != axisLabels ) {
        if ( self.labelsUpdated ) {
            axisLabels = newLabels;
        }
        else {
            for ( CPTAxisLabel *label in axisLabels ) {
                [label.contentLayer removeFromSuperlayer];
            }

            axisLabels = newLabels;

            CPTPlotArea *thePlotArea = self.plotArea;
            [thePlotArea updateAxisSetLayersForType:CPTGraphLayerTypeAxisLabels];

            if ( axisLabels ) {
                CPTAxisLabelGroup *axisLabelGroup = thePlotArea.axisLabelGroup;
                CALayer *lastLayer                = nil;

                for ( CPTAxisLabel *label in axisLabels ) {
                    CPTLayer *contentLayer = label.contentLayer;
                    if ( contentLayer ) {
                        if ( lastLayer ) {
                            [axisLabelGroup insertSublayer:contentLayer below:lastLayer];
                        }
                        else {
                            [axisLabelGroup insertSublayer:contentLayer atIndex:[thePlotArea sublayerIndexForAxis:self layerType:CPTGraphLayerTypeAxisLabels]];
                        }

                        lastLayer = contentLayer;
                    }
                }
            }
        }

        if ( self.labelingPolicy == CPTAxisLabelingPolicyNone ) {
            [self updateCustomTickLabels];
        }
        else {
            [self updateMajorTickLabels];
        }
    }
}

-(void)setMinorTickAxisLabels:(nullable CPTAxisLabelSet *)newLabels
{
    if ( newLabels != minorTickAxisLabels ) {
        if ( self.labelsUpdated ) {
            minorTickAxisLabels = newLabels;
        }
        else {
            for ( CPTAxisLabel *label in minorTickAxisLabels ) {
                [label.contentLayer removeFromSuperlayer];
            }

            minorTickAxisLabels = newLabels;

            CPTPlotArea *thePlotArea = self.plotArea;
            [thePlotArea updateAxisSetLayersForType:CPTGraphLayerTypeAxisLabels];

            if ( minorTickAxisLabels ) {
                CPTAxisLabelGroup *axisLabelGroup = thePlotArea.axisLabelGroup;
                CALayer *lastLayer                = nil;

                for ( CPTAxisLabel *label in minorTickAxisLabels ) {
                    CPTLayer *contentLayer = label.contentLayer;
                    if ( contentLayer ) {
                        if ( lastLayer ) {
                            [axisLabelGroup insertSublayer:contentLayer below:lastLayer];
                        }
                        else {
                            [axisLabelGroup insertSublayer:contentLayer atIndex:[thePlotArea sublayerIndexForAxis:self layerType:CPTGraphLayerTypeAxisLabels]];
                        }

                        lastLayer = contentLayer;
                    }
                }
            }
        }

        if ( self.labelingPolicy == CPTAxisLabelingPolicyNone ) {
            [self updateCustomTickLabels];
        }
        else {
            [self updateMinorTickLabels];
        }
    }
}

-(void)setLabelTextStyle:(nullable CPTTextStyle *)newStyle
{
    if ( labelTextStyle != newStyle ) {
        labelTextStyle = [newStyle copy];

        Class textLayerClass = [CPTTextLayer class];
        for ( CPTAxisLabel *axisLabel in self.axisLabels ) {
            CPTLayer *contentLayer = axisLabel.contentLayer;
            if ( [contentLayer isKindOfClass:textLayerClass] ) {
                ((CPTTextLayer *)contentLayer).textStyle = labelTextStyle;
            }
        }

        [self updateMajorTickLabels];
    }
}

-(void)setMinorTickLabelTextStyle:(nullable CPTTextStyle *)newStyle
{
    if ( minorTickLabelTextStyle != newStyle ) {
        minorTickLabelTextStyle = [newStyle copy];

        Class textLayerClass = [CPTTextLayer class];
        for ( CPTAxisLabel *axisLabel in self.minorTickAxisLabels ) {
            CPTLayer *contentLayer = axisLabel.contentLayer;
            if ( [contentLayer isKindOfClass:textLayerClass] ) {
                ((CPTTextLayer *)contentLayer).textStyle = minorTickLabelTextStyle;
            }
        }

        [self updateMinorTickLabels];
    }
}

-(void)setAxisTitle:(nullable CPTAxisTitle *)newTitle
{
    if ( newTitle != axisTitle ) {
        [axisTitle.contentLayer removeFromSuperlayer];
        axisTitle = newTitle;

        CPTPlotArea *thePlotArea = self.plotArea;
        [thePlotArea updateAxisSetLayersForType:CPTGraphLayerTypeAxisTitles];

        if ( axisTitle ) {
            axisTitle.offset = self.titleOffset;
            CPTLayer *contentLayer = axisTitle.contentLayer;
            if ( contentLayer ) {
                [thePlotArea.axisTitleGroup insertSublayer:contentLayer atIndex:[thePlotArea sublayerIndexForAxis:self layerType:CPTGraphLayerTypeAxisTitles]];
                [self updateAxisTitle];
            }
        }
    }
}

-(nullable CPTAxisTitle *)axisTitle
{
    if ( !axisTitle ) {
        CPTAxisTitle *newTitle = nil;

        if ( self.attributedTitle ) {
            CPTTextLayer *textLayer = [[CPTTextLayer alloc] initWithAttributedText:self.attributedTitle];
            newTitle = [[CPTAxisTitle alloc] initWithContentLayer:textLayer];
        }
        else if ( self.title ) {
            newTitle = [[CPTAxisTitle alloc] initWithText:self.title textStyle:self.titleTextStyle];
        }

        if ( newTitle ) {
            newTitle.rotation = self.titleRotation;
            self.axisTitle    = newTitle;
        }
    }
    return axisTitle;
}

-(void)setTitleTextStyle:(nullable CPTTextStyle *)newStyle
{
    if ( newStyle != titleTextStyle ) {
        titleTextStyle = [newStyle copy];

        if ( !self.inTitleUpdate ) {
            self.inTitleUpdate   = YES;
            self.attributedTitle = nil;
            self.inTitleUpdate   = NO;

            CPTLayer *contentLayer = self.axisTitle.contentLayer;
            if ( [contentLayer isKindOfClass:[CPTTextLayer class]] ) {
                ((CPTTextLayer *)contentLayer).textStyle = titleTextStyle;
                [self updateAxisTitle];
            }
        }
    }
}

-(void)setTitleOffset:(CGFloat)newOffset
{
    if ( newOffset != titleOffset ) {
        titleOffset = newOffset;

        self.axisTitle.offset = titleOffset;
        [self updateAxisTitle];
    }
}

-(void)setTitleRotation:(CGFloat)newRotation
{
    if ( newRotation != titleRotation ) {
        titleRotation = newRotation;

        self.axisTitle.rotation = titleRotation;
        [self updateAxisTitle];
    }
}

-(void)setTitleDirection:(CPTSign)newDirection
{
    if ( newDirection != titleDirection ) {
        titleDirection = newDirection;

        [self updateAxisTitle];
    }
}

-(void)setTitle:(nullable NSString *)newTitle
{
    if ( newTitle != title ) {
        title = [newTitle copy];

        if ( !self.inTitleUpdate ) {
            self.inTitleUpdate   = YES;
            self.attributedTitle = nil;
            self.inTitleUpdate   = NO;

            if ( title ) {
                CPTLayer *contentLayer = self.axisTitle.contentLayer;
                if ( [contentLayer isKindOfClass:[CPTTextLayer class]] ) {
                    ((CPTTextLayer *)contentLayer).text = title;
                    [self updateAxisTitle];
                }
            }
            else {
                self.axisTitle = nil;
            }
        }
    }
}

-(void)setAttributedTitle:(nullable NSAttributedString *)newTitle
{
    if ( newTitle != attributedTitle ) {
        attributedTitle = [newTitle copy];

        if ( !self.inTitleUpdate ) {
            self.inTitleUpdate = YES;

            if ( attributedTitle ) {
                self.titleTextStyle = [CPTTextStyle textStyleWithAttributes:[attributedTitle attributesAtIndex:0
                                                                                                effectiveRange:NULL]];
                self.title = attributedTitle.string;

                CPTLayer *contentLayer = self.axisTitle.contentLayer;
                if ( [contentLayer isKindOfClass:[CPTTextLayer class]] ) {
                    ((CPTTextLayer *)contentLayer).attributedText = attributedTitle;
                    [self updateAxisTitle];
                }
            }
            else {
                self.titleTextStyle = nil;
                self.title          = nil;

                self.axisTitle = nil;
            }

            self.inTitleUpdate = NO;
        }
    }
}

-(void)setTitleLocation:(nullable NSNumber *)newLocation
{
    BOOL needsUpdate = YES;

    if ( newLocation ) {
        NSNumber *location = newLocation;
        needsUpdate = ![titleLocation isEqualToNumber:location];
    }

    if ( needsUpdate ) {
        titleLocation = newLocation;
        [self updateAxisTitle];
    }
}

-(nullable NSNumber *)titleLocation
{
    if ( isnan(titleLocation.doubleValue)) {
        return self.defaultTitleLocation;
    }
    else {
        return titleLocation;
    }
}

-(void)setLabelExclusionRanges:(nullable CPTPlotRangeArray *)ranges
{
    if ( ranges != labelExclusionRanges ) {
        labelExclusionRanges = ranges;
        self.needsRelabel    = YES;
    }
}

-(void)setNeedsRelabel:(BOOL)newNeedsRelabel
{
    if ( newNeedsRelabel != needsRelabel ) {
        needsRelabel = newNeedsRelabel;
        if ( needsRelabel ) {
            [self setNeedsDisplay];
            if ( self.separateLayers ) {
                CPTGridLines *gridlines = self.majorGridLines;
                [gridlines setNeedsDisplay];

                gridlines = self.minorGridLines;
                [gridlines setNeedsDisplay];
            }
            else {
                CPTPlotArea *thePlotArea = self.plotArea;
                [thePlotArea.majorGridLineGroup setNeedsDisplay];
                [thePlotArea.minorGridLineGroup setNeedsDisplay];
            }
        }
    }
}

-(void)setMajorTickLocations:(nullable CPTNumberSet *)newLocations
{
    if ( newLocations != majorTickLocations ) {
        majorTickLocations = newLocations;
        if ( self.separateLayers ) {
            CPTGridLines *gridlines = self.majorGridLines;
            [gridlines setNeedsDisplay];
        }
        else {
            CPTPlotArea *thePlotArea = self.plotArea;
            [thePlotArea.majorGridLineGroup setNeedsDisplay];
        }

        self.needsRelabel = YES;
    }
}

-(void)setMinorTickLocations:(nullable CPTNumberSet *)newLocations
{
    if ( newLocations != minorTickLocations ) {
        minorTickLocations = newLocations;
        if ( self.separateLayers ) {
            CPTGridLines *gridlines = self.minorGridLines;
            [gridlines setNeedsDisplay];
        }
        else {
            CPTPlotArea *thePlotArea = self.plotArea;
            [thePlotArea.minorGridLineGroup setNeedsDisplay];
        }

        self.needsRelabel = YES;
    }
}

-(void)setMajorTickLength:(CGFloat)newLength
{
    if ( newLength != majorTickLength ) {
        majorTickLength = newLength;

        [self updateMajorTickLabelOffsets];
        [self updateMinorTickLabelOffsets];

        [self setNeedsDisplay];
        [self updateMajorTickLabels];
        [self updateMinorTickLabels];
    }
}

-(void)setMinorTickLength:(CGFloat)newLength
{
    if ( newLength != minorTickLength ) {
        minorTickLength = newLength;
        [self setNeedsDisplay];
    }
}

-(void)setLabelOffset:(CGFloat)newOffset
{
    if ( newOffset != labelOffset ) {
        labelOffset = newOffset;

        [self updateMajorTickLabelOffsets];
        [self updateMajorTickLabels];
    }
}

-(void)setMinorTickLabelOffset:(CGFloat)newOffset
{
    if ( newOffset != minorTickLabelOffset ) {
        minorTickLabelOffset = newOffset;

        [self updateMinorTickLabelOffsets];
        [self updateMinorTickLabels];
    }
}

-(void)setLabelRotation:(CGFloat)newRotation
{
    if ( newRotation != labelRotation ) {
        labelRotation = newRotation;
        for ( CPTAxisLabel *label in self.axisLabels ) {
            label.rotation = labelRotation;
        }
        [self updateMajorTickLabels];
    }
}

-(void)setMinorTickLabelRotation:(CGFloat)newRotation
{
    if ( newRotation != minorTickLabelRotation ) {
        minorTickLabelRotation = newRotation;
        for ( CPTAxisLabel *label in self.minorTickAxisLabels ) {
            label.rotation = minorTickLabelRotation;
        }
        [self updateMinorTickLabels];
    }
}

-(void)setLabelAlignment:(CPTAlignment)newAlignment
{
    if ( newAlignment != labelAlignment ) {
        labelAlignment = newAlignment;
        [self updateMajorTickLabels];
    }
}

-(void)setMinorTickLabelAlignment:(CPTAlignment)newAlignment
{
    if ( newAlignment != minorTickLabelAlignment ) {
        minorTickLabelAlignment = newAlignment;
        [self updateMinorTickLabels];
    }
}

-(void)setLabelShadow:(nullable CPTShadow *)newLabelShadow
{
    if ( newLabelShadow != labelShadow ) {
        labelShadow = newLabelShadow;
        for ( CPTAxisLabel *label in self.axisLabels ) {
            label.contentLayer.shadow = labelShadow;
        }
        [self updateMajorTickLabels];
    }
}

-(void)setMinorTickLabelShadow:(nullable CPTShadow *)newLabelShadow
{
    if ( newLabelShadow != minorTickLabelShadow ) {
        minorTickLabelShadow = newLabelShadow;
        for ( CPTAxisLabel *label in self.minorTickAxisLabels ) {
            label.contentLayer.shadow = minorTickLabelShadow;
        }
        [self updateMinorTickLabels];
    }
}

-(void)setPlotSpace:(nullable CPTPlotSpace *)newSpace
{
    if ( newSpace != plotSpace ) {
        plotSpace         = newSpace;
        self.needsRelabel = YES;
    }
}

-(void)setCoordinate:(CPTCoordinate)newCoordinate
{
    if ( newCoordinate != coordinate ) {
        coordinate        = newCoordinate;
        self.needsRelabel = YES;
    }
}

-(void)setAxisLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    if ( newLineStyle != axisLineStyle ) {
        axisLineStyle = [newLineStyle copy];
        [self setNeedsDisplay];
    }
}

-(void)setMajorTickLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    if ( newLineStyle != majorTickLineStyle ) {
        majorTickLineStyle = [newLineStyle copy];
        [self setNeedsDisplay];
    }
}

-(void)setMinorTickLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    if ( newLineStyle != minorTickLineStyle ) {
        minorTickLineStyle = [newLineStyle copy];
        [self setNeedsDisplay];
    }
}

-(void)setMajorGridLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    if ( newLineStyle != majorGridLineStyle ) {
        majorGridLineStyle = [newLineStyle copy];

        CPTPlotArea *thePlotArea = self.plotArea;
        [thePlotArea updateAxisSetLayersForType:CPTGraphLayerTypeMajorGridLines];

        if ( self.separateLayers ) {
            if ( majorGridLineStyle ) {
                CPTGridLines *gridLines = self.majorGridLines;

                if ( gridLines ) {
                    [gridLines setNeedsDisplay];
                }
                else {
                    gridLines           = [[CPTGridLines alloc] init];
                    self.majorGridLines = gridLines;
                }
            }
            else {
                self.majorGridLines = nil;
            }
        }
        else {
            [thePlotArea.majorGridLineGroup setNeedsDisplay];
        }
    }
}

-(void)setMinorGridLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    if ( newLineStyle != minorGridLineStyle ) {
        minorGridLineStyle = [newLineStyle copy];

        CPTPlotArea *thePlotArea = self.plotArea;
        [thePlotArea updateAxisSetLayersForType:CPTGraphLayerTypeMinorGridLines];

        if ( self.separateLayers ) {
            if ( minorGridLineStyle ) {
                CPTGridLines *gridLines = self.minorGridLines;

                if ( gridLines ) {
                    [gridLines setNeedsDisplay];
                }
                else {
                    gridLines           = [[CPTGridLines alloc] init];
                    self.minorGridLines = gridLines;
                }
            }
            else {
                self.minorGridLines = nil;
            }
        }
        else {
            [thePlotArea.minorGridLineGroup setNeedsDisplay];
        }
    }
}

-(void)setAxisLineCapMin:(nullable CPTLineCap *)newAxisLineCapMin
{
    if ( newAxisLineCapMin != axisLineCapMin ) {
        axisLineCapMin = [newAxisLineCapMin copy];
        [self setNeedsDisplay];
    }
}

-(void)setAxisLineCapMax:(nullable CPTLineCap *)newAxisLineCapMax
{
    if ( newAxisLineCapMax != axisLineCapMax ) {
        axisLineCapMax = [newAxisLineCapMax copy];
        [self setNeedsDisplay];
    }
}

-(void)setLabelingOrigin:(nonnull NSNumber *)newLabelingOrigin
{
    BOOL needsUpdate = YES;

    if ( newLabelingOrigin ) {
        needsUpdate = ![labelingOrigin isEqualToNumber:newLabelingOrigin];
    }

    if ( needsUpdate ) {
        labelingOrigin = newLabelingOrigin;

        self.needsRelabel = YES;
    }
}

-(void)setMajorIntervalLength:(nullable NSNumber *)newIntervalLength
{
    BOOL needsUpdate = YES;

    if ( newIntervalLength ) {
        NSNumber *interval = newIntervalLength;
        needsUpdate = ![majorIntervalLength isEqualToNumber:interval];
    }

    if ( needsUpdate ) {
        majorIntervalLength = newIntervalLength;

        self.needsRelabel = YES;
    }
}

-(void)setMinorTicksPerInterval:(NSUInteger)newMinorTicksPerInterval
{
    if ( newMinorTicksPerInterval != minorTicksPerInterval ) {
        minorTicksPerInterval = newMinorTicksPerInterval;

        self.needsRelabel = YES;
    }
}

-(void)setLabelingPolicy:(CPTAxisLabelingPolicy)newPolicy
{
    if ( newPolicy != labelingPolicy ) {
        labelingPolicy    = newPolicy;
        self.needsRelabel = YES;
    }
}

-(void)setPreferredNumberOfMajorTicks:(NSUInteger)newPreferredNumberOfMajorTicks
{
    if ( newPreferredNumberOfMajorTicks != preferredNumberOfMajorTicks ) {
        preferredNumberOfMajorTicks = newPreferredNumberOfMajorTicks;
        if ( self.labelingPolicy == CPTAxisLabelingPolicyAutomatic ) {
            self.needsRelabel = YES;
        }
    }
}

-(void)setLabelFormatter:(nullable NSFormatter *)newTickLabelFormatter
{
    if ( newTickLabelFormatter != labelFormatter ) {
        labelFormatter = newTickLabelFormatter;

        self.labelFormatterChanged = YES;
        self.needsRelabel          = YES;
    }
}

-(void)setMinorTickLabelFormatter:(nullable NSFormatter *)newMinorTickLabelFormatter
{
    if ( newMinorTickLabelFormatter != minorTickLabelFormatter ) {
        minorTickLabelFormatter = newMinorTickLabelFormatter;

        self.minorLabelFormatterChanged = YES;
        self.needsRelabel               = YES;
    }
}

-(void)setTickDirection:(CPTSign)newDirection
{
    if ( newDirection != tickDirection ) {
        tickDirection = newDirection;

        [self updateMajorTickLabelOffsets];
        [self updateMinorTickLabelOffsets];

        [self setNeedsDisplay];
        [self updateMajorTickLabels];
        [self updateMinorTickLabels];
    }
}

-(void)setTickLabelDirection:(CPTSign)newDirection
{
    if ( newDirection != tickLabelDirection ) {
        tickLabelDirection = newDirection;

        [self updateMajorTickLabelOffsets];
        [self updateMajorTickLabels];
    }
}

-(void)setMinorTickLabelDirection:(CPTSign)newDirection
{
    if ( newDirection != minorTickLabelDirection ) {
        minorTickLabelDirection = newDirection;

        [self updateMinorTickLabelOffsets];
        [self updateMinorTickLabels];
    }
}

-(void)setGridLinesRange:(nullable CPTPlotRange *)newRange
{
    if ( gridLinesRange != newRange ) {
        gridLinesRange = [newRange copy];
        if ( self.separateLayers ) {
            CPTGridLines *gridlines = self.majorGridLines;
            [gridlines setNeedsDisplay];

            gridlines = self.minorGridLines;
            [gridlines setNeedsDisplay];
        }
        else {
            CPTPlotArea *thePlotArea = self.plotArea;
            [thePlotArea.majorGridLineGroup setNeedsDisplay];
            [thePlotArea.minorGridLineGroup setNeedsDisplay];
        }
    }
}

-(void)setPlotArea:(nullable CPTPlotArea *)newPlotArea
{
    if ( newPlotArea != plotArea ) {
        plotArea = newPlotArea;

        CPTGridLines *theMinorGridLines = self.minorGridLines;
        CPTGridLines *theMajorGridLines = self.majorGridLines;

        if ( newPlotArea ) {
            [newPlotArea updateAxisSetLayersForType:CPTGraphLayerTypeMinorGridLines];
            if ( theMinorGridLines ) {
                [theMinorGridLines removeFromSuperlayer];
                [newPlotArea.minorGridLineGroup insertSublayer:theMinorGridLines atIndex:[newPlotArea sublayerIndexForAxis:self layerType:CPTGraphLayerTypeMinorGridLines]];
            }

            [newPlotArea updateAxisSetLayersForType:CPTGraphLayerTypeMajorGridLines];
            if ( theMajorGridLines ) {
                [theMajorGridLines removeFromSuperlayer];
                [newPlotArea.majorGridLineGroup insertSublayer:theMajorGridLines atIndex:[newPlotArea sublayerIndexForAxis:self layerType:CPTGraphLayerTypeMajorGridLines]];
            }

            [newPlotArea updateAxisSetLayersForType:CPTGraphLayerTypeAxisLabels];
            if ( self.axisLabels.count > 0 ) {
                CPTAxisLabelGroup *axisLabelGroup = newPlotArea.axisLabelGroup;
                CALayer *lastLayer                = nil;

                for ( CPTAxisLabel *label in self.axisLabels ) {
                    CPTLayer *contentLayer = label.contentLayer;
                    if ( contentLayer ) {
                        [contentLayer removeFromSuperlayer];

                        if ( lastLayer ) {
                            [axisLabelGroup insertSublayer:contentLayer below:lastLayer];
                        }
                        else {
                            [axisLabelGroup insertSublayer:contentLayer atIndex:[newPlotArea sublayerIndexForAxis:self layerType:CPTGraphLayerTypeAxisLabels]];
                        }

                        lastLayer = contentLayer;
                    }
                }
            }

            if ( self.minorTickAxisLabels.count > 0 ) {
                CPTAxisLabelGroup *axisLabelGroup = newPlotArea.axisLabelGroup;
                CALayer *lastLayer                = nil;

                for ( CPTAxisLabel *label in self.minorTickAxisLabels ) {
                    CPTLayer *contentLayer = label.contentLayer;
                    if ( contentLayer ) {
                        [contentLayer removeFromSuperlayer];

                        if ( lastLayer ) {
                            [axisLabelGroup insertSublayer:contentLayer below:lastLayer];
                        }
                        else {
                            [axisLabelGroup insertSublayer:contentLayer atIndex:[newPlotArea sublayerIndexForAxis:self layerType:CPTGraphLayerTypeAxisLabels]];
                        }

                        lastLayer = contentLayer;
                    }
                }
            }

            [newPlotArea updateAxisSetLayersForType:CPTGraphLayerTypeAxisTitles];
            CPTLayer *content = self.axisTitle.contentLayer;
            if ( content ) {
                [content removeFromSuperlayer];
                [newPlotArea.axisTitleGroup insertSublayer:content atIndex:[newPlotArea sublayerIndexForAxis:self layerType:CPTGraphLayerTypeAxisTitles]];
            }
        }
        else {
            [theMinorGridLines removeFromSuperlayer];
            [theMajorGridLines removeFromSuperlayer];

            for ( CPTAxisLabel *label in self.axisLabels ) {
                [label.contentLayer removeFromSuperlayer];
            }
            for ( CPTAxisLabel *label in self.minorTickAxisLabels ) {
                [label.contentLayer removeFromSuperlayer];
            }
            [self.axisTitle.contentLayer removeFromSuperlayer];
        }
    }
}

-(void)setVisibleRange:(nullable CPTPlotRange *)newRange
{
    if ( newRange != visibleRange ) {
        visibleRange      = [newRange copy];
        self.needsRelabel = YES;
    }
}

-(void)setVisibleAxisRange:(nullable CPTPlotRange *)newRange
{
    if ( newRange != visibleAxisRange ) {
        visibleAxisRange  = [newRange copy];
        self.needsRelabel = YES;
    }
}

-(void)setSeparateLayers:(BOOL)newSeparateLayers
{
    if ( newSeparateLayers != separateLayers ) {
        separateLayers = newSeparateLayers;
        if ( separateLayers ) {
            if ( self.minorGridLineStyle ) {
                CPTGridLines *gridLines = [[CPTGridLines alloc] init];
                self.minorGridLines = gridLines;
            }
            if ( self.majorGridLineStyle ) {
                CPTGridLines *gridLines = [[CPTGridLines alloc] init];
                self.majorGridLines = gridLines;
            }
        }
        else {
            CPTPlotArea *thePlotArea = self.plotArea;
            self.minorGridLines = nil;
            if ( self.minorGridLineStyle ) {
                [thePlotArea.minorGridLineGroup setNeedsDisplay];
            }
            self.majorGridLines = nil;
            if ( self.majorGridLineStyle ) {
                [thePlotArea.majorGridLineGroup setNeedsDisplay];
            }
        }
    }
}

-(void)setMinorGridLines:(nullable CPTGridLines *)newGridLines
{
    CPTGridLines *oldGridLines = minorGridLines;

    if ( newGridLines != oldGridLines ) {
        [oldGridLines removeFromSuperlayer];
        minorGridLines = newGridLines;

        if ( newGridLines ) {
            CPTGridLines *gridLines = newGridLines;

            gridLines.major = NO;
            gridLines.axis  = self;

            CPTPlotArea *thePlotArea = self.plotArea;
            [thePlotArea.minorGridLineGroup insertSublayer:gridLines atIndex:[thePlotArea sublayerIndexForAxis:self layerType:CPTGraphLayerTypeMinorGridLines]];
        }
    }
}

-(void)setMajorGridLines:(nullable CPTGridLines *)newGridLines
{
    CPTGridLines *oldGridLines = majorGridLines;

    if ( newGridLines != oldGridLines ) {
        [oldGridLines removeFromSuperlayer];
        majorGridLines = newGridLines;

        if ( newGridLines ) {
            CPTGridLines *gridLines = newGridLines;

            gridLines.major = YES;
            gridLines.axis  = self;

            CPTPlotArea *thePlotArea = self.plotArea;
            [thePlotArea.majorGridLineGroup insertSublayer:gridLines atIndex:[thePlotArea sublayerIndexForAxis:self layerType:CPTGraphLayerTypeMajorGridLines]];
        }
    }
}

-(void)setAlternatingBandFills:(nullable CPTFillArray *)newFills
{
    if ( newFills != alternatingBandFills ) {
        Class nullClass = [NSNull class];
        Class fillClass = [CPTFill class];

        BOOL convertFills = NO;
        for ( id obj in newFills ) {
            if ( [obj isKindOfClass:nullClass] || [obj isKindOfClass:fillClass] ) {
                continue;
            }
            else {
                convertFills = YES;
                break;
            }
        }

        if ( convertFills ) {
            Class colorClass    = [CPTColor class];
            Class gradientClass = [CPTGradient class];
            Class imageClass    = [CPTImage class];

            CPTMutableFillArray *fillArray = [newFills mutableCopy];
            NSUInteger i                   = 0;
            CPTFill *newFill               = nil;

            for ( id obj in newFills ) {
                if ( [obj isKindOfClass:nullClass] || [obj isKindOfClass:fillClass] ) {
                    i++;
                    continue;
                }
                else if ( [obj isKindOfClass:colorClass] ) {
                    newFill = [[CPTFill alloc] initWithColor:obj];
                }
                else if ( [obj isKindOfClass:gradientClass] ) {
                    newFill = [[CPTFill alloc] initWithGradient:obj];
                }
                else if ( [obj isKindOfClass:imageClass] ) {
                    newFill = [[CPTFill alloc] initWithImage:obj];
                }
                else {
                    [NSException raise:CPTException format:@"Alternating band fills must be one or more of the following: CPTFill, CPTColor, CPTGradient, CPTImage, or [NSNull null]."];
                }

                fillArray[i] = newFill;

                i++;
            }

            alternatingBandFills = fillArray;
        }
        else {
            alternatingBandFills = [newFills copy];
        }

        CPTPlotArea *thePlotArea = self.plotArea;
        [thePlotArea setNeedsDisplay];
    }
}

-(void)setAlternatingBandAnchor:(nullable NSNumber *)newBandAnchor
{
    if ( newBandAnchor != alternatingBandAnchor ) {
        alternatingBandAnchor = newBandAnchor;

        CPTPlotArea *thePlotArea = self.plotArea;
        [thePlotArea setNeedsDisplay];
    }
}

-(nullable CPTLimitBandArray *)backgroundLimitBands
{
    return [self.mutableBackgroundLimitBands copy];
}

-(nullable CPTAxisSet *)axisSet
{
    CPTPlotArea *thePlotArea = self.plotArea;

    return thePlotArea.axisSet;
}

-(void)setHidden:(BOOL)newHidden
{
    if ( newHidden != self.hidden ) {
        super.hidden = newHidden;
        [self setNeedsRelabel];
    }
}

/// @endcond

@end

#pragma mark -

@implementation CPTAxis(AbstractMethods)

/** @brief Converts a position on the axis to drawing coordinates.
 *  @param coordinateValue The axis value in data coordinate space.
 *  @return The drawing coordinates of the point.
 **/
-(CGPoint)viewPointForCoordinateValue:(nullable NSNumber *__unused)coordinateValue
{
    return CGPointZero;
}

/** @brief Draws grid lines into the provided graphics context.
 *  @param context The graphics context to draw into.
 *  @param major Draw the major grid lines If @YES, minor grid lines otherwise.
 **/
-(void)drawGridLinesInContext:(nonnull CGContextRef __unused)context isMajor:(BOOL __unused)major
{
    // do nothing--subclasses must override to do their drawing
}

/** @brief Draws alternating background bands into the provided graphics context.
 *  @param context The graphics context to draw into.
 **/
-(void)drawBackgroundBandsInContext:(nonnull CGContextRef __unused)context
{
    // do nothing--subclasses must override to do their drawing
}

/** @brief Draws background limit ranges into the provided graphics context.
 *  @param context The graphics context to draw into.
 **/
-(void)drawBackgroundLimitsInContext:(nonnull CGContextRef __unused)context
{
    // do nothing--subclasses must override to do their drawing
}

@end

#import "CPTLegend.h"

#import "CPTExceptions.h"
#import "CPTFill.h"
#import "CPTGraph.h"
#import "CPTLegendEntry.h"
#import "CPTLineStyle.h"
#import "CPTPathExtensions.h"
#import "CPTTextStyle.h"
#import "CPTUtilities.h"
#import "NSCoderExtensions.h"
#import "NSNumberExtensions.h"
#import <tgmath.h>

/** @defgroup legendAnimation Legends
 *  @brief Legend properties that can be animated using Core Animation.
 *  @if MacOnly
 *  @since Custom layer property animation is supported on macOS 10.6 and later.
 *  @endif
 *  @ingroup animation
 **/

CPTLegendNotification const CPTLegendNeedsRedrawForPlotNotification        = @"CPTLegendNeedsRedrawForPlotNotification";
CPTLegendNotification const CPTLegendNeedsLayoutForPlotNotification        = @"CPTLegendNeedsLayoutForPlotNotification";
CPTLegendNotification const CPTLegendNeedsReloadEntriesForPlotNotification = @"CPTLegendNeedsReloadEntriesForPlotNotification";

/// @cond
@interface CPTLegend()

@property (nonatomic, readwrite, strong, nonnull) CPTMutablePlotArray *plots;
@property (nonatomic, readwrite, strong, nonnull) CPTMutableLegendEntryArray *legendEntries;
@property (nonatomic, readwrite, strong, nullable) CPTNumberArray *rowHeightsThatFit;
@property (nonatomic, readwrite, strong, nullable) CPTNumberArray *columnWidthsThatFit;
@property (nonatomic, readwrite, assign) BOOL layoutChanged;
@property (nonatomic, readwrite, cpt_weak_property, nullable) CPTLegendEntry *pointingDeviceDownEntry;

-(void)recalculateLayout;
-(void)removeLegendEntriesForPlot:(nonnull CPTPlot *)plot;

-(void)legendEntryForInteractionPoint:(CGPoint)interactionPoint row:(nonnull NSUInteger *)row col:(nonnull NSUInteger *)col;

-(void)legendNeedsRedraw:(nonnull NSNotification *)notif;
-(void)legendNeedsLayout:(nonnull NSNotification *)notif;
-(void)legendNeedsReloadEntries:(nonnull NSNotification *)notif;

@end

/// @endcond

#pragma mark -

/** @brief A graph legend.
 *
 *  The legend consists of one or more legend entries associated with plots. Each legend
 *  entry is made up of a graphical @quote{swatch} that corresponds with the plot and a text
 *  title or label to identify the data series to the viewer. The swatches provide a visual
 *  connection to the plot. For instance, a swatch for a scatter plot might include a line
 *  segment drawn in the line style of the plot along with a plot symbol while a swatch for
 *  a pie chart might only show a rectangle or other shape filled with the background fill
 *  of the corresponding pie slice.
 *
 *  The plots are not required to belong to the same graph, although that is the usual
 *  case. This allows creation of a master legend that covers multiple graphs.
 *
 *  @see See @ref legendAnimation "Legends" for a list of animatable properties.
 **/
@implementation CPTLegend

/** @property nullable CPTTextStyle *textStyle
 *  @brief The text style used to draw all legend entry titles.
 **/
@synthesize textStyle;

/** @property CGSize swatchSize
 *  @brief The size of the graphical swatch.
 *  If swatchSize is (@num{0.0}, @num{0.0}), swatches will be drawn using a square @num{150%} of the text size on a side.
 **/
@synthesize swatchSize;

/** @property nullable CPTLineStyle *swatchBorderLineStyle
 *  @brief The line style for the border drawn around each swatch.
 *  If @nil (the default), no border is drawn.
 **/
@synthesize swatchBorderLineStyle;

/** @property CGFloat swatchCornerRadius
 *  @brief The corner radius for each swatch. Default is @num{0.0}.
 *  @ingroup legendAnimation
 **/
@synthesize swatchCornerRadius;

/** @property nullable CPTFill *swatchFill
 *  @brief The background fill drawn behind each swatch.
 *  If @nil (the default), no fill is drawn.
 **/
@synthesize swatchFill;

/** @property nullable CPTLineStyle *entryBorderLineStyle
 *  @brief The line style for the border drawn around each legend entry.
 *  If @nil (the default), no border is drawn.
 **/
@synthesize entryBorderLineStyle;

/** @property CGFloat entryCornerRadius
 *  @brief The corner radius for the border around each legend entry. Default is @num{0.0}.
 *  @ingroup legendAnimation
 **/
@synthesize entryCornerRadius;

/** @property nullable CPTFill *entryFill
 *  @brief The background fill drawn behind each legend entry.
 *  If @nil (the default), no fill is drawn.
 **/
@synthesize entryFill;

/** @property CGFloat entryPaddingLeft
 *  @brief Amount to inset the swatch and title from the left side of the legend entry.
 **/
@synthesize entryPaddingLeft;

/** @property CGFloat entryPaddingTop
 *  @brief Amount to inset the swatch and title from the top of the legend entry.
 **/
@synthesize entryPaddingTop;

/** @property CGFloat entryPaddingRight
 *  @brief Amount to inset the swatch and title from the right side of the legend entry.
 **/
@synthesize entryPaddingRight;

/** @property CGFloat entryPaddingBottom
 *  @brief Amount to inset the swatch and title from the bottom of the legend entry.
 **/
@synthesize entryPaddingBottom;

/** @property NSUInteger numberOfRows
 *  @brief The desired number of rows of legend entries.
 *  If zero (@num{0}) (the default), the number of rows will be automatically determined.
 *  If both @ref numberOfRows and @ref numberOfColumns are greater than zero but their product is less than
 *  the total number of legend entries, some entries will not be shown.
 **/
@synthesize numberOfRows;

/** @property NSUInteger numberOfColumns
 *  @brief The desired number of columns of legend entries.
 *  If zero (@num{0}) (the default), the number of columns will be automatically determined.
 *  If both @ref numberOfRows and @ref numberOfColumns are greater than zero but their product is less than
 *  the total number of legend entries, some entries will not be shown.
 **/
@synthesize numberOfColumns;

/** @property BOOL equalRows
 *  @brief If @YES (the default) each row of legend entries will have the same height, otherwise rows will be sized to best fit the entries.
 **/
@synthesize equalRows;

/** @property BOOL equalColumns
 *  @brief If @YES each column of legend entries will have the same width, otherwise columns will be sized to best fit the entries.
 *  Default is @NO, meaning columns will be sized for the best fit.
 **/
@synthesize equalColumns;

/** @property nullable CPTNumberArray *rowHeights
 *  @brief The desired height of each row of legend entries, including the swatch and title.
 *  Each element in this array should be an NSNumber representing the height of the corresponding row in device units.
 *  Rows are numbered from top to bottom starting from zero (@num{0}). If @nil, all rows will be sized automatically.
 *  If there are more rows in the legend than specified in this array, the remaining rows will be sized automatically.
 *  Default is @nil.
 **/
@synthesize rowHeights;

/** @property nullable CPTNumberArray *rowHeightsThatFit
 *  @brief The computed best-fit height of each row of legend entries, including the swatch and title.
 *  Each element in this array is an NSNumber representing the height of the corresponding row in device units.
 *  Rows are numbered from top to bottom starting from zero (@num{0}).
 **/
@synthesize rowHeightsThatFit;

/** @property nullable CPTNumberArray *columnWidths
 *  @brief The desired width of each column of legend entries, including the swatch, title, and title offset.
 *  Each element in this array should be an NSNumber representing the width of the corresponding column in device units.
 *  Columns are numbered from left to right starting from zero (@num{0}). If @nil, all columns will be sized automatically.
 *  If there are more columns in the legend than specified in this array, the remaining columns will be sized automatically.
 *  Default is @nil.
 **/
@synthesize columnWidths;

/** @property nullable CPTNumberArray *columnWidthsThatFit
 *  @brief The computed best-fit width of each column of legend entries, including the swatch, title, and title offset.
 *  Each element in this array is an NSNumber representing the width of the corresponding column in device units.
 *  Columns are numbered from left to right starting from zero (@num{0}).
 **/
@synthesize columnWidthsThatFit;

/** @property CGFloat columnMargin
 *  @brief The margin between columns, specified in device units. Default is @num{10.0}.
 **/
@synthesize columnMargin;

/** @property CGFloat rowMargin
 *  @brief The margin between rows, specified in device units. Default is @num{5.0}.
 **/
@synthesize rowMargin;

/** @property CGFloat titleOffset
 *  @brief The distance between each swatch and its title, specified in device units. Default is @num{5.0}.
 **/
@synthesize titleOffset;

/** @property CPTLegendSwatchLayout swatchLayout
 *  @brief Where to draw the legend swatch relative to the title. Default is #CPTLegendSwatchLayoutLeft.
 **/
@synthesize swatchLayout;

/** @internal
 *  @property nonnull CPTMutablePlotArray *plots
 *  @brief An array of all plots associated with the legend.
 **/
@synthesize plots;

/** @internal
 *  @property nonnull CPTMutableLegendEntryArray *legendEntries
 *  @brief An array of all legend entries.
 **/
@synthesize legendEntries;

/** @property  BOOL layoutChanged
 *  @brief If @YES, the legend layout needs to recalculated.
 **/
@synthesize layoutChanged;

/** @internal
 *  @property nullable CPTLegendEntry *pointingDeviceDownEntry
 *  @brief The legend entry that was selected on the pointing device down event.
 **/
@synthesize pointingDeviceDownEntry;

#pragma mark -
#pragma mark Factory Methods

/** @brief Creates and returns a new CPTLegend instance with legend entries for each plot in the given array.
 *  @param newPlots An array of plots.
 *  @return A new CPTLegend instance.
 **/
+(nonnull instancetype)legendWithPlots:(nullable CPTPlotArray *)newPlots
{
    return [[self alloc] initWithPlots:newPlots];
}

/** @brief Creates and returns a new CPTLegend instance with legend entries for each plot in the given graph.
 *  @param graph The graph.
 *  @return A new CPTLegend instance.
 **/
+(nonnull instancetype)legendWithGraph:(nullable __kindof CPTGraph *)graph
{
    return [[self alloc] initWithGraph:graph];
}

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTLegend object with the provided frame rectangle.
 *
 *  This is the designated initializer. The initialized layer will have the following properties:
 *  - @ref layoutChanged = @YES
 *  - @ref textStyle = default text style
 *  - @ref swatchSize = (@num{0.0}, @num{0.0})
 *  - @ref swatchBorderLineStyle = @nil
 *  - @ref swatchCornerRadius = @num{0}
 *  - @ref swatchFill = @nil
 *  - @ref entryBorderLineStyle = @nil
 *  - @ref entryCornerRadius = @num{0}
 *  - @ref entryFill = @nil
 *  - @ref entryPaddingLeft = @num{0}
 *  - @ref entryPaddingTop = @num{0}
 *  - @ref entryPaddingRight = @num{0}
 *  - @ref entryPaddingBottom = @num{0}
 *  - @ref numberOfRows = @num{0}
 *  - @ref numberOfColumns = @num{0}
 *  - @ref equalRows = @YES
 *  - @ref equalColumns = @NO
 *  - @ref rowHeights = @nil
 *  - @ref rowHeightsThatFit = @nil
 *  - @ref columnWidths = @nil
 *  - @ref columnWidthsThatFit = @nil
 *  - @ref columnMargin = @num{10.0}
 *  - @ref rowMargin = @num{5.0}
 *  - @ref titleOffset = @num{5.0}
 *  - @ref swatchLayout = #CPTLegendSwatchLayoutLeft
 *  - @ref paddingLeft = @num{5.0}
 *  - @ref paddingTop = @num{5.0}
 *  - @ref paddingRight = @num{5.0}
 *  - @ref paddingBottom = @num{5.0}
 *  - @ref needsDisplayOnBoundsChange = @YES
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTLegend object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect)newFrame
{
    if ((self = [super initWithFrame:newFrame])) {
        plots                 = [[NSMutableArray alloc] init];
        legendEntries         = [[NSMutableArray alloc] init];
        layoutChanged         = YES;
        textStyle             = [[CPTTextStyle alloc] init];
        swatchSize            = CGSizeZero;
        swatchBorderLineStyle = nil;
        swatchCornerRadius    = CPTFloat(0.0);
        swatchFill            = nil;
        entryBorderLineStyle  = nil;
        entryCornerRadius     = CPTFloat(0.0);
        entryFill             = nil;
        entryPaddingLeft      = CPTFloat(0.0);
        entryPaddingTop       = CPTFloat(0.0);
        entryPaddingRight     = CPTFloat(0.0);
        entryPaddingBottom    = CPTFloat(0.0);
        numberOfRows          = 0;
        numberOfColumns       = 0;
        equalRows             = YES;
        equalColumns          = NO;
        rowHeights            = nil;
        rowHeightsThatFit     = nil;
        columnWidths          = nil;
        columnWidthsThatFit   = nil;
        columnMargin          = CPTFloat(10.0);
        rowMargin             = CPTFloat(5.0);
        titleOffset           = CPTFloat(5.0);
        swatchLayout          = CPTLegendSwatchLayoutLeft;

        pointingDeviceDownEntry = nil;

        self.paddingLeft   = CPTFloat(5.0);
        self.paddingTop    = CPTFloat(5.0);
        self.paddingRight  = CPTFloat(5.0);
        self.paddingBottom = CPTFloat(5.0);

        self.needsDisplayOnBoundsChange = YES;
    }
    return self;
}

/// @}

/** @brief Initializes a newly allocated CPTLegend object and adds legend entries for each plot in the given array.
 *  @param newPlots An array of plots.
 *  @return The initialized CPTLegend object.
 **/
-(nonnull instancetype)initWithPlots:(nullable CPTPlotArray *)newPlots
{
    if ((self = [self initWithFrame:CGRectZero])) {
        for ( CPTPlot *plot in newPlots ) {
            [self addPlot:plot];
        }
    }
    return self;
}

/** @brief Initializes a newly allocated CPTLegend object and adds legend entries for each plot in the given graph.
 *  @param graph A graph.
 *  @return The initialized CPTLegend object.
 **/
-(nonnull instancetype)initWithGraph:(nullable __kindof CPTGraph *)graph
{
    if ((self = [self initWithFrame:CGRectZero])) {
        for ( CPTPlot *plot in [graph allPlots] ) {
            [self addPlot:plot];
        }
    }
    return self;
}

/// @cond

-(nonnull instancetype)initWithLayer:(nonnull id)layer
{
    if ((self = [super initWithLayer:layer])) {
        CPTLegend *theLayer = (CPTLegend *)layer;

        plots                 = theLayer->plots;
        legendEntries         = theLayer->legendEntries;
        layoutChanged         = theLayer->layoutChanged;
        textStyle             = theLayer->textStyle;
        swatchSize            = theLayer->swatchSize;
        swatchBorderLineStyle = theLayer->swatchBorderLineStyle;
        swatchCornerRadius    = theLayer->swatchCornerRadius;
        swatchFill            = theLayer->swatchFill;
        entryBorderLineStyle  = theLayer->entryBorderLineStyle;
        entryCornerRadius     = theLayer->entryCornerRadius;
        entryFill             = theLayer->entryFill;
        entryPaddingLeft      = theLayer->entryPaddingLeft;
        entryPaddingTop       = theLayer->entryPaddingTop;
        entryPaddingRight     = theLayer->entryPaddingRight;
        entryPaddingBottom    = theLayer->entryPaddingBottom;
        numberOfRows          = theLayer->numberOfRows;
        numberOfColumns       = theLayer->numberOfColumns;
        equalRows             = theLayer->equalRows;
        equalColumns          = theLayer->equalColumns;
        rowHeights            = theLayer->rowHeights;
        rowHeightsThatFit     = theLayer->rowHeightsThatFit;
        columnWidths          = theLayer->columnWidths;
        columnWidthsThatFit   = theLayer->columnWidthsThatFit;
        columnMargin          = theLayer->columnMargin;
        rowMargin             = theLayer->rowMargin;
        titleOffset           = theLayer->titleOffset;
        swatchLayout          = theLayer->swatchLayout;

        pointingDeviceDownEntry = theLayer->pointingDeviceDownEntry;
    }
    return self;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeObject:self.plots forKey:@"CPTLegend.plots"];
    [coder encodeObject:self.legendEntries forKey:@"CPTLegend.legendEntries"];
    [coder encodeBool:self.layoutChanged forKey:@"CPTLegend.layoutChanged"];
    [coder encodeObject:self.textStyle forKey:@"CPTLegend.textStyle"];
    [coder encodeCPTSize:self.swatchSize forKey:@"CPTLegend.swatchSize"];
    [coder encodeObject:self.swatchBorderLineStyle forKey:@"CPTLegend.swatchBorderLineStyle"];
    [coder encodeCGFloat:self.swatchCornerRadius forKey:@"CPTLegend.swatchCornerRadius"];
    [coder encodeObject:self.swatchFill forKey:@"CPTLegend.swatchFill"];
    [coder encodeObject:self.entryBorderLineStyle forKey:@"CPTLegend.entryBorderLineStyle"];
    [coder encodeCGFloat:self.entryCornerRadius forKey:@"CPTLegend.entryCornerRadius"];
    [coder encodeObject:self.entryFill forKey:@"CPTLegend.entryFill"];
    [coder encodeCGFloat:self.entryPaddingLeft forKey:@"CPTLegend.entryPaddingLeft"];
    [coder encodeCGFloat:self.entryPaddingTop forKey:@"CPTLegend.entryPaddingTop"];
    [coder encodeCGFloat:self.entryPaddingRight forKey:@"CPTLegend.entryPaddingRight"];
    [coder encodeCGFloat:self.entryPaddingBottom forKey:@"CPTLegend.entryPaddingBottom"];
    [coder encodeInteger:(NSInteger)self.numberOfRows forKey:@"CPTLegend.numberOfRows"];
    [coder encodeInteger:(NSInteger)self.numberOfColumns forKey:@"CPTLegend.numberOfColumns"];
    [coder encodeBool:self.equalRows forKey:@"CPTLegend.equalRows"];
    [coder encodeBool:self.equalColumns forKey:@"CPTLegend.equalColumns"];
    [coder encodeObject:self.rowHeights forKey:@"CPTLegend.rowHeights"];
    [coder encodeObject:self.rowHeightsThatFit forKey:@"CPTLegend.rowHeightsThatFit"];
    [coder encodeObject:self.columnWidths forKey:@"CPTLegend.columnWidths"];
    [coder encodeObject:self.columnWidthsThatFit forKey:@"CPTLegend.columnWidthsThatFit"];
    [coder encodeCGFloat:self.columnMargin forKey:@"CPTLegend.columnMargin"];
    [coder encodeCGFloat:self.rowMargin forKey:@"CPTLegend.rowMargin"];
    [coder encodeCGFloat:self.titleOffset forKey:@"CPTLegend.titleOffset"];
    [coder encodeInteger:(NSInteger)self.swatchLayout forKey:@"CPTLegend.swatchLayout"];

    // No need to archive these properties:
    // pointingDeviceDownEntry
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        NSArray *plotArray = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [CPTPlot class]]]
                                                   forKey:@"CPTLegend.plots"];
        if ( plotArray ) {
            plots = [plotArray mutableCopy];
        }
        else {
            plots = [[NSMutableArray alloc] init];
        }

        NSArray *entries = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [CPTLegendEntry class]]]
                                                 forKey:@"CPTLegend.legendEntries"];
        if ( entries ) {
            legendEntries = [entries mutableCopy];
        }
        else {
            legendEntries = [[NSMutableArray alloc] init];
        }

        layoutChanged = [coder decodeBoolForKey:@"CPTLegend.layoutChanged"];
        textStyle     = [[coder decodeObjectOfClass:[CPTTextStyle class]
                                             forKey:@"CPTLegend.textStyle"] copy];
        swatchSize            = [coder decodeCPTSizeForKey:@"CPTLegend.swatchSize"];
        swatchBorderLineStyle = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                                     forKey:@"CPTLegend.swatchBorderLineStyle"] copy];
        swatchCornerRadius = [coder decodeCGFloatForKey:@"CPTLegend.swatchCornerRadius"];
        swatchFill         = [[coder decodeObjectOfClass:[CPTFill class]
                                                  forKey:@"CPTLegend.swatchFill"] copy];
        entryBorderLineStyle = [[coder decodeObjectOfClass:[CPTLineStyle class]
                                                    forKey:@"CPTLegend.entryBorderLineStyle"] copy];
        entryCornerRadius = [coder decodeCGFloatForKey:@"CPTLegend.entryCornerRadius"];
        entryFill         = [[coder decodeObjectOfClass:[CPTFill class]
                                                 forKey:@"CPTLegend.entryFill"] copy];
        entryPaddingLeft   = [coder decodeCGFloatForKey:@"CPTLegend.entryPaddingLeft"];
        entryPaddingTop    = [coder decodeCGFloatForKey:@"CPTLegend.entryPaddingTop"];
        entryPaddingRight  = [coder decodeCGFloatForKey:@"CPTLegend.entryPaddingRight"];
        entryPaddingBottom = [coder decodeCGFloatForKey:@"CPTLegend.entryPaddingBottom"];
        numberOfRows       = (NSUInteger)[coder decodeIntegerForKey:@"CPTLegend.numberOfRows"];
        numberOfColumns    = (NSUInteger)[coder decodeIntegerForKey:@"CPTLegend.numberOfColumns"];
        equalRows          = [coder decodeBoolForKey:@"CPTLegend.equalRows"];
        equalColumns       = [coder decodeBoolForKey:@"CPTLegend.equalColumns"];
        rowHeights         = [[coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSNumber class]]]
                                                    forKey:@"CPTLegend.rowHeights"] copy];
        rowHeightsThatFit = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSNumber class]]]
                                                  forKey:@"CPTLegend.rowHeightsThatFit"];
        columnWidths = [[coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSNumber class]]]
                                              forKey:@"CPTLegend.columnWidths"] copy];
        columnWidthsThatFit = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSNumber class]]]
                                                    forKey:@"CPTLegend.columnWidthsThatFit"];
        columnMargin = [coder decodeCGFloatForKey:@"CPTLegend.columnMargin"];
        rowMargin    = [coder decodeCGFloatForKey:@"CPTLegend.rowMargin"];
        titleOffset  = [coder decodeCGFloatForKey:@"CPTLegend.titleOffset"];
        swatchLayout = (CPTLegendSwatchLayout)[coder decodeIntegerForKey:@"CPTLegend.swatchLayout"];

        pointingDeviceDownEntry = nil;
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
#pragma mark Drawing

/// @cond

-(void)renderAsVectorInContext:(nonnull CGContextRef)context
{
    if ( self.hidden ) {
        return;
    }

    [super renderAsVectorInContext:context];

    if ( self.legendEntries.count == 0 ) {
        return;
    }

    BOOL isHorizontalLayout;

    switch ( self.swatchLayout ) {
        case CPTLegendSwatchLayoutLeft:
        case CPTLegendSwatchLayoutRight:
            isHorizontalLayout = YES;
            break;

        case CPTLegendSwatchLayoutTop:
        case CPTLegendSwatchLayoutBottom:
            isHorizontalLayout = NO;
            break;
    }

    // calculate column positions
    CPTNumberArray *computedColumnWidths = self.columnWidthsThatFit;
    NSUInteger columnCount               = computedColumnWidths.count;
    CGFloat *actualColumnWidths          = calloc(columnCount, sizeof(CGFloat));
    CGFloat *columnPositions             = calloc(columnCount, sizeof(CGFloat));
    columnPositions[0] = self.paddingLeft;
    CGFloat theOffset       = self.titleOffset;
    CGSize theSwatchSize    = self.swatchSize;
    CGFloat theColumnMargin = self.columnMargin;

    CGFloat padLeft   = self.entryPaddingLeft;
    CGFloat padTop    = self.entryPaddingTop;
    CGFloat padRight  = self.entryPaddingRight;
    CGFloat padBottom = self.entryPaddingBottom;

    for ( NSUInteger col = 0; col < columnCount; col++ ) {
        NSNumber *colWidth = computedColumnWidths[col];
        CGFloat width      = [colWidth cgFloatValue];
        actualColumnWidths[col] = width;
        if ( col < columnCount - 1 ) {
            columnPositions[col + 1] = columnPositions[col] + padLeft + width + padRight + (isHorizontalLayout ? theOffset + theSwatchSize.width : CPTFloat(0.0)) + theColumnMargin;
        }
    }

    // calculate row positions
    CPTNumberArray *computedRowHeights = self.rowHeightsThatFit;
    NSUInteger rowCount                = computedRowHeights.count;
    CGFloat *actualRowHeights          = calloc(rowCount, sizeof(CGFloat));
    CGFloat *rowPositions              = calloc(rowCount, sizeof(CGFloat));
    rowPositions[rowCount - 1] = self.paddingBottom;
    CGFloat theRowMargin  = self.rowMargin;
    CGFloat lastRowHeight = 0.0;

    for ( NSUInteger rw = 0; rw < rowCount; rw++ ) {
        NSUInteger row      = rowCount - rw - 1;
        NSNumber *rowHeight = computedRowHeights[row];
        CGFloat height      = [rowHeight cgFloatValue];
        actualRowHeights[row] = height;
        if ( row < rowCount - 1 ) {
            rowPositions[row] = rowPositions[row + 1] + padBottom + lastRowHeight + padTop + (isHorizontalLayout ? CPTFloat(0.0) : theOffset + theSwatchSize.height) + theRowMargin;
        }
        lastRowHeight = height;
    }

    // draw legend entries
    NSUInteger desiredRowCount    = self.numberOfRows;
    NSUInteger desiredColumnCount = self.numberOfColumns;

    CPTFill *theEntryFill           = self.entryFill;
    CPTLineStyle *theEntryLineStyle = self.entryBorderLineStyle;
    CGFloat entryRadius             = self.entryCornerRadius;

    id<CPTLegendDelegate> theDelegate = (id<CPTLegendDelegate>)self.delegate;
    BOOL delegateCanDraw              = [theDelegate respondsToSelector:@selector(legend:shouldDrawSwatchAtIndex:forPlot:inRect:inContext:)];
    BOOL delegateProvidesFills        = [theDelegate respondsToSelector:@selector(legend:fillForEntryAtIndex:forPlot:)];
    BOOL delegateProvidesLines        = [theDelegate respondsToSelector:@selector(legend:lineStyleForEntryAtIndex:forPlot:)];

    for ( CPTLegendEntry *legendEntry in self.legendEntries ) {
        NSUInteger row = legendEntry.row;
        NSUInteger col = legendEntry.column;

        if (((desiredRowCount == 0) || (row < desiredRowCount)) &&
            ((desiredColumnCount == 0) || (col < desiredColumnCount))) {
            NSUInteger entryIndex = legendEntry.index;
            CPTPlot *entryPlot    = legendEntry.plot;

            CGFloat left        = columnPositions[col];
            CGFloat rowPosition = rowPositions[row];

            CGRect entryRect;

            if ( isHorizontalLayout ) {
                entryRect = CPTRectMake(left,
                                        rowPosition,
                                        padLeft + theSwatchSize.width + theOffset + actualColumnWidths[col] + CPTFloat(1.0) + padRight,
                                        padBottom + actualRowHeights[row] + padTop);
            }
            else {
                entryRect = CPTRectMake(left,
                                        rowPosition,
                                        padLeft + MAX(theSwatchSize.width, actualColumnWidths[col]) + CPTFloat(1.0) + padRight,
                                        padBottom + theSwatchSize.height + theOffset + actualRowHeights[row] + padTop);
            }

            // draw background
            CPTFill *theFill = nil;
            if ( delegateProvidesFills ) {
                theFill = [theDelegate legend:self fillForEntryAtIndex:entryIndex forPlot:entryPlot];
            }
            if ( !theFill ) {
                theFill = theEntryFill;
            }
            if ( theFill ) {
                CGContextBeginPath(context);
                CPTAddRoundedRectPath(context, CPTAlignIntegralRectToUserSpace(context, entryRect), entryRadius);
                [theFill fillPathInContext:context];
            }

            CPTLineStyle *theLineStyle = nil;
            if ( delegateProvidesLines ) {
                theLineStyle = [theDelegate legend:self lineStyleForEntryAtIndex:entryIndex forPlot:entryPlot];
            }
            if ( !theLineStyle ) {
                theLineStyle = theEntryLineStyle;
            }
            if ( theLineStyle ) {
                [theLineStyle setLineStyleInContext:context];
                CGContextBeginPath(context);
                CPTAddRoundedRectPath(context, CPTAlignBorderedRectToUserSpace(context, entryRect, theLineStyle), entryRadius);
                [theLineStyle strokePathInContext:context];
            }

            // lay out swatch and title
            CGFloat swatchLeft, swatchBottom;
            CGFloat titleLeft, titleBottom;

            switch ( self.swatchLayout ) {
                case CPTLegendSwatchLayoutLeft:
                    swatchLeft   = CGRectGetMinX(entryRect) + padLeft;
                    swatchBottom = CGRectGetMinY(entryRect) + (entryRect.size.height - theSwatchSize.height) * CPTFloat(0.5);

                    titleLeft   = swatchLeft + theSwatchSize.width + theOffset;
                    titleBottom = CGRectGetMinY(entryRect) + padBottom;
                    break;

                case CPTLegendSwatchLayoutRight:
                    swatchLeft   = CGRectGetMaxX(entryRect) - padRight - theSwatchSize.width;
                    swatchBottom = CGRectGetMinY(entryRect) + (entryRect.size.height - theSwatchSize.height) * CPTFloat(0.5);

                    titleLeft   = CGRectGetMinX(entryRect) + padLeft;
                    titleBottom = CGRectGetMinY(entryRect) + padBottom;
                    break;

                case CPTLegendSwatchLayoutTop:
                    swatchLeft   = CGRectGetMidX(entryRect) - theSwatchSize.width * CPTFloat(0.5);
                    swatchBottom = CGRectGetMaxY(entryRect) - padTop - theSwatchSize.height;

                    titleLeft   = CGRectGetMidX(entryRect) - actualColumnWidths[col] * CPTFloat(0.5);
                    titleBottom = CGRectGetMinY(entryRect) + padBottom;
                    break;

                case CPTLegendSwatchLayoutBottom:
                    swatchLeft   = CGRectGetMidX(entryRect) - theSwatchSize.width * CPTFloat(0.5);
                    swatchBottom = CGRectGetMinY(entryRect) + padBottom;

                    titleLeft   = CGRectGetMidX(entryRect) - actualColumnWidths[col] * CPTFloat(0.5);
                    titleBottom = swatchBottom + theOffset + theSwatchSize.height;
                    break;
            }

            // draw swatch
            CGRect swatchRect = CPTRectMake(swatchLeft,
                                            swatchBottom,
                                            theSwatchSize.width,
                                            theSwatchSize.height);

            BOOL legendShouldDrawSwatch = YES;
            if ( delegateCanDraw ) {
                legendShouldDrawSwatch = [theDelegate legend:self
                                     shouldDrawSwatchAtIndex:entryIndex
                                                     forPlot:entryPlot
                                                      inRect:swatchRect
                                                   inContext:context];
            }
            if ( legendShouldDrawSwatch ) {
                [entryPlot drawSwatchForLegend:self
                                       atIndex:entryIndex
                                        inRect:swatchRect
                                     inContext:context];
            }

            // draw title
            CGRect titleRect = CPTRectMake(titleLeft,
                                           titleBottom,
                                           actualColumnWidths[col] + CPTFloat(1.0),
                                           actualRowHeights[row]);

            [legendEntry drawTitleInRect:CPTAlignRectToUserSpace(context, titleRect)
                               inContext:context
                                   scale:self.contentsScale];
        }
    }

    free(actualColumnWidths);
    free(columnPositions);
    free(actualRowHeights);
    free(rowPositions);
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
        keys = [NSSet setWithArray:@[@"swatchSize",
                                     @"swatchCornerRadius"]];
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
#pragma mark Layout

/**
 *  @brief Marks the receiver as needing to update the layout of its legend entries.
 **/
-(void)setLayoutChanged
{
    self.layoutChanged = YES;
}

/// @cond

-(void)layoutSublayers
{
    [self recalculateLayout];
    [super layoutSublayers];
}

-(void)recalculateLayout
{
    if ( !self.layoutChanged ) {
        return;
    }

    BOOL isHorizontalLayout;

    switch ( self.swatchLayout ) {
        case CPTLegendSwatchLayoutLeft:
        case CPTLegendSwatchLayoutRight:
            isHorizontalLayout = YES;
            break;

        case CPTLegendSwatchLayoutTop:
        case CPTLegendSwatchLayoutBottom:
            isHorizontalLayout = NO;
            break;
    }

    // compute the number of rows and columns needed to hold the legend entries
    NSUInteger rowCount           = self.numberOfRows;
    NSUInteger columnCount        = self.numberOfColumns;
    NSUInteger desiredRowCount    = rowCount;
    NSUInteger desiredColumnCount = columnCount;

    NSUInteger legendEntryCount = self.legendEntries.count;
    if ((rowCount == 0) && (columnCount == 0)) {
        rowCount    = (NSUInteger)lrint(sqrt((double)legendEntryCount));
        columnCount = rowCount;
        if ( rowCount * columnCount < legendEntryCount ) {
            columnCount++;
        }
        if ( rowCount * columnCount < legendEntryCount ) {
            rowCount++;
        }
    }
    else if ((rowCount == 0) && (columnCount > 0)) {
        rowCount = legendEntryCount / columnCount;
        if ( legendEntryCount % columnCount ) {
            rowCount++;
        }
    }
    else if ((rowCount > 0) && (columnCount == 0)) {
        columnCount = legendEntryCount / rowCount;
        if ( legendEntryCount % rowCount ) {
            columnCount++;
        }
    }

    // compute row heights and column widths
    NSUInteger row                      = 0;
    NSUInteger col                      = 0;
    CGFloat *maxTitleHeight             = calloc(rowCount, sizeof(CGFloat));
    CGFloat *maxTitleWidth              = calloc(columnCount, sizeof(CGFloat));
    CGSize theSwatchSize                = self.swatchSize;
    CPTNumberArray *desiredRowHeights   = self.rowHeights;
    CPTNumberArray *desiredColumnWidths = self.columnWidths;
    Class numberClass                   = [NSNumber class];

    for ( CPTLegendEntry *legendEntry in self.legendEntries ) {
        legendEntry.row    = row;
        legendEntry.column = col;
        CGSize titleSize = legendEntry.titleSize;

        if ((desiredRowCount == 0) || (row < desiredRowCount)) {
            maxTitleHeight[row] = MAX(maxTitleHeight[row], titleSize.height);
            if ( isHorizontalLayout ) {
                maxTitleHeight[row] = MAX(maxTitleHeight[row], theSwatchSize.height);
            }

            if ( row < desiredRowHeights.count ) {
                id desiredRowHeight = desiredRowHeights[row];
                if ( [desiredRowHeight isKindOfClass:numberClass] ) {
                    maxTitleHeight[row] = MAX(maxTitleHeight[row], [(NSNumber *) desiredRowHeight cgFloatValue]);
                }
            }
        }

        if ((desiredColumnCount == 0) || (col < desiredColumnCount)) {
            maxTitleWidth[col] = MAX(maxTitleWidth[col], titleSize.width);
            if ( !isHorizontalLayout ) {
                maxTitleWidth[col] = MAX(maxTitleWidth[col], theSwatchSize.width);
            }

            if ( col < desiredColumnWidths.count ) {
                id desiredColumnWidth = desiredColumnWidths[col];
                if ( [desiredColumnWidth isKindOfClass:numberClass] ) {
                    maxTitleWidth[col] = MAX(maxTitleWidth[col], [(NSNumber *) desiredColumnWidth cgFloatValue]);
                }
            }
        }

        col++;
        if ( col >= columnCount ) {
            row++;
            col = 0;
            if ( row >= rowCount ) {
                break;
            }
        }
    }

    // save row heights and column widths
    CPTMutableNumberArray *maxRowHeights = [[NSMutableArray alloc] initWithCapacity:rowCount];
    for ( NSUInteger i = 0; i < rowCount; i++ ) {
        [maxRowHeights addObject:@(maxTitleHeight[i])];
    }
    self.rowHeightsThatFit = maxRowHeights;

    CPTMutableNumberArray *maxColumnWidths = [[NSMutableArray alloc] initWithCapacity:columnCount];
    for ( NSUInteger i = 0; i < columnCount; i++ ) {
        [maxColumnWidths addObject:@(maxTitleWidth[i])];
    }
    self.columnWidthsThatFit = maxColumnWidths;

    free(maxTitleHeight);
    free(maxTitleWidth);

    // compute the size needed to contain all legend entries, margins, and padding
    CGSize legendSize = CPTSizeMake(self.paddingLeft + self.paddingRight, self.paddingTop + self.paddingBottom);

    CGFloat lineWidth = self.borderLineStyle.lineWidth;
    legendSize.width  += lineWidth;
    legendSize.height += lineWidth;

    if ( self.equalColumns ) {
        NSNumber *maxWidth = [maxColumnWidths valueForKeyPath:@"@max.doubleValue"];
        legendSize.width += [maxWidth cgFloatValue] * columnCount;
    }
    else {
        for ( NSNumber *width in maxColumnWidths ) {
            legendSize.width += [width cgFloatValue];
        }
    }
    if ( columnCount > 0 ) {
        legendSize.width += ((self.entryPaddingLeft + self.entryPaddingRight) * columnCount) + (self.columnMargin * (columnCount - 1));
        if ( isHorizontalLayout ) {
            legendSize.width += (theSwatchSize.width + self.titleOffset) * columnCount;
        }
    }

    NSUInteger rows = row;
    if ( col ) {
        rows++;
    }
    for ( NSNumber *height in maxRowHeights ) {
        legendSize.height += [height cgFloatValue];
    }
    if ( rows > 0 ) {
        legendSize.height += ((self.entryPaddingBottom + self.entryPaddingTop) * rowCount) + (self.rowMargin * (rows - 1));
        if ( !isHorizontalLayout ) {
            legendSize.height += (theSwatchSize.height + self.titleOffset) * rowCount;
        }
    }

    self.bounds = CPTRectMake(0.0, 0.0, ceil(legendSize.width), ceil(legendSize.height));
    [self pixelAlign];

    self.layoutChanged = NO;
}

/// @endcond

#pragma mark -
#pragma mark Plots

/** @brief All plots associated with the legend.
 *  @return An array of all plots associated with the legend.
 **/
-(nonnull CPTPlotArray *)allPlots
{
    return [NSArray arrayWithArray:self.plots];
}

/** @brief Gets the plot at the given index in the plot array.
 *  @param idx An index within the bounds of the plot array.
 *  @return The plot at the given index.
 **/
-(nullable CPTPlot *)plotAtIndex:(NSUInteger)idx
{
    if ( idx < self.plots.count ) {
        return (self.plots)[idx];
    }
    else {
        return nil;
    }
}

/** @brief Gets the plot with the given identifier from the plot array.
 *  @param identifier A plot identifier.
 *  @return The plot with the given identifier or nil if it was not found.
 **/
-(nullable CPTPlot *)plotWithIdentifier:(nullable id<NSCopying>)identifier
{
    for ( CPTPlot *plot in self.plots ) {
        if ( [plot.identifier isEqual:identifier] ) {
            return plot;
        }
    }
    return nil;
}

#pragma mark -
#pragma mark Organizing Plots

/** @brief Add a plot to the legend.
 *  @param plot The plot.
 **/
-(void)addPlot:(nonnull CPTPlot *)plot
{
    if ( [plot isKindOfClass:[CPTPlot class]] ) {
        [self.plots addObject:plot];
        self.layoutChanged = YES;

        CPTMutableLegendEntryArray *theLegendEntries = self.legendEntries;
        CPTTextStyle *theTextStyle                   = self.textStyle;
        NSUInteger numberOfLegendEntries             = [plot numberOfLegendEntries];
        for ( NSUInteger i = 0; i < numberOfLegendEntries; i++ ) {
            NSString *newTitle = [plot titleForLegendEntryAtIndex:i];
            if ( newTitle ) {
                CPTLegendEntry *newLegendEntry = [[CPTLegendEntry alloc] init];
                newLegendEntry.plot      = plot;
                newLegendEntry.index     = i;
                newLegendEntry.textStyle = theTextStyle;
                [theLegendEntries addObject:newLegendEntry];
            }
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(legendNeedsRedraw:) name:CPTLegendNeedsRedrawForPlotNotification object:plot];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(legendNeedsLayout:) name:CPTLegendNeedsLayoutForPlotNotification object:plot];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(legendNeedsReloadEntries:) name:CPTLegendNeedsReloadEntriesForPlotNotification object:plot];
    }
}

/** @brief Add a plot to the legend at the given index in the plot array.
 *  @param plot The plot.
 *  @param idx An index within the bounds of the plot array.
 **/
-(void)insertPlot:(nonnull CPTPlot *)plot atIndex:(NSUInteger)idx
{
    if ( [plot isKindOfClass:[CPTPlot class]] ) {
        CPTMutablePlotArray *thePlots = self.plots;
        NSAssert(idx <= thePlots.count, @"index greater than the number of plots");

        CPTMutableLegendEntryArray *theLegendEntries = self.legendEntries;
        NSUInteger legendEntryIndex                  = 0;
        if ( idx == thePlots.count ) {
            legendEntryIndex = theLegendEntries.count;
        }
        else {
            CPTPlot *lastPlot = thePlots[idx];
            for ( CPTLegendEntry *legendEntry in theLegendEntries ) {
                if ( legendEntry.plot == lastPlot ) {
                    break;
                }
                legendEntryIndex++;
            }
        }

        [thePlots insertObject:plot atIndex:idx];
        self.layoutChanged = YES;

        CPTTextStyle *theTextStyle       = self.textStyle;
        NSUInteger numberOfLegendEntries = [plot numberOfLegendEntries];
        for ( NSUInteger i = 0; i < numberOfLegendEntries; i++ ) {
            NSString *newTitle = [plot titleForLegendEntryAtIndex:i];
            if ( newTitle ) {
                CPTLegendEntry *newLegendEntry = [[CPTLegendEntry alloc] init];
                newLegendEntry.plot      = plot;
                newLegendEntry.index     = i;
                newLegendEntry.textStyle = theTextStyle;
                [theLegendEntries insertObject:newLegendEntry atIndex:legendEntryIndex++];
            }
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(legendNeedsRedraw:) name:CPTLegendNeedsRedrawForPlotNotification object:plot];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(legendNeedsLayout:) name:CPTLegendNeedsLayoutForPlotNotification object:plot];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(legendNeedsReloadEntries:) name:CPTLegendNeedsReloadEntriesForPlotNotification object:plot];
    }
}

/** @brief Remove a plot from the legend.
 *  @param plot The plot to remove.
 **/
-(void)removePlot:(nonnull CPTPlot *)plot
{
    if ( [self.plots containsObject:plot] ) {
        [self.plots removeObjectIdenticalTo:plot];
        [self removeLegendEntriesForPlot:plot];
        self.layoutChanged = YES;
        [[NSNotificationCenter defaultCenter] removeObserver:self name:CPTLegendNeedsRedrawForPlotNotification object:plot];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:CPTLegendNeedsLayoutForPlotNotification object:plot];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:CPTLegendNeedsReloadEntriesForPlotNotification object:plot];
    }
    else {
        [NSException raise:CPTException format:@"Tried to remove CPTPlot which did not exist."];
    }
}

/** @brief Remove a plot from the legend.
 *  @param identifier The identifier of the plot to remove.
 **/
-(void)removePlotWithIdentifier:(nullable id<NSCopying>)identifier
{
    CPTPlot *plotToRemove = [self plotWithIdentifier:identifier];

    if ( plotToRemove ) {
        [self.plots removeObjectIdenticalTo:plotToRemove];
        [self removeLegendEntriesForPlot:plotToRemove];
        self.layoutChanged = YES;
        [[NSNotificationCenter defaultCenter] removeObserver:self name:CPTLegendNeedsRedrawForPlotNotification object:plotToRemove];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:CPTLegendNeedsLayoutForPlotNotification object:plotToRemove];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:CPTLegendNeedsReloadEntriesForPlotNotification object:plotToRemove];
    }
}

/// @cond

/** @internal
 *  @brief Remove all legend entries for the given plot from the legend.
 *  @param plot The plot.
 **/
-(void)removeLegendEntriesForPlot:(nonnull CPTPlot *)plot
{
    CPTMutableLegendEntryArray *theLegendEntries = self.legendEntries;
    CPTMutableLegendEntryArray *entriesToRemove  = [[NSMutableArray alloc] init];

    for ( CPTLegendEntry *legendEntry in theLegendEntries ) {
        if ( legendEntry.plot == plot ) {
            [entriesToRemove addObject:legendEntry];
        }
    }
    [theLegendEntries removeObjectsInArray:entriesToRemove];
}

/// @endcond

#pragma mark -
#pragma mark Notifications

/// @cond

-(void)legendNeedsRedraw:(nonnull NSNotification *__unused)notif
{
    [self setNeedsDisplay];
}

-(void)legendNeedsLayout:(nonnull NSNotification *__unused)notif
{
    self.layoutChanged = YES;
    [self setNeedsDisplay];
}

-(void)legendNeedsReloadEntries:(nonnull NSNotification *)notif
{
    CPTPlot *thePlot = (CPTPlot *)notif.object;

    CPTMutableLegendEntryArray *theLegendEntries = self.legendEntries;

    NSUInteger legendEntryIndex = 0;

    for ( CPTLegendEntry *legendEntry in theLegendEntries ) {
        if ( legendEntry.plot == thePlot ) {
            break;
        }
        legendEntryIndex++;
    }

    [self removeLegendEntriesForPlot:thePlot];

    CPTTextStyle *theTextStyle       = self.textStyle;
    NSUInteger numberOfLegendEntries = [thePlot numberOfLegendEntries];
    for ( NSUInteger i = 0; i < numberOfLegendEntries; i++ ) {
        NSString *newTitle = [thePlot titleForLegendEntryAtIndex:i];
        if ( newTitle ) {
            CPTLegendEntry *newLegendEntry = [[CPTLegendEntry alloc] init];
            newLegendEntry.plot      = thePlot;
            newLegendEntry.index     = i;
            newLegendEntry.textStyle = theTextStyle;
            [theLegendEntries insertObject:newLegendEntry atIndex:legendEntryIndex++];
        }
    }
    self.layoutChanged = YES;
}

/// @endcond

#pragma mark -
#pragma mark Responder Chain and User interaction

/// @cond

-(void)legendEntryForInteractionPoint:(CGPoint)interactionPoint row:(nonnull NSUInteger *)row col:(nonnull NSUInteger *)col
{
    // Convert the interaction point to the local coordinate system
    CPTGraph *theGraph = self.graph;

    if ( theGraph ) {
        interactionPoint = [self convertPoint:interactionPoint fromLayer:theGraph];
    }
    else {
        for ( CPTPlot *plot in self.plots ) {
            CPTGraph *plotGraph = plot.graph;

            if ( plotGraph ) {
                interactionPoint = [self convertPoint:interactionPoint fromLayer:plotGraph];
                break;
            }
        }
    }

    // Update layout if needed
    [self recalculateLayout];

    // Hit test the legend entries
    CGFloat rMargin = self.rowMargin;
    CGFloat cMargin = self.columnMargin;

    CGFloat swatchWidth = self.swatchSize.width + self.titleOffset;

    CGFloat padHorizontal = self.entryPaddingLeft + self.entryPaddingRight;
    CGFloat padVertical   = self.entryPaddingTop + self.entryPaddingBottom;

    // Rows
    CGFloat position = CGRectGetMaxY(self.bounds) - self.paddingTop;

    NSUInteger i = 0;

    for ( NSNumber *height in self.rowHeightsThatFit ) {
        CGFloat rowHeight = height.cgFloatValue + padVertical;
        if ((interactionPoint.y <= position) && (interactionPoint.y >= position - rowHeight)) {
            *row = i;
            break;
        }

        position -= rowHeight + rMargin;
        i++;
    }

    // Columns
    position = self.paddingLeft;

    i = 0;

    for ( NSNumber *width in self.columnWidthsThatFit ) {
        CGFloat colWidth = width.cgFloatValue + swatchWidth + padHorizontal;
        if ((interactionPoint.x >= position) && (interactionPoint.x <= position + colWidth)) {
            *col = i;
            break;
        }

        position += colWidth + cMargin;
        i++;
    }
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
 *  If this legend has a delegate that responds to the
 *  @link CPTLegendDelegate::legend:legendEntryForPlot:touchDownAtIndex: -legend:legendEntryForPlot:touchDownAtIndex: @endlink or
 *  @link CPTLegendDelegate::legend:legendEntryForPlot:touchDownAtIndex:withEvent: -legend:legendEntryForPlot:touchDownAtIndex:withEvent: @endlink
 *  methods, the legend entries are searched to find the plot and index of the one whose swatch or title contains the @par{interactionPoint}.
 *  The delegate method will be called and this method returns @YES if the @par{interactionPoint} is within a legend entry.
 *  This method returns @NO if the @par{interactionPoint} is too far away from all of the legend entries.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceDownEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    if ( self.hidden || (self.plots.count == 0)) {
        return NO;
    }

    id<CPTLegendDelegate> theDelegate = (id<CPTLegendDelegate>)self.delegate;
    if ( [theDelegate respondsToSelector:@selector(legend:legendEntryForPlot:touchDownAtIndex:)] ||
         [theDelegate respondsToSelector:@selector(legend:legendEntryForPlot:touchDownAtIndex:withEvent:)] ||
         [theDelegate respondsToSelector:@selector(legend:legendEntryForPlot:wasSelectedAtIndex:)] ||
         [theDelegate respondsToSelector:@selector(legend:legendEntryForPlot:wasSelectedAtIndex:withEvent:)] ) {
        NSUInteger row = NSNotFound;
        NSUInteger col = NSNotFound;
        [self legendEntryForInteractionPoint:interactionPoint row:&row col:&col];

        // Notify the delegate if we found a hit
        if ((row != NSNotFound) && (col != NSNotFound)) {
            for ( CPTLegendEntry *legendEntry in self.legendEntries ) {
                if ((legendEntry.row == row) && (legendEntry.column == col)) {
                    self.pointingDeviceDownEntry = legendEntry;

                    CPTPlot *legendPlot = legendEntry.plot;
                    BOOL handled        = NO;

                    if ( [theDelegate respondsToSelector:@selector(legend:legendEntryForPlot:touchDownAtIndex:)] ) {
                        handled = YES;
                        [theDelegate legend:self legendEntryForPlot:legendPlot touchDownAtIndex:legendEntry.index];
                    }
                    if ( [theDelegate respondsToSelector:@selector(legend:legendEntryForPlot:touchDownAtIndex:withEvent:)] ) {
                        handled = YES;
                        [theDelegate legend:self legendEntryForPlot:legendPlot touchDownAtIndex:legendEntry.index withEvent:event];
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
 *  If this legend has a delegate that responds to the
 *  @link CPTLegendDelegate::legend:legendEntryForPlot:touchUpAtIndex: -legend:legendEntryForPlot:touchUpAtIndex: @endlink or
 *  @link CPTLegendDelegate::legend:legendEntryForPlot:touchUpAtIndex:withEvent: -legend:legendEntryForPlot:touchUpAtIndex:withEvent: @endlink
 *  methods, the legend entries are searched to find the plot and index of the one whose swatch or title contains the @par{interactionPoint}.
 *  The delegate method will be called and this method returns @YES if the @par{interactionPoint} is within a legend entry.
 *  This method returns @NO if the @par{interactionPoint} is too far away from all of the legend entries.
 *
 *  If the bar being released is the same as the one that was pressed (see
 *  @link CPTLegend::pointingDeviceDownEvent:atPoint: -pointingDeviceDownEvent:atPoint: @endlink), if the delegate responds to the
 *  @link CPTLegendDelegate::legend:legendEntryForPlot:wasSelectedAtIndex: -legend:legendEntryForPlot:wasSelectedAtIndex: @endlink and/or
 *  @link CPTLegendDelegate::legend:legendEntryForPlot:wasSelectedAtIndex:withEvent: -legend:legendEntryForPlot:wasSelectedAtIndex:withEvent: @endlink
 *  methods, these will be called.
 *
 *  @param event The OS event.
 *  @param interactionPoint The coordinates of the interaction.
 *  @return Whether the event was handled or not.
 **/
-(BOOL)pointingDeviceUpEvent:(nonnull CPTNativeEvent *)event atPoint:(CGPoint)interactionPoint
{
    CPTLegendEntry *selectedDownEntry = self.pointingDeviceDownEntry;

    self.pointingDeviceDownEntry = nil;

    if ( self.hidden || (self.plots.count == 0)) {
        return NO;
    }

    id<CPTLegendDelegate> theDelegate = (id<CPTLegendDelegate>)self.delegate;
    if ( [theDelegate respondsToSelector:@selector(legend:legendEntryForPlot:touchUpAtIndex:)] ||
         [theDelegate respondsToSelector:@selector(legend:legendEntryForPlot:touchUpAtIndex:withEvent:)] ||
         [theDelegate respondsToSelector:@selector(legend:legendEntryForPlot:wasSelectedAtIndex:)] ||
         [theDelegate respondsToSelector:@selector(legend:legendEntryForPlot:wasSelectedAtIndex:withEvent:)] ) {
        NSUInteger row = NSNotFound;
        NSUInteger col = NSNotFound;
        [self legendEntryForInteractionPoint:interactionPoint row:&row col:&col];

        // Notify the delegate if we found a hit
        if ((row != NSNotFound) && (col != NSNotFound)) {
            for ( CPTLegendEntry *legendEntry in self.legendEntries ) {
                if ((legendEntry.row == row) && (legendEntry.column == col)) {
                    BOOL handled = NO;

                    CPTPlot *entryPlot = legendEntry.plot;

                    if ( [theDelegate respondsToSelector:@selector(legend:legendEntryForPlot:touchUpAtIndex:)] ) {
                        handled = YES;
                        [theDelegate legend:self legendEntryForPlot:entryPlot touchUpAtIndex:legendEntry.index];
                    }
                    if ( [theDelegate respondsToSelector:@selector(legend:legendEntryForPlot:touchUpAtIndex:withEvent:)] ) {
                        handled = YES;
                        [theDelegate legend:self legendEntryForPlot:entryPlot touchUpAtIndex:legendEntry.index withEvent:event];
                    }

                    if ( legendEntry == selectedDownEntry ) {
                        if ( [theDelegate respondsToSelector:@selector(legend:legendEntryForPlot:wasSelectedAtIndex:)] ) {
                            handled = YES;
                            [theDelegate legend:self legendEntryForPlot:entryPlot wasSelectedAtIndex:legendEntry.index];
                        }

                        if ( [theDelegate respondsToSelector:@selector(legend:legendEntryForPlot:wasSelectedAtIndex:withEvent:)] ) {
                            handled = YES;
                            [theDelegate legend:self legendEntryForPlot:entryPlot wasSelectedAtIndex:legendEntry.index withEvent:event];
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
#pragma mark Description

/// @cond

-(nullable NSString *)description
{
    return [NSString stringWithFormat:@"<%@ for plots %@>", super.description, self.plots];
}

/// @endcond

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setTextStyle:(nullable CPTTextStyle *)newTextStyle
{
    if ( newTextStyle != textStyle ) {
        textStyle = [newTextStyle copy];
        [self.legendEntries makeObjectsPerformSelector:@selector(setTextStyle:) withObject:textStyle];
        self.layoutChanged = YES;
    }
}

-(void)setSwatchSize:(CGSize)newSwatchSize
{
    if ( !CGSizeEqualToSize(newSwatchSize, swatchSize)) {
        swatchSize         = newSwatchSize;
        self.layoutChanged = YES;
    }
}

-(CGSize)swatchSize
{
    CGSize theSwatchSize = swatchSize;

    if ( CGSizeEqualToSize(theSwatchSize, CGSizeZero)) {
        CPTTextStyle *theTextStyle = self.textStyle;
        CGFloat fontSize           = theTextStyle.fontSize;
        if ( fontSize > CPTFloat(0.0)) {
            fontSize     *= CPTFloat(1.5);
            fontSize      = round(fontSize);
            theSwatchSize = CPTSizeMake(fontSize, fontSize);
        }
        else {
            theSwatchSize = CPTSizeMake(15.0, 15.0);
        }
    }
    return theSwatchSize;
}

-(void)setSwatchBorderLineStyle:(nullable CPTLineStyle *)newSwatchBorderLineStyle
{
    if ( newSwatchBorderLineStyle != swatchBorderLineStyle ) {
        swatchBorderLineStyle = [newSwatchBorderLineStyle copy];
        [self setNeedsDisplay];
    }
}

-(void)setSwatchCornerRadius:(CGFloat)newSwatchCornerRadius
{
    if ( newSwatchCornerRadius != swatchCornerRadius ) {
        swatchCornerRadius = newSwatchCornerRadius;
        [self setNeedsDisplay];
    }
}

-(void)setSwatchFill:(nullable CPTFill *)newSwatchFill
{
    if ( newSwatchFill != swatchFill ) {
        swatchFill = [newSwatchFill copy];
        [self setNeedsDisplay];
    }
}

-(void)setEntryBorderLineStyle:(nullable CPTLineStyle *)newEntryBorderLineStyle
{
    if ( newEntryBorderLineStyle != entryBorderLineStyle ) {
        entryBorderLineStyle = [newEntryBorderLineStyle copy];
        [self setNeedsDisplay];
    }
}

-(void)setEntryCornerRadius:(CGFloat)newEntryCornerRadius
{
    if ( newEntryCornerRadius != entryCornerRadius ) {
        entryCornerRadius = newEntryCornerRadius;
        [self setNeedsDisplay];
    }
}

-(void)setEntryFill:(nullable CPTFill *)newEntryFill
{
    if ( newEntryFill != entryFill ) {
        entryFill = [newEntryFill copy];
        [self setNeedsDisplay];
    }
}

-(void)setEntryPaddingLeft:(CGFloat)newPadding
{
    if ( newPadding != entryPaddingLeft ) {
        entryPaddingLeft   = newPadding;
        self.layoutChanged = YES;
    }
}

-(void)setEntryPaddingTop:(CGFloat)newPadding
{
    if ( newPadding != entryPaddingTop ) {
        entryPaddingTop    = newPadding;
        self.layoutChanged = YES;
    }
}

-(void)setEntryPaddingRight:(CGFloat)newPadding
{
    if ( newPadding != entryPaddingRight ) {
        entryPaddingRight  = newPadding;
        self.layoutChanged = YES;
    }
}

-(void)setEntryPaddingBottom:(CGFloat)newPadding
{
    if ( newPadding != entryPaddingBottom ) {
        entryPaddingBottom = newPadding;
        self.layoutChanged = YES;
    }
}

-(void)setNumberOfRows:(NSUInteger)newNumberOfRows
{
    if ( newNumberOfRows != numberOfRows ) {
        numberOfRows       = newNumberOfRows;
        self.layoutChanged = YES;
    }
}

-(void)setNumberOfColumns:(NSUInteger)newNumberOfColumns
{
    if ( newNumberOfColumns != numberOfColumns ) {
        numberOfColumns    = newNumberOfColumns;
        self.layoutChanged = YES;
    }
}

-(void)setEqualRows:(BOOL)newEqualRows
{
    if ( newEqualRows != equalRows ) {
        equalRows          = newEqualRows;
        self.layoutChanged = YES;
    }
}

-(void)setEqualColumns:(BOOL)newEqualColumns
{
    if ( newEqualColumns != equalColumns ) {
        equalColumns       = newEqualColumns;
        self.layoutChanged = YES;
    }
}

-(void)setRowHeights:(nullable CPTNumberArray *)newRowHeights
{
    if ( newRowHeights != rowHeights ) {
        rowHeights         = [newRowHeights copy];
        self.layoutChanged = YES;
    }
}

-(void)setColumnWidths:(nullable CPTNumberArray *)newColumnWidths
{
    if ( newColumnWidths != columnWidths ) {
        columnWidths       = [newColumnWidths copy];
        self.layoutChanged = YES;
    }
}

-(void)setColumnMargin:(CGFloat)newColumnMargin
{
    if ( newColumnMargin != columnMargin ) {
        columnMargin       = newColumnMargin;
        self.layoutChanged = YES;
    }
}

-(void)setRowMargin:(CGFloat)newRowMargin
{
    if ( newRowMargin != rowMargin ) {
        rowMargin          = newRowMargin;
        self.layoutChanged = YES;
    }
}

-(void)setTitleOffset:(CGFloat)newTitleOffset
{
    if ( newTitleOffset != titleOffset ) {
        titleOffset        = newTitleOffset;
        self.layoutChanged = YES;
    }
}

-(void)setSwatchLayout:(CPTLegendSwatchLayout)newSwatchLayout
{
    if ( newSwatchLayout != swatchLayout ) {
        swatchLayout       = newSwatchLayout;
        self.layoutChanged = YES;
    }
}

-(void)setLayoutChanged:(BOOL)newLayoutChanged
{
    if ( newLayoutChanged != layoutChanged ) {
        layoutChanged = newLayoutChanged;
        if ( newLayoutChanged ) {
            self.rowHeightsThatFit   = nil;
            self.columnWidthsThatFit = nil;
            [self setNeedsLayout];
        }
    }
}

-(void)setPaddingLeft:(CGFloat)newPadding
{
    if ( newPadding != self.paddingLeft ) {
        super.paddingLeft  = newPadding;
        self.layoutChanged = YES;
    }
}

-(void)setPaddingTop:(CGFloat)newPadding
{
    if ( newPadding != self.paddingTop ) {
        super.paddingTop   = newPadding;
        self.layoutChanged = YES;
    }
}

-(void)setPaddingRight:(CGFloat)newPadding
{
    if ( newPadding != self.paddingRight ) {
        super.paddingRight = newPadding;
        self.layoutChanged = YES;
    }
}

-(void)setPaddingBottom:(CGFloat)newPadding
{
    if ( newPadding != self.paddingBottom ) {
        super.paddingBottom = newPadding;
        self.layoutChanged  = YES;
    }
}

-(void)setBorderLineStyle:(nullable CPTLineStyle *)newLineStyle
{
    CPTLineStyle *oldLineStyle = self.borderLineStyle;

    if ( newLineStyle != oldLineStyle ) {
        super.borderLineStyle = newLineStyle;

        if ( newLineStyle.lineWidth != oldLineStyle.lineWidth ) {
            self.layoutChanged = YES;
        }
    }
}

-(nullable CPTNumberArray *)rowHeightsThatFit
{
    if ( !rowHeightsThatFit ) {
        [self recalculateLayout];
    }
    return rowHeightsThatFit;
}

-(nullable CPTNumberArray *)columnWidthsThatFit
{
    if ( !columnWidthsThatFit ) {
        [self recalculateLayout];
    }
    return columnWidthsThatFit;
}

/// @endcond

@end

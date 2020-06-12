#import "CPTBorderedLayer.h"
#import "CPTPlot.h"

/// @file

@class CPTFill;
@class CPTLegend;
@class CPTLineStyle;
@class CPTTextStyle;

/**
 *  @brief Graph notification type.
 **/
typedef NSString *CPTLegendNotification cpt_swift_struct;

/// @name Legend
/// @{

/** @brief Notification sent by plots to tell the legend it should redraw itself.
 *  @ingroup notification
 **/
extern CPTLegendNotification __nonnull const CPTLegendNeedsRedrawForPlotNotification NS_SWIFT_NAME(needsRedrawForPlot);

/** @brief Notification sent by plots to tell the legend it should update its layout and redraw itself.
 *  @ingroup notification
 **/
extern CPTLegendNotification __nonnull const CPTLegendNeedsLayoutForPlotNotification NS_SWIFT_NAME(needsLayoutForPlot);

/** @brief Notification sent by plots to tell the legend it should reload all legend entries.
 *  @ingroup notification
 **/
extern CPTLegendNotification __nonnull const CPTLegendNeedsReloadEntriesForPlotNotification NS_SWIFT_NAME(needsReloadEntriesForPlot);

/// @}

/**
 *  @brief Enumeration of legend layout options.
 **/
typedef NS_ENUM (NSInteger, CPTLegendSwatchLayout) {
    CPTLegendSwatchLayoutLeft,  ///< Lay out the swatch to the left side of the title.
    CPTLegendSwatchLayoutRight, ///< Lay out the swatch to the right side of the title.
    CPTLegendSwatchLayoutTop,   ///< Lay out the swatch above the title.
    CPTLegendSwatchLayoutBottom ///< Lay out the swatch below the title.
};

#pragma mark -

/**
 *  @brief Legend delegate.
 **/
@protocol CPTLegendDelegate<CPTLayerDelegate>

@optional

/// @name Drawing
/// @{

/** @brief @optional This method gives the delegate a chance to provide a background fill for each legend entry.
 *  @param legend The legend.
 *  @param idx The zero-based index of the legend entry for the given plot.
 *  @param plot The plot.
 *  @return The fill for the legend entry background or @nil to use the default @link CPTLegend::entryFill entryFill @endlink .
 **/
-(nullable CPTFill *)legend:(nonnull CPTLegend *)legend fillForEntryAtIndex:(NSUInteger)idx forPlot:(nonnull CPTPlot *)plot;

/** @brief @optional This method gives the delegate a chance to provide a border line style for each legend entry.
 *  @param legend The legend.
 *  @param idx The zero-based index of the legend entry for the given plot.
 *  @param plot The plot.
 *  @return The line style for the legend entry border or @nil to use the default @link CPTLegend::entryBorderLineStyle entryBorderLineStyle @endlink .
 **/
-(nullable CPTLineStyle *)legend:(nonnull CPTLegend *)legend lineStyleForEntryAtIndex:(NSUInteger)idx forPlot:(nonnull CPTPlot *)plot;

/** @brief @optional This method gives the delegate a chance to provide a custom swatch fill for each legend entry.
 *  @param legend The legend.
 *  @param idx The zero-based index of the legend entry for the given plot.
 *  @param plot The plot.
 *  @return The fill for the legend swatch or @nil to use the default @link CPTLegend::swatchFill swatchFill @endlink .
 **/
-(nullable CPTFill *)legend:(nonnull CPTLegend *)legend fillForSwatchAtIndex:(NSUInteger)idx forPlot:(nonnull CPTPlot *)plot;

/** @brief @optional This method gives the delegate a chance to provide a custom swatch border line style for each legend entry.
 *  @param legend The legend.
 *  @param idx The zero-based index of the legend entry for the given plot.
 *  @param plot The plot.
 *  @return The line style for the legend swatch border or @nil to use the default @link CPTLegend::swatchBorderLineStyle swatchBorderLineStyle @endlink .
 **/
-(nullable CPTLineStyle *)legend:(nonnull CPTLegend *)legend lineStyleForSwatchAtIndex:(NSUInteger)idx forPlot:(nonnull CPTPlot *)plot;

/** @brief @optional This method gives the delegate a chance to draw custom swatches for each legend entry.
 *
 *  The "swatch" is the graphical part of the legend entry, usually accompanied by a text title
 *  that will be drawn by the legend. Returning @NO will cause the legend to not draw the default
 *  legend graphics. It is then the delegate&rsquo;s responsibility to do this.
 *  @param legend The legend.
 *  @param idx The zero-based index of the legend entry for the given plot.
 *  @param plot The plot.
 *  @param rect The bounding rectangle to use when drawing the swatch.
 *  @param context The graphics context to draw into.
 *  @return @YES if the legend should draw the default swatch or @NO if the delegate handled the drawing.
 **/
-(BOOL)legend:(nonnull CPTLegend *)legend shouldDrawSwatchAtIndex:(NSUInteger)idx forPlot:(nonnull CPTPlot *)plot inRect:(CGRect)rect inContext:(nonnull CGContextRef)context;

/// @}

/// @name Legend Entry Selection
/// @{

/** @brief @optional Informs the delegate that the swatch or label of a legend entry
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param legend The legend.
 *  @param plot The plot associated with the selected legend entry.
 *  @param idx The index of the
 *  @if MacOnly clicked legend entry. @endif
 *  @if iOSOnly touched legend entry. @endif
 **/
-(void)legend:(nonnull CPTLegend *)legend legendEntryForPlot:(nonnull CPTPlot *)plot wasSelectedAtIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that the swatch or label of a legend entry
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param legend The legend.
 *  @param plot The plot associated with the selected legend entry.
 *  @param idx The index of the
 *  @if MacOnly clicked legend entry. @endif
 *  @if iOSOnly touched legend entry. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)legend:(nonnull CPTLegend *)legend legendEntryForPlot:(nonnull CPTPlot *)plot wasSelectedAtIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that the swatch or label of a legend entry
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param legend The legend.
 *  @param plot The plot associated with the selected legend entry.
 *  @param idx The index of the
 *  @if MacOnly clicked legend entry. @endif
 *  @if iOSOnly touched legend entry. @endif
 **/
-(void)legend:(nonnull CPTLegend *)legend legendEntryForPlot:(nonnull CPTPlot *)plot touchDownAtIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that the swatch or label of a legend entry
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param legend The legend.
 *  @param plot The plot associated with the selected legend entry.
 *  @param idx The index of the
 *  @if MacOnly clicked legend entry. @endif
 *  @if iOSOnly touched legend entry. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)legend:(nonnull CPTLegend *)legend legendEntryForPlot:(nonnull CPTPlot *)plot touchDownAtIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that the swatch or label of a legend entry
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param legend The legend.
 *  @param plot The plot associated with the selected legend entry.
 *  @param idx The index of the
 *  @if MacOnly clicked legend entry. @endif
 *  @if iOSOnly touched legend entry. @endif
 **/
-(void)legend:(nonnull CPTLegend *)legend legendEntryForPlot:(nonnull CPTPlot *)plot touchUpAtIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that the swatch or label of a legend entry
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param legend The legend.
 *  @param plot The plot associated with the selected legend entry.
 *  @param idx The index of the
 *  @if MacOnly clicked legend entry. @endif
 *  @if iOSOnly touched legend entry. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)legend:(nonnull CPTLegend *)legend legendEntryForPlot:(nonnull CPTPlot *)plot touchUpAtIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/// @}

@end

#pragma mark -

@interface CPTLegend : CPTBorderedLayer

/// @name Formatting
/// @{
@property (nonatomic, readwrite, copy, nullable) CPTTextStyle *textStyle;
@property (nonatomic, readwrite, assign) CGSize swatchSize;
@property (nonatomic, readwrite, copy, nullable) CPTLineStyle *swatchBorderLineStyle;
@property (nonatomic, readwrite, assign) CGFloat swatchCornerRadius;
@property (nonatomic, readwrite, copy, nullable) CPTFill *swatchFill;

@property (nonatomic, readwrite, copy, nullable) CPTLineStyle *entryBorderLineStyle;
@property (nonatomic, readwrite, assign) CGFloat entryCornerRadius;
@property (nonatomic, readwrite, copy, nullable) CPTFill *entryFill;
@property (nonatomic, readwrite, assign) CGFloat entryPaddingLeft;
@property (nonatomic, readwrite, assign) CGFloat entryPaddingTop;
@property (nonatomic, readwrite, assign) CGFloat entryPaddingRight;
@property (nonatomic, readwrite, assign) CGFloat entryPaddingBottom;
/// @}

/// @name Layout
/// @{
@property (nonatomic, readonly) BOOL layoutChanged;
@property (nonatomic, readwrite, assign) NSUInteger numberOfRows;
@property (nonatomic, readwrite, assign) NSUInteger numberOfColumns;
@property (nonatomic, readwrite, assign) BOOL equalRows;
@property (nonatomic, readwrite, assign) BOOL equalColumns;
@property (nonatomic, readwrite, copy, nullable) CPTNumberArray *rowHeights;
@property (nonatomic, readonly, nullable) CPTNumberArray *rowHeightsThatFit;
@property (nonatomic, readwrite, copy, nullable) CPTNumberArray *columnWidths;
@property (nonatomic, readonly, nullable) CPTNumberArray *columnWidthsThatFit;
@property (nonatomic, readwrite, assign) CGFloat columnMargin;
@property (nonatomic, readwrite, assign) CGFloat rowMargin;
@property (nonatomic, readwrite, assign) CGFloat titleOffset;
@property (nonatomic, readwrite, assign) CPTLegendSwatchLayout swatchLayout;
/// @}

/// @name Factory Methods
/// @{
+(nonnull instancetype)legendWithPlots:(nullable CPTPlotArray *)newPlots;
+(nonnull instancetype)legendWithGraph:(nullable __kindof CPTGraph *)graph;
/// @}

/// @name Initialization
/// @{
-(nonnull instancetype)initWithPlots:(nullable CPTPlotArray *)newPlots;
-(nonnull instancetype)initWithGraph:(nullable __kindof CPTGraph *)graph;
/// @}

/// @name Plots
/// @{
-(nonnull CPTPlotArray *)allPlots;
-(nullable CPTPlot *)plotAtIndex:(NSUInteger)idx;
-(nullable CPTPlot *)plotWithIdentifier:(nullable id<NSCopying>)identifier;

-(void)addPlot:(nonnull CPTPlot *)plot;
-(void)insertPlot:(nonnull CPTPlot *)plot atIndex:(NSUInteger)idx;
-(void)removePlot:(nonnull CPTPlot *)plot;
-(void)removePlotWithIdentifier:(nullable id<NSCopying>)identifier;
/// @}

/// @name Layout
/// @{
-(void)setLayoutChanged;
/// @}

@end

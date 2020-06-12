#import "CPTAnnotationHostLayer.h"
#import "CPTDefinitions.h"
#import "CPTNumericDataType.h"

/// @file

@class CPTLegend;
@class CPTMutableNumericData;
@class CPTNumericData;
@class CPTPlot;
@class CPTPlotArea;
@class CPTPlotSpace;
@class CPTPlotSpaceAnnotation;
@class CPTPlotRange;
@class CPTTextStyle;

/**
 *  @brief Plot bindings.
 **/
typedef NSString *CPTPlotBinding cpt_swift_struct;

/// @ingroup plotBindingsAllPlots
/// @{
extern CPTPlotBinding __nonnull const CPTPlotBindingDataLabels;
/// @}

/**
 *  @brief Enumeration of cache precisions.
 **/
typedef NS_ENUM (NSInteger, CPTPlotCachePrecision) {
    CPTPlotCachePrecisionAuto,   ///< Cache precision is determined automatically from the data. All cached data will be converted to match the last data loaded.
    CPTPlotCachePrecisionDouble, ///< All cached data will be converted to double precision.
    CPTPlotCachePrecisionDecimal ///< All cached data will be converted to @ref NSDecimal.
};

/**
 *  @brief An array of plots.
 **/
typedef NSArray<__kindof CPTPlot *> CPTPlotArray;

/**
 *  @brief A mutable array of plots.
 **/
typedef NSMutableArray<__kindof CPTPlot *> CPTMutablePlotArray;

#pragma mark -

/**
 *  @brief A plot data source.
 **/
@protocol CPTPlotDataSource<NSObject>

/// @name Data Values
/// @{

/** @brief @required The number of data points for the plot.
 *  @param plot The plot.
 *  @return The number of data points for the plot.
 **/
-(NSUInteger)numberOfRecordsForPlot:(nonnull CPTPlot *)plot;

@optional

/** @brief @optional Gets a range of plot data for the given plot and field.
 *  Implement one and only one of the optional methods in this section.
 *
 *  For fields where the @link CPTPlot::plotSpace plotSpace @endlink scale type is #CPTScaleTypeCategory,
 *  this method should return an array of NSString objects containing the category names. Otherwise, it should
 *  return an array of NSNumber objects holding the data values. For any scale type, include instances of NSNull
 *  in the array to indicate missing values.
 *
 *  @param plot The plot.
 *  @param fieldEnum The field index.
 *  @param indexRange The range of the data indexes of interest.
 *  @return An array of data points.
 **/
-(nullable NSArray *)numbersForPlot:(nonnull CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndexRange:(NSRange)indexRange;

/** @brief @optional Gets a plot data value for the given plot and field.
 *  Implement one and only one of the optional methods in this section.
 *
 *  For fields where the @link CPTPlot::plotSpace plotSpace @endlink scale type is #CPTScaleTypeCategory,
 *  this method should return an NSString containing the category name. Otherwise, it should return an
 *  NSNumber holding the data value. For any scale type, return @nil or an instance of NSNull to indicate
 *  missing values.
 *
 *  @param plot The plot.
 *  @param fieldEnum The field index.
 *  @param idx The data index of interest.
 *  @return A data point.
 **/
-(nullable id)numberForPlot:(nonnull CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)idx;

/** @brief @optional Gets a range of plot data for the given plot and field.
 *  Implement one and only one of the optional methods in this section.
 *  @param plot The plot.
 *  @param fieldEnum The field index.
 *  @param indexRange The range of the data indexes of interest.
 *  @return A retained C array of data points.
 **/
-(nullable double *)doublesForPlot:(nonnull CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndexRange:(NSRange)indexRange NS_RETURNS_INNER_POINTER;

/** @brief @optional Gets a plot data value for the given plot and field.
 *  Implement one and only one of the optional methods in this section.
 *  @param plot The plot.
 *  @param fieldEnum The field index.
 *  @param idx The data index of interest.
 *  @return A data point.
 **/
-(double)doubleForPlot:(nonnull CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)idx;

/** @brief @optional Gets a range of plot data for the given plot and field.
 *  Implement one and only one of the optional methods in this section.
 *  @param plot The plot.
 *  @param fieldEnum The field index.
 *  @param indexRange The range of the data indexes of interest.
 *  @return A one-dimensional array of data points.
 **/
-(nullable CPTNumericData *)dataForPlot:(nonnull CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndexRange:(NSRange)indexRange;

/** @brief @optional Gets a range of plot data for all fields of the given plot simultaneously.
 *  Implement one and only one of the optional methods in this section.
 *
 *  The data returned from this method should be a two-dimensional array. It can be arranged
 *  in row- or column-major order although column-major will load faster, especially for large arrays.
 *  The array should have the same number of rows as the length of @par{indexRange}.
 *  The number of columns should be equal to the number of plot fields required by the plot.
 *  The column index (zero-based) corresponds with the field index.
 *  The data type will be converted to match the @link CPTPlot::cachePrecision cachePrecision @endlink if needed.
 *
 *  @param plot The plot.
 *  @param indexRange The range of the data indexes of interest.
 *  @return A two-dimensional array of data points.
 **/
-(nullable CPTNumericData *)dataForPlot:(nonnull CPTPlot *)plot recordIndexRange:(NSRange)indexRange;

/// @}

/// @name Data Labels
/// @{

/** @brief @optional Gets a range of data labels for the given plot.
 *  @param plot The plot.
 *  @param indexRange The range of the data indexes of interest.
 *  @return An array of data labels.
 **/
-(nullable CPTLayerArray *)dataLabelsForPlot:(nonnull CPTPlot *)plot recordIndexRange:(NSRange)indexRange;

/** @brief @optional Gets a data label for the given plot.
 *  This method will not be called if
 *  @link CPTPlotDataSource::dataLabelsForPlot:recordIndexRange: -dataLabelsForPlot:recordIndexRange: @endlink
 *  is also implemented in the datasource.
 *  @param plot The plot.
 *  @param idx The data index of interest.
 *  @return The data label for the point with the given index.
 *  If you return @nil, the default data label will be used. If you return an instance of NSNull,
 *  no label will be shown for the index in question.
 **/
-(nullable CPTLayer *)dataLabelForPlot:(nonnull CPTPlot *)plot recordIndex:(NSUInteger)idx;

/// @}

@end

#pragma mark -

/**
 *  @brief Plot delegate.
 **/
@protocol CPTPlotDelegate<CPTLayerDelegate>

@optional

/// @name Point Selection
/// @{

/** @brief @optional Informs the delegate that a data label
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param plot The plot.
 *  @param idx The index of the
 *  @if MacOnly clicked data label. @endif
 *  @if iOSOnly touched data label. @endif
 **/
-(void)plot:(nonnull CPTPlot *)plot dataLabelWasSelectedAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a data label
 *  @if MacOnly was both pressed and released. @endif
 *  @if iOSOnly received both the touch down and up events. @endif
 *  @param plot The plot.
 *  @param idx The index of the
 *  @if MacOnly clicked data label. @endif
 *  @if iOSOnly touched data label. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)plot:(nonnull CPTPlot *)plot dataLabelWasSelectedAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a data label
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param plot The plot.
 *  @param idx The index of the
 *  @if MacOnly clicked data label. @endif
 *  @if iOSOnly touched data label. @endif
 **/
-(void)plot:(nonnull CPTPlot *)plot dataLabelTouchDownAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a data label
 *  @if MacOnly was pressed. @endif
 *  @if iOSOnly touch started. @endif
 *  @param plot The plot.
 *  @param idx The index of the
 *  @if MacOnly clicked data label. @endif
 *  @if iOSOnly touched data label. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)plot:(nonnull CPTPlot *)plot dataLabelTouchDownAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/** @brief @optional Informs the delegate that a data label
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param plot The plot.
 *  @param idx The index of the
 *  @if MacOnly clicked data label. @endif
 *  @if iOSOnly touched data label. @endif
 **/
-(void)plot:(nonnull CPTPlot *)plot dataLabelTouchUpAtRecordIndex:(NSUInteger)idx;

/** @brief @optional Informs the delegate that a data label
 *  @if MacOnly was released. @endif
 *  @if iOSOnly touch ended. @endif
 *  @param plot The plot.
 *  @param idx The index of the
 *  @if MacOnly clicked data label. @endif
 *  @if iOSOnly touched data label. @endif
 *  @param event The event that triggered the selection.
 **/
-(void)plot:(nonnull CPTPlot *)plot dataLabelTouchUpAtRecordIndex:(NSUInteger)idx withEvent:(nonnull CPTNativeEvent *)event;

/// @}

/// @name Drawing
/// @{

/**
 *  @brief @optional Informs the delegate that plot drawing is finished.
 *  @param plot The plot.
 **/
-(void)didFinishDrawing:(nonnull CPTPlot *)plot;

/// @}

@end

#pragma mark -

@interface CPTPlot : CPTAnnotationHostLayer

/// @name Data Source
/// @{
@property (nonatomic, readwrite, cpt_weak_property, nullable) id<CPTPlotDataSource> dataSource;
/// @}

/// @name Identification
/// @{
@property (nonatomic, readwrite, copy, nullable) NSString *title;
@property (nonatomic, readwrite, copy, nullable) NSAttributedString *attributedTitle;
/// @}

/// @name Plot Space
/// @{
@property (nonatomic, readwrite, strong, nullable) CPTPlotSpace *plotSpace;
/// @}

/// @name Plot Area
/// @{
@property (nonatomic, readonly, nullable) CPTPlotArea *plotArea;
/// @}

/// @name Data Loading
/// @{
@property (nonatomic, readonly) BOOL dataNeedsReloading;
/// @}

/// @name Data Cache
/// @{
@property (nonatomic, readonly) NSUInteger cachedDataCount;
@property (nonatomic, readonly) BOOL doublePrecisionCache;
@property (nonatomic, readwrite, assign) CPTPlotCachePrecision cachePrecision;
@property (nonatomic, readonly) CPTNumericDataType doubleDataType;
@property (nonatomic, readonly) CPTNumericDataType decimalDataType;
/// @}

/// @name Data Labels
/// @{
@property (nonatomic, readonly) BOOL needsRelabel;
@property (nonatomic, readwrite, assign) BOOL adjustLabelAnchors;
@property (nonatomic, readwrite, assign) BOOL showLabels;
@property (nonatomic, readwrite, assign) CGFloat labelOffset;
@property (nonatomic, readwrite, assign) CGFloat labelRotation;
@property (nonatomic, readwrite, assign) NSUInteger labelField;
@property (nonatomic, readwrite, copy, nullable) CPTTextStyle *labelTextStyle;
@property (nonatomic, readwrite, strong, nullable) NSFormatter *labelFormatter;
@property (nonatomic, readwrite, strong, nullable) CPTShadow *labelShadow;
/// @}

/// @name Drawing
/// @{
@property (nonatomic, readwrite, assign) BOOL alignsPointsToPixels;
/// @}

/// @name Legends
/// @{
@property (nonatomic, readwrite, assign) BOOL drawLegendSwatchDecoration;
/// @}

/// @name Data Labels
/// @{
-(void)setNeedsRelabel;
-(void)relabel;
-(void)relabelIndexRange:(NSRange)indexRange;
-(void)repositionAllLabelAnnotations;
-(void)reloadDataLabels;
-(void)reloadDataLabelsInIndexRange:(NSRange)indexRange;
/// @}

/// @name Data Loading
/// @{
-(void)setDataNeedsReloading;
-(void)reloadData;
-(void)reloadDataIfNeeded;
-(void)reloadDataInIndexRange:(NSRange)indexRange;
-(void)insertDataAtIndex:(NSUInteger)idx numberOfRecords:(NSUInteger)numberOfRecords;
-(void)deleteDataInIndexRange:(NSRange)indexRange;
-(void) reloadPlotData NS_SWIFT_NAME(CPTPlot.reloadPlotData());

-(void)reloadPlotDataInIndexRange:(NSRange) indexRange NS_SWIFT_NAME(CPTPlot.reloadPlotData(inIndexRange:));

/// @}

/// @name Plot Data
/// @{
+(nonnull id)nilData;
-(nullable id)numbersFromDataSourceForField:(NSUInteger)fieldEnum recordIndexRange:(NSRange)indexRange;
-(BOOL)loadNumbersForAllFieldsFromDataSourceInRecordIndexRange:(NSRange)indexRange;
/// @}

/// @name Data Cache
/// @{
-(nullable CPTMutableNumericData *)cachedNumbersForField:(NSUInteger)fieldEnum;
-(nullable NSNumber *)cachedNumberForField:(NSUInteger)fieldEnum recordIndex:(NSUInteger)idx;
-(double)cachedDoubleForField:(NSUInteger)fieldEnum recordIndex:(NSUInteger)idx;
-(NSDecimal)cachedDecimalForField:(NSUInteger)fieldEnum recordIndex:(NSUInteger)idx;
-(nullable NSArray *)cachedArrayForKey:(nonnull NSString *)key;
-(nullable id)cachedValueForKey:(nonnull NSString *)key recordIndex:(NSUInteger)idx;

-(void)cacheNumbers:(nullable id)numbers forField:(NSUInteger)fieldEnum;
-(void)cacheNumbers:(nullable id)numbers forField:(NSUInteger)fieldEnum atRecordIndex:(NSUInteger)idx;
-(void)cacheArray:(nullable NSArray *)array forKey:(nonnull NSString *)key;
-(void)cacheArray:(nullable NSArray *)array forKey:(nonnull NSString *)key atRecordIndex:(NSUInteger)idx;
/// @}

/// @name Plot Data Ranges
/// @{
-(nullable CPTPlotRange *)plotRangeForField:(NSUInteger)fieldEnum;
-(nullable CPTPlotRange *)plotRangeForCoordinate:(CPTCoordinate)coord;
-(nullable CPTPlotRange *)plotRangeEnclosingField:(NSUInteger)fieldEnum;
-(nullable CPTPlotRange *)plotRangeEnclosingCoordinate:(CPTCoordinate)coord;
/// @}

/// @name Legends
/// @{
-(NSUInteger)numberOfLegendEntries;
-(nullable NSString *)titleForLegendEntryAtIndex:(NSUInteger)idx;
-(nullable NSAttributedString *)attributedTitleForLegendEntryAtIndex:(NSUInteger)idx;
-(void)drawSwatchForLegend:(nonnull CPTLegend *)legend atIndex:(NSUInteger)idx inRect:(CGRect)rect inContext:(nonnull CGContextRef)context;
/// @}

@end

#pragma mark -

/** @category CPTPlot(AbstractMethods)
 *  @brief CPTPlot abstract methods—must be overridden by subclasses
 **/
@interface CPTPlot(AbstractMethods)

/// @name Fields
/// @{
-(NSUInteger)numberOfFields;
-(nonnull CPTNumberArray *)fieldIdentifiers;
-(nonnull CPTNumberArray *)fieldIdentifiersForCoordinate:(CPTCoordinate)coord;
-(CPTCoordinate)coordinateForFieldIdentifier:(NSUInteger)field;
/// @}

/// @name Data Labels
/// @{
-(void)positionLabelAnnotation:(nonnull CPTPlotSpaceAnnotation *)label forIndex:(NSUInteger)idx;
/// @}

/// @name User Interaction
/// @{
-(NSUInteger)dataIndexFromInteractionPoint:(CGPoint)point;
/// @}

@end

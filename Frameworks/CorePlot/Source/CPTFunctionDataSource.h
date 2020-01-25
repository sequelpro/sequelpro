#import "CPTPlot.h"

@class CPTPlotRange;

/// @file

/**
 *  @brief A function called to generate plot data in a CPTFunctionDataSource datasource.
 **/
typedef double (*CPTDataSourceFunction)(double);

/**
 *  @brief An Objective-C block called to generate plot data in a CPTFunctionDataSource datasource.
 **/
typedef double (^CPTDataSourceBlock)(double);

@interface CPTFunctionDataSource : NSObject<CPTPlotDataSource>

@property (nonatomic, readonly, nullable) CPTDataSourceFunction dataSourceFunction;
@property (nonatomic, readonly, nullable) CPTDataSourceBlock dataSourceBlock;
@property (nonatomic, readonly, nonnull) CPTPlot *dataPlot;

@property (nonatomic, readwrite) CGFloat resolution;
@property (nonatomic, readwrite, strong, nullable) CPTPlotRange *dataRange;

/// @name Factory Methods
/// @{
+(nonnull instancetype)dataSourceForPlot:(nonnull CPTPlot *)plot withFunction:(nonnull CPTDataSourceFunction) function NS_SWIFT_NAME(init(for:withFunction:));

+(nonnull instancetype)dataSourceForPlot:(nonnull CPTPlot *)plot withBlock:(nonnull CPTDataSourceBlock) block NS_SWIFT_NAME(init(for:withBlock:));

/// @}

/// @name Initialization
/// @{
-(nonnull instancetype)initForPlot:(nonnull CPTPlot *)plot withFunction:(nonnull CPTDataSourceFunction) function NS_SWIFT_NAME(init(forPlot:withFunction:));

-(nonnull instancetype)initForPlot:(nonnull CPTPlot *)plot withBlock:(nonnull CPTDataSourceBlock) block NS_SWIFT_NAME(init(forPlot:withBlock:));

/// @}

@end

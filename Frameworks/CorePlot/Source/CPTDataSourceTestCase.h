#import "CPTTestCase.h"

#import "CPTPlot.h"

@class CPTMutablePlotRange;

@interface CPTDataSourceTestCase : CPTTestCase<CPTPlotDataSource>

@property (nonatomic, readwrite, copy, nullable) CPTNumberArray *xData;
@property (nonatomic, readwrite, copy, nullable) CPTNumberArray *yData;
@property (nonatomic, readwrite, assign) NSUInteger nRecords;
@property (nonatomic, readonly, strong, nonnull) CPTPlotRange *xRange;
@property (nonatomic, readonly, strong, nonnull) CPTPlotRange *yRange;
@property (nonatomic, readwrite, strong, nonnull) CPTMutablePlotArray *plots;

-(void)buildData;

-(void)addPlot:(nonnull CPTPlot *)newPlot;

@end

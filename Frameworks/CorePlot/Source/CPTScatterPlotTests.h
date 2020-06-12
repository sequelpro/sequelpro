#import "CPTTestCase.h"

@class CPTScatterPlot;
@class CPTXYPlotSpace;

@interface CPTScatterPlotTests : CPTTestCase

@property (nonatomic, readwrite, strong, nullable) CPTScatterPlot *plot;
@property (nonatomic, readwrite, strong, nullable) CPTXYPlotSpace *plotSpace;

@end

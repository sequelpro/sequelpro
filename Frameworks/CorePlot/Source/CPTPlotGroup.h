#import "CPTLayer.h"

@class CPTPlot;

@interface CPTPlotGroup : CPTLayer

/// @name Adding and Removing Plots
/// @{
-(void)addPlot:(nonnull CPTPlot *)plot;
-(void)removePlot:(nullable CPTPlot *)plot;
-(void)insertPlot:(nonnull CPTPlot *)plot atIndex:(NSUInteger)idx;
/// @}

@end

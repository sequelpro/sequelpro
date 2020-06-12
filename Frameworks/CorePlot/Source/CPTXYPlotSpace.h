#import "CPTAnimation.h"
#import "CPTDefinitions.h"
#import "CPTPlotSpace.h"

@class CPTPlotRange;

@interface CPTXYPlotSpace : CPTPlotSpace<CPTAnimationDelegate>

@property (nonatomic, readwrite, copy, nonnull) CPTPlotRange *xRange;
@property (nonatomic, readwrite, copy, nonnull) CPTPlotRange *yRange;
@property (nonatomic, readwrite, copy, nullable) CPTPlotRange *globalXRange;
@property (nonatomic, readwrite, copy, nullable) CPTPlotRange *globalYRange;
@property (nonatomic, readwrite, assign) CPTScaleType xScaleType;
@property (nonatomic, readwrite, assign) CPTScaleType yScaleType;

@property (nonatomic, readwrite) BOOL allowsMomentum;
@property (nonatomic, readwrite) BOOL allowsMomentumX;
@property (nonatomic, readwrite) BOOL allowsMomentumY;
@property (nonatomic, readwrite) CPTAnimationCurve momentumAnimationCurve;
@property (nonatomic, readwrite) CPTAnimationCurve bounceAnimationCurve;
@property (nonatomic, readwrite) CGFloat momentumAcceleration;
@property (nonatomic, readwrite) CGFloat bounceAcceleration;
@property (nonatomic, readwrite) CGFloat minimumDisplacementToDrag;

-(void)cancelAnimations;

@end

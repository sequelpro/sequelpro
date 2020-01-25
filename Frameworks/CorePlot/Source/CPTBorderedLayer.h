#import "CPTAnnotationHostLayer.h"

@class CPTLineStyle;
@class CPTFill;

@interface CPTBorderedLayer : CPTAnnotationHostLayer

/// @name Drawing
/// @{
@property (nonatomic, readwrite, copy, nullable) CPTLineStyle *borderLineStyle;
@property (nonatomic, readwrite, copy, nullable) CPTFill *fill;
/// @}

/// @name Layout
/// @{
@property (nonatomic, readwrite) BOOL inLayout;
/// @}

/// @name Drawing
/// @{
-(void)renderBorderedLayerAsVectorInContext:(nonnull CGContextRef)context;
/// @}

@end

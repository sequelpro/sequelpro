#import "CPTAnnotation.h"
#import "CPTLayer.h"

@interface CPTAnnotationHostLayer : CPTLayer

@property (nonatomic, readonly, nonnull) CPTAnnotationArray *annotations;

/// @name Annotations
/// @{
-(void)addAnnotation:(nullable CPTAnnotation *)annotation;
-(void)removeAnnotation:(nullable CPTAnnotation *)annotation;
-(void)removeAllAnnotations;
/// @}

@end

#import "CPTDefinitions.h"

/// @file

@class CPTAnnotation;
@class CPTAnnotationHostLayer;
@class CPTLayer;

/**
 *  @brief An array of annotations.
 **/
typedef NSArray<__kindof CPTAnnotation *> CPTAnnotationArray;

/**
 *  @brief A mutable array of annotations.
 **/
typedef NSMutableArray<__kindof CPTAnnotation *> CPTMutableAnnotationArray;

@interface CPTAnnotation : NSObject<NSCoding, NSSecureCoding>

@property (nonatomic, readwrite, strong, nullable) CPTLayer *contentLayer;
@property (nonatomic, readwrite, cpt_weak_property, nullable) CPTAnnotationHostLayer *annotationHostLayer;
@property (nonatomic, readwrite, assign) CGPoint contentAnchorPoint;
@property (nonatomic, readwrite, assign) CGPoint displacement;
@property (nonatomic, readwrite, assign) CGFloat rotation;

/// @name Initialization
/// @{
-(nonnull instancetype)init NS_DESIGNATED_INITIALIZER;
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder NS_DESIGNATED_INITIALIZER;
/// @}

@end

#pragma mark -

/** @category CPTAnnotation(AbstractMethods)
 *  @brief CPTAnnotation abstract methods—must be overridden by subclasses.
 **/
@interface CPTAnnotation(AbstractMethods)

/// @name Layout
/// @{
-(void)positionContentLayer;
/// @}

@end

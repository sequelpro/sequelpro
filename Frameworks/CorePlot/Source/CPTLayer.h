#import "CPTDefinitions.h"
#import "CPTResponder.h"
#import <QuartzCore/QuartzCore.h>

/// @file

@class CPTGraph;
@class CPTLayer;
@class CPTShadow;

/**
 *  @brief Layer notification type.
 **/
typedef NSString *CPTLayerNotification cpt_swift_struct;

/// @name Layout
/// @{

/** @brief Notification sent by all layers when the layer @link CALayer::bounds bounds @endlink change.
 *  @ingroup notification
 **/
extern CPTLayerNotification __nonnull const CPTLayerBoundsDidChangeNotification NS_SWIFT_NAME(boundsDidChange);

/// @}

/**
 *  @brief An array of CPTLayer objects.
 **/
typedef NSArray<CPTLayer *> CPTLayerArray;

/**
 *  @brief A mutable array of CPTLayer objects.
 **/
typedef NSMutableArray<CPTLayer *> CPTMutableLayerArray;

/**
 *  @brief A set of CPTLayer objects.
 **/
typedef NSSet<CPTLayer *> CPTLayerSet;

/**
 *  @brief A mutable set of CPTLayer objects.
 **/
typedef NSMutableSet<CPTLayer *> CPTMutableLayerSet;

/**
 *  @brief An array of CALayer objects.
 **/
typedef NSArray<CALayer *> CPTSublayerArray;

/**
 *  @brief A mutable array of CALayer objects.
 **/
typedef NSMutableArray<CALayer *> CPTMutableSublayerArray;

/**
 *  @brief A set of CALayer objects.
 **/
typedef NSSet<CALayer *> CPTSublayerSet;

/**
 *  @brief A mutable set of CALayer objects.
 **/
typedef NSMutableSet<CALayer *> CPTMutableSublayerSet;

#pragma mark -

/**
 *  @brief Layer delegate.
 **/
#if ((TARGET_OS_SIMULATOR || TARGET_OS_IPHONE || TARGET_OS_TV) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= 100000)) \
    || (TARGET_OS_MAC && (MAC_OS_X_VERSION_MAX_ALLOWED >= 101200))
// CALayerDelegate is defined by Core Animation in iOS 10.0+, macOS 10.12+, and tvOS 10.0+
@protocol CPTLayerDelegate<CALayerDelegate>
#else
@protocol CPTLayerDelegate<NSObject>
#endif

@end

#pragma mark -

@interface CPTLayer : CALayer<CPTResponder, NSSecureCoding>

/// @name Graph
/// @{
@property (nonatomic, readwrite, cpt_weak_property, nullable) CPTGraph *graph;
/// @}

/// @name Padding
/// @{
@property (nonatomic, readwrite) CGFloat paddingLeft;
@property (nonatomic, readwrite) CGFloat paddingTop;
@property (nonatomic, readwrite) CGFloat paddingRight;
@property (nonatomic, readwrite) CGFloat paddingBottom;
/// @}

/// @name Drawing
/// @{
@property (readwrite) CGFloat contentsScale;
@property (nonatomic, readonly) BOOL useFastRendering;
@property (nonatomic, readwrite, copy, nullable) CPTShadow *shadow;
@property (nonatomic, readonly) CGSize shadowMargin;
/// @}

/// @name Masking
/// @{
@property (nonatomic, readwrite, assign) BOOL masksToBorder;
@property (nonatomic, readwrite, assign, nullable)  CGPathRef outerBorderPath;
@property (nonatomic, readwrite, assign, nullable)  CGPathRef innerBorderPath;
@property (nonatomic, readonly, nullable)  CGPathRef maskingPath;
@property (nonatomic, readonly, nullable)  CGPathRef sublayerMaskingPath;
/// @}

/// @name Identification
/// @{
@property (nonatomic, readwrite, copy, nullable) id<NSCopying, NSCoding, NSObject> identifier;
/// @}

/// @name Layout
/// @{
@property (nonatomic, readonly, nullable) CPTSublayerSet *sublayersExcludedFromAutomaticLayout;
/// @}

/// @name Initialization
/// @{
-(nonnull instancetype)initWithFrame:(CGRect)newFrame NS_DESIGNATED_INITIALIZER;
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder NS_DESIGNATED_INITIALIZER;
-(nonnull instancetype)initWithLayer:(nonnull id)layer NS_DESIGNATED_INITIALIZER;
/// @}

/// @name Drawing
/// @{
-(void)setNeedsDisplayAllLayers;
-(void)renderAsVectorInContext:(nonnull CGContextRef)context;
-(void)recursivelyRenderInContext:(nonnull CGContextRef)context;
-(void)layoutAndRenderInContext:(nonnull CGContextRef)context;
-(nonnull NSData *)dataForPDFRepresentationOfLayer;
/// @}

/// @name Masking
/// @{
-(void)applySublayerMaskToContext:(nonnull CGContextRef)context forSublayer:(nonnull CPTLayer *)sublayer withOffset:(CGPoint)offset;
-(void)applyMaskToContext:(nonnull CGContextRef)context;
/// @}

/// @name Layout
/// @{
-(void)pixelAlign;
-(void)sublayerMarginLeft:(nonnull CGFloat *)left top:(nonnull CGFloat *)top right:(nonnull CGFloat *)right bottom:(nonnull CGFloat *)bottom;
/// @}

/// @name Information
/// @{
-(void)logLayers;
/// @}

@end

#import "CPTDefinitions.h"
#import "CPTPlatformSpecificDefines.h"

@interface CPTImage : NSObject<NSCopying, NSCoding, NSSecureCoding>

@property (nonatomic, readwrite, copy, nullable) CPTNativeImage *nativeImage;
@property (nonatomic, readwrite, assign, nullable) CGImageRef image;
@property (nonatomic, readwrite, assign) CGFloat scale;
@property (nonatomic, readwrite, assign, getter = isTiled) BOOL tiled;
@property (nonatomic, readwrite, assign) CPTEdgeInsets edgeInsets;
@property (nonatomic, readwrite, assign) BOOL tileAnchoredToContext;
@property (nonatomic, readonly, getter = isOpaque) BOOL opaque;

/// @name Factory Methods
/// @{
+(nonnull instancetype)imageNamed:(nonnull NSString *)name;

+(nonnull instancetype)imageWithNativeImage:(nullable CPTNativeImage *)anImage;
+(nonnull instancetype)imageWithContentsOfFile:(nonnull NSString *)path;
+(nonnull instancetype)imageWithCGImage:(nullable CGImageRef)anImage scale:(CGFloat)newScale;
+(nonnull instancetype)imageWithCGImage:(nullable CGImageRef)anImage;
+(nonnull instancetype)imageForPNGFile:(nonnull NSString *)path;
/// @}

/// @name Initialization
/// @{
-(nonnull instancetype)initWithContentsOfFile:(nonnull NSString *)path;
-(nonnull instancetype)initWithCGImage:(nullable CGImageRef)anImage scale:(CGFloat)newScale NS_DESIGNATED_INITIALIZER;
-(nonnull instancetype)initWithCGImage:(nullable CGImageRef)anImage;
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder NS_DESIGNATED_INITIALIZER;
/// @}

/// @name Drawing
/// @{
-(void)drawInRect:(CGRect)rect inContext:(nonnull CGContextRef)context;
/// @}

@end

#pragma mark -

/** @category CPTImage(CPTPlatformSpecificImageExtensions)
 *  @brief Platform-specific extensions to CPTImage.
 **/
@interface CPTImage(CPTPlatformSpecificImageExtensions)

/// @name Initialization
/// @{
-(nonnull instancetype)initWithNativeImage:(nullable CPTNativeImage *)anImage;
-(nonnull instancetype)initForPNGFile:(nonnull NSString *)path;
/// @}

@end

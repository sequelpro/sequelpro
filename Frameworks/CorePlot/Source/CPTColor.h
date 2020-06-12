#import "CPTPlatformSpecificDefines.h"

@interface CPTColor : NSObject<NSCopying, NSCoding, NSSecureCoding>

@property (nonatomic, readonly, nonnull) CGColorRef cgColor;
@property (nonatomic, readonly, getter = isOpaque) BOOL opaque;

#if TARGET_OS_OSX
@property (nonatomic, readonly, nonnull) NSColor *nsColor;
#elif TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
@property (nonatomic, readonly, nonnull) UIColor *uiColor;
#endif
@property (nonatomic, readonly, nonnull) CPTNativeColor *nativeColor;

/// @name Standard Colors
/// @{
+(nonnull instancetype)clearColor;
+(nonnull instancetype)whiteColor;
+(nonnull instancetype)lightGrayColor;
+(nonnull instancetype)grayColor;
+(nonnull instancetype)darkGrayColor;
+(nonnull instancetype)blackColor;
+(nonnull instancetype)redColor;
+(nonnull instancetype)greenColor;
+(nonnull instancetype)blueColor;
+(nonnull instancetype)cyanColor;
+(nonnull instancetype)yellowColor;
+(nonnull instancetype)magentaColor;
+(nonnull instancetype)orangeColor;
+(nonnull instancetype)purpleColor;
+(nonnull instancetype)brownColor;
/// @}

/// @name Factory Methods
/// @{
+(nonnull instancetype)colorWithCGColor:(nonnull CGColorRef)newCGColor;
+(nonnull instancetype)colorWithComponentRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+(nonnull instancetype)colorWithGenericGray:(CGFloat)gray;

#if TARGET_OS_OSX
+(nonnull instancetype)colorWithNSColor:(nonnull NSColor *)newNSColor;
#elif TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
+(nonnull instancetype)colorWithUIColor:(nonnull UIColor *)newUIColor;
#endif
+(nonnull instancetype)colorWithNativeColor:(nonnull CPTNativeColor *)newColor;

/// @}

/// @name Initialization
/// @{
-(nonnull instancetype)initWithCGColor:(nonnull CGColorRef)cgColor NS_DESIGNATED_INITIALIZER;
-(nonnull instancetype)initWithComponentRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder NS_DESIGNATED_INITIALIZER;

#if TARGET_OS_OSX
-(nonnull instancetype)initWithNSColor:(nonnull NSColor *)newNSColor NS_DESIGNATED_INITIALIZER;
#elif TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
-(nonnull instancetype)initWithUIColor:(nonnull UIColor *)newUIColor NS_DESIGNATED_INITIALIZER;
#endif
-(nonnull instancetype)initWithNativeColor:(nonnull CPTNativeColor *)newColor;

-(nonnull instancetype)colorWithAlphaComponent:(CGFloat)alpha;
/// @}

@end

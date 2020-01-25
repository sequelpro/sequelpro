// Based on CTGradient (http://blog.oofn.net/2006/01/15/gradients-in-cocoa/)
// CTGradient is in public domain (Thanks Chad Weider!)

/// @file

#import "CPTDefinitions.h"

/**
 *  @brief A structure representing one node in a linked list of RGBA colors.
 **/
typedef struct _CPTGradientElement {
    CPTRGBAColor color;    ///< Color
    CGFloat      position; ///< Gradient position (0 ≤ @par{position} ≤ 1)

    struct _CPTGradientElement *__nullable nextElement; ///< Pointer to the next CPTGradientElement in the list (last element == @NULL)
}
CPTGradientElement;

/**
 *  @brief Enumeration of blending modes
 **/
typedef NS_ENUM (NSInteger, CPTGradientBlendingMode) {
    CPTLinearBlendingMode,          ///< Linear blending mode
    CPTChromaticBlendingMode,       ///< Chromatic blending mode
    CPTInverseChromaticBlendingMode ///< Inverse chromatic blending mode
};

/**
 *  @brief Enumeration of gradient types
 **/
typedef NS_ENUM (NSInteger, CPTGradientType) {
    CPTGradientTypeAxial, ///< Axial gradient
    CPTGradientTypeRadial ///< Radial gradient
};

@class CPTColorSpace;
@class CPTColor;

@interface CPTGradient : NSObject<NSCopying, NSCoding, NSSecureCoding>

@property (nonatomic, readonly, getter = isOpaque) BOOL opaque;

/// @name Gradient Type
/// @{
@property (nonatomic, readonly) CPTGradientBlendingMode blendingMode;
@property (nonatomic, readwrite, assign) CPTGradientType gradientType;
/// @}

/// @name Axial Gradients
/// @{
@property (nonatomic, readwrite, assign) CGFloat angle;
/// @}

/// @name Radial Gradients
/// @{
@property (nonatomic, readwrite, assign) CGPoint startAnchor;
@property (nonatomic, readwrite, assign) CGPoint endAnchor;
/// @}

/// @name Factory Methods
/// @{
+(nonnull instancetype)gradientWithBeginningColor:(nonnull CPTColor *)begin endingColor:(nonnull CPTColor *)end;
+(nonnull instancetype)gradientWithBeginningColor:(nonnull CPTColor *)begin endingColor:(nonnull CPTColor *)end beginningPosition:(CGFloat)beginningPosition endingPosition:(CGFloat)endingPosition;

+(nonnull instancetype)aquaSelectedGradient;
+(nonnull instancetype)aquaNormalGradient;
+(nonnull instancetype)aquaPressedGradient;

+(nonnull instancetype)unifiedSelectedGradient;
+(nonnull instancetype)unifiedNormalGradient;
+(nonnull instancetype)unifiedPressedGradient;
+(nonnull instancetype)unifiedDarkGradient;

+(nonnull instancetype)sourceListSelectedGradient;
+(nonnull instancetype)sourceListUnselectedGradient;

+(nonnull instancetype)rainbowGradient;
+(nonnull instancetype)hydrogenSpectrumGradient;
/// @}

/// @name Modification
/// @{
-(nonnull CPTGradient *)gradientWithAlphaComponent:(CGFloat)alpha;
-(nonnull CPTGradient *)gradientWithBlendingMode:(CPTGradientBlendingMode)mode;

-(nonnull CPTGradient *)addColorStop:(nonnull CPTColor *)color atPosition:(CGFloat)position; // positions given relative to [0,1]
-(nonnull CPTGradient *)removeColorStopAtIndex:(NSUInteger)idx;
-(nonnull CPTGradient *)removeColorStopAtPosition:(CGFloat)position;
/// @}

/// @name Information
/// @{
-(nullable CGColorRef)newColorStopAtIndex:(NSUInteger)idx CF_RETURNS_RETAINED;
-(nonnull CGColorRef)newColorAtPosition:(CGFloat)position CF_RETURNS_RETAINED;
/// @}

/// @name Drawing
/// @{
-(void)drawSwatchInRect:(CGRect)rect inContext:(nonnull CGContextRef)context;
-(void)fillRect:(CGRect)rect inContext:(nonnull CGContextRef)context;
-(void)fillPathInContext:(nonnull CGContextRef)context;
/// @}

@end

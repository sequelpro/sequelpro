#import "CPTDefinitions.h"

/// @file

@class CPTColor;
@class CPTFill;
@class CPTGradient;
@class CPTLineStyle;

/**
 *  @brief An array of line styles.
 **/
typedef NSArray<CPTLineStyle *> CPTLineStyleArray;

/**
 *  @brief A mutable array of line styles.
 **/
typedef NSMutableArray<CPTLineStyle *> CPTMutableLineStyleArray;

@interface CPTLineStyle : NSObject<NSCopying, NSMutableCopying, NSCoding, NSSecureCoding>

@property (nonatomic, readonly) CGLineCap lineCap;
@property (nonatomic, readonly) CGLineJoin lineJoin;
@property (nonatomic, readonly) CGFloat miterLimit;
@property (nonatomic, readonly) CGFloat lineWidth;
@property (nonatomic, readonly, nullable) CPTNumberArray *dashPattern;
@property (nonatomic, readonly) CGFloat patternPhase;
@property (nonatomic, readonly, nullable) CPTColor *lineColor;
@property (nonatomic, readonly, nullable) CPTFill *lineFill;
@property (nonatomic, readonly, nullable) CPTGradient *lineGradient;
@property (nonatomic, readonly, getter = isOpaque) BOOL opaque;

/// @name Factory Methods
/// @{
+(nonnull instancetype)lineStyle;
+(nonnull instancetype)lineStyleWithStyle:(nullable CPTLineStyle *)lineStyle;
/// @}

/// @name Drawing
/// @{
-(void)setLineStyleInContext:(nonnull CGContextRef)context;
-(void)strokePathInContext:(nonnull CGContextRef)context;
-(void)strokeRect:(CGRect)rect inContext:(nonnull CGContextRef)context;
/// @}

@end

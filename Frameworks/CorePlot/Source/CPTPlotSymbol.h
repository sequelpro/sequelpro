/// @file

@class CPTLineStyle;
@class CPTFill;
@class CPTPlotSymbol;
@class CPTShadow;

/**
 *  @brief Plot symbol types.
 **/
typedef NS_ENUM (NSInteger, CPTPlotSymbolType) {
    CPTPlotSymbolTypeNone,      ///< No symbol.
    CPTPlotSymbolTypeRectangle, ///< Rectangle symbol.
    CPTPlotSymbolTypeEllipse,   ///< Elliptical symbol.
    CPTPlotSymbolTypeDiamond,   ///< Diamond symbol.
    CPTPlotSymbolTypeTriangle,  ///< Triangle symbol.
    CPTPlotSymbolTypeStar,      ///< 5-point star symbol.
    CPTPlotSymbolTypePentagon,  ///< Pentagon symbol.
    CPTPlotSymbolTypeHexagon,   ///< Hexagon symbol.
    CPTPlotSymbolTypeCross,     ///< X symbol.
    CPTPlotSymbolTypePlus,      ///< Plus symbol.
    CPTPlotSymbolTypeDash,      ///< Dash symbol.
    CPTPlotSymbolTypeSnow,      ///< Snowflake symbol.
    CPTPlotSymbolTypeCustom     ///< Custom symbol.
};

/**
 *  @brief An array of plot symbols.
 **/
typedef NSArray<CPTPlotSymbol *> CPTPlotSymbolArray;

/**
 *  @brief A mutable array of plot symbols.
 **/
typedef NSMutableArray<CPTPlotSymbol *> CPTMutablePlotSymbolArray;

@interface CPTPlotSymbol : NSObject<NSCopying, NSCoding, NSSecureCoding>

@property (nonatomic, readwrite, assign) CGPoint anchorPoint;
@property (nonatomic, readwrite, assign) CGSize size;
@property (nonatomic, readwrite, assign) CPTPlotSymbolType symbolType;
@property (nonatomic, readwrite, strong, nullable) CPTLineStyle *lineStyle;
@property (nonatomic, readwrite, strong, nullable) CPTFill *fill;
@property (nonatomic, readwrite, copy, nullable) CPTShadow *shadow;
@property (nonatomic, readwrite, assign, nullable) CGPathRef customSymbolPath;
@property (nonatomic, readwrite, assign) BOOL usesEvenOddClipRule;

/// @name Factory Methods
/// @{
+(nonnull instancetype)plotSymbol;
+(nonnull instancetype)crossPlotSymbol;
+(nonnull instancetype)ellipsePlotSymbol;
+(nonnull instancetype)rectanglePlotSymbol;
+(nonnull instancetype)plusPlotSymbol;
+(nonnull instancetype)starPlotSymbol;
+(nonnull instancetype)diamondPlotSymbol;
+(nonnull instancetype)trianglePlotSymbol;
+(nonnull instancetype)pentagonPlotSymbol;
+(nonnull instancetype)hexagonPlotSymbol;
+(nonnull instancetype)dashPlotSymbol;
+(nonnull instancetype)snowPlotSymbol;
+(nonnull instancetype)customPlotSymbolWithPath:(nullable CGPathRef)aPath;
/// @}

/// @name Drawing
/// @{
-(void)renderInContext:(nonnull CGContextRef)context atPoint:(CGPoint)center scale:(CGFloat)scale alignToPixels:(BOOL)alignToPixels;
-(void)renderAsVectorInContext:(nonnull CGContextRef)context atPoint:(CGPoint)center scale:(CGFloat)scale;
/// @}

@end

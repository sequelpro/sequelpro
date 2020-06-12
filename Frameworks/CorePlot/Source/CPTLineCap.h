/// @file

@class CPTLineStyle;
@class CPTFill;

/**
 *  @brief Line cap types.
 **/
typedef NS_ENUM (NSInteger, CPTLineCapType) {
    CPTLineCapTypeNone,       ///< No line cap.
    CPTLineCapTypeOpenArrow,  ///< Open arrow line cap.
    CPTLineCapTypeSolidArrow, ///< Solid arrow line cap.
    CPTLineCapTypeSweptArrow, ///< Swept arrow line cap.
    CPTLineCapTypeRectangle,  ///< Rectangle line cap.
    CPTLineCapTypeEllipse,    ///< Elliptical line cap.
    CPTLineCapTypeDiamond,    ///< Diamond line cap.
    CPTLineCapTypePentagon,   ///< Pentagon line cap.
    CPTLineCapTypeHexagon,    ///< Hexagon line cap.
    CPTLineCapTypeBar,        ///< Bar line cap.
    CPTLineCapTypeCross,      ///< X line cap.
    CPTLineCapTypeSnow,       ///< Snowflake line cap.
    CPTLineCapTypeCustom      ///< Custom line cap.
};

@interface CPTLineCap : NSObject<NSCopying, NSCoding, NSSecureCoding>

@property (nonatomic, readwrite, assign) CGSize size;
@property (nonatomic, readwrite, assign) CPTLineCapType lineCapType;
@property (nonatomic, readwrite, strong, nullable) CPTLineStyle *lineStyle;
@property (nonatomic, readwrite, strong, nullable) CPTFill *fill;
@property (nonatomic, readwrite, assign, nullable) CGPathRef customLineCapPath;
@property (nonatomic, readwrite, assign) BOOL usesEvenOddClipRule;

/// @name Factory Methods
/// @{
+(nonnull instancetype)lineCap;
+(nonnull instancetype)openArrowPlotLineCap;
+(nonnull instancetype)solidArrowPlotLineCap;
+(nonnull instancetype)sweptArrowPlotLineCap;
+(nonnull instancetype)rectanglePlotLineCap;
+(nonnull instancetype)ellipsePlotLineCap;
+(nonnull instancetype)diamondPlotLineCap;
+(nonnull instancetype)pentagonPlotLineCap;
+(nonnull instancetype)hexagonPlotLineCap;
+(nonnull instancetype)barPlotLineCap;
+(nonnull instancetype)crossPlotLineCap;
+(nonnull instancetype)snowPlotLineCap;
+(nonnull instancetype)customLineCapWithPath:(nullable CGPathRef)aPath;
/// @}

/// @name Drawing
/// @{
-(void)renderAsVectorInContext:(nonnull CGContextRef)context atPoint:(CGPoint)center inDirection:(CGPoint)direction;
/// @}

@end

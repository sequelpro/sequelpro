#import "CPTDefinitions.h"

/**
 *  @brief Theme name type.
 **/
typedef NSString *CPTThemeName cpt_swift_struct;

/// @ingroup themeNames
/// @{
extern CPTThemeName __nonnull const kCPTDarkGradientTheme; ///< A graph theme with dark gray gradient backgrounds and light gray lines.
extern CPTThemeName __nonnull const kCPTPlainBlackTheme;   ///< A graph theme with black backgrounds and white lines.
extern CPTThemeName __nonnull const kCPTPlainWhiteTheme;   ///< A graph theme with white backgrounds and black lines.
extern CPTThemeName __nonnull const kCPTSlateTheme;        ///< A graph theme with colors that match the default iPhone navigation bar, toolbar buttons, and table views.
extern CPTThemeName __nonnull const kCPTStocksTheme;       ///< A graph theme with a gradient background and white lines.
/// @}

@class CPTGraph;
@class CPTPlotAreaFrame;
@class CPTAxisSet;
@class CPTMutableTextStyle;

@interface CPTTheme : NSObject<NSCoding, NSSecureCoding>

@property (nonatomic, readwrite, strong, nullable) Class graphClass;

/// @name Theme Management
/// @{
+(void)registerTheme:(nonnull Class)themeClass;
+(nullable NSArray<Class> *)themeClasses;
+(nullable instancetype)themeNamed:(nullable CPTThemeName)themeName;
+(nonnull CPTThemeName)name;
/// @}

/// @name Theme Usage
/// @{
-(void)applyThemeToGraph:(nonnull CPTGraph *)graph;
/// @}

@end

/** @category CPTTheme(AbstractMethods)
 *  @brief CPTTheme abstract methods—must be overridden by subclasses
 **/
@interface CPTTheme(AbstractMethods)

/// @name Theme Usage
/// @{
-(nullable id)newGraph;

-(void)applyThemeToBackground:(nonnull CPTGraph *)graph;
-(void)applyThemeToPlotArea:(nonnull CPTPlotAreaFrame *)plotAreaFrame;
-(void)applyThemeToAxisSet:(nonnull CPTAxisSet *)axisSet;
/// @}

@end

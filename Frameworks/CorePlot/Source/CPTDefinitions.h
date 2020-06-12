#import <Availability.h>
#import <TargetConditionals.h>

/// @file

/**
 *  @def CPT_SDK_SUPPORTS_WEAK
 *  @hideinitializer
 *  @brief Defined as @num{1} if the compiler and active SDK support weak references, @num{0} otherwise.
 **/

/**
 *  @def cpt_weak_property
 *  @hideinitializer
 *  @brief A custom definition for automatic reference counting (ARC) weak properties that falls back to
 *  <code>assign</code> on older platforms.
 **/

// This is based on Ryan Petrich's ZWRCompatibility: https://github.com/rpetrich/ZWRCompatibility

#if TARGET_OS_IPHONE && defined(__IPHONE_5_0) && (__IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_5_0) && __clang__ && (__clang_major__ >= 3)
#define CPT_SDK_SUPPORTS_WEAK 1
#elif TARGET_OS_MAC && defined(__MAC_10_7) && (MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_7) && __clang__ && (__clang_major__ >= 3)
#define CPT_SDK_SUPPORTS_WEAK 1
#else
#define CPT_SDK_SUPPORTS_WEAK 0
#endif

#if CPT_SDK_SUPPORTS_WEAK
#define cpt_weak_property weak
#else
#define cpt_weak_property unsafe_unretained
#endif

// Deprecated method attribute

/**
 *  @def cpt_deprecated
 *  @hideinitializer
 *  @brief Marks a method declaration as deprecated.
 **/

#define cpt_deprecated __attribute__((deprecated))

// Unused parameter attribute (DEBUG only)

/**
 *  @def cpt_unused
 *  @hideinitializer
 *  @brief Marks a parameter value as unused only in RELEASE builds.
 **/

#ifdef DEBUG
#define cpt_unused
#else
#define cpt_unused __unused
#endif

// Swift wrappers

/**
 *  @def cpt_swift_enum
 *  @hideinitializer
 *  @brief Marks a type definition to be imported into Swift as an enumeration.
 **/
#define cpt_swift_enum __attribute__((swift_wrapper(enum)))

/**
 *  @def cpt_swift_struct
 *  @hideinitializer
 *  @brief Marks a type definition to be imported into Swift as a structure.
 **/
#define cpt_swift_struct __attribute__((swift_wrapper(struct)))

// Type safety defines

/**
 *  @def CPTFloat
 *  @hideinitializer
 *  @param x The number to cast.
 *  @brief Casts a number to @ref CGFloat.
 **/
#define CPTFloat(x) ((CGFloat)(x))

/**
 *  @def CPTPointMake
 *  @hideinitializer
 *  @param x The x-coordinate of the point.
 *  @param y The y-coordinate of the point.
 *  @brief A replacement for @ref CGPointMake(), casting each parameter to @ref CGFloat.
 **/
#define CPTPointMake(x, y) CGPointMake((CGFloat)(x), (CGFloat)(y))

/**
 *  @def CPTSizeMake
 *  @hideinitializer
 *  @param w The width of the size.
 *  @param h The height of the size.
 *  @brief A replacement for @ref CGSizeMake(), casting each parameter to @ref CGFloat.
 **/
#define CPTSizeMake(w, h) CGSizeMake((CGFloat)(w), (CGFloat)(h))

/**
 *  @def CPTRectMake
 *  @hideinitializer
 *  @param x The x-coordinate of the rectangle.
 *  @param y The y-coordinate of the rectangle.
 *  @param w The width of the rectangle.
 *  @param h The height of the rectangle.
 *  @brief A replacement for @ref CGRectMake(), casting each parameter to @ref CGFloat.
 **/
#define CPTRectMake(x, y, w, h) CGRectMake((CGFloat)(x), (CGFloat)(y), (CGFloat)(w), (CGFloat)(h))

/**
 *  @def CPTRectInset
 *  @hideinitializer
 *  @param rect The rectangle to offset.
 *  @param dx The x-offset.
 *  @param dy The y-offset.
 *  @brief A replacement for @ref CGRectInset(), casting each offset parameter to @ref CGFloat.
 **/
#define CPTRectInset(rect, dx, dy) CGRectInset(rect, (CGFloat)(dx), (CGFloat)(dy))

/**
 *  @def CPTNAN
 *  @hideinitializer
 *  @brief The not-a-number constant (@NAN), cast to @ref CGFloat.
 **/
#define CPTNAN ((CGFloat)NAN)

/**
 *  @brief Enumeration of numeric types
 **/
typedef NS_ENUM (NSInteger, CPTNumericType) {
    CPTNumericTypeInteger, ///< Integer
    CPTNumericTypeFloat,   ///< Float
    CPTNumericTypeDouble   ///< Double
};

/**
 *  @brief Enumeration of error bar types
 **/
typedef NS_ENUM (NSInteger, CPTErrorBarType) {
    CPTErrorBarTypeCustom,        ///< Custom error bars
    CPTErrorBarTypeConstantRatio, ///< Constant ratio error bars
    CPTErrorBarTypeConstantValue  ///< Constant value error bars
};

/**
 *  @brief Enumeration of axis scale types
 **/
typedef NS_ENUM (NSInteger, CPTScaleType) {
    CPTScaleTypeLinear,    ///< Linear axis scale
    CPTScaleTypeLog,       ///< Logarithmic axis scale
    CPTScaleTypeAngular,   ///< Angular axis scale (not implemented)
    CPTScaleTypeDateTime,  ///< Date/time axis scale (not implemented)
    CPTScaleTypeCategory,  ///< Category axis scale
    CPTScaleTypeLogModulus ///< Log-modulus axis scale
};

/**
 *  @brief Enumeration of axis coordinates
 **/
typedef NS_ENUM (NSInteger, CPTCoordinate) {
    CPTCoordinateX    = 0,           ///< X axis
    CPTCoordinateY    = 1,           ///< Y axis
    CPTCoordinateZ    = 2,           ///< Z axis
    CPTCoordinateNone = NSIntegerMax ///< Invalid coordinate value
};

/**
 *  @brief RGBA color for gradients
 **/
typedef struct _CPTRGBAColor {
    CGFloat red;   ///< The red component (0 ≤ @par{red} ≤ 1).
    CGFloat green; ///< The green component (0 ≤ @par{green} ≤ 1).
    CGFloat blue;  ///< The blue component (0 ≤ @par{blue} ≤ 1).
    CGFloat alpha; ///< The alpha component (0 ≤ @par{alpha} ≤ 1).
}
CPTRGBAColor;

/**
 *  @brief Enumeration of label positioning offset directions
 **/
typedef NS_CLOSED_ENUM(NSInteger, CPTSign) {
    CPTSignNone     = 0,  ///< No offset
    CPTSignPositive = +1, ///< Positive offset
    CPTSignNegative = -1  ///< Negative offset
};

/**
 *  @brief Locations around the edge of a rectangle.
 **/
typedef NS_ENUM (NSInteger, CPTRectAnchor) {
    CPTRectAnchorBottomLeft,  ///< The bottom left corner
    CPTRectAnchorBottom,      ///< The bottom center
    CPTRectAnchorBottomRight, ///< The bottom right corner
    CPTRectAnchorLeft,        ///< The left middle
    CPTRectAnchorRight,       ///< The right middle
    CPTRectAnchorTopLeft,     ///< The top left corner
    CPTRectAnchorTop,         ///< The top center
    CPTRectAnchorTopRight,    ///< The top right
    CPTRectAnchorCenter       ///< The center of the rect
};

/**
 *  @brief Label and constraint alignment constants.
 **/
typedef NS_ENUM (NSInteger, CPTAlignment) {
    CPTAlignmentLeft,   ///< Align horizontally to the left side.
    CPTAlignmentCenter, ///< Align horizontally to the center.
    CPTAlignmentRight,  ///< Align horizontally to the right side.
    CPTAlignmentTop,    ///< Align vertically to the top.
    CPTAlignmentMiddle, ///< Align vertically to the middle.
    CPTAlignmentBottom  ///< Align vertically to the bottom.
};

/**
 *  @brief Edge inset distances for stretchable images.
 **/
typedef struct _CPTEdgeInsets {
    CGFloat top;    ///< The top inset.
    CGFloat left;   ///< The left inset.
    CGFloat bottom; ///< The bottom inset.
    CGFloat right;  ///< The right inset.
}
CPTEdgeInsets;

extern const CPTEdgeInsets CPTEdgeInsetsZero; ///< Defines a set of stretchable image edge insets where all of the values are zero (@num{0}).

extern const NSStringDrawingOptions CPTStringDrawingOptions; ///< String drawing options used when measuring and drawing text.

/**
 *  @brief An array of numbers.
 **/
typedef NSArray<NSNumber *> CPTNumberArray;

/**
 *  @brief A mutable array of numbers.
 **/
typedef NSMutableArray<NSNumber *> CPTMutableNumberArray;

/**
 *  @brief A set of numbers.
 **/
typedef NSSet<NSNumber *> CPTNumberSet;

/**
 *  @brief A mutable set of numbers.
 **/
typedef NSMutableSet<NSNumber *> CPTMutableNumberSet;

/**
 *  @brief An array of strings.
 **/
typedef NSArray<NSString *> CPTStringArray;

/**
 *  @brief A mutable array of strings.
 **/
typedef NSMutableArray<NSString *> CPTMutableStringArray;

/**
 *  @brief An array of values.
 **/
typedef NSArray<NSValue *> CPTValueArray;

/**
 *  @brief A mutable array of values.
 **/
typedef NSMutableArray<NSValue *> CPTMutableValueArray;

/**
 *  @brief An array of strings.
 **/
typedef NSDictionary<NSString *, id> CPTDictionary;

/**
 *  @brief A mutable array of strings.
 **/
typedef NSMutableDictionary<NSString *, id> CPTMutableDictionary;

/**
 *  @brief Render a Quick Look image into the given context.
 **/
typedef void (^CPTQuickLookImageBlock)(__nonnull CGContextRef context, CGFloat scale, CGRect bounds);

#import <QuartzCore/QuartzCore.h>

@class CPTAnimationOperation;
@class CPTAnimationPeriod;

/**
 *  @brief Enumeration of animation curves.
 **/
typedef NS_ENUM (NSInteger, CPTAnimationCurve) {
    CPTAnimationCurveDefault,          ///< Use the default animation curve.
    CPTAnimationCurveLinear,           ///< Linear animation curve.
    CPTAnimationCurveBackIn,           ///< Backing in animation curve.
    CPTAnimationCurveBackOut,          ///< Backing out animation curve.
    CPTAnimationCurveBackInOut,        ///< Backing in and out animation curve.
    CPTAnimationCurveBounceIn,         ///< Bounce in animation curve.
    CPTAnimationCurveBounceOut,        ///< Bounce out animation curve.
    CPTAnimationCurveBounceInOut,      ///< Bounce in and out animation curve.
    CPTAnimationCurveCircularIn,       ///< Circular in animation curve.
    CPTAnimationCurveCircularOut,      ///< Circular out animation curve.
    CPTAnimationCurveCircularInOut,    ///< Circular in and out animation curve.
    CPTAnimationCurveElasticIn,        ///< Elastic in animation curve.
    CPTAnimationCurveElasticOut,       ///< Elastic out animation curve.
    CPTAnimationCurveElasticInOut,     ///< Elastic in and out animation curve.
    CPTAnimationCurveExponentialIn,    ///< Exponential in animation curve.
    CPTAnimationCurveExponentialOut,   ///< Exponential out animation curve.
    CPTAnimationCurveExponentialInOut, ///< Exponential in and out animation curve.
    CPTAnimationCurveSinusoidalIn,     ///< Sinusoidal in animation curve.
    CPTAnimationCurveSinusoidalOut,    ///< Sinusoidal out animation curve.
    CPTAnimationCurveSinusoidalInOut,  ///< Sinusoidal in and out animation curve.
    CPTAnimationCurveCubicIn,          ///< Cubic in animation curve.
    CPTAnimationCurveCubicOut,         ///< Cubic out animation curve.
    CPTAnimationCurveCubicInOut,       ///< Cubic in and out animation curve.
    CPTAnimationCurveQuadraticIn,      ///< Quadratic in animation curve.
    CPTAnimationCurveQuadraticOut,     ///< Quadratic out animation curve.
    CPTAnimationCurveQuadraticInOut,   ///< Quadratic in and out animation curve.
    CPTAnimationCurveQuarticIn,        ///< Quartic in animation curve.
    CPTAnimationCurveQuarticOut,       ///< Quartic out animation curve.
    CPTAnimationCurveQuarticInOut,     ///< Quartic in and out animation curve.
    CPTAnimationCurveQuinticIn,        ///< Quintic in animation curve.
    CPTAnimationCurveQuinticOut,       ///< Quintic out animation curve.
    CPTAnimationCurveQuinticInOut      ///< Quintic in and out animation curve.
};

#pragma mark -

/**
 *  @brief Animation delegate.
 **/
#if ((TARGET_OS_SIMULATOR || TARGET_OS_IPHONE || TARGET_OS_TV) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= 100000)) \
    || (TARGET_OS_MAC && (MAC_OS_X_VERSION_MAX_ALLOWED >= 101200))
// CAAnimationDelegate is defined by Core Animation in iOS 10.0+, macOS 10.12+, and tvOS 10.0+
@protocol CPTAnimationDelegate<CAAnimationDelegate>
#else
@protocol CPTAnimationDelegate<NSObject>
#endif

@optional

/// @name Animation
/// @{

/** @brief @optional Informs the delegate that an animation operation started animating.
 *  @param operation The animation operation.
 **/
-(void)animationDidStart:(nonnull CPTAnimationOperation *)operation;

/** @brief @optional Informs the delegate that an animation operation stopped after reaching its full duration.
 *  @param operation The animation operation.
 **/
-(void)animationDidFinish:(nonnull CPTAnimationOperation *)operation;

/** @brief @optional Informs the delegate that an animation operation was stopped before reaching its full duration.
 *  @param operation The animation operation.
 **/
-(void)animationCancelled:(nonnull CPTAnimationOperation *)operation;

/** @brief @optional Informs the delegate that the animated property is about to update.
 *  @param operation The animation operation.
 **/
-(void)animationWillUpdate:(nonnull CPTAnimationOperation *)operation;

/** @brief @optional Informs the delegate that the animated property has been updated.
 *  @param operation The animation operation.
 **/
-(void)animationDidUpdate:(nonnull CPTAnimationOperation *)operation;

/// @}

@end

#pragma mark -

@interface CPTAnimation : NSObject

/// @name Time
/// @{
@property (nonatomic, readonly) CGFloat timeOffset;
/// @}

/// @name Animation Curve
/// @{
@property (nonatomic, assign) CPTAnimationCurve defaultAnimationCurve;
/// @}

/// @name Animation Controller Instance
/// @{
+(nonnull instancetype)sharedInstance;
/// @}

/// @name Property Animation
/// @{
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property period:(nonnull CPTAnimationPeriod *)period animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
/// @}

/// @name Animation Management
/// @{
-(nonnull CPTAnimationOperation *)addAnimationOperation:(nonnull CPTAnimationOperation *)animationOperation;
-(void)removeAnimationOperation:(nullable CPTAnimationOperation *)animationOperation;
-(void)removeAllAnimationOperations;
/// @}

/// @name Retrieving Animation Operations
/// @{
-(nullable CPTAnimationOperation *)operationWithIdentifier:(nullable id<NSCopying, NSObject>)identifier;
/// @}

@end

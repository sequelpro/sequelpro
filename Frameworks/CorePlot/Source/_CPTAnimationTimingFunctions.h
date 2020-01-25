/// @file

typedef CGFloat (*CPTAnimationTimingFunction)(CGFloat, CGFloat);

#if __cplusplus
extern "C" {
#endif

/// @name Linear
/// @{
CGFloat CPTAnimationTimingFunctionLinear(CGFloat time, CGFloat duration);

/// @}

/// @name Backing
/// @{
CGFloat CPTAnimationTimingFunctionBackIn(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionBackOut(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionBackInOut(CGFloat time, CGFloat duration);

/// @}

/// @name Bounce
/// @{
CGFloat CPTAnimationTimingFunctionBounceIn(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionBounceOut(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionBounceInOut(CGFloat time, CGFloat duration);

/// @}

/// @name Circular
/// @{
CGFloat CPTAnimationTimingFunctionCircularIn(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionCircularOut(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionCircularInOut(CGFloat time, CGFloat duration);

/// @}

/// @name Elastic
/// @{
CGFloat CPTAnimationTimingFunctionElasticIn(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionElasticOut(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionElasticInOut(CGFloat time, CGFloat duration);

/// @}

/// @name Exponential
/// @{
CGFloat CPTAnimationTimingFunctionExponentialIn(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionExponentialOut(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionExponentialInOut(CGFloat time, CGFloat duration);

/// @}

/// @name Sinusoidal
/// @{
CGFloat CPTAnimationTimingFunctionSinusoidalIn(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionSinusoidalOut(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionSinusoidalInOut(CGFloat time, CGFloat duration);

/// @}

/// @name Cubic
/// @{
CGFloat CPTAnimationTimingFunctionCubicIn(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionCubicOut(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionCubicInOut(CGFloat time, CGFloat duration);

/// @}

/// @name Quadratic
/// @{
CGFloat CPTAnimationTimingFunctionQuadraticIn(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionQuadraticOut(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionQuadraticInOut(CGFloat time, CGFloat duration);

/// @}

/// @name Quartic
/// @{
CGFloat CPTAnimationTimingFunctionQuarticIn(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionQuarticOut(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionQuarticInOut(CGFloat time, CGFloat duration);

/// @}

/// @name Quintic
/// @{
CGFloat CPTAnimationTimingFunctionQuinticIn(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionQuinticOut(CGFloat time, CGFloat duration);
CGFloat CPTAnimationTimingFunctionQuinticInOut(CGFloat time, CGFloat duration);

/// @}

#if __cplusplus
}
#endif

#import "_CPTAnimationTimingFunctions.h"

#import "CPTDefinitions.h"
#import <tgmath.h>

// elapsedTime should be between 0 and duration for all timing functions

#pragma mark Linear

/**
 *  @brief Computes a linear animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionLinear(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    return elapsedTime;
}

#pragma mark -
#pragma mark Back

/**
 *  @brief Computes a backing in animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionBackIn(CGFloat elapsedTime, CGFloat duration)
{
    const CGFloat s = CPTFloat(1.70158);

    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    return elapsedTime * elapsedTime * ((s + CPTFloat(1.0)) * elapsedTime - s);
}

/**
 *  @brief Computes a backing out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionBackOut(CGFloat elapsedTime, CGFloat duration)
{
    const CGFloat s = CPTFloat(1.70158);

    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime = elapsedTime / duration - CPTFloat(1.0);

    if ( elapsedTime >= CPTFloat(0.0)) {
        return CPTFloat(1.0);
    }

    return elapsedTime * elapsedTime * ((s + CPTFloat(1.0)) * elapsedTime + s) + CPTFloat(1.0);
}

/**
 *  @brief Computes a backing in and out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionBackInOut(CGFloat elapsedTime, CGFloat duration)
{
    const CGFloat s = CPTFloat(1.70158 * 1.525);

    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration * CPTFloat(0.5);

    if ( elapsedTime >= CPTFloat(2.0)) {
        return CPTFloat(1.0);
    }

    if ( elapsedTime < CPTFloat(1.0)) {
        return CPTFloat(0.5) * (elapsedTime * elapsedTime * ((s + CPTFloat(1.0)) * elapsedTime - s));
    }
    else {
        elapsedTime -= CPTFloat(2.0);

        return CPTFloat(0.5) * (elapsedTime * elapsedTime * ((s + CPTFloat(1.0)) * elapsedTime + s) + CPTFloat(2.0));
    }
}

#pragma mark -
#pragma mark Bounce

/**
 *  @brief Computes a bounce in animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionBounceIn(CGFloat elapsedTime, CGFloat duration)
{
    return CPTFloat(1.0) - CPTAnimationTimingFunctionBounceOut(duration - elapsedTime, duration);
}

/**
 *  @brief Computes a bounce out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionBounceOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    if ( elapsedTime < CPTFloat(1.0 / 2.75)) {
        return CPTFloat(7.5625) * elapsedTime * elapsedTime;
    }
    else if ( elapsedTime < CPTFloat(2.0 / 2.75)) {
        elapsedTime -= CPTFloat(1.5 / 2.75);

        return CPTFloat(7.5625) * elapsedTime * elapsedTime + CPTFloat(0.75);
    }
    else if ( elapsedTime < CPTFloat(2.5 / 2.75)) {
        elapsedTime -= CPTFloat(2.25 / 2.75);

        return CPTFloat(7.5625) * elapsedTime * elapsedTime + CPTFloat(0.9375);
    }
    else {
        elapsedTime -= CPTFloat(2.625 / 2.75);

        return CPTFloat(7.5625) * elapsedTime * elapsedTime + CPTFloat(0.984375);
    }
}

/**
 *  @brief Computes a bounce in and out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionBounceInOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime < duration * CPTFloat(0.5)) {
        return CPTAnimationTimingFunctionBounceIn(elapsedTime * CPTFloat(2.0), duration) * CPTFloat(0.5);
    }
    else {
        return CPTAnimationTimingFunctionBounceOut(elapsedTime * CPTFloat(2.0) - duration, duration) * CPTFloat(0.5) +
               CPTFloat(0.5);
    }
}

#pragma mark -
#pragma mark Circular

/**
 *  @brief Computes a circular in animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionCircularIn(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    return -(sqrt(CPTFloat(1.0) - elapsedTime * elapsedTime) - CPTFloat(1.0));
}

/**
 *  @brief Computes a circular out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionCircularOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime = elapsedTime / duration - CPTFloat(1.0);

    if ( elapsedTime >= CPTFloat(0.0)) {
        return CPTFloat(1.0);
    }

    return sqrt(CPTFloat(1.0) - elapsedTime * elapsedTime);
}

/**
 *  @brief Computes a circular in and out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionCircularInOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration * CPTFloat(0.5);

    if ( elapsedTime >= CPTFloat(2.0)) {
        return CPTFloat(1.0);
    }

    if ( elapsedTime < CPTFloat(1.0)) {
        return CPTFloat(-0.5) * (sqrt(CPTFloat(1.0) - elapsedTime * elapsedTime) - CPTFloat(1.0));
    }
    else {
        elapsedTime -= CPTFloat(2.0);

        return CPTFloat(0.5) * (sqrt(CPTFloat(1.0) - elapsedTime * elapsedTime) + CPTFloat(1.0));
    }
}

#pragma mark -
#pragma mark Elastic

/**
 *  @brief Computes a elastic in animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionElasticIn(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    CGFloat period = duration * CPTFloat(0.3);
    CGFloat s      = period * CPTFloat(0.25);

    elapsedTime -= CPTFloat(1.0);

    return -(pow(CPTFloat(2.0), CPTFloat(10.0) * elapsedTime) * sin((elapsedTime * duration - s) * CPTFloat(2.0 * M_PI) / period));
}

/**
 *  @brief Computes a elastic out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionElasticOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    CGFloat period = duration * CPTFloat(0.3);
    CGFloat s      = period * CPTFloat(0.25);

    return pow(CPTFloat(2.0), CPTFloat(-10.0) * elapsedTime) * sin((elapsedTime * duration - s) * CPTFloat(2.0 * M_PI) / period) + CPTFloat(1.0);
}

/**
 *  @brief Computes a elastic in and out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionElasticInOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration * CPTFloat(0.5);

    if ( elapsedTime >= CPTFloat(2.0)) {
        return CPTFloat(1.0);
    }

    CGFloat period = duration * CPTFloat(0.3 * 1.5);
    CGFloat s      = period * CPTFloat(0.25);

    elapsedTime -= CPTFloat(1.0);

    if ( elapsedTime < CPTFloat(0.0)) {
        return CPTFloat(-0.5) * (pow(CPTFloat(2.0), CPTFloat(10.0) * elapsedTime) * sin((elapsedTime * duration - s) * CPTFloat(2.0 * M_PI) / period));
    }
    else {
        return pow(CPTFloat(2.0), CPTFloat(-10.0) * elapsedTime) * sin((elapsedTime * duration - s) * CPTFloat(2.0 * M_PI) / period) * CPTFloat(0.5) + CPTFloat(1.0);
    }
}

#pragma mark -
#pragma mark Exponential

/**
 *  @brief Computes a exponential in animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionExponentialIn(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    return pow(CPTFloat(2.0), CPTFloat(10.0) * (elapsedTime - CPTFloat(1.0)));
}

/**
 *  @brief Computes a exponential out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionExponentialOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    return -pow(CPTFloat(2.0), CPTFloat(-10.0) * elapsedTime) + CPTFloat(1.0);
}

/**
 *  @brief Computes a exponential in and out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionExponentialInOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration * CPTFloat(0.5);
    elapsedTime -= CPTFloat(1.0);

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    if ( elapsedTime < CPTFloat(0.0)) {
        return CPTFloat(0.5) * pow(CPTFloat(2.0), CPTFloat(10.0) * elapsedTime);
    }
    else {
        return CPTFloat(0.5) * (-pow(CPTFloat(2.0), CPTFloat(-10.0) * elapsedTime) + CPTFloat(2.0));
    }
}

#pragma mark -
#pragma mark Sinusoidal

/**
 *  @brief Computes a sinusoidal in animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionSinusoidalIn(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    return -cos(elapsedTime * CPTFloat(M_PI_2)) + CPTFloat(1.0);
}

/**
 *  @brief Computes a sinusoidal out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionSinusoidalOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    return sin(elapsedTime * CPTFloat(M_PI_2));
}

/**
 *  @brief Computes a sinusoidal in and out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionSinusoidalInOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    return CPTFloat(-0.5) * (cos(CPTFloat(M_PI) * elapsedTime) - CPTFloat(1.0));
}

#pragma mark -
#pragma mark Cubic

/**
 *  @brief Computes a cubic in animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionCubicIn(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    return elapsedTime * elapsedTime * elapsedTime;
}

/**
 *  @brief Computes a cubic out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionCubicOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime = elapsedTime / duration - CPTFloat(1.0);

    if ( elapsedTime >= CPTFloat(0.0)) {
        return CPTFloat(1.0);
    }

    return elapsedTime * elapsedTime * elapsedTime + CPTFloat(1.0);
}

/**
 *  @brief Computes a cubic in and out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionCubicInOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration * CPTFloat(0.5);

    if ( elapsedTime >= CPTFloat(2.0)) {
        return CPTFloat(1.0);
    }

    if ( elapsedTime < CPTFloat(1.0)) {
        return CPTFloat(0.5) * elapsedTime * elapsedTime * elapsedTime;
    }
    else {
        elapsedTime -= CPTFloat(2.0);

        return CPTFloat(0.5) * (elapsedTime * elapsedTime * elapsedTime + CPTFloat(2.0));
    }
}

#pragma mark -
#pragma mark Quadratic

/**
 *  @brief Computes a quadratic in animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionQuadraticIn(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    return elapsedTime * elapsedTime;
}

/**
 *  @brief Computes a quadratic out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionQuadraticOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    return -elapsedTime * (elapsedTime - CPTFloat(2.0));
}

/**
 *  @brief Computes a quadratic in and out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionQuadraticInOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration * CPTFloat(0.5);

    if ( elapsedTime >= CPTFloat(2.0)) {
        return CPTFloat(1.0);
    }

    if ( elapsedTime < CPTFloat(1.0)) {
        return CPTFloat(0.5) * elapsedTime * elapsedTime;
    }
    else {
        elapsedTime -= CPTFloat(1.0);

        return CPTFloat(-0.5) * (elapsedTime * (elapsedTime - CPTFloat(2.0)) - CPTFloat(1.0));
    }
}

#pragma mark -
#pragma mark Quartic

/**
 *  @brief Computes a quartic in animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionQuarticIn(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    return elapsedTime * elapsedTime * elapsedTime * elapsedTime;
}

/**
 *  @brief Computes a quartic out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionQuarticOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime = elapsedTime / duration - CPTFloat(1.0);

    if ( elapsedTime >= CPTFloat(0.0)) {
        return CPTFloat(1.0);
    }

    return -(elapsedTime * elapsedTime * elapsedTime * elapsedTime - CPTFloat(1.0));
}

/**
 *  @brief Computes a quartic in and out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionQuarticInOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration * CPTFloat(0.5);

    if ( elapsedTime >= CPTFloat(2.0)) {
        return CPTFloat(1.0);
    }

    if ( elapsedTime < CPTFloat(1.0)) {
        return CPTFloat(0.5) * elapsedTime * elapsedTime * elapsedTime * elapsedTime;
    }
    else {
        elapsedTime -= CPTFloat(2.0);

        return CPTFloat(-0.5) * (elapsedTime * elapsedTime * elapsedTime * elapsedTime - CPTFloat(2.0));
    }
}

#pragma mark -
#pragma mark Quintic

/**
 *  @brief Computes a quintic in animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionQuinticIn(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration;

    if ( elapsedTime >= CPTFloat(1.0)) {
        return CPTFloat(1.0);
    }

    return elapsedTime * elapsedTime * elapsedTime * elapsedTime * elapsedTime;
}

/**
 *  @brief Computes a quintic out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionQuinticOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime = elapsedTime / duration - CPTFloat(1.0);

    if ( elapsedTime >= CPTFloat(0.0)) {
        return CPTFloat(1.0);
    }

    return elapsedTime * elapsedTime * elapsedTime * elapsedTime * elapsedTime + CPTFloat(1.0);
}

/**
 *  @brief Computes a quintic in and out animation timing function.
 *  @param elapsedTime The elapsed time of the animation between zero (@num{0}) and @par{duration}.
 *  @param duration The overall duration of the animation in seconds.
 *  @return The animation progress in the range zero (@num{0}) to one (@num{1}) at the given @par{elapsedTime}.
 **/
CGFloat CPTAnimationTimingFunctionQuinticInOut(CGFloat elapsedTime, CGFloat duration)
{
    if ( elapsedTime <= CPTFloat(0.0)) {
        return CPTFloat(0.0);
    }

    elapsedTime /= duration * CPTFloat(0.5);

    if ( elapsedTime >= CPTFloat(2.0)) {
        return CPTFloat(1.0);
    }

    if ( elapsedTime < CPTFloat(1.0)) {
        return CPTFloat(0.5) * elapsedTime * elapsedTime * elapsedTime * elapsedTime * elapsedTime;
    }
    else {
        elapsedTime -= CPTFloat(2.0);

        return CPTFloat(0.5) * (elapsedTime * elapsedTime * elapsedTime * elapsedTime * elapsedTime + CPTFloat(2.0));
    }
}

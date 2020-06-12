#import "CPTAxisLabelGroup.h"

/**
 *  @brief A container layer for the axis labels.
 **/
@implementation CPTAxisLabelGroup

#pragma mark -
#pragma mark Drawing

/// @cond

-(void)display
{
    // nothing to draw
}

-(void)renderAsVectorInContext:(nonnull CGContextRef __unused)context
{
    // nothing to draw
}

/// @endcond

#pragma mark -
#pragma mark Layout

/// @name Layout
/// @{

/**
 *  @brief Updates the layout of all sublayers. No layout is done—each axis is responsible for positioning its labels.
 *
 *  This is where we do our custom replacement for the Mac-only layout manager and autoresizing mask.
 *  Subclasses should override this method to provide a different layout of their own sublayers.
 **/
-(void)layoutSublayers
{
    // do nothing--axis is responsible for positioning its labels
}

/// @}

@end

#import "CPTGraphHostingView.h"

#import "CPTGraph.h"
#import "CPTPlotArea.h"
#import "CPTPlotAreaFrame.h"
#import "CPTPlotSpace.h"

/// @cond

static void *CPTGraphHostingViewKVOContext = (void *)&CPTGraphHostingViewKVOContext;

@interface CPTGraphHostingView()

@property (nonatomic, readwrite) NSPoint locationInWindow;
@property (nonatomic, readwrite) CGPoint scrollOffset;

-(void)plotSpaceAdded:(nonnull NSNotification *)notification;
-(void)plotSpaceRemoved:(nonnull NSNotification *)notification;
-(void)plotAreaBoundsChanged;

@end

/// @endcond

#pragma mark -

/**
 *  @brief A container view for displaying a CPTGraph.
 **/
@implementation CPTGraphHostingView

/** @property nullable CPTGraph *hostedGraph
 *  @brief The CPTGraph hosted inside this view.
 **/
@synthesize hostedGraph;

/** @property NSRect printRect
 *  @brief The bounding rectangle used when printing this view. Default is NSZeroRect.
 *
 *  If NSZeroRect (the default), the frame rectangle of the view is used instead.
 **/
@synthesize printRect;

/** @property nullable NSCursor *closedHandCursor
 *  @brief The cursor displayed when the user is actively dragging any plot space.
 **/
@synthesize closedHandCursor;

/** @property nullable NSCursor *openHandCursor
 *  @brief The cursor displayed when the mouse pointer is over a plot area mapped to a plot space that allows user interaction, but not actively being dragged.
 **/
@synthesize openHandCursor;

/** @property BOOL allowPinchScaling
 *  @brief Whether a pinch gesture will trigger plot space scaling. Default is @YES.
 **/
@synthesize allowPinchScaling;

@synthesize locationInWindow;
@synthesize scrollOffset;

/// @cond

-(void)commonInit
{
    self.hostedGraph = nil;
    self.printRect   = NSZeroRect;

    self.closedHandCursor  = [NSCursor closedHandCursor];
    self.openHandCursor    = [NSCursor openHandCursor];
    self.allowPinchScaling = YES;

    self.locationInWindow = NSZeroPoint;
    self.scrollOffset     = CGPointZero;

    [self addObserver:self
           forKeyPath:@"effectiveAppearance"
              options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionInitial
              context:CPTGraphHostingViewKVOContext];

    if ( !self.superview.wantsLayer ) {
        self.layer = [self makeBackingLayer];
    }
}

-(nonnull instancetype)initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        [self commonInit];
    }
    return self;
}

-(nonnull CALayer *)makeBackingLayer
{
    return [[CPTLayer alloc] initWithFrame:NSRectToCGRect(self.bounds)];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [hostedGraph removeObserver:self forKeyPath:@"plotAreaFrame" context:CPTGraphHostingViewKVOContext];
    [hostedGraph.plotAreaFrame removeObserver:self forKeyPath:@"plotArea" context:CPTGraphHostingViewKVOContext];

    for ( CPTPlotSpace *space in hostedGraph.allPlotSpaces ) {
        [space removeObserver:self forKeyPath:@"isDragging" context:CPTGraphHostingViewKVOContext];
    }

    [self removeObserver:self forKeyPath:@"effectiveAppearance" context:CPTGraphHostingViewKVOContext];

    [hostedGraph removeFromSuperlayer];
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeObject:self.hostedGraph forKey:@"CPTLayerHostingView.hostedGraph"];
    [coder encodeRect:self.printRect forKey:@"CPTLayerHostingView.printRect"];
    [coder encodeObject:self.closedHandCursor forKey:@"CPTLayerHostingView.closedHandCursor"];
    [coder encodeObject:self.openHandCursor forKey:@"CPTLayerHostingView.openHandCursor"];
    [coder encodeBool:self.allowPinchScaling forKey:@"CPTLayerHostingView.allowPinchScaling"];

    // No need to archive these properties:
    // locationInWindow
    // scrollOffset
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        [self commonInit];

        self.hostedGraph = [coder decodeObjectOfClass:[CPTGraph class]
                                               forKey:@"CPTLayerHostingView.hostedGraph"]; // setup layers
        self.printRect        = [coder decodeRectForKey:@"CPTLayerHostingView.printRect"];
        self.closedHandCursor = [coder decodeObjectOfClass:[NSCursor class]
                                                    forKey:@"CPTLayerHostingView.closedHandCursor"];
        self.openHandCursor = [coder decodeObjectOfClass:[NSCursor class]
                                                  forKey:@"CPTLayerHostingView.openHandCursor"];

        if ( [coder containsValueForKey:@"CPTLayerHostingView.allowPinchScaling"] ) {
            self.allowPinchScaling = [coder decodeBoolForKey:@"CPTLayerHostingView.allowPinchScaling"];
        }
    }
    return self;
}

/// @endcond

#pragma mark -
#pragma mark NSSecureCoding Methods

/// @cond

+(BOOL)supportsSecureCoding
{
    return YES;
}

/// @endcond

#pragma mark -
#pragma mark Drawing

/// @cond

-(void)drawRect:(NSRect __unused)dirtyRect
{
    if ( self.hostedGraph ) {
        if ( ![NSGraphicsContext currentContextDrawingToScreen] ) {
            [self viewDidChangeBackingProperties];

            NSGraphicsContext *graphicsContext = [NSGraphicsContext currentContext];

            [graphicsContext saveGraphicsState];

            CGRect sourceRect      = NSRectToCGRect(self.frame);
            CGRect destinationRect = NSRectToCGRect(self.printRect);
            if ( CGRectEqualToRect(destinationRect, CGRectZero)) {
                destinationRect = sourceRect;
            }

            // scale the view isotropically so that it fits on the printed page
            CGFloat widthScale  = (sourceRect.size.width != CPTFloat(0.0)) ? destinationRect.size.width / sourceRect.size.width : CPTFloat(1.0);
            CGFloat heightScale = (sourceRect.size.height != CPTFloat(0.0)) ? destinationRect.size.height / sourceRect.size.height : CPTFloat(1.0);
            CGFloat scale       = MIN(widthScale, heightScale);

            // position the view so that its centered on the printed page
            CGPoint offset = destinationRect.origin;
            offset.x += ((destinationRect.size.width - (sourceRect.size.width * scale)) / CPTFloat(2.0));
            offset.y += ((destinationRect.size.height - (sourceRect.size.height * scale)) / CPTFloat(2.0));

            NSAffineTransform *transform = [NSAffineTransform transform];
            [transform translateXBy:offset.x yBy:offset.y];
            [transform scaleBy:scale];
            [transform concat];

            // render CPTLayers recursively into the graphics context used for printing
            // (thanks to Brad for the tip: http://stackoverflow.com/a/2791305/132867 )
            CGContextRef context = graphicsContext.graphicsPort;
            [self.hostedGraph recursivelyRenderInContext:context];

            [graphicsContext restoreGraphicsState];
        }
    }
}

/// @endcond

#pragma mark -
#pragma mark Printing

/// @cond

-(BOOL)knowsPageRange:(nonnull NSRangePointer)rangePointer
{
    rangePointer->location = 1;
    rangePointer->length   = 1;

    return YES;
}

-(NSRect)rectForPage:(NSInteger __unused)pageNumber
{
    return self.printRect;
}

/// @endcond

#pragma mark -
#pragma mark Mouse handling

/// @cond

-(BOOL)acceptsFirstMouse:(nullable NSEvent *__unused)theEvent
{
    return YES;
}

-(void)mouseDown:(nonnull NSEvent *)theEvent
{
    [super mouseDown:theEvent];

    CPTGraph *theGraph = self.hostedGraph;
    BOOL handled       = NO;

    if ( theGraph ) {
        CGPoint pointOfMouseDown   = NSPointToCGPoint([self convertPoint:theEvent.locationInWindow fromView:nil]);
        CGPoint pointInHostedGraph = [self.layer convertPoint:pointOfMouseDown toLayer:theGraph];
        handled = [theGraph pointingDeviceDownEvent:theEvent atPoint:pointInHostedGraph];
    }

    if ( !handled ) {
        [self.nextResponder mouseDown:theEvent];
    }
}

-(void)mouseDragged:(nonnull NSEvent *)theEvent
{
    CPTGraph *theGraph = self.hostedGraph;
    BOOL handled       = NO;

    if ( theGraph ) {
        CGPoint pointOfMouseDrag   = NSPointToCGPoint([self convertPoint:theEvent.locationInWindow fromView:nil]);
        CGPoint pointInHostedGraph = [self.layer convertPoint:pointOfMouseDrag toLayer:theGraph];
        handled = [theGraph pointingDeviceDraggedEvent:theEvent atPoint:pointInHostedGraph];
    }

    if ( !handled ) {
        [self.nextResponder mouseDragged:theEvent];
    }
}

-(void)mouseUp:(nonnull NSEvent *)theEvent
{
    CPTGraph *theGraph = self.hostedGraph;
    BOOL handled       = NO;

    if ( theGraph ) {
        CGPoint pointOfMouseUp     = NSPointToCGPoint([self convertPoint:theEvent.locationInWindow fromView:nil]);
        CGPoint pointInHostedGraph = [self.layer convertPoint:pointOfMouseUp toLayer:theGraph];
        handled = [theGraph pointingDeviceUpEvent:theEvent atPoint:pointInHostedGraph];
    }

    if ( !handled ) {
        [self.nextResponder mouseUp:theEvent];
    }
}

/// @endcond

#pragma mark -
#pragma mark Trackpad handling

/// @cond

-(void)magnifyWithEvent:(nonnull NSEvent *)event
{
    CPTGraph *theGraph = self.hostedGraph;
    BOOL handled       = NO;

    if ( theGraph && self.allowPinchScaling ) {
        CGPoint pointOfMagnification = NSPointToCGPoint([self convertPoint:event.locationInWindow fromView:nil]);
        CGPoint pointInHostedGraph   = [self.layer convertPoint:pointOfMagnification toLayer:theGraph];
        CGPoint pointInPlotArea      = [theGraph convertPoint:pointInHostedGraph toLayer:theGraph.plotAreaFrame.plotArea];

        CGFloat scale = event.magnification + CPTFloat(1.0);

        for ( CPTPlotSpace *space in theGraph.allPlotSpaces ) {
            if ( space.allowsUserInteraction ) {
                [space scaleBy:scale aboutPoint:pointInPlotArea];
                handled = YES;
            }
        }
    }

    if ( !handled ) {
        [self.nextResponder magnifyWithEvent:event];
    }
}

-(void)scrollWheel:(nonnull NSEvent *)theEvent
{
    CPTGraph *theGraph = self.hostedGraph;
    BOOL handled       = NO;

    if ( theGraph ) {
        switch ( theEvent.phase ) {
            case NSEventPhaseBegan: // Trackpad with no momentum scrolling. Fingers moved on trackpad.
            {
                self.locationInWindow = theEvent.locationInWindow;
                self.scrollOffset     = CGPointZero;

                CGPoint pointOfMouseDown   = NSPointToCGPoint([self convertPoint:self.locationInWindow fromView:nil]);
                CGPoint pointInHostedGraph = [self.layer convertPoint:pointOfMouseDown toLayer:theGraph];
                handled = [theGraph pointingDeviceDownEvent:theEvent atPoint:pointInHostedGraph];
            }
            // Fall through

            case NSEventPhaseChanged:
            {
                CGPoint offset = self.scrollOffset;
                offset.x         += theEvent.scrollingDeltaX;
                offset.y         -= theEvent.scrollingDeltaY;
                self.scrollOffset = offset;

                NSPoint scrolledPointOfMouse = self.locationInWindow;
                scrolledPointOfMouse.x += offset.x;
                scrolledPointOfMouse.y += offset.y;

                CGPoint pointOfMouseDrag   = NSPointToCGPoint([self convertPoint:scrolledPointOfMouse fromView:nil]);
                CGPoint pointInHostedGraph = [self.layer convertPoint:pointOfMouseDrag toLayer:theGraph];
                handled = handled || [theGraph pointingDeviceDraggedEvent:theEvent atPoint:pointInHostedGraph];
            }
            break;

            case NSEventPhaseEnded:
            {
                CGPoint offset = self.scrollOffset;

                NSPoint scrolledPointOfMouse = self.locationInWindow;
                scrolledPointOfMouse.x += offset.x;
                scrolledPointOfMouse.y += offset.y;

                CGPoint pointOfMouseUp     = NSPointToCGPoint([self convertPoint:scrolledPointOfMouse fromView:nil]);
                CGPoint pointInHostedGraph = [self.layer convertPoint:pointOfMouseUp toLayer:theGraph];
                handled = [theGraph pointingDeviceUpEvent:theEvent atPoint:pointInHostedGraph];
            }
            break;

            case NSEventPhaseNone:
                if ( theEvent.momentumPhase == NSEventPhaseNone ) {
                    // Mouse wheel
                    CGPoint startLocation      = theEvent.locationInWindow;
                    CGPoint pointOfMouse       = NSPointToCGPoint([self convertPoint:startLocation fromView:nil]);
                    CGPoint pointInHostedGraph = [self.layer convertPoint:pointOfMouse toLayer:theGraph];

                    CGPoint scrolledLocationInWindow = startLocation;
                    if ( theEvent.hasPreciseScrollingDeltas ) {
                        scrolledLocationInWindow.x += theEvent.scrollingDeltaX;
                        scrolledLocationInWindow.y -= theEvent.scrollingDeltaY;
                    }
                    else {
                        scrolledLocationInWindow.x += theEvent.scrollingDeltaX * CPTFloat(10.0);
                        scrolledLocationInWindow.y -= theEvent.scrollingDeltaY * CPTFloat(10.0);
                    }
                    CGPoint scrolledPointOfMouse       = NSPointToCGPoint([self convertPoint:scrolledLocationInWindow fromView:nil]);
                    CGPoint scrolledPointInHostedGraph = [self.layer convertPoint:scrolledPointOfMouse toLayer:theGraph];

                    handled = [theGraph scrollWheelEvent:theEvent fromPoint:pointInHostedGraph toPoint:scrolledPointInHostedGraph];
                }
                break;

            default:
                break;
        }
    }

    if ( !handled ) {
        [self.nextResponder scrollWheel:theEvent];
    }
}

/// @endcond

#pragma mark -
#pragma mark HiDPI display support

/// @cond

-(void)viewDidChangeBackingProperties
{
    [super viewDidChangeBackingProperties];

    NSWindow *myWindow = self.window;

    if ( myWindow ) {
        self.layer.contentsScale = myWindow.backingScaleFactor;
    }
    else {
        self.layer.contentsScale = CPTFloat(1.0);
    }
}

/// @endcond

#pragma mark -
#pragma mark Cursor management

/// @cond

-(void)resetCursorRects
{
    [super resetCursorRects];

    CPTGraph *theGraph    = self.hostedGraph;
    CPTPlotArea *plotArea = theGraph.plotAreaFrame.plotArea;

    NSCursor *closedCursor = self.closedHandCursor;
    NSCursor *openCursor   = self.openHandCursor;

    if ( plotArea && (closedCursor || openCursor)) {
        BOOL allowsInteraction = NO;
        BOOL isDragging        = NO;

        for ( CPTPlotSpace *space in theGraph.allPlotSpaces ) {
            allowsInteraction = allowsInteraction || space.allowsUserInteraction;
            isDragging        = isDragging || space.isDragging;
        }

        if ( allowsInteraction ) {
            NSCursor *cursor = isDragging ? closedCursor : openCursor;

            if ( cursor ) {
                CGRect plotAreaBounds = [self.layer convertRect:plotArea.bounds fromLayer:plotArea];

                [self addCursorRect:NSRectFromCGRect(plotAreaBounds)
                             cursor:cursor];
            }
        }
    }
}

/// @endcond

#pragma mark -
#pragma mark Notifications

/// @cond

/** @internal
 *  @brief Adds a KVO observer to a new plot space added to the hosted graph.
 **/
-(void)plotSpaceAdded:(nonnull NSNotification *)notification
{
    CPTDictionary *userInfo = notification.userInfo;
    CPTPlotSpace *space     = userInfo[CPTGraphPlotSpaceNotificationKey];

    [space addObserver:self
            forKeyPath:@"isDragging"
               options:NSKeyValueObservingOptionNew
               context:CPTGraphHostingViewKVOContext];
}

/** @internal
 *  @brief Removes the KVO observer from a plot space removed from the hosted graph.
 **/
-(void)plotSpaceRemoved:(nonnull NSNotification *)notification
{
    CPTDictionary *userInfo = notification.userInfo;
    CPTPlotSpace *space     = userInfo[CPTGraphPlotSpaceNotificationKey];

    [space removeObserver:self forKeyPath:@"isDragging" context:CPTGraphHostingViewKVOContext];
    [self.window invalidateCursorRectsForView:self];
}

/** @internal
 *  @brief Updates the cursor rect when the plot area is resized.
 **/
-(void)plotAreaBoundsChanged
{
    [self.window invalidateCursorRectsForView:self];
}

-(void)viewWillMoveToSuperview:(nullable NSView *)newSuperview
{
    if ( self.superview.wantsLayer != newSuperview.wantsLayer ) {
        self.wantsLayer = NO;
        self.layer      = nil;

        if ( newSuperview.wantsLayer ) {
            self.wantsLayer = YES;
        }
        else {
            self.layer      = [self makeBackingLayer];
            self.wantsLayer = YES;
        }

        CPTGraph *theGraph = self.hostedGraph;
        if ( theGraph ) {
            [self.layer addSublayer:theGraph];
        }
    }
}

/// @endcond

#pragma mark -
#pragma mark KVO Methods

/// @cond

-(void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable CPTDictionary *)change context:(nullable void *)context
{
    if ( context == CPTGraphHostingViewKVOContext ) {
        CPTGraph *theGraph = self.hostedGraph;

        if ( [keyPath isEqualToString:@"isDragging"] && [object isKindOfClass:[CPTPlotSpace class]] ) {
            [self.window invalidateCursorRectsForView:self];
        }
        else if ( [keyPath isEqualToString:@"plotAreaFrame"] && (object == theGraph)) {
            CPTPlotAreaFrame *oldPlotAreaFrame = change[NSKeyValueChangeOldKey];
            CPTPlotAreaFrame *newPlotAreaFrame = change[NSKeyValueChangeNewKey];

            if ( oldPlotAreaFrame ) {
                [oldPlotAreaFrame removeObserver:self forKeyPath:@"plotArea" context:CPTGraphHostingViewKVOContext];
            }

            if ( newPlotAreaFrame ) {
                [newPlotAreaFrame addObserver:self
                                   forKeyPath:@"plotArea"
                                      options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionInitial
                                      context:CPTGraphHostingViewKVOContext];
            }
        }
        else if ( [keyPath isEqualToString:@"plotArea"] && (object == theGraph.plotAreaFrame)) {
            CPTPlotArea *oldPlotArea = change[NSKeyValueChangeOldKey];
            CPTPlotArea *newPlotArea = change[NSKeyValueChangeNewKey];

            if ( oldPlotArea ) {
                [[NSNotificationCenter defaultCenter] removeObserver:self
                                                                name:CPTLayerBoundsDidChangeNotification
                                                              object:oldPlotArea];
            }

            if ( newPlotArea ) {
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(plotAreaBoundsChanged)
                                                             name:CPTLayerBoundsDidChangeNotification
                                                           object:newPlotArea];
            }
        }
        else if ( [keyPath isEqualToString:@"effectiveAppearance"] && (object == self)) {
            [self.hostedGraph setNeedsDisplayAllLayers];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

/// @endcond

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setHostedGraph:(nullable CPTGraph *)newGraph
{
    NSParameterAssert((newGraph == nil) || [newGraph isKindOfClass:[CPTGraph class]]);

    if ( newGraph != hostedGraph ) {
        self.wantsLayer = YES;

        if ( hostedGraph ) {
            [hostedGraph removeFromSuperlayer];
            hostedGraph.hostingView = nil;

            [[NSNotificationCenter defaultCenter] removeObserver:self name:CPTGraphDidAddPlotSpaceNotification object:hostedGraph];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:CPTGraphDidRemovePlotSpaceNotification object:hostedGraph];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:CPTLayerBoundsDidChangeNotification object:hostedGraph.plotAreaFrame.plotArea];

            [hostedGraph removeObserver:self forKeyPath:@"plotAreaFrame" context:CPTGraphHostingViewKVOContext];
            [hostedGraph.plotAreaFrame removeObserver:self forKeyPath:@"plotArea" context:CPTGraphHostingViewKVOContext];

            for ( CPTPlotSpace *space in hostedGraph.allPlotSpaces ) {
                [space removeObserver:self forKeyPath:@"isDragging" context:CPTGraphHostingViewKVOContext];
            }
        }

        hostedGraph = newGraph;

        if ( newGraph ) {
            CPTGraph *theGraph = newGraph;

            newGraph.hostingView = self;

            [self viewDidChangeBackingProperties];
            [self.layer addSublayer:theGraph];

            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(plotSpaceAdded:)
                                                         name:CPTGraphDidAddPlotSpaceNotification
                                                       object:theGraph];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(plotSpaceRemoved:)
                                                         name:CPTGraphDidRemovePlotSpaceNotification
                                                       object:theGraph];

            [theGraph addObserver:self
                       forKeyPath:@"plotAreaFrame"
                          options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionInitial
                          context:CPTGraphHostingViewKVOContext];

            for ( CPTPlotSpace *space in newGraph.allPlotSpaces ) {
                [space addObserver:self
                        forKeyPath:@"isDragging"
                           options:NSKeyValueObservingOptionNew
                           context:CPTGraphHostingViewKVOContext];
            }
        }
    }
}

-(void)setClosedHandCursor:(nullable NSCursor *)newCursor
{
    if ( newCursor != closedHandCursor ) {
        closedHandCursor = newCursor;

        [self.window invalidateCursorRectsForView:self];
    }
}

-(void)setOpenHandCursor:(nullable NSCursor *)newCursor
{
    if ( newCursor != openHandCursor ) {
        openHandCursor = newCursor;

        [self.window invalidateCursorRectsForView:self];
    }
}

/// @endcond

@end

#import "CPTTheme.h"

#import "CPTExceptions.h"
#import "CPTGraph.h"

/** @defgroup themeNames Theme Names
 *  @brief Names of the predefined themes.
 **/

// Registered themes
static NSMutableSet<Class> *themes = nil;

/** @brief Creates a CPTGraph instance formatted with a predefined style.
 *
 *  Themes apply a predefined combination of line styles, text styles, and fills to
 *  the graph. The styles are applied to the axes, the plot area, and the graph itself.
 *  Using a theme to format the graph does not prevent any of the style properties
 *  from being changed later. Therefore, it is possible to apply initial formatting to
 *  a graph using a theme and then customize the styles to suit the application later.
 **/
@implementation CPTTheme

/** @property nullable Class graphClass
 *  @brief The class used to create new graphs. Must be a subclass of CPTGraph.
 **/
@synthesize graphClass;

#pragma mark -
#pragma mark Init/Dealloc

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTTheme object.
 *
 *  The initialized object will have the following properties:
 *  - @ref graphClass = @Nil
 *
 *  @return The initialized object.
 **/
-(nonnull instancetype)init
{
    if ((self = [super init])) {
        graphClass = Nil;
    }
    return self;
}

/// @}

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [coder encodeObject:[[self class] name] forKey:@"CPTTheme.name"];

    Class theGraphClass = self.graphClass;
    if ( theGraphClass ) {
        [coder encodeObject:NSStringFromClass(theGraphClass) forKey:@"CPTTheme.graphClass"];
    }
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    self = [CPTTheme themeNamed:[coder decodeObjectOfClass:[NSString class]
                                                    forKey:@"CPTTheme.name"]];

    if ( self ) {
        NSString *className = [coder decodeObjectOfClass:[NSString class]
                                                  forKey:@"CPTTheme.graphClass"];
        if ( className ) {
            self.graphClass = NSClassFromString(className);
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
#pragma mark Theme management

/** @brief List of the available theme classes, sorted by name.
 *  @return An NSArray containing all available theme classes, sorted by name.
 **/
+(nullable NSArray<Class> *)themeClasses
{
    NSSortDescriptor *nameSort = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)];

    return [themes sortedArrayUsingDescriptors:@[nameSort]];
}

/** @brief Gets a named theme.
 *  @param themeName The name of the desired theme.
 *  @return A CPTTheme instance with name matching @par{themeName} or @nil if no themes with a matching name were found.
 *  @see See @ref themeNames "Theme Names" for a list of named themes provided by Core Plot.
 **/
+(nullable instancetype)themeNamed:(nullable CPTThemeName)themeName
{
    CPTTheme *newTheme = nil;

    for ( Class themeClass in themes ) {
        if ( [themeName isEqualToString:[themeClass name]] ) {
            newTheme = [[themeClass alloc] init];
            break;
        }
    }

    return newTheme;
}

/** @brief Register a theme class.
 *  @param themeClass Theme class to register.
 **/
+(void)registerTheme:(nonnull Class)themeClass
{
    NSParameterAssert(themeClass);

    @synchronized ( self ) {
        if ( !themes ) {
            themes = [[NSMutableSet alloc] init];
        }

        if ( [themes containsObject:themeClass] ) {
            [NSException raise:CPTException format:@"Theme class already registered: %@", themeClass];
        }
        else {
            [themes addObject:themeClass];
        }
    }
}

/** @brief The name used for this theme class.
 *  @return The name.
 **/
+(nonnull CPTThemeName)name
{
    return NSStringFromClass(self);
}

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setGraphClass:(nullable Class)newGraphClass
{
    if ( graphClass != newGraphClass ) {
        if ( ![newGraphClass isSubclassOfClass:[CPTGraph class]] ) {
            [NSException raise:CPTException format:@"Invalid graph class for theme; must be a subclass of CPTGraph"];
        }
        else if ( [newGraphClass isEqual:[CPTGraph class]] ) {
            [NSException raise:CPTException format:@"Invalid graph class for theme; must be a subclass of CPTGraph"];
        }
        else {
            graphClass = newGraphClass;
        }
    }
}

/// @endcond

#pragma mark -
#pragma mark Apply the theme

/** @brief Applies the theme to the provided graph.
 *  @param graph The graph to style.
 **/
-(void)applyThemeToGraph:(nonnull CPTGraph *)graph
{
    [self applyThemeToBackground:graph];

    CPTPlotAreaFrame *plotAreaFrame = graph.plotAreaFrame;
    if ( plotAreaFrame ) {
        [self applyThemeToPlotArea:plotAreaFrame];
    }

    CPTAxisSet *axisSet = graph.axisSet;
    if ( axisSet ) {
        [self applyThemeToAxisSet:axisSet];
    }
}

@end

#pragma mark -

@implementation CPTTheme(AbstractMethods)

/** @brief Creates a new graph styled with the theme.
 *  @return The new graph.
 **/
-(nullable id)newGraph
{
    return nil;
}

/** @brief Applies the background theme to the provided graph.
 *  @param graph The graph to style.
 **/
-(void)applyThemeToBackground:(nonnull CPTGraph *__unused)graph
{
}

/** @brief Applies the theme to the provided plot area.
 *  @param plotAreaFrame The plot area to style.
 **/
-(void)applyThemeToPlotArea:(nonnull CPTPlotAreaFrame *__unused)plotAreaFrame
{
}

/** @brief Applies the theme to the provided axis set.
 *  @param axisSet The axis set to style.
 **/
-(void)applyThemeToAxisSet:(nonnull CPTAxisSet *__unused)axisSet
{
}

@end

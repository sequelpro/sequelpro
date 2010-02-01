//
//  MGTemplateEngine.h
//
//  Created by Matt Gemmell on 11/05/2008.
//  Copyright 2008 Instinctive Code. All rights reserved.
//

// Keys in blockInfo dictionaries passed to delegate methods.
#define	BLOCK_NAME_KEY					@"name"				// NSString containing block name (first word of marker)
#define BLOCK_END_NAMES_KEY				@"endNames"			// NSArray containing names of possible ending-markers for block
#define BLOCK_ARGUMENTS_KEY				@"args"				// NSArray of further arguments in block start marker
#define BLOCK_START_MARKER_RANGE_KEY	@"startMarkerRange"	// NSRange (as NSValue) of block's starting marker
#define BLOCK_VARIABLES_KEY				@"vars"				// NSDictionary of variables

#define TEMPLATE_ENGINE_ERROR_DOMAIN	@"MGTemplateEngineErrorDomain"

@class MGTemplateEngine;
@protocol MGTemplateEngineDelegate
@optional
- (void)templateEngine:(MGTemplateEngine *)engine blockStarted:(NSDictionary *)blockInfo;
- (void)templateEngine:(MGTemplateEngine *)engine blockEnded:(NSDictionary *)blockInfo;
- (void)templateEngineFinishedProcessingTemplate:(MGTemplateEngine *)engine;
- (void)templateEngine:(MGTemplateEngine *)engine encounteredError:(NSError *)error isContinuing:(BOOL)continuing;
@end

// Keys in marker dictionaries returned from Matcher methods.
#define MARKER_NAME_KEY					@"name"				// NSString containing marker name (first word of marker)
#define MARKER_TYPE_KEY					@"type"				// NSString, either MARKER_TYPE_EXPRESSION or MARKER_TYPE_MARKER
#define MARKER_TYPE_MARKER				@"marker"
#define MARKER_TYPE_EXPRESSION			@"expression"
#define MARKER_ARGUMENTS_KEY			@"args"				// NSArray of further arguments in marker, if any
#define MARKER_FILTER_KEY				@"filter"			// NSString containing name of filter attached to marker, if any
#define MARKER_FILTER_ARGUMENTS_KEY		@"filterArgs"		// NSArray of filter arguments, if any
#define MARKER_RANGE_KEY				@"range"			// NSRange (as NSValue) of marker's range

@protocol MGTemplateEngineMatcher
@required
- (id)initWithTemplateEngine:(MGTemplateEngine *)engine;
- (void)engineSettingsChanged; // always called at least once before beginning to process a template.
- (NSDictionary *)firstMarkerWithinRange:(NSRange)range;
@end

#import "MGTemplateMarker.h"
#import "MGTemplateFilter.h"

@interface MGTemplateEngine : NSObject {
@public
	NSString *markerStartDelimiter;		// default: {%
	NSString *markerEndDelimiter;		// default: %}
	NSString *expressionStartDelimiter;	// default: {{
	NSString *expressionEndDelimiter;	// default: }}
	NSString *filterDelimiter;			// default: |	example: {{ myVar|uppercase }}
	NSString *literalStartMarker;		// default: literal
	NSString *literalEndMarker;			// default: /literal
@private
	NSMutableArray *_openBlocksStack;
	NSMutableDictionary *_globals;
	NSInteger _outputDisabledCount;
	NSInteger _templateLength;
	NSMutableDictionary *_filters;
	NSMutableDictionary *_markers;
	NSMutableDictionary *_templateVariables;
	BOOL _literal;
@public
	NSRange remainingRange;
	id <MGTemplateEngineDelegate> delegate;
	id <MGTemplateEngineMatcher> matcher;
	NSString *templateContents;
}

@property(retain) NSString *markerStartDelimiter;
@property(retain) NSString *markerEndDelimiter;
@property(retain) NSString *expressionStartDelimiter;
@property(retain) NSString *expressionEndDelimiter;
@property(retain) NSString *filterDelimiter;
@property(retain) NSString *literalStartMarker;
@property(retain) NSString *literalEndMarker;
@property(assign, readonly) NSRange remainingRange;
@property(assign) id <MGTemplateEngineDelegate> delegate;	// weak ref
@property(retain) id <MGTemplateEngineMatcher> matcher;
@property(retain, readonly) NSString *templateContents;

// Creation.
+ (NSString *)version;
+ (MGTemplateEngine *)templateEngine;

// Managing persistent values.
- (void)setObject:(id)anObject forKey:(id)aKey;
- (void)addEntriesFromDictionary:(NSDictionary *)dict;
- (id)objectForKey:(id)aKey;

// Configuration and extensibility.
- (void)loadMarker:(NSObject <MGTemplateMarker> *)marker;
- (void)loadFilter:(NSObject <MGTemplateFilter> *)filter;

// Utilities.
- (NSObject *)resolveVariable:(NSString *)var;
- (NSDictionary *)templateVariables;

// Processing templates.
- (NSString *)processTemplate:(NSString *)templateString withVariables:(NSDictionary *)variables;
- (NSString *)processTemplateInFileAtPath:(NSString *)templatePath withVariables:(NSDictionary *)variables;

@end

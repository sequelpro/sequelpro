//  xibLocalizationPostprocessor.m
//
//  Created by William Shipley on 4/14/08.
//  Copyright © 2005-2009 Golden % Braeburn, LLC.

#import <Cocoa/Cocoa.h>


int main(int argc, const char *argv[])
{
    NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init]; {
        if (argc != 3) {
            fprintf(stderr, "Usage: %s inputfile outputfile\n", argv[0]);
            exit (-1);   
        }

        NSError *error = nil;
        NSStringEncoding usedEncoding;
        NSString *rawXIBStrings = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[1]] usedEncoding:&usedEncoding error:&error];
        if (error) {
            fprintf(stderr, "Error reading %s: %s\n", argv[1], error.localizedDescription.UTF8String);
            exit (-1);
        }
                                   
        NSMutableString *outputStrings = [NSMutableString string];
        NSUInteger lineCount = 0;
        NSString *lastComment = nil;
        for (NSString *line in [rawXIBStrings componentsSeparatedByString:@"\n"]) {
            lineCount++;
            
            if ([line hasPrefix:@"/*"]) { // eg: /* Class = "NSMenuItem"; title = "Quit Library"; ObjectID = "136"; */
                lastComment = line;
                continue;

            } else if (line.length == 0) {
                lastComment = nil;
                continue;

            } else if ([line hasPrefix:@"\""] && [line hasSuffix:@"\";"]) { // eg: "136.title" = "Quit Library";
                
                NSRange quoteEqualsQuoteRange = [line rangeOfString:@"\" = \""];
                if (quoteEqualsQuoteRange.length && NSMaxRange(quoteEqualsQuoteRange) < line.length - 1) {
                    if (lastComment) {
                        [outputStrings appendString:lastComment];
                        [outputStrings appendString:@"\n"];
                    }
                    NSString *stringNeedingLocalization = [line substringFromIndex:NSMaxRange(quoteEqualsQuoteRange)]; // chop off leading: "blah" = "
                    stringNeedingLocalization = [stringNeedingLocalization substringToIndex:stringNeedingLocalization.length - 2]; // chop off trailing: ";
                    [outputStrings appendFormat:@"\"%@\" = \"%@\";\n\n", stringNeedingLocalization, stringNeedingLocalization];
                    continue;
                }
            }
            
            NSLog(@"Warning: skipped garbage input line %d, contents: \"%@\"", lineCount, line);
        }
        
        if (outputStrings.length && ![outputStrings writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:NO encoding:usedEncoding error:&error]) {
            fprintf(stderr, "Error writing %s: %s\n", argv[2], error.localizedDescription.UTF8String);
            exit (-1);
        }
    } [autoreleasePool release];
}
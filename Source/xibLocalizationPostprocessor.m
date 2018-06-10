//  xibLocalizationPostprocessor.m
//
//  Created by William Shipley on 4/14/08.
//  Copyright © 2005-2009 Golden % Braeburn, LLC.

#import <Cocoa/Cocoa.h>

NSDictionary *load_kv_pairs(NSString *input);

int main(int argc, const char *argv[])
{
	@autoreleasepool {
		if (argc != 3 && argc != 4) {
			fprintf(stderr, "Usage: xibLocalizationPostprocessor inputfile outputfile (Replace IB keys with their English string value)\n");
			fprintf(stderr, "       xibLocalizationPostprocessor transfile inputfile outputfile (Reverse mode: Change English keys back to IB keys in translation)\n");
			exit(-1);
		}
		
		NSUInteger inputFileIndex = 1;
		NSDictionary *translatedStrings = nil;
		if(argc == 4) {
			NSError *error = nil;
			NSStringEncoding usedEncoding;
			NSString *translatedFile = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[1]] usedEncoding:&usedEncoding error:&error];
			if (error) {
				fprintf(stderr, "Error reading transfile %s: %s\n", argv[1], error.localizedDescription.UTF8String);
				exit (-1);
			}
			translatedStrings = load_kv_pairs(translatedFile);
			
			inputFileIndex++;
		}

		NSError *error = nil;
		NSStringEncoding usedEncoding;
		NSString *rawXIBStrings = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[inputFileIndex]] usedEncoding:&usedEncoding error:&error];
		if (error) {
			fprintf(stderr, "Error reading inputfile %s: %s\n", argv[inputFileIndex], error.localizedDescription.UTF8String);
			exit(-1);
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
					if(translatedStrings) {
						NSString *translation = [translatedStrings objectForKey:stringNeedingLocalization];
						if(!translation) {
							fprintf(stderr, "Warning: key \"%s\" not found in transfile.\n",[stringNeedingLocalization UTF8String]);
							translation = stringNeedingLocalization; //fallback to untranslated
						}
						[outputStrings appendFormat:@"%@\" = \"%@\";\n\n", [line substringToIndex:quoteEqualsQuoteRange.location], translation];
					}
					else {
						[outputStrings appendFormat:@"\"%@\" = \"%@\";\n\n", stringNeedingLocalization, stringNeedingLocalization];
					}

					continue;
				}
			}

			NSLog(@"Warning: skipped garbage input line %lu, contents: \"%@\"", (unsigned long) lineCount, line);
		}

		if (outputStrings.length && ![outputStrings writeToFile:[NSString stringWithUTF8String:argv[inputFileIndex + 1]] atomically:NO encoding:usedEncoding error:&error]) {
			fprintf(stderr, "Error writing %s: %s\n", argv[inputFileIndex + 1], error.localizedDescription.UTF8String);
			exit(-1);
		}
	}
}

NSDictionary *load_kv_pairs(NSString *input)
{
	NSDictionary *result = [NSMutableDictionary dictionary];
	
	NSUInteger lineCount = 0;
	//don't try [NSString enumerateLines...] here. It supports some obscure Unicode line breaks!
	for (NSString *line in [input componentsSeparatedByString:@"\n"]) {
		lineCount++;

		if (line.length == 0 || [line hasPrefix:@"/*"]) {
			continue;
		}
		
		if ([line hasPrefix:@"\""] && [line hasSuffix:@"\";"]) { // eg: "136.title" = "Quit Library";
			
			NSRange quoteEqualsQuoteRange = [line rangeOfString:@"\" = \""];
			if (quoteEqualsQuoteRange.location != NSNotFound && quoteEqualsQuoteRange.length && NSMaxRange(quoteEqualsQuoteRange) < line.length - 1) {
				NSRange keyRange = NSMakeRange(1,quoteEqualsQuoteRange.location - 1); //the first " is always at pos. 0 (we checked that above)
				NSString *key = [line substringWithRange:keyRange];
				NSString *value = [line substringFromIndex:NSMaxRange(quoteEqualsQuoteRange)]; // chop off leading: "blah" = "
				value = [value substringToIndex:[value length] - 2]; // chop off trailing: ";
				[result setValue:value forKey:key];
				continue;
			}
		}
		
		NSLog(@"Warning: skipped garbage trans line %lu, contents: \"%@\"", (unsigned long)lineCount, line);
	}
	
	return result;
}

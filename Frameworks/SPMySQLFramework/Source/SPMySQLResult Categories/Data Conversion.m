//
//  Data Conversion.m
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on May 26, 2013
//  Copyright (c) 2013 Rowan Beentje. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>


#import "Data Conversion.h"

#ifdef SPMYSQL_FOR_UNIT_TESTING
#define PRIVATE /* public */
#else
#define PRIVATE static inline
#endif

PRIVATE SPMySQLResultFieldProcessor _processorForField(MYSQL_FIELD aField);
PRIVATE NSString * _bitStringWithBytes(const char *bytes, NSUInteger length, NSUInteger padLength);
PRIVATE NSString * _convertStringData(const void *dataBytes, NSUInteger dataLength, NSStringEncoding aStringEncoding, NSUInteger previewLength);

static SPMySQLResultFieldProcessor fieldProcessingMap[256];
static id NSNullPointer;
static NSStringEncoding NSFromCFStringEncodingBig5;
static NSStringEncoding NSFromCFStringEncodingDOSJapanese;
static NSStringEncoding NSFromCFStringEncodingEUC_KR;
static NSStringEncoding NSFromCFStringEncodingGB_2312_80;
static NSStringEncoding NSFromCFStringEncodingGBK_95;

@implementation SPMySQLResult (Data_Conversion_Private_API)

/**
 * In the one-off class initialisation, set up the result processing map
 */
+ (void)_initializeDataConversion
{
	// Cached NSNull singleton reference
	if (!NSNullPointer) NSNullPointer = [NSNull null];

	// Go through the list of enum_field_types in mysql_com.h, mapping each to the method for
	// processing that result set.
	fieldProcessingMap[MYSQL_TYPE_DECIMAL] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_TINY] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_SHORT] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_LONG] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_FLOAT] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_DOUBLE] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_NULL] = SPMySQLResultFieldAsNull;
	fieldProcessingMap[MYSQL_TYPE_TIMESTAMP] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_LONGLONG] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_INT24] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_DATE] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_TIME] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_DATETIME] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_YEAR] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_NEWDATE] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_VARCHAR] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_BIT] = SPMySQLResultFieldAsBit;
	fieldProcessingMap[MYSQL_TYPE_JSON] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_NEWDECIMAL] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_ENUM] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_SET] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_TINY_BLOB] = SPMySQLResultFieldAsBlob;
	fieldProcessingMap[MYSQL_TYPE_MEDIUM_BLOB] = SPMySQLResultFieldAsBlob;
	fieldProcessingMap[MYSQL_TYPE_LONG_BLOB] = SPMySQLResultFieldAsBlob;
	fieldProcessingMap[MYSQL_TYPE_BLOB] = SPMySQLResultFieldAsBlob;
	fieldProcessingMap[MYSQL_TYPE_VAR_STRING] = SPMySQLResultFieldAsStringOrBlob;
	fieldProcessingMap[MYSQL_TYPE_STRING] = SPMySQLResultFieldAsStringOrBlob;
	fieldProcessingMap[MYSQL_TYPE_GEOMETRY] = SPMySQLResultFieldAsGeometry;
	fieldProcessingMap[MYSQL_TYPE_DECIMAL] = SPMySQLResultFieldAsString;

	// Set up string encodings use in if/else checks
	NSFromCFStringEncodingBig5 = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5);
	NSFromCFStringEncodingDOSJapanese = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSJapanese);
	NSFromCFStringEncodingEUC_KR = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_KR);
	NSFromCFStringEncodingGB_2312_80 = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_2312_80);
	NSFromCFStringEncodingGBK_95 = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGBK_95);
}

/**
 * Core data conversion function, taking C data provided by MySQL and converting
 * to an appropriate return type.
 * Note that the data passed in currently is *not* nul-terminated for fast
 * streaming results, which is safe for the current implementation but should be
 * kept in mind for future changes.
 * If a preview length is supplied, the returned data will be shortened to
 * approximately that length, allowing optimisation of data conversion - although
 * note only text and data typess will be shortened, and if shortened, will have
 * an ellipsis added to indicate truncation.  Supply NSNotFound as the length
 * to retrieve the entire cell value.
 */
- (id)_getObjectFromBytes:(char *)bytes ofLength:(NSUInteger)length fieldDefinitionIndex:(NSUInteger)fieldIndex previewLength:(NSUInteger)previewLength
{
	MYSQL_FIELD theField = fieldDefinitions[fieldIndex];

	// A NULL pointer for the data indicates a null value; return a NSNull object.
	if (bytes == NULL) {
		return NSNullPointer;
	}

	// Determine the field processor to use
	SPMySQLResultFieldProcessor dataProcessor = _processorForField(theField);

	// If this instance is set to convert all data as strings, override blob processors.
	if (returnDataAsStrings && dataProcessor == SPMySQLResultFieldAsBlob) {
		dataProcessor = SPMySQLResultFieldAsString;
	}

	// Now switch the processing method again to actually process the data.
	switch (dataProcessor) {

		// Convert string types using a method that will preserve any nul characters
		// within the string
		case SPMySQLResultFieldAsString:
		case SPMySQLResultFieldAsStringOrBlob:
			return _convertStringData(bytes, length, stringEncoding, previewLength);

		// Convert BLOB types to NSData.
		// Use the preview length as supplied.
		case SPMySQLResultFieldAsBlob:
			if (previewLength != NSNotFound && previewLength < length) {
				NSMutableData *theData = [NSMutableData dataWithBytes:bytes length:previewLength];
				if (previewLength > 5) {
					[theData replaceBytesInRange:NSMakeRange(previewLength - 3, 3) withBytes:"..."];
				} else {
					[theData appendBytes:"..." length:3];
				}
				return theData;
			}
			return [NSData dataWithBytes:bytes length:length];

		// For Geometry types, use a special Geometry object to handle their complexity
		case SPMySQLResultFieldAsGeometry:
			return [SPMySQLGeometryData dataWithBytes:bytes length:length];

		// For bit fields, get a zero-padded representation of the data
		case SPMySQLResultFieldAsBit:
			return _bitStringWithBytes(bytes, length, fieldDefinitions[fieldIndex].length);

		// Convert null types to NSNulls
		case SPMySQLResultFieldAsNull:
			return NSNullPointer;

		case SPMySQLResultFieldAsUnhandled:
			NSLog(@"SPMySQLResult processing encountered an unknown field type (%d), falling back to NSData handling", fieldDefinitions[fieldIndex].type);
			return [NSData dataWithBytes:bytes length:length];
	}

	[NSException raise:NSInternalInconsistencyException format:@"Unhandled field type when processing SPMySQLResults"];
	return nil;
}

@end

/**
 * Returns the field processor to use for a specified field.
 */
PRIVATE SPMySQLResultFieldProcessor _processorForField(MYSQL_FIELD aField)
{
	// Determine the default field processor to use
	SPMySQLResultFieldProcessor dataProcessor = fieldProcessingMap[aField.type];

	// Switch the method to process the cell data based on the field type mapping.
	switch (dataProcessor) {

		// STRING and VAR_STRING types may be strings or binary types; check the binary flag
		case SPMySQLResultFieldAsStringOrBlob:
			if (aField.flags & BINARY_FLAG) {
				dataProcessor = SPMySQLResultFieldAsBlob;
			}
			break;

		// Blob types may be automatically be converted to strings, or may be non-binary
		case SPMySQLResultFieldAsBlob:
			if (!(aField.flags & BINARY_FLAG)) {
				dataProcessor = SPMySQLResultFieldAsString;
			}
			break;

		// In most cases, use the original data processor.
		default:
			break;
	}

	return dataProcessor;
}

/**
 * Provides a binary representation of the supplied bytes as a returned NSString.
 * The resulting binary representation will be zero-padded according to the supplied
 * field length.
 * MySQL stores bit data as string data stored in an 8-bit wide character set.
 */
PRIVATE NSString * _bitStringWithBytes(const char *bytes, NSUInteger length, NSUInteger padLength)
{
	NSUInteger i = 0;
	NSUInteger bitLength = length << 3;

	if (bytes == NULL) {
		return nil;
	}

	// use whatever is smaller. padLength comes from BIT(x), bitLength from the actual bytes transmitted.
	// if bitLength < padLength it means the value is smaller than what the field can accomodate.
	// if bitLength > padLength it means BIT(x) is not a full n bytes long and was extended by mysqls storage.
	//   In that case the additional bits should still be 0 as mysql does not allow to set bits over the size of x.
	bitLength = MIN(bitLength,padLength);
	// Generate a nul-terminated C string representation of the binary data
	char *cStringBuffer = malloc(padLength + 1);
	memset(cStringBuffer, '0', padLength);

	while (i < bitLength)
	{
		// start with the least significant bit (the rightmost bit in the last byte) and move left
		unsigned char bitInByteMask =  i % 8; // 0-7, the cycle is 0,1,...,7,0,...
		unsigned long bytesOffset = (length - 1) - (i >> 3); // i>>3 == floor(i/8)
		++i;
		cStringBuffer[padLength - i] = ((bytes[bytesOffset] & (1 << bitInByteMask)) != 0) ? '1' : '0';
	}
	
	cStringBuffer[padLength] = '\0';
	
	// Convert to a string
	NSString *returnString = [NSString stringWithUTF8String:cStringBuffer];

	// Free up memory and return
	free(cStringBuffer);

	return returnString;
}

/**
 * Converts stored string data - which may contain nul bytes - to a native
 * Objective-C string, using the current class encoding.
 */
PRIVATE NSString * _convertStringData(const void *dataBytes, NSUInteger dataLength, NSStringEncoding aStringEncoding, NSUInteger previewLength)
{

	// Fast case - if not using a preview length, or if the data length is shorter, return the requested data.
    if (previewLength == NSNotFound || dataLength <= previewLength) {
        return [NSString stringForDataBytes:dataBytes length:dataLength encoding:aStringEncoding];
    }

	NSUInteger i = 0, characterLength = 0, byteLength = previewLength;
	uint16_t continuationStart, continuationEnd;

	// Handle various special encodings:

	// Variable-length UTF16, in either endianness.  Code points U+D800 to U+DFFF are used to
	// indicate continuation characters, so can be used to identify if each character is two
	// or four bytes long.
	if (aStringEncoding == NSUTF16LittleEndianStringEncoding || aStringEncoding == NSUTF16BigEndianStringEncoding)
	{
		if (aStringEncoding == NSUTF16LittleEndianStringEncoding) {
			continuationStart = 0x00D8;
			continuationEnd = 0xFFDF;
		} else {
			continuationStart = 0xD800;
			continuationEnd = 0xDFFF;
		}

		while (i < dataLength && characterLength < previewLength) {
			uint16_t charStart = ((uint16_t *)dataBytes)[i/2];
			if (charStart >= continuationStart && charStart <= continuationEnd) {
				i += 4;
			} else {
				i += 2;
			}
			characterLength++;
		}
		byteLength = i;
	}

	// Variable-length UTF-8 string encoding.  The first bits can be inspected to determine
	// character length; one-byte characters start with a zero, two-byte characters with
	// 110..., three-byte characters with 1110..., and four-byte with 11110...
	else if (aStringEncoding == NSUTF8StringEncoding)
	{
		while (i < dataLength && characterLength < previewLength) {
			uint8_t charStart = ((uint8_t *)dataBytes)[i];
			if ((charStart & 0xf0) == 0xf0) {
				i += 4;
			} else if ((charStart & 0xe0) == 0xe0) {
				i += 3;
			} else if ((charStart & 0xc0) == 0xc0) {
				i += 2;
			} else {
				i++;
			}
			characterLength++;
		}
		byteLength = i;
	}

	// Variable-length CP932 encoding; if the first byte is between 0x81-0x9F,
	// or between 0xE0-0xFC, the character takes two bytes.
	else if (aStringEncoding == NSFromCFStringEncodingDOSJapanese) {
		while (i < dataLength && characterLength < previewLength) {
			uint8_t charStart = ((uint8_t *)dataBytes)[i];
			if ((charStart >= 0x81 && charStart <= 0x9f) || (charStart >= 0xE0 && charStart <= 0xFC)) {
				i += 2;
			} else {
				i++;
			}
			characterLength++;
		}
		byteLength = i;
	}

	// Variable-length EUCJPMS encoding, which can be one to three bytes.  If a character
	// begins with 0x8F, it's three bytes long; if it begins with 0x8E or 0xA1-0xFE, it's
	// two bytes long, otherwise only one.
	else if (aStringEncoding == NSJapaneseEUCStringEncoding) {
		while (i < dataLength && characterLength < previewLength) {
			uint8_t charStart = ((uint8_t *)dataBytes)[i];
			if (charStart == 0x8F) {
				i += 3;
			} else if (charStart == 0x8E || (charStart >= 0xA1 && charStart <= 0xFE)) {
				i += 2;
			} else {
				i++;
			}
			characterLength++;
		}
		byteLength = i;
	}

	// Variable-length EUC-KR, which can be one or two bytes.  If a character begins with
	// 0xA1-0xFE, it's two bytes long, otherwise just one byte long.  The checks below have
	// been modified to look for 0x81-0xFE for two byte logic, for additional compatibility
	// with CP949.
	// Similarly, variable-length GBK, which can be one or two bytes; a character beginning
	// with 0x81-0xFE is two bytes long, otherwise one byte.
	else if (aStringEncoding == NSFromCFStringEncodingEUC_KR || aStringEncoding == NSFromCFStringEncodingGBK_95) {
		while (i < dataLength && characterLength < previewLength) {
			uint8_t charStart = ((uint8_t *)dataBytes)[i];
			if (charStart >= 0x81 && charStart <= 0xFE) {
				i += 2;
			} else {
				i++;
			}
			characterLength++;
		}
		byteLength = i;
	}

	// Shift JIS, which can be one or two bytes.  A character starting in the ranges
	// 0x80-0xA0 or 0xE0-0xFF is two bytes, otherwise one.
	else if (aStringEncoding == NSShiftJISStringEncoding) {
		while (i < dataLength && characterLength < previewLength) {
			uint8_t charStart = ((uint8_t *)dataBytes)[i];
			if ((charStart >= 0x80 && charStart <= 0xA0) || (charStart >= 0xE0 && charStart <= 0xFF)) {
				i += 2;
			} else {
				i++;
			}
			characterLength++;
		}
		byteLength = i;
	}

	// Encodings where characters are always 4 bytes
	else if (aStringEncoding == NSUTF32StringEncoding)
	{
		characterLength = MIN(previewLength, floor(dataLength / 4));
		byteLength = characterLength * 4;
	}

	// Encodings where characters are always 2 bytes
	else if (
		aStringEncoding == NSFromCFStringEncodingBig5 ||
		aStringEncoding == NSFromCFStringEncodingGB_2312_80 ||
		aStringEncoding == NSUnicodeStringEncoding /* UCS-2 */
	) {
		characterLength = MIN(previewLength, floor(dataLength / 2));
		byteLength = characterLength * 2;
	}

	// Default to a single byte per character
	else {
		characterLength = previewLength;
		byteLength = previewLength;
	}

	// If returning the full string, use a fast path
	if (byteLength >= dataLength) {
		return [NSString stringForDataBytes:dataBytes length:dataLength encoding:aStringEncoding];
	}

	// Get a string using the calculated details
	NSMutableString *previewString = [[[NSMutableString alloc] initWithBytes:dataBytes length:byteLength encoding:aStringEncoding] autorelease];

	// If that failed, fall back to using NSString methods to produce a preview
	if (!previewString) {
		previewString = [[[NSMutableString alloc] initWithBytes:dataBytes length:dataLength encoding:aStringEncoding] autorelease];
		if ([previewString length] > previewLength) {
			[previewString deleteCharactersInRange:NSMakeRange(previewLength, [previewString length] - previewLength)];
		}
	}

	// Add an indication the string is a preview
	[previewString appendString:@"..."];

	return previewString;
}

#undef PRIVATE

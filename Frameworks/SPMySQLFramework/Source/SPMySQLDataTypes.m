//
//  SPMySQLDataTypes.m
//  SPMySQLFramework
//
//  Created by Stuart Connolly (stuconnolly.com) on January 14, 2014.
//  Copyright (c) 2014 Stuart Connolly. All rights reserved.
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

#import "SPMySQLDataTypes.h"

NSString * const SPMySQLTinyIntType            = @"TINYINT";
NSString * const SPMySQLSmallIntType           = @"SMALLINT";
NSString * const SPMySQLMediumIntType          = @"MEDIUMINT";
NSString * const SPMySQLIntType                = @"INT";
NSString * const SPMySQLBigIntType             = @"BIGINT";
NSString * const SPMySQLFloatType              = @"FLOAT";
NSString * const SPMySQLDoubleType             = @"DOUBLE";
NSString * const SPMySQLDoublePrecisionType    = @"DOUBLE PRECISION";
NSString * const SPMySQLRealType               = @"REAL";
NSString * const SPMySQLDecimalType            = @"DECIMAL";
NSString * const SPMySQLBitType                = @"BIT";
NSString * const SPMySQLSerialType             = @"SERIAL";
NSString * const SPMySQLBoolType               = @"BOOL";
NSString * const SPMySQLBoolean                = @"BOOLEAN";
NSString * const SPMySQLDecType                = @"DEC";
NSString * const SPMySQLFixedType              = @"FIXED";
NSString * const SPMySQLNumericType            = @"NUMERIC";
NSString * const SPMySQLCharType               = @"CHAR";
NSString * const SPMySQLVarCharType            = @"VARCHAR";
NSString * const SPMySQLTinyTextType           = @"TINYTEXT";
NSString * const SPMySQLTextType               = @"TEXT";
NSString * const SPMySQLMediumTextType         = @"MEDIUMTEXT";
NSString * const SPMySQLLongTextType           = @"LONGTEXT";
NSString * const SPMySQLTinyBlobType           = @"TINYBLOB";
NSString * const SPMySQLMediumBlobType         = @"MEDIUMBLOB";
NSString * const SPMySQLBlobType               = @"BLOB";
NSString * const SPMySQLLongBlobType           = @"LONGBLOB";
NSString * const SPMySQLBinaryType             = @"BINARY";
NSString * const SPMySQLVarBinaryType          = @"VARBINARY";
NSString * const SPMySQLEnumType               = @"ENUM";
NSString * const SPMySQLSetType                = @"SET";
NSString * const SPMySQLDateType               = @"DATE";
NSString * const SPMySQLDatetimeType           = @"DATETIME";
NSString * const SPMySQLTimestampType          = @"TIMESTAMP";
NSString * const SPMySQLTimeType               = @"TIME";
NSString * const SPMySQLYearType               = @"YEAR";
NSString * const SPMySQLGeometryType           = @"GEOMETRY";
NSString * const SPMySQLPointType              = @"POINT";
NSString * const SPMySQLLineStringType         = @"LINESTRING";
NSString * const SPMySQLPolygonType            = @"POLYGON";
NSString * const SPMySQLMultiPointType         = @"MULTIPOINT";
NSString * const SPMySQLMultiLineStringType    = @"MULTILINESTRING";
NSString * const SPMySQLMultiPolygonType       = @"MULTIPOLYGON";
NSString * const SPMySQLGeometryCollectionType = @"GEOMETRYCOLLECTION";
NSString * const SPMySQLJsonType               = @"JSON";

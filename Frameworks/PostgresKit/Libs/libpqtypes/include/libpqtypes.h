
/*
 * libpqtypes.h
 *   Public header for libpqtypes.  Contains the entire public API.
 *
 * Copyright (c) 2011 eSilo, LLC. All rights reserved.
 * This is free software; see the source for copying conditions.  There is
 * NO warranty; not even for MERCHANTABILITY or  FITNESS FOR A  PARTICULAR
 * PURPOSE.
 */

#ifndef LIBPQTYPES_H
#define LIBPQTYPES_H

#include "libpq-fe.h"
#include <time.h>
#include <stdarg.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_MSC_VER) || defined(__MINGW32__) || defined(__CYGWIN__)
#	define PQT_EXPORT __declspec(dllexport)
#else
#	define PQT_EXPORT extern
#endif

/* MSVC 6 must use `i64', everything else uses `LL'. */
#if !defined(_MSC_VER) || _MSC_VER > 1200
#	define PQT_INT64CONST(x) ((PGint8) x##LL)
#else
#	define PQT_INT64CONST(x) ((PGint8) x##i64)
#endif

enum
{
	PQT_SUBCLASS,
	PQT_COMPOSITE,
	PQT_USERDEFINED
};

typedef struct pg_param PGparam;
typedef struct pg_typeargs PGtypeArgs;
typedef int (*PGtypeProc)(PGtypeArgs *args);

/* For use with a PQregisterXXX function */
typedef struct
{
	const char *typname;
	PGtypeProc typput;
	PGtypeProc typget;
} PGregisterType;

typedef struct
{
	int sversion;
	int pversion;
	char datestyle[48];
	int integer_datetimes;
} PGtypeFormatInfo;

/* Record Attribute Description, its columns */
typedef struct
{
	Oid attoid;
	int attlen;
	int atttypmod;
	char attname[65];
} PGrecordAttDesc;

/* Type handler for putf and getf functions.  The char fixed length buffers
 * used to be allocated pointers.  This was a performance problem when
 * many type handlers are registered and one uses getf on a composite or
 * an array.  These types require generating a PGresult and duplicating
 * the type handlers.  Saved 40% by not having to deep copy the strings.
 */
typedef struct pg_typhandler
{
	int id;
	char typschema[65];
	char typname[65];
	int typlen;
	Oid typoid;
	Oid typoid_array;
	PGtypeProc typput;
	PGtypeProc typget;
	int base_id;

	/* For composites, contains each attribute of a composite */
	int nattrs;
	int freeAttDescs;
	PGrecordAttDesc attDescsBuf[16];
	PGrecordAttDesc *attDescs;
} PGtypeHandler;

/* Values required during a type handler put ot get operation. */
struct pg_typeargs
{
	int is_put;
	const PGtypeFormatInfo *fmtinfo;
	int is_ptr;
	int format;
	va_list ap;
	int typpos;
	PGtypeHandler *typhandler;
	int (*errorf)(PGtypeArgs *args, const char *format, ...);
	int (*super)(PGtypeArgs *args, ...);

	struct
	{
		PGparam *param;
		char *out;
		char *__allocated_out; /* leave me alone! */
		int outl;
		int (*expandBuffer)(PGtypeArgs *args, int new_len);
	} put;

	struct
	{
		PGresult *result;
		int tup_num;
		int field_num;
	} get;
};


/* ----------------
 * Variable Length types
 * ----------------
 */

typedef char *PGtext;
typedef char *PGvarchar;
typedef char *PGbpchar;
typedef char *PGuuid;
typedef struct
{
  int len;
  char *data;
} PGbytea;

/* ----------------
 * Numeric types
 * ----------------
 */

typedef signed char PGchar;
typedef int PGbool;
typedef short PGint2;
typedef int PGint4;
typedef float PGfloat4;
typedef double PGfloat8;
typedef char *PGnumeric;

/* Defined by an end-user if the system is missing long long. */
#ifdef PQT_LONG_LONG
	typedef PQT_LONG_LONG PGint8;
	typedef PQT_LONG_LONG PGmoney;

/* MinGW and MSVC can use __int64 */
#elif defined(__MINGW32__) || defined(_MSC_VER)
	typedef __int64 PGint8;
	typedef __int64 PGmoney;

/* Cygwin and Unixes. */
#else
	typedef long long PGint8;
	typedef long long PGmoney;
#endif

/* ----------------
 * Geometric type structures
 * ----------------
 */

typedef struct
{
	double x;
	double y;
} PGpoint;

typedef struct
{
	PGpoint pts[2];
} PGlseg;

typedef struct
{
	PGpoint high;
	PGpoint low;
} PGbox;

typedef struct
{
	PGpoint center;
	double radius;
} PGcircle;

typedef struct
{
	int npts;
	int closed;
	PGpoint *pts; /* for getf, only valid while PGresult is. */
} PGpath;

typedef struct
{
	int npts;
	PGpoint *pts; /* for getf, only valid while PGresult is. */
} PGpolygon;

/* ----------------
 * Network type structures
 * ----------------
 */

/* This struct works with CIDR as well. */
typedef struct
{
	int mask;
	int is_cidr;
	int sa_buf_len;

	/* sockaddr buffer, can be casted to sockaddr, sockaddr_in,
	 * sockaddr_in6 or sockaddr_stroage.
	 */
	char sa_buf[128];
} PGinet;

typedef struct
{
	int a;
	int b;
	int c;
	int d;
	int e;
	int f;
} PGmacaddr;

/* ----------------
 * Date & Time structures
 * ----------------
 */

typedef struct
{
	int years;
	int mons;
	int days;
	int hours;
	int mins;
	int secs;
	int usecs;
} PGinterval;

typedef struct
{
	int isbc;
	int year;
	int mon;
	int mday;
	int jday;
	int yday;
	int wday;
} PGdate;

typedef struct
{
	int hour;
	int min;
	int sec;
	int usec;
	int withtz;
	int isdst;
	int gmtoff;
	char tzabbr[16];
} PGtime;

typedef struct
{
	PGint8 epoch;
	PGdate date;
	PGtime time;
} PGtimestamp;

/* ----------------
 * Array structures
 * ----------------
 */

#ifndef MAXDIM
#	define MAXDIM 6
#endif

typedef struct
{
	int ndims;
	int lbound[MAXDIM];
	int dims[MAXDIM];
	PGparam *param;
	PGresult *res;
} PGarray;

/* ----------------
 * Public API funcs
 * ----------------
 */

/* === in events.c === */

/* Deprecated, see PQinitTypes */
PQT_EXPORT int
PQtypesRegister(PGconn *conn);

/* === in error.c === */

PQT_EXPORT char *
PQgeterror(void);

/* PQseterror(NULL) will clear the error message */
PQT_EXPORT void
PQseterror(const char *format, ...);

/* Gets the error field for the last executed query.  This only
 * pertains to PQparamExec and PQparamExecPrepared.  When using a
 * standard libpq function like PQexec, PQresultErrorField should be used.
 */
PQT_EXPORT char *
PQgetErrorField(int fieldcode);

/* === in spec.c === */

/* Set 'format' argument to NULL to clear a single prepared specifier. */
PQT_EXPORT int
PQspecPrepare(PGconn *conn, const char *name, const char *format, int is_stmt);

PQT_EXPORT int
PQclearSpecs(PGconn *conn);

/* === in handler.c === */

/* Initialize type support on the given connection */
PQT_EXPORT int
PQinitTypes(PGconn *conn);

/* Deprecated, see PQregisterTypes */
PQT_EXPORT int
PQregisterSubClasses(PGconn *conn, PGregisterType *types, int count);

/* Deprecated, see PQregisterTypes */
PQT_EXPORT int
PQregisterComposites(PGconn *conn, PGregisterType *types, int count);

/* Deprecated, see PQregisterTypes */
PQT_EXPORT int
PQregisterUserDefinedTypes(PGconn *conn, PGregisterType *types, int count);

/* Registers PQT_SUBCLASS, PQT_COMPOSITE or PQT_USERDEFINED
 * (the 'which' argument) for use with libpqtypes.
 *
 * For asynchronous type registration, set the 'async' argument to a
 * non-zero value.  This value is ignored when 'which' is PQT_SUBCLASS,
 * since subclass registration does not execute any commands against the
 * server.  Use the standard PQconsumeInput, PQisBusy and PQgetResult
 * to properly obtain a PGresult, which must be passed to PQregisterResult
 * to complete the registration.
 */
PQT_EXPORT int
PQregisterTypes(PGconn *conn, int which, PGregisterType *types,
	int count, int async);

/* Registers a set of 'which' types found in the given PGresult.  Caller
 * is responsible for clearing the result 'res'.  Useful for performing
 * asynchronous type registration or for caching type result data to
 * avoid lookups on a new connection.  If PQregisterTypes is ran in async
 * mode, the PGresult obtained via PGgetResult can be cached by an
 * application and provided to this function for new connections.
 *
 * Types and count should be identical to what was originally supplied
 * to PQregisterTypes.
 *
 * NOTE: although a PGconn is a required argument, it is never used
 * to perform any network operation (non-blocking safe).
 *
 * PQT_SUBCLASS is not supported and will result in an error if supplied.
 */
PQT_EXPORT int
PQregisterResult(PGconn *conn, int which, PGregisterType *types,
	int count, PGresult *res);

/* Clears all type handlers registered on 'conn'.  This is useful after a
 * PQreset or PQresetPoll to optionally allow one to re-register types via
 * PQregisterTypes.
 */
PQT_EXPORT int
PQclearTypes(PGconn *conn);

/* === in param.c === */

PQT_EXPORT PGparam *
PQparamCreate(const PGconn *conn);

PQT_EXPORT PGparam *
PQparamDup(PGparam *param);

PQT_EXPORT int
PQparamCount(PGparam *param);

PQT_EXPORT void
PQparamReset(PGparam *param);

PQT_EXPORT void
PQparamClear(PGparam *param);

PQT_EXPORT int
PQputf(PGparam *param, const char *format, ...);

PQT_EXPORT int
PQputvf(PGparam *param, char *stmtBuf, size_t stmtBufLen,
	const char *format, va_list ap);

/* === in exec.c === */

PQT_EXPORT int
PQgetf(const PGresult *res, int tup_num, const char *format, ...);

PQT_EXPORT int
PQgetvf(const PGresult *res, int tup_num, const char *format, va_list ap);

PQT_EXPORT PGresult *
PQexecf(PGconn *conn, const char *cmdspec, ...);

PQT_EXPORT PGresult *
PQexecvf(PGconn *conn, const char *cmdspec, va_list ap);

PQT_EXPORT int
PQsendf(PGconn *conn, const char *cmdspec, ...);

PQT_EXPORT int
PQsendvf(PGconn *conn, const char *cmdspec, va_list ap);

PQT_EXPORT PGresult *
PQparamExec(PGconn *conn, PGparam *param,
	const char *command, int resultFormat);

PQT_EXPORT int
PQparamSendQuery(PGconn *conn, PGparam *param,
	const char *command, int resultFormat);

PQT_EXPORT PGresult *
PQparamExecPrepared(PGconn *conn, PGparam *param,
	const char *stmtName, int resultFormat);

PQT_EXPORT int
PQparamSendQueryPrepared(PGconn *conn, PGparam *param,
	const char *stmtName, int resultFormat);

/* === in datetime.c === */

PQT_EXPORT void
PQlocalTZInfo(time_t *t, int *gmtoff, int *isdst, char **tzabbrp);

#ifdef __cplusplus
}
#endif
#endif /* !LIBPQTYPES_H */


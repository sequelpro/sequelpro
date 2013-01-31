-- $Id$
--
-- SQL script used by PostgresKit's integration tests.
--
-- For the tests to execute successfully this file should 
-- be run against a blank database called 'pgkit_test' and 
-- the user 'pgkit_test' with password 'pgkit' should exist:
--
-- CREATE DATABASE pgkit_test;
-- CREATE USER pgkit_test WITH PASSWORD 'pgkit';

SET datestyle = 'DMY';
SET client_encoding = 'UNICODE';

BEGIN;

DROP TABLE IF EXISTS data_types;

CREATE TABLE data_types
(
	int_field         INT PRIMARY KEY NOT NULL,
	smallint_field    SMALLINT NOT NULL,
	bigint_field      BIGINT NOT NULL,
	bool_field        BOOL NOT NULL,
	float_field       REAL NOT NULL,
	numeric_field     NUMERIC(8, 3) NOT NULL,
	char_field        CHAR(4) NOT NULL,
	varchar_field     VARCHAR(32) NOT NULL,
	date_field        DATE NOT NULL,
	time_field        TIME NOT NULL,
	timetz_field      TIME WITH TIME ZONE NOT NULL,
	timestamp_field   TIMESTAMP NOT NULL,
	timestamptz_field TIMESTAMP WITH TIME ZONE NOT NULL
);

INSERT INTO data_types (
	int_field, 
	smallint_field, 
	bigint_field,
	bool_field, 
	float_field,
	numeric_field, 
	char_field, 
 	varchar_field, 
	date_field, 
	time_field, 
	timetz_field, 
	timestamp_field, 
	timestamptz_field)
VALUES (
	12345, 
	2,
	123456789,
	TRUE,
	12345.678,
	12345.678, 
	'CHAR',
	'VARCHAR', 
	'08-04-1987',
	'02:02:02',
	'02:02:02 +1000',
	'08-04-1987 02:02:02',
	'08-04-1987 02:02:02 +0000');

COMMIT;

ANALYZE data_types;

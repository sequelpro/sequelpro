-- $Id$
--
-- SQL script used by PostgresKit's integration tests.
--
-- For the tests to execute successfully this file should 
-- be run against a blank database called 'pgkit_test' and 
-- the user 'pgkit_test' with password 'pgkit' should exit:
--
-- CREATE DATABASE pgkit_test;
-- CREATE USER pgkit_test WITH PASSWORD 'pgkit';

BEGIN;

SET datestyle = 'DMY';
SET client_encoding = 'UNICODE';

CREATE TABLE IF NOT EXISTS data_types
(
	int_field INT PRIMARY KEY NOT NULL,
	smallint_field SMALLINT NOT NULL,
	bool_field BOOL NOT NULL,
	float_field REAL NOT NULL,
	char_field CHAR(5) NOT NULL,
	varchar_field VARCHAR(32) NOT NULL,
	date_field DATE NOT NULL,
	time_field TIME NOT NULL,
	timetz_field TIME WITH TIME ZONE NOT NULL,
	timstamp_field TIMESTAMP NOT NULL,
	timestamptz_field TIMESTAMP WITH TIME ZONE NOT NULL
);

INSERT INTO data_types (
	int_field, 
	smallint_field, 
	bool_field, 
	float_field, 
	char_field, 
 	varchar_field, 
	date_field, 
	time_field, 
	timetz_field, 
	timstamp_field, 
	timestamptz_field)
SELECT
	12345, 
	2, 
	TRUE, 
	12345.678, 
	'CHARV', 
	'VARCHAR_VALUE', 
	'08-04-1987',
	'02:02:02',
	'02:02:02 GMT',
	'08-04-1987 02:02:02',
	'08-04-1987 02:02:02 GMT'
WHERE NOT EXISTS (SELECT 1 FROM data_types WHERE int_field = 12345);

COMMIT;

ANALYZE data_types;

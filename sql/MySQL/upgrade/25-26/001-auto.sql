-- Convert schema 'sql/_source/deploy/25/001-auto.yml' to 'sql/_source/deploy/26/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE sms CHANGE COLUMN port port varchar(25) NOT NULL;

;

COMMIT;


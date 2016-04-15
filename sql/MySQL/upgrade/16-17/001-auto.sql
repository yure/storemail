-- Convert schema 'sql/_source/deploy/16/001-auto.yml' to 'sql/_source/deploy/17/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE sms DROP COLUMN date,
                ADD COLUMN created timestamp NOT NULL DEFAULT current_timestamp,
                ADD COLUMN direction varchar(1) NOT NULL;

;

COMMIT;


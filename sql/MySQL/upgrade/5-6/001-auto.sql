-- Convert schema 'sql/_source/deploy/5/001-auto.yml' to 'sql/_source/deploy/6/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE batch ADD COLUMN domain varchar(90) NULL;

;

COMMIT;


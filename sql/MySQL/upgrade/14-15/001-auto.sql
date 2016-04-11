-- Convert schema 'sql/_source/deploy/14/001-auto.yml' to 'sql/_source/deploy/15/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE click CHANGE COLUMN params params text NULL;

;

COMMIT;


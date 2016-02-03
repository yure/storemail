-- Convert schema 'sql/_source/deploy/6/001-auto.yml' to 'sql/_source/deploy/7/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE message CHANGE COLUMN `read` opened integer NULL;

;

COMMIT;


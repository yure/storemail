-- Convert schema 'sql/_source/deploy/37/001-auto.yml' to 'sql/_source/deploy/38/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE email CHANGE COLUMN id id integer NULL auto_increment;

;

COMMIT;


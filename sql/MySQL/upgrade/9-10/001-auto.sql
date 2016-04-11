-- Convert schema 'sql/_source/deploy/9/001-auto.yml' to 'sql/_source/deploy/10/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE message_group CHANGE COLUMN id id integer NOT NULL auto_increment;

;

COMMIT;


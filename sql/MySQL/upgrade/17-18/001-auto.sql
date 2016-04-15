-- Convert schema 'sql/_source/deploy/17/001-auto.yml' to 'sql/_source/deploy/18/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE sms ADD COLUMN frm varchar(255) NOT NULL;

;

COMMIT;


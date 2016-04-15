-- Convert schema 'sql/_source/deploy/21/001-auto.yml' to 'sql/_source/deploy/22/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE sms ADD COLUMN gateway_id varchar(1) NOT NULL;

;

COMMIT;


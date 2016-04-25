-- Convert schema 'sql/_source/deploy/24/001-auto.yml' to 'sql/_source/deploy/25/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE sms CHANGE COLUMN gateway_id gateway_id varchar(255) NULL;

;

COMMIT;


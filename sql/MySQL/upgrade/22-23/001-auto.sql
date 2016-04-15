-- Convert schema 'sql/_source/deploy/22/001-auto.yml' to 'sql/_source/deploy/23/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE sms CHANGE COLUMN gateway_id gateway_id varchar(255) NOT NULL;

;

COMMIT;


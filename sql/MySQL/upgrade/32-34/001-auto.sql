-- Convert schema 'sql/_source/deploy/32/001-auto.yml' to 'sql/_source/deploy/34/001-auto.yml':;

;
BEGIN;
/*
;
ALTER TABLE group_email CHANGE COLUMN email email varchar(90) NOT NULL;

;
ALTER TABLE message_group DROP INDEX email_UNIQUE,
                          ADD COLUMN domains_id varchar(90) NOT NULL,
                          ADD COLUMN domain varchar(90) NOT NULL,
                          ADD UNIQUE id_UNIQUE (domains_id);

;
*/
COMMIT;


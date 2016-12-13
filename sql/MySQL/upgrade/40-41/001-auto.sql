-- Convert schema 'sql/_source/deploy/40/001-auto.yml' to 'sql/_source/deploy/41/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE batch CHANGE COLUMN domain domain varchar(255) NULL;

;
ALTER TABLE email CHANGE COLUMN email email varchar(255) NOT NULL,
                  CHANGE COLUMN type type varchar(255) NOT NULL DEFAULT 'to',
                  CHANGE COLUMN name name varchar(255) NULL;

;
ALTER TABLE email_blacklist CHANGE COLUMN email email varchar(255) NOT NULL;

;
ALTER TABLE message_group CHANGE COLUMN domains_id domains_id varchar(255) NOT NULL,
                          CHANGE COLUMN domain domain varchar(255) NOT NULL,
                          CHANGE COLUMN email email varchar(255) NOT NULL,
                          CHANGE COLUMN tag tag varchar(255) NULL;

;
ALTER TABLE tag CHANGE COLUMN value value varchar(255) NOT NULL;

;

COMMIT;


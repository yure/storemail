-- Convert schema 'sql/_source/deploy/33/001-auto.yml' to 'sql/_source/deploy/34/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE group_email CHANGE COLUMN email email varchar(90) NOT NULL;

;
ALTER TABLE message_group DROP PRIMARY KEY,
                          DROP INDEX id_UNIQUE,
                          DROP COLUMN internal_id,
                          ADD COLUMN domains_id varchar(90) NOT NULL,
                          CHANGE COLUMN id id integer NOT NULL auto_increment,
                          ADD PRIMARY KEY (id),
                          ADD UNIQUE id_UNIQUE (domains_id);

;

COMMIT;


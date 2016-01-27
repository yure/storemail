-- Convert schema 'sql/_source/deploy/1/001-auto.yml' to 'sql/_source/deploy/2/001-auto.yml':;

;
BEGIN;

;
SET foreign_key_checks=0;

;
CREATE TABLE `batch` (
  `id` integer NOT NULL auto_increment,
  `domain` varchar(255) NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

;
SET foreign_key_checks=1;

;
ALTER TABLE message ADD COLUMN batch_id integer NULL,
                    ADD INDEX message_idx_batch_id (batch_id),
                    ADD CONSTRAINT message_fk_batch_id FOREIGN KEY (batch_id) REFERENCES batch (id) ON DELETE SET NULL ON UPDATE CASCADE;

;

COMMIT;


-- Convert schema 'sql/_source/deploy/29/001-auto.yml' to 'sql/_source/deploy/30/001-auto.yml':;

;
BEGIN;

;
SET foreign_key_checks=0;

;
CREATE TABLE `send_grid_event` (
  `id` integer NOT NULL auto_increment,
  `timestamp` integer NULL,
  `sendgrid_id` varchar(64) NULL,
  `email` varchar(255) NULL,
  `type` varchar(255) NULL,
  `data` text NULL,
  `record_created` datetime NOT NULL,
  `record_updated` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE `send_grid_event_sendgrid_id` (`sendgrid_id`)
);

;
SET foreign_key_checks=1;

;
DROP TABLE event;

;

COMMIT;


-- Convert schema 'sql/_source/deploy/15/001-auto.yml' to 'sql/_source/deploy/16/001-auto.yml':;

;
BEGIN;

;
SET foreign_key_checks=0;

;
CREATE TABLE `sms` (
  `id` integer NOT NULL auto_increment,
  `domain` varchar(255) NULL,
  `to` varchar(255) NOT NULL,
  `body` text NULL,
  `date` timestamp NOT NULL DEFAULT current_timestamp,
  `port` tinyint NULL,
  `send_queue` tinyint NULL,
  `send_timestamp` datetime NULL,
  PRIMARY KEY (`id`)
);

;
SET foreign_key_checks=1;

;
;

COMMIT;


-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Wed Feb  3 13:08:19 2016
-- 
;
SET foreign_key_checks=0;
--
-- Table: `batch`
--
CREATE TABLE `batch` (
  `id` integer NOT NULL auto_increment,
  `domain` varchar(90) NULL,
  `name` varchar(255) NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `click`
--
CREATE TABLE `click` (
  `id` integer NOT NULL auto_increment,
  `message_id` integer NOT NULL,
  `date` datetime NULL,
  `url` text NOT NULL,
  `host` varchar(255) NULL,
  `path` varchar(255) NULL,
  `params` varchar(255) NULL,
  INDEX `click_idx_message_id` (`message_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `click_fk_message_id` FOREIGN KEY (`message_id`) REFERENCES `message` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
--
-- Table: `conversation`
--
CREATE TABLE `conversation` (
  `id` varchar(45) NOT NULL,
  `domain` varchar(45) NULL,
  `subject` varchar(45) NULL,
  `date` timestamp NOT NULL DEFAULT current_timestamp,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `email`
--
CREATE TABLE `email` (
  `message_id` integer NOT NULL,
  `email` varchar(90) NOT NULL,
  `type` varchar(15) NOT NULL DEFAULT 'to',
  `name` varchar(90) NULL,
  INDEX `email_idx_message_id` (`message_id`),
  PRIMARY KEY (`message_id`, `email`, `type`),
  CONSTRAINT `email_fk_message_id` FOREIGN KEY (`message_id`) REFERENCES `message` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
--
-- Table: `message`
--
CREATE TABLE `message` (
  `id` integer NOT NULL auto_increment,
  `domain` varchar(90) NULL,
  `conversation_id` varchar(45) NULL,
  `batch_id` integer NULL,
  `frm` varchar(90) NOT NULL,
  `name` varchar(90) NULL,
  `body` text NULL,
  `plain_body` text NULL,
  `raw_body` text NULL,
  `date` timestamp NOT NULL DEFAULT current_timestamp,
  `subject` text NULL,
  `direction` varchar(1) NOT NULL,
  `new` tinyint NOT NULL DEFAULT 1,
  `send_queue` tinyint NULL,
  `send_queue_fail_count` tinyint NOT NULL DEFAULT 0,
  `send_queue_sleep` integer NOT NULL DEFAULT 0,
  `type` varchar(45) NOT NULL DEFAULT 'email',
  `body_type` varchar(10) NOT NULL DEFAULT 'plain',
  `message_id` varchar(36) NULL,
  `source` varchar(45) NULL,
  `sent` integer NULL,
  `read` integer NULL,
  INDEX `message_idx_batch_id` (`batch_id`),
  INDEX `message_idx_conversation_id` (`conversation_id`),
  PRIMARY KEY (`id`),
  UNIQUE `message_id_UNIQUE` (`message_id`),
  CONSTRAINT `message_fk_batch_id` FOREIGN KEY (`batch_id`) REFERENCES `batch` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `message_fk_conversation_id` FOREIGN KEY (`conversation_id`) REFERENCES `conversation` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;
--
-- Table: `tag`
--
CREATE TABLE `tag` (
  `message_id` integer NOT NULL,
  `value` varchar(90) NOT NULL,
  INDEX `tag_idx_message_id` (`message_id`),
  PRIMARY KEY (`message_id`, `value`),
  CONSTRAINT `tag_fk_message_id` FOREIGN KEY (`message_id`) REFERENCES `message` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
--
-- Table: `user`
--
CREATE TABLE `user` (
  `conversation_id` varchar(45) NOT NULL,
  `email` varchar(90) NOT NULL,
  `name` varchar(45) NULL,
  INDEX `user_idx_conversation_id` (`conversation_id`),
  PRIMARY KEY (`conversation_id`, `email`),
  CONSTRAINT `user_fk_conversation_id` FOREIGN KEY (`conversation_id`) REFERENCES `conversation` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;
SET foreign_key_checks=1;

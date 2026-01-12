/*
  Warnings:

  - A unique constraint covering the columns `[stripe_session_id]` on the table `compra` will be added. If there are existing duplicate values, this will fail.

*/
-- AlterTable
ALTER TABLE `compra` ADD COLUMN `payment_intent_id` VARCHAR(255) NULL,
    ADD COLUMN `stripe_session_id` VARCHAR(191) NULL;

-- CreateTable
CREATE TABLE `stripe_event` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `event_id` VARCHAR(191) NOT NULL,
    `processed` BOOLEAN NOT NULL DEFAULT false,
    `payload` JSON NULL,
    `received_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    UNIQUE INDEX `stripe_event_event_id_key`(`event_id`),
    INDEX `idx_stripe_event_processed`(`processed`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE UNIQUE INDEX `compra_stripe_session_id_key` ON `compra`(`stripe_session_id`);

-- CreateIndex
CREATE INDEX `idx_compra_payment_intent` ON `compra`(`payment_intent_id`);

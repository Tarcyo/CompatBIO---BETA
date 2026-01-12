/*
  Warnings:

  - A unique constraint covering the columns `[stripe_subscription_id]` on the table `assinatura` will be added. If there are existing duplicate values, this will fail.

*/
-- AlterTable
ALTER TABLE `assinatura` ADD COLUMN `cancel_at_period_end` BOOLEAN NULL DEFAULT false,
    ADD COLUMN `canceled_at` TIMESTAMP(0) NULL,
    ADD COLUMN `current_period_end` TIMESTAMP(0) NULL,
    ADD COLUMN `status` VARCHAR(60) NULL,
    ADD COLUMN `stripe_customer_id` VARCHAR(191) NULL,
    ADD COLUMN `stripe_price_id` VARCHAR(191) NULL,
    ADD COLUMN `stripe_subscription_id` VARCHAR(191) NULL;

-- AlterTable
ALTER TABLE `plano` ADD COLUMN `stripe_price_id` VARCHAR(255) NULL;

-- CreateIndex
CREATE UNIQUE INDEX `assinatura_stripe_subscription_id_key` ON `assinatura`(`stripe_subscription_id`);

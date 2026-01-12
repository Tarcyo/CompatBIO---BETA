-- AlterTable
ALTER TABLE `compra` ADD COLUMN `created_at` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0);

-- AlterTable
ALTER TABLE `stripe_event` ADD COLUMN `processed_at` DATETIME(3) NULL;

-- CreateTable
CREATE TABLE `revoked_jti` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `jti` VARCHAR(191) NOT NULL,
    `reason` VARCHAR(191) NULL,
    `created_at` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    UNIQUE INDEX `revoked_jti_jti_key`(`jti`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

/*
  Warnings:

  - A unique constraint covering the columns `[jti]` on the table `password_reset_token` will be added. If there are existing duplicate values, this will fail.

*/
-- AlterTable
ALTER TABLE `produto` ADD COLUMN `demo` BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE `usuario` ADD COLUMN `ja_fez_compra` BOOLEAN NOT NULL DEFAULT false;

-- CreateIndex
CREATE UNIQUE INDEX `password_reset_token_jti_key` ON `password_reset_token`(`jti`);

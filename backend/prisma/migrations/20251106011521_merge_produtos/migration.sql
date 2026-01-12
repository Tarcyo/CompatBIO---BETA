/*
  Warnings:

  - You are about to drop the column `nome_produto_biologico` on the `catalogo_resultado` table. All the data in the column will be lost.
  - You are about to drop the column `nome_produto_quimico` on the `catalogo_resultado` table. All the data in the column will be lost.
  - You are about to drop the column `nome_produto_biologico` on the `solicitacao_analise` table. All the data in the column will be lost.
  - You are about to drop the column `nome_produto_quimico` on the `solicitacao_analise` table. All the data in the column will be lost.
  - You are about to drop the `produto_biologico` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `produto_quimico` table. If the table is not empty, all the data it contains will be lost.
  - A unique constraint covering the columns `[id_produto_quimico,id_produto_biologico]` on the table `catalogo_resultado` will be added. If there are existing duplicate values, this will fail.
  - Added the required column `id_produto_biologico` to the `catalogo_resultado` table without a default value. This is not possible if the table is not empty.
  - Added the required column `id_produto_quimico` to the `catalogo_resultado` table without a default value. This is not possible if the table is not empty.
  - Added the required column `id_produto_biologico` to the `solicitacao_analise` table without a default value. This is not possible if the table is not empty.
  - Added the required column `id_produto_quimico` to the `solicitacao_analise` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE `catalogo_resultado` DROP FOREIGN KEY `fk_catalogo_bio`;

-- DropForeignKey
ALTER TABLE `catalogo_resultado` DROP FOREIGN KEY `fk_catalogo_quim`;

-- DropForeignKey
ALTER TABLE `solicitacao_analise` DROP FOREIGN KEY `fk_solic_bio_prod`;

-- DropForeignKey
ALTER TABLE `solicitacao_analise` DROP FOREIGN KEY `fk_solic_quim_prod`;

-- DropIndex
DROP INDEX `catalogo_unique_pair` ON `catalogo_resultado`;

-- DropIndex
DROP INDEX `fk_catalogo_bio` ON `catalogo_resultado`;

-- DropIndex
DROP INDEX `fk_solic_bio_prod` ON `solicitacao_analise`;

-- DropIndex
DROP INDEX `fk_solic_quim_prod` ON `solicitacao_analise`;

-- AlterTable
ALTER TABLE `catalogo_resultado` DROP COLUMN `nome_produto_biologico`,
    DROP COLUMN `nome_produto_quimico`,
    ADD COLUMN `id_produto_biologico` INTEGER NOT NULL,
    ADD COLUMN `id_produto_quimico` INTEGER NOT NULL;

-- AlterTable
ALTER TABLE `solicitacao_analise` DROP COLUMN `nome_produto_biologico`,
    DROP COLUMN `nome_produto_quimico`,
    ADD COLUMN `id_produto_biologico` INTEGER NOT NULL,
    ADD COLUMN `id_produto_quimico` INTEGER NOT NULL;

-- DropTable
DROP TABLE `produto_biologico`;

-- DropTable
DROP TABLE `produto_quimico`;

-- CreateTable
CREATE TABLE `produto` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `nome` VARCHAR(255) NOT NULL,
    `tipo` VARCHAR(100) NOT NULL,
    `genero` ENUM('quimico', 'biologico') NOT NULL,

    UNIQUE INDEX `produto_nome_key`(`nome`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE INDEX `fk_catalogo_bio` ON `catalogo_resultado`(`id_produto_biologico`);

-- CreateIndex
CREATE INDEX `fk_catalogo_quim` ON `catalogo_resultado`(`id_produto_quimico`);

-- CreateIndex
CREATE UNIQUE INDEX `catalogo_unique_pair` ON `catalogo_resultado`(`id_produto_quimico`, `id_produto_biologico`);

-- CreateIndex
CREATE INDEX `fk_solic_bio_prod` ON `solicitacao_analise`(`id_produto_biologico`);

-- CreateIndex
CREATE INDEX `fk_solic_quim_prod` ON `solicitacao_analise`(`id_produto_quimico`);

-- AddForeignKey
ALTER TABLE `catalogo_resultado` ADD CONSTRAINT `fk_catalogo_bio` FOREIGN KEY (`id_produto_biologico`) REFERENCES `produto`(`id`) ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `catalogo_resultado` ADD CONSTRAINT `fk_catalogo_quim` FOREIGN KEY (`id_produto_quimico`) REFERENCES `produto`(`id`) ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `solicitacao_analise` ADD CONSTRAINT `fk_solic_bio_prod` FOREIGN KEY (`id_produto_biologico`) REFERENCES `produto`(`id`) ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `solicitacao_analise` ADD CONSTRAINT `fk_solic_quim_prod` FOREIGN KEY (`id_produto_quimico`) REFERENCES `produto`(`id`) ON DELETE RESTRICT ON UPDATE NO ACTION;

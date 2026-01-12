-- CreateTable
CREATE TABLE `plano` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `prioridade_de_tempo` INTEGER NOT NULL,
    `nome` VARCHAR(150) NOT NULL,
    `preco_mensal` DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    `quantidade_credito_mensal` INTEGER NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `usuario` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `nome` VARCHAR(200) NOT NULL,
    `data_nascimento` DATE NULL,
    `empresa` VARCHAR(200) NULL,
    `cpf` CHAR(11) NOT NULL,
    `email` VARCHAR(254) NOT NULL,
    `senha` VARCHAR(255) NOT NULL,
    `tipo_usuario` VARCHAR(50) NULL,
    `id_vinculo_assinatura` INTEGER NULL,
    `telefone` VARCHAR(30) NULL,
    `cidade` VARCHAR(100) NULL,
    `estado` VARCHAR(50) NULL,
    `created_at` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),
    `updated_at` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    UNIQUE INDEX `cpf`(`cpf`),
    UNIQUE INDEX `email`(`email`),
    INDEX `fk_usuario_assinatura`(`id_vinculo_assinatura`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `assinatura` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `id_plano` INTEGER NOT NULL,
    `id_dono` INTEGER NOT NULL,
    `data_assinatura` DATE NOT NULL DEFAULT (curdate()),
    `data_renovacao` DATE NULL,
    `ativo` BOOLEAN NOT NULL DEFAULT true,
    `criado_em` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `fk_assinatura_plano`(`id_plano`),
    INDEX `fk_assinatura_usuario`(`id_dono`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `produto_biologico` (
    `nome` VARCHAR(255) NOT NULL,
    `tipo` VARCHAR(100) NOT NULL,

    PRIMARY KEY (`nome`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `produto_quimico` (
    `nome` VARCHAR(255) NOT NULL,
    `tipo` VARCHAR(100) NOT NULL,

    PRIMARY KEY (`nome`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `catalogo_resultado` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `nome_produto_quimico` VARCHAR(255) NOT NULL,
    `nome_produto_biologico` VARCHAR(255) NOT NULL,
    `resultado_final` TEXT NULL,
    `descricao_resultado` TEXT NULL,
    `criado_em` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `fk_catalogo_bio`(`nome_produto_biologico`),
    UNIQUE INDEX `catalogo_unique_pair`(`nome_produto_quimico`, `nome_produto_biologico`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `config_sistema` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `data_estabelecimento` DATE NOT NULL DEFAULT (curdate()),
    `preco_do_credito` DECIMAL(10, 4) NOT NULL DEFAULT 0.0000,
    `preco_da_solicitacao_em_creditos` INTEGER NOT NULL DEFAULT 0,
    `descricao` TEXT NULL,
    `validade_em_dias` INTEGER NOT NULL DEFAULT 0,
    `atualizado_em` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `logs_usuario` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `id_do_usuario` INTEGER NOT NULL,
    `acao_no_sistema` TEXT NOT NULL,
    `data_acao` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `fk_logs_usuario_usuario`(`id_do_usuario`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `solicitacao_analise` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `nome_produto_biologico` VARCHAR(255) NOT NULL,
    `nome_produto_quimico` VARCHAR(255) NOT NULL,
    `prioridade` INTEGER NOT NULL DEFAULT 0,
    `data_solicitacao` DATETIME(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),
    `data_resultado` DATETIME(0) NULL,
    `resultado_final` TEXT NULL,
    `status` ENUM('em_andamento', 'finalizado') NOT NULL DEFAULT 'em_andamento',
    `descricao_resultado` TEXT NULL,
    `id_usuario` INTEGER NULL,

    INDEX `fk_solic_bio_prod`(`nome_produto_biologico`),
    INDEX `fk_solic_quim_prod`(`nome_produto_quimico`),
    INDEX `idx_solicitacao_status`(`status`),
    INDEX `idx_solicitacao_data_solicitacao`(`data_solicitacao`),
    INDEX `idx_solicitacao_usuario`(`id_usuario`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `pacote_creditos` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `id_usuario` INTEGER NOT NULL,
    `quantidade` INTEGER NOT NULL,
    `origem` VARCHAR(255) NOT NULL,
    `data_recebimento` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),

    INDEX `fk_pacote_creditos_usuario`(`id_usuario`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `compra` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `id_usuario` INTEGER NOT NULL,
    `valor_pago` DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    `descricao` TEXT NOT NULL,

    INDEX `fk_compra_usuario`(`id_usuario`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `receita` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `data` TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP(0),
    `valor` DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    `descricao` TEXT NOT NULL,
    `id_usuario` INTEGER NULL,

    INDEX `fk_receita_usuario`(`id_usuario`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `usuario` ADD CONSTRAINT `fk_usuario_assinatura` FOREIGN KEY (`id_vinculo_assinatura`) REFERENCES `assinatura`(`id`) ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `assinatura` ADD CONSTRAINT `fk_assinatura_plano` FOREIGN KEY (`id_plano`) REFERENCES `plano`(`id`) ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `assinatura` ADD CONSTRAINT `fk_assinatura_usuario` FOREIGN KEY (`id_dono`) REFERENCES `usuario`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `catalogo_resultado` ADD CONSTRAINT `fk_catalogo_bio` FOREIGN KEY (`nome_produto_biologico`) REFERENCES `produto_biologico`(`nome`) ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `catalogo_resultado` ADD CONSTRAINT `fk_catalogo_quim` FOREIGN KEY (`nome_produto_quimico`) REFERENCES `produto_quimico`(`nome`) ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `logs_usuario` ADD CONSTRAINT `fk_logs_usuario_usuario` FOREIGN KEY (`id_do_usuario`) REFERENCES `usuario`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `solicitacao_analise` ADD CONSTRAINT `fk_solicitacao_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `solicitacao_analise` ADD CONSTRAINT `fk_solic_bio_prod` FOREIGN KEY (`nome_produto_biologico`) REFERENCES `produto_biologico`(`nome`) ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `solicitacao_analise` ADD CONSTRAINT `fk_solic_quim_prod` FOREIGN KEY (`nome_produto_quimico`) REFERENCES `produto_quimico`(`nome`) ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `pacote_creditos` ADD CONSTRAINT `fk_pacote_creditos_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `compra` ADD CONSTRAINT `fk_compra_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE `receita` ADD CONSTRAINT `fk_receita_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario`(`id`) ON DELETE SET NULL ON UPDATE NO ACTION;

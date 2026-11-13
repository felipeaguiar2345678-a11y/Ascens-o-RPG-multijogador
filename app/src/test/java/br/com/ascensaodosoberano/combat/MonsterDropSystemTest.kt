package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.CriaturaGerada
import br.com.ascensaodosoberano.world.DropCriatura
import br.com.ascensaodosoberano.companions.BlacksmithSystem
import br.com.ascensaodosoberano.companions.MerchantSystem
import br.com.ascensaodosoberano.companions.PlayerInventory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MonsterDropSystemTest {

    @Test
    fun rankMaisAltoAumentaQuantidadeDeMateriais() {
        fun materialDoRank(rank: String): Int {
            val criatura = CriaturaGerada(
                id = "criatura_${rank.lowercase()}",
                nome = "Criatura de teste",
                rank = rank,
                drops = listOf(
                    DropCriatura(
                        itemId = "fragmento",
                        nome = "Fragmento",
                        descricao = "Material de teste",
                        tipo = "MATERIAL",
                        garantido = true,
                        quantidadeMinima = 2,
                        quantidadeMaxima = 2
                    )
                )
            )
            return MonsterDropSystem.roll(criatura).materials.single().quantity
        }

        assertEquals(2, materialDoRank("E"))
        assertTrue(materialDoRank("SSS") > materialDoRank("E"))
    }

    @Test
    fun equipamentosDerrubadosEmCombatesDiferentesRecebemIdsUnicos() {
        val creature = CriaturaGerada(
            id = "golem_teste",
            nome = "Golem de Pedra",
            drops = listOf(
                DropCriatura(
                    itemId = "martelo_golem",
                    nome = "Martelo do Golem",
                    descricao = "Arma pesada",
                    tipo = "EQUIPAMENTO",
                    garantido = true,
                    tipoEquipamento = "WEAPON",
                    raridadeEquipamento = "COMMON",
                    rankEquipamento = "E"
                )
            )
        )

        val first = MonsterDropSystem.roll(creature).equipment.single()
        val second = MonsterDropSystem.roll(creature).equipment.single()

        assertTrue(first.id.isNotBlank())
        assertTrue(second.id.isNotBlank())
        org.junit.Assert.assertNotEquals(first.id, second.id)
    }

    @Test
    fun equipamentoDeCriaturaDeRankAltoNaoFicaAbaixoDoRankDaCriatura() {
        val criatura = CriaturaGerada(
            id = "dragao_sss_teste",
            nome = "Dragão Ancestral",
            rank = "SSS",
            drops = listOf(
                DropCriatura(
                    itemId = "lamina_teste",
                    nome = "Lâmina Ancestral",
                    descricao = "Arma de teste",
                    tipo = "EQUIPAMENTO",
                    garantido = true,
                    tipoEquipamento = "WEAPON",
                    raridadeEquipamento = "COMMON",
                    rankEquipamento = "E"
                )
            )
        )

        val equipamento = MonsterDropSystem.roll(criatura).equipment.single()
        assertEquals("SSS", equipamento.rank)
    }

    @Test
    fun materialObtidoEmCombatePodeSerVendidoEUsadoNaForja() {
        val creature = CriaturaGerada(
            id = "lobo_arcano_teste",
            nome = "Lobo Arcano",
            descricao = "Predador da floresta",
            bioma = "Floresta Arcana",
            drops = listOf(
                DropCriatura(
                    itemId = "presa_lobo",
                    nome = "Presa Arcana",
                    descricao = "Uma presa resistente",
                    tipo = "MATERIAL",
                    raridade = "COMUM",
                    garantido = true,
                    quantidadeMinima = 2,
                    quantidadeMaxima = 2
                )
            )
        )

        val material = MonsterDropSystem.roll(creature).materials.single()

        assertEquals("MATERIAL", material.type)
        assertTrue(MerchantSystem.sellPrice(material) > 0L)
        val inventory = PlayerInventory(items = listOf(material), gold = 100_000L)
        assertTrue(BlacksmithSystem.suggestions(inventory, "aurelia", "espada").isNotEmpty())
    }
}

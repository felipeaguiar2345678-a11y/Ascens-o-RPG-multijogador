package br.com.ascensaodosoberano.companions

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class EquipmentVisualCatalogIdentityTest {

    private fun equipamento(
        id: String = "copia_1",
        rarity: EquipmentRarity = EquipmentRarity.COMMON,
        rank: String = "E",
        materials: List<String> = listOf("Aço lunar"),
        traits: List<String> = listOf("LUMINOSO")
    ) = Equipment(
        id = id,
        name = "Lâmina da Aurora",
        description = "Espada longa com runas douradas e cristal azul no punho.",
        type = EquipmentType.WEAPON,
        rarity = rarity,
        rank = rank,
        attributes = EquipmentAttributes(physicalDamage = 12, strength = 3),
        specialEffect = "Causa dano adicional contra criaturas sombrias.",
        craftingMaterials = materials,
        materialTraits = traits
    )

    @Test
    fun copiasDoMesmoVisualCompartilhamIdentidadeApesarDeRankERaridade() {
        val primeira = equipamento()
        val segunda = equipamento(
            id = "copia_de_outro_jogador",
            rarity = EquipmentRarity.MYTHIC,
            rank = "SSS"
        ).copy(
            attributes = EquipmentAttributes(physicalDamage = 900, strength = 200),
            specialEffect = "Efeito mecânico diferente.",
            upgradeLevel = 10
        )

        assertEquals(
            RepositorioCatalogoVisualEquipamentos.criarIdentidadeVisual(primeira),
            RepositorioCatalogoVisualEquipamentos.criarIdentidadeVisual(segunda)
        )
    }

    @Test
    fun materialOuCaracteristicaVisualDiferenteCriaOutraIdentidade() {
        val original = equipamento()
        val cristal = equipamento(materials = listOf("Cristal astral"))
        val sombrio = equipamento(traits = listOf("SOMBRIO"))

        val idOriginal = RepositorioCatalogoVisualEquipamentos.criarIdentidadeVisual(original)

        assertNotEquals(
            idOriginal,
            RepositorioCatalogoVisualEquipamentos.criarIdentidadeVisual(cristal)
        )
        assertNotEquals(
            idOriginal,
            RepositorioCatalogoVisualEquipamentos.criarIdentidadeVisual(sombrio)
        )
    }

    @Test
    fun identidadeVisualEhDeterministicaEntreChamadas() {
        val item = equipamento()
        assertEquals(
            RepositorioCatalogoVisualEquipamentos.criarIdentidadeVisual(item),
            RepositorioCatalogoVisualEquipamentos.criarIdentidadeVisual(item.copy(id = "outra_copia"))
        )
    }
}

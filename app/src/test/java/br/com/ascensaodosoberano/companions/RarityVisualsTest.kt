package br.com.ascensaodosoberano.companions

import org.junit.Assert.assertEquals
import org.junit.Test

class RarityVisualsTest {
    @Test
    fun normalizaNomesEmPortuguesEIngles() {
        assertEquals(RarityTier.COMMON, RarityVisuals.normalize("Comum"))
        assertEquals(RarityTier.UNCOMMON, RarityVisuals.normalize("INCOMUM"))
        assertEquals(RarityTier.RARE, RarityVisuals.normalize("Rare"))
        assertEquals(RarityTier.EPIC, RarityVisuals.normalize("Épico"))
        assertEquals(RarityTier.LEGENDARY, RarityVisuals.normalize("Lendário"))
        assertEquals(RarityTier.MYTHIC, RarityVisuals.normalize("Mítico"))
        assertEquals(RarityTier.DIVINE, RarityVisuals.normalize("Divino"))
        assertEquals(RarityTier.ANCESTRAL, RarityVisuals.normalize("Ancestral"))
        assertEquals(RarityTier.WORLD, RarityVisuals.normalize("Mundial"))
    }

    @Test
    fun rankDaCriaturaNaoEhRaridadeDeItem() {
        assertEquals(RarityTier.COMMON, RarityVisuals.normalize("SSS"))
        assertEquals(RarityTier.COMMON, RarityVisuals.normalize("S"))
        assertEquals(RarityTier.WORLD, RarityVisuals.normalize("WORLD"))
    }

    @Test
    fun chancesDeDropSomamCemPorCento() {
        assertEquals(100f, RarityVisuals.dropChancesPercent.values.sum(), 0.001f)
    }

    @Test
    fun tabelaDeDropIncluiDivinoAncestralEWorld() {
        assertEquals(RarityTier.COMMON, RarityVisuals.rollDropRarity(0f))
        assertEquals(RarityTier.DIVINE, RarityVisuals.rollDropRarity(0.9985f))
        assertEquals(RarityTier.ANCESTRAL, RarityVisuals.rollDropRarity(0.9995f))
        assertEquals(RarityTier.WORLD, RarityVisuals.rollDropRarity(0.9999f))
    }

    @Test
    fun worldTemChanceDeZeroVirgulaZeroDoisMesmoQuandoIaDefineOutraRaridade() {
        assertEquals(RarityTier.WORLD, RarityVisuals.resolveDropRarity("Comum", 0.9999f))
        assertEquals(RarityTier.WORLD, RarityVisuals.resolveDropRarity("Lendário", 0.9999f))
        assertEquals(RarityTier.LEGENDARY, RarityVisuals.resolveDropRarity("Lendário", 0.5f))
        assertEquals(RarityTier.ANCESTRAL, RarityVisuals.resolveDropRarity("World", 0.5f))
    }

    @Test
    fun multiplicadorWorldAcompanhaRankDaCriatura() {
        assertEquals(4f, RarityVisuals.worldAttributeMultiplier("E"), 0f)
        assertEquals(4f, RarityVisuals.worldAttributeMultiplier("D"), 0f)
        assertEquals(4.5f, RarityVisuals.worldAttributeMultiplier("C"), 0f)
        assertEquals(4.5f, RarityVisuals.worldAttributeMultiplier("B"), 0f)
        assertEquals(5f, RarityVisuals.worldAttributeMultiplier("A"), 0f)
        assertEquals(5f, RarityVisuals.worldAttributeMultiplier("S"), 0f)
        assertEquals(7f, RarityVisuals.worldAttributeMultiplier("SS"), 0f)
        assertEquals(10f, RarityVisuals.worldAttributeMultiplier("SSS"), 0f)
    }

    @Test
    fun converteRaridadePortuguesaParaEnumDeEquipamento() {
        assertEquals(EquipmentRarity.DIVINE, RarityVisuals.equipmentRarity("Divino"))
        assertEquals(EquipmentRarity.ANCESTRAL, RarityVisuals.equipmentRarity("Ancestral"))
        assertEquals(EquipmentRarity.WORLD, RarityVisuals.equipmentRarity("Mundial"))
        assertEquals(EquipmentRarity.MYTHIC, RarityVisuals.equipmentRarity("MYTHIC"))
    }

    @Test
    fun preservaPaletaDeRankDosOvosSeparadaDaRaridade() {
        assertEquals(RarityVisuals.creatureRankColor("SSS"), RarityVisuals.creatureRankColor("sss"))
        assertEquals(RarityVisuals.color("MYTHIC"), RarityVisuals.color("Mítico"))
    }
}

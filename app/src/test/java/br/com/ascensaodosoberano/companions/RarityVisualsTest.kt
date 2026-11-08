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
    fun preservaPaletaDeRankDosOvosSeparadaDaRaridade() {
        assertEquals(RarityVisuals.creatureRankColor("SSS"), RarityVisuals.creatureRankColor("sss"))
        assertEquals(RarityVisuals.color("MYTHIC"), RarityVisuals.color("Mítico"))
    }
}

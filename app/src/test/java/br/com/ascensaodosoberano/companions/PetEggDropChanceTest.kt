package br.com.ascensaodosoberano.companions

import org.junit.Assert.assertEquals
import org.junit.Test

class PetEggDropChanceTest {

    @Test
    fun chancesDeOvoSeguemORankDaCriatura() {
        assertEquals(5, PetEggSystem.getDropChance("E"))
        assertEquals(4, PetEggSystem.getDropChance("D"))
        assertEquals(3, PetEggSystem.getDropChance("C"))
        assertEquals(2, PetEggSystem.getDropChance("B"))
        assertEquals(2, PetEggSystem.getDropChance("A"))
        assertEquals(1, PetEggSystem.getDropChance("S"))
        assertEquals(1, PetEggSystem.getDropChance("SS"))
        assertEquals(1, PetEggSystem.getDropChance("SSS"))
    }

    @Test
    fun consultaDeRankIgnoraMaiusculasEMinusculas() {
        assertEquals(5, PetEggSystem.getDropChance("e"))
        assertEquals(1, PetEggSystem.getDropChance("sss"))
    }

    @Test
    fun ovosDaMesmaCriaturaRecebemIdsDiferentes() {
        val primeiro = PetEggSystem.rollEggDrop(
            monsterId = "lobo_arcano",
            species = "Lobo Arcano",
            rank = "E",
            imageKey = "lobo",
            chanceMultiplier = 100f
        )
        val segundo = PetEggSystem.rollEggDrop(
            monsterId = "lobo_arcano",
            species = "Lobo Arcano",
            rank = "E",
            imageKey = "lobo",
            chanceMultiplier = 100f
        )

        assertNotNull(primeiro)
        assertNotNull(segundo)
        assertNotEquals(primeiro!!.id, segundo!!.id)
    }

    @Test
    fun rankDesconhecidoUsaChanceMinima() {
        assertEquals(1, PetEggSystem.getDropChance("DESCONHECIDO"))
    }
}

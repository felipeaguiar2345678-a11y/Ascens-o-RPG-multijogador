package br.com.ascensaodosoberano.character

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CharacterVisualVersionPolicyTest {

    @Test
    fun rejeitaArtesAntigasDoCatalogo() {
        assertFalse(CharacterVisualVersionPolicy.isCompatible(1))
        assertFalse(CharacterVisualVersionPolicy.isCompatible(2))
    }

    @Test
    fun aceitaVersaoAtualEVersoesFuturas() {
        assertTrue(
            CharacterVisualVersionPolicy.isCompatible(
                CharacterVisualVersionPolicy.MINIMUM_COMPATIBLE_VERSION
            )
        )
        assertTrue(
            CharacterVisualVersionPolicy.isCompatible(
                CharacterVisualVersionPolicy.MINIMUM_COMPATIBLE_VERSION + 1
            )
        )
    }
}

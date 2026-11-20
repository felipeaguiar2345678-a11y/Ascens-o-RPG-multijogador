package br.com.ascensaodosoberano.character

/**
 * Versão mínima da folha corporal aceita pelo fluxo atual de criação.
 * Versões antigas permanecem armazenadas, mas não são reutilizadas como arte nova.
 */
object CharacterVisualVersionPolicy {
    const val MINIMUM_COMPATIBLE_VERSION = 3

    fun isCompatible(version: Int): Boolean =
        version >= MINIMUM_COMPATIBLE_VERSION
}

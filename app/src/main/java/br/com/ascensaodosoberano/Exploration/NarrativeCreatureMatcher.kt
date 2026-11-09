package br.com.ascensaodosoberano.exploration

import br.com.ascensaodosoberano.world.CriaturaGerada
import java.text.Normalizer
import java.util.Locale

/**
 * Atualização narrativa 2026-11-09.
 * Faz a ponte entre a pista escrita pelo narrador e o bestiário existente.
 * A seleção é determinística para a mesma lista e pista; não depende de mapa.
 */
object NarrativeCreatureMatcher {
    private val ignoredWords = setOf(
        "com", "sem", "uma", "uns", "das", "dos", "que", "para", "pela",
        "pelo", "sobre", "entre", "criatura", "monstro", "inimigo", "aparece"
    )

    fun selectBest(
        candidates: List<CriaturaGerada>,
        hint: String
    ): CriaturaGerada? {
        val tokens = normalize(hint).split(Regex("\\s+"))
            .filter { it.length >= 3 && it !in ignoredWords }
            .toSet()
        if (tokens.isEmpty() || candidates.isEmpty()) return null

        return candidates
            .map { creature ->
                val searchable = normalize(
                    listOf(
                        creature.nome,
                        creature.descricao,
                        creature.bioma,
                        creature.habitat
                    ).plus(creature.habilidades).joinToString(" ")
                )
                val score = tokens.count { token ->
                    searchable.contains(token)
                }
                creature to score
            }
            .filter { it.second > 0 }
            .sortedWith(
                compareByDescending<Pair<CriaturaGerada, Int>> { it.second }
                    .thenBy { it.first.nome.lowercase(Locale.ROOT) }
            )
            .firstOrNull()
            ?.first
    }

    private fun normalize(value: String): String =
        Normalizer.normalize(value.lowercase(Locale.ROOT), Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}+"), "")
            .replace(Regex("[^a-z0-9 ]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
}

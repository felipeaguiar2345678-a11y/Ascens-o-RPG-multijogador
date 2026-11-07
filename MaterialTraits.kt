package br.com.ascensaodosoberano.companions

import br.com.ascensaodosoberano.world.CriaturaGerada

object MaterialTraits {
    fun fromCreature(creature: CriaturaGerada): List<String> {
        val text = listOf(creature.nome, creature.descricao, creature.bioma, creature.habitat, creature.ecosystemId, creature.raridade).joinToString(" ").lowercase()
        val traits = linkedSetOf<String>()
        fun addIf(words: List<String>, trait: String) { if (words.any { text.contains(it) }) traits.add(trait) }
        addIf(listOf("lobo", "canino", "presa", "garra", "caçador", "predador"), "PREDADOR")
        addIf(listOf("planta", "flor", "raiz", "vinha", "musgo", "floresta"), "NATUREZA")
        addIf(listOf("dragão", "dracon", "escama", "sopro"), "DRACONICO")
        addIf(listOf("gelo", "neve", "glacial", "congel"), "GELO")
        addIf(listOf("fogo", "lava", "brasas", "vulc"), "FOGO")
        addIf(listOf("veneno", "toxina", "ácido", "pântano"), "VENENO")
        addIf(listOf("espírito", "alma", "fantasma", "sombr", "abiss"), "ESPIRITUAL")
        addIf(listOf("pedra", "minério", "metal", "cristal", "montanha"), "MINERAL")
        addIf(listOf("água", "marinho", "oceano", "rio", "aquát"), "AQUATICO")
        if (traits.isEmpty()) traits.add("BESTIAL")
        return traits.toList()
    }
}

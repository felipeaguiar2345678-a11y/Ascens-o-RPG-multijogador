
package br.com.ascensaodosoberano.companions

data class Companion(
    val id: String,
    val name: String,
    val species: String,
    val rank: String,

    // Progressão
    val level: Int = 1,
    val xp: Int = 0,
    val stage: String = "FILHOTE",

    // Atributos atuais
    val maxHp: Int,
    val hp: Int,
    val attack: Int,
    val defense: Int,
    val agility: Int,
    val magicPower: Int,

    // Atributos originais do monstro
    val originalMonsterId: String = "",
    val originalMonsterRank: String = rank,
    val originalMaxHp: Int = maxHp,
    val originalAttack: Int = attack,
    val originalDefense: Int = defense,
    val originalAgility: Int = agility,
    val originalMagicPower: Int = magicPower,

    // Mutação herdada do ovo
    val mutationId: String = "NORMAL",
    val mutationName: String = "Normal",
    val mutationRarity: String = "COMUM",
    val mutationDescription: String = "",

    // Modificadores da mutação (percentuais)
    val mutationHpPercent: Int = 0,
    val mutationAttackPercent: Int = 0,
    val mutationDefensePercent: Int = 0,
    val mutationAgilityPercent: Int = 0,
    val mutationMagicPercent: Int = 0,

    // Aparência geral
    val imageKey: String,
    val isActive: Boolean = false,

    // Aparência atual
    val imagemIconeCaminho: String = "",
    val imagemDetalhadaCaminho: String = "",
    val imagemSpriteCaminho: String = "",

    // Aparência de filhote
    val filhoteImagemIconeCaminho: String = "",
    val filhoteImagemDetalhadaCaminho: String = "",
    val filhoteImagemSpriteCaminho: String = "",

    // Aparência de adolescente
    val adolescenteImagemIconeCaminho: String = "",
    val adolescenteImagemDetalhadaCaminho: String = "",
    val adolescenteImagemSpriteCaminho: String = "",

    // Aparência de adulto
    val adultoImagemIconeCaminho: String = "",
    val adultoImagemDetalhadaCaminho: String = "",
    val adultoImagemSpriteCaminho: String = ""
)

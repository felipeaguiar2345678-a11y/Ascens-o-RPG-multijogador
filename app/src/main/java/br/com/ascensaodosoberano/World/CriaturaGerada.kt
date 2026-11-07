
package br.com.ascensaodosoberano.world

import br.com.ascensaodosoberano.companions.EquipmentAttributes

data class AtaqueCriatura(
    val id: String = "",
    val nome: String = "",
    val descricao: String = "",
    val tipoDano: String = "FISICO",
    val elemento: String = "NEUTRO",
    val danoBase: Int = 0,
    val multiplicador: Float = 1f,
    val custoMana: Int = 0,
    val custoManaMinimo: Int = 0,
    val custoManaMaximo: Int = 0,
    val efeitos: List<String> = emptyList(),
    val duracaoTurnos: Int = 0,
    val chanceAplicacao: Int = 100,
    val chanceUso: Int = 50,
    val turnosCarregamento: Int = 0,
    val turnosRecarga: Int = 0,
    val podeSerInterrompida: Boolean = true
)

data class DropCriatura(
    val itemId: String = "",
    val nome: String = "",
    val descricao: String = "",
    val tipo: String = "MATERIAL",
    val raridade: String = "COMUM",
    val chancePercentual: Float = 0f,
    val garantido: Boolean = false,

    val quantidadeMinima: Int = 1,
    val quantidadeMaxima: Int = 1,

    val tipoEquipamento: String = "",
    val raridadeEquipamento: String = "",
    val rankEquipamento: String = "E",
    val nivelRequerido: Int = 1,

    val atributos: EquipmentAttributes = EquipmentAttributes(),
    val efeitoEspecial: String? = null
)

data class CriaturaGerada(
    val id: String = "",
    val nome: String = "",
    val descricao: String = "",

    val rank: String = "E",
    val nivel: Int = 1,

    val vidaMaxima: Int = 100,
    val ataque: Int = 10,
    val defesa: Int = 5,
    val manaMaxima: Int = 0,
    val agilidade: Int = 5,
    val poderMagico: Int = 10,

    val experienciaBase: Int = 10,
    val perigo: Int = 10,

    val ecosystemId: String = "unknown",
    val bioma: String = "",
    val habitat: String = "",

    val raridade: String = "COMUM",

    val imagemId: String = "",
    val imagemIconeCaminho: String = "",
    val imagemDetalhadaCaminho: String = "",

    val habilidades: List<String> = emptyList(),
    val ataques: List<AtaqueCriatura> = emptyList(),
    val drops: List<DropCriatura> = emptyList(),

    val chefe: Boolean = false,
    // UID que registrou primeiro esta criatura no catálogo global.
    // Usado pelas regras do Firestore para impedir alterações por terceiros.
    val criadoPorUid: String = "",
    val versao: Int = 1
)

package br.com.ascensaodosoberano.companions

import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await
import java.security.MessageDigest
import java.text.Normalizer
import java.util.Locale

/**
 * Catálogo mundial de artes de equipamentos.
 *
 * A identidade visual ignora dono, nível, atributos e melhorias: esses dados
 * pertencem à cópia do jogador. Ela considera apenas o que altera a aparência.
 */
data class ResultadoCatalogoVisualEquipamento(
    val equipamento: Equipment,
    val visualId: String,
    val arteDisponivel: Boolean,
    val criadoAgora: Boolean
)

object RepositorioCatalogoVisualEquipamentos {
    private const val COLECAO = "equipamentos_visuais"
    private const val VERSAO_PERFIL = "corpo_base_v1"
    private const val VERSAO_ARTE = 1

    private val banco: FirebaseFirestore
        get() = FirebaseFirestore.getInstance()

    private fun normalizar(valor: String): String {
        val semAcentos = Normalizer.normalize(valor.trim(), Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}+"), "")
        return semAcentos.lowercase(Locale.ROOT)
            .replace(Regex("[^a-z0-9]+"), " ")
            .trim()
            .replace(Regex("\\s+"), " ")
    }

    /**
     * O hash é determinístico entre aparelhos. Materiais e descrição entram
     * na chave para não misturar, por exemplo, uma espada de ferro com uma
     * espada visualmente distinta de cristal. Upgrade e atributos não entram.
     */
    fun criarIdentidadeVisual(equipamento: Equipment): String {
        val identidade = listOf(
            "versao=$VERSAO_ARTE",
            "encaixe=$VERSAO_PERFIL",
            "tipo=${equipamento.type.name}",
            "nome=${normalizar(equipamento.name)}",
            "descricao=${normalizar(equipamento.description)}",
            "raridade=${equipamento.rarity.name}",
            "rank=${normalizar(equipamento.rank)}",
            "materiais=${equipamento.craftingMaterials.map(::normalizar).filter(String::isNotBlank).sorted().joinToString("|")}",
            "caracteristicas=${equipamento.materialTraits.map(::normalizar).filter(String::isNotBlank).sorted().joinToString("|")}"
        ).joinToString("\n")
        val bytes = MessageDigest.getInstance("SHA-256")
            .digest(identidade.toByteArray(Charsets.UTF_8))
        return "equip_" + bytes.joinToString("") { "%02x".format(it) }
    }

    /**
     * Registra a identidade visual uma única vez e sempre devolve os caminhos
     * já publicados. Não chama IA nem cria cobrança.
     */
    suspend fun registrarOuRecuperar(equipamento: Equipment): ResultadoCatalogoVisualEquipamento {
        require(equipamento.name.isNotBlank()) { "O equipamento precisa ter um nome." }
        require(equipamento.description.isNotBlank()) { "O equipamento precisa ter uma descrição visual." }

        val visualId = criarIdentidadeVisual(equipamento)
        val referencia = banco.collection(COLECAO).document(visualId)
        val uid = com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid.orEmpty()

        val resultado = banco.runTransaction { transacao ->
            val existente = transacao.get(referencia)
            if (existente.exists()) {
                Triple(
                    existente.getString("visualFrenteCaminho").orEmpty(),
                    existente.getString("visualCostasCaminho").orEmpty(),
                    existente.getString("visualLadoEsquerdoCaminho").orEmpty()
                ) to (existente.getString("visualLadoDireitoCaminho").orEmpty() to false)
            } else {
                transacao.set(referencia, mapOf(
                    "visualId" to visualId,
                    "nomeReferencia" to equipamento.name,
                    "tipo" to equipamento.type.name,
                    "descricaoVisual" to equipamento.description,
                    "raridadeVisual" to equipamento.rarity.name,
                    "rankVisual" to equipamento.rank,
                    "craftingMaterials" to equipamento.craftingMaterials,
                    "materialTraits" to equipamento.materialTraits,
                    "perfilEncaixeVisual" to VERSAO_PERFIL,
                    "versaoVisualEquipamento" to VERSAO_ARTE,
                    "status" to "aguardando_arte",
                    "visualFrenteCaminho" to "",
                    "visualCostasCaminho" to "",
                    "visualLadoEsquerdoCaminho" to "",
                    "visualLadoDireitoCaminho" to "",
                    "criadoPorUid" to uid,
                    "criadoEm" to System.currentTimeMillis()
                ))
                Triple("", "", "") to ("" to true)
            }
        }.await()

        val frente = resultado.first.first
        val costas = resultado.first.second
        val esquerda = resultado.first.third
        val direita = resultado.second.first
        val atualizado = equipamento.copy(
            visualFrenteCaminho = frente.ifBlank { equipamento.visualFrenteCaminho },
            visualCostasCaminho = costas.ifBlank { equipamento.visualCostasCaminho },
            visualLadoEsquerdoCaminho = esquerda.ifBlank { equipamento.visualLadoEsquerdoCaminho },
            visualLadoDireitoCaminho = direita.ifBlank { equipamento.visualLadoDireitoCaminho },
            perfilEncaixeVisual = VERSAO_PERFIL,
            versaoVisualEquipamento = VERSAO_ARTE
        )
        val pronto = listOf(frente, costas, esquerda, direita).all(String::isNotBlank) ||
            listOf(
                atualizado.visualFrenteCaminho,
                atualizado.visualCostasCaminho,
                atualizado.visualLadoEsquerdoCaminho,
                atualizado.visualLadoDireitoCaminho
            ).all(String::isNotBlank)

        return ResultadoCatalogoVisualEquipamento(
            equipamento = atualizado,
            visualId = visualId,
            arteDisponivel = pronto,
            criadoAgora = resultado.second.second
        )
    }

}

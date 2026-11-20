package br.com.ascensaodosoberano.companions

import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
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
    private const val VERSAO_PERFIL = "corpo_base_v3"
    private const val VERSAO_ARTE = 4

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
     * O hash é determinístico entre aparelhos. Materiais, características e descrição entram
     * na chave para não misturar, por exemplo, uma espada de ferro com uma
     * espada visualmente distinta de cristal. Upgrade, atributos, raridade, rank e efeitos puramente mecânicos não entram.
     */
    fun criarIdentidadeVisual(equipamento: Equipment): String {
        val identidade = listOf(
            "versao=$VERSAO_ARTE",
            "encaixe=$VERSAO_PERFIL",
            "tipo=${equipamento.type.name}",
            "nome=${normalizar(equipamento.name)}",
            "descricao=${normalizar(equipamento.description)}",
            // Raridade, rank e efeito de combate não identificam a aparência:
            // cópias equivalentes devem compartilhar a mesma arte oficial.
            // Efeitos puramente mecânicos não alteram a arte. Variações visuais reais devem constar em description/materialTraits.
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
    suspend fun registrarOuRecuperar(
        equipamento: Equipment,
        solicitarGeracaoPendente: Boolean = true
    ): ResultadoCatalogoVisualEquipamento {
        require(equipamento.name.isNotBlank()) { "O equipamento precisa ter um nome." }
        require(equipamento.description.isNotBlank()) { "O equipamento precisa ter uma descrição visual." }

        val visualId = criarIdentidadeVisual(equipamento)
        val referencia = banco.collection(COLECAO).document(visualId)
        val uid = com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid.orEmpty()

        val resultado = banco.runTransaction { transacao ->
            val existente = transacao.get(referencia)
            if (existente.exists()) {
                mapOf(
                    "frente" to existente.getString("visualFrenteCaminho").orEmpty(),
                    "costas" to existente.getString("visualCostasCaminho").orEmpty(),
                    "esquerda" to existente.getString("visualLadoEsquerdoCaminho").orEmpty(),
                    "direita" to existente.getString("visualLadoDireitoCaminho").orEmpty(),
                    "traseira" to existente.getString("visualCamadaTraseiraCaminho").orEmpty(),
                    "dianteira" to existente.getString("visualCamadaDianteiraCaminho").orEmpty(),
                    "versao" to (existente.getLong("versaoVisualEquipamento") ?: 0L).toInt(),
                    "perfil" to existente.getString("perfilEncaixeVisual").orEmpty(),
                    "formato" to existente.getString("formatoFolhaVisual").orEmpty(),
                    "status" to existente.getString("status").orEmpty()
                ) to false
            } else {
                transacao.set(referencia, mapOf(
                    "visualId" to visualId,
                    "nomeReferencia" to equipamento.name,
                    "tipo" to equipamento.type.name,
                    "descricaoVisual" to equipamento.description,
                    "craftingMaterials" to equipamento.craftingMaterials,
                    "materialTraits" to equipamento.materialTraits,
                    "perfilEncaixeVisual" to VERSAO_PERFIL,
                    "versaoVisualEquipamento" to VERSAO_ARTE,
                    "formatoFolhaVisual" to "folha_4x2_profundidade",
                    "status" to "aguardando_arte",
                    "visualFrenteCaminho" to "",
                    "visualCostasCaminho" to "",
                    "visualLadoEsquerdoCaminho" to "",
                    "visualLadoDireitoCaminho" to "",
                    "visualCamadaTraseiraCaminho" to "",
                    "visualCamadaDianteiraCaminho" to "",
                    "criadoPorUid" to uid,
                    "criadoEm" to System.currentTimeMillis()
                ))
                mapOf("frente" to "", "costas" to "", "esquerda" to "", "direita" to "", "traseira" to "", "dianteira" to "") to true
            }
        }.await()

        val registroCompativel =
            resultado.first["versao"] == VERSAO_ARTE &&
            resultado.first["perfil"] == VERSAO_PERFIL &&
            resultado.first["formato"] == "folha_4x2_profundidade" &&
            resultado.first["status"] == "pronto"
        val caminhosRegistrados = listOf("frente", "costas", "esquerda", "direita", "traseira", "dianteira")
            .map { (resultado.first[it] as? String).orEmpty() }
        val registroCompleto = registroCompativel && caminhosRegistrados.all { it.isNotBlank() }
        val caminhosOficiais = if (registroCompleto) caminhosRegistrados else emptyList()

        // O endpoint é cache-only. Respostas parciais ou pendentes nunca viram arte v4.
        val arteRemota = if (!registroCompleto) {
            runCatching {
                val resolucao = EquipmentVisualApi.resolverArteOficial(visualId)
                val caminhos = listOf(
                    resolucao.visualFrenteCaminho, resolucao.visualCostasCaminho,
                    resolucao.visualLadoEsquerdoCaminho, resolucao.visualLadoDireitoCaminho,
                    resolucao.visualCamadaTraseiraCaminho, resolucao.visualCamadaDianteiraCaminho
                )
                if (resolucao.visualId == visualId &&
                    resolucao.status == "already_generated" &&
                    caminhos.all(String::isNotBlank)
                ) {
                    resolucao
                } else {
                    if (solicitarGeracaoPendente && resolucao.geracaoAtivada && resolucao.status == "pending") {
                        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
                            runCatching { EquipmentVisualApi.solicitarGeracaoSeLiberada(visualId) }
                        }
                    }
                    null
                }
            }.getOrNull()
        } else null

        val caminhosRemotos = arteRemota?.let {
            listOf(
                it.visualFrenteCaminho, it.visualCostasCaminho,
                it.visualLadoEsquerdoCaminho, it.visualLadoDireitoCaminho,
                it.visualCamadaTraseiraCaminho, it.visualCamadaDianteiraCaminho
            )
        }.orEmpty()
        val caminhosProntos = caminhosOficiais.ifEmpty { caminhosRemotos }
        val arteV4Pronta = caminhosProntos.size == 6 && caminhosProntos.all(String::isNotBlank)

        val atualizado = if (arteV4Pronta) {
            equipamento.copy(
                visualFrenteCaminho = caminhosProntos[0],
                visualCostasCaminho = caminhosProntos[1],
                visualLadoEsquerdoCaminho = caminhosProntos[2],
                visualLadoDireitoCaminho = caminhosProntos[3],
                visualCamadaTraseiraCaminho = caminhosProntos[4],
                visualCamadaDianteiraCaminho = caminhosProntos[5],
                perfilEncaixeVisual = VERSAO_PERFIL,
                versaoVisualEquipamento = VERSAO_ARTE
            )
        } else {
            // Não reclassifica uma folha 2x2 antiga como folha v4.
            equipamento
        }
        val pronto = arteV4Pronta

        return ResultadoCatalogoVisualEquipamento(
            equipamento = atualizado,
            visualId = visualId,
            arteDisponivel = pronto,
            criadoAgora = resultado.second
        )
    }

}

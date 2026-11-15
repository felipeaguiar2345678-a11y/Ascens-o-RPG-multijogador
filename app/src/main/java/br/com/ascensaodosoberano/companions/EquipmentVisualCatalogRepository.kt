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
    suspend fun registrarOuRecuperar(equipamento: Equipment): ResultadoCatalogoVisualEquipamento {
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
                    "dianteira" to existente.getString("visualCamadaDianteiraCaminho").orEmpty()
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

        val frente = resultado.first["frente"].orEmpty()
        val costas = resultado.first["costas"].orEmpty()
        val esquerda = resultado.first["esquerda"].orEmpty()
        val direita = resultado.first["direita"].orEmpty()
        val camadaTraseira = resultado.first["traseira"].orEmpty()
        val camadaDianteira = resultado.first["dianteira"].orEmpty()

        // Consulta a arte oficial já publicada, se houver. O endpoint é cache-only:
        // não chama IA nem reserva orçamento; quando ainda não existe imagem,
        // apenas devolve "pending" e a peça continua utilizável no inventário.
        val arteRemota = if (
            frente.isBlank() || costas.isBlank() || esquerda.isBlank() || direita.isBlank() ||
            camadaTraseira.isBlank() || camadaDianteira.isBlank()
        ) {
            runCatching {
                val resolucao = EquipmentVisualApi.resolverArteOficial(visualId)
                if (resolucao.geracaoAtivada && resolucao.status == "pending") {
                    // A geração nunca é aguardada aqui: o item pode ser entregue/equipado
                    // enquanto a arte compartilhada é criada em segundo plano.
                    CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
                        runCatching {
                            EquipmentVisualApi.solicitarGeracaoSeLiberada(visualId)
                        }
                    }
                }
                resolucao
            }.getOrNull()
        } else null

        val atualizado = equipamento.copy(
            visualFrenteCaminho = frente.ifBlank {
                arteRemota?.visualFrenteCaminho?.ifBlank { equipamento.visualFrenteCaminho }
                    ?: equipamento.visualFrenteCaminho
            },
            visualCostasCaminho = costas.ifBlank {
                arteRemota?.visualCostasCaminho?.ifBlank { equipamento.visualCostasCaminho }
                    ?: equipamento.visualCostasCaminho
            },
            visualLadoEsquerdoCaminho = esquerda.ifBlank {
                arteRemota?.visualLadoEsquerdoCaminho?.ifBlank { equipamento.visualLadoEsquerdoCaminho }
                    ?: equipamento.visualLadoEsquerdoCaminho
            },
            visualLadoDireitoCaminho = direita.ifBlank {
                arteRemota?.visualLadoDireitoCaminho?.ifBlank { equipamento.visualLadoDireitoCaminho }
                    ?: equipamento.visualLadoDireitoCaminho
            },
            visualCamadaTraseiraCaminho = camadaTraseira.ifBlank {
                arteRemota?.visualCamadaTraseiraCaminho?.ifBlank { equipamento.visualCamadaTraseiraCaminho }
                    ?: equipamento.visualCamadaTraseiraCaminho
            },
            visualCamadaDianteiraCaminho = camadaDianteira.ifBlank {
                arteRemota?.visualCamadaDianteiraCaminho?.ifBlank { equipamento.visualCamadaDianteiraCaminho }
                    ?: equipamento.visualCamadaDianteiraCaminho
            },
            perfilEncaixeVisual = VERSAO_PERFIL,
            versaoVisualEquipamento = VERSAO_ARTE
        )
        val pronto = listOf(
            atualizado.visualFrenteCaminho,
            atualizado.visualCostasCaminho,
            atualizado.visualLadoEsquerdoCaminho,
            atualizado.visualLadoDireitoCaminho,
            atualizado.visualCamadaTraseiraCaminho,
            atualizado.visualCamadaDianteiraCaminho
        ).all(String::isNotBlank)

        return ResultadoCatalogoVisualEquipamento(
            equipamento = atualizado,
            visualId = visualId,
            arteDisponivel = pronto,
            criadoAgora = resultado.second
        )
    }

}

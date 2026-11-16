
package br.com.ascensaodosoberano.world

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope

internal fun validarCriaturaParaCatalogoGlobal(criatura: CriaturaGerada) {
    require(criatura.id.isNotBlank()) { "A criatura precisa de um identificador." }
    require(criatura.nome.isNotBlank()) { "A criatura precisa de um nome." }
    // Rank e raridade são conceitos criativos da IA, não enums fechados.
    require(criatura.rank.isNotBlank()) { "A criatura precisa informar seu rank." }
    require(criatura.raridade.isNotBlank()) { "A criatura precisa informar sua raridade." }
    require(criatura.nivel > 0) { "O nível da criatura precisa ser positivo." }
    require(criatura.vidaMaxima > 0) { "A vida máxima da criatura precisa ser positiva." }
    require(criatura.ataque >= 0 && criatura.defesa >= 0)
    require(criatura.manaMaxima >= 0 && criatura.agilidade >= 0 && criatura.poderMagico >= 0)
    require(criatura.experienciaBase >= 0 && criatura.perigo >= 0)
    require(criatura.ecosystemId.isNotBlank()) { "A criatura precisa pertencer a um ecossistema." }
    require(criatura.bioma.isNotBlank()) { "A criatura precisa informar seu bioma." }
    require(criatura.ataques.isNotEmpty()) { "A criatura precisa ter ao menos um ataque utilizável." }
}

data class ResultadoArteOficialCriatura(
    val criatura: CriaturaGerada,
    val custoRealBRL: Double
)

object RepositorioCriaturas {

    private val banco =
        FirebaseFirestore.getInstance()

    // Registra uma criatura somente se ela ainda não existir.
    suspend fun registrarCriaturaGlobal(
        criatura: CriaturaGerada
    ): CriaturaGerada {
        require(criatura.id.matches(Regex("[A-Za-z0-9_-]{1,128}"))) {
            "Identificador da criatura inválido."
        }
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Entre em uma conta para registrar a criatura.")

        val referencia = banco.collection("criaturas").document(criatura.id)

        // Primeiro consulta o catálogo. Se a criatura já existe, usa o registro
        // oficial completo mesmo que o rascunho local esteja incompleto.
        val existente = referencia.get().await()
        val (registrada, _) = if (existente.exists()) {
            val oficial = existente.toObject(CriaturaGerada::class.java)
                ?: throw IllegalStateException("Dados da criatura oficial inválidos.")
            Pair(oficial, false)
        } else {
            validarCriaturaParaCatalogoGlobal(criatura)
            val resultado = banco.runTransaction { transacao ->
                val documento = transacao.get(referencia)
                if (documento.exists()) {
                    val oficial = documento.toObject(CriaturaGerada::class.java)
                        ?: throw IllegalStateException("Dados da criatura oficial inválidos.")
                    Pair(oficial, false)
                } else {
                    val registroInicial = criatura.copy(criadoPorUid = uid)
                    transacao.set(referencia, registroInicial)
                    Pair(registroInicial, true)
                }
            }.await()
            resultado
        }

        // Registros antigos podem existir no catálogo sem criadoPorUid.
        // O primeiro jogador autenticado que solicitar a arte assume a geração
        // visual somente quando esse campo ainda está vazio.
        val registradaComResponsavel = assegurarCriadorDaArte(registrada, uid)
        val imagemAtual = buscarCriaturaComImagem(registradaComResponsavel.id)
        val precisaGerarImagem = imagemAtual?.imagemIconeCaminho.isNullOrBlank()
        val jogadorPodeGerar = registradaComResponsavel.criadoPorUid == uid

        // Gera automaticamente para a criatura inédita. Se a primeira tentativa falhar,
        // o próprio criador pode tentar novamente em outro encontro. O Worker reutiliza
        // a imagem oficial existente e bloqueia gerações concorrentes/duplicadas.
        if (precisaGerarImagem && jogadorPodeGerar) {
            runCatching {
                CreatureImageApi.gerarImagemOficial(registradaComResponsavel.id)
            }.onFailure { erro ->
                android.util.Log.w(
                    "RepositorioCriaturas",
                    "A primeira arte de ${registradaComResponsavel.nome} ainda não foi gerada.",
                    erro
                )
            }
        }

        // Se o serviço visual estiver temporariamente indisponível, mantém o encontro
        // textual e carrega a arte oficial assim que ela estiver disponível.
        return buscarCriaturaComImagem(registradaComResponsavel.id) ?: registradaComResponsavel
    }

    /**
     * Atribui a geração inicial ao primeiro solicitante somente para registros
     * legados sem proprietário. Nunca substitui o criador já gravado.
     */
    private suspend fun assegurarCriadorDaArte(
        criatura: CriaturaGerada,
        uid: String
    ): CriaturaGerada {
        val referencia = banco.collection("criaturas").document(criatura.id)
        return banco.runTransaction { transacao ->
            val documento = transacao.get(referencia)
            if (!documento.exists()) {
                throw IllegalStateException("A criatura não existe mais no catálogo global.")
            }
            val criadorAtual = documento.getString("criadoPorUid").orEmpty()
            if (criadorAtual.isBlank()) {
                transacao.update(referencia, "criadoPorUid", uid)
                criatura.copy(criadoPorUid = uid)
            } else {
                criatura.copy(criadoPorUid = criadorAtual)
            }
        }.await()
    }

    /**
     * Qualquer jogador autenticado pode solicitar a arte oficial global.
     * O Worker valida o catálogo, grava no R2 e publica os metadados no Firebase.
     */
    suspend fun solicitarImagemOficialComAutorizacao(
        criaturaId: String
    ): ResultadoArteOficialCriatura {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Entre em uma conta para gerar a imagem.")
        require(criaturaId.matches(Regex("[A-Za-z0-9_-]{1,100}"))) {
            "Identificador da criatura inválido."
        }
        val registrada = buscarCriatura(criaturaId)
            ?: throw IllegalStateException("A criatura não existe no catálogo global.")
        val registradaComResponsavel = assegurarCriadorDaArte(registrada, uid)
        if (registradaComResponsavel.criadoPorUid != uid) {
            throw IllegalStateException(
                "A primeira arte desta criatura pertence ao jogador que a registrou. Quando ele gerar a imagem, todos poderão reutilizá-la."
            )
        }
        val imagemExistente = buscarCriaturaComImagem(criaturaId)
        if (!imagemExistente?.imagemIconeCaminho.isNullOrBlank()) {
            return ResultadoArteOficialCriatura(imagemExistente!!, 0.0)
        }

        // O servidor grava no R2, publica os metadados e devolve o custo real.
        val resultadoImagem = CreatureImageApi.gerarImagemOficial(criaturaId)
        val criaturaAtualizada = buscarCriaturaComImagem(criaturaId)
            ?.takeIf { it.imagemIconeCaminho.isNotBlank() }
            ?: throw IllegalStateException(
                "A imagem foi enviada ao armazenamento, mas o catálogo ainda está atualizando. Atualize novamente em instantes."
            )
        return ResultadoArteOficialCriatura(criaturaAtualizada, resultadoImagem.actualCostBRL)
    }

    // Carrega a última arte oficial sem modificar o documento principal da criatura.
    suspend fun buscarCriaturaComImagem(
        id: String,
        somenteCache: Boolean = false
    ): CriaturaGerada? {
        val criatura = buscarCriatura(id, somenteCache) ?: return null
        return anexarImagemOficial(criatura, somenteCache)
    }

    private suspend fun anexarImagemOficial(
        criatura: CriaturaGerada,
        somenteCache: Boolean
    ): CriaturaGerada {
        val consultaImagem = banco.collection("criaturas").document(criatura.id).collection("imagens")
            .orderBy("criadaEm", com.google.firebase.firestore.Query.Direction.DESCENDING)
            .limit(1)
        val imagem = if (somenteCache) {
            runCatching {
                consultaImagem.get(com.google.firebase.firestore.Source.CACHE).await().documents.firstOrNull()
            }.getOrNull()
        } else {
            runCatching { consultaImagem.get().await().documents.firstOrNull() }
                .getOrElse {
                    runCatching {
                        consultaImagem.get(com.google.firebase.firestore.Source.CACHE).await().documents.firstOrNull()
                    }.getOrNull()
                }
        } ?: return criatura
        val url = imagem.getString("imageUrl").orEmpty()
        if (!url.startsWith("https://")) return criatura
        return criatura.copy(
            imagemId = imagem.getString("imagemId").orEmpty(),
            imagemIconeCaminho = url,
            imagemDetalhadaCaminho = url
        )
    }

    // Busca todas as criaturas oficiais de um ecossistema.
    suspend fun buscarPorEcossistema(
        ecosystemId: String,
        somenteCache: Boolean = false
    ): List<CriaturaGerada> {

        val consulta = banco
            .collection("criaturas")
            .whereEqualTo("ecosystemId", ecosystemId)

        val resultado = if (somenteCache) {
            consulta.get(com.google.firebase.firestore.Source.CACHE).await()
        } else {
            runCatching { consulta.get().await() }
                .getOrElse {
                    // Se a rede falhar, usa somente o catálogo já armazenado no aparelho.
                    consulta.get(com.google.firebase.firestore.Source.CACHE).await()
                }
        }

        val criaturas = resultado.toObjects(CriaturaGerada::class.java)
        return coroutineScope {
            criaturas.map { criatura ->
                async { anexarImagemOficial(criatura, somenteCache) }
            }.awaitAll()
        }
    }

    // Busca uma criatura já registrada globalmente.
    suspend fun buscarCriatura(
        id: String,
        somenteCache: Boolean = false
    ): CriaturaGerada? {

        val referencia = banco.collection("criaturas").document(id)
        val documento = if (somenteCache) {
            referencia.get(com.google.firebase.firestore.Source.CACHE).await()
        } else {
            runCatching { referencia.get().await() }
                .getOrElse {
                    referencia.get(com.google.firebase.firestore.Source.CACHE).await()
                }
        }

        return documento.toObject(CriaturaGerada::class.java)
    }

    // Registra a descoberta no bestiário individual.
    suspend fun registrarDescoberta(
    uid: String,
    criatura: CriaturaGerada
) {
    require(uid.isNotBlank())
    require(criatura.id.isNotBlank())

    val referencia = banco
        .collection("jogadores")
        .document(uid)
        .collection("bestiario")
        .document(criatura.id)

    banco.runTransaction { transacao ->

        val documento = transacao.get(referencia)

        if (!documento.exists()) {
            transacao.set(
                referencia,
                mapOf(
                    "criaturaId" to criatura.id,
                    "nome" to criatura.nome,
                    "dataDescoberta" to System.currentTimeMillis()
                )
            )
        }
    }.await()
}
    // Busca as criaturas descobertas pelo jogador.
    suspend fun buscarBestiario(
        uid: String
    ): List<CriaturaGerada> {

        require(uid.isNotBlank())

        val descobertas = banco
            .collection("jogadores")
            .document(uid)
            .collection("bestiario")
            .get()
            .await()

        return descobertas.documents.mapNotNull { documento ->
            val criaturaId = documento.getString("criaturaId") ?: documento.id
            buscarCriaturaComImagem(criaturaId)
        }
    }
}
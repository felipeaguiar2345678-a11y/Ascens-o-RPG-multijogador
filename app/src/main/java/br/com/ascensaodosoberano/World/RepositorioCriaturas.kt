
package br.com.ascensaodosoberano.world

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await

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
        val registrada = if (existente.exists()) {
            existente.toObject(CriaturaGerada::class.java)
                ?: throw IllegalStateException("Dados da criatura oficial inválidos.")
        } else {
            validarCriaturaParaCatalogoGlobal(criatura)
            banco.runTransaction { transacao ->
                val documento = transacao.get(referencia)
                if (documento.exists()) {
                    documento.toObject(CriaturaGerada::class.java)
                        ?: throw IllegalStateException("Dados da criatura oficial inválidos.")
                } else {
                    val registroInicial = criatura.copy(criadoPorUid = uid)
                    transacao.set(referencia, registroInicial)
                    registroInicial
                }
            }.await()
        }

        // Registrar/encontrar criatura nunca chama serviço pago.
        // A arte é carregada se já existir; geração fica em ação explícita.
        return buscarCriaturaComImagem(registrada.id) ?: registrada
    }


    /**
     * Qualquer jogador autenticado pode solicitar a arte oficial global.
     * O Worker valida o catálogo, grava no R2 e publica os metadados no Firebase.
     */
    suspend fun solicitarImagemOficialComAutorizacao(criaturaId: String): CriaturaGerada {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Entre em uma conta para gerar a imagem.")
        require(criaturaId.matches(Regex("[A-Za-z0-9_-]{1,100}"))) {
            "Identificador da criatura inválido."
        }
        val criatura = buscarCriatura(criaturaId)
            ?: throw IllegalStateException("A criatura não existe no catálogo global.")
        val imagemExistente = buscarCriaturaComImagem(criaturaId)
        if (!imagemExistente?.imagemIconeCaminho.isNullOrBlank()) return imagemExistente!!

        // O servidor grava a imagem diretamente no R2 e cria os metadados.
        CreatureImageApi.gerarImagemOficial(criaturaId)
        return buscarCriaturaComImagem(criaturaId)
            ?.takeIf { it.imagemIconeCaminho.isNotBlank() }
            ?: throw IllegalStateException(
                "A imagem foi enviada ao armazenamento, mas o catálogo ainda está atualizando. Atualize novamente em instantes."
            )
    }

    // Carrega a última arte oficial sem modificar o documento principal da criatura.
    suspend fun buscarCriaturaComImagem(
        id: String,
        somenteCache: Boolean = false
    ): CriaturaGerada? {
        val criatura = buscarCriatura(id, somenteCache) ?: return null
        val consultaImagem = banco.collection("criaturas").document(id).collection("imagens")
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
        return criatura.copy(
            imagemId = imagem.getString("imagemId").orEmpty(),
            imagemIconeCaminho = imagem.getString("imageUrl").orEmpty(),
            imagemDetalhadaCaminho = imagem.getString("imageUrl").orEmpty()
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

        return resultado.toObjects(CriaturaGerada::class.java)
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
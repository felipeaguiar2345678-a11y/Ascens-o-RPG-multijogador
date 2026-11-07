
package br.com.ascensaodosoberano.world

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await

object RepositorioCriaturas {

    private val banco =
        FirebaseFirestore.getInstance()

    // Registra uma criatura somente se ela ainda não existir.
    suspend fun registrarCriaturaGlobal(
        criatura: CriaturaGerada
    ): CriaturaGerada {

        val ranksValidos = setOf(
            "E", "D", "C", "B", "A", "S", "SS", "SSS"
        )

        val raridadesValidas = setOf(
            "COMUM", "INCOMUM", "RARO",
            "ÉPICO", "LENDÁRIO", "MÍTICO", "MUNDO"
        )

        require(criatura.id.isNotBlank())
        require(criatura.nome.isNotBlank())
        require(criatura.rank.uppercase() in ranksValidos)
        require(criatura.vidaMaxima > 0)
        require(criatura.ataque >= 0 && criatura.defesa >= 0)
        require(criatura.experienciaBase >= 0)
        require(criatura.ecosystemId.isNotBlank())
        require(criatura.raridade.uppercase() in raridadesValidas)

        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Entre em uma conta para registrar a criatura.")

        val referencia = banco
            .collection("criaturas")
            .document(criatura.id)

        val (registrada, criadaAgora) = banco.runTransaction { transacao ->
            val documento = transacao.get(referencia)
            if (documento.exists()) {
                Pair(
                    documento.toObject(CriaturaGerada::class.java)
                        ?: throw IllegalStateException("Dados da criatura oficial inválidos."),
                    false
                )
            } else {
                val registroInicial = criatura.copy(criadoPorUid = uid)
                transacao.set(referencia, registroInicial)
                Pair(registroInicial, true)
            }
        }.await()

        // Só o primeiro registro dispara a geração paga; criaturas já existentes nunca geram arte de novo.
        if (criadaAgora) {
            runCatching { gerarImagemOficialSeAusente(registrada.id) }
        }
        return registrada
    }


    /** Gera a primeira arte oficial apenas para o jogador que registrou a criatura. */
    suspend fun gerarImagemOficialSeAusente(criaturaId: String): CreatureImageResult? {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Entre em uma conta para gerar a imagem.")
        val criaturaRef = banco.collection("criaturas").document(criaturaId)
        val criatura = criaturaRef.get().await().toObject(CriaturaGerada::class.java)
            ?: throw IllegalStateException("A criatura não existe no catálogo global.")
        require(criatura.criadoPorUid == uid) {
            "Somente quem registrou originalmente esta criatura pode gerar sua imagem."
        }
        val existente = criaturaRef.collection("imagens").limit(1).get().await()
        if (!existente.isEmpty) return null
        val imagem = CreatureImageApi.gerarImagemOficial(criaturaId)
        registrarImagemOficial(criaturaId, imagem)
        return imagem
    }

    // Guarda metadados da arte numa subcoleção imutável, sem alterar o documento principal.
    suspend fun registrarImagemOficial(criaturaId: String, imagem: CreatureImageResult) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
            ?: throw IllegalStateException("Entre em uma conta para registrar a imagem.")
        require(criaturaId.isNotBlank() && imagem.imageId.isNotBlank())
        require(imagem.objectKey == "criaturas/$criaturaId.png")
        val criaturaRef = banco.collection("criaturas").document(criaturaId)
        val imagemRef = criaturaRef.collection("imagens").document(imagem.imageId)
        banco.runTransaction { transacao ->
            val criaturaDoc = transacao.get(criaturaRef)
            require(criaturaDoc.exists()) { "A criatura não existe no catálogo global." }
            require(criaturaDoc.getString("criadoPorUid") == uid) {
                "Somente quem registrou a criatura pode adicionar sua imagem oficial."
            }
            if (!transacao.get(imagemRef).exists()) {
                transacao.set(imagemRef, mapOf(
                    "criaturaId" to criaturaId, "imagemId" to imagem.imageId,
                    "criadoPorUid" to uid, "objectKey" to imagem.objectKey,
                    "imageUrl" to imagem.imageUrl, "sizeBytes" to imagem.sizeBytes,
                    "custoRealBRL" to imagem.actualCostBRL,
                    "criadaEm" to System.currentTimeMillis()
                ))
            }
        }.await()
    }

    // Carrega a última arte oficial sem modificar o documento principal da criatura.
    suspend fun buscarCriaturaComImagem(id: String): CriaturaGerada? {
        val criatura = buscarCriatura(id) ?: return null
        val imagem = banco.collection("criaturas").document(id).collection("imagens")
            .orderBy("criadaEm", com.google.firebase.firestore.Query.Direction.DESCENDING)
            .limit(1).get().await().documents.firstOrNull() ?: return criatura
        return criatura.copy(
            imagemId = imagem.getString("imagemId").orEmpty(),
            imagemIconeCaminho = imagem.getString("imageUrl").orEmpty(),
            imagemDetalhadaCaminho = imagem.getString("imageUrl").orEmpty()
        )
    }

    // Busca todas as criaturas oficiais de um ecossistema.
    suspend fun buscarPorEcossistema(
        ecosystemId: String
    ): List<CriaturaGerada> {

        val resultado = banco
            .collection("criaturas")
            .whereEqualTo("ecosystemId", ecosystemId)
            .get()
            .await()

        return resultado.toObjects(CriaturaGerada::class.java)
    }

    // Busca uma criatura já registrada globalmente.
    suspend fun buscarCriatura(
        id: String
    ): CriaturaGerada? {

        val documento = banco
            .collection("criaturas")
            .document(id)
            .get()
            .await()

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

            val criaturaId =
                documento.getString("criaturaId")
                    ?: documento.id

            buscarCriatura(criaturaId)
        }
    }
}
package br.com.ascensaodosoberano.character

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await

class CharacterAIGenerationRepository(
    private val db: FirebaseFirestore =
        FirebaseFirestore.getInstance(),
    private val auth: FirebaseAuth =
        FirebaseAuth.getInstance()
) {

    suspend fun save(
        generation: CharacterAIGeneration
    ) {
        val ownerUid = auth.currentUser?.uid
            ?: throw IllegalStateException(
                "Usuário precisa estar autenticado."
            )

        // A imagem só pode ser associada a um personagem que pertence
        // ao jogador autenticado.
        val character = db.collection("characters")
            .document(generation.characterId)
            .get()
            .await()

        if (!character.exists() ||
            character.getString("ownerUid") != ownerUid
        ) {
            throw SecurityException(
                "Este personagem não pertence ao jogador autenticado."
            )
        }

        val data = CharacterAIGenerationMapper
            .toMap(generation)
            .toMutableMap()

        data["ownerUid"] = ownerUid

        db.collection("characterVisuals")
            .document(generation.characterId)
            .set(data)
            .await()
    }

    suspend fun get(
        characterId: String
    ): CharacterAIGeneration? {
        val ownerUid = auth.currentUser?.uid
            ?: return null

        val document = db.collection("characterVisuals")
            .document(characterId)
            .get()
            .await()

        if (!document.exists()) return null

        // Defesa adicional no aplicativo; as regras do Firestore
        // também verificam o proprietário no servidor.
        if (document.getString("ownerUid") != ownerUid) {
            return null
        }

        val data = document.data ?: return null

        return CharacterAIGenerationMapper.fromMap(data)
    }
}

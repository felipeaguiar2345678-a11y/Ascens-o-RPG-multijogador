package br.com.ascensaodosoberano.character

import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await
import java.security.MessageDigest

data class ClassVisualAsset(
    val classKey: String,
    val className: String,
    val imageUrl: String,
    val imagePath: String,
    val visualVersion: Int
)

/**
 * Catálogo compartilhado: a primeira imagem aprovada para uma identidade de
 * classe é reutilizada por todos os jogadores que escolherem a mesma classe.
 */
class CharacterClassVisualRepository(
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance()
) {
    fun keyFor(characterClass: CharacterClass, appearance: CharacterAppearance): String {
        // A arte compartilhada precisa respeitar a aparência escolhida.
        // Não reutilizar a imagem de outro aventureiro só porque ambos têm a mesma classe.
        val identity = listOf(
            "folha_quatro_angulos_v2",
            characterClass.name.trim().lowercase(),
            characterClass.description.trim().lowercase(),
            appearance.skinId,
            appearance.faceId,
            appearance.hairId,
            appearance.hairColorId,
            appearance.eyeId,
            appearance.outfitId
        ).joinToString("|")
        val bytes = MessageDigest.getInstance("SHA-256")
            .digest(identity.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }

    suspend fun get(characterClass: CharacterClass, appearance: CharacterAppearance): ClassVisualAsset? {
        val key = keyFor(characterClass, appearance)
        val snapshot = db.collection("classVisualCatalog")
            .document(key)
            .get()
            .await()
        if (!snapshot.exists()) return null
        val url = snapshot.getString("imageUrl").orEmpty()
        val path = snapshot.getString("imagePath").orEmpty()
        if (!url.startsWith("https://") || path.isBlank()) return null
        return ClassVisualAsset(
            classKey = key,
            className = snapshot.getString("className").orEmpty(),
            imageUrl = url,
            imagePath = path,
            visualVersion = (snapshot.getLong("visualVersion") ?: 1L).toInt()
        )
    }

    suspend fun save(characterClass: CharacterClass, appearance: CharacterAppearance, asset: ClassVisualAsset) {
        val key = keyFor(characterClass, appearance)
        require(asset.classKey == key)
        require(asset.imageUrl.startsWith("https://"))
        require(asset.imagePath.isNotBlank())
        val reference = db.collection("classVisualCatalog").document(key)
        db.runTransaction { transaction ->
            val current = transaction.get(reference)
            // A imagem vencedora não é sobrescrita por gerações posteriores.
            if (!current.exists()) {
                transaction.set(reference, mapOf(
                    "classKey" to key,
                    "className" to characterClass.name.take(80),
                    "imageUrl" to asset.imageUrl,
                    "imagePath" to asset.imagePath,
                    "visualVersion" to asset.visualVersion,
                    "createdAt" to com.google.firebase.firestore.FieldValue.serverTimestamp()
                ))
            }
        }.await()
    }
}

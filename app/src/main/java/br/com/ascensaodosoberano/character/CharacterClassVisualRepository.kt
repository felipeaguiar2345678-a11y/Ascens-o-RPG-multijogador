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
    fun keyFor(characterClass: CharacterClass): String {
        val identity = listOf(
            characterClass.name.trim().lowercase(),
            characterClass.description.trim().lowercase()
        ).joinToString("|")
        val bytes = MessageDigest.getInstance("SHA-256")
            .digest(identity.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }

    suspend fun get(characterClass: CharacterClass): ClassVisualAsset? {
        val key = keyFor(characterClass)
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

    suspend fun save(characterClass: CharacterClass, asset: ClassVisualAsset) {
        val key = keyFor(characterClass)
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

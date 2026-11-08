package br.com.ascensaodosoberano.character

import android.content.Context
import com.google.gson.Gson
import com.google.gson.JsonSyntaxException

/**
 * Cópia local do personagem. O arquivo fica no armazenamento privado do app.
 * pendingCloudSync indica que o progresso local ainda precisa ser enviado à conta.
 */
data class CharacterLocalRecord(
    val profile: CharacterProfile,
    val ownerUid: String? = null,
    val savedAtMillis: Long = System.currentTimeMillis(),
    val pendingCloudSync: Boolean = true
)

class CharacterLocalStore(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        "ascensao_character_local",
        Context.MODE_PRIVATE
    )
    private val gson = Gson()

    fun loadRecord(): CharacterLocalRecord? {
        val json = preferences.getString(KEY_RECORD, null) ?: return null
        return try {
            gson.fromJson(json, CharacterLocalRecord::class.java)
        } catch (_: JsonSyntaxException) {
            null
        } catch (_: Exception) {
            null
        }
    }

    fun load(): CharacterProfile? = loadRecord()?.profile

    @Synchronized
    fun save(
        profile: CharacterProfile,
        ownerUid: String? = loadRecord()?.ownerUid,
        pendingCloudSync: Boolean = true
    ) {
        require(profile.id.isNotBlank()) { "Personagem inválido." }
        val record = CharacterLocalRecord(
            profile = profile,
            ownerUid = ownerUid,
            savedAtMillis = System.currentTimeMillis(),
            pendingCloudSync = pendingCloudSync
        )
        preferences.edit()
            .putString(KEY_RECORD, gson.toJson(record))
            .commit()
            .also { saved ->
                check(saved) { "Não foi possível gravar o personagem neste aparelho." }
            }
    }

    @Synchronized
    fun markCloudSynced(profileId: String, ownerUid: String) {
        val current = loadRecord() ?: return
        if (current.profile.id != profileId) return
        save(
            profile = current.profile,
            ownerUid = ownerUid,
            pendingCloudSync = false
        )
    }

    companion object {
        private const val KEY_RECORD = "character_record_v1"
    }
}

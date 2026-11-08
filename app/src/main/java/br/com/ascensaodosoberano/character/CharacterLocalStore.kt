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

    /**
     * Cada conta possui seu próprio registro local.
     * O registro legado só pode ser reutilizado por uma conta quando já
     * estiver explicitamente vinculado ao mesmo UID.
     */
    fun loadRecord(ownerUid: String? = null): CharacterLocalRecord? {
        val key = ownerUid?.let { keyForUid(it) } ?: KEY_RECORD
        val json = preferences.getString(key, null)
            ?: if (ownerUid != null) {
                // Compatibilidade com versões antigas que guardavam um único registro.
                val legacy = readRecord(KEY_RECORD)
                if (legacy?.ownerUid == ownerUid) {
                    preferences.edit().putString(key, gson.toJson(legacy)).apply()
                    gson.toJson(legacy)
                } else null
            } else null
            ?: return null
        val record = decodeRecord(json) ?: return null
        // Mesmo que um registro tenha sido gravado na chave errada por uma
        // versão antiga, nunca o entregue a uma conta diferente.
        return if (ownerUid == null || record.ownerUid == ownerUid) record else null
    }

    private fun readRecord(key: String): CharacterLocalRecord? =
        preferences.getString(key, null)?.let(::decodeRecord)

    private fun decodeRecord(json: String): CharacterLocalRecord? = try {
        gson.fromJson(json, CharacterLocalRecord::class.java)
    } catch (_: JsonSyntaxException) {
        null
    } catch (_: Exception) {
        null
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
        val key = ownerUid?.let { keyForUid(it) } ?: KEY_RECORD
        preferences.edit()
            .putString(key, gson.toJson(record))
            .commit()
            .also { saved ->
                check(saved) { "Não foi possível gravar o personagem neste aparelho." }
            }
    }

    @Synchronized
    fun markCloudSynced(profileId: String, ownerUid: String) {
        val current = loadRecord(ownerUid) ?: return
        if (current.profile.id != profileId) return
        save(
            profile = current.profile,
            ownerUid = ownerUid,
            pendingCloudSync = false
        )
    }

    companion object {
        private const val KEY_RECORD = "character_record_v1"
        private const val KEY_RECORD_PREFIX = "character_record_v1_uid_"

        private fun keyForUid(uid: String): String =
            KEY_RECORD_PREFIX + uid
    }
}

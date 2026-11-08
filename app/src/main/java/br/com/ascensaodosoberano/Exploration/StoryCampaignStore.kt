package br.com.ascensaodosoberano.exploration

import android.content.Context

data class StoryCampaignMemory(
    val chapterTitle: String = "Prólogo — A Clareira Inicial",
    val memorySummary: String = "",
    val previousScene: String = "",
    val revision: Long = 0L
)

class StoryCampaignStore(context: Context) {
    private val prefs = context.getSharedPreferences("ascensao_story_campaigns", Context.MODE_PRIVATE)

    fun load(characterId: String): StoryCampaignMemory {
        val prefix = "campaign_$characterId"
        return StoryCampaignMemory(
            chapterTitle = prefs.getString("${prefix}_chapter", "Prólogo — A Clareira Inicial") ?: "Prólogo — A Clareira Inicial",
            memorySummary = prefs.getString("${prefix}_memory", "").orEmpty(),
            previousScene = prefs.getString("${prefix}_scene", "").orEmpty(),
            revision = prefs.getLong("${prefix}_revision", 0L)
        )
    }

    fun save(characterId: String, scene: StoryScene, previousScene: String) {
        val prefix = "campaign_$characterId"
        prefs.edit()
            .putString("${prefix}_chapter", scene.chapterTitle)
            .putString("${prefix}_memory", scene.memorySummary)
            .putString("${prefix}_scene", previousScene.take(2500))
            .putLong("${prefix}_revision", load(characterId).revision + 1L)
            .apply()
    }
}

package br.com.ascensaodosoberano.character

object CharacterAIPrompt {

    fun generate(
        characterName: String,
        appearance: CharacterAppearance,
        characterClass: CharacterClass
    ): String {
        val skin = AppearanceOptions.skinTones
            .firstOrNull { it.id == appearance.skinId }?.name ?: "Clara"
        val face = AppearanceOptions.faces
            .firstOrNull { it.id == appearance.faceId }?.name ?: "Jovem"
        val hair = AppearanceOptions.hairstyles
            .firstOrNull { it.id == appearance.hairId }?.name ?: "Curto"
        val hairColor = AppearanceOptions.hairColors
            .firstOrNull { it.id == appearance.hairColorId }?.name ?: "Castanho"
        val eyes = AppearanceOptions.eyeStyles
            .firstOrNull { it.id == appearance.eyeId }?.name ?: "Normal"
        val descricaoCorpo = appearance.descricaoCorpo.trim()
            .take(700)
            .ifBlank { "Aventureiro humanoide de fantasia, sem espécie especial especificada." }

        fun affinity(domain: SkillDomain): String = when (characterClass.affinities[domain] ?: Affinity.MEDIUM) {
            Affinity.LOW -> "baixa"
            Affinity.MEDIUM -> "média"
            Affinity.HIGH -> "alta"
        }

        return """
            Create a completely original playable hero for a premium fantasy RPG.

            IDENTITY:
            - Character name: $characterName
            - Class/archetype: ${characterClass.name}
            - Player's class concept and powers: ${characterClass.description}
            - Physical affinity: ${affinity(SkillDomain.PHYSICAL)}
            - Magic affinity: ${affinity(SkillDomain.MAGIC)}
            - Agility affinity: ${affinity(SkillDomain.AGILITY)}
            - Defense affinity: ${affinity(SkillDomain.DEFENSE)}
            - Summoning affinity: ${affinity(SkillDomain.SUMMONING)}

            PLAYER-SELECTED APPEARANCE — MUST BE RESPECTED:
            - Skin tone: $skin
            - Face: $face
            - Hairstyle: $hair
            - Hair color: $hairColor
            - Eyes: $eyes
            - Anatomia, espécie e conceito físico descrito livremente pelo jogador: $descricaoCorpo
            - Preserve a ideia escrita pelo jogador sem substituir por uma raça ou espécie padrão.

            ART DIRECTION — MATCH THIS CONSISTENT GAME IDENTITY:
            - Highly detailed, hand-crafted 2.5D pixel art, with a dimensional anime-fantasy look.
            - Strong readable silhouette, expressive anime face, carefully shaped hair locks.
            - Anatomia detalhada e legível; roupa externa e equipamentos serão adicionados em camadas separadas.
            - Crisp pixel clusters, deliberate pixel edges, rich multi-step shading, warm highlights and cool rim light.
            - Deep atmospheric fantasy lighting, subtle magical particles and a restrained colored aura.
            - Detailed enough to feel like a polished character concept from a premium pixel-art RPG.
            - Avoid flat icons, chibi proportions, block people, Minecraft-like cubes, primitive 32x32 sprites,
              blurry painting, smooth vector art, photorealism and generic stock fantasy costumes.

            CLASS EXPRESSION:
            - A classe deve ser reconhecível pela postura, anatomia visual quando aplicável e energia/sinais mágicos,
              mas NÃO deve adicionar armaduras, roupas externas, armas ou acessórios à base corporal.
            - Express the class through its anatomy when relevant, posture, facial expression and subtle
              non-wearable magical energy only. Examples: temporal light for a time mage or spectral
              aura for a necromancer. These effects must not become clothing, armor or accessories.
            - Never force a sword, staff, wings, skulls, robe or any other motif when the class does not call for it.
            - Custom classes must be interpreted from the player's own description, not replaced by a standard class.

            CLASS PRESENTATION — FOUR-VIEW CHARACTER TURNAROUND:
            - Create ONE clean character reference sheet arranged as an exact 2-by-2 grid.
            - Each of the four cells must contain the SAME full-body anatomical base character,
              head to feet, at the same scale, centered, with the complete silhouette visible.
            - TOP LEFT: exact front view, facing the viewer.
            - TOP RIGHT: exact left-side profile, facing left.
            - BOTTOM LEFT: exact rear view, showing the back of the head, hair, anatomy,
              tail, wings and all biological traits from behind.
            - BOTTOM RIGHT: exact right-side profile, facing right.
            - These are four orthographic reference angles, NOT four different characters.
            - Keep identical anatomy, height, proportions, hairstyle, hair length and color,
              skin tone, species traits and class identity in every cell.
            - The character wears ONLY simple opaque neutral underwear/shorts, like a technical
              character-model base. This is not nudity and not the final outfit.
            - NO armor, shirt, pants, boots, gloves, jewelry, weapons, cape, backpack or external clothing.
            - Preserve every requested non-human trait: horns, scales, wings, tail, claws, ears,
              extra limbs or unusual silhouette. Do not hide, remove or normalize them.
            - Leave clear body regions for later transparent equipment layers; armor must be wearable
              without deleting the character's biological traits.
            - Side and rear views must logically continue the exact design visible in the front view.
            - Keep the background simple and identical in all four cells; no action pose, perspective
              distortion, overlapping cells, borders, gutters, labels or decorative panels.
            - The character must occupy a similar amount of space in each cell.
            - No companion, enemies, extra people, captions, letters, UI, watermark or logos.

            ORIGINALITY AND CONTINUITY:
            - Respect every selected appearance characteristic and the actual custom class concept.
            - Create an original design; do not imitate a named copyrighted character.
            - This four-view sheet is the canonical visual reference for the character.
            - Never redesign the character between angles.
        """.trimIndent()
    }
}

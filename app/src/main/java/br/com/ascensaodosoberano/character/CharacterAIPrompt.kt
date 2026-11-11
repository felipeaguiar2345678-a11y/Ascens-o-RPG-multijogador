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
        val outfit = AppearanceOptions.outfits
            .firstOrNull { it.id == appearance.outfitId }?.name ?: "Aventureiro"

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
            - Clothing preference: $outfit

            ART DIRECTION — MATCH THIS CONSISTENT GAME IDENTITY:
            - Highly detailed, hand-crafted 2.5D pixel art, with a dimensional anime-fantasy look.
            - Strong readable silhouette, expressive anime face, carefully shaped hair locks.
            - Layered clothing, belts, armor plates, fabric folds, stitching, ornaments and class-specific accessories.
            - Crisp pixel clusters, deliberate pixel edges, rich multi-step shading, warm highlights and cool rim light.
            - Deep atmospheric fantasy lighting, subtle magical particles and a restrained colored aura.
            - Detailed enough to feel like a polished character concept from a premium pixel-art RPG.
            - Avoid flat icons, chibi proportions, block people, Minecraft-like cubes, primitive 32x32 sprites,
              blurry painting, smooth vector art, photorealism and generic stock fantasy costumes.

            CLASS EXPRESSION:
            - The class concept must be unmistakable from clothing, silhouette, equipment, symbols and magic.
            - A time mage may use hourglass motifs, temporal rings and fractured clockwork light.
            - A light mage may use radiant gold-white details and controlled luminous effects.
            - A necromancer may use dark layered robes, soul sigils and spectral green-violet energy.
            - These are examples only: invent a design that precisely fits the actual class concept above.
            - Never force a sword, staff, wings, skulls, robe or any other motif when the class does not call for it.
            - Custom classes must be interpreted from the player's own description, not replaced by a standard class.

            CLASS PRESENTATION COMPOSITION:
            - Show exactly ONE dominant full-body hero, fully visible from head to boots.
            - Use a dynamic three-quarter action pose that visibly demonstrates the defining ability of this exact class.
            - A warrior is caught in a powerful sword technique; an archer is releasing a precise shot;
              a time mage is bending temporal energy; a fire mage is shaping flame; a necromancer is
              commanding spectral souls. Invent the correct action for any other class concept.
            - The face, eyes, hands, equipment and class effect must be clearly readable at phone-screen size.
            - Keep the silhouette separated from the magical effect so the character is never hidden by it.
            - Isolated transparent background, with only a few restrained class-colored energy particles.
            - Do not create a character sheet, turnaround, portrait panel, multiple poses or extra characters.
            - No captions, letters, UI, watermark, logos or frames.

            ORIGINALITY AND CONTINUITY:
            - Respect every selected appearance characteristic.
            - Create an original design; do not imitate a named copyrighted character.
            - The generated sheet defines the canonical appearance for future portraits, poses,
              combat illustrations and directional sprites.
        """.trimIndent()
    }
}

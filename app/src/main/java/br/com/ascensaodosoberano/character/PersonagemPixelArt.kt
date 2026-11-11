package br.com.ascensaodosoberano.character

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import br.com.ascensaodosoberano.companions.Equipment
import br.com.ascensaodosoberano.companions.EquipmentType
import br.com.ascensaodosoberano.companions.EquipmentLoadout

/**
 * Sprite humano em pixel art 32x32.
 * A silhueta usa volumes separados para cabeça, tronco, braços, pernas e botas,
 * com contorno, luz e sombra para evitar o aspecto de boneco cúbico.
 */
@Composable
fun PersonagemPixelArt(
    appearance: CharacterAppearance,
    modifier: Modifier = Modifier,
    equippedEquipment: List<Equipment> = emptyList(),
    equipmentLoadout: EquipmentLoadout = EquipmentLoadout()
) {
    val skin = when (appearance.skinId) {
        "pele_01" -> Color(0xFFFFDFC4)
        "pele_02" -> Color(0xFFEBC09A)
        "pele_03" -> Color(0xFFB87950)
        "pele_04" -> Color(0xFF75452F)
        "pele_05" -> Color(0xFF432719)
        else -> Color(0xFFEBC09A)
    }
    val hair = when (appearance.hairColorId) {
        "preto" -> Color(0xFF20202A)
        "loiro" -> Color(0xFFE5C16B)
        "branco" -> Color(0xFFE8E8E8)
        "vermelho" -> Color(0xFFB83A32)
        "azul" -> Color(0xFF3768C5)
        "roxo" -> Color(0xFF8546B5)
        else -> Color(0xFF70452D)
    }
    val outfit = when (appearance.outfitId) {
        "roupa_inicial_02" -> Color(0xFF355B7A)
        "roupa_inicial_03" -> Color(0xFF65458F)
        "roupa_inicial_04" -> Color(0xFF34343F)
        "roupa_inicial_05" -> Color(0xFF8A653A)
        else -> Color(0xFF9E3542)
    }
    val eye = when (appearance.eyeId) {
        "olhos_02" -> Color(0xFF4B8B55)
        "olhos_03" -> Color(0xFF70DCEB)
        "olhos_04" -> Color(0xFF8C68D5)
        else -> Color(0xFF332A26)
    }
    val outline = Color(0xFF171923)
    val skinShadow = Color(
        (skin.red * .76f).coerceIn(0f, 1f),
        (skin.green * .70f).coerceIn(0f, 1f),
        (skin.blue * .68f).coerceIn(0f, 1f)
    )
    val clothShadow = Color(
        (outfit.red * .55f).coerceIn(0f, 1f),
        (outfit.green * .55f).coerceIn(0f, 1f),
        (outfit.blue * .55f).coerceIn(0f, 1f)
    )
    val clothLight = Color(
        (outfit.red * 1.22f).coerceIn(0f, 1f),
        (outfit.green * 1.22f).coerceIn(0f, 1f),
        (outfit.blue * 1.22f).coerceIn(0f, 1f)
    )

    Canvas(modifier) {
        val px = size.minDimension / 34f
        val left = (size.width - px * 24f) / 2f
        val top = (size.height - px * 32f) / 2f

        fun pixel(color: Color, x: Int, y: Int, w: Int = 1, h: Int = 1) {
            drawRect(
                color = color,
                topLeft = Offset(left + x * px, top + y * px),
                size = Size(w * px, h * px)
            )
        }

        // Sombra no chão e capa: a capa tem ombros estreitos e barra aberta.
        drawOval(
            color = Color(0x66070B12),
            topLeft = Offset(left + 5f * px, top + 29f * px),
            size = Size(14f * px, 2f * px)
        )
        pixel(outline, 7, 12, 10, 15)
        pixel(clothShadow, 8, 13, 8, 13)
        pixel(outfit, 9, 13, 6, 11)
        pixel(clothLight, 10, 14, 1, 5)
        pixel(clothShadow, 14, 17, 2, 7)
        pixel(outline, 6, 15, 2, 9)
        pixel(outline, 16, 15, 2, 9)
        pixel(clothShadow, 7, 16, 2, 6)
        pixel(clothShadow, 15, 16, 2, 6)

        // Pernas com separação de joelho e botas.
        pixel(outline, 8, 23, 4, 7)
        pixel(outline, 13, 23, 4, 7)
        pixel(Color(0xFF303D50), 9, 23, 3, 6)
        pixel(Color(0xFF263247), 13, 23, 3, 6)
        pixel(Color(0xFF526176), 9, 24, 1, 3)
        pixel(Color(0xFF46546A), 14, 24, 1, 3)
        pixel(outline, 7, 29, 5, 2)
        pixel(outline, 13, 29, 5, 2)
        pixel(Color(0xFF59402F), 8, 29, 4, 1)
        pixel(Color(0xFF59402F), 13, 29, 4, 1)
        pixel(Color(0xFFB58A55), 8, 29, 2, 1)
        pixel(Color(0xFFB58A55), 13, 29, 2, 1)

        // Tronco com cintura e ombros, não um único bloco retangular.
        pixel(outline, 6, 12, 12, 2)
        pixel(outline, 5, 14, 14, 6)
        pixel(outline, 6, 20, 12, 4)
        pixel(clothShadow, 6, 14, 2, 6)
        pixel(outfit, 8, 14, 8, 8)
        pixel(clothLight, 9, 14, 3, 6)
        pixel(clothShadow, 14, 15, 2, 7)
        pixel(Color(0xFF8C673B), 7, 21, 10, 2)
        pixel(Color(0xFFE7C16F), 11, 21, 2, 2)
        pixel(Color(0xFFFFE6A3), 11, 21, 1, 1)

        // Ombreiras, braços e mãos com volumes em camadas.
        pixel(outline, 4, 13, 3, 3)
        pixel(outline, 17, 13, 3, 3)
        pixel(Color(0xFF9AAABD), 5, 13, 2, 2)
        pixel(Color(0xFF9AAABD), 17, 13, 2, 2)
        pixel(clothShadow, 4, 16, 3, 6)
        pixel(outfit, 5, 16, 2, 4)
        pixel(clothShadow, 17, 16, 3, 6)
        pixel(outfit, 17, 16, 2, 4)
        pixel(outline, 4, 21, 3, 3)
        pixel(outline, 17, 21, 3, 3)
        pixel(skinShadow, 5, 21, 2, 2)
        pixel(skin, 17, 21, 2, 2)

        // Pescoço e cabeça com contorno, orelhas e planos de luz.
        pixel(outline, 9, 8, 6, 6)
        pixel(skinShadow, 9, 9, 6, 5)
        pixel(skin, 10, 8, 4, 5)
        pixel(skin, 9, 10, 1, 2)
        pixel(skin, 14, 10, 1, 2)
        pixel(Color(0xFFD18D78), 10, 12, 4, 1)

        // Cabelo por estilo: curto, longo, franja, preso ou raspado.
        if (appearance.hairId != "cabelo_06") {
            pixel(outline, 8, 4, 8, 2)
            pixel(outline, 7, 5, 2, 5)
            pixel(outline, 15, 5, 2, 5)
            pixel(hair, 8, 4, 8, 2)
            pixel(hair, 8, 5, 2, 4)
            pixel(hair, 14, 5, 2, 3)
            when (appearance.hairId) {
                "cabelo_02" -> {
                    pixel(outline, 7, 8, 2, 7)
                    pixel(outline, 15, 8, 2, 7)
                    pixel(hair, 8, 8, 1, 6)
                    pixel(hair, 15, 8, 1, 6)
                }
                "cabelo_03" -> {
                    pixel(outline, 8, 3, 8, 2)
                    pixel(hair, 9, 3, 6, 2)
                    pixel(hair, 10, 6, 5, 2)
                    pixel(hair, 14, 7, 2, 3)
                }
                "cabelo_04" -> {
                    pixel(outline, 7, 7, 2, 8)
                    pixel(outline, 15, 7, 2, 8)
                    pixel(hair, 8, 8, 1, 6)
                    pixel(hair, 15, 8, 1, 6)
                    pixel(hair, 10, 4, 4, 1)
                }
                "cabelo_05" -> {
                    pixel(outline, 9, 2, 6, 4)
                    pixel(hair, 10, 2, 4, 3)
                    pixel(hair, 14, 4, 2, 4)
                }
                else -> {
                    pixel(hair, 8, 6, 2, 3)
                    pixel(hair, 13, 6, 2, 2)
                    pixel(hair, 10, 5, 3, 2)
                }
            }
            pixel(Color.White.copy(alpha = .28f), 9, 4, 2, 1)
        } else {
            pixel(outline, 8, 4, 8, 2)
            pixel(hair, 9, 4, 6, 1)
        }

        // Olhos, sobrancelhas, nariz e boca em pixels individuais.
        pixel(outline, 9, 8, 3, 1)
        pixel(outline, 13, 8, 3, 1)
        pixel(eye, 10, 9, 1, 1)
        pixel(eye, 14, 9, 1, 1)
        pixel(Color.White.copy(alpha = .8f), 10, 9)
        pixel(Color.White.copy(alpha = .8f), 14, 9)
        pixel(skinShadow, 12, 10)
        pixel(Color(0xFF9A5B50), 11, 12, 3, 1)

        // Costuras, placas e detalhes de tecido.
        pixel(Color(0xFF263344), 8, 17, 1, 4)
        pixel(Color(0xFF263344), 15, 17, 1, 4)
        pixel(Color(0xFFB8C5CC), 9, 15, 1, 2)
        pixel(Color(0xFFB8C5CC), 14, 15, 1, 2)
        pixel(Color(0xFFE7C16F), 11, 17, 2, 2)
        pixel(Color(0xFFFFE6A3), 11, 17)
        pixel(Color(0xFF8C673B), 7, 22, 10, 1)
        pixel(Color(0xFFB8C5CC), 9, 25, 1, 2)
        pixel(Color(0xFFB8C5CC), 14, 25, 1, 2)

        // Equipamentos são desenhados por cima do sprite-base.
        val metal = Color(0xFFB8C5D2)
        val metalShadow = Color(0xFF596B7D)
        val gold = Color(0xFFE5BE65)
        if (equippedEquipment.any { it.type == EquipmentType.HELMET }) {
            pixel(outline, 7, 3, 10, 3)
            pixel(metalShadow, 8, 3, 8, 2)
            pixel(metal, 9, 3, 6, 1)
            pixel(gold, 11, 5, 2, 1)
        }
        if (equippedEquipment.any { it.type == EquipmentType.ARMOR }) {
            pixel(outline, 5, 13, 14, 10)
            pixel(metalShadow, 6, 14, 12, 8)
            pixel(metal, 7, 14, 10, 6)
            pixel(Color(0xFF7C8FA1), 9, 15, 6, 5)
            pixel(gold, 11, 20, 2, 2)
        }
        if (equippedEquipment.any { it.type == EquipmentType.GLOVES }) {
            pixel(outline, 3, 20, 4, 4)
            pixel(metal, 4, 21, 2, 2)
            pixel(outline, 17, 20, 4, 4)
            pixel(metal, 18, 21, 2, 2)
        }
        if (equippedEquipment.any { it.type == EquipmentType.BOOTS }) {
            pixel(metalShadow, 7, 28, 5, 3)
            pixel(metalShadow, 13, 28, 5, 3)
            pixel(metal, 8, 28, 3, 1)
            pixel(metal, 14, 28, 3, 1)
        }
        if (equippedEquipment.any { it.type == EquipmentType.NECKLACE }) {
            pixel(gold, 11, 13, 2, 3)
            pixel(Color(0xFF64D9E8), 11, 15, 2, 1)
        }
        if (equippedEquipment.any { it.type == EquipmentType.RING }) {
            pixel(gold, 18, 22, 1, 1)
        }

        val weapon = equippedEquipment.firstOrNull { it.id == equipmentLoadout.weaponId }
        val secondary = equippedEquipment.firstOrNull { it.id == equipmentLoadout.shieldId }
        if (weapon != null) {
            pixel(outline, 20, 11, 2, 17)
            pixel(Color(0xFF76502E), 20, 22, 1, 6)
            pixel(metalShadow, 20, 8, 2, 14)
            pixel(metal, 20, 7, 1, 12)
            pixel(Color(0xFFE6EAF0), 20, 6, 2, 2)
            pixel(gold, 19, 19, 4, 1)
        }
        when (secondary?.type) {
            EquipmentType.SHIELD -> {
                pixel(outline, 1, 14, 5, 11)
                pixel(Color(0xFF527B9C), 2, 15, 3, 9)
                pixel(metal, 3, 16, 1, 6)
                pixel(gold, 3, 18, 1, 2)
            }
            EquipmentType.WEAPON -> {
                pixel(outline, 1, 12, 4, 17)
                pixel(Color(0xFF704A32), 2, 20, 2, 8)
                pixel(metalShadow, 1, 11, 4, 7)
                pixel(metal, 2, 10, 2, 7)
                pixel(gold, 2, 17, 2, 1)
            }
            else -> Unit
        }
    }
}

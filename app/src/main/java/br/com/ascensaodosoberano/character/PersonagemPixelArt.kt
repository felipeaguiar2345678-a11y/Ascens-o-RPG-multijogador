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

/** Prévia em pixel art 16-bit que respeita as opções do criador de personagem. */
@Composable
fun PersonagemPixelArt(
    appearance: CharacterAppearance,
    modifier: Modifier = Modifier,
    equippedEquipment: List<Equipment> = emptyList(),
    equipmentLoadout: EquipmentLoadout = EquipmentLoadout()
) {
    val pele = when (appearance.skinId) {
        "pele_01" -> Color(0xFFFFDFC4)
        "pele_02" -> Color(0xFFEBC09A)
        "pele_03" -> Color(0xFFB87950)
        "pele_04" -> Color(0xFF75452F)
        "pele_05" -> Color(0xFF432719)
        else -> Color(0xFFEBC09A)
    }
    val cabelo = when (appearance.hairColorId) {
        "preto" -> Color(0xFF202020)
        "loiro" -> Color(0xFFE5C16B)
        "branco" -> Color(0xFFE8E8E8)
        "vermelho" -> Color(0xFFB83A32)
        "azul" -> Color(0xFF3768C5)
        "roxo" -> Color(0xFF8546B5)
        else -> Color(0xFF70452D)
    }
    val roupa = when (appearance.outfitId) {
        "roupa_inicial_02" -> Color(0xFF355B7A)
        "roupa_inicial_03" -> Color(0xFF65458F)
        "roupa_inicial_04" -> Color(0xFF34343F)
        "roupa_inicial_05" -> Color(0xFF8A653A)
        else -> Color(0xFF9E3542)
    }
    val sombraRoupa = Color(roupa.red * .52f, roupa.green * .52f, roupa.blue * .52f)
    val olhos = if (appearance.eyeId == "olhos_03" || appearance.eyeId == "olhos_04") {
        Color(0xFF70DCEB)
    } else {
        Color(0xFF332A26)
    }

    Canvas(modifier) {
        val p = size.minDimension / 30f
        val cx = size.width / 2f
        val cy = size.height / 2f
        fun bloco(c: Color, x: Float, y: Float, w: Float, h: Float) {
            drawRect(c, Offset(cx + x * p, cy + y * p), Size(w * p, h * p))
        }

        drawOval(Color(0x660B1420), Offset(cx - p * 10f, cy + p * 12f), Size(p * 20f, p * 3f))
        // Capa e pernas.
        bloco(sombraRoupa, -6f, 1f, 12f, 12f)
        bloco(roupa, -5f, 2f, 10f, 8f)
        bloco(Color(0xFF263344), -4f, 9f, 3f, 5f)
        bloco(Color(0xFF263344), 1f, 9f, 3f, 5f)
        bloco(Color(0xFF171D27), -4.5f, 13f, 4f, 1.5f)
        bloco(Color(0xFF171D27), .5f, 13f, 4f, 1.5f)
        // Tronco, peitoral e cinto.
        bloco(sombraRoupa, -6f, -5f, 12f, 10f)
        bloco(Color(0xFF8295A5), -4f, -4f, 8f, 7f)
        bloco(Color(0xFFB8C5CC), -3f, -4f, 6f, 2f)
        bloco(Color(0xFF8C673B), -6f, 3f, 12f, 2f)
        bloco(Color(0xFFE7C16F), -1f, 3f, 2f, 2f)
        // Braços e ombreiras.
        bloco(sombraRoupa, -8f, -4f, 3f, 8f)
        bloco(sombraRoupa, 5f, -4f, 3f, 8f)
        bloco(Color(0xFFB8C5CC), -8f, -5f, 3f, 2f)
        bloco(Color(0xFFB8C5CC), 5f, -5f, 3f, 2f)
        // Cabeça, rosto e cabelo.
        bloco(pele, -3.5f, -12f, 7f, 8f)
        if (appearance.hairId != "cabelo_06") {
            bloco(cabelo, -4f, -14f, 8f, 3f)
            when (appearance.hairId) {
                "cabelo_02", "cabelo_04" -> {
                    bloco(cabelo, -4f, -12f, 1.5f, 6f)
                    bloco(cabelo, 2.5f, -12f, 1.5f, 6f)
                }
                "cabelo_05" -> {
                    bloco(cabelo, -2f, -17f, 4f, 4f)
                    bloco(cabelo, 2f, -13f, 2f, 3f)
                }
                else -> bloco(cabelo, -4f, -12f, 2f, 3f)
            }
        }
        bloco(olhos, -2f, -9f, 1f, 1.2f)
        bloco(olhos, 1f, -9f, 1f, 1.2f)
        bloco(Color(0xFF9A5B50), -.7f, -6.5f, 1.4f, .7f)
        // Pequenos reflexos para separar os planos do sprite.
        bloco(Color.White.copy(alpha = .45f), -3f, -11f, 1.2f, 1f)
        bloco(Color.White.copy(alpha = .28f), -3f, -3f, 1.5f, 2f)

        // Acabamento do sprite: costuras, placas, luvas, botas e insígnia.
        bloco(Color(0xFF202A37), -5.5f, 10f, 11f, 1.2f)
        bloco(Color(0xFF526273), -3.5f, 10f, 2f, 2.5f)
        bloco(Color(0xFF526273), 1.5f, 10f, 2f, 2.5f)
        bloco(Color(0xFFB8C5CC), -7.5f, -3f, 2f, 3f)
        bloco(Color(0xFFB8C5CC), 5.5f, -3f, 2f, 3f)
        bloco(Color(0xFF263344), -3f, 5f, 1f, 3f)
        bloco(Color(0xFF263344), 2f, 5f, 1f, 3f)
        bloco(Color(0xFFE7C16F), -1f, -1.5f, 2f, 2f)
        bloco(Color(0xFFFFE6A3), -.5f, -1f, 1f, 1f)
        bloco(Color(0xFF8C673B), -7f, 4f, 2f, 3f)
        bloco(Color(0xFF8C673B), 5f, 4f, 2f, 3f)
        bloco(pele.copy(red = (pele.red * .82f).coerceIn(0f, 1f)), -7f, 3f, 2f, 2f)
        bloco(pele.copy(red = (pele.red * .82f).coerceIn(0f, 1f)), 5f, 3f, 2f, 2f)
        bloco(Color.White.copy(alpha = .55f), -1.8f, -9f, .55f, .55f)
        bloco(Color.White.copy(alpha = .55f), 1.2f, -9f, .55f, .55f)
        if (appearance.hairId == "cabelo_03" || appearance.hairId == "cabelo_05") {
            bloco(cabelo, -1f, -13f, 2.5f, 3f)
            bloco(cabelo, 1f, -12f, 1.5f, 2f)
        }
        if (appearance.outfitId == "roupa_inicial_03") {
            bloco(Color(0xFFC7A5F5), -5f, -2f, 1.2f, 5f)
            bloco(Color(0xFFC7A5F5), 3.8f, -2f, 1.2f, 5f)
        }

        // Camadas visuais do equipamento vestido.
        val metal = Color(0xFFB8C5D2)
        val sombraMetal = Color(0xFF596B7D)
        val dourado = Color(0xFFE5BE65)
        val arma = equippedEquipment.firstOrNull { it.id == equipmentLoadout.weaponId }
        val itemNaMaoSecundaria = equippedEquipment.firstOrNull { it.id == equipmentLoadout.shieldId }
        if (equippedEquipment.any { it.type == EquipmentType.HELMET }) {
            bloco(sombraMetal, -4.5f, -15f, 9f, 4f)
            bloco(metal, -3.5f, -15.5f, 7f, 2.5f)
            bloco(dourado, -1f, -14f, 2f, 1f)
        }
        if (equippedEquipment.any { it.type == EquipmentType.ARMOR }) {
            bloco(sombraMetal, -5.5f, -4.5f, 11f, 8f)
            bloco(metal, -4.5f, -4f, 9f, 6f)
            bloco(Color(0xFF7C8FA1), -2.5f, -3f, 5f, 3f)
            bloco(dourado, -1f, 1f, 2f, 1.5f)
        }
        if (equippedEquipment.any { it.type == EquipmentType.GLOVES }) {
            bloco(metal, -9f, 1f, 3f, 3f)
            bloco(metal, 6f, 1f, 3f, 3f)
        }
        if (equippedEquipment.any { it.type == EquipmentType.BOOTS }) {
            bloco(sombraMetal, -4.5f, 12f, 4.5f, 2f)
            bloco(sombraMetal, .5f, 12f, 4.5f, 2f)
            bloco(metal, -4f, 12f, 3f, 1f)
            bloco(metal, 1f, 12f, 3f, 1f)
        }
        if (equippedEquipment.any { it.type == EquipmentType.NECKLACE }) {
            bloco(dourado, -1f, -2f, 2f, 3f)
            bloco(Color(0xFF64D9E8), -.7f, 0f, 1.4f, 1.5f)
        }
        if (equippedEquipment.any { it.type == EquipmentType.RING }) {
            bloco(dourado, 7f, 3f, 1.5f, 1.5f)
        }
        if (arma != null) {
            bloco(Color(0xFF76502E), 9f, 1f, 1.5f, 7f)
            bloco(metal, 8.5f, -5f, 2.5f, 7f)
            bloco(Color(0xFFE6EAF0), 9f, -7f, 1.5f, 3f)
        }
        when (itemNaMaoSecundaria?.type) {
            EquipmentType.SHIELD -> {
                bloco(Color(0xFF76502E), -10f, -2f, 1.5f, 7f)
                bloco(Color(0xFF527B9C), -13f, -3f, 4f, 7f)
                bloco(metal, -12f, -2f, 2f, 5f)
                bloco(dourado, -11.5f, 0f, 1f, 1f)
            }
            EquipmentType.WEAPON -> {
                // Arma pesada ocupa o espaço do escudo e ganha silhueta maior.
                bloco(Color(0xFF704A32), -10f, -2f, 1.5f, 12f)
                bloco(metal, -12f, -4f, 5f, 4f)
                bloco(sombraMetal, -11f, -5f, 3f, 1.5f)
            }
            else -> Unit
        }
    }
}

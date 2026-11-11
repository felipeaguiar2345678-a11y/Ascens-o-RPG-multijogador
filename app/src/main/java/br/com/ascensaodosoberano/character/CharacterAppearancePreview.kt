package br.com.ascensaodosoberano.character

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import br.com.ascensaodosoberano.companions.Equipment
import br.com.ascensaodosoberano.companions.EquipmentLoadout
import coil.compose.AsyncImage

@Composable
fun CharacterAppearancePreview(
    appearance: CharacterAppearance,
    modifier: Modifier = Modifier,
    equippedEquipment: List<Equipment> = emptyList(),
    equipmentLoadout: EquipmentLoadout = EquipmentLoadout()
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .height(260.dp)
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            if (appearance.generatedImageUrl.isNotBlank() && equippedEquipment.isEmpty()) {
                AsyncImage(
                    model = appearance.generatedImageUrl,
                    contentDescription = "Imagem do personagem",
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Fit
                )
            } else {
                Row(
                    modifier = Modifier.fillMaxSize().padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    PersonagemPixelArt(
                        appearance = appearance,
                        modifier = Modifier.size(138.dp),
                        equippedEquipment = equippedEquipment,
                        equipmentLoadout = equipmentLoadout
                    )
                    Column(
                        verticalArrangement = Arrangement.spacedBy(7.dp)
                    ) {
                        Text("Seu aventureiro", style = MaterialTheme.typography.titleMedium)
                        Text("Pele: ${when (appearance.skinId) { "pele_01" -> "Clara"; "pele_02" -> "Morena clara"; "pele_03" -> "Morena"; "pele_04" -> "Retinta"; "pele_05" -> "Retinta escura"; else -> "Personalizada" }}")
                        Text("Cabelo: ${when (appearance.hairId) { "cabelo_01" -> "Curto"; "cabelo_02" -> "Longo"; "cabelo_03" -> "Franja"; "cabelo_04" -> "Ondulado"; "cabelo_05" -> "Preso"; "cabelo_06" -> "Raspado"; else -> "Personalizado" }}")
                        Text("Olhos: ${when (appearance.eyeId) { "olhos_01" -> "Castanhos"; "olhos_02" -> "Verdes"; "olhos_03" -> "Azuis"; "olhos_04" -> "Violetas"; else -> "Personalizados" }}")
                        Text("Roupa: ${when (appearance.outfitId) { "roupa_inicial_01" -> "Aventureiro"; "roupa_inicial_02" -> "Explorador"; "roupa_inicial_03" -> "Místico"; "roupa_inicial_04" -> "Sombras"; "roupa_inicial_05" -> "Mercenário"; else -> "Personalizada" }}")
                        Text(
                            "A prévia usa as opções escolhidas no criador.",
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }
        }
    }
}

package br.com.ascensaodosoberano.companions

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun BlacksmithPanel(
    pointId: String,
    inventory: PlayerInventory,
    onInventoryChanged: (PlayerInventory) -> Unit,
    onMessage: (String) -> Unit,
    rolagemInterna: Boolean = true
) {
    var pergunta by remember(pointId) { mutableStateOf("") }
    val city = BlacksmithSystem.city(pointId)
    val resultadoSugestoes = remember(inventory, pointId, pergunta) {
        runCatching { BlacksmithSystem.suggestions(inventory, pointId, pergunta) }
    }
    val options = resultadoSugestoes.getOrDefault(emptyList())
    val materiais = inventory.items.filter {
        it.type.contains("material", true) || it.materialOrigin.isNotBlank() || it.sourceCreatureId.isNotBlank()
    }

    Column(
        modifier = if (rolagemInterna) Modifier.fillMaxWidth().verticalScroll(rememberScrollState()) else Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text("FERREIRO DE ${city.cityName.uppercase()}", style = MaterialTheme.typography.titleLarge)
        Text(if (city.availableHere) "${city.blacksmithName}: Especialista em ${city.specialty}." else "Não há ferreiro neste local. Viaje até uma cidade ou vila para fabricar equipamentos.")
        Text("Ouro disponível: ${inventory.gold}", style = MaterialTheme.typography.titleMedium)

        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Fale com o ferreiro", style = MaterialTheme.typography.titleMedium)
                Text("Pergunte naturalmente. Exemplo: ‘O que consigo fazer com esses itens, velho?’")
                OutlinedTextField(
                    value = pergunta,
                    onValueChange = { pergunta = it },
                    label = { Text("O que deseja perguntar?") },
                    modifier = Modifier.fillMaxWidth()
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { pergunta = "O que consigo fazer com esses itens, velho?" }) { Text("Ver opções") }
                    TextButton(onClick = { pergunta = "" }) { Text("Limpar") }
                }
                Text(
                    when {
                        !city.availableHere -> "${city.blacksmithName}: Você precisa estar em uma cidade ou vila para negociar e forjar."
                        materiais.isEmpty() -> "${city.blacksmithName}: Volte quando trouxer materiais de criaturas ou recursos de exploração."
                        options.isEmpty() -> "${city.blacksmithName}: Com esses materiais não consigo montar essa peça. Tente pedir outro tipo de equipamento."
                        else -> "${city.blacksmithName}: Dei uma olhada na sua bolsa. Estas são as peças que consigo forjar com o que você trouxe. Os atributos respeitam a origem e as propriedades dos materiais."
                    }
                )
            }
        }

        Text("Seus materiais", style = MaterialTheme.typography.titleMedium)
        if (materiais.isEmpty()) Text("Você ainda não possui materiais de fabricação.")
        materiais.forEach { material ->
            Row(
                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(9.dp)
            ) {
                MaterialPixelArt(
                    tipo = material.name,
                    rank = material.materialRank,
                    modifier = Modifier.size(46.dp)
                )
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text("${material.name} ×${material.quantity}")
                    Text("Rank ${material.materialRank} · Origem: ${material.materialOrigin.ifBlank { "Desconhecida" }}", style = MaterialTheme.typography.bodySmall)
                    if (material.materialTraits.isNotEmpty()) Text("Propriedades: ${material.materialTraits.joinToString()}", style = MaterialTheme.typography.bodySmall)
                }
            }
        }

        Text("Opções de fabricação", style = MaterialTheme.typography.titleMedium)
        if (resultadoSugestoes.isFailure) {
            Text(
                "Não foi possível carregar as opções do ferreiro. Seus itens continuam seguros; tente novamente.",
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall
            )
        }
        options.forEach { option ->
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        EquipamentoPixelArt(
                            tipo = option.equipment.type,
                            raridade = option.equipment.rarity.name,
                            modifier = Modifier.size(64.dp)
                        )
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(option.equipment.name, style = MaterialTheme.typography.titleMedium)
                            Text("Peça forjada · Rank " + option.equipment.rank, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                    val tipoPt = when (option.equipment.type) {
                        EquipmentType.WEAPON -> "Arma"
                        EquipmentType.ARMOR -> "Armadura"
                        EquipmentType.HELMET -> "Elmo"
                        EquipmentType.BOOTS -> "Botas"
                        EquipmentType.GLOVES -> "Luvas"
                        EquipmentType.RING -> "Anel"
                        EquipmentType.NECKLACE -> "Colar"
                        EquipmentType.SHIELD -> "Escudo"
                    }
                    val raridadePt = when (option.equipment.rarity) {
                        EquipmentRarity.COMMON -> "Comum"
                        EquipmentRarity.UNCOMMON -> "Incomum"
                        EquipmentRarity.RARE -> "Raro"
                        EquipmentRarity.EPIC -> "Épico"
                        EquipmentRarity.LEGENDARY -> "Lendário"
                        EquipmentRarity.MYTHIC -> "Mítico"
                        EquipmentRarity.WORLD -> "Mundial"
                    }
                    Text("Tipo: $tipoPt · Rank: ${option.equipment.rank} · Raridade: $raridadePt")
                    Text("Atributos: Força ${option.equipment.attributes.strength}, Inteligência ${option.equipment.attributes.intelligence}, Agilidade ${option.equipment.attributes.agility}, Vitalidade ${option.equipment.attributes.vitality}, Espírito ${option.equipment.attributes.spirit}, Dano físico ${option.equipment.attributes.physicalDamage}, Dano mágico ${option.equipment.attributes.magicalDamage}, Defesa ${option.equipment.attributes.defense}")
                    Text("Materiais: ${option.materialsRequired.map { (id, amount) -> "${materiais.firstOrNull { it.id == id }?.name ?: id} ×$amount" }.joinToString(" + ")}")
                    Text("Custo: ${option.goldCost} de ouro")
                    Text(option.explanation, style = MaterialTheme.typography.bodySmall)
                    Button(
                        enabled = inventory.gold >= option.goldCost,
                        onClick = {
                            runCatching { BlacksmithSystem.craft(inventory, option) }
                                .onSuccess { updated ->
                                    if (updated == null) {
                                        onMessage("Materiais ou ouro insuficientes para esta fabricação.")
                                    } else {
                                        onInventoryChanged(updated)
                                        onMessage("${option.equipment.name} foi forjada! Os materiais foram consumidos e o equipamento foi para seu inventário.")
                                    }
                                }
                                .onFailure { erro ->
                                    onMessage("Não foi possível forjar agora: ${erro.localizedMessage ?: "erro inesperado"}. Seus materiais não foram alterados.")
                                }
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (inventory.gold >= option.goldCost) "FORJAR EQUIPAMENTO" else "OURO INSUFICIENTE") }
                }
            }
        }
    }
}

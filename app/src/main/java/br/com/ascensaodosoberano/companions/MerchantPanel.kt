package br.com.ascensaodosoberano.companions

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun MerchantPanel(
    pointId: String,
    inventory: PlayerInventory,
    merchantOpen: Boolean,
    onInventoryChanged: (PlayerInventory) -> Unit,
    onMessage: (String) -> Unit,
    rolagemInterna: Boolean = true
) {
    val city = BlacksmithSystem.city(pointId)
    Column(
        modifier = if (rolagemInterna) Modifier.fillMaxWidth().verticalScroll(rememberScrollState()) else Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text("MERCADO DE ${city.cityName.uppercase()}", style = MaterialTheme.typography.titleLarge)
        Text("Ouro disponível: ${inventory.gold}")
        if (!city.availableHere || !merchantOpen) {
            Text(if (!city.availableHere) "Não existe mercado neste local." else "O mercado está fechado neste momento.")
            return@Column
        }
        Text("Mercadorias à venda", style = MaterialTheme.typography.titleMedium)
        MerchantSystem.offers(pointId).forEach { offer ->
            Card(Modifier.fillMaxWidth()) {
                Row(Modifier.fillMaxWidth().padding(12.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Text(offer.item.name, style = MaterialTheme.typography.titleSmall)
                        Text("Rank ${offer.item.materialRank} · ${offer.item.description}", style = MaterialTheme.typography.bodySmall)
                        Text("Preço: ${offer.price} ouro", style = MaterialTheme.typography.bodySmall)
                    }
                    Button(
                        enabled = inventory.gold >= offer.price,
                        onClick = {
                            val updated = MerchantSystem.buy(inventory, pointId, offer.id)
                            if (updated == null) onMessage("Ouro insuficiente ou mercadoria indisponível.")
                            else {
                                onInventoryChanged(updated)
                                onMessage("Você comprou ${offer.item.name}.")
                            }
                        }
                    ) { Text("COMPRAR") }
                }
            }
        }
        Text("Vender materiais", style = MaterialTheme.typography.titleMedium)
        val materials = inventory.items.filter {
            it.quantity > 0 && it.type.equals("MATERIAL", ignoreCase = true)
        }
        if (materials.isEmpty()) Text("Você ainda não possui materiais que o mercador possa comprar.")
        materials.forEach { item ->
            val value = MerchantSystem.sellPrice(item)
            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                Column(Modifier.weight(1f)) {
                    Text("${item.name} ×${item.quantity}")
                    Text("O mercador paga ${value} ouro por unidade.", style = MaterialTheme.typography.bodySmall)
                }
                Button(
                    enabled = value > 0L,
                    onClick = {
                        val updated = MerchantSystem.sellOne(inventory, item.id)
                        if (updated == null) onMessage("Não foi possível vender este material.")
                        else {
                            onInventoryChanged(updated)
                            onMessage("Você vendeu uma unidade de ${item.name} por ${value} ouro.")
                        }
                    }
                ) { Text("VENDER 1") }
            }
        }
    }
}

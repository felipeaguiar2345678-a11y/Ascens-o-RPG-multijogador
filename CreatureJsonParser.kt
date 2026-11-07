
package br.com.ascensaodosoberano.world

import br.com.ascensaodosoberano.companions.EquipmentAttributes
import org.json.JSONArray
import org.json.JSONObject

object CreatureJsonParser {

    fun parse(json: JSONObject): CriaturaGerada {
        val id = json.optString("id", "").trim()
        val nome = json.optString("nome", "").trim()

        require(id.isNotEmpty()) {
            "A criatura recebida não possui ID."
        }

        require(nome.isNotEmpty()) {
            "A criatura recebida não possui nome."
        }

        return CriaturaGerada(
            id = id,
            nome = nome,
            descricao = json.optString("descricao", ""),
            rank = json.optString("rank", "E"),
            nivel = json.optInt("nivel", 1),

            vidaMaxima = json.optInt("vidaMaxima", 100),
            ataque = json.optInt("ataque", 10),
            defesa = json.optInt("defesa", 5),
            manaMaxima = json.optInt("manaMaxima", 0),
            agilidade = json.optInt("agilidade", 5),
            poderMagico = json.optInt("poderMagico", 10),

            experienciaBase = json.optInt("experienciaBase", 10),
            perigo = json.optInt("perigo", 10),

            ecosystemId = json.optString("ecosystemId", "unknown"),
            bioma = json.optString("bioma", ""),
            habitat = json.optString("habitat", ""),

            raridade = json.optString("raridade", "COMUM"),

            imagemId = json.optString("imagemId", ""),
            imagemIconeCaminho = json.optString(
                "imagemIconeCaminho", ""
            ),
            imagemDetalhadaCaminho = json.optString(
                "imagemDetalhadaCaminho", ""
            ),

            habilidades = lerTextos(
                json.optJSONArray("habilidades")
            ),

            ataques = lerAtaques(
                json.optJSONArray("ataques")
            ),

            drops = lerDrops(
                json.optJSONArray("drops")
            ),

            chefe = json.optBoolean("chefe", false),
            versao = json.optInt("versao", 1)
        )
    }

    private fun lerAtaques(
        array: JSONArray?
    ): List<AtaqueCriatura> {

        if (array == null) return emptyList()

        return buildList {
            for (i in 0 until array.length()) {
                val item = array.optJSONObject(i) ?: continue

                add(
                    AtaqueCriatura(
                        id = item.optString("id", ""),
                        nome = item.optString("nome", ""),
                        descricao = item.optString("descricao", ""),
                        tipoDano = item.optString(
                            "tipoDano", "FISICO"
                        ),
                        elemento = item.optString(
                            "elemento", "NEUTRO"
                        ),
                        danoBase = item.optInt("danoBase", 0),
                        multiplicador = item.optDouble(
                            "multiplicador", 1.0
                        ).toFloat(),
                        custoMana = item.optInt("custoMana", 0),
                        custoManaMinimo = item.optInt(
                            "custoManaMinimo", 0
                        ),
                        custoManaMaximo = item.optInt(
                            "custoManaMaximo", 0
                        ),
                        efeitos = lerTextos(
                            item.optJSONArray("efeitos")
                        ),
                        duracaoTurnos = item.optInt(
                            "duracaoTurnos", 0
                        ),
                        chanceAplicacao = item.optInt(
                            "chanceAplicacao", 100
                        ),
                        chanceUso = item.optInt(
                            "chanceUso", 50
                        ),
                        turnosCarregamento = item.optInt(
                            "turnosCarregamento", 0
                        ),
                        turnosRecarga = item.optInt(
                            "turnosRecarga", 0
                        ),
                        podeSerInterrompida = item.optBoolean(
                            "podeSerInterrompida", true
                        )
                    )
                )
            }
        }
    }

    private fun lerDrops(
        array: JSONArray?
    ): List<DropCriatura> {

        if (array == null) return emptyList()

        return buildList {
            for (i in 0 until array.length()) {
                val item = array.optJSONObject(i) ?: continue

                add(
                    DropCriatura(
                        itemId = item.optString("itemId", ""),
                        nome = item.optString("nome", ""),
                        descricao = item.optString("descricao", ""),
                        tipo = item.optString(
                            "tipo", "MATERIAL"
                        ),
                        raridade = item.optString(
                            "raridade", "COMUM"
                        ),
                        chancePercentual = item.optDouble(
                            "chancePercentual", 0.0
                        ).toFloat(),
                        garantido = item.optBoolean(
                            "garantido", false
                        ),

                        quantidadeMinima = item.optInt(
                            "quantidadeMinima", 1
                        ),
                        quantidadeMaxima = item.optInt(
                            "quantidadeMaxima", 1
                        ),

                        tipoEquipamento = item.optString(
                            "tipoEquipamento", ""
                        ),
                        raridadeEquipamento = item.optString(
                            "raridadeEquipamento", ""
                        ),
                        rankEquipamento = item.optString(
                            "rankEquipamento", "E"
                        ),
                        nivelRequerido = item.optInt(
                            "nivelRequerido", 1
                        ),

                        atributos = lerAtributos(
                            item.optJSONObject("atributos")
                        ),

                        efeitoEspecial = item.optString(
                            "efeitoEspecial", ""
                        ).takeIf { it.isNotBlank() }
                    )
                )
            }
        }
    }

    private fun lerAtributos(
        json: JSONObject?
    ): EquipmentAttributes {

        if (json == null) {
            return EquipmentAttributes()
        }

        return EquipmentAttributes(
            strength = json.optInt("strength", 0),
            intelligence = json.optInt("intelligence", 0),
            agility = json.optInt("agility", 0),
            vitality = json.optInt("vitality", 0),
            spirit = json.optInt("spirit", 0),
            physicalDamage = json.optInt("physicalDamage", 0),
            magicalDamage = json.optInt("magicalDamage", 0),
            defense = json.optInt("defense", 0)
        )
    }

    private fun lerTextos(
        array: JSONArray?
    ): List<String> {

        if (array == null) return emptyList()

        return buildList {
            for (i in 0 until array.length()) {
                val texto = array.optString(i, "")

                if (texto.isNotBlank()) {
                    add(texto)
                }
            }
        }
    }
}

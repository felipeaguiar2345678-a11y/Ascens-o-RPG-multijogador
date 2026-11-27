-- Registro idempotente das trocas bilaterais.
-- A inserção do registro e as duas atualizações de personagem ocorrem no mesmo D1 batch.
CREATE TABLE IF NOT EXISTS world_trade_transactions (
  world_id TEXT NOT NULL,
  transaction_id TEXT NOT NULL,
  nonce TEXT NOT NULL,
  fingerprint TEXT NOT NULL,
  player_a_key TEXT NOT NULL,
  player_b_key TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (world_id, transaction_id),
  CHECK (player_a_key <> player_b_key)
);

CREATE INDEX IF NOT EXISTS idx_world_trade_transactions_created
  ON world_trade_transactions (created_at);

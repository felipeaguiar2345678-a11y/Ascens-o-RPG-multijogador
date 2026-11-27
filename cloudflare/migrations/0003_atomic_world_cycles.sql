-- Confirmação atômica do ciclo ecológico global.
-- O registro e os 17 documentos (recursos + 16 fragmentos de fauna)
-- são gravados no mesmo D1 batch/transação.
CREATE TABLE IF NOT EXISTS world_cycle_transactions (
  world_id TEXT NOT NULL,
  transaction_id TEXT NOT NULL,
  nonce TEXT NOT NULL,
  fingerprint TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (world_id, transaction_id)
);

CREATE INDEX IF NOT EXISTS idx_world_cycle_transactions_created
  ON world_cycle_transactions (created_at);

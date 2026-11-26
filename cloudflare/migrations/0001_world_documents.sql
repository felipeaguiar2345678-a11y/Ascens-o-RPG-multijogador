-- Armazenamento central do único mundo lógico de Ascensão do Soberano.
-- Aplicar somente após criar e vincular um banco D1 ao Worker.
CREATE TABLE IF NOT EXISTS world_documents (
  world_id TEXT NOT NULL,
  document_key TEXT NOT NULL,
  revision INTEGER NOT NULL CHECK (revision >= 1),
  payload TEXT NOT NULL CHECK (json_valid(payload)),
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (world_id, document_key)
);

CREATE INDEX IF NOT EXISTS idx_world_documents_updated
  ON world_documents (updated_at);

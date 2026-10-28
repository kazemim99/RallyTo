/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** The API origin, without the `/api/v1` prefix (the client adds it per call). Default `http://localhost:5000`. */
  readonly VITE_API_BASE_URL?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

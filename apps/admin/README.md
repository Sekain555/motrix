# Motrix — Panel Admin

Panel de administración para talleres mecánicos de motos.
Parte del monorepo Motrix.

## Requisitos

- Node.js 20+
- pnpm 10+

## Configuración

### 1. Variables de entorno

Copiar `.env.example` de la raíz como `.env.local` y completar:

```env
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

### 2. Instalar dependencias

cd ../..   # volver a la raíz del monorepo
pnpm install

### 3. Ejecutar en desarrollo

pnpm dev
Abre http://localhost:3000

## Deploy en Vercel

Al hacer el primer deploy, configurar estas variables de entorno en Vercel
(Settings → Environment Variables):

Variable | Valor | Entorno
NEXT_PUBLIC_SUPABASE_URL | URL de tu proyecto Supabase | Production / Preview
NEXT_PUBLIC_SUPABASE_ANON_KEY | Clave anónima pública | Production / Preview
SUPABASE_SERVICE_ROLE_KEY | Clave de servicio secreta | Production / Preview

La SUPABASE_SERVICE_ROLE_KEY nunca debe exponerse al frontend.
Solo se usa en funciones server-side de Next.js.

# CONTEXTO — Motrix (Frontend + Backend Supabase)

## Stack tecnológico

| Capa          | Tecnología                | Versión / Notas               |
|---------------|---------------------------|-------------------------------|
| Frontend      | Next.js + TypeScript      | 14+ (App Router)              |
| UI            | shadcn/ui + Tailwind CSS  | Última estable                |
| Backend / DB  | Supabase (PostgreSQL)     | Proyecto cloud                |
| Auth          | Supabase Auth             | Email + password              |
| Monorepo      | Turborepo + pnpm          | Workspaces                    |
| Deploy        | Vercel                    | `apps/admin`                  |
| Package manager  | pnpm                   |                               |

## Arquitectura

Se eligió una **variante de la Arquitectura B (Frontend directo a BaaS)**, documentada en `METODOLOGIA_v2.md`.  
Motrix consume Supabase directamente desde el frontend, sin backend propio. Supabase actúa como BaaS, proporcionando base de datos PostgreSQL, autenticación y Row Level Security.
[Frontend Next.js] -> SDK Supabase -> [Supabase PostgreSQL + Auth + RLS]

- **Aislamiento multi‑tenant mediante RLS** desde el día 1 (política por `tenant_id`).
- El registro de un nuevo taller crea automáticamente el tenant y el perfil `owner`.
- La lógica de negocio relevante (cambio de estado de OT, generación de código) se implementa en funciones PostgreSQL y en el frontend según convenga, sin capa intermedia de API.

## Modelos principales

*Entidades:* tenants, profiles, clients, motorcycles, work_orders, ot_sequences.  

*Campos destacados por entidad:*
- **tenants:** name, slug, plan, business_name, rut, address, phone.
- **motorcycles:** brand, model, year, displacement, plate, color, vin.
- **work_orders:** code, status, description, diagnosis, reception_notes, assigned_to.
- El resto de entidades mantiene los campos definidos en la migración `0001_initial_schema.sql`.

*Relaciones:*
- Un tenant tiene muchos profiles, clients, motorcycles y work_orders.
- Un cliente pertenece a un tenant y puede tener varias motos.
- Una moto pertenece a un cliente y a un tenant.
- Una OT pertenece a un tenant, un cliente y una moto; puede estar asignada a un perfil.

*Operaciones:* CRUD completo para clientes, motos y OTs, filtrado siempre por `tenant_id` (RLS).

## Servicios core

| Servicio        | Responsabilidad                             |
|-----------------|---------------------------------------------|
| Supabase Auth   | Registro, login, sesión, user_metadata       |
| Supabase DB     | Almacenamiento y consultas vía SDK           |
| Supabase RLS    | Aislamiento entre tenants                    |
| Supabase Storage| Para futuros assets del portal cliente       |

## Estado del roadmap (MVP actual)

**Leyenda:** 🔴 BACKLOG · 🟡 EN PROGRESO · 🔵 EN REVISIÓN · 🟢 DONE

- 🟢 DONE  
  1. Setup Monorepo (Alta · M · MVP) ✅  
  2. Schema Inicial y Migración (Alta · M · MVP) ✅

- 🔵 EN REVISIÓN  
  *(vacío)*

- 🟡 EN PROGRESO  
  3. Variables de Entorno y Config inicial (Alta · S · MVP)

- 🔴 BACKLOG  
  4. Auth Multitenant (Alta · M · MVP)  
  5. Layout Dashboard y Navegación (Alta · S · MVP)  
  6. CRUD de Clientes (Alta · M · MVP)  
  7. CRUD de Motos (Alta · M · MVP)  
  8. Órdenes de Trabajo (Alta · L · MVP)  
  9. Dashboard KPIs (Media · S · MVP)  
  10. Deploy en Vercel (Media · S · MVP)  
  11. Ajustes Responsive (Baja · S · MVP)

## Pendientes técnicos conocidos

- Definir si el campo `rut` se mantendrá obligatorio u opcional (RUT chileno).
- Evaluar si `work_orders.status` conviene como `VARCHAR` con `CHECK` en lugar de `ENUM` para facilitar evolución del flujo.
- Portal cliente con avatar 3D (React Three Fiber) queda **fuera del MVP**; se planificará en categoría post‑MVP.
- **Post-MVP:** Agregar campo "Enviado a:" (derivación a terceros) en `work_orders` para cubrir toda la información de una OT física chilena.

## Decisiones de arquitectura

1. **Supabase en lugar de backend propio**  
   - La experiencia previa con TechFlow (Firebase) demostró que un BaaS acelera el MVP y simplifica la infraestructura.  
   - Supabase ofrece PostgreSQL relacional y RLS nativo, lo que permite mantener las ventajas de una base de datos relacional sin sacrificar velocidad de desarrollo.

2. **Monorepo con Turborepo + pnpm**  
   - Facilita la futura incorporación de la app `cliente/` (portal 3D) como workspace adicional.  
   - Mejora la caché de builds y la organización del código compartido.

3. **shadcn/ui + Tailwind CSS**  
   - Componentes accesibles y personalizables, sin dependencia de librerías pesadas de UI.  
   - Consistencia visual con bajo acoplamiento.

## Notas de desarrollo

### Flujo de ramas Git
- feature/nombre-descriptivo → dev → main (release)
- `dev` rama de integración continua.
- `main` solo recibe merges de `dev` cuando se lanza una versión.
- Una rama por card, sin excepciones.  
- Merge vía **Squash & Merge** siempre.

### Convención de commits
- `feat:` nueva funcionalidad.
- `fix:` corrección de bug.
- `chore:` configuración, documentación, migraciones.

### Metodología Trello
Columnas: `BACKLOG → EN PROGRESO → EN REVISIÓN / TESTING → HECHO / DONE`  
Cada card lleva tres etiquetas:
- **Prioridad:** Alta / Media / Baja (color rojo / naranja / verde)
- **Tamaño:** S / M / L (color azul / amarillo / violeta)
- **Categoría:** MVP (color a definir), post‑MVP, etc.

Formato de card y cierre según lo especificado en `METODOLOGIA_v2.md`.

### Pruebas y RLS
- RLS se prueba manualmente desde el primer momento: crear dos tenants y verificar que sus datos no se cruzan.
- Las políticas RLS están definidas en la migración inicial (`schema-inicial`).

---

*Última actualización: 26 de abril de 2026*
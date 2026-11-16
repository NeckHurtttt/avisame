# Avisame 💗

> *"Avisame cuando llegues."* Ahora no depende de que alguien se acuerde.

**Página:** https://neckhurtttt.github.io/avisame/ (muestra "Falta configurar" hasta llenar `config.js`)

Marca cuándo sales. Si no confirmas que llegaste a tiempo, tus contactos de confianza reciben una alerta por Telegram con tu última ubicación. Hecho para **Nodo Cero — Hackathon n8n Bolivia**.

## Cómo funciona

```
Página (Clerk login) ──token de Clerk──▶ Supabase (tablas con RLS)
        │                                    │ Database Webhook (INSERT/UPDATE viajes)
        │                                    ▼
Clerk ──webhook user.created──▶  n8n  ◀── cada minuto: viajes vencidos
                                   │
                                   ▼
                          Telegram (avisos a contactos)
```

- **Clerk:** inicio de sesión. Su token entra directo a Supabase (integración nativa), así cada usuaria solo ve sus datos. El webhook `user.created` guarda el perfil desde n8n.
- **Supabase:** tablas `perfiles`, `contactos`, `viajes` con Row Level Security.
- **n8n** (1 workflow, 4 flujos):
  1. **Clerk → perfil**: guarda a la usuaria nueva.
  2. **Telegram `/start CODIGO`**: el contacto abre el link del bot y queda vinculado.
  3. **Cambio en viajes**: avisa "salió", "llegó bien" o "🆘 pánico".
  4. **Vigilante (cada minuto)**: viajes vencidos → `alerta` → avisa con link de Google Maps.
- **Telegram:** el bot es gratis y n8n ya trae el nodo.

## Archivos

| Archivo | Qué es |
|---|---|
| `index.html` | La app (una sola página, funciona en el celular) |
| `config.js` | Claves públicas (llenar) |
| `supabase.sql` | Tablas y reglas |
| `n8n/avisame.json` | Workflow para importar en n8n |

## Puesta en marcha (≈ 40 min)

1. **Supabase:** crear proyecto → *SQL Editor* → pegar `supabase.sql` → *Run*.
2. **Clerk:** crear aplicación (correo y Google). Ir a la integración **Supabase** de Clerk y activarla; copiar el *Clerk domain*.
   En Supabase → *Authentication → Sign In / Providers → Third-Party Auth* → **Add Clerk** → pegar el dominio.
3. **Telegram:** hablar con **@BotFather** → `/newbot` → guardar el **token** y el **nombre del bot**.
4. **n8n** (n8n Cloud de prueba, o uno propio con HTTPS público — el trigger de Telegram lo necesita):
   - *Import from file* → `n8n/avisame.json`.
   - Crear credencial **Supabase** (Host = URL del proyecto, Service Role Secret = *service_role key* de Supabase → *Project Settings → API*).
   - Crear credencial **Telegram** con el token.
   - Abrir cada nodo rojo y elegir la credencial. Guardar y **activar** el workflow.
5. **Clerk → Webhooks → Add Endpoint:** URL de producción del nodo *Clerk: usuaria nueva* (`…/webhook/llegue-clerk`), evento `user.created`.
6. **Supabase → Database → Webhooks → Create:** tabla `viajes`, eventos **Insert** y **Update**, tipo HTTP POST a la URL del nodo *Supabase: cambio en viajes* (`…/webhook/llegue-viajes`).
7. **`config.js`:** pegar *Publishable key* de Clerk, URL y *anon key* de Supabase y el nombre del bot (sin @).
8. **Probar en la compu:** `python3 -m http.server 8080` en esta carpeta → abrir http://localhost:8080.
   **Para el celular** (la ubicación pide HTTPS): subir la carpeta a GitHub Pages o Vercel.

## Demo (3 min)

1. **Historia:** "¿Cuántas veces le escribiste a una amiga 'avisame cuando llegues'… y se olvidó?"
2. Una jurado escanea el **QR** del contacto → aprieta *Iniciar* en Telegram → aparece ✅ conectado.
3. **Salgo** con "1 minuto (demo)" → a la jurado le llega "salió hacia Casa".
4. No apretar *Llegué*. Al minuto le llega la **alerta con el mapa**.
5. Apretar *Estoy bien, ya llegué* → le llega "llegó bien ✅". (Extra: botón 🆘 Pánico.)
6. Mostrar el workflow de n8n en pantalla.

**Respaldo:** sacar capturas o un video de la demo funcionando, por si falla el internet.

## Si algo falla

- **"Falta configurar":** `config.js` todavía tiene `PEGAR_AQUI`.
- **Error de permisos al guardar (RLS):** revisar el paso 2 (Clerk ↔ Supabase). El token de Clerk debe llevar `role: authenticated`, y eso lo pone la integración de Supabase en Clerk.
- **No llegan avisos:** ¿el workflow está *activo*? ¿El webhook de Supabase apunta a la URL de **producción** (`/webhook/`, no `/webhook-test/`)? En n8n → *Executions* se ve qué nodo falló.
- **El contacto no queda ✅:** debe abrir el link exacto y apretar *Iniciar*. El bot espera `/start` + código de 8 caracteres.
- **Nodo de Supabase con campos vacíos al importar:** rellenar a mano. Filtros usados: `estado=eq.en_camino&limite=lt.<ahora>`, `usuaria_id=eq.<id>&telegram_chat_id=not.is.null`, `codigo=eq.<código>`.

## Seguridad (para mencionar: siguientes pasos)

Es un prototipo: no reemplaza a la policía (**110**). Antes de usarlo de verdad faltaría: verificar la firma Svix del webhook de Clerk, ponerle *Header Auth* al webhook de viajes, permitir varios destinos guardados y compartir la ubicación en vivo.

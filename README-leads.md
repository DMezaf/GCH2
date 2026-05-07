# Landing + API de Leads

Este módulo agrega una landing para campañas digitales y una API local para capturar leads con datos de atribución.

## Archivos principales

- `landing-campanas.html`: landing con formulario y captura de UTMs.
- `api/lead-server.ps1`: servidor local en PowerShell.
- `api/data/leads.json`: almacenamiento estructurado de leads.
- `api/data/leads.csv`: exportación simple para marketing y ventas.

## Cómo iniciarlo

Abre PowerShell en `GCH/WEB` y ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File .\api\lead-server.ps1
```

Si quieres otro puerto:

```powershell
powershell -ExecutionPolicy Bypass -File .\api\lead-server.ps1 -Port 8090
```

## URLs

- Landing: `http://localhost:8080/landing-campanas.html`
- API GET: `http://localhost:8080/api/leads`
- API POST: `http://localhost:8080/api/leads`

## Ejemplo de enlace con UTMs

```text
http://localhost:8080/landing-campanas.html?utm_source=google&utm_medium=cpc&utm_campaign=certificaciones_q2&utm_content=anuncio_a
```

## Ejemplo de body para la API

```json
{
  "nombre": "María López",
  "empresa": "Empresa Demo",
  "telefono": "3312345678",
  "email": "maria@demo.com",
  "servicio": "Certificaciones",
  "mensaje": "Quiero una propuesta",
  "utm_source": "google",
  "utm_medium": "cpc",
  "utm_campaign": "certificaciones_q2"
}
```

## Siguiente evolución sugerida

1. Conectar a una base de datos real.
2. Enviar notificaciones por correo o WhatsApp.
3. Integrar con CRM.
4. Crear dashboard de campañas y conversión.

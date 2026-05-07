param(
  [int]$Port = 8080
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$webRoot = Split-Path -Parent $scriptDir
$dataDir = Join-Path $scriptDir "data"
$jsonFile = Join-Path $dataDir "leads.json"
$csvFile = Join-Path $dataDir "leads.csv"

if (-not (Test-Path $dataDir)) {
  New-Item -ItemType Directory -Path $dataDir | Out-Null
}

if (-not (Test-Path $jsonFile)) {
  Set-Content -Path $jsonFile -Value "[]"
}

if (-not (Test-Path $csvFile)) {
  Set-Content -Path $csvFile -Value "id,created_at,nombre,empresa,cargo,telefono,email,servicio,origen,presupuesto,mensaje,estado,utm_source,utm_medium,utm_campaign,utm_term,utm_content,gclid,fbclid,landing_page,referrer,user_agent"
}

function Get-ContentType {
  param([string]$Path)

  switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
    ".html" { "text/html; charset=utf-8" }
    ".css" { "text/css; charset=utf-8" }
    ".js" { "application/javascript; charset=utf-8" }
    ".json" { "application/json; charset=utf-8" }
    ".xml" { "application/xml; charset=utf-8" }
    ".txt" { "text/plain; charset=utf-8" }
    ".svg" { "image/svg+xml" }
    ".png" { "image/png" }
    ".jpg" { "image/jpeg" }
    ".jpeg" { "image/jpeg" }
    ".webp" { "image/webp" }
    ".gif" { "image/gif" }
    ".pdf" { "application/pdf" }
    default { "application/octet-stream" }
  }
}

function Send-Json {
  param(
    [Parameter(Mandatory = $true)]$Response,
    [Parameter(Mandatory = $true)]$Body,
    [int]$StatusCode = 200
  )

  $json = $Body | ConvertTo-Json -Depth 8
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $Response.StatusCode = $StatusCode
  $Response.ContentType = "application/json; charset=utf-8"
  $Response.ContentLength64 = $bytes.Length
  $Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $Response.OutputStream.Close()
}

function Convert-ToCsvValue {
  param([object]$Value)

  if ($null -eq $Value) {
    return '""'
  }

  $text = [string]$Value
  $text = $text.Replace('"', '""')
  '"' + $text + '"'
}

function Read-Leads {
  if (-not (Test-Path $jsonFile)) {
    return @()
  }

  $raw = Get-Content -Path $jsonFile -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return @()
  }

  $parsed = $raw | ConvertFrom-Json
  if ($parsed -is [System.Array]) {
    return $parsed
  }

  return @($parsed)
}

function Save-Lead {
  param([hashtable]$Lead)

  $current = @()
  $existing = Read-Leads
  if ($existing) {
    $current += $existing
  }

  $current += [pscustomobject]$Lead
  @($current) | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonFile

  $fields = @(
    "id", "created_at", "nombre", "empresa", "cargo", "telefono", "email", "servicio",
    "origen", "presupuesto", "mensaje", "estado", "utm_source", "utm_medium",
    "utm_campaign", "utm_term", "utm_content", "gclid", "fbclid", "landing_page",
    "referrer", "user_agent"
  )

  $line = ($fields | ForEach-Object { Convert-ToCsvValue $Lead[$_] }) -join ","
  Add-Content -Path $csvFile -Value $line
}

function Get-RequestBody {
  param($Request)

  $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
  try {
    return $reader.ReadToEnd()
  } finally {
    $reader.Close()
  }
}

$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host "Lead server activo en $prefix"
Write-Host "Landing: $prefix/landing-campanas.html"
Write-Host "API: POST $prefix/api/leads"

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    try {
      if ($request.HttpMethod -eq "OPTIONS") {
        $response.StatusCode = 204
        $response.AddHeader("Access-Control-Allow-Origin", "*")
        $response.AddHeader("Access-Control-Allow-Headers", "Content-Type")
        $response.AddHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        $response.OutputStream.Close()
        continue
      }

      $path = [System.Uri]::UnescapeDataString($request.Url.AbsolutePath)

      if ($path -eq "/api/leads" -and $request.HttpMethod -eq "GET") {
        $response.AddHeader("Access-Control-Allow-Origin", "*")
        $leadList = @()
        $leadList += Read-Leads
        Send-Json -Response $response -Body @{
          ok = $true
          count = $leadList.Length
          leads = @($leadList)
        }
        continue
      }

      if ($path -eq "/api/leads" -and $request.HttpMethod -eq "POST") {
        $response.AddHeader("Access-Control-Allow-Origin", "*")
        $body = Get-RequestBody -Request $request

        if ([string]::IsNullOrWhiteSpace($body)) {
          Send-Json -Response $response -StatusCode 400 -Body @{
            ok = $false
            error = "El body no puede ir vacío."
          }
          continue
        }

        $payload = $body | ConvertFrom-Json

        if ([string]::IsNullOrWhiteSpace([string]$payload.nombre)) {
          Send-Json -Response $response -StatusCode 400 -Body @{
            ok = $false
            error = "El campo nombre es obligatorio."
          }
          continue
        }

        if ([string]::IsNullOrWhiteSpace([string]$payload.email) -and [string]::IsNullOrWhiteSpace([string]$payload.telefono)) {
          Send-Json -Response $response -StatusCode 400 -Body @{
            ok = $false
            error = "Debes enviar al menos email o teléfono."
          }
          continue
        }

        $now = Get-Date
        $lead = @{
          id = $now.ToString("yyyyMMddHHmmssfff")
          created_at = $now.ToString("s")
          nombre = [string]$payload.nombre
          empresa = [string]$payload.empresa
          cargo = [string]$payload.cargo
          telefono = [string]$payload.telefono
          email = [string]$payload.email
          servicio = [string]$payload.servicio
          origen = [string]$payload.origen
          presupuesto = [string]$payload.presupuesto
          mensaje = [string]$payload.mensaje
          estado = if ([string]::IsNullOrWhiteSpace([string]$payload.estado)) { "nuevo" } else { [string]$payload.estado }
          utm_source = [string]$payload.utm_source
          utm_medium = [string]$payload.utm_medium
          utm_campaign = [string]$payload.utm_campaign
          utm_term = [string]$payload.utm_term
          utm_content = [string]$payload.utm_content
          gclid = [string]$payload.gclid
          fbclid = [string]$payload.fbclid
          landing_page = [string]$payload.landing_page
          referrer = [string]$payload.referrer
          user_agent = [string]$payload.user_agent
        }

        Save-Lead -Lead $lead

        Send-Json -Response $response -StatusCode 201 -Body @{
          ok = $true
          message = "Lead guardado correctamente."
          lead = $lead
        }
        continue
      }

      if ($path -eq "/") {
        $path = "/landing-campanas.html"
      }

      $relative = $path.TrimStart("/") -replace "/", "\"
      $fullPath = Join-Path $webRoot $relative
      $resolvedRoot = [System.IO.Path]::GetFullPath($webRoot)
      $resolvedPath = [System.IO.Path]::GetFullPath($fullPath)

      if (-not $resolvedPath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Send-Json -Response $response -StatusCode 403 -Body @{
          ok = $false
          error = "Ruta no permitida."
        }
        continue
      }

      if (-not (Test-Path $resolvedPath -PathType Leaf)) {
        Send-Json -Response $response -StatusCode 404 -Body @{
          ok = $false
          error = "Recurso no encontrado."
        }
        continue
      }

      $bytes = [System.IO.File]::ReadAllBytes($resolvedPath)
      $response.StatusCode = 200
      $response.ContentType = Get-ContentType -Path $resolvedPath
      $response.ContentLength64 = $bytes.Length
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
      $response.OutputStream.Close()
    } catch {
      if ($response.OutputStream.CanWrite) {
        Send-Json -Response $response -StatusCode 500 -Body @{
          ok = $false
          error = $_.Exception.Message
        }
      }
    }
  }
} finally {
  $listener.Stop()
  $listener.Close()
}

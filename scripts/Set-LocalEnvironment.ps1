# Dot-source this file in the current shell. It never prints credentials.
$env:PGHOST = 'localhost'
$env:PGPORT = '5432'
$env:PGDATABASE = 'shannon_dev'
$env:PGUSER = 'shannon_app'
$env:PGSSLMODE = 'disable' # Local development only.
$env:HTTP_ADDR = '127.0.0.1:8080'
if (-not $env:PGPASSWORD) {
    $env:PGPASSWORD = [Environment]::GetEnvironmentVariable('PGPASSWORD', 'User')
}
# pgx also supports the standard %APPDATA%\postgresql\pgpass.conf file.

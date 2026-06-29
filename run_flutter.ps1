$env:Path = ($env:Path -split ';' | Where-Object { $_ -notmatch 'SECU&TECHNOLOGY' }) -join ';'
flutter run -d web-server --web-port=8080 --web-hostname=localhost

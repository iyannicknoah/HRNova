$env:Path = ($env:Path -split ';' | Where-Object { $_ -notmatch 'SECU&TECHNOLOGY' }) -join ';'
flutter analyze

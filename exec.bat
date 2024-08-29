cd windows-amd64
powershell -Command "java/bin/java -Xmx16384m --enable-preview '-Djava.library.path=$((Get-Location).Path)..\..\lib' -cp 'lib/SSRenderer.jar;lib/*' SSRenderer"
$b64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
$bytes = [Convert]::FromBase64String($b64)
[IO.File]::WriteAllBytes('H:\Work\SoundMesh\SoundMesh\app\assets\logos\soundmesh-logo-white-trans.png', $bytes)
[IO.File]::WriteAllBytes('H:\Work\SoundMesh\SoundMesh\app\assets\logos\soundmesh-logo-black-trans.png', $bytes)
Write-Host "Done"
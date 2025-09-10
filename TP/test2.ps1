    # Nom du datacenter cible
$datacenterName = "StudentDC01"

# Récupérer le datacenter
$dc = Get-Datacenter -Name $datacenterName
if (-not $dc) {
    Write-Host "Datacenter '$datacenterName' introuvable !" -ForegroundColor Red
    exit
}

# Récupérer tous les ESXi hosts du datacenter
$hosts = Get-VMHost -Location $dc

# Pour chaque hôte, récupérer les disques non utilisés de 6GB
foreach ($vmhost in $hosts) {
    Write-Host "`nTraitement de l'hôte : $($vmhost.Name)" -ForegroundColor Cyan

    # Récupération des disques libres
    $freeDisks = Get-ScsiLun -VmHost $vmhost -LunType disk | Where-Object {
        $_.CapacityGB -eq 6 -and $_.CanonicalName -notin (Get-Datastore -VmHost $vmhost).ExtensionData.Config.Vmfs | ForEach-Object { $_.Name }
    }

    if ($freeDisks.Count -eq 0) {
        Write-Host "Aucun disque libre de 6GB trouvé pour cet hôte." -ForegroundColor Yellow
        continue
    }

    # Créer un datastore pour chaque disque libre
    foreach ($disk in $freeDisks) {
        $dsName = "DS_$($vmhost.Name)_$($disk.CanonicalName)"
        Write-Host "Création du datastore $dsName sur disque $($disk.CanonicalName)..."

        try {
            New-Datastore -Vmfs -Name $dsName -VmHost $vmhost -Disk $disk -Confirm:$false
            Write-Host "Datastore $dsName créé avec succès !" -ForegroundColor Green
        } catch {
            Write-Host "Erreur lors de la création du datastore $dsName : $_" -ForegroundColor Red
        }
    }
}

$vms = Get-VM -Location StudentDC01 | Where-Object { $_.MemoryGB -lt 1 }
$restartVms = @()
foreach($vm in $vms) {
        if ($vm.PowerState -eq 'PoweredOff') {
                $vm | Start-VM -Confirm:$false | Out-Null
        } else {
                $vm | Stop-VM -Confirm:$false | Out-Null
                $restartVms += $vm
                Start-Sleep -Seconds 1
                $vm | Start-VM -Confirm:$false
        }
}
Write-Host("Restart VM: $restartVms")
$startVms = $vms | Where-Object { $restartVms -notcontains $_ }
Write-Host("Start VM: $startVms")
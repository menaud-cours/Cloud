foreach($vm in Get-VM) {
    if($vm.PowerState -eq 'PoweredOn') {
        Write-Host $vm.Name -ForegroundColor Green
    }
    if($vm.PowerState -eq 'PoweredOff') {
        Write-Host $vm.Name -ForegroundColor Red
    }
}

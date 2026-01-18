$Location            = "francecentral"
$ResourceGroupName      = "mate-azure-task-9"
$NetworkSecurityGroup   = "defaultnsg"
$VirtualNetworkName     = "vnet"
$SubnetName             = "default"
$VnetAddressPrefix      = "10.0.0.0/16"
$SubnetAddressPrefix    = "10.0.0.0/24"
$PublicIpName           = "whatislavx-pip"
$SshKeyName             = "linuxboxsshkey"
$SshKeyPublicKey        = Get-Content "C:\Users\Asus\.ssh\id_ed25519.pub" -Raw
$VmName                 = "matebox"
$VmSize                 = "Standard_B2ts_v2"
$AdminUsername          = "azureuser"

New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Force

$RuleSSH = New-AzNetworkSecurityRuleConfig -Name "SSH" -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$RuleHTTP = New-AzNetworkSecurityRuleConfig -Name "HTTP" -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow

$NSG = New-AzNetworkSecurityGroup -Name $NetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $Location -SecurityRules $RuleSSH, $RuleHTTP

$VNet = New-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $ResourceGroupName -Location $Location -AddressPrefix $VnetAddressPrefix

$SubnetConfig = Add-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix -VirtualNetwork $VNet -NetworkSecurityGroup $NSG
$VNet = Set-AzVirtualNetwork -VirtualNetwork $VNet

$SubnetId = ($VNet.Subnets | Where-Object { $_.Name -eq $SubnetName }).Id

$PublicIp = New-AzPublicIpAddress -Name $PublicIpName -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Static -Sku Standard -DomainNameLabel "wbx-$(Get-Random)"

$SshKey = New-AzSshKey -Name $SshKeyName -ResourceGroupName $ResourceGroupName -PublicKey $SshKeyPublicKey

$Nic = New-AzNetworkInterface -Name "$VmName-nic" -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $SubnetId -PublicIpAddressId $PublicIp.Id

$VmConfig = New-AzVmConfig -VMName $VmName -VMSize $VmSize
$VmConfig = Set-AzVMOperatingSystem -VM $VmConfig -Linux -ComputerName $VmName -Credential (New-Object System.Management.Automation.PSCredential($AdminUsername, (ConvertTo-SecureString "DummyPass123!" -AsPlainText -Force))) -DisablePasswordAuthentication
$VmConfig = Set-AzVMSourceImage -VM $VmConfig -PublisherName "Canonical" -Offer "ubuntu-24_04-lts" -Skus "server" -Version "latest"
$VmConfig = Add-AzVMNetworkInterface -VM $VmConfig -Id $Nic.Id
$VmConfig = Add-AzVMSshPublicKey -VM $VmConfig -KeyData $SshKeyPublicKey -Path "/home/$AdminUsername/.ssh/authorized_keys"

New-AzVm -ResourceGroupName $ResourceGroupName -Location $Location -VM $VmConfig
Write-Host "VM '$VmName' created successfully."
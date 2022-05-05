$rgName = Read-Host -Prompt "Name of the new resouce group"

New-AzResourceGroup -Name $rgName -Location "eastus"

New-AzResourceGroupDeployment -Name "DemoEnv" `
    -ResourceGroupName $rgName `
    -TemplateFile .\demoEnvironment.bicep
# python-azure-functions

A repo that demostrates how to build out an environment with a focus on private connectivity for a python function with an Event hub trigger.

## Key features shown in this repo.

- python Event Hub Trigger
- mocking of event hub in unit test
- Bicep to create
    - resource groups
    - function
    - storage
    - eventhub
    - identities
    - role assignments
    - vnet and subnets
    - private endpoints
    - key vault references

> The function and the storage account also have public access enabled to allow for deploying and testing from a local machine. This should be disabled in a real world environment and the use of a self hosted runner that has network connectivity.

## Deploy infra

> You will need to find the ID for the "Diagnostic Services Trusted Storage Access" app which is deployed in your tenant to allow private connectivity from app insights into a storage account.

```
az deployment sub create -n pyfunc8 -l uksouth -f ./infra/main.bicep --parameters diagnosticServicesTrustedStorageAccessId=<magic app id> disablePublicAccess=false deploymentAgentPrincipalId=$(az ad signed-in-user show --query id -o tsv) deploymentAgentPrincipalType=User
```

Parameters

| Name                                     | Type         | Default                        | Description                                                                |
| ---------------------------------------- | ------------ | ------------------------------ | -------------------------------------------------------------------------- |
| name                                     | string       | The name of the deployment     | The name used for the resource groups                                      |
| location                                 | string       | The location of the deployment | The location to deploy all resources                                       |
| diagnosticServicesTrustedStorageAccessId | object ID    |                                | The object ID of the special app for Azure Monitor in a Private Link Scope |
| deploymentAgentPrincipalId               | principal ID |                                | The principal ID of the user of service running the deployment             |
| deploymentAgentPrincipalType             | string       | ServicePrincipal               | The principal type of the user or service doing the deployment             |


## Deploy app

```
cd ./src
func azure functionapp publish <function app name>
```

## Local Tooling

[Install Function Core tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=windows%2Cportal%2Cv2%2Cbash&pivots=programming-language-csharp#install-the-azure-functions-core-tools)

vscode extensions
- [Azurite](https://marketplace.visualstudio.com/items?itemName=Azurite.azurite)
- [Azure Tool Suite](https://marketplace.visualstudio.com/items?itemName=ms-vscode.vscode-node-azure-pack)
- [Python](https://marketplace.visualstudio.com/items?itemName=ms-python.python)
- [Bicep](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)

## Further Reading

[Setup and Create Function](https://learn.microsoft.com/en-us/azure/azure-functions/create-first-function-cli-python?pivots=python-mode-decorators&tabs=powershell%2Cazure-cli)

[Python Event Hub Trigger](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-event-hubs-trigger?tabs=python-v2%2Cin-process%2Cfunctionsv2%2Cextensionv5&pivots=programming-language-python)

[Python dev guide](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python)
# python-azure-functions

A repo that demostrates how to build out an environment with a focus on private connectivity for a python function with an Event hub trigger.

Key features shown in this repo.
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

> The function and the storage account also have public access enabled to allow for deploying and testing from a local machine. This should be disabled in a real world environment and the use of a self hosted runner that has network connectivity.

Deploy infra

```
az deployment sub create -n pyfunc -l uksouth -f ./infra/main.bicep
```

Deploy app
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
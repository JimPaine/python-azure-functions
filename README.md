# azure-functions-101

## local tooling

[Install Function Core tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=windows%2Cportal%2Cv2%2Cbash&pivots=programming-language-csharp#install-the-azure-functions-core-tools)

vscode extensions
- [Azurite](https://marketplace.visualstudio.com/items?itemName=Azurite.azurite)
- [Azure Tool Suite](https://marketplace.visualstudio.com/items?itemName=ms-vscode.vscode-node-azure-pack)
- [Python](https://marketplace.visualstudio.com/items?itemName=ms-python.python)
- [Bicep](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)

```
func new
```

```
az deployment group create -g hub-func -f ./env/main.bicep -n demo0 --parameters principalIds=[]
```
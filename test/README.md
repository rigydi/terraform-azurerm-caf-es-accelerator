# How to Start a Testrun
## Prepare Settings

Copy **bootstrap.yaml** from from the repo root to the folder **test**. Edit the yaml file according to your requirements.

</br>

## Testrun
To execute the script (authenticate to Azure) you need a [Azure Service Principal](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal).

Execute the script:

```bash
./test.sh -i <Service Principal Application/Client ID> -s <Service Principal Application/Client Secret>
```

It will perform a complete testrun, i.e. creating and destroying the Azure Launchpad and Enterprise Scale resources.
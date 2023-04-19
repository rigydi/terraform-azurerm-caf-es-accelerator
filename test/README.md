# How to Start a Testrun
## Prepare Settings

Copy **bootstrap.yaml** from from the repo root to the **test** folder. Edit the yaml file according to your requirements.

</br>

## Testrun
To execute the script (authenticate to Azure) you need an [Azure Service Principal](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal).

Execute the script:

```bash
./test.sh -a <deploy|destroy|fullrun> -i <Service Principal Application/Client ID> -s <Service Principal Application/Client Secret>
```

If you chose **-a fullrun** It will perform a complete testrun, i.e. creating and destroying the Azure Launchpad and Enterprise Scale resources.
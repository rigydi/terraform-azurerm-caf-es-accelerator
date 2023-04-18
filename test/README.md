# How to Start a Testrun
## Edit Settings

Edit the file **bootstrap.yaml** in folder **test** according to your requirements.

</br>

## Testrun
Execute the script:

```bash
./test.sh -i <Service Principal Application/Client ID> -s <Service Principal Application/Client Secret>
```

It will perform a complete testrun, i.e. creating and destroying the Launchpad and Enterprise Scale Azure resources.
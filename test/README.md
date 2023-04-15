# How to Start a Testrun
## Edit bootstrap.yaml

Edit the file **bootstrap.yaml** in folder **test** according to your requirements.

</br>

## Export Bash Shell Environment Variables
Export the following environment variables.

```bash
export ARM_SUBSCRIPTION_ID=""
export ARM_TENANT_ID=""
export ARM_CLIENT_ID=""
export ARM_CLIENT_SECRET=""
```
ARM_SUBSCRIPTION_ID: Your launchpad subscription.

ARM_CLIENT_ID: The client/application ID of your Service Principal (automation user).

ARM_CLIENT_SECRET: The secret of your automation user.

</br>

## Testrun
Execute the script:

```bash
./test.sh $ARM_CLIENT_ID $ARM_CLIENT_SECRET $ARM_SUBSCRIPTION_ID $ARM_TENANT_ID
```
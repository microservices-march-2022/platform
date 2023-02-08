# Enabling blue/green deployment with canary

Automating deployment is critical to the success of most projects. However, in today's world, it's not enough to just deploy your code. You also need to ensure downtime is limited (or eliminated), and you can quickly rollback in the event of a failure. One common approach to this is to use a [blue/green deployment strategy](https://martinfowler.com/bliki/BlueGreenDeployment.html). This strategy involves deploying your code to a new environment, and then slowly shifting traffic from the old environment to the new environment. This allows you to test your new code in production, and quickly rollback if there are any issues.

In this tutorial, you'll explore how to use [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps) to deploy a new version of your application, and then use Azure Traffic Manager to shift traffic from the old environment to the new environment. You'll start by creating and configuring the necessary Azure resources. You'll then configure a workflow in GitHub to deploy your application with a [canary](https://www.opsmx.com/blog/what-is-canary-deployment/) to automate rollback. Finally, you'll test the deployment and rollback process by commiting a change and monitoring the workflow.

## Create an Azure account and install resources

This workshop uses Azure Container Apps as the cloud-based host for an NGINX webserver playing the role of the application. You'll need to create an Azure account and install the Azure CLI to complete this tutorial.

> **NOTE**: While this tutorial uses Azure Container Apps, the concepts and techniques can be applied to any cloud-based host.

1. Create an [Azure account](https://azure.microsoft.com/free/) if you don't already have one
2. Install the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)

## Create the initial container app

With the tooling installed, you can now create the container app. This will be the initial version of the application, and will be used as the baseline for the blue/green deployment. You will login to Azure using the Azure CLI, install the extension for Azure Container Apps, clone the starting repository, and then deploy the container app.

1. Open a terminal or command window
2. Run the following command to login to Azure for the Azure CLI:

    ```bash
    az login
    ```

3. Follow the prompts to login using a browser window
4. Run the following command to install the `containerapp` extension:

    ```bash
    az extension add --name containerapp --upgrade
    ```

5. Run the following command to create a resource group for the container app:

    ```bash
    az group create --name my-container-app-rg --location westus
    ```

5. Clone your repository locally, replacing <YOUR_GITHUB_ACCOUNT_NAME> with your account name

    ```bash
    git clone https://github.com/<YOUR_GITHUB_ACCOUNT_NAME>/platform.git
    cd platform
    cd load_balancer
    ```

6. Run the following command to deploy the container to Azure Container Apps

    ```bash
    az containerapp up \
        --resource-group my-container-app-rg \
        --name my-container-app \
        --source . \
        --ingress external \
        --target-port 4001 \
        --location westus
    ```

7. In the command output, find the name of the Azure Container Registry. It should look like this: **cac085021b77acr**. You'll need this name in the next section.

8. In the command output, find the URL of the newly created container app. It should look like this: **https://my-container-app.delightfulmoss-eb6d59d5.westus.azurecontainerapps.io**. You'll need this URL in the next section.

9. Run the following command to enable revisions for the container app, which will allow for blue-green deployments:

    ```bash
    az containerapp revision set-mode \
        --name my-container-app \
        --resource-group my-container-app-rg \
        --mode multiple
    ```

## Create the managed identity for deployment

In order to deploy the new version of the application, you'll need to create a managed identity to authenticate to the Azure Container Registry. You'll then assign the managed identity the role to pull images from the Azure Container Registry. Finally, you'll configure the container app to use the managed identity to pull images from the Azure Container Registry.

While this set of steps may seem tedious, it's fortunately one you'll only need to run when creating a new application. It's also possible to fully script this process. As this is a workshop, we'll walk through the steps manually to breakdown the process. You'll start by obtaining the ID for the Azure Container Registry, and then the principal ID for the managed identity. You'll then assign the role to the managed identity, and configure the container app to use the managed identity. Finally you'll obtain the JSON credentials for the managed identity, which will be used by the GitHub Action to authenticate to Azure.

> **NOTE**: The process for creating credentials for deployment will vary from cloud provider to cloud provider.

1. Run the following command to get the Azure Container Registry Resource ID, replacing <ACR_NAME> with the Azure Container Registry name from the prior step.

    ```bash
    az acr show --name <ACR_NAME> --query id --output tsv
    ```

    The output should look like **/subscriptions/259c31a1-c389-4e5e-99f4-6ba0acb6f6ed/resourceGroups/my-container-app-rg/providers/Microsoft.ContainerRegistry/registries/caa3fc981c93acr**. You will use this Azure Container Registry Resource ID (ACR Resource ID) several times in this tutorial.

2. Run the following command to find the principal ID of the managed identity

    ```bash
    az containerapp identity assign \
        --name my-container-app \
        --resource-group my-container-app-rg \
        --system-assigned \
        --output table
    ```

    The GUID under **PrincipalID** is the managed identity. You will use this value in the next step.

3. Run the following command to assign the role for the Azure Container Registry to the container app's managed identity, replacing `<MANAGED_IDENTITY_PRINCIPAL_ID>` with the managed identity obtained earlier, and `<ACR_RESOURCE_ID>` with the resource ID of the Azure Container Registry from above.

    ```bash
    az role assignment create \
        --assignee <MANAGED_IDENTITY_PRINCIPAL_ID> \
        --role AcrPull \
        --scope <ACR_RESOURCE_ID>
    ```

4. Configure the container app to use the managed identity to pull images from the Azure Container Registry by running the following command, replacing `<ACR_NAME>` with the Azure Container Registry name from the prior step:

    ```bash
    az containerapp registry set \
        --name my-container-app \
        --resource-group my-container-app-rg \
        --server <ACR_NAME>.azurecr.io \
        --identity system
    ```

5. Create the JSON which contains the credentials to be used by the GitHub Action by running the following command, replacing `<SUBSCRIPTION_ID>` with your [Azure subscription ID](https://learn.microsoft.com/azure/azure-portal/get-subscription-tenant-id):

    ```bash
    az ad sp create-for-rbac \
        --name my-container-app \
        --role contributor \
        --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/my-container-app-rg \
        --sdk-auth \
        --output json
    ```

    > **NOTE**: You can find your Azure subscription ID by running `az account show --query id --output tsv`

6. Copy the JSON output from the command and place it in a text editor. It will be required for the next step.

## Create the secret in your GitHub repository

In order to deploy the new version of the application, you'll need to create a secret in your GitHub repository. This secret will contain the JSON credentials for the managed identity created in the prior step, and the necessary settings to deploy to Azure. You'll then use these secrets in the GitHub action to automate deployment.

1. Navigate to your GitHub repository.
2. Select **Settings** > **Secrets and variables** > **Actions**.
3. Select **New repository secret**.
4. Create a new secret with the following values:

    - **Name**: `AZURE_CREDENTIALS`
    - **Secret**: `<Paste the JSON credentials from the prior step>`

5. Select **Add secret**.
6. Repeat steps 3 - 5 to create the following secrets (replacing the values with your own):

    | Name | Secret |
    | --- | --- |
    | `CONTAINER_APP_NAME` | `my-container-app-rg` |
    | `RESOURCE_GROUP` | `my-container-app` |
    | `ACR_NAME` | `<ACR_NAME>` |

## Create the GitHub Action

Now that you've created the managed identity and configured the secrets, you can create the GitHub Action to automate deployment. You'll start by creating a new workflow file, and then add the necessary steps to deploy the new version of the application.

The entire workflow file is shown at the end of this section. You can copy the contents of the file and paste it into a new file in your GitHub repository. You can also create the file manually by following the steps below.

> **IMPORTANT**: Workflow files are defined as YAML files. Whitespace is significant in YAML files, so be sure to use the same indentation as shown in the example below.

1. Navigate to your GitHub repository.
2. Select **Actions** > **New workflow**.
3. Add the following to the YAML file to name the workflow:

    ```yaml
    name: Deploy to Azure
    ```

4. Add the following to the YAML file to configure the workflow to run when a push or pull request is made to the main branch:

    ```yaml
    on:
      push:
        branches:
          - main
      pull_request:
        branches:
          - main
    ```

5. Add the following to define the `jobs` section of the workflow:

    ```yaml
    jobs:
    ```

6. Add the following to define the `build-deploy` job. This job will checkout the code, log into Azure, and deploy the application to Azure Container App:

    ```yaml
      build-deploy:
        runs-on: ubuntu-latest

        steps:
          - uses: actions/checkout@v3

          - name: Log in to Azure
            uses: azure/login@v1
            with:
            creds: ${{ secrets.AZURE_CREDENTIALS }}

          - name: Build and deploy Container App
            uses: azure/container-apps-deploy-action@v0
            with:
              appSourcePath: ${{ github.workspace }}/load_balancer/ # Location of Dockerfile
              acrName: ${{ secrets.ACR_NAME }} # Name of Azure Container Registry
              containerAppName: ${{ secrets.CONTAINER_APP_NAME }} # Name of Azure Container App
              resourceGroup: ${{ secrets.RESOURCE_GROUP }} # Name of Azure Resource Group
    ```

    > **NOTE**: The `appSourcePath` is the location of the Dockerfile. The `acrName` is the name of the Azure Container Registry. The `containerAppName` is the name of the Azure Container App. The `resourceGroup` is the name of the Azure Resource Group.

7. Add the following to define the `test-deployment` job. This job will determine the staging URL of the newly deployed revision and use a GitHub Action to ping the API endpoint to ensure it is responding. If the health check succeeds, the traffic manager on the container app will be updated to point all traffic at the newly deployed container.

    ```yaml
      test-deployment:
        needs: build-deploy
        runs-on: ubuntu-latest

        steps:
        - name: Log in to Azure
          uses: azure/login@v1
          with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
        - name: Get new container name
          run: |
            # Enable extension installation
            az config set extension.use_dynamic_install=yes_without_prompt
            # Get the last deployed revision name
            REVISION_NAME=`az containerapp revision list -n ${{ secrets.CONTAINER_APP_NAME }} -g ${{ secrets.RESOURCE_GROUP }} --query "[].name" -o tsv | tail -1`
            # Get the last deployed revision's fqdn
            REVISION_FQDN=`az containerapp revision show -n ${{ secrets.CONTAINER_APP_NAME }} -g ${{ secrets.RESOURCE_GROUP }} --revision "$REVISION_NAME" --query properties.fqdn -o tsv`
            # Store values in env vars
            echo "REVISION_NAME=$REVISION_NAME" >> $GITHUB_ENV
            echo "REVISION_FQDN=$REVISION_FQDN" >> $GITHUB_ENV
        - name: Test deployment
          id: test-deployment
          uses: jtalk/url-health-check-action@v3 # Marketplace action to touch the endpoint
          with:
            url: "https://${{ env.REVISION_FQDN }}/api" # Staging endpoint
        - name: Deploy succeeded
          run: |
            echo "Deployment succeeded! Enabling new revision"
            az containerapp ingress traffic set -n ${{ secrets.CONTAINER_APP_NAME }} -g ${{ secrets.RESOURCE_GROUP }} --revision-weight "${{ env.REVISION_NAME }}=100"
    ```

8. Select **Commit changes**, and on the dialog select **Commit changes** again. This will merge the new workflow file to the main branch, and begin executing the workflow.
9. Select **Actions** where you can monitor the progress of the workflow.

## Test the workflow

You'll finish the configuration of the workflow by testing it. You'll first make a successful change, see the updated application, and then make an unsuccessful change to see the published application remains unchanged.

### Successful change

Let's create a good update and see the workflow succeed.

1. Select **Code** > **load_balancer** > **nginx.conf**.
2. Select the pencil icon with the tooltip "Edit this file" to edit the file.
3. Update line **73** to read `return 200 "Updated!!";`
4. Select **Commit changes**.
5. Select **Create a new branch for this commit and start a pull request.** on the dialog box.
6. Select **Create pull request** to access the pull request template.
7. Select **Create pull request** again to create the pull request.
8. Select **Actions** to monitor the progress of the workflow. When the workflow completes, navigate to your container app by using the **<APP_CONTAINER_URL>/api**, where **<APP_CONTAINER_URL>** is the URL you copied earlier. Notice the updated message.

### Unsuccessful change

Let's create a bad update and see the workflow fail.

1. Select **Code** > **load_balancer** > **nginx.conf**.
2. In the upper left, select **main** then the name of the branch which ends with **patch-1**, which is the branch created in the previous step.
3. Select the pencil icon with the tooltip "Edit this file" to edit the file.
4. Update line **73** to read `return 500 "Bad update!!";`
5. Select **Commit changes**.
6. Ensure **Commit directly to the <YOUR_NAME>-patch-1 branch** is selected.
7. Select **Commit changes**.
8.  Select **Actions** to monitor the progress of the workflow. Notice the workflow executes again when files in the PR are updated. When the workflow completes, navigate to your container app by using the **<APP_CONTAINER_URL>/api**, where **<APP_CONTAINER_URL>** is the URL you copied earlier. Notice the message is still **Updated!!**, which is the message from the previous update.

## Next steps

Congratulations! You've now seen how to use GitHub Actions to enable blue-green deployments. You started by configuring the resources on Azure, configuring the repository with the settings necessary for the workflow, and created the workflow itself. You finished by testing the workflow by making a successful and unsuccessful change to the application.

From here, you can continue to explore and grow your knowledge of DevOps. Here are some suggestions:

- [About GitHub workflows](https://docs.github.com/actions/using-workflows/about-workflows)
- [Continuous integration](https://docs.github.com/actions/automating-builds-and-tests/about-continuous-integration)
- [Deploying with GitHub Actions](https://docs.github.com/actions/deployment/about-deployments/about-continuous-deployment)
- [Monitoring and troubleshooting GitHub Actions](https://docs.github.com/actions/monitoring-and-troubleshooting-workflows/about-monitoring-and-troubleshooting)

## Complete workflow file

```yaml
name: Azure Container Apps Deploy

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main

jobs:
  build-deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Log in to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Build and deploy Container App
        uses: azure/container-apps-deploy-action@v0
        with:
          appSourcePath: ${{ github.workspace }}/load_balancer/ # Location of Dockerfile
          acrName: ${{ secrets.ACR_NAME }} # Name of Azure Container Registry
          containerAppName: ${{ secrets.CONTAINER_APP_NAME }} # Name of Azure Container App
          resourceGroup: ${{ secrets.RESOURCE_GROUP }} # Name of Azure Resource Group
  
  test-deployment:
    needs: build-deploy
    runs-on: ubuntu-latest

    steps:
      - name: Log in to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - name: Get new container name
        run: |
          # Enable extension installation
          az config set extension.use_dynamic_install=yes_without_prompt
          # Get the last deployed revision name
          REVISION_NAME=`az containerapp revision list -n ${{ secrets.CONTAINER_APP_NAME }} -g ${{ secrets.RESOURCE_GROUP }} --query "[].name" -o tsv | tail -1`
          # Get the last deployed revision's fqdn
          REVISION_FQDN=`az containerapp revision show -n ${{ secrets.CONTAINER_APP_NAME }} -g ${{ secrets.RESOURCE_GROUP }} --revision "$REVISION_NAME" --query properties.fqdn -o tsv`
          # Store values in env vars
          echo "REVISION_NAME=$REVISION_NAME" >> $GITHUB_ENV
          echo "REVISION_FQDN=$REVISION_FQDN" >> $GITHUB_ENV
      - name: Test deployment
        id: test-deployment
        uses: jtalk/url-health-check-action@v3 # Marketplace action to touch the endpoint
        with:
          url: "https://${{ env.REVISION_FQDN }}/api" # Staging endpoint
      - name: Deploy succeeded
        run: |
          echo "Deployment succeeded! Enabling new revision"
          az containerapp ingress traffic set -n ${{ secrets.CONTAINER_APP_NAME }} -g ${{ secrets.RESOURCE_GROUP }} --revision-weight "${{ env.REVISION_NAME }}=100"
```

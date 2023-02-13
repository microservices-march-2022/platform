# Enabling Blue/Green Canary Deployment with GitHub Actions

Automating deployment is critical to the success of most projects. However, in today's world, it's not enough to just deploy your code. You also need to ensure downtime is limited (or eliminated), and you can quickly rollback in the event of a failure. One common approach to this is to use a [blue/green deployment strategy](https://martinfowler.com/bliki/BlueGreenDeployment.html). This strategy involves deploying your code to a new environment, and then slowly shifting traffic from the old environment to the new environment. This allows you to test your new code in production, and quickly rollback if there are any issues.

In this lab, you'll explore how to use [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps) to deploy a new version of your application, and then use Azure Traffic Manager to shift traffic from the old environment to the new environment. You'll start by creating and configuring the necessary Azure resources. You'll then configure a workflow in GitHub to deploy your application with a [canary](https://www.opsmx.com/blog/what-is-canary-deployment/) to automate rollback. Finally, you'll test the deployment and rollback process by commiting a change and monitoring the workflow.

## Create an Azure Account and Install Resources

This workshop uses Azure Container Apps as the cloud-based host for an NGINX container playing the role of an application's ingress. You'll need to create an Azure account and install the Azure CLI to complete this lab. Optionally, if you wish to run the lab in its entirety from your terminal, you will also need the GitHub CLI.

> **NOTE:** While this lab uses Azure Container Apps, the concepts and techniques can be applied to any cloud-based host.

1. Create an [Azure account](https://azure.microsoft.com/free/) if you don't already have one. We also recommend you create a new account if your current Azure account is provided by your company to prevent any potential permission related issues.
2. Install the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli).
3. (Optional) Install the [GitHub CLI](https://cli.github.com/).

## Create the Initial Container App

With the tooling installed, you can now create the container app. This will be the initial version of the application, and will be used as the baseline for the blue/green deployment. You will login to Azure using the Azure CLI, install the extension for Azure Container Apps, clone the starting repository, and then deploy the container app.

1. Open a terminal or command window and create a Microservices March directory:

   ```bash
   mkdir microservices-march
   cd microservices-march
   ```

2. Fork and clone the [Microservices March platform](https://github.com/microservices-march/platform) repository to your personal GitHub account:

   - If using the GitHub UI/website, select **Fork** on the upper right corner, and in the **Owner** menu, select your personal GitHub account. Then, clone your repository locally, replacing <YOUR_GITHUB_ACCOUNT_NAME> with your account name:

     ```bash
      git clone https://github.com/<YOUR_GITHUB_ACCOUNT_NAME>/platform.git
      cd platform
     ```

   - If using the GitHub CLI, run:

     ```bash
     gh repo fork microservices-march/platform --clone
     cd platform
     ```

3. Run the following command to login to Azure for the Azure CLI. Follow the prompts to login using a browser window:

   ```bash
   az login
   ```

4. Run the following command to install the `containerapp` extension:

   ```bash
   az extension add --name containerapp --upgrade
   ```

5. Run the following command to create a resource group for the container app:

   ```bash
   az group create --name my-container-app-rg --location westus
   ```

6. Run the following command to deploy the container to Azure Container Apps:

   ```bash
   az containerapp up \
       --resource-group my-container-app-rg \
       --name my-container-app \
       --source ./ingress \
       --ingress external \
       --target-port 80 \
       --location westus
   ```

7. In the command output, find the name and the URL of the newly created Azure Container Registry container app. They should look like **cac085021b77acr** (you should be able to find it under the `registry` key) and **<https://my-container-app.delightfulmoss-eb6d59d5.westus.azurecontainerapps.io>** (this URL is hard to miss in the command output, but do note that you need the `https` endpoint, not the `http` one) respectively. You'll need this name (from here on `<ACR_NAME>`) and URL (from here on `<ACR_URL>`) in the next section.

8. Run the following command to enable revisions for the container app, which will allow for blue-green deployments:

   ```bash
   az containerapp revision set-mode \
       --name my-container-app \
       --resource-group my-container-app-rg \
       --mode multiple
   ```

9. (Optional) Test that your deployment is working by quering the container `/health` endpoint:

   ```bash
   curl <ACR_URL>/health
   ```

   The output should show `OK`.

## Create the Managed Identity for Deployment

In order to deploy the new version of the application, you'll need to create a managed identity to authenticate to the Azure Container Registry. You'll then assign the managed identity the role to pull images from the Azure Container Registry. Finally, you'll configure the container app to use the managed identity to pull images from the Azure Container Registry.

While this set of steps may seem tedious, it's fortunately one you'll only need to run when creating a new application. It's also possible to fully script this process. As this is a lab, we'll walk through the steps manually to breakdown the process. You'll start by obtaining the ID for the Azure Container Registry, and then the principal ID for the managed identity. You'll then assign the role to the managed identity, and configure the container app to use the managed identity. Finally you'll obtain the JSON credentials for the managed identity, which will be used by GitHub Actions to authenticate to Azure.

> **NOTE:** The process for creating credentials for deployment will vary from cloud provider to cloud provider.

1. Run the following command to get the Azure Container Registry Resource ID, replacing `<ACR_NAME>` with the Azure Container Registry name from Step 10 in the previous section:

   ```bash
   az acr show --name <ACR_NAME> --query id --output tsv
   ```

   The output should look like **/subscriptions/259c31a1-c389-4e5e-99f4-6ba0acb6f6ed/resourceGroups/my-container-app-rg/providers/Microsoft.ContainerRegistry/registries/caa3fc981c93acr**. You will use this value in Step 3.

2. Run the following command to find the principal ID of the managed identity:

   ```bash
   az containerapp identity assign \
       --name my-container-app \
       --resource-group my-container-app-rg \
       --system-assigned \
       --output table
   ```

   The GUID under **PrincipalID** is the managed identity. You will use this value in Step 3.

3. Run the following command to assign the role for the Azure Container Registry to the container app's managed identity, replacing `<MANAGED_IDENTITY_PRINCIPAL_ID>` with the managed identity obtained in Step 2, and `<ACR_RESOURCE_ID>` with the resource ID of the Azure Container Registry obtained in Step 1:

   ```bash
   az role assignment create \
       --assignee <MANAGED_IDENTITY_PRINCIPAL_ID> \
       --role AcrPull \
       --scope <ACR_RESOURCE_ID>
   ```

4. Configure the container app to use the managed identity to pull images from the Azure Container Registry by running the following command, replacing `<ACR_NAME>` with the Azure Container Registry name from Step 10 in the previous section:

   ```bash
   az containerapp registry set \
       --name my-container-app \
       --resource-group my-container-app-rg \
       --server <ACR_NAME>.azurecr.io \
       --identity system
   ```

5. Retrieve your Azure subscription ID. You will use this in the next step:

   ```bash
   az account show --query id --output tsv
   ```

6. Create a JSON token which contains the credentials to be used by the GitHub Action by running the following command, replacing `<SUBSCRIPTION_ID>` with your [Azure subscription ID](https://learn.microsoft.com/azure/azure-portal/get-subscription-tenant-id). You will use this token in the next section. (**Note:** Ignore the `--sdk-auth` deprecation warning, it's a known [issue](https://github.com/azure/login#configure-a-service-principal-with-a-secret).):

   ```bash
   az ad sp create-for-rbac \
       --name my-container-app \
       --role contributor \
       --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/my-container-app-rg \
       --sdk-auth \
       --output json
   ```

## Create the Secret in Your GitHub Repository

In order to deploy a new version of the application, you'll need to create a secret in the GitHub repository you forked at the beginning of this lab. This secret will contain the JSON credentials for the managed identity created in the prior step, and the necessary settings to deploy to Azure. You'll then use these secrets in a GitHub action to automate deployment.

If using the GitHub UI/website:

1. Navigate to your forked GitHub repository.
2. Select **Settings** > **Secrets and variables** > **Actions**.
3. Select **New repository secret**.
4. Create a new secret with the following values:

   - **Name**: `AZURE_CREDENTIALS`
   - **Secret**: `<Paste the JSON credentials from Step 6 in the previous section>`

5. Select **Add secret**.
6. Repeat Steps 3 - 5 three times to create the following secrets (replacing the values with your own):

   | Name                 | Secret                |
   | -------------------- | --------------------- |
   | `CONTAINER_APP_NAME` | `my-container-app-rg` |
   | `RESOURCE_GROUP`     | `my-container-app`    |
   | `ACR_NAME`           | `<ACR_NAME>`          |

If using the GitHub CLI:

1. Create a new secret for your Azure credentials by replacing `<SECRET>` with `AZURE_CREDENTIALS` and pasting the JSON credentials obtained from Step 6 in the previous section:

   ```bash
   gh secret set <SECRET> --repo <YOUR_GITHUB_ACCOUNT_NAME>/platform
   ```

2. Repeat Step 1 three times to create the following secrets (replacing the values with your own):

   | Name                 | Secret                |
   | -------------------- | --------------------- |
   | `CONTAINER_APP_NAME` | `my-container-app-rg` |
   | `RESOURCE_GROUP`     | `my-container-app`    |
   | `ACR_NAME`           | `<ACR_NAME>`          |

## Create a GitHub Action

Now that you've created the managed identity and configured the secrets, you can create a GitHub Action to automate deployments. You'll start by creating a new workflow file, and then add the necessary steps to deploy a new version of the application.

The entire workflow file is shown at the end of this section. You can copy the contents of the file and paste it into a new file in your GitHub repository. You can also create the file manually by following the steps below.

> **IMPORTANT:** Workflow files are defined as YAML files. Whitespace is significant in YAML files, so be sure to use the same indentation as shown in the example below.

If using the GitHub UI/website:

1. Navigate to your GitHub repository.
2. Select **Actions** > **New workflow** > **Skip this and set up a workflow yourself**.

If using the GitHub CLI:

1. Create the `.github/workflows` directory:

   ```bash
   mkdir .github/workflows
   ```

2. Use your text editor of choice to create a new file, `main.yml` in the `.github/workflows` directory (in this lab we will use `vim`, but any alternative would work):

   ```bash
   vim .github/workflows/main.yml
   ```

If using either the GitHub UI/website or the GitHub CLI:

1. Add the following to the YAML file to name the workflow:

   ```yaml
   name: Deploy to Azure
   ```

2. Add the following to the YAML file to configure the workflow to run when a push or pull request is made to the main branch:

   ```yaml
   on:
     push:
       branches:
         - main
     pull_request:
       branches:
         - main
   ```

3. Add the following to define the `jobs` section of the workflow:

   ```yaml
   jobs:
   ```

4. Add the following to define the `build-deploy` job. This job will checkout the code, log into Azure, and deploy the application to Azure Container App:

   ```yaml
   build-deploy:
     runs-on: ubuntu-22.04
     steps:
       - name: Check out the codebase
         uses: actions/checkout@v3

       - name: Log in to Azure
         uses: azure/login@v1
         with:
           creds: ${{ secrets.AZURE_CREDENTIALS }}

       - name: Build and deploy Container App
         uses: azure/container-apps-deploy-action@5bbc4488982e54e10e3ff1400b47efb87e899dec
         with:
           appSourcePath: ${{ github.workspace }}/load_balancer/ # Location of Dockerfile
           acrName: ${{ secrets.ACR_NAME }} # Name of Azure Container Registry
           containerAppName: ${{ secrets.CONTAINER_APP_NAME }} # Name of Azure Container App
           resourceGroup: ${{ secrets.RESOURCE_GROUP }} # Name of Azure Resource Group
   ```

   > **NOTE**: The `appSourcePath` is the location of the Dockerfile. The `acrName` is the name of the Azure Container Registry. The `containerAppName` is the name of the Azure Container App. The `resourceGroup` is the name of the Azure Resource Group.

5. Add the following to define the `test-deployment` job. This job will determine the staging URL of the newly deployed revision and use a GitHub Action to ping the API endpoint to ensure it is responding. If the health check succeeds, the traffic manager on the container app will be updated to point all traffic at the newly deployed container:

   ```yaml
   test-deployment:
     needs: build-deploy
     runs-on: ubuntu-22.04
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
           url: "https://${{ env.REVISION_FQDN }}/health" # Staging endpoint

       - name: Deploy succeeded
         run: |
           echo "Deployment succeeded! Enabling new revision"
           az containerapp ingress traffic set -n ${{ secrets.CONTAINER_APP_NAME }} -g ${{ secrets.RESOURCE_GROUP }} --revision-weight "${{ env.REVISION_NAME }}=100"
   ```

If using the GitHub UI/website:

1. Select **Start commit**, add a commit message if you wish, and on the dialog select **Commit new file**. This will merge the new workflow file to the main branch, and begin executing the workflow.
2. Select **Actions** where you can monitor the progress of the workflow.

If using the GitHub CLI:

1. Add the file you just created to `git`:

   ```bash
   git add .github/workflows/main.yml
   ```

2. Commit the file to `git`:

   ```bash
   git commit -m "feat: create GitHub Actions workflow"
   ```

3. Push your changes to GitHub:

   ```bash
   git push
   ```

4. Monitor the progress of the workflow:

   ```bash
   gh workflow view main.yml --repo <YOUR_GITHUB_ACCOUNT_NAME>/platform
   ```

## Test the Workflow

You'll finish the configuration of the workflow by testing it. You'll first make a successful change, see the updated application, and then make an unsuccessful change to see the published application remains unchanged.

### Successful Update

Let's create a successful update and see the workflow succeed.

If using the GitHub UI/website:

1. Select **Code** > **ingress** > **default.conf.template**.
2. Select the pencil icon with the tooltip "Edit this file" to edit the file.
3. Update line **36** to read `return 200 "Successful Update!\n";`.
4. Select **Create a new branch for this commit and start a pull request.** on the dialog box and then select **Propose changes**.
5. Select **Create pull request** to access the pull request template.
6. Select **Create pull request** again to create the pull request.
7. Select **Actions** to monitor the progress of the workflow. When the workflow completes, navigate to your container app by navigating to the `<ACR_URL>/health` endpoint, where the `<ACR_URL>` is the URL you copied earlier. Notice the updated message.

If using the GitHub CLI:

1. Create a new branch called `patch-1`:

   ```bash
   git checkout -b patch-1
   ```

2. Update line **36** in the NGINX ingress configuration file to `return 200 "Successful Update!\n"`:

   ```bash
   vim ingress/default.conf.template
   ```

3. Track the modified file in `git`:

   ```bash
   git add ingress/default.conf.template
   ```

4. Commit the file to `git`:

   ```bash
   git commit -m "feat: update NGINX ingress"
   ```

5. Push your changes to GitHub:

   ```bash
   git push --set-upstream origin patch-1
   ```

6. Create a PR:

   ```bash
   gh pr create --head patch-1 --fill --repo <YOUR_GITHUB_ACCOUNT_NAME>/platform
   ```

7. Monitor the progress of the workflow:

   ```bash
   gh workflow view main.yml --repo <YOUR_GITHUB_ACCOUNT_NAME>/platform
   ```

### Unsuccessful Update

Let's create an unsuccessful update and see the workflow fail.

If using the GitHub UI/website:

1. Select **Code** > **ingress** > **default.conf.template**.
2. In the upper left, select **main** then the name of the branch which ends with **patch-1**, which is the branch created in the previous step.
3. Select the pencil icon with the tooltip "Edit this file" to edit the file.
4. Update line **36** to read `return 500 "Unsuccessful Update!\n";`.
5. Select **Commit directly to the <YOUR_GITHUB_ACCOUNT_NAME>-patch-1 branch** is selected and then select **Commit changes**
6. Select **Actions** to monitor the progress of the workflow. Notice the workflow executes again when files in the PR are updated. When the workflow completes, navigate to your container app by navigating to the `<ACR_URL>/health` endpoint, where `<ACR_URL>` is the URL you copied earlier. Notice the message is still `Successful Update!`, which is the message from the previous update.

If using the GitHub CLI:

1. Checkout the `patch-1` branch you created in the previous section:

   ```bash
   git checkout patch-1
   ```

2. Update line **36** in the NGINX ingress configuration file to `return 200 "Unsuccessful Update!\n"`:

   ```bash
   vim ingress/default.conf.template
   ```

3. Track the modified file in `git`:

   ```bash
   git add ingress/default.conf.template
   ```

4. Commit the file to `git`:

   ```bash
   git commit -m "feat: update NGINX ingress again"
   ```

5. Push your changes to GitHub:

   ```bash
   git push
   ```

6. Monitor the progress of the workflow:

   ```bash
   gh workflow view main.yml --repo <YOUR_GITHUB_ACCOUNT_NAME>/platform
   ```

## Resource Cleanup

Once you are done with the lab you might want to remove the Azure resources you deployed in the lab to avoid any potential charges down the line:

```bash
az group delete -n my-container-app-rg -y
```

You can delete the fork you created if you wish.

If using the GitHub UI/website:

1. Select **Settings**.
2. Scroll down to the bottom of the page.
3. Select **Delete this repository**.
4. Type `<YOUR_GITHUB_ACCOUNT_NAME>/platform` and select **I understand the consequences, delete this repository**.

If using the GitHub CLI:

```bash
gh repo delete <YOUR_GITHUB_ACCOUNT_NAME>/platform --yes
```

## Next Steps

Congratulations! You've now seen how to use GitHub Actions to enable blue-green deployments. You started by configuring the resources on Azure, configuring the repository with the settings necessary for the workflow, and created the workflow itself. You finished by testing the workflow by making a successful and unsuccessful change to the application.

From here, you can continue to explore and grow your knowledge of DevOps. Here are some suggestions:

- [About GitHub workflows](https://docs.github.com/actions/using-workflows/about-workflows)
- [Continuous integration](https://docs.github.com/actions/automating-builds-and-tests/about-continuous-integration)
- [Deploying with GitHub Actions](https://docs.github.com/actions/deployment/about-deployments/about-continuous-deployment)
- [Monitoring and troubleshooting GitHub Actions](https://docs.github.com/actions/monitoring-and-troubleshooting-workflows/about-monitoring-and-troubleshooting)


## Complete Workflow File

```yaml
---
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
    runs-on: ubuntu-22.04
    steps:
      - name: Check out the codebase
        uses: actions/checkout@v3

      - name: Log in to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Build and deploy Container App
        uses: azure/container-apps-deploy-action@5bbc4488982e54e10e3ff1400b47efb87e899dec
        with:
          appSourcePath: ${{ github.workspace }}/load_balancer/ # Location of Dockerfile
          acrName: ${{ secrets.ACR_NAME }} # Name of Azure Container Registry
          containerAppName: ${{ secrets.CONTAINER_APP_NAME }} # Name of Azure Container App
          resourceGroup: ${{ secrets.RESOURCE_GROUP }} # Name of Azure Resource Group

  test-deployment:
    needs: build-deploy
    runs-on: ubuntu-22.04
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
          url: https://${{ env.REVISION_FQDN }}/health # Staging endpoint

      - name: Deploy succeeded
        run: |
          echo "Deployment succeeded! Enabling new revision"
          az containerapp ingress traffic set -n ${{ secrets.CONTAINER_APP_NAME }} -g ${{ secrets.RESOURCE_GROUP }} --revision-weight "${{ env.REVISION_NAME }}=100"
```

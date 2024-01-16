# Using Azure Load Testing to test Multi-Tenant services   

## Table of Contents

- [Introduction](#introduction)
- [Features and architectures](#features-and-architectures)
- [Getting started](#getting-started)
- [Using Azure DevOps pipelines and Github Actions](#using-azure-devops-pipelines-and-github-actions)
- [Under the hood](#under-the-hood)
- [Contribute](#contribute)

## Introduction

This Azure Load Testing sample describes how to test a Multi-Tenant Application based on an frontend hosted on Azure Static Web App, a backend (REST API) hosted on Azure Function and a Database hosted in a table on Azure Storage. This sample will run load testing for several users hosted in different Microsoft Entra ID, the Microsoft Entra ID token associated witheach user will be stored in the Azure Key Vault associated with the Azure Load Testing infrastructure. 

This repository contains:

- bash files and ARM templates to:
  - deploy/undeploy the infrastructure to test,
  - deploy/undeploy the load testing infrastructure
  - open/close the access to Azure Key Vault from Azure Load Testing
  - run the load test
- bash file to create the users used for the tests in a Microsoft Entra ID tenant
- an Azure DevOps pipeline and a Github Action to automate the load testing scenario.

The pipelines (Azure DevOps pipelines and Github Actions) running multi-tenant load testing includes the following steps:

- deploy the infrastructure to test
- deploy the load testing infrastructure
- update the infrastructure for the load test
- run the load testing
- update the infrastructure after the load test
- publish the load testing results  

## Features and architectures

This chapter describes the architecture based on Azure Static Web App, Azure Function and Azure Storage to host the multi-tenant service.
As the backend (REST API) is running in a container, an Azure Container Registry is used to store the container images.
  
This service based on Azure Static Web App, Azure Function and Azure Storage could be for instance a Teams Application.

  ![eventhub-architecture-restricted-public-access](./docs/img/load-testing-web-app-auth/architecture-scenario.png)

*Download a [SVG file](./docs/img/load-testing-web-app-auth/architecture-scenario.svg) of this diagram.*

This repository contains the code associated with:
- the frontend: a basic HTML/Javascript application calling the backend REST API once the user is authentified, 
- the backend: a REST API which record the visit in an Azure Storage table. Each record inn the table contains the user's Tenant Id and the user's mail address.

Moreover, it contains the code to run Azure Load Testing against the REST API which required a user authentication. 
The Azure Load Testing infrastructure is extended with an Azure Key Vault which is used to store the user's Microsoft Entra Id tokens.

  ![eventhub-architecture-restricted-public-access-load-testing](./docs/img/load-testing-web-app-auth/architecture-scenario-load-testing.png)

*Download a [SVG file](./docs/img/load-testing-web-app-auth/architecture-scenario-load-testing.svg) of this diagram.*

## Getting started

This chapter describes how to :

1. Install the pre-requisites including Visual Studio Code, Dev Container
2. Create, deploy and run the load tests
  
This repository contains the following resources :

- A Dev container under '.devcontainer' folder
- The Azure configuration for a deployment under 'configuration' folder
- The pipelines (Azure DevOps pipeline, Github Action) used to run the load testing scenarios and the bash files used to create and run the pipelines under 'devops-pipeline' folder
- The ARM templates used to deploy the target infrastructure and the load testing resources under 'infra' folder

### Installing the pre-requisites

In order to test the solution, you need first an Azure Subscription, you can get further information about Azure Subscription [here](https://azure.microsoft.com/en-us/free).

You also need to install Git client and Visual Studio Code on your machine, below the links.

|[![Windows](./docs/img/load-testing-web-app-auth/windows_logo.png)](https://git-scm.com/download/win) |[![Linux](./docs/img/load-testing-web-app-auth/linux_logo.png)](https://git-scm.com/download/linux)|[![MacOS](./docs/img/load-testing-web-app-auth/macos_logo.png)](https://git-scm.com/download/mac)|
|:---|:---|:---|
| [Git Client for Windows](https://git-scm.com/download/win) | [Git client for Linux](https://git-scm.com/download/linux)| [Git Client for MacOs](https://git-scm.com/download/mac) |
[Visual Studio Code for Windows](https://code.visualstudio.com/Download)  | [Visual Studio Code for Linux](https://code.visualstudio.com/Download)  &nbsp;| [Visual Studio Code for MacOS](https://code.visualstudio.com/Download) &nbsp; &nbsp;|

Once the Git client is installed you can clone the repository on your machine running the following commands:

1. Create a Git directory on your machine

    ```bash
        c:\> mkdir git
        c:\> cd git
        c:\git>
    ```

2. Clone the repository.  
    For instance:

    ```bash
        c:\git> git clone  https://github.com/Azure-Samples/load-testing-restricted-public-access.git 
        c:\git> cd ./load-testing-restricted-public-access 
        c:\git\load-testing-restricted-public-access> 
    ```

### Using Dev Container

#### Installing Dev Container pre-requisites

You need to install the following pre-requisite on your machine

1. Install and configure [Docker](https://www.docker.com/get-started) for your operating system.

   - Windows / macOS:

     1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop) for Windows/Mac.

     2. Right-click on the Docker task bar item, select Settings / Preferences and update Resources > File Sharing with any locations your source code is kept. See [tips and tricks](https://code.visualstudio.com/docs/remote/troubleshooting#_container-tips) for troubleshooting.

     3. If you are using WSL 2 on Windows, to enable the [Windows WSL 2 back-end](https://docs.docker.com/docker-for-windows/wsl/): Right-click on the Docker taskbar item and select Settings. Check Use the WSL 2 based engine and verify your distribution is enabled under Resources > WSL Integration.

   - Linux:

     1. Follow the official install [instructions for Docker CE/EE for your distribution](https://docs.docker.com/get-docker/). If you are using Docker Compose, follow the [Docker Compose directions](https://docs.docker.com/compose/install/) as well.

     2. Add your user to the docker group by using a terminal to run: 'sudo usermod -aG docker $USER'

     3. Sign out and back in again so your changes take effect.

2. Ensure [Visual Studio Code](https://code.visualstudio.com/) is already installed.

3. Install the [Remote Development extension pack](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack)

#### Using Visual Studio Code and Dev Container

1. Launch Visual Studio Code in the folder where you cloned the load-testing-restricted-public-access repository

    ```bash
        c:\git\load-testing-restricted-public-access> code .
    ```

2. Once Visual Studio Code is launched, you should see the following dialog box:

    ![Visual Studio Code](./docs/img/load-testing-web-app-auth/reopen-in-container.png)

3. Click on the button 'Reopen in Container'
4. Visual Studio Code opens the Dev Container. If it's the first time you open the project in container mode, it first builds the container, it can take several minutes to build the new container.
5. Once the container is loaded, you can open a new terminal (Terminal -> New Terminal).
6. And from the terminal, you have access to the tools installed in the Dev Container like az client,....

    ```bash
        vscode ➜ /workspace $ az login 
    ```

### How to deploy infrastructure and launch load test from the Dev Container terminal

The Dev Container is now running, you can use the bash file [./scripts/load-testing-tool.sh](./scripts/load-testing-tool.sh) to:

- deploy the infrastructure with Azure Static Web App, Azure Function and Azure Storage
- deploy the Load Testing infrastructure
- prepare the network configuration for the tests
- launch the Load Tests
- restore the network configuration
- undeploy the Load Testing infrastructure
- undeploy the infrastructure

If you are not interested in running the load testing manually from the Dev Container terminal, you can directly jump to the chapter [Using Azure DevOps pipelines and Github Actions](#using-azure-devops-pipelines-and-github-actions) to automate the infrastructure deployment and load tests.

Below the list of arguments associated with 'load-testing-tool.sh':

- -a  Sets iactool action {login, install, createconfig, deploy, undeploy, deploytest, undeploytest, opentest, runtest, closetest}
- -c  Sets the iactool configuration file
- -h  Azure Function Sku - by default B1 (B1, B2, B3, S1, S2, S3)
- -r  Sets the Azure Region for the deployment

#### Installing the pre-requisites on the host machine

Follow the steps below to install the pre-requisites on your host machine which could be the Azure DevOps Agent or a Github Agent. As currently the pre-requisite includes only the Azure CLI, this step is not required for the Dev Container environment as Azure CLI is already installed in the Dev Container.

1. You can launch the installation of the pre-requisites using the command below with the action "install"

    ```bash
        vscode ➜ /workspace $ ./projects/web-app-auth/scripts/load-testing-tool.sh  -a install
    ```

2. Once the pre-requisites are installed, launch the Azure login process using 'load-testing-tool.sh -a login'.  
Usually this step is not required in a pipeline as the connection with Azure is already established.

    ```bash
        vscode ➜ /workspace $ ./projects/web-app-auth/scripts/load-testing-tool.sh  -a login
    ```
    
    After this step the default Azure subscription has been selected. You can still change the Azure subscription, using Azure CLI command below:

    ```bash
        vscode ➜ /workspace $ az account set --subscription <azure-subscription-id>
    ```

3. Once you are connected to your Azure subscription, you can create the configuration file which is used to deploy the infrastructure.

    ```bash
        vscode ➜ /workspace $ ./projects/web-app-auth/scripts/load-testing-tool.sh  -a createconfig -c ./projects/web-app-auth/configuration/.default.env -r 'eastus2' 
    ```

    After this step, the variables AZURE_REGION, AZURE_TEST_SUFFIX, AZURE_SUBSCRIPTION_ID and AZURE_TENANT_ID used for the deployment are stored in the file ./configuration/.default.env.

    ```bash
        vscode ➜ /workspace $ cat ./projects/web-app-auth/configuration/.default.env
        AZURE_REGION="eastus2"
        AZURE_TEST_SUFFIX=waa2821
        AZURE_SUBSCRIPTION_ID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
        AZURE_TENANT_ID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
    ```

    AZURE_REGION defines the Azure region where you want to install your infrastructure, it's 'eastus2' by default.
    AZURE_TEST_SUFFIX defines the prefix which is used to name the Azure resources. By default this prefix includes 4 random digits which are used to avoid naming conflict when a resource with the same name has already been deployed in another subscription.
    AZURE_SUBSCRIPTION_ID is the Azure Subscription Id where you want to install your infrastructure
    AZURE_TENANT_ID is the Azure Tenant Id used for the authentication.

#### Deploying the infrastructure

Once the pre-requisites are installed and the configuration ready, you can deploy the infrastructure you want to test, using the following arguments:

```bash
    vscode ➜ /workspace $ ./projects/web-app-auth/scripts/load-testing-tool.sh  -a deploy -c ./projects/web-app-auth/configuration/.default.env 
```

As the bash file deploys an Azure Function infrastructure, you can also select the following options:
    -h : Azure Function Sku.  
         Below the list of SKUs ("B1" by default):
          "B1", "B2", "B3", "S1", "S2", "S3",...

For instance run the following command to deploy an Azure Function with Standard SKU:

```bash
    vscode ➜ /workspace $ ./projects/web-app-auth/scripts/load-testing-tool.sh  -a deploy -c ./projects/web-app-auth/configuration/.default.env -h 'S1' 
```

After few minutes, the resources are visible on the Azure Portal.
The infrastructure has been deployed with one Azure Static Web App, one Azure Function, one Azure Storage and one Azure Container Registry.
Moreover, during this step the multi-tenant application has been created in the Microsoft Entra ID tenant associated with the infrastructure. The name of this application is 'sp-${AZURE_TEST_SUFFIX}-app'. This application has the following permissions:  
- https://storage.azure.com/user_impersonation: used to allow the backend to access the table in Azure Storage  
- https://graph.microsoft.com/User.Read: used to read user information through the Graph API  
Morever, the application is associated with the following scope https://${TENANT_DNS_NAME}/${appId}.
At least, the client application Azure CLI (ClientId: 04b07795-8ddb-461a-bbee-02f9e1bf7b46) is authorized to access the service. With this authorization it will be possible to get the Microsoft Entra ID token of each user with the following curl command:  

```bash
    curl -s -X POST https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token  \
                    -H 'accept: application/json' -H 'Content-Type: application/x-www-form-urlencoded' \
                    -d 'client_id=${CLIENT_ID}&scope=${SCOPE}&username=${AD_USER}&password=${PASSWORD}&grant_type=password' | jq -r '.access_token'
```

Once the application has been created, the role "Storage Blob Data Contributor"  on Azure Storage Scope have been assigned to the new application. 
After this step, the infrastructure to test is ready and we can deploy and run the load testing.

#### Creating users in a Microsoft Entra ID test tenant 

##### Creating the test tenant

As the REST API ( HTTPS POST/GET/PUT/DELETE visit, HTTPS GET time) hosted on the backend requires and authenticated calls, we need to create temporary users in a Microsoft Entra ID test tenant.

You can get a test tenant in joining the Microsoft 365 Developer Program:
https://learn.microsoft.com/en-us/entra/identity-platform/test-setup-environment#get-a-test-tenant

##### Creating users manually

Once you get the test tenant, if you are connected to the tenant using the Tenant Administrator account, you can create manually users which will be used for the load testing scenarios:
https://learn.microsoft.com/en-us/entra/identity-platform/test-setup-environment#populate-your-tenant-with-users

You need to disable the MFA (Multi Factor Authentication) for each new user. If the MFA is not disabled, the script or the pipeline running the load testing scenario won't be able to get the Microsoft Entry ID token for the user.

The load testing script and the pipeline will use the environment variable LOAD_TESTING_USERS_CONFIGURATION to get the list of users for the load testing scenario.

The value of the variable LOAD_TESTING_USERS_CONFIGURATION is a json string with the following format:

```json
    [
      { "adu":"automationtest1@******.onmicrosoft.com",
        "pw":"*******",
        "sco":"https://******.onmicrosoft.com/d3c5dde6-2a9e-****-****-***********/user_impersonation",
        "clid":"04b07795-8ddb-461a-bbee-02f9e1bf7b46",
        "tid":"a007455c-dcb3-****-****-***********"
      },
      {},
      {}
    ]
```

where each user is defined with:  
- 'adu' is the user's mail adress with the following format: {TEST_USER}@{TEST_TENANT_DNS_NAME}  
- 'pw' is the user's password  
- 'sco' is the scope of the application with the following format 'https://{INFRASTRUCTURE_TENANT_DNS_NAME}/{APP_ID}/user_impersonation'  
- 'clid' is the Azure CLI client id, the value is '04b07795-8ddb-461a-bbee-02f9e1bf7b46'  
- 'tid' is the tenant Id of the test tenant  

Once the json string is fully defined, you can set the variable LOAD_TESTING_USERS_CONFIGURATION in the environment file. For instance, in the file ./projects/web-app-auth/configuration/.default.env:

```env
  LOAD_TESTING_USERS_CONFIGURATION='[{"adu":"automationtest@******.onmicrosoft.com","pw":"**************","sco":"https://********.onmicrosoft.com/786e637c-11c6-4b14-9f62-***********/user_impersonation","clid":"04b07795-8ddb-461a-bbee-02f9e1bf7b46","tid":"a007455c-dcb3-4067-8a33-***********"}]'
```

##### Creating users automatically

You can also use the script ./scripts/create-users.sh to automatically create the automation test users.

1. From the devcontainer terminal, you can call the script create-users.sh with the following parameters:  
- '-a': action either 'create' or 'delete'  
- '-t': test tenant id  
- '-s': scope of the application with the following format 'https://{INFRASTRUCTURE_TENANT_DNS_NAME}/{APP_ID}/user_impersonation'  
- '-p': user name prefix, the user's email address will be {PREFIX}{INDEX}@{TEST_TENANT_DNS_NAME}   
- '-c': the number of users to create or delete  

If you are not connected to the test tenant with Azure CLI, you'll be asked to enter the login/password of the tenant Administrator.

For instance:

```bash
    vscode ➜ /workspace $ ./scripts/create-users.sh -a create -t a007455c-dcb3-4067-8a33-************ -s https://****.onmicrosoft.com/d3c5dde6-2a9e-4e96-b09f-************/user_impersonation -p automationtest -c 2 
```

2. When the users are created, the script will show the value of the variable LOAD_TESTING_USERS_CONFIGURATION.
For instance:

```text
Value of the variable LOAD_TESTING_USERS_CONFIGURATION: 
'[{"adu":"automationtest1@63whhf.onmicrosoft.com","pw":"******","sco":"https://****.onmicrosoft.com/d3c5dde6-2a9e-4e96-b09f-************/user_impersonation","clid":"04b07795-8ddb-461a-bbee-02f9e1bf7b46","tid":"a007455c-dcb3-4067-8a33-************"},{"adu":"automationtest2@63whhf.onmicrosoft.com","pw":"******","sco":"https://****.onmicrosoft.com/d3c5dde6-2a9e-4e96-b09f-************/user_impersonation","clid":"04b07795-8ddb-461a-bbee-02f9e1bf7b46","tid":"a007455c-dcb3-4067-8a33-************"}]'
Creation done
```

##### Deleting users automatically

When all the tests are completed, using the same script you can also automatically delete the user accounts created for the tests. You can call the script create-users.sh with the following parameters:  
- '-a': action 'delete'  
- '-t': test tenant id   
- '-p': user name prefix, the user's email address will be {PREFIX}{INDEX}@{TEST_TENANT_DNS_NAME}   
- '-c': the number of users to delete  

For instance:

```bash
    vscode ➜ /workspace $ ./scripts/create-users.sh -a delete -t a007455c-dcb3-4067-8a33-********** -p automationtest -c 2 
```

##### Granting tenant-wide admin consent

When all the users are created in the Microsoft Entra ID tenant, you need to grant admin consent for all the users.

As you know the client ID (also known as the application ID) of the application, you can build the URL to grant tenant-wide admin consent.

The tenant-wide admin consent URL follows the following format:

```bash
    https://login.microsoftonline.com/{organization}/adminconsent?client_id={client-id}
```

where:  

- {client-id} is the application's client ID (also known as app ID).  
- {organization} is the tenant ID or any verified domain name of the tenant you want to consent the application in. You can use the value organizationsthat causes the consent to happen in the home tenant of the user you sign in with.

1. Open the admin consent url using the Microsoft Entra ID Tenant admin login and password. 

2. If the admin constent has not been granted, you will see the dialog box below to accept the permissions for all users on behalf of your organisation. Check the box 'Consent on behalft of your organization' and click on the 'Accept' button.  

![azure-devops-org](./docs/img/load-testing-web-app-auth/admin-consent.png)

3. After this step, as the users created for the tests won't have to accept those permissions, we could use those users to run the loading tests in a automated way.

#### Deploying the load testing infrastructure

Once the infrastructure is deployed, you can deploy the load testing infrastructure, using the following arguments:

```bash
    vscode ➜ /workspace $ ./projects/web-app-auth/scripts/load-testing-tool.sh  -a deploytest -c ./projects/web-app-auth/configuration/.default.env 
```

This step deploys the following resources:

- Azure Load Testing
- Azure Key vault

It assigns the following roles:

- 'Load Test Contributor' for the current user on the Load Testing scope
- 'Key Vault Secrets Officer' for the current user on the Key Vault scope
- 'Key Vault Secrets User' for the Load Testing identity on the Key Vault scope

#### Opening the access to Azure Key Vault

Once the load testing infrastructure is deployed, you need to open the access to :

- Azure Key Vault for the current user or current service principal and Azure Load Testing.

The command line below configures the network access to Azure Event Hubs and Azure Key Vault:

```bash
    vscode ➜ /workspace $ ./projects/web-app-auth/scripts/load-testing-tool.sh  -a opentest -c ./projects/web-app-auth/configuration/.default.env 
```

This step opens the access to Azure Key Vault.

#### Running the load test scenario

Once the Azure Event Hubs and Azure Key Vault are configured, you can launch the load test scenario with the following command line.

```bash
    vscode ➜ /workspace $ ./projects/web-app-auth/scripts/load-testing-tool.sh  -a runtest -c ./projects/web-app-auth/configuration/.default.env 
```

By default, the load test scenario runs with the following parameters:

- duration: 60 seconds
- Threads: 1 thread
- Engine Instances: 1
- Error trigger: 5%
- Average Response Time trigger: 100ms

You can change those parameters in editing the variables below in the configuration file, for instance: ./projects/web-app-auth/configuration/.default.env

```bash
LOAD_TESTING_DURATION=60
LOAD_TESTING_THREADS=1
LOAD_TESTING_ENGINE_INSTANCES=1
LOAD_TESTING_ERROR_PERCENTAGE=5
LOAD_TESTING_RESPONSE_TIME=100
```

This step is a journey between the different status of the Azure Load Testing Test instance:

- ACCEPTED: The load testing configuration with the JMX file and CSV files has been accepted
- PROVISIONING: The load testing service is provisioning the resources for the test
- CONFIGURING: The load testing service is configuring the resources
- EXECUTING: The load testing service is executing the test
- DONE: the test is completed

Once the test is completed, when the result status is "PASSED", the results of the test are available, and the bash file displays the results:  
For instance:  

```json
    {
      "Request for user user_1  ": {
        "transaction": "Request for user user_1  ",
        "sampleCount": 280,
        "errorCount": 0,
        "errorPct": 0,
        "meanResTime": 38.371428571428574,
        "medianResTime": 34,
        "maxResTime": 281,
        "minResTime": 22,
        "pct1ResTime": 52,
        "pct2ResTime": 58,
        "pct3ResTime": 85,
        "throughput": 4.67,
        "receivedKBytesPerSec": 0,
        "sentKBytesPerSec": 0
      },
      "Request for user user_2  ": {
        "transaction": "Request for user user_2  ",
        "sampleCount": 279,
        "errorCount": 0,
        "errorPct": 0,
        "meanResTime": 42.06810035842294,
        "medianResTime": 35,
        "maxResTime": 991,
        "minResTime": 23,
        "pct1ResTime": 54,
        "pct2ResTime": 61,
        "pct3ResTime": 103,
        "throughput": 4.73,
        "receivedKBytesPerSec": 0,
        "sentKBytesPerSec": 0
      },
      "Total": {
        "transaction": "Total",
        "sampleCount": 1396,
        "errorCount": 0,
        "errorPct": 0,
        "meanResTime": 41.00787965616046,
        "medianResTime": 35,
        "maxResTime": 991,
        "minResTime": 22,
        "pct1ResTime": 54,
        "pct2ResTime": 63,
        "pct3ResTime": 151,
        "throughput": 23.27,
        "receivedKBytesPerSec": 0,
        "sentKBytesPerSec": 0
      }
    }
```

For this step, the bash file uses curl commands to call the Azure Load Testing Data Plane REST API defined [here](https://learn.microsoft.com/en-us/rest/api/loadtesting/) to create, configure, run and monitor the load test.

#### Closing the access to Azure Key Vault

If you don't want to run any new load test, you can close the access to Azure Key Vault, with the following command line:

```bash
    vscode ➜ /workspace $ ./projects/web-app-auth/scripts/load-testing-tool.sh  -a closetest -c ./projects/web-app-auth/configuration/.default.env 
```

#### Undeploying the load testing infrastructure

You can also undeploy the load testing infrastructure with the following command:

```bash
    vscode ➜ /workspace $ ./projects/web-app-auth/scripts/load-testing-tool.sh  -a undeploytest -c ./projects/web-app-auth/configuration/.default.env 
```

#### Undeploying the infrastructure

Once the load testing infrastructure is undeployed, you can undeploy the infrastructure using load-testing-tool.sh with action 'undeploy'.
For instance the following command:

```bash
    vscode ➜ /workspace $ ./projects/web-app-auth/scripts/load-testing-tool.sh  -a undeploy -c ./projects/web-app-auth/configuration/.default.env 
```

## Using Azure DevOps pipelines and Github Actions

In this chapter, you will use Azure DevOps pipeline and/or Github Action to automate the deployment of the infrastructure and the launch of the load test.  

The pipelines (Azure DevOps pipelines and Github Actions) running Event Hub load testing includes the following steps:

- deploy the infrastructure to test
- deploy the load testing infrastructure
- update the infrastructure for the load test
- run the load testing
- update the infrastructure after the load test
- publish the load testing results  

### Creating the Service Principal for Github Action and Azure DevOps pipelines Azure Authentication  

If you want to use Azure DevOps pipelines or Github Actions, an authentication with Azure using a Service Principal is required.

In order to create this service principal you can use the following bash file: [scripts/create-rbac-sp.sh](./scripts/create-rbac-sp.sh)

This bash file assigns the role "Load Test Contributor" to the service principal, this role is mandatory to deploy and run Azure Load Testing from an Azure DevOps pipeline or a Github Action.

Before running this bash file you need to be connected with your Azure Account using Azure CLI. Run 'az login' in your linux environment or in your Dev Container Terminal

```bash
    vscode ➜ /workspace $ az login
```

Once you are connected with Azure, you can run the following bash to create the Service Principal:

```bash
    vscode ➜ /workspace $ ./scripts/create-rbac-sp.sh -s <Azure-Subscription-Id> -a <Service-Principal-Name>
```

where \<Azure-Subscription-Id\> is the subscriptionId of your Azure Account and \<Service-Principal-Name\> the name of the service principal which is created.  
Once completed, this bash file displays the information required for the Azure authentication with GitHub Action and Azure DevOps pipeline.

For instance:

```bash
    vscode ➜ /workspace $ ./scripts/create-rbac-sp.sh -s d3814ade-afe8-4260-9b5f-************ -a sp-loadtest-01
```

The bash file displays the following information in Json format:

```bash
    {
    "clientId": "********-****-****-****-************",
    "clientSecret": "************",
    "subscriptionId": "********-****-****-****-************",
    "tenantId": "********-****-****-****-************",
    "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
    "resourceManagerEndpointUrl": "https://management.azure.com/",
    "activeDirectoryGraphResourceId": "https://graph.windows.net/",
    "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
    "galleryEndpointUrl": "https://gallery.azure.com/",
    "managementEndpointUrl": "https://management.core.windows.net/"
    }
```

In the subsequent chapter, you'll see how to use this Json string to create the Github Action Secret AZURE_CREDENTIALS and how to use the clientId and clientSecret values to create the Azure DevOps Service Connection.

The creation of this service principal with your Azure Account may fail with the following error: "insufficient privileges to complete the operation", in that case, you'll need to contact your Azure Active Directory Administrator to create the Service Principal for you.

### Azure DevOps pipeline

The service principal for the Azure DevOps pipeline has been created, you can use Azure DevOps to create load testing pipelines.

The diagram below describes the architecture for this test with with Azure DevOps:

- a resource group associated with the Event Hubs based infrastructure to test
- a resource group associated with the load testing infrastructure and the VNET
- the Azure DevOps resources repository, pipeline and artifact

  ![eventhub-architecture-restricted-public-access-load-testing-azdo](./docs/img/load-testing-web-app-auth/architecture-scenario-load-testing-azdo.png)

*Download a [SVG file](./docs/img/load-testing-web-app-auth/architecture-scenario-load-testing-azdo.svg) of this diagram.*

#### **Link your Azure DevOps project with the GitHub repository**
<!-- markdown-link-check-disable -->
1. Navigate on your Azure DevOps organization "https://dev.azure.com/YOUR_ORG"

    ![azure-devops-org](./docs/img/load-testing-web-app-auth/azure-devops-org.png)
<!-- markdown-link-check-enable -->
2. Click on the button '+ New project'

3. On the 'Create new project' page enter the name of your project and click on the button 'Create'

    ![azure-devops-newproject](./docs/img/load-testing-web-app-auth/azure-devops-newproject.png)

4. On the main page of your project on Azure DevOps portal, select 'Repos' -> 'Files' page.

    ![azure-devops-project-repo](./docs/img/load-testing-web-app-auth/azure-devops-project-repo.png)

5. On this page, click on the 'import' button in the'Import a repository' section.

6. On the Import a Git repository page, enter the url of the git repository where you stored the source code of this project.

    ![azure-devops-project-git](./docs/img/load-testing-web-app-auth/azure-devops-project-git.png)

7. Click on the button 'Import', after few seconds the repository is imported.

    ![azure-devops-project-git-imported](./docs/img/load-testing-web-app-auth/azure-devops-project-git-imported.png)

#### **Install Azure Load Testing from the Azure DevOps Market Place**

As the new pipeline runs Azure Load Testing, you need to install the Azure Load Testing for Azure DevOps.

1. Click on the Market Place icon to browse the market place  
![azure-devops-market-1](./docs/img/load-testing-web-app-auth/azure-devops-market-1.png)

2. Search for the Azure Load Testing component  
![azure-devops-market-2](./docs/img/load-testing-web-app-auth/azure-devops-market-2.png)

3. On the Azure Load Testing page click on the button "Get it Free"  
![azure-devops-market-3](./docs/img/load-testing-web-app-auth/azure-devops-market-3.png)

4. On the Market Place page click on the button "Install"  
![azure-devops-market-4](./docs/img/load-testing-web-app-auth/azure-devops-market-4.png)

5. After few seconds the component is installed, Go back to Azure DevOps portal clicking on button "Proceed to organization"  
![azure-devops-market-5](./docs/img/load-testing-web-app-auth/azure-devops-market-5.png)

You can now create the service connection for the authentication with your Azure Account, the Variable Group and the Azure DevOps pipeline.

#### **Create Azure DevOps Service Connection, Variable Group and pipeline**

In order to create the service connection, Variable Group and pipeline you can use the following bash file: [scripts/create-azdo-resources.sh](../../scripts/create-azdo-resources.sh)  
This bash file creates:

- the service connection for the authentication with Azure Subscription. The name of this service connection is the name of the service principal created in the previous step with the prefix "sc-".
- the variable group which contains the parameters of the pipeline like AZURE_TEST_SUFFIX, AZURE_REGION, SERVICE_CONNECTION. By default the name of this variable group is "load-testing-vg". If you want to change this name, you'll have to update the file [scripts/create-azdo-resources.sh](../../scripts/create-azdo-resources.sh) and the pipeline file [azure-pipelines-load-testing.yml](./devops-pipelines/azure-pipelines/azure-pipelines-load-testing.yml).
- the Azure DevOps pipeline to run the load testing. By default, the name of the pipeline is "Load-Testing-EventHubs". If you want to change this name, you'll have to update the file [scripts/create-azdo-resources.sh](./scripts/create-azdo-resources.sh).
By default, the pipeline file should be present in the "main" branch, if it's not the case, you also need to update the file [scripts/create-azdo-resources.sh](./scripts/create-azdo-resources.sh).
  
Before running this bash file you need to be connected with your Azure Account using Azure CLI. Run 'az login' in your linux environment or in your Dev Container Terminal

```bash
    vscode ➜ /workspace $ az login
```

Once you are connected with Azure, you can run the following bash to create the Service Principal:

```bash
    vscode ➜ /workspace $ ./scripts/create-azdo-resources.sh -o "<MyORG>" -p "<MyProject>" -y "<MyRepository>" -s "<Azure-Subscription-Id>"  -t "<Azure-Tenant-Id>" -i "<ServicePrincipalId>" -k "<ServicePrincipalKey>"
```

where:

- \<MyORG\> is the name of your DevOps organization,
- \<MyProject\> is the name of your project,
- \<MyRepository\> is the name of your repository where the pipeline is stored,
- \<Azure-Subscription-Id\> is the subscriptionId of your Azure Account,
- \<Azure-Tenant-Id\> is the Tenant Id of your Azure AD Tenant,
- \<ServicePrincipalId\> is the value "clientId" of your Service Principal created with the bash file [scripts/create-rbac-sp.sh](./scripts/create-rbac-sp.sh),
- \<ServicePrincipalKey\> is the value "clientSecret" of your Service Principal created with the bash file [scripts/create-rbac-sp.sh](./scripts/create-rbac-sp.sh),

For instance:

```bash
        vscode ➜ /workspace $ ./scripts/create-azdo-resources.sh -o "TestAzDO" -p "load-testing-sharing" -y "load-testing-restricted-public-access" -s "d3814ade-afe8-4260-9b5f-xxxxxxxxxxxx"  -t "6a13df32-a807-43c4-8277-xxxxxxxxxxxx" -i "1d736738-9c5f-4de7-84f9-xxxxxxxxxxxx" -k "ok-8Q~Rsxxxxxxxxxxxx"
```

Once completed, this bash file displays the information about the different resources created.

```bash
  Creating Service Connection for:
    Subscription: d3814ade-afe8-4260-9b5f-xxxxxxxxxxxx
    Tenant: 6a13df32-a807-43c4-8277-xxxxxxxxxxxx
    Service Principal Id: 1d736738-9c5f-4de7-84f9-xxxxxxxxxxxx
  Creating Service Connection...
  Updating Service Connection to allow all pipelines...
  Creating Variables Group 'load-testing-vg' for:
    Organization: 'https://dev.azure.com/TestAzDO/'
    Project: 'load-testing-sharing'
  Creating Variables Group...
  Creating Pipeline 'Load-Testing-EventHubs' for:
    Organization: 'https://dev.azure.com/TestAzDO/'
    Project: 'load-testing-sharing'
  Creating Pipeline...
  Pipeline 'Load-Testing-EventHubs' created.
```

You can now check whether the service connection, the variable group and pipeline have been created.

1. On the main page of your project on Azure DevOps portal, select 'Project Settings' -> 'Service Connections' page. You should see the new service  connection with the prefix "sc-".  

    ![azure-devops-service-connection](./docs/img/load-testing-web-app-auth/azure-devops-service-connection.png)

2. On the main page of your project on Azure DevOps portal, select 'Pipelines' -> 'Library' page. You should see the new variable group "load-testing-vg".  

    ![azure-devops-service-variable-group](./docs/img/load-testing-web-app-auth/azure-devops-variable-group.png)

3. On the main page of your project on Azure DevOps portal, select 'Pipelines' -> 'Pipelines' page. You should see the new pipeline "Load-Testing-EventHubs".  

    ![azure-devops-service-pipeline](./docs/img/load-testing-web-app-auth/azure-devops-pipeline.png)

4. You can now click on the "Run pipeline" button to run manually the pipeline.
5. On the dialog box 'Run pipeline',  
    - select the 'main' branch,  
    - select the EventHubs Sku "Basic", "Standard", "Premium" ("Standard" by default),  
    - enter the duration of the test in seconds (60 seconds by default),  
    - enter the number of threads for the load testing (1 by default),  
    - enter the number of engine instances for the load testing (1 by default),  
    - enter the error percentage threshold for the load testing (5 by default),  
    - enter the average response time in milliseconds threshold for the load testing (100 by default),  
  Then click on the button "Run"

    ![azure-devops-pipeline-eventhub-02](./docs/img/load-testing-web-app-auth/azure-devops-pipeline-eventhub-02.png)

6. After few minutes, the pipeline is completed and you can download and visualize the results on the Azure Portal.

    ![azure-devops-pipeline-eventhub-03](./docs/img/load-testing-web-app-auth/azure-devops-pipeline-eventhub-03.png)

7. On the Azure Load Testing result page, you can see the requests/sec and the response time for the Event Hubs REST API requests towards both Event Hub inputs.

    ![azure-devops-pipeline-eventhub-04](./docs/img/load-testing-web-app-auth/azure-devops-pipeline-eventhub-04.png)

    **Note:**
    As the Azure Load Testing resource has been created in the pipeline, by default, you don't have access to this resource.
    The Azure Load Testing resource is present in the resource group whose name starts with "rgldtestevhub".  
    You will probably see the message below:  

    ![azure-devops-pipeline-eventhub-05](./docs/img/load-testing-web-app-auth/azure-devops-pipeline-eventhub-05.png)

    You need to assign the role "Load Test Contributor" to your Azure AD Account for the Azure Load Testing scope.  
    After few minutes you should have access to the page which displays the test results.

### Github Action

You can also use Github Action to automate the load testing of the same infrastructure based on Azure Event Hubs:

The diagram below describes the architecture for this test with Github Action:

- a resource group associated with the Event Hubs based infrastructure to test  
- a resource group associated with the load testing infrastructure and the Virtual Network  
- the Github resources repository, Github Action and artifact  
  
  ![eventhub-architecture-restricted-public-access-load-testing-github-action](./docs/img/load-testing-web-app-auth/architecture-scenario-load-testing-github-action.png)

*Download a [SVG file](./docs/img/load-testing-web-app-auth/architecture-scenario-load-testing-github-action.svg) of this diagram.*

First, you need to create the Github Action Secret AZURE_CREDENTIALS for the authentication with Azure.

#### **Create Github Action Secret AZURE_CREDENTIALS**

1. On the GitHub portal where you store your project, navigate on the the page 'Settings' and select the submenu 'Actions' in the menu 'Secrets and variables' and select the tab 'Secrets' on the page 'Actions secrets and variables'.

    ![github-action-secrets](./docs/img/load-testing-web-app-auth/github-action-secrets.png)

2. Click on 'New repository secret' button, enter 'AZURE_CREDENTIALS' in the Name field and copy/paste the JSON value associated with the service principal created with create-rbac-sp.sh.

    ![github-action-add-secret](./docs/img/load-testing-web-app-auth/github-action-add-secret.png)

3. Click on 'Add secret' button. The new secret will be accessible on the Secret page.  

    ![github-action-added-secret](./docs/img/load-testing-web-app-auth/github-action-added-secret.png)

#### **Create Github Action configuration variables**

Before installing the Github Action, you need to create the configuration variables which will be used by the Github Action:

- AZURE_REGION: The Azure region where the service will be deployed, for instance: 'eastus2'
- AZURE_TEST_SUFFIX: The suffix which it used to give a name to all the Azure resources.

When you enter the value of AZURE_TEST_SUFFIX, select a value which will not generate an Azure resource name which already exists.
You can use the command line below to generate a value which will avoid any conflict with existing Azure Storage, Azure Key Vault and Azure Events Hubs:

```bash
  vscode ➜ /workspace $ ./projects/web-app-auth/scripts/load-testing-tool.sh  -a getsuffix 
```

1. On the GitHub portal page associated with your project, navigate on the the page 'Settings' and select the submenu 'Actions' in the menu 'Secrets and variables' and select the tab 'Variables' on the page 'Actions secrets and variables'.

    ![github-action-variables](./docs/img/load-testing-web-app-auth/github-action-variables.png)

2. Click on 'New repository variable' button, enter 'AZURE_REGION' in the 'Name' field and the Azure region in the 'Value' field and click on the 'Add variable' button.

3. Click on 'New repository variable' button, enter 'AZURE_TEST_SUFFIX' in the 'Name' field and enter the suffix in the 'Value' field and click on the 'Add variable'

    ![github-action-added-variable](./docs/img/load-testing-web-app-auth/github-action-added-variable.png)

#### **Create Github Action pipeline for Event Hubs with restricted public access Load Testing**

By default, all the Github Action pipelines are stored under 'devops-pipelines/github-action'.
The Load Testing Github Action pipeline is [github-action-load-testing-eventhub-restricted-public-access.yml](devops-pipelines/github-action/github-action-load-testing-eventhub-restricted-public-access.yml)

In order to activate this pipeline, follow the steps below:

1. Create a folder '.github/workflows' in your repository
2. Copy the file github-action-load-testing-eventhub-restricted-public-access.yml in the folder '.github/workflows'
3. Commit and push this modification in your "main" branch

    ```bash
      git add  .github/workflows/github-action-load-testing-eventhub-restricted-public-access.yml
      git commit -m "Create Eventhub Load with restricted public access Testing Github Action"
      git push
    ```

4. Once the new pipeline is pushed into the main branch, you can launch manually the Github Action. On the GitHub portal, on the 'Action' page, select the workflow 'load-testing-eventhub-restricted-public-access' and click on the button 'Run workflow'. If required you can change the following input parameters:

   - Github branch: main by default
   - Azure Eventhub Sku: Standard by default
   - Load Testing duration: 60 seconds by default
   - Load Testing number of threads: 1 by default
   - Load Testing number of engine instances: 1 by default  
   - Load Testing error percentage threshold: 5% by default  
   - Load Testing average response time in milliseconds threshold: 100 ms by default  
   ![github-action-eventhub-start](./docs/img/load-testing-web-app-auth/github-action-eventhub-start.png)

5. After few minutes, the pipeline has been completed and you can download the load testing artifacts.  

    ![github-action-eventhub-completed](./docs/img/load-testing-web-app-auth/github-action-eventhub-completed.png)

## Under the hood

### Defining load testing parameters

Currently you can create one Azure DevOps pipeline using the YAML file below:

- EventHubs with restricted public access Load Testing pipeline: [azure-pipelines-load-testing.yml](./devops-pipelines/azure-pipelines/azure-pipelines-load-testing.yml)

You can create one Github Actions using the YAML file below:

- EventHubs with restricted public access Load Testing GitHub action: [github-action-load-testing-eventhub-restricted-public-access.yml](./devops-pipelines/github-action/github-action-load-testing-eventhub-restricted-public-access.yml)

Associated with each pipeline or GitHub action there are:

- a YAML file which defines the Azure Load Testing configuration. EventHubs with restricted public access Load Testing configuration file: [projects/eventhub/scenarios/eventhub-restricted-public-access/load-testing.template.yaml](./scenarios/eventhub-restricted-public-access/load-testing.template.yaml)  
- a JMX file which contains the JMeter project in XML format. EventHubs with restricted public access Load Testing JMX file: [load-testing.jmx](./scenarios/eventhub-restricted-public-access/load-testing.jmx)  

For each load test you can define:

- the number of engine instances to use,  
- the average response time in ms threshold which triggers an error and stop the pipeline, if the average response time is over this threshold,
- the error percentage threshold which triggers an error and stop the pipeline, if the error percentage is over this threshold.

For instance, if the average response time is over 100 ms or if the error percentage is over 5%, an error will be generated.

You also need to define in the Load Testing Configuration file the subnetId of subnet the Load Testing service will be connected to. The pipeline or the GitHub action will automatically replace {subnetId} with the value of the subnetId.

Moreover, you need to define the information related to the storage of Azure Event Hubs token in the Azure Key Vault. You need to define the secret name for the Event Hubs Token in the JMX file (currently 'eventhub_token'), the Azure Key Vault Name and the Key Vault secret name.

All those input parameters are defined in the Load Testing configuration file in the following variables:

- {engineInstances}
- {responseTimeMs}
- {errorPercentage}
- {subnetId}
- {loadTestSecretName}
- {keyVaultName}
- {keyVaultSecretName}

```yml
      engineInstances: "{engineInstances}"
      subnetId: "{subnetId}"

      failureCriteria:
          - "avg(response_time_ms) > {responseTimeMs}"
          - "percentage(error) > {errorPercentage}"

      secrets:
          - name: "{loadTestSecretName}"
            value: "https://{keyVaultName}.vault.azure.net/secrets/{keyVaultSecretName}/"
```

The Azure DevOps pipeline and the GitHub action automatically replaces the values in the configuration file.
For instance, below the Azure DevOps step which updates the Load Testing configuration file to take into account the values of "engineInstances", "responseTimeMs", "errorPercentage", "loadTestSecretName", "keyVaultName", "keyVaultSecretName", "subnetId":  

```yml
          - task: AzureCLI@2
            displayName: 'Configure and display Load Testing Configuration for Eventhub'
            name: configureloadtest
            inputs:
              azureSubscription: $(SERVICE_CONNECTION)
              scriptType: "bash"
              addSpnToEnvironment: "true"
              scriptLocation: "inlineScript"
              inlineScript: |
                # Read variables from configuration file
                set -o allexport
                source "$(CONFIGURATION_FILE)"
                set +o allexport

                echo "AZURE_RESOURCE_EVENTHUBS_NAMESPACE: $(AZURE_RESOURCE_EVENTHUBS_NAMESPACE)"
                echo "AZURE_RESOURCE_EVENTHUB_INPUT1_NAME: $(AZURE_RESOURCE_EVENTHUB_INPUT1_NAME)"
                echo "AZURE_RESOURCE_EVENTHUB_INPUT2_NAME: $(AZURE_RESOURCE_EVENTHUB_INPUT2_NAME)"
                echo "DURATION: ${{ parameters.duration }}"
                echo "THREADS: ${{ parameters.threads }}"
                echo "ENGINE INSTANCES: ${{ parameters.engineInstances }}"
                echo "ERROR PERCENTAGE: ${{ parameters.errorPercentage }}"
                echo "RESPONSE TIME MS: ${{ parameters.responseTimeMs }}"
                # Update Load Testing configuration file
                TEMP_DIR=$(mktemp -d)
                cp "$(System.DefaultWorkingDirectory)/devops-pipelines/load-testing/load-testing-eventhub-restricted-public-access.jmx" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.jmx"
                cp "$(System.DefaultWorkingDirectory)/devops-pipelines/load-testing/load-testing-eventhubevents1.csv" "$TEMP_DIR/load-testing-eventhubevents1.csv"
                cp "$(System.DefaultWorkingDirectory)/devops-pipelines/load-testing/load-testing-eventhubevents2.csv" "$TEMP_DIR/load-testing-eventhubevents2.csv"
                cp "$(System.DefaultWorkingDirectory)/devops-pipelines/load-testing/load-testing-eventhub-restricted-public-access.template.yaml" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.yaml"
                sed -i "s/{engineInstances}/${{ parameters.engineInstances }}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.yaml"
                sed -i "s/{errorPercentage}/${{ parameters.errorPercentage }}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.yaml"
                sed -i "s/{responseTimeMs}/${{ parameters.responseTimeMs }}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.yaml"
                sed -i "s/{loadTestSecretName}/eventhub_token/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.yaml"
                sed -i "s/{keyVaultName}/${LOAD_TESTING_KEY_VAULT_NAME}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.yaml"
                sed -i "s/{keyVaultSecretName}/${LOAD_TESTING_SECRET_NAME}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.yaml"
                sed -i "s/{subnetId}/${LOAD_TESTING_SUBNET_ID////\\/}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.yaml"

                echo "load-testing-eventhub-restricted-public-access.yaml content:"
                cat "$TEMP_DIR/load-testing-eventhub-restricted-public-access.yaml"

                # Store the temporary directory in output variable
                echo "##vso[task.setvariable variable=TEMP_DIR;issecret=false]$TEMP_DIR"
                echo "##vso[task.setvariable variable=LOAD_TESTING_RESOURCE_GROUP;issecret=false]$LOAD_TESTING_RESOURCE_GROUP"
                echo "##vso[task.setvariable variable=LOAD_TESTING_NAME;issecret=false]$LOAD_TESTING_NAME"
```

### Opening access to Azure Event Hubs and Azure Key Vault

Before running the Load Test, we need to ensure the Azure Event Hubs and the Azure Key Vault are accessible from Azure Load Testing.

For instance, below the Azure DevOps pipeline step in [azure-pipelines-load-testing.yml](./devops-pipelines/azure-pipelines/azure-pipelines-load-testing.yml) which calls iactoo.sh bash with the option 'opentest'.

```yml
          - task: AzureCLI@2
            displayName: 'Open access to EventHub and KeyVault for the test'
            name: openloadtest
            inputs:
              azureSubscription: $(SERVICE_CONNECTION)
              scriptType: "bash"
              addSpnToEnvironment: "true"
              scriptLocation: "inlineScript"
              inlineScript: |
                cmd="devops-pipelines/utils/load-testing-tool.sh -a opentest -c $(CONFIGURATION_FILE)"
                echo "$cmd"
                eval "$cmd"
```

The bash file:

- reads the variables in the configuration file (./projects/web-app-auth/configuration/.default.env)
- adds the public IP address in the list of IP addresses allowed to access the Azure Event Hubs.
- allows the Access to the Azure Key Vault where the Event Hubs token will be stored

```bash
        readConfigurationFile "$CONFIGURATION_FILE"

        printProgress "Open access to EventHubs '${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}' access for the load testing resource with public ip: ${LOAD_TESTING_PUBLIC_IP_ADDRESS}..."    
        if [[ -n ${AZURE_RESOURCE_EVENTHUBS_NAMESPACE} ]]; then
            if [[ -n $(az eventhubs namespace show --name "${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}" --resource-group "${RESOURCE_GROUP}" 2>/dev/null| jq -r .id) ]]; then
                if [[ -n ${LOAD_TESTING_PUBLIC_IP_ADDRESS} ]]; then
                    cmd="az eventhubs namespace network-rule list  --namespace-name ${AZURE_RESOURCE_EVENTHUBS_NAMESPACE} -g ${RESOURCE_GROUP} | jq -r '.ipRules[]  |  select(.ipMask==\"${LOAD_TESTING_PUBLIC_IP_ADDRESS}\") ' | jq --slurp '.[0].action' | tr -d '\"'"
                    ALLOW=$(eval "${cmd}")
                    if [ ! "${ALLOW}" == "Allow" ]  
                    then
                        cmd="az eventhubs namespace network-rule add --ip-address ${LOAD_TESTING_PUBLIC_IP_ADDRESS} --namespace-name ${AZURE_RESOURCE_EVENTHUBS_NAMESPACE} -g ${RESOURCE_GROUP} "
                        echo "$cmd"
                        eval "${cmd}" >/dev/null
                        # Wait 30 seconds for the access to the eventhubs
                        sleep 30
                    fi
                fi
            fi
        fi

        printProgress "Open access to Key Vault '${LOAD_TESTING_KEY_VAULT_NAME}' for the test..."    
        cmd="az keyvault update --default-action Allow --name ${LOAD_TESTING_KEY_VAULT_NAME} -g ${LOAD_TESTING_RESOURCE_GROUP}"
        echo "$cmd"
        eval "${cmd}" >/dev/null
        printMessage "Eventhub and Keyvault are now accessible from Azure Load Testing"

```

### Implementing the Azure Event Hubs authentication in the JMX files

For the Azure Event Hubs Load Testing pipeline [azure-pipelines-load-testing.yml](./devops-pipelines/azure-pipelines/azure-pipelines-load-testing.yml), the authentication with Azure Event Hubs is required, the Load Testing platform sends the Event Hubs Shared Access Token in each http requests towards the endpoint for the authentication.

In the step 'Get EventHub Token and store it in Key Vault', the pipeline create the Event Hubs Shared Access Token using the bash file [get-event-hub-token.sh](./scripts/get-event-hub-token.sh) and then store the token in the Azure Key Vault using the Azure CLI command line 'az keyvault secret set '.

```bash
          - task: AzureCLI@2
            displayName: 'Get EventHub Token and store it in Key Vault'
            name: getandstoretoken
            inputs:
              azureSubscription: $(SERVICE_CONNECTION)
              scriptType: "bash"
              addSpnToEnvironment: "true"
              scriptLocation: "inlineScript"
              inlineScript: |
                # Read variables from configuration file
                set -o allexport
                source "$(CONFIGURATION_FILE)"
                set +o allexport

                cat "$(CONFIGURATION_FILE)"

                # Get Event Hub Token
                KEY=$(az eventhubs namespace authorization-rule keys list --resource-group "$(RESOURCE_GROUP)" --namespace-name "$(AZURE_RESOURCE_EVENTHUBS_NAMESPACE)" --name RootManageSharedAccessKey | jq -r .primaryKey)
                echo "KEY: $KEY"
                EVENTHUB_TOKEN=$("$(System.DefaultWorkingDirectory)/scripts/get-event-hub-token.sh" "$(AZURE_RESOURCE_EVENTHUBS_NAMESPACE)" RootManageSharedAccessKey "${KEY}")
                echo "EVENTHUB_TOKEN: $EVENTHUB_TOKEN"

                # store eventhub token into azure key vault secret
                az keyvault secret set --vault-name "${LOAD_TESTING_KEY_VAULT_NAME}" --name "${LOAD_TESTING_SECRET_NAME}" --value "${EVENTHUB_TOKEN}" --output none

```

The information related to the token stored in the Azure Key Vault are already defined in the file [load-testing-eventhub-restricted-public-access.template.yaml](./scenarios/eventhub-restricted-public-access/load-testing.template.yaml)

```yml
      secrets:
          - name: "{loadTestSecretName}"
            value: "https://{keyVaultName}.vault.azure.net/secrets/{keyVaultSecretName}/"
```

This configuration file is used to create the load test in the step: 'Step Run Load Testing EventHub'.
This step shares the Event Hubs Shared Access Token with the load testing platform running the jmx file through the secret called 'eventhub_token':  

```yaml
    - task: AzureLoadTest@1
      displayName: 'Step Run Load Testing EventHub'
      inputs:
        azureSubscription: $(SERVICE_CONNECTION)
        loadTestConfigFile: '$(TEMP_DIR)/load-testing-eventhub-restricted-public-access.yaml'
        resourceGroup: $(LOAD_TESTING_RESOURCE_GROUP)
        loadTestResource: $(LOAD_TESTING_NAME)
        secrets: |
          [
          ]
        env: |
          [
            {
            "name": "eventhub_name_space",
            "value": "$(AZURE_RESOURCE_EVENTHUBS_NAMESPACE)"
            },
            {
            "name": "eventhub_input_1",
            "value": "$(AZURE_RESOURCE_EVENTHUB_INPUT1_NAME)"
            },
            {
            "name": "eventhub_input_2",
            "value": "$(AZURE_RESOURCE_EVENTHUB_INPUT2_NAME)"
            },
            {
            "name": "duration",
            "value": "${{ parameters.duration }}"
            },
            {
            "name": "threads",
            "value": "${{ parameters.threads }}"
            }
          ]

```

The load testing service reads the secret called 'eventhub_token'and initialize the variable 'udv_token' with the token value.

```xml
        <Arguments guiclass="ArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
          <collectionProp name="Arguments.arguments">
            <elementProp name="udv_namespace" elementType="Argument">
              <stringProp name="Argument.name">udv_namespace</stringProp>
              <stringProp name="Argument.value">${__BeanShell( System.getenv("eventhub_name_space") )}</stringProp>
              <stringProp name="Argument.desc">Event Hubs Name Space</stringProp>
              <stringProp name="Argument.metadata">=</stringProp>
            </elementProp>
            <elementProp name="udv_evinput1" elementType="Argument">
              <stringProp name="Argument.name">udv_evinput1</stringProp>
              <stringProp name="Argument.value">${__BeanShell( System.getenv("eventhub_input_1") )}</stringProp>
              <stringProp name="Argument.desc">Event Hub input 1</stringProp>
              <stringProp name="Argument.metadata">=</stringProp>
            </elementProp> 
            <elementProp name="udv_evinput2" elementType="Argument">
              <stringProp name="Argument.name">udv_evinput2</stringProp>
              <stringProp name="Argument.value">${__BeanShell( System.getenv("eventhub_input_2") )}</stringProp>
              <stringProp name="Argument.desc">Event Hub input 2</stringProp>
              <stringProp name="Argument.metadata">=</stringProp>
            </elementProp>             
            <elementProp name="udv_token" elementType="Argument">
              <stringProp name="Argument.name">udv_token</stringProp>
              <stringProp name="Argument.value">${__GetSecret(eventhub_token)}</stringProp>
              <stringProp name="Argument.desc">Event Hub Token</stringProp>
              <stringProp name="Argument.metadata">=</stringProp>
            </elementProp>
            <elementProp name="udv_duration" elementType="Argument">
              <stringProp name="Argument.name">udv_duration</stringProp>
              <stringProp name="Argument.value">${__BeanShell( System.getenv("duration") )}</stringProp>
              <stringProp name="Argument.desc">Test Duration</stringProp>
              <stringProp name="Argument.metadata">=</stringProp>
            </elementProp>
            <elementProp name="udv_threads" elementType="Argument">
              <stringProp name="Argument.name">udv_threads</stringProp>
              <stringProp name="Argument.value">${__BeanShell( System.getenv("threads") )}</stringProp>
              <stringProp name="Argument.desc">Test number of threads</stringProp>
              <stringProp name="Argument.metadata">=</stringProp>
            </elementProp>
          </collectionProp>
        </Arguments>
```

And finally, the http header 'Authorization' is initialized with the value of the 'udv_token' variable.

```xml
        <HeaderManager guiclass="HeaderPanel" testclass="HeaderManager" testname="HTTP Header Manager" enabled="true">
          <collectionProp name="HeaderManager.headers">
            <elementProp name="" elementType="Header">
              <stringProp name="Header.name">Content-Type</stringProp>
              <stringProp name="Header.value">application/atom+xml;type=entry;charset=utf-8</stringProp>
            </elementProp>
            <elementProp name="" elementType="Header">
              <stringProp name="Header.name">Authorization</stringProp>
              <stringProp name="Header.value">${udv_token}</stringProp>
            </elementProp>
            <elementProp name="" elementType="Header">
              <stringProp name="Header.name">Host</stringProp>
              <stringProp name="Header.value">${udv_namespace}.servicebus.windows.net</stringProp>
            </elementProp>
            <elementProp name="" elementType="Header">
              <stringProp name="Header.name">BrokerProperties</stringProp>
              <stringProp name="Header.value">{"PartitionKey": "${appid}${hostname}"}</stringProp>
            </elementProp>
          </collectionProp>
        </HeaderManager>
```

### Streaming events from two different CSV files simultaneously

For this scenario, the infrastructure supports two input Event Hubs receiving different kind of events:

The input 1 receives events generated from the content in file [load-testing-eventhubevents1.csv](./devops-pipelines/load-testing/load-testing-eventhubevents1.csv)

```csv
      index,appid,hostname,ts,severity,http_status,domain,application
      0,loadtest0,evhasa,2022-05-13T15:04:35.7602665,W,204,com.some.logger,MAIN
      1,loadtest1,evhasa,2022-05-13T15:04:35.6517124,W,200,com.some.logger,MAIN
      2,loadtest2,evhasa,2022-05-13T15:06:35.4017622,W,200,com.some.logger,MAIN
      3,loadtest3,evhasa,2022-05-13T15:08:35.2924317,W,202,com.some.logger,MAIN
      4,loadtest4,evhasa,2022-05-13T15:10:35.2924317,W,202,com.some.logger,MAIN
      .
      .
```

The input 2 receives events generated from the content in file [load-testing-eventhubevents2.csv](./devops-pipelines/load-testing/load-testing-eventhubevents2.csv)

```csv
      index,appid,hostname,ts,time_ms,resp_time,failed_trans
      0,loadtest0,evhasa,2022-05-13T15:00:35.6517124,395,160,134
      1,loadtest1,evhasa,2022-05-13T15:01:35.4017622,216,386,32
      2,loadtest2,evhasa,2022-05-13T15:02:35.2924317,168,163,24
      3,loadtest3,evhasa,2022-05-13T15:03:34.8030526,91,121,52
      .
      .
```

These two CSV source files don't contain the same kind of data, the columns are different, the file [load-testing-eventhub-restricted-public-access.jmx](./devops-pipelines/load-testing/load-testing-eventhub-restricted-public-access.jmx) has been updated to support the different models.

Input 1 with the declaration of each variable associated with the columns in the first CSV file:

```xml
        <CSVDataSet guiclass="TestBeanGUI" testclass="CSVDataSet" testname="CSV Logs" enabled="true">
          <stringProp name="delimiter">,</stringProp>
          <stringProp name="fileEncoding">UTF-8</stringProp>
          <stringProp name="filename">load-testing-eventhubevents1.csv</stringProp>
          <boolProp name="ignoreFirstLine">true</boolProp>
          <boolProp name="quotedData">true</boolProp>
          <boolProp name="recycle">true</boolProp>
          <stringProp name="shareMode">shareMode.all</stringProp>
          <boolProp name="stopThread">true</boolProp>
          <stringProp name="variableNames">index,appid,hostname,ts,severity,http_status,domain,application</stringProp>
        </CSVDataSet> 
```

Input 2 with the declaration of each variable associated with the columns in the second CSV file:

```xml
        <CSVDataSet guiclass="TestBeanGUI" testclass="CSVDataSet" testname="CSV Metrics" enabled="true">
          <stringProp name="delimiter">,</stringProp>
          <stringProp name="fileEncoding">UTF-8</stringProp>
          <stringProp name="filename">load-testing-eventhubevents2.csv</stringProp>
          <boolProp name="ignoreFirstLine">true</boolProp>
          <boolProp name="quotedData">true</boolProp>
          <boolProp name="recycle">true</boolProp>
          <stringProp name="shareMode">shareMode.all</stringProp>
          <boolProp name="stopThread">true</boolProp>
          <stringProp name="variableNames">index,appid,hostname,ts,time_ms,resp_time,failed_trans</stringProp>
        </CSVDataSet>  
```

Once the format of the source files is defined, the file [load-testing-eventhub-restricted-public-access.jmx](./devops-pipelines/load-testing/load-testing-eventhub-restricted-public-access.jmx) is updated to define the format of the HTTP request body towards the Event Hub.

HTTP request for Input 1:

```xml
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="Logs Request" enabled="true">
          <boolProp name="HTTPSampler.postBodyRaw">true</boolProp>
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments">
            <collectionProp name="Arguments.arguments">
              <elementProp name="" elementType="HTTPArgument">
                <boolProp name="HTTPArgument.always_encode">false</boolProp>
                <stringProp name="Argument.value">{&quot;ts&quot;: &quot;${__time(yyyy-MM-dd)}T${__time(HH:mm:ss:SSS)}&quot;, &quot;appid&quot;:&quot;${appid}&quot;,&quot;hostname&quot;: &quot;${hostname}&quot;,&quot;severity&quot;:&quot;${severity}&quot;,&quot;http_status&quot;:&quot;${http_status}&quot;,&quot;domain&quot;:&quot;${domain}&quot;,&quot;application&quot;:&quot;${application}&quot; }&#xd;</stringProp>
                <stringProp name="Argument.metadata">=</stringProp>
              </elementProp>
            </collectionProp>
          </elementProp>
          <stringProp name="HTTPSampler.domain">${udv_namespace}.servicebus.windows.net</stringProp>
          <stringProp name="HTTPSampler.port">443</stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.contentEncoding"></stringProp>
          <stringProp name="HTTPSampler.path">${udv_evinput1}/messages?timeout=60&amp;api-version=2014-01</stringProp>
          <stringProp name="HTTPSampler.method">POST</stringProp>
          <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
          <boolProp name="HTTPSampler.auto_redirects">false</boolProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
          <boolProp name="HTTPSampler.DO_MULTIPART_POST">false</boolProp>
          <stringProp name="HTTPSampler.embedded_url_re"></stringProp>
          <stringProp name="HTTPSampler.connect_timeout"></stringProp>
          <stringProp name="HTTPSampler.response_timeout"></stringProp>
        </HTTPSamplerProxy>
```

HTTP request for Input 2:

```xml
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="Metrics Request" enabled="true">
          <boolProp name="HTTPSampler.postBodyRaw">true</boolProp>
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments">
            <collectionProp name="Arguments.arguments">
              <elementProp name="" elementType="HTTPArgument">
                <boolProp name="HTTPArgument.always_encode">false</boolProp>
                <stringProp name="Argument.value">{&quot;ts&quot;: &quot;${__time(yyyy-MM-dd)}T${__time(HH:mm:ss:SSS)}&quot;, &quot;appid&quot;:&quot;${appid}&quot;,&quot;hostname&quot;: &quot;${hostname}&quot;,&quot;time_ms&quot;:&quot;${time_ms}&quot;,&quot;resp_time&quot;:&quot;${resp_time}&quot;,&quot;failed_trans&quot;:&quot;${failed_trans}&quot; }&#xd;</stringProp>
                <stringProp name="Argument.metadata">=</stringProp>
              </elementProp>
            </collectionProp>
          </elementProp>
          <stringProp name="HTTPSampler.domain">${udv_namespace}.servicebus.windows.net</stringProp>
          <stringProp name="HTTPSampler.port">443</stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.contentEncoding"></stringProp>
          <stringProp name="HTTPSampler.path">${udv_evinput2}/messages?timeout=60&amp;api-version=2014-01</stringProp>
          <stringProp name="HTTPSampler.method">POST</stringProp>
          <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
          <boolProp name="HTTPSampler.auto_redirects">false</boolProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
          <boolProp name="HTTPSampler.DO_MULTIPART_POST">false</boolProp>
          <stringProp name="HTTPSampler.embedded_url_re"></stringProp>
          <stringProp name="HTTPSampler.connect_timeout"></stringProp>
          <stringProp name="HTTPSampler.response_timeout"></stringProp>
        </HTTPSamplerProxy>
```
<!-- markdown-link-check-disable -->
Moreover, the ts value (Timestamp) in the body of the POST HTTP request is updated with the current time.

At least, when the test is completed, you can check in the result file whether both Event Hub inputs did receive the HTTP Request:

| timeStamp  | elapsed | label | responseCode | responseMessage | threadName | dataType | URL | Latency | IdleTime | Connect|
|:----------:|:-------:|:-----:|:-------------:|:----------------:|:-----------:|:---------:|:----|:-------:|:---------:|:-------:|
|1.67395E+12 | 122   | Logs  Request | 201     | Created   | 10.1.1.4-Thread Group 1-1 | text | "https://evhevhubxxxx.servicebus.windows.net/evinput1/messages?timeout=60&api-version=2014-01" | 122 | 0 | 63|
| 1.67395E+12 | 39 | Metrics Request | 201 | Created | 10.1.1.4-Thread Group 1-1 | text | "https://evhevhubxxxx.servicebus.windows.net/evinput2/messages?timeout=60&api-version=2014-01" | 39 | 0 | 0|
| 1.67395E+12 | 44 | Logs Request | 201 | Created | 10.1.1.4-Thread Group 1-1 | text | "https://evhevhubxxxx.servicebus.windows.net/evinput1/messages?timeout=60&api-version=2014-01" | 44 | 0 | 0|
| 1.67395E+12 | 40 | Metrics Request | 201 | Created | 10.1.1.4-Thread Group 1-1 | text | "https://evhevhubxxxx.servicebus.windows.net/evinput2/messages?timeout=60&api-version=2014-01"  | 40  | 0 | 0|
<!-- markdown-link-check-enable -->

### Using Data Plane Load Test Administration and Load Test Run REST API

When you use load-testing-tool.sh bash file with the option 'runtest' to run the load tests, it uses Data Plane Load Test Administration and Load Test Run REST APIs to create the test, run the test and monitor the test.

Before calling the REST API, you need to get the Load Testing Token. First you need to retrieve the Load Testing Hostname from the Load Testing Azure resource. Once you can get the hostname, you can get the token using the Azure CLI command 'az account get-access-token' see below:

```bash
    LOAD_TESTING_HOSTNAME=$(az load  show --name "${LOAD_TESTING_RESOURCE_NAME}" --resource-group "${LOAD_TESTING_RESOURCE_GROUP}" | jq -r ".dataPlaneURI")
    LOAD_TESTING_TOKEN=$(az account get-access-token --resource "${LOAD_TESTING_HOSTNAME}" --scope "https://cnt-prod.loadtesting.azure.com/.default" | jq -r '.accessToken')
```

Once you get the token, you can call the load test administration REST API to create a new test filling the values in the template file [./devops-pipelines/load-testing/load-testing-eventhub-restricted-public-access.template.json](./devops-pipelines/load-testing/load-testing-eventhub-restricted-public-access.template.json). This json file is used as the body of the REST API call. 

Further information about the load test administration REST API on this page: [https://learn.microsoft.com/en-us/rest/api/loadtesting/dataplane(2022-11-01)/load-test-administration](https://learn.microsoft.com/en-us/rest/api/loadtesting/dataplane(2022-11-01)/load-test-administration)

Below the code to create the load test:

```bash
    LOAD_TESTING_TEST_ID=$(cat /proc/sys/kernel/random/uuid)

    TEMP_DIR=$(mktemp -d)
    cp  "$SCRIPTS_DIRECTORY/../../devops-pipelines/load-testing/load-testing-eventhub-restricted-public-access.template.json"  "$TEMP_DIR/load-testing-eventhub-restricted-public-access.json"
    sed -i "s/{name}/${LOAD_TESTING_TEST_NAME}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.json"
    sed -i "s/{engineInstances}/${LOAD_TESTING_ENGINE_INSTANCES}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.json"
    sed -i "s/{errorPercentage}/${LOAD_TESTING_ERROR_PERCENTAGE}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.json"
    sed -i "s/{responseTimeMs}/${LOAD_TESTING_RESPONSE_TIME}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.json"
    sed -i "s/{loadTestSecretName}/eventhub_token/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.json"
    sed -i "s/{keyVaultName}/${LOAD_TESTING_KEY_VAULT_NAME}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.json"
    sed -i "s/{keyVaultSecretName}/${LOAD_TESTING_SECRET_NAME}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.json"
    sed -i "s/{eventhubNameSpace}/${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.json"
    sed -i "s/{eventhubInput1}/${AZURE_RESOURCE_EVENTHUB_INPUT1_NAME}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.json"
    sed -i "s/{eventhubInput2}/${AZURE_RESOURCE_EVENTHUB_INPUT2_NAME}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.json"
    sed -i "s/{duration}/${LOAD_TESTING_DURATION}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.json"
    sed -i "s/{threads}/${LOAD_TESTING_THREADS}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.json"
    sed -i "s/{subnetId}/${LOAD_TESTING_SUBNET_ID////\\/}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access.json"

    cmd="curl -s -X PATCH \
    \"https://$LOAD_TESTING_HOSTNAME/tests/$LOAD_TESTING_TEST_ID?api-version=2022-11-01\" \
    -H 'accept: application/merge-patch+json'  -H 'Content-Type: application/merge-patch+json' -H 'Authorization: Bearer $LOAD_TESTING_TOKEN' \
     -d \"@$TEMP_DIR/load-testing-eventhub-restricted-public-access.json\" "
    eval "$cmd" >/dev/null
```

Once the load test is created you need to upload the jmx and csv files associated with the load test using the code below:

```bash
    cmd="curl -s -X PUT \
    \"https://${LOAD_TESTING_HOSTNAME}/tests/${LOAD_TESTING_TEST_ID}/files/load-testing-eventhub-restricted-public-access.jmx?fileType=JMX_FILE&api-version=2022-11-01\" \
     -H 'Content-Type: application/octet-stream' -H 'Authorization: Bearer ${LOAD_TESTING_TOKEN}' \
     --data-binary  \"@$SCRIPTS_DIRECTORY/../../devops-pipelines/load-testing/load-testing-eventhub-restricted-public-access.jmx\" "
    eval "$cmd" >/dev/null
```

Once the jmx file and the 2 csv files are uploaded, you can run the load test using the load test run REST API. Further information about this REST API on this page:
[https://learn.microsoft.com/en-us/rest/api/loadtesting/dataplane(2022-11-01)/load-test-run](https://learn.microsoft.com/en-us/rest/api/loadtesting/dataplane(2022-11-01)/load-test-run).

You need to fill the values in the template file [./devops-pipelines/load-testing/load-testing-eventhub-restricted-public-access-run.template.json](./devops-pipelines/load-testing/load-testing-eventhub-restricted-public-access-run.template.json) before calling the API to run the test. This json file is used as the body of the REST API call. 

```bash
    LOAD_TESTING_TEST_RUN_ID=$(cat /proc/sys/kernel/random/uuid)
    printProgress "Launching test ${LOAD_TESTING_TEST_NAME} RunID:${LOAD_TESTING_TEST_RUN_ID}..."    
    # Update Load Testing configuration file
    LOAD_TESTING_DATE=$(date +"%y%m%d-%H%M%S")
    TEMP_DIR=$(mktemp -d)
    cp  "$SCRIPTS_DIRECTORY/../../devops-pipelines/load-testing/load-testing-eventhub-restricted-public-access-run.template.json"  "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{name}/${LOAD_TESTING_TEST_NAME}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{id}/${LOAD_TESTING_TEST_ID}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{date}/${LOAD_TESTING_DATE}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{engineInstances}/${LOAD_TESTING_ENGINE_INSTANCES}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{errorPercentage}/${LOAD_TESTING_ERROR_PERCENTAGE}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{responseTimeMs}/${LOAD_TESTING_RESPONSE_TIME}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{loadTestSecretName}/eventhub_token/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{keyVaultName}/${LOAD_TESTING_KEY_VAULT_NAME}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{keyVaultSecretName}/${LOAD_TESTING_SECRET_NAME}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{eventhubNameSpace}/${AZURE_RESOURCE_EVENTHUBS_NAMESPACE}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{eventhubInput1}/${AZURE_RESOURCE_EVENTHUB_INPUT1_NAME}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{eventhubInput2}/${AZURE_RESOURCE_EVENTHUB_INPUT2_NAME}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{duration}/${LOAD_TESTING_DURATION}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{threads}/${LOAD_TESTING_THREADS}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"
    sed -i "s/{subnetId}/${LOAD_TESTING_SUBNET_ID////\\/}/g" "$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json"

    # Wait 10 seconds to be sure the JMX file is validated
    sleep 10

    cmd="curl -s -X PATCH  \
    \"https://${LOAD_TESTING_HOSTNAME}/test-runs/${LOAD_TESTING_TEST_RUN_ID}?api-version=2022-11-01\" \
    -H 'accept: application/merge-patch+json'  -H 'Content-Type: application/merge-patch+json' -H 'Authorization: Bearer ${LOAD_TESTING_TOKEN}' \
     -d \"@$TEMP_DIR/load-testing-eventhub-restricted-public-access-run.json\" "
    eval "$cmd"  >/dev/null
```

Once the load test is launched, you can monitor the status of the load test using the REST API below.

```bash
    statuscmd="curl -s -X GET \
    \"https://${LOAD_TESTING_HOSTNAME}/test-runs/${LOAD_TESTING_TEST_RUN_ID}?api-version=2022-11-01\" \
    -H 'accept: application/merge-patch+json'  -H 'Content-Type: application/merge-patch+json' -H 'Authorization: Bearer ${LOAD_TESTING_TOKEN}' "
    LOAD_TESTING_STATUS="unknown"
    while [ "${LOAD_TESTING_STATUS}" != "DONE" ] && [ "${LOAD_TESTING_STATUS}" != "FAILED" ] && [ "${LOAD_TESTING_STATUS}" != "null" ]
    do
        sleep 10
        LOAD_TESTING_STATUS=$(eval "$statuscmd" | jq -r '.status')
        printProgress "Current status: ${LOAD_TESTING_STATUS}" 
    done
```

This REST API returns the status of the load test:

- ACCEPTED: The load testing configuration with the JMX file and CSV files has been accepted
- PROVISIONING: The load testing service is provisioning the resources for the test
- CONFIGURING: The load testing service is configuring the resources
- EXECUTING: The load testing service is executing the test
- DONE: the test is completed

As soon as the status of the load test is 'DONE', you can check the status of testResult. When the value is 'PASSED' the load test results are available.

```bash
    LOAD_TESTING_RESULT="NOT_APPLICABLE"
    while [ "${LOAD_TESTING_RESULT}" == "NOT_APPLICABLE" ] 
    do
        sleep 10
        LOAD_TESTING_RESULT=$(eval "$statuscmd" | jq -r '.testResult')
        printProgress "Current results status: ${LOAD_TESTING_RESULT}" 
    done
    LOAD_TESTING_STATISTICS=$(eval "$statuscmd" | jq -r '.testRunStatistics')
    printMessage "Running load testing successful"
    printMessage "Result: $LOAD_TESTING_RESULT"
    printMessage "Statistics: $LOAD_TESTING_STATISTICS"  
```

## Contribute

This project welcomes contributions and suggestions. Further information about contributions in this [document](./CONTRIBUTING.md)

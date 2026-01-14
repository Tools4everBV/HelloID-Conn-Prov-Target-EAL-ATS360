# HelloID-Conn-Prov-Target-EAL-ATS360 
> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://www.eal.nl/images/logo-eal-blauw-final.svg">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-EAL-ATS360](#helloid-conn-prov-target-eal-ats360)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Supported  features](#supported--features)
  - [Getting started](#getting-started)
    - [HelloID Icon URL](#helloid-icon-url)
    - [Requirements](#requirements)
    - [Connection settings](#connection-settings)
    - [Correlation configuration](#correlation-configuration)
    - [Field mapping](#field-mapping)
    - [Account Reference](#account-reference)
  - [Remarks](#remarks)
    - [No Authentication](#no-authentication)
    - [Mandatory property](#mandatory-property)
    - [No get user API request](#no-get-user-api-request)
    - [Grant permission](#grant-permission)
    - [Mapping logic](#mapping-logic)
  - [Development resources](#development-resources)
    - [API endpoints](#api-endpoints)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-EAL-ATS360_ is a _target_ connector. _EAL-ATS360_ provides a set of REST API's that allow you to programmatically interact with its data.

## Supported  features

The following features are available:

| Feature                                   | Supported | Actions                                 | Remarks |
| ----------------------------------------- | --------- | --------------------------------------- | ------- |
| **Account Lifecycle**                     | ✅         | Create, Update, Enable, Disable, Delete |         |
| **Permissions**                           | ✅         | Retrieve, Grant, Revoke                 |         |
| **Resources**                             | ❌         | -                                       |         |
| **Entitlement Import: Accounts**          | ✅         | -                                       |         |
| **Entitlement Import: Permissions**       | ✅         | -                                       |         |
| **Governance Reconciliation Resolutions** | ✅         | -                                       |         |

## Getting started

### HelloID Icon URL
URL of the icon used for the HelloID Provisioning target system.
```
https://raw.githubusercontent.com/Tools4everBV/HelloID-Conn-Prov-Target-ActiveDirectory/refs/heads/main/Icon.png
```

### Requirements
- An local agent is required for this connector. It only works when there is a local connection to the API and therefore does not function with the cloud agent.
- The connector uses the `ExternalId` property for correlation. Make sure this property is populated for existing users so the connector can function properly.

### Connection settings

The following settings are required to connect to the API.

| Setting | Description        | Mandatory |
| ------- | ------------------ | --------- |
| BaseUrl | The URL to the API | Yes       |

### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _EAL-ATS360_ to a person in _HelloID_.

| Setting                   | Value        |
| ------------------------- | ------------ |
| Enable correlation        | `True`       |
| Person correlation field  | `ExternalId` |
| Account correlation field | `externalId` |

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

### Field mapping

The field mapping can be imported by using the _fieldMapping.json_ file.

### Account Reference

The account reference is populated with the property `id` property from _EAL-ATS360_

## Remarks

### No Authentication
- **No Authentication**: The connector was built and tested in an environment where the API did not require authentication.  
Because the API was only accessible within the environment’s internal network, no API authentication was implemented in the connector.  
However, according to the API documentation, it is possible to implement authentication if required.

### Mandatory property
- **LastName**: The property lastName is a mandatory property when creating or updating a user.

### No get user API request
- **Use Filters instead**: The API does not provide a request to retrieve a user by ID. Instead, it allows you to retrieve users using a filter.

### Grant permission
- **Empty body**: The API requires a body in the grant-permission POST request, but it can be left empty. The only fields it supports are start and expiration dates which are managed by HelloID.

### Mapping logic
- **Different property names**: The API uses different property names for the name-prefix field. In **PUT** and **PATCH** requests it is called `middleName`, while in **GET** responses it is returned as `insertion`. Because of this, additional logic is included in `create.ps1`, `update.ps1` and `import.ps1`.

- **Import accounts**: The data used during testing may not be representative of all environments. During development, the externalId property was empty for most existing users, and this was taken into account in the import script.


## Development resources

### API endpoints

The following endpoints are used by the connector

| Endpoint                                                                                                  | Description                           |
| --------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| /v1.1/BadgeHolder?$filter=externalID eq ':externalId'                                                     | Retrieve user information with filter |
| /v1.1/BadgeHolder?$filter=id eq ':id'                                                                     | Retrieve user information with filter |
| /v1.1/BadgeHolder?$top=':pageSize'&$skip=':skip'&$count=true                                              | Get all users paginated               |
| /v1.1/BadgeHolder/Import?keyField=':keyField'&keyValue=':keyValue'&badgeHolderTypeId=':badgeHolderTypeId' | Create user                           |
| /v1.1/BadgeHolder/Import?keyField=':keyField'&keyValue=':keyValue'                                        | Update user                           |
| /v1.1/BadgeHolder(':id')                                                                                  | Delete user                           |
| /v1.1/BadgeHolder(':id')/DoorProfiles?profileId=':permissionId'                                           | grant and revoke permissions          |
| /v1.1/DoorProfile?$top=$(':pageSize')&$skip=$(':skip')&$count=true                                        | Get all doorProfile permissions       |
| /v1.1/BadgeHolder(':id')/DoorProfiles                                                                     | Get doorProfile permissions for user  |

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]
>  _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com/forum/helloid-connectors/provisioning/5383-helloid-conn-prov-target-eal-ats360)_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/

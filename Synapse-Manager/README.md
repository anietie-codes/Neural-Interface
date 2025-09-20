# Brain-Computer Interface Management Smart Contract

## Overview

This smart contract provides a comprehensive management system for Brain-Computer Interface (BCI) devices on the Stacks blockchain. It handles device registration, data storage, user permissions, and research access while maintaining strict security and privacy controls.

## Features

- **Device Management**: Register and manage BCI devices with status tracking
- **Permission System**: Granular access control with multiple permission levels
- **Neural Data Storage**: Secure storage of encrypted neural data with quality scoring
- **Research Access**: Controlled access for authorized researchers
- **Emergency Controls**: Emergency access modes for critical situations
- **Analytics**: Device performance and usage analytics
- **Data Retention**: Configurable data retention policies

## Constants

### Error Codes
- `ERR_UNAUTHORIZED (100)`: Unauthorized access attempt
- `ERR_DEVICE_NOT_FOUND (101)`: Device not found in registry
- `ERR_DEVICE_ALREADY_EXISTS (102)`: Device already registered
- `ERR_INVALID_DEVICE_TYPE (103)`: Invalid device type specified
- `ERR_INVALID_DATA_TYPE (104)`: Invalid data type specified
- `ERR_INSUFFICIENT_PERMISSIONS (105)`: User lacks required permissions
- `ERR_DEVICE_OFFLINE (106)`: Device is offline or inactive
- `ERR_DATA_RETENTION_EXPIRED (107)`: Data retention period expired
- `ERR_INVALID_RESEARCHER (108)`: Researcher not authorized
- `ERR_RESEARCH_ACCESS_DENIED (109)`: Research access denied
- `ERR_EMERGENCY_ACCESS_ONLY (110)`: Emergency access required
- `ERR_INVALID_INPUT (111)`: Invalid input parameters

### Device Status
- `DEVICE_STATUS_ACTIVE (1)`: Device is active and operational
- `DEVICE_STATUS_INACTIVE (2)`: Device is inactive
- `DEVICE_STATUS_MAINTENANCE (3)`: Device under maintenance
- `DEVICE_STATUS_EMERGENCY (4)`: Device in emergency mode

### Data Types
- `DATA_TYPE_NEURAL (1)`: Neural activity data
- `DATA_TYPE_MOTOR (2)`: Motor control data
- `DATA_TYPE_SENSORY (3)`: Sensory input data
- `DATA_TYPE_COGNITIVE (4)`: Cognitive function data

### Permission Levels
- `PERMISSION_OWNER (100)`: Full device ownership
- `PERMISSION_EMERGENCY (75)`: Emergency access
- `PERMISSION_MEDICAL (50)`: Medical professional access
- `PERMISSION_RESEARCHER (25)`: Research access

## Public Functions

### Device Management

#### `register-bci-device`
Registers a new BCI device in the system.

**Parameters:**
- `device-id` (string-ascii 64): Unique device identifier
- `device-type` (uint): Type of BCI device (1-10)
- `encryption-key` (string-ascii 128): Device encryption key
- `firmware-version` (string-ascii 32): Current firmware version

**Returns:** `(ok true)` on success

#### `update-device-status`
Updates the operational status of a device.

**Parameters:**
- `device-id` (string-ascii 64): Device identifier
- `new-status` (uint): New status (1-4)

**Requires:** Medical-level permissions or ownership

#### `device-heartbeat`
Updates the last heartbeat timestamp for a device.

**Parameters:**
- `device-id` (string-ascii 64): Device identifier

**Requires:** Device ownership

### Permission Management

#### `grant-device-permission`
Grants access permissions to a user for a specific device.

**Parameters:**
- `device-id` (string-ascii 64): Device identifier
- `user` (principal): User to grant permissions to
- `permission-level` (uint): Permission level (1-100)
- `expires-at` (optional uint): Optional expiration block
- `data-types-allowed` (list 10 uint): Allowed data types

**Requires:** Device ownership

#### `revoke-device-permission`
Revokes access permissions from a user.

**Parameters:**
- `device-id` (string-ascii 64): Device identifier
- `user` (principal): User to revoke permissions from

**Requires:** Device ownership

### Data Management

#### `store-neural-data`
Stores encrypted neural data from a BCI device.

**Parameters:**
- `device-id` (string-ascii 64): Device identifier
- `data-type` (uint): Type of neural data (1-4)
- `data-hash` (string-ascii 128): Hash of the data
- `encrypted-data` (string-ascii 1024): Encrypted data payload
- `quality-score` (uint): Data quality score (0-100)

**Requires:** Medical-level permissions and active device status

#### `get-neural-data`
Retrieves stored neural data.

**Parameters:**
- `device-id` (string-ascii 64): Device identifier
- `timestamp` (uint): Block height when data was stored

**Requires:** Researcher-level permissions
**Returns:** Neural data entry

### Research Access

#### `authorize-researcher`
Authorizes a researcher for system access.

**Parameters:**
- `researcher` (principal): Researcher's principal
- `institution` (string-ascii 128): Research institution
- `research-area` (string-ascii 256): Area of research
- `clearance-level` (uint): Clearance level
- `expires-at` (uint): Authorization expiration

**Requires:** Contract ownership

#### `request-research-access`
Requests temporary access to device data for research.

**Parameters:**
- `device-id` (string-ascii 64): Device identifier
- `data-types` (list 10 uint): Required data types
- `purpose` (string-ascii 256): Research purpose

**Requires:** Authorized researcher status

### Emergency Functions

#### `emergency-access`
Activates emergency access to a device.

**Parameters:**
- `device-id` (string-ascii 64): Device identifier

**Requires:** Emergency mode activation and emergency permissions

#### `toggle-emergency-mode`
Toggles the contract's emergency mode.

**Requires:** Contract ownership

### Administrative Functions

#### `pause-contract` / `unpause-contract`
Pauses or unpauses contract operations.

**Requires:** Contract ownership

#### `update-data-retention-days`
Updates the data retention period.

**Parameters:**
- `new-days` (uint): New retention period (30-365 days)

**Requires:** Contract ownership

#### `update-min-quality-score`
Updates the minimum required quality score for data storage.

**Parameters:**
- `new-score` (uint): New minimum score (0-100)

**Requires:** Contract ownership

## Read-Only Functions

### `get-device-info`
Returns device information for a given device ID.

### `get-user-permissions`
Returns permission information for a user-device pair.

### `get-device-analytics`
Returns analytics data for a device.

### `get-researcher-info`
Returns information about an authorized researcher.

### `is-contract-paused`
Returns the contract's pause status.

### `is-emergency-mode`
Returns the emergency mode status.

### `get-data-retention-days`
Returns the current data retention period.

### `get-min-quality-score`
Returns the minimum quality score requirement.

### `check-device-authorization`
Checks if a user is authorized to access a device.

## Data Structures

### BCI Device
```
{
    owner: principal,
    device-type: uint,
    status: uint,
    last-heartbeat: uint,
    encryption-key: string-ascii 128,
    firmware-version: string-ascii 32,
    created-at: uint,
    updated-at: uint
}
```

### User Permissions
```
{
    permission-level: uint,
    granted-by: principal,
    granted-at: uint,
    expires-at: optional uint,
    data-types-allowed: list 10 uint
}
```

### Neural Data
```
{
    data-type: uint,
    data-hash: string-ascii 128,
    encrypted-data: string-ascii 1024,
    quality-score: uint,
    created-by: principal,
    retention-until: uint
}
```

## Security Features

- **Input Validation**: All inputs are validated for format and constraints
- **Permission Checks**: Multi-level permission system with expiration
- **Data Encryption**: All neural data is stored encrypted
- **Emergency Controls**: Emergency access modes for critical situations
- **Audit Trail**: All actions are logged with events
- **Data Retention**: Automatic data expiration based on retention policies
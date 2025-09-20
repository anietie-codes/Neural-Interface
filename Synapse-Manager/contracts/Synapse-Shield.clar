;; Brain-Computer Interface Management Smart Contract
;; This contract manages BCI device registration, data access, and user permissions

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_DEVICE_NOT_FOUND (err u101))
(define-constant ERR_DEVICE_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_DEVICE_TYPE (err u103))
(define-constant ERR_INVALID_DATA_TYPE (err u104))
(define-constant ERR_INSUFFICIENT_PERMISSIONS (err u105))
(define-constant ERR_DEVICE_OFFLINE (err u106))
(define-constant ERR_DATA_RETENTION_EXPIRED (err u107))
(define-constant ERR_INVALID_RESEARCHER (err u108))
(define-constant ERR_RESEARCH_ACCESS_DENIED (err u109))
(define-constant ERR_EMERGENCY_ACCESS_ONLY (err u110))
(define-constant ERR_INVALID_INPUT (err u111))

;; Device status constants
(define-constant DEVICE_STATUS_ACTIVE u1)
(define-constant DEVICE_STATUS_INACTIVE u2)
(define-constant DEVICE_STATUS_MAINTENANCE u3)
(define-constant DEVICE_STATUS_EMERGENCY u4)

;; Data types
(define-constant DATA_TYPE_NEURAL u1)
(define-constant DATA_TYPE_MOTOR u2)
(define-constant DATA_TYPE_SENSORY u3)
(define-constant DATA_TYPE_COGNITIVE u4)

;; Permission levels
(define-constant PERMISSION_OWNER u100)
(define-constant PERMISSION_MEDICAL u50)
(define-constant PERMISSION_RESEARCHER u25)
(define-constant PERMISSION_EMERGENCY u75)

;; Data Maps
(define-map bci-devices 
    { device-id: (string-ascii 64) }
    {
        owner: principal,
        device-type: uint,
        status: uint,
        last-heartbeat: uint,
        encryption-key: (string-ascii 128),
        firmware-version: (string-ascii 32),
        created-at: uint,
        updated-at: uint
    }
)

(define-map user-permissions
    { user: principal, device-id: (string-ascii 64) }
    {
        permission-level: uint,
        granted-by: principal,
        granted-at: uint,
        expires-at: (optional uint),
        data-types-allowed: (list 10 uint)
    }
)

(define-map neural-data
    { device-id: (string-ascii 64), timestamp: uint }
    {
        data-type: uint,
        data-hash: (string-ascii 128),
        encrypted-data: (string-ascii 1024),
        quality-score: uint,
        created-by: principal,
        retention-until: uint
    }
)

(define-map authorized-researchers
    { researcher: principal }
    {
        institution: (string-ascii 128),
        research-area: (string-ascii 256),
        clearance-level: uint,
        authorized-by: principal,
        authorized-at: uint,
        expires-at: uint
    }
)

(define-map device-analytics
    { device-id: (string-ascii 64) }
    {
        total-data-points: uint,
        last-data-timestamp: uint,
        average-quality-score: uint,
        uptime-percentage: uint,
        maintenance-count: uint
    }
)

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var emergency-mode bool false)
(define-data-var data-retention-days uint u90)
(define-data-var min-quality-score uint u70)

;; Private Functions
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (validate-principal (user principal))
    (not (is-eq user 'SP000000000000000000002Q6VF78))
)

(define-private (validate-optional-uint (value (optional uint)))
    (match value
        some-val (> some-val u0)
        true
    )
)

(define-private (validate-uint (value uint))
    (>= value u0)
)

(define-private (validate-device-id (device-id (string-ascii 64)))
    (and 
        (> (len device-id) u0)
        (<= (len device-id) u64)
    )
)

(define-private (validate-string-input (input (string-ascii 1024)) (max-len uint))
    (and 
        (> (len input) u0)
        (<= (len input) max-len)
    )
)

(define-private (validate-data-types-list (data-types (list 10 uint)))
    (fold check-data-type data-types true)
)

(define-private (check-data-type (data-type uint) (acc bool))
    (and acc (is-valid-data-type data-type))
)

(define-private (is-authorized-for-device (device-id (string-ascii 64)) (required-permission uint))
    (let ((device-data (unwrap! (map-get? bci-devices { device-id: device-id }) false))
          (permission-data (map-get? user-permissions { user: tx-sender, device-id: device-id })))
        (or 
            (is-eq tx-sender (get owner device-data))
            (match permission-data
                permission-info
                (and 
                    (>= (get permission-level permission-info) required-permission)
                    (match (get expires-at permission-info)
                        expires-time (> expires-time stacks-block-height)
                        true
                    )
                )
                false
            )
        )
    )
)

(define-private (is-valid-device-type (device-type uint))
    (and (>= device-type u1) (<= device-type u10))
)

(define-private (is-valid-data-type (data-type uint))
    (or 
        (is-eq data-type DATA_TYPE_NEURAL)
        (is-eq data-type DATA_TYPE_MOTOR)
        (is-eq data-type DATA_TYPE_SENSORY)
        (is-eq data-type DATA_TYPE_COGNITIVE)
    )
)

(define-private (calculate-retention-expiry)
    (+ stacks-block-height (* (var-get data-retention-days) u144))
)

(define-private (update-device-analytics (device-id (string-ascii 64)) (quality-score uint))
    (let ((current-analytics (default-to 
            { 
                total-data-points: u0, 
                last-data-timestamp: u0, 
                average-quality-score: u0,
                uptime-percentage: u100,
                maintenance-count: u0 
            } 
            (map-get? device-analytics { device-id: device-id }))))
        (map-set device-analytics
            { device-id: device-id }
            (merge current-analytics
                {
                    total-data-points: (+ (get total-data-points current-analytics) u1),
                    last-data-timestamp: stacks-block-height,
                    average-quality-score: (/ 
                        (+ (* (get average-quality-score current-analytics) (get total-data-points current-analytics)) quality-score)
                        (+ (get total-data-points current-analytics) u1)
                    )
                }
            )
        )
    )
)

;; Public Functions
(define-public (register-bci-device 
    (device-id (string-ascii 64))
    (device-type uint)
    (encryption-key (string-ascii 128))
    (firmware-version (string-ascii 32)))
    (begin
        (asserts! (validate-device-id device-id) ERR_INVALID_INPUT)
        (asserts! (validate-string-input encryption-key u128) ERR_INVALID_INPUT)
        (asserts! (validate-string-input firmware-version u32) ERR_INVALID_INPUT)
        (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
        (asserts! (is-none (map-get? bci-devices { device-id: device-id })) ERR_DEVICE_ALREADY_EXISTS)
        (asserts! (is-valid-device-type device-type) ERR_INVALID_DEVICE_TYPE)
        
        (map-set bci-devices 
            { device-id: device-id }
            {
                owner: tx-sender,
                device-type: device-type,
                status: DEVICE_STATUS_ACTIVE,
                last-heartbeat: stacks-block-height,
                encryption-key: encryption-key,
                firmware-version: firmware-version,
                created-at: stacks-block-height,
                updated-at: stacks-block-height
            }
        )
        
        (map-set device-analytics
            { device-id: device-id }
            {
                total-data-points: u0,
                last-data-timestamp: stacks-block-height,
                average-quality-score: u0,
                uptime-percentage: u100,
                maintenance-count: u0
            }
        )
        
        (print { event: "device-registered", device-id: device-id, owner: tx-sender })
        (ok true)
    )
)

(define-public (update-device-status (device-id (string-ascii 64)) (new-status uint))
    (begin
        (asserts! (validate-device-id device-id) ERR_INVALID_INPUT)
        (let ((device-data (unwrap! (map-get? bci-devices { device-id: device-id }) ERR_DEVICE_NOT_FOUND)))
            (asserts! (is-authorized-for-device device-id PERMISSION_MEDICAL) ERR_INSUFFICIENT_PERMISSIONS)
            (asserts! (<= new-status u4) ERR_UNAUTHORIZED)
            
            (map-set bci-devices 
                { device-id: device-id }
                (merge device-data { status: new-status, updated-at: stacks-block-height })
            )
            
            (if (is-eq new-status DEVICE_STATUS_MAINTENANCE)
                (let ((current-analytics (unwrap! (map-get? device-analytics { device-id: device-id }) ERR_DEVICE_NOT_FOUND)))
                    (map-set device-analytics
                        { device-id: device-id }
                        (merge current-analytics
                            { maintenance-count: (+ (get maintenance-count current-analytics) u1) }
                        )
                    )
                )
                true
            )
            
            (print { event: "device-status-updated", device-id: device-id, new-status: new-status })
            (ok true)
        )
    )
)

(define-public (device-heartbeat (device-id (string-ascii 64)))
    (begin
        (asserts! (validate-device-id device-id) ERR_INVALID_INPUT)
        (let ((device-data (unwrap! (map-get? bci-devices { device-id: device-id }) ERR_DEVICE_NOT_FOUND)))
            (asserts! (is-eq tx-sender (get owner device-data)) ERR_UNAUTHORIZED)
            
            (map-set bci-devices 
                { device-id: device-id }
                (merge device-data { last-heartbeat: stacks-block-height, updated-at: stacks-block-height })
            )
            
            (ok true)
        )
    )
)

(define-public (grant-device-permission
    (device-id (string-ascii 64))
    (user principal)
    (permission-level uint)
    (expires-at (optional uint))
    (data-types-allowed (list 10 uint)))
    (begin
        (asserts! (validate-device-id device-id) ERR_INVALID_INPUT)
        (asserts! (validate-principal user) ERR_INVALID_INPUT)
        (asserts! (validate-optional-uint expires-at) ERR_INVALID_INPUT)
        (asserts! (validate-data-types-list data-types-allowed) ERR_INVALID_INPUT)
        (let ((device-data (unwrap! (map-get? bci-devices { device-id: device-id }) ERR_DEVICE_NOT_FOUND)))
            (asserts! (is-eq tx-sender (get owner device-data)) ERR_UNAUTHORIZED)
            (asserts! (<= permission-level PERMISSION_OWNER) ERR_UNAUTHORIZED)
            
            (map-set user-permissions
                { user: user, device-id: device-id }
                {
                    permission-level: permission-level,
                    granted-by: tx-sender,
                    granted-at: stacks-block-height,
                    expires-at: expires-at,
                    data-types-allowed: data-types-allowed
                }
            )
            
            (print { event: "permission-granted", device-id: device-id, user: user, permission-level: permission-level })
            (ok true)
        )
    )
)

(define-public (revoke-device-permission (device-id (string-ascii 64)) (user principal))
    (begin
        (asserts! (validate-device-id device-id) ERR_INVALID_INPUT)
        (asserts! (validate-principal user) ERR_INVALID_INPUT)
        (let ((device-data (unwrap! (map-get? bci-devices { device-id: device-id }) ERR_DEVICE_NOT_FOUND)))
            (asserts! (is-eq tx-sender (get owner device-data)) ERR_UNAUTHORIZED)
            
            (map-delete user-permissions { user: user, device-id: device-id })
            (print { event: "permission-revoked", device-id: device-id, user: user })
            (ok true)
        )
    )
)

(define-public (store-neural-data
    (device-id (string-ascii 64))
    (data-type uint)
    (data-hash (string-ascii 128))
    (encrypted-data (string-ascii 1024))
    (quality-score uint))
    (begin
        (asserts! (validate-device-id device-id) ERR_INVALID_INPUT)
        (asserts! (validate-string-input data-hash u128) ERR_INVALID_INPUT)
        (asserts! (validate-string-input encrypted-data u1024) ERR_INVALID_INPUT)
        (let ((device-data (unwrap! (map-get? bci-devices { device-id: device-id }) ERR_DEVICE_NOT_FOUND)))
            (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
            (asserts! (is-authorized-for-device device-id PERMISSION_MEDICAL) ERR_INSUFFICIENT_PERMISSIONS)
            (asserts! (is-valid-data-type data-type) ERR_INVALID_DATA_TYPE)
            (asserts! (is-eq (get status device-data) DEVICE_STATUS_ACTIVE) ERR_DEVICE_OFFLINE)
            (asserts! (>= quality-score (var-get min-quality-score)) ERR_UNAUTHORIZED)
            
            (map-set neural-data
                { device-id: device-id, timestamp: stacks-block-height }
                {
                    data-type: data-type,
                    data-hash: data-hash,
                    encrypted-data: encrypted-data,
                    quality-score: quality-score,
                    created-by: tx-sender,
                    retention-until: (calculate-retention-expiry)
                }
            )
            
            (update-device-analytics device-id quality-score)
            
            (print { event: "neural-data-stored", device-id: device-id, data-type: data-type, quality-score: quality-score })
            (ok true)
        )
    )
)

(define-public (get-neural-data (device-id (string-ascii 64)) (timestamp uint))
    (begin
        (asserts! (validate-device-id device-id) ERR_INVALID_INPUT)
        (let ((data-entry (unwrap! (map-get? neural-data { device-id: device-id, timestamp: timestamp }) ERR_DEVICE_NOT_FOUND))
              (permission-check (is-authorized-for-device device-id PERMISSION_RESEARCHER)))
            (asserts! permission-check ERR_INSUFFICIENT_PERMISSIONS)
            (asserts! (> (get retention-until data-entry) stacks-block-height) ERR_DATA_RETENTION_EXPIRED)
            
            (ok data-entry)
        )
    )
)

(define-public (authorize-researcher
    (researcher principal)
    (institution (string-ascii 128))
    (research-area (string-ascii 256))
    (clearance-level uint)
    (expires-at uint))
    (begin
        (asserts! (validate-principal researcher) ERR_INVALID_INPUT)
        (asserts! (validate-string-input institution u128) ERR_INVALID_INPUT)
        (asserts! (validate-string-input research-area u256) ERR_INVALID_INPUT)
        (asserts! (validate-uint expires-at) ERR_INVALID_INPUT)
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (asserts! (<= clearance-level PERMISSION_RESEARCHER) ERR_UNAUTHORIZED)
        
        (map-set authorized-researchers
            { researcher: researcher }
            {
                institution: institution,
                research-area: research-area,
                clearance-level: clearance-level,
                authorized-by: tx-sender,
                authorized-at: stacks-block-height,
                expires-at: expires-at
            }
        )
        
        (print { event: "researcher-authorized", researcher: researcher, institution: institution })
        (ok true)
    )
)

(define-public (request-research-access
    (device-id (string-ascii 64))
    (data-types (list 10 uint))
    (purpose (string-ascii 256)))
    (begin
        (asserts! (validate-device-id device-id) ERR_INVALID_INPUT)
        (asserts! (validate-data-types-list data-types) ERR_INVALID_INPUT)
        (asserts! (validate-string-input purpose u256) ERR_INVALID_INPUT)
        (let ((researcher-data (unwrap! (map-get? authorized-researchers { researcher: tx-sender }) ERR_INVALID_RESEARCHER))
              (device-data (unwrap! (map-get? bci-devices { device-id: device-id }) ERR_DEVICE_NOT_FOUND)))
            (asserts! (> (get expires-at researcher-data) stacks-block-height) ERR_RESEARCH_ACCESS_DENIED)
            
            (map-set user-permissions
                { user: tx-sender, device-id: device-id }
                {
                    permission-level: PERMISSION_RESEARCHER,
                    granted-by: CONTRACT_OWNER,
                    granted-at: stacks-block-height,
                    expires-at: (some (+ stacks-block-height u1440)),
                    data-types-allowed: data-types
                }
            )
            
            (print { event: "research-access-granted", researcher: tx-sender, device-id: device-id, purpose: purpose })
            (ok true)
        )
    )
)

(define-public (emergency-access (device-id (string-ascii 64)))
    (begin
        (asserts! (validate-device-id device-id) ERR_INVALID_INPUT)
        (let ((device-data (unwrap! (map-get? bci-devices { device-id: device-id }) ERR_DEVICE_NOT_FOUND)))
            (asserts! (var-get emergency-mode) ERR_EMERGENCY_ACCESS_ONLY)
            (asserts! (or 
                (is-contract-owner)
                (is-authorized-for-device device-id PERMISSION_EMERGENCY)
            ) ERR_INSUFFICIENT_PERMISSIONS)
            
            (map-set bci-devices 
                { device-id: device-id }
                (merge device-data { status: DEVICE_STATUS_EMERGENCY, updated-at: stacks-block-height })
            )
            
            (print { event: "emergency-access-activated", device-id: device-id, accessor: tx-sender })
            (ok true)
        )
    )
)

(define-public (toggle-emergency-mode)
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (var-set emergency-mode (not (var-get emergency-mode)))
        (print { event: "emergency-mode-toggled", status: (var-get emergency-mode) })
        (ok (var-get emergency-mode))
    )
)

(define-public (pause-contract)
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (var-set contract-paused true)
        (print { event: "contract-paused" })
        (ok true)
    )
)

(define-public (unpause-contract)
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (var-set contract-paused false)
        (print { event: "contract-unpaused" })
        (ok true)
    )
)

(define-public (update-data-retention-days (new-days uint))
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (asserts! (and (>= new-days u30) (<= new-days u365)) ERR_UNAUTHORIZED)
        (var-set data-retention-days new-days)
        (print { event: "data-retention-updated", new-days: new-days })
        (ok true)
    )
)

(define-public (update-min-quality-score (new-score uint))
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (asserts! (<= new-score u100) ERR_UNAUTHORIZED)
        (var-set min-quality-score new-score)
        (print { event: "min-quality-score-updated", new-score: new-score })
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-device-info (device-id (string-ascii 64)))
    (if (validate-device-id device-id)
        (map-get? bci-devices { device-id: device-id })
        none
    )
)

(define-read-only (get-user-permissions (user principal) (device-id (string-ascii 64)))
    (if (and (validate-principal user) (validate-device-id device-id))
        (map-get? user-permissions { user: user, device-id: device-id })
        none
    )
)

(define-read-only (get-device-analytics (device-id (string-ascii 64)))
    (if (validate-device-id device-id)
        (map-get? device-analytics { device-id: device-id })
        none
    )
)

(define-read-only (get-researcher-info (researcher principal))
    (map-get? authorized-researchers { researcher: researcher })
)

(define-read-only (is-contract-paused)
    (var-get contract-paused)
)

(define-read-only (is-emergency-mode)
    (var-get emergency-mode)
)

(define-read-only (get-data-retention-days)
    (var-get data-retention-days)
)

(define-read-only (get-min-quality-score)
    (var-get min-quality-score)
)

(define-read-only (check-device-authorization (device-id (string-ascii 64)) (user principal))
    (if (and (validate-device-id device-id) (validate-principal user))
        (let ((device-data (map-get? bci-devices { device-id: device-id }))
              (permission-data (map-get? user-permissions { user: user, device-id: device-id })))
            (match device-data
                device-info
                (or 
                    (is-eq user (get owner device-info))
                    (match permission-data
                        permission-info
                        (match (get expires-at permission-info)
                            expires-time (> expires-time stacks-block-height)
                            true
                        )
                        false
                    )
                )
                false
            )
        )
        false
    )
)
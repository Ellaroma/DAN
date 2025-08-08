# Decentralized API Network - On-Chain Service Marketplace

A decentralized blockchain-based platform for API services and data feeds, built on the Stacks blockchain using Clarity smart contracts.

## Overview

The Decentralized API Network enables developers to monetize their APIs while providing users with reliable, transparent access to various services including data feeds, compute resources, storage solutions, and oracles. All transactions and service management occur on-chain, ensuring transparency and eliminating intermediaries.

## Features

### For API Providers
- **Service Deployment**: Register and configure API services on-chain
- **Flexible Pricing**: Set both per-call and bulk package pricing
- **Revenue Management**: Automatic earnings calculation and withdrawal
- **Service Control**: Update configurations and toggle service availability
- **Performance Tracking**: Monitor total calls and revenue metrics

### For API Consumers
- **Multiple Payment Options**: Choose between per-call credits or bulk packages
- **Subscription Management**: Track active subscriptions and remaining credits
- **Service Discovery**: Browse available services by category
- **Review System**: Rate and review services for community feedback
- **Access Control**: Secure, authenticated API calls

### Network Features
- **Decentralized Governance**: Network-wide fee management
- **Transparent Fee Structure**: 1.5% default network fee
- **Service Categories**: Organized by type (data-feed, compute, storage, oracle)
- **IPFS Integration**: Decentralized storage for API documentation

## Service Categories

- **Data Feed**: Real-time data streams and market information
- **Compute**: Processing and computational services  
- **Storage**: Decentralized file and data storage
- **Oracle**: External data integration for smart contracts

## Smart Contract Functions

### Service Management

#### `deploy-service`
Register a new API service on the network.

```clarity
(deploy-service service-key service-title service-info api-category per-call-price bulk-package-price endpoint-hash)
```

**Parameters:**
- `service-key`: Unique 40-character ASCII identifier
- `service-title`: Service name (max 120 UTF-8 characters)
- `service-info`: Detailed description (max 600 UTF-8 characters)
- `api-category`: Service type (max 28 ASCII characters)
- `per-call-price`: Cost per individual API call (in microSTX)
- `bulk-package-price`: Cost for bulk subscription (in microSTX)
- `endpoint-hash`: IPFS hash for API documentation (64 ASCII characters)

#### `update-service-config`
Modify existing service configuration (provider only).

```clarity
(update-service-config service-key service-title service-info per-call-price bulk-package-price endpoint-hash is-active)
```

### Payment & Subscriptions

#### `purchase-bulk-package`
Buy unlimited access for a fixed period (60 days).

```clarity
(purchase-bulk-package service-key)
```

#### `buy-call-credits`
Purchase specific number of API call credits.

```clarity
(buy-call-credits service-key call-count)
```

#### `make-api-call`
Execute an API call (consumes credits or validates subscription).

```clarity
(make-api-call service-key)
```

### Provider Functions

#### `withdraw-provider-earnings`
Withdraw accumulated earnings from service usage.

```clarity
(withdraw-provider-earnings)
```

### Review System

#### `review-service`
Submit a rating and review for a service.

```clarity
(review-service service-key quality-rating review-text)
```

**Parameters:**
- `quality-rating`: 1-5 star rating
- `review-text`: Review content (max 450 UTF-8 characters)

### Read-Only Functions

#### `get-service`
Retrieve complete service information.

#### `get-subscription`
Check subscription status and remaining credits.

#### `get-service-review`
Fetch review for a specific service and client.

#### `get-provider-earnings`
Check accumulated earnings for a provider.

#### `can-access-service`
Verify if a client can access a specific service.

## Getting Started

### Prerequisites
- Stacks wallet with STX tokens
- Access to Stacks blockchain testnet/mainnet

### Deploying a Service

1. **Prepare Service Information**
   - Create unique service key (40 characters)
   - Write compelling service title and description
   - Determine pricing strategy
   - Upload API documentation to IPFS

2. **Deploy Contract Function**
   ```clarity
   (deploy-service 
     "my-weather-api-v1" 
     "Real-time Weather Data API" 
     "Provides current weather conditions and forecasts for global locations with high accuracy and low latency"
     "data-feed"
     u1000    ;; 0.001 STX per call
     u100000  ;; 0.1 STX bulk package
     "QmX4k5h2n8P9r6Y1mW3vB7zQ8sL2fD6jK9nM1xC5qA7wE9t"
   )
   ```

### Purchasing Access

1. **For Per-Call Usage**
   ```clarity
   (buy-call-credits "my-weather-api-v1" u100)  ;; Buy 100 API calls
   ```

2. **For Bulk Access**
   ```clarity
   (purchase-bulk-package "my-weather-api-v1")  ;; 60 days unlimited
   ```

### Making API Calls

```clarity
(make-api-call "my-weather-api-v1")
```

## Economic Model

- **Network Fee**: 1.5% of all transactions (configurable by network owner)
- **Provider Revenue**: 98.5% of service payments
- **Payment Methods**: STX tokens
- **Subscription Types**: 
  - Per-call: Pay for individual API requests
  - Bulk package: Fixed-price unlimited access (60 days)

## Error Codes

- `u400`: Owner access only
- `u401`: Service not available
- `u402`: Unauthorized access
- `u403`: Payment insufficient
- `u404`: Service already exists
- `u405`: Invalid input parameters

## Network Governance

The network owner can adjust the network fee percentage (maximum 10%) through the `set-network-fee` function, ensuring sustainable platform operation while maintaining competitive pricing.

## Security Features

- **Access Control**: Service providers control their offerings
- **Payment Validation**: Automatic payment verification before service access
- **Subscription Management**: Secure credit tracking and validation
- **Review System**: Community-driven service quality assessment

## Future Enhancements

- Multi-token payment support
- Advanced subscription tiers
- API rate limiting
- Service discovery improvements
- Integration with external oracle networks

## Contributing

This project is open for community contributions. Areas of focus include:
- Frontend development for service marketplace
- Integration tools and SDKs
- Documentation improvements
- Security audits and testing

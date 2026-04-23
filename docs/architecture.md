# System Architecture

## Overview
This document describes the system architecture of Nirdist Messenger, covering the frontend, backend, infrastructure, and data flow.

## High-Level Architecture

### Component Diagram
```
[Flutter Mobile App] 
        ↓ (HTTPS/WSS)
[Cloudflare CDN/DNS] 
        ↓ (HTTPS/WSS)
[Render.com Load Balancer] 
        ↓ (HTTP/WS)
[Spring Boot Application] 
        ↓ (JDBC)
[PostgreSQL Database]
        ↓
[Cloudflare R2 Storage] (Media)
        ↓
[Firebase Cloud Messaging] (Push Notifications)
        ↓
[STUN/TURN Servers] (WebRTC)
```

### Technology Layers

#### Presentation Layer
- Flutter mobile application (Android-first)
- Responsive UI with adaptive layouts
- Platform-specific implementations where needed

#### Application Layer
- RESTful API endpoints
- WebSocket/STOMP connections for real-time features
- JWT-based authentication and authorization
- Business logic services

#### Data Layer
- PostgreSQL relational database
- JPA/Hibernate ORM for data access
- Connection pooling for performance
- Database migrations with Flyway

#### Infrastructure Layer
- Docker containerization
- Render.com hosting platform
- Cloudflare for CDN, DNS, and DDoS protection
- Monitoring and logging systems

## Data Flow

### User Authentication Flow
1. User enters phone number in Flutter app
2. App requests OTP via Firebase Authentication
3. Firebase sends OTP to user's phone
4. User enters OTP in app
5. App verifies OTP with Firebase
6. App sends verified phone number to backend
7. Backend creates/finds user profile
8. Backend generates JWT access and refresh tokens
9. Tokens stored securely in Flutter secure storage
10. Subsequent requests include JWT in Authorization header

### Message Sending Flow
1. User composes message in Flutter chat UI
2. App sends message to WebSocket endpoint (/app/chat.send)
3. Spring Boot WebSocket handler receives message
4. Handler validates JWT and user permissions
5. Message persisted to chat_message table
6. Spring Boot broadcasts message to room topic (/topic/room.{id})
7. All subscribed clients receive message via WebSocket
8. Push notification sent via FCM for offline users

### Media Upload Flow
1. User selects media file in app
2. App requests presigned upload URL from backend (/media/presign)
3. Backend generates time-limited presigned URL for Cloudflare R2
4. App uploads file directly to R2 using presigned URL
5. App receives confirmation of successful upload
6. Backend stores media URL in database
7. Media served via Cloudflare CDN with caching

### WebRTC Call Flow
1. Caller initiates call in Flutter app
2. App sends offer via WebSocket (/app/webrtc.offer)
3. Signaling server relays offer to callee
4. Callee sends answer via WebSocket (/app/webrtc.answer)
5. ICE candidates exchanged via WebSocket (/app/webrtc.ice)
6. Direct peer-to-peer connection established
7. Media flows directly between clients (with TURN fallback)
8. Call events logged to database for history

## Security Architecture

### Authentication & Authorization
- JWT tokens for stateless authentication
- Refresh token rotation for security
- Passwords hashed with bcrypt
- OTP verification via Firebase Phone Auth
- Role-based access control (RBAC) for admin features

### Data Protection
- TLS encryption for all client-server communications
- Field-level encryption for sensitive data (planned)
- Regular security audits and penetration testing
- GDPR compliance for user data handling

### Network Security
- Cloudflare WAF and DDoS protection
- Rate limiting on API endpoints
- Input validation and sanitization
- SQL injection prevention via ORM
- CORS policies configured appropriately

## Scalability Considerations

### Horizontal Scaling
- Stateless Spring Boot services enable easy scaling
- Database read replicas for query distribution
- Load balancing via Render.com
- CDN caching for static assets
- Redis caching for frequently accessed data

### Database Optimization
- Connection pooling with HikariCP
- Proper indexing strategies
- Query optimization and profiling
- Archive strategies for old data
- Partitioning for large tables (planned)

## Monitoring & Observability

### Logging
- Structured logging with correlation IDs
- Centralized log aggregation
- Error tracking with Sentry
- Audit trails for security-sensitive operations

### Metrics
- Prometheus metrics endpoints
- Grafana dashboards for visualization
- Business metrics (DAU, message volume, etc.)
- Infrastructure metrics (CPU, memory, disk, network)

### Health Checks
- Kubernetes-style liveness and readiness probes
- Database connectivity checks
- External service dependency checks
- Circuit breaker patterns for external calls

## Deployment Architecture

### Environments
- Development: Local Docker Compose
- Staging: Separate Render.com services
- Production: Render.com with auto-scaling

### CI/CD Pipeline
1. Code pushed to GitHub repository
2. GitHub Actions workflow triggered
3. Code linting and unit tests executed
4. Docker image built and pushed to registry
5. Render.com automatically deploys new image
6. Smoke tests run against deployed service
7. Rollback on failure detection

### Disaster Recovery
- Automated daily database backups
- Point-in-time recovery capabilities
- Cross-region replication (planned)
- Runbook procedures for common failure scenarios
- Chaos engineering for resilience testing

## Future Enhancements

### Planned Improvements
- Microservices decomposition for specific features
- Event-driven architecture with Kafka/RabbitMQ
- GraphQL API alongside REST
- Machine learning for content recommendations
- Offline-first capabilities with local sync
- End-to-end encryption for private conversations
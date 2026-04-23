# Backend Todo

## Started
- [x] Create the Spring Boot backend scaffold
- [x] Add a PostgreSQL Flyway migration for the core profile/chat tables
- [x] Add an in-memory chat cache service for recent messages
- [x] Add core profile/chat JPA entities and repositories
- [x] Add chat room/message service and REST endpoints
- [x] Wire the chat cache into WebSocket message handling
- [x] Add Firebase OTP verification exchange and JWT issuance
- [x] Add friend requests, contact sync, and communication permission checks
- [x] Convert the legacy SQL in `/db` into the backend Flyway migration set

## Next
- [x] Add Render deployment configuration and environment variable docs
- [x] Add integration tests for auth, friendship, contact sync, and chat flows
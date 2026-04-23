# Nirdist Messenger

A full-featured social messaging platform with stories, notes, real-time chat, and WebRTC calls. Built with Flutter frontend, Spring Boot backend, and PostgreSQL database.

## Overview

Nirdist Messenger is a cross-platform messaging application currently targeting Android, with planned expansions to web and iOS platforms. The application features:

- Real-time messaging with STOMP/WebSocket
- Stories with 24-hour expiry
- Notes (text/image/video posts)
- Reactions and commenting system
- Follow/follower social graph
- WebRTC voice and video calls
- Push notifications via FCM
- Media uploads and storage

## Tech Stack

### Frontend
- Flutter 3.x
- Riverpod/Bloc for state management
- STOMP/WebSocket for real-time communication
- flutter_webrtc for video calls
- JWT + Secure Storage for authentication

### Backend
- Spring Boot 3.x
- Java 21 / Kotlin
- PostgreSQL 16
- JPA/Hibernate ORM
- Spring Security + JWT

### Infrastructure
- Render.com hosting
- Cloudflare CDN/DNS
- Docker containers
- Cloudflare R2 for media storage (planned)
- Cloudflare TURN/coturn for WebRTC

## Documentation

Comprehensive documentation is available in the `/docs` directory:

- [Documentation Plan](docs/nirdist_messenger_documentation_plan.md)
- [Technical Architecture](docs/architecture.md)
- [API Reference](docs/api.md)
- [Database Schema](docs/database.md)
- [Deployment Guide](docs/deployment.md)
- [User Guides](docs/user-guides/)
- [Developer Guides](docs/developer-guides/)

## Getting Started

### Prerequisites
- JDK 21+
- Flutter 3.x
- PostgreSQL 16
- Docker & Docker Compose
- Firebase account (for OTP verification)
- Cloudflare account (for DNS/CDN)

### Backend Setup
1. Clone the repository
2. Navigate to the backend directory
3. Configure application properties:
   ```bash
   cp src/main/resources/application-template.yml src/main/resources/application.yml
   # Edit application.yml with your database credentials
   ```
4. Start PostgreSQL (using Docker or local installation)
5. Run database migrations:
   ```bash
   ./mvnw flyway:migrate
   ```
6. Start the application:
   ```bash
   ./mvnw spring-boot:run
   ```

### Frontend Setup
1. Navigate to the frontend directory
2. Get dependencies:
   ```bash
   flutter pub get
   ```
3. Configure Firebase for OTP verification (see [Firebase Setup Guide](docs/developer-guides/firebase-setup.md))
4. Run the app:
   ```bash
   flutter run
   ```

### Docker Deployment
1. Build the Docker image:
   ```bash
   docker build -t nirdist-messenger .
   ```
2. Start services with docker-compose:
   ```bash
   docker-compose up
   ```

## Contributing

Please read our [Contributing Guidelines](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

For questions and support, please open an issue in this repository or contact the maintainers.
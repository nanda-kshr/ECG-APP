# Saveetha Cardio App

A comprehensive Flutter application for ECG image management with role-based access control.

## Features

### 🔐 Authentication System
- Role-based login (User, Admin, Doctor)
- Secure session management
- Demo credentials available

### 👨‍⚕️ For Users
- Upload ECG images via camera or gallery
- Record voice notes for each image
- Add patient information
- View upload history and doctor responses

### 👩‍💼 For Administrators
- View all uploaded ECG images
- Assign doctors to specific cases
- Monitor system statistics
- Track completion status

### 🩺 For Doctors
- Review assigned ECG cases
- View images and listen to voice notes
- Provide diagnostic responses
- Track completed reviews

## Demo Credentials

| Role | Username | Password |
|------|----------|----------|
| User | tech1 | password |
| Admin | admin1 | password |
| Doctor | doc1 | password |

## Getting Started

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK
- Android Studio / VS Code
- Android/iOS device or emulator

### Installation

1. Clone the repository
2. Navigate to the project directory
3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Run the application:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── models/           # Data models
├── screens/          # UI screens
├── services/         # Business logic
├── widgets/          # Reusable components
└── main.dart        # App entry point
```

## Dependencies

- `image_picker`: Camera/gallery access
- `flutter_sound`: Audio recording
- `shared_preferences`: Local storage
- `permission_handler`: Device permissions

## Features Overview

### Clean Material Design
- Modern, intuitive interface
- Consistent design patterns
- Responsive layouts
- Proper color schemes

### Role-Based Navigation
- Automatic routing based on user role
- Secure logout functionality
- Session persistence

### Dummy Data Integration
- Pre-populated sample data
- Realistic user scenarios
- Complete workflow demonstration

## Usage

1. **Login**: Use demo credentials or create your own
2. **User Workflow**: Upload images → Record voice notes → Submit
3. **Admin Workflow**: Review submissions → Assign doctors → Monitor progress
4. **Doctor Workflow**: Review cases → Provide diagnosis → Complete reviews

## Future Enhancements

- Real backend integration
- Push notifications
- Advanced image analysis
- Report generation
- Multi-language support

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License.# ECG-APP
# ECG-BE

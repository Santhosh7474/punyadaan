import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized Cloudinary configuration.
/// Reads credentials from the `.env` file loaded at app startup.
class CloudinaryConfig {
  CloudinaryConfig._(); // Prevent instantiation

  static String get cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME']!;
  static String get apiKey => dotenv.env['CLOUDINARY_API_KEY']!;
  static String get apiSecret => dotenv.env['CLOUDINARY_API_SECRET']!;
}

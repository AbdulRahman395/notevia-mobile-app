import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class ApiService {
  static const String baseUrl = 'https://new-my-journals.vercel.app';

  // Handle 401 Unauthorized responses
  static Future<void> _handleUnauthorized() async {
    print('Handling 401 Unauthorized - clearing access token only');
    await TokenService.clearAccessToken();
    // Note: The page reload will be handled by the calling method
  }

  // Handle 401 for login token (clear both tokens)
  static Future<void> _handleLoginUnauthorized() async {
    print('Handling 401 Unauthorized - clearing all tokens');
    await TokenService.clearTokens();
    // Note: The page reload will be handled by the calling method
  }

  // Check if user has PIN
  static Future<Map<String, dynamic>> hasPin(String token) async {
    try {
      print('Checking if user has PIN with token: $token');

      final response = await http
          .get(
            Uri.parse('$baseUrl/pin/has-pin'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'User-Agent': 'Notevia-Flutter-App',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('Has PIN response status: ${response.statusCode}');
      print('Has PIN response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'PIN status checked successfully',
          'data': jsonDecode(response.body),
        };
      } else if (response.statusCode == 401) {
        await _handleLoginUnauthorized();
        return {
          'success': false,
          'message': 'Authentication expired. Please login again.',
          'requires_login_redirect': true,
        };
      } else {
        return {
          'success': false,
          'message':
              jsonDecode(response.body)['message'] ??
              'Failed to check PIN status',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('Has PIN ClientException: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection failed while checking PIN status',
        'error': e.toString(),
      };
    } catch (e) {
      print('Has PIN error: ${e.toString()}');
      return {
        'success': false,
        'message': 'PIN status check error: ${e.toString()}',
      };
    }
  }

  // Test method to check API connectivity
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'API server is reachable'};
      } else {
        return {
          'success': false,
          'message': 'API server returned status ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot reach API server: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      print('Attempting registration to: $baseUrl/auth/register');
      print(
        'Request body: ${jsonEncode({"name": name, "email": email, "passwordHash": password})}',
      );

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'Notevia-Flutter-App',
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
              'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
            body: jsonEncode({
              "name": name,
              "email": email,
              "passwordHash": password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Registration successful',
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message':
              jsonDecode(response.body)['message'] ?? 'Registration failed',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('ClientException: ${e.toString()}');

      // Try with a simpler request as fallback
      try {
        print('Trying fallback request...');
        final fallbackResponse = await http
            .post(
              Uri.parse('$baseUrl/auth/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                "name": name,
                "email": email,
                "passwordHash": password,
              }),
            )
            .timeout(const Duration(seconds: 10));

        print('Fallback response status: ${fallbackResponse.statusCode}');
        print('Fallback response body: ${fallbackResponse.body}');

        if (fallbackResponse.statusCode == 200 ||
            fallbackResponse.statusCode == 201) {
          return {
            'success': true,
            'message': 'Registration successful',
            'data': jsonDecode(fallbackResponse.body),
          };
        } else {
          return {
            'success': false,
            'message':
                jsonDecode(fallbackResponse.body)['message'] ??
                'Registration failed',
            'error': fallbackResponse.body,
          };
        }
      } catch (fallbackError) {
        print('Fallback also failed: ${fallbackError.toString()}');
        return {
          'success': false,
          'message':
              'Connection failed. The API server may not allow requests from this app. Please contact support.',
          'error': e.toString(),
        };
      }
    } catch (e) {
      print('General error: ${e.toString()}');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> verifyAccount(
    String email,
    String otp,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-account'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({"email": email, "otp": otp}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Account verified successfully',
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message':
              jsonDecode(response.body)['message'] ?? 'Verification failed',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'message':
            'Connection failed. Please check your internet connection and try again.',
        'error': e.toString(),
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Login successful',
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': jsonDecode(response.body)['message'] ?? 'Login failed',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'message':
            'Connection failed. Please check your internet connection and try again.',
        'error': e.toString(),
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> createPIN(
    String token,
    String pin,
  ) async {
    try {
      print('Creating PIN with token: $token');

      final response = await http
          .post(
            Uri.parse('$baseUrl/pin/create'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'User-Agent': 'Notevia-Flutter-App',
            },
            body: jsonEncode({"pin": pin}),
          )
          .timeout(const Duration(seconds: 15));

      print('Create PIN response status: ${response.statusCode}');
      print('Create PIN response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'PIN created successfully',
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message':
              jsonDecode(response.body)['message'] ?? 'PIN creation failed',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('Create PIN ClientException: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection failed while creating PIN',
        'error': e.toString(),
      };
    } catch (e) {
      print('Create PIN error: ${e.toString()}');
      return {
        'success': false,
        'message': 'PIN creation error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> verifyPIN(
    String token,
    String pin,
  ) async {
    try {
      print('Verifying PIN with token: $token');

      final response = await http
          .post(
            Uri.parse('$baseUrl/pin/verify'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'User-Agent': 'Notevia-Flutter-App',
            },
            body: jsonEncode({"pin": pin}),
          )
          .timeout(const Duration(seconds: 15));

      print('Verify PIN response status: ${response.statusCode}');
      print('Verify PIN response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'PIN verified successfully',
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message':
              jsonDecode(response.body)['message'] ?? 'PIN verification failed',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('Verify PIN ClientException: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection failed while verifying PIN',
        'error': e.toString(),
      };
    } catch (e) {
      print('Verify PIN error: ${e.toString()}');
      return {
        'success': false,
        'message': 'PIN verification error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getJournals(
    String token, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      print('Fetching journals with token: $token');

      final response = await http
          .get(
            Uri.parse('$baseUrl/journals?page=$page&limit=$limit'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'User-Agent': 'Notevia-Flutter-App',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('Journals response status: ${response.statusCode}');
      print('Journals response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Journals fetched successfully',
          'data': responseData['data'] ?? [],
          'pagination': responseData['pagination'] ?? {},
        };
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
        return {
          'success': false,
          'message': 'Authentication expired. Please login again.',
          'requires_auth_redirect': true,
        };
      } else {
        return {
          'success': false,
          'message':
              jsonDecode(response.body)['message'] ??
              'Failed to fetch journals',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('Journals ClientException: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection failed while fetching journals',
        'error': e.toString(),
      };
    } catch (e) {
      print('Journals error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Journals fetch error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      print('Fetching profile with token: $token');

      final response = await http
          .get(
            Uri.parse('$baseUrl/profiles/me'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'User-Agent': 'Notevia-Flutter-App',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('Profile response status: ${response.statusCode}');
      print('Profile response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Profile fetched successfully',
          'data': jsonDecode(response.body),
        };
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
        return {
          'success': false,
          'message': 'Authentication expired. Please login again.',
          'requires_auth_redirect': true,
        };
      } else {
        return {
          'success': false,
          'message':
              jsonDecode(response.body)['message'] ?? 'Failed to fetch profile',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('Profile ClientException: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection failed while fetching profile',
        'error': e.toString(),
      };
    } catch (e) {
      print('Profile error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Profile fetch error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getJournalById(
    String token,
    int journalId,
  ) async {
    try {
      print('Fetching journal $journalId with token: $token');

      final response = await http
          .get(
            Uri.parse('$baseUrl/journals/$journalId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'User-Agent': 'Notevia-Flutter-App',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('Journal detail response status: ${response.statusCode}');
      print('Journal detail response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Journal fetched successfully',
          'data': jsonDecode(response.body),
        };
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
        return {
          'success': false,
          'message': 'Authentication expired. Please login again.',
          'requires_auth_redirect': true,
        };
      } else {
        return {
          'success': false,
          'message':
              jsonDecode(response.body)['message'] ?? 'Failed to fetch journal',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('Journal detail ClientException: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection failed while fetching journal',
        'error': e.toString(),
      };
    } catch (e) {
      print('Journal detail error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Journal fetch error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> createJournal(
    String token,
    String title,
    String content,
    String date, {
    List<File>? imageFiles,
  }) async {
    try {
      print('Creating journal with token: $token');

      // Create multipart request for file upload
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/journals'),
      );

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'User-Agent': 'Notevia-Flutter-App',
      });

      // Add form fields with exact field names
      request.fields['title'] = title;
      request.fields['content'] = content;
      request.fields['journalDate'] = date; // Exact field name as specified

      // Add multiple image files if provided
      if (imageFiles != null && imageFiles.isNotEmpty) {
        print('Adding ${imageFiles.length} image files to request');
        for (var i = 0; i < imageFiles.length; i++) {
          var imageFile = imageFiles[i];
          print('Processing image $i: ${imageFile.path}');

          // Check if file exists
          if (!await imageFile.exists()) {
            print('ERROR: Image file does not exist: ${imageFile.path}');
            continue;
          }

          try {
            var imageStream = http.ByteStream(imageFile.openRead());
            var imageLength = await imageFile.length();
            print('Image size: $imageLength bytes');

            var multipartFile = http.MultipartFile(
              'files', // Field name for multiple files
              imageStream,
              imageLength,
              filename: imageFile.path.split('/').last,
            );
            request.files.add(multipartFile);
            print('Successfully added image $i to request');
          } catch (e) {
            print('ERROR adding image $i: $e');
          }
        }
        print('Total files in request: ${request.files.length}');
      } else {
        print('No image files provided');
      }

      // Log request details before sending
      print('--- Request Details ---');
      print('URL: ${request.url}');
      print('Method: ${request.method}');
      print('Headers: ${request.headers}');
      print('Fields: ${request.fields}');
      print('Files count: ${request.files.length}');
      for (var file in request.files) {
        print('File: ${file.field} - ${file.filename}');
      }
      print('--- End Request Details ---');

      // Send request
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      var response = await http.Response.fromStream(streamedResponse);

      print('Create journal response status: ${response.statusCode}');
      print('Create journal response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Journal created successfully',
          'data': jsonDecode(response.body),
        };
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
        return {
          'success': false,
          'message': 'Authentication expired. Please login again.',
          'requires_auth_redirect': true,
        };
      } else {
        return {
          'success': false,
          'message':
              jsonDecode(response.body)['message'] ?? 'Journal creation failed',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('Create journal ClientException: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection failed while creating journal',
        'error': e.toString(),
      };
    } catch (e) {
      print('Create journal error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Journal creation error: ${e.toString()}',
      };
    }
  }
}

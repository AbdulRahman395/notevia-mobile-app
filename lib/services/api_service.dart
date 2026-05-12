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
    String? search,
  }) async {
    try {
      print('Fetching journals with token: $token, search: $search');

      String url = '$baseUrl/journals?page=$page&limit=$limit';
      if (search != null && search.isNotEmpty) {
        url += '&search=$search';
      }

      final response = await http
          .get(
            Uri.parse(url),
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

  static Future<Map<String, dynamic>> updateProfile(
    String token, {
    String? fullName,
    String? dateOfBirth,
    String? bio,
    File? profilePicture,
  }) async {
    try {
      print('Updating profile with token: $token');

      // Create multipart request for file upload and data
      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse('$baseUrl/profiles/me'),
      );

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'User-Agent': 'Notevia-Flutter-App',
      });

      // Add only non-null fields that have been modified
      if (fullName != null) request.fields['full_name'] = fullName;
      if (dateOfBirth != null) request.fields['date_of_birth'] = dateOfBirth;
      if (bio != null) request.fields['bio'] = bio;

      // Add profile picture file if provided
      if (profilePicture != null) {
        print('Adding profile picture to update request');

        // Check if file exists
        if (!await profilePicture.exists()) {
          print(
            'ERROR: Profile picture file does not exist: ${profilePicture.path}',
          );
          return {
            'success': false,
            'message': 'Profile picture file not found',
          };
        }

        try {
          final stream = http.ByteStream(profilePicture.openRead());
          final length = await profilePicture.length();
          final multipartFile = http.MultipartFile(
            'profile_picture',
            stream,
            length,
            filename: profilePicture.path.split('/').last,
          );
          request.files.add(multipartFile);
        } catch (e) {
          print('ERROR processing profile picture: ${e.toString()}');
          return {
            'success': false,
            'message': 'Failed to process profile picture: ${e.toString()}',
          };
        }
      }

      // Send the request
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      // Get the response
      final response = await http.Response.fromStream(streamedResponse);

      print('Update profile response status: ${response.statusCode}');
      print('Update profile response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Profile updated successfully',
          'data': jsonDecode(response.body),
        };
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
        return {
          'success': false,
          'message': 'Authentication expired. Please login again.',
          'requires_auth_redirect': true,
        };
      } else if (response.statusCode == 413) {
        return {
          'success': false,
          'message': 'Profile picture is too large. Please choose a smaller image (max 2MB).',
          'error': response.body,
          'is_file_too_large': true,
        };
      } else {
        return {
          'success': false,
          'message':
              jsonDecode(response.body)['message'] ??
              'Failed to update profile',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('Update profile ClientException: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection failed while updating profile',
        'error': e.toString(),
      };
    } catch (e) {
      print('Update profile error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Profile update error: ${e.toString()}',
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

  static Future<Map<String, dynamic>> deleteJournal(
    String token,
    int journalId,
  ) async {
    try {
      print('Deleting journal $journalId with token: $token');

      final response = await http
          .delete(
            Uri.parse('$baseUrl/journals/$journalId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'User-Agent': 'Notevia-Flutter-App',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('Delete journal response status: ${response.statusCode}');
      print('Delete journal response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Journal deleted successfully'};
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
              'Failed to delete journal',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('Delete journal ClientException: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection failed while deleting journal',
        'error': e.toString(),
      };
    } catch (e) {
      print('Delete journal error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Journal deletion error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateJournal(
    String token,
    int journalId, {
    String? title,
    String? content,
    String? journalDate,
    String? mood,
    List<File>? newImageFiles,
    List<String>? imagesToDelete,
  }) async {
    try {
      print('Updating journal $journalId with token: $token');

      // Create multipart request for file upload and data
      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse('$baseUrl/journals/$journalId'),
      );

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'User-Agent': 'Notevia-Flutter-App',
      });

      // Add only non-null fields that have been modified
      if (title != null) request.fields['title'] = title;
      if (content != null) request.fields['content'] = content;
      if (journalDate != null) request.fields['journalDate'] = journalDate;
      if (mood != null) request.fields['mood'] = mood;

      // Add images to delete if any
      if (imagesToDelete != null && imagesToDelete.isNotEmpty) {
        for (int i = 0; i < imagesToDelete.length; i++) {
          request.fields['imagesToDelete[$i]'] = imagesToDelete[i];
        }
      }

      // Add new image files if provided
      if (newImageFiles != null && newImageFiles.isNotEmpty) {
        print(
          'Adding ${newImageFiles.length} new image files to update request',
        );
        for (var i = 0; i < newImageFiles.length; i++) {
          var imageFile = newImageFiles[i];
          print('Processing new image $i: ${imageFile.path}');

          // Check if file exists
          if (!await imageFile.exists()) {
            print('ERROR: Image file does not exist: ${imageFile.path}');
            continue;
          }

          try {
            final stream = http.ByteStream(imageFile.openRead());
            final length = await imageFile.length();
            final multipartFile = http.MultipartFile(
              'images',
              stream,
              length,
              filename: imageFile.path.split('/').last,
            );
            request.files.add(multipartFile);
          } catch (e) {
            print('ERROR processing image $i: ${e.toString()}');
            continue;
          }
        }
      }

      // Send the request
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      // Get the response
      final response = await http.Response.fromStream(streamedResponse);

      print('Update journal response status: ${response.statusCode}');
      print('Update journal response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Journal updated successfully',
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
              jsonDecode(response.body)['message'] ??
              'Failed to update journal',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('Update journal ClientException: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection failed while updating journal',
        'error': e.toString(),
      };
    } catch (e) {
      print('Update journal error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Journal update error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> createJournal(
    String token,
    String title,
    String content,
    String date, {
    String? mood,
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
      if (mood != null) {
        request.fields['mood'] = mood!;
      }

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

  static Future<Map<String, dynamic>> getLockPreferences(String token) async {
    try {
      print('Getting lock preferences with token: $token');

      final response = await http
          .get(
            Uri.parse('$baseUrl/lock/preferences'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'User-Agent': 'Notevia-Flutter-App',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('Get lock preferences response status: ${response.statusCode}');
      print('Get lock preferences response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Lock preferences fetched successfully',
          'data': jsonDecode(response.body),
        };
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
        return {
          'success': false,
          'message': 'Authentication expired. Please login again.',
          'requires_lock_redirect': true,
        };
      } else {
        return {
          'success': false,
          'message':
              jsonDecode(response.body)['message'] ??
              'Failed to fetch lock preferences',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('Get lock preferences ClientException: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection failed while fetching lock preferences',
        'error': e.toString(),
      };
    } catch (e) {
      print('Get lock preferences error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Lock preferences fetch error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateLockPreferences(
    String token,
    String preferences,
  ) async {
    try {
      print(
        'Updating lock preferences with token: $token, preferences: $preferences',
      );

      final response = await http
          .put(
            Uri.parse('$baseUrl/lock/preferences'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'User-Agent': 'Notevia-Flutter-App',
            },
            body: jsonEncode({"preferences": preferences}),
          )
          .timeout(const Duration(seconds: 15));

      print('Update lock preferences response status: ${response.statusCode}');
      print('Update lock preferences response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Lock preferences updated successfully',
          'data': jsonDecode(response.body),
        };
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
        return {
          'success': false,
          'message': 'Authentication expired. Please login again.',
          'requires_lock_redirect': true,
        };
      } else {
        return {
          'success': false,
          'message':
              jsonDecode(response.body)['message'] ??
              'Failed to update lock preferences',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('Update lock preferences ClientException: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection failed while updating lock preferences',
        'error': e.toString(),
      };
    } catch (e) {
      print('Update lock preferences error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Lock preferences update error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> sendHeartbeat(String token) async {
    try {
      print('Sending heartbeat with token: $token');

      final response = await http
          .get(
            Uri.parse('$baseUrl/heartbeat'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'User-Agent': 'Notevia-Flutter-App',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('Heartbeat response status: ${response.statusCode}');
      print('Heartbeat response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Heartbeat sent successfully',
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
          'message': jsonDecode(response.body)['message'] ?? 'Heartbeat failed',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('Heartbeat ClientException: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection failed while sending heartbeat',
        'error': e.toString(),
      };
    } catch (e) {
      print('Heartbeat error: ${e.toString()}');
      return {'success': false, 'message': 'Heartbeat error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> getDashboard(String token) async {
    try {
      print('Fetching dashboard with token: $token');

      final response = await http
          .get(
            Uri.parse('$baseUrl/dashboard'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'User-Agent': 'Notevia-Flutter-App',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('Dashboard response status: ${response.statusCode}');
      print('Dashboard response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Dashboard fetched successfully',
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
              jsonDecode(response.body)['message'] ??
              'Failed to fetch dashboard',
          'error': response.body,
        };
      }
    } on http.ClientException catch (e) {
      print('Dashboard ClientException: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection failed while fetching dashboard',
        'error': e.toString(),
      };
    } catch (e) {
      print('Dashboard error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Dashboard fetch error: ${e.toString()}',
      };
    }
  }
}

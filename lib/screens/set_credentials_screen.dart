import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class SetCredentialsScreen extends StatefulWidget {
  const SetCredentialsScreen({super.key});

  @override
  State<SetCredentialsScreen> createState() =>
      _SetCredentialsScreenState();
}

class _SetCredentialsScreenState
    extends State<SetCredentialsScreen> {

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController =
      TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();
  final TextEditingController _confirmController =
      TextEditingController();

  bool isLoading = false;
  bool isCheckingUsername = false;
  bool? usernameExists;
  bool hidePassword = true;
  bool hideConfirm = true;

  int? userId;
  String? firebaseUid;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();

    userId = prefs.getInt('user_id');
    firebaseUid = prefs.getString('firebase_uid');

    final savedUsername = prefs.getString('username');
    final displayName = prefs.getString('display_name');
    final email = prefs.getString('email');

    if (savedUsername != null && savedUsername.isNotEmpty) {
      _usernameController.text = savedUsername;
    } else if (displayName != null && displayName.isNotEmpty) {
      _usernameController.text =
          displayName.replaceAll(' ', '').toLowerCase();
    } else if (email != null && email.isNotEmpty) {
      _usernameController.text =
          email.split('@')[0].toLowerCase();
    }

    // Auto check availability
    if (_usernameController.text.length >= 4 &&
        userId != null) {
      _onUsernameChanged(_usernameController.text);
    }

    setState(() {});
  }
  

  void _onUsernameChanged(String value) {
    if (value.trim().length < 4 || userId == null) return;

    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    _debounce = Timer(
      const Duration(milliseconds: 400),
      () async {
        setState(() => isCheckingUsername = true);

        final result = await AuthService.checkUsername(
          username: value.trim(),
          userId: userId!,
        );

        setState(() {
          isCheckingUsername = false;
          usernameExists = result['exists'] == true;
        });
      },
    );
  }

  Future<void> _saveCredentials() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final result = await AuthService.setUsernamePassword(
      firebaseUid: firebaseUid!,
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    setState(() => isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credentials saved successfully')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Something went wrong')),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 14),
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Set Credentials',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const SizedBox(height: 10),

            const Text(
              "Create your login credentials (Optional)",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              "You only need this if you want to log in without Google.",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            

            const SizedBox(height: 24),

            /// CARD CONTAINER
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [

                    /// USERNAME
                    TextFormField(
                      controller: _usernameController,
                      onChanged: _onUsernameChanged,
                      decoration: _decoration(
                        "Username",
                        suffix: isCheckingUsername
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : usernameExists == true
                                ? const Icon(Icons.close, color: Colors.red)
                                : usernameExists == false
                                    ? const Icon(Icons.check, color: Colors.green)
                                    : null,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Username is required";
                        }
                        if (value.trim().length < 4) {
                          return "Minimum 4 characters";
                        }
                        if (usernameExists == true) {
                          return "Username already taken";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 22),

                    /// PASSWORD
                    TextFormField(
                      controller: _passwordController,
                      obscureText: hidePassword,
                      decoration: _decoration(
                        "Password",
                        suffix: IconButton(
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return "Minimum 6 characters";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 22),

                    /// CONFIRM PASSWORD
                    TextFormField(
                      controller: _confirmController,
                      obscureText: hideConfirm,
                      decoration: _decoration(
                        "Confirm Password",
                        suffix: IconButton(
                          icon: Icon(
                            hideConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              hideConfirm = !hideConfirm;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return "Passwords do not match";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            /// BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                onPressed: isLoading ? null : _saveCredentials,
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Save Credentials",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:final_project/pages/signup/signup.dart';
import 'package:final_project/services/auth_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Login extends StatelessWidget {
  Login({super.key});

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _signup(context),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        toolbarHeight: 50,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Login',
                  style: GoogleFonts.albertSans(
                      textStyle: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 32
                      )
                  ),
                ),
              ),
              _emailAddress(),
              _password(),
              const SizedBox(height: 50),
              _signin(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emailAddress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 60),
        Text(
          'Email',
          style: GoogleFonts.albertSans(
              textStyle: const TextStyle(
                  color: Colors.black,
                  fontSize: 18
              )
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
              hintStyle: const TextStyle(
                  color: Color(0xff6A6A6A),
                  fontSize: 14
              ),
              fillColor: const Color(0x86bfbfbf),
              border: OutlineInputBorder(
              )
          ),
        )
      ],
    );
  }

  Widget _password() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Password',
          style: GoogleFonts.albertSans(
              textStyle: const TextStyle(
                  color: Colors.black,
                  fontSize: 18
              )
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          obscureText: true,
          controller: _passwordController,
          decoration: InputDecoration(
              fillColor: const Color(0x86bfbfbf),
              border: OutlineInputBorder(
              )
          ),
        )
      ],
    );
  }

  Widget _signin(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xff964ddc),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        fixedSize: const Size(200, 60),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: () async {
        await AuthService().signin(
            email: _emailController.text,
            password: _passwordController.text,
            context: context
        );

      },
      child: const Text("Log In"),
    );
  }

  Widget _signup(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
              children: [
                TextSpan(
                    text: "New User? Create Account Here",
                    style: const TextStyle(
                        color: Color(0xff964ddc),
                        fontSize: 16
                    ),
                    recognizer: TapGestureRecognizer()..onTap = () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => Signup()
                        ),
                      );
                    }
                ),
              ]
          )
      ),
    );
  }
}

// Link: https://www.youtube.com/watch?v=T96Pue6ePGA&t=352s
// Description: Google font usage + sign-in/sign-up methods general structure
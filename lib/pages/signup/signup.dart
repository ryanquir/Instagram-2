import 'package:final_project/pages/login/login.dart';
import 'package:final_project/services/auth_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Signup extends StatelessWidget {
  Signup({super.key});

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        bottomNavigationBar: _signin(context),
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 50,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 16),
            child: Column(
              children: [
                Center(
                  child: Text(
                    'Create Account',
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
                _signup(context),
              ],
            ),

          ),
        )
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
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
              fillColor: const Color(0x86bfbfbf) ,
              border: OutlineInputBorder(
              )
          ),
        )
      ],
    );
  }

  Widget _signup(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xff964ddc),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        fixedSize: const Size(200, 60),
        elevation: 0,
      ),
      onPressed: () async {
        await AuthService().signup(
            email: _emailController.text,
            password: _passwordController.text,
            context: context
        );
      },
      child: const Text("Create Account"),
    );
  }

  Widget _signin(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
              children: [
                TextSpan(
                    text: "Already Have An Account? Log In Here",
                    style: const TextStyle(
                        color: Color(0xff964ddc),
                        fontSize: 16
                    ),
                    recognizer: TapGestureRecognizer()..onTap = () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => Login()
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

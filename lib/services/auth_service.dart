import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../pages/home/home.dart';
import '../pages/login/login.dart';

class AuthService {

  Future<void> signup({
    required String email,
    required String password,
    required BuildContext context
  }) async {

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password
      );

      await Future.delayed(const Duration(seconds: 1));
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (BuildContext context) => const Home()
          )
      );
    } on FirebaseAuthException catch(e) {
      String message = '';
      if (e.code == 'weak-password') {
        message = 'Use a stronger password.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists with that email.';
      } else {
        message = 'There was an issue. Make sure your email is properly formatted';
      }
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.grey,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
    catch(e){
      print('this is my error $e');
    }

  }

  Future<void> signin({
    required String email,
    required String password,
    required BuildContext context
  }) async {

    try {

      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password
      );
      await Future.delayed(const Duration(seconds: 1));
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (BuildContext context) => const Home()
          )
      );
      print("Navigation call made");

    } on FirebaseAuthException catch(e) {
      String message = '';
      if (e.code == 'user-not-found') {
        message = 'Could not find user for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is invalid.';
      } else {
        message = 'Sign-in failure: ${e.message}';
      }
      print("FirebaseAuthException: ${e.code} - ${e.message}");
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.grey,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
    catch(e){
      print('this is my error $e');
    }

  }

  Future<void> signout({
    required BuildContext context
  }) async {
    await FirebaseAuth.instance.signOut();
    await Future.delayed(const Duration(seconds: 1));
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) =>Login()
        )
    );
  }
}

// Link: https://www.youtube.com/watch?v=T96Pue6ePGA&t=352s
// Description: Help with setting up firebase authentication and exception handling
// on this file & general project structure
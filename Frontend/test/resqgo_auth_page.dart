import 'package:flutter/material.dart';

class ResQGoAuthPage extends StatefulWidget {
  @override
  _ResQGoAuthPageState createState() => _ResQGoAuthPageState();
}

class _ResQGoAuthPageState extends State<ResQGoAuthPage> {
  bool isLogin = true;
  final _formKey = GlobalKey<FormState>();
  String email = '', password = '', username = '';

  void toggleForm() => setState(() => isLogin = !isLogin);

  void submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (isLogin) {
        // Handle login logic here
        print('Login with $email and $password');
      } else {
        // Handle sign up logic here
        print('Sign up with $username, $email, and $password');
      }
      // Display success or error as needed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ResQGo'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLogin ? 'Login' : 'Sign Up',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                    SizedBox(height: 24),
                    if (!isLogin)
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Username'),
                        onSaved: (val) => username = val ?? '',
                        validator: (val) =>
                        val == null || val.isEmpty ? 'Enter username' : null,
                      ),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      onSaved: (val) => email = val ?? '',
                      validator: (val) => val != null && val.contains('@')
                          ? null
                          : 'Enter valid email',
                    ),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      onSaved: (val) => password = val ?? '',
                      validator: (val) => val != null && val.length >= 6
                          ? null
                          : 'Password must be 6+ chars',
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: submit,
                      child: Text(isLogin ? 'Login' : 'Sign Up'),
                    ),
                    TextButton(
                      onPressed: toggleForm,
                      child: Text(isLogin
                          ? 'Don\'t have an account? Sign Up'
                          : 'Already have an account? Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
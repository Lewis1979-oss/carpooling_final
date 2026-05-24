class FormValidator {
  static bool isValidEmail(String email) {
    // Improved regex to handle subdomains and modern TLDs
    return RegExp(
            r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email);
  }

  static bool isValidPassword(String password, {int minLength = 6}) {
    return password.trim().length >= minLength;
  }

  static bool isValidName(String name, {int minLength = 3}) {
    return name.trim().length >= minLength;
  }

  static bool isValidPhone(String phone, {int minLength = 10}) {
    // Handles optional + prefix and ensures at least 10 digits
    return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(phone.trim());
  }
}

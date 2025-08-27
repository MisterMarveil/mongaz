import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:toast/toast.dart';
import '../../../routes.dart';
import '../../models/api_response.dart';
import '../../models/users.dart';
import '../../services/api_service.dart';
import '../../services/mercure_service.dart';
import '../core/contants.dart';
import '../core/network_aware_wrapper.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(); // Replace with your base URL
});

// Add enum for reset password steps
enum ResetPasswordStep {
  phoneInput,
  codeVerification,
  newPassword
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetCodeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _phoneNumber = "";
  //String _resetPhoneNumber = "";
  bool _isValidPhonenumberEntered = false;
  bool _isPasswordEntered = false;
  String _countryCode = "";
  bool _showPassword = false;
  final _storage = const FlutterSecureStorage();

  bool _loading = false;
  String _error = "";

  // Reset password state variables
  bool _showResetPassword = false;
  ResetPasswordStep _resetStep = ResetPasswordStep.phoneInput;
  //bool _isValidResetCode = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _resetCodeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();

    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return; // Prevent multiple submissions

    if (!_formKey.currentState!.validate()) return;

    if(_isPasswordEntered && _isValidPhonenumberEntered) {
      setState(() {
        _loading = true;
        _error = "";
      });

      // Show the loading dialog
      _showLoadingDialog();

      try {
        final api = ref.read(apiServiceProvider);
        final User user = await api.login(
          _phoneNumber,
          _passwordController.text.trim(),
        );
        final envVars = await api.getEnvVars([
          'MAPBOX_TOKEN'
        ]);
        if(envVars['MAPBOX_TOKEN'] != null) {
          MapboxOptions.setAccessToken(envVars['MAPBOX_TOKEN']!);
        }else{
          debugPrint("failed to retrieve mapbox token. object details: ${envVars.toString()}");
        }

        final mercureService = ref.read(mercureServiceProvider);
        // Determine topics based on user role
        List<String> topics = [kSSEGeneralNotificationTopic, '$kSSESpecificUserNotificationTopic${user.id}'];
        if (user.roles.contains('ROLE_ADMIN')) {
          topics.add(kSSEAdminRoleTopic);
        } else if (user.roles.contains('ROLE_DRIVER')) {
          topics.add(kSSEDriverRoleTopic);
        }
        await mercureService.connect(topics);

        // Hide the loading dialog
        Navigator.of(context).pop();
        if (user.roles.contains('ROLE_ADMIN')) {
          Navigator.pushReplacementNamed(context, Routes.adminOrders);
        } else if (user.roles.contains('ROLE_DRIVER')) {
          Navigator.pushReplacementNamed(context, Routes.driverHome);
        } else {
          setState(() => _error = "Oops! L'utilisateur n'est ni un admin, ni un livreur");
        }
      } on DioException catch (e) {
        // Hide the loading dialog on error
        Navigator.of(context).pop();

        if(e.response?.data?["code"] == 401) {
          Toast.show("Oops! Identifiants incorrect fournis (${e.response?.data?["message"]})", duration: Toast.lengthLong,
              gravity: Toast.top);
        }

      } catch (e){
        // Hide the loading dialog on error
        Navigator.of(context).pop();
        Toast.show("Oops! something went wrong.. details: (${e.toString()})", duration: Toast.lengthLong,
            gravity: Toast.top);

      } finally {
        setState((){
          _loading = false;
          _showPassword = false;
          _phoneNumber = "";
          _countryCode = "";
          _usernameController.clear();
          _isValidPhonenumberEntered = false;
        });
      }
    }else{
      if(_error.isNotEmpty) {
        Toast.show(_error, duration: Toast.lengthLong, gravity: Toast.top);
      }else{
        Toast.show("Oops! besoin d'insérer votre numéro et mot de passe avant de vous connecter", duration: Toast.lengthLong, gravity: Toast.top);
      }
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }


  // Add reset password methods
  Future<void> _sendResetCode() async {
    setState(() {
      _loading = true;
      _error = "";
    });

    try {
      final api = ref.read(apiServiceProvider);

      //to facilitate development, we receive the code directly here, but in production, we will send the code via WhatsApp or SMS
      ApiResponse response = await api.sendResetCode(_phoneNumber);

      if(response.success) {
        setState(() {
          _resetStep = ResetPasswordStep.codeVerification;
          _loading = false;
        });
        Toast.show(
            "Code envoyé par WhatsApp", duration: Toast.lengthLong,
            gravity: Toast.top);
      }else{
        Toast.show(
            "oops! un problème est survenu pendant l'envoi du code vers whatsapp", duration: Toast.lengthLong,
            gravity: Toast.top);
      }
    } catch (e) {
      setState(() {
        _error = 'Échec envoi code: $e';
        _loading = false;
      });
    }
  }

  Future<void> _verifyResetCode() async {
    setState(() {
      _loading = true;
      _error = "";
    });

    try {
      final api = ref.read(apiServiceProvider);
      final isValid = await api.verifyResetCode(_phoneNumber, _resetCodeController.text);

      if (isValid) {
        setState(() {
          _resetStep = ResetPasswordStep.newPassword;
          _loading = false;
          //_isValidResetCode = true;
        });
      } else {
        setState(() {
          _error = 'Code invalide';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Échec vérification: $e';
        _loading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _error = 'Les mots de passe ne correspondent pas';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = "";
    });

    try {
      final api = ref.read(apiServiceProvider);
      await api.resetPassword(_phoneNumber, _newPasswordController.text);

      setState(() {
        _loading = false;
        _showResetPassword = false;
        _resetStep = ResetPasswordStep.phoneInput;
      });

      Toast.show("Mot de passe réinitialisé avec succès", duration: Toast.lengthLong, gravity: Toast.bottom);
    } catch (e) {
      setState(() {
        _error = 'Échec réinitialisation: $e';
        _loading = false;
      });
    }
  }

  void _backToLogin() {
    setState(() {
      _showResetPassword = false;
      _resetStep = ResetPasswordStep.phoneInput;
      _resetCodeController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    ToastContext().init(context);
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double logoWidth = 260;
    double logoBoxHeight = screenHeight * 0.3;
    Color generalColor = Colors.indigo;

    if(_error.isNotEmpty){
      Toast.show(_error, duration: Toast.lengthLong, gravity:  Toast.top);
    }

    return Scaffold(
      floatingActionButton: _showResetPassword
          ? _buildResetPasswordFAB(generalColor)
          : _buildLoginFAB(generalColor),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: NetworkAwareWrapper(
        showFullScreenMessage: true,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: logoBoxHeight,
                        child: Stack(
                          children: [
                            Positioned(
                              top: logoBoxHeight * 0.3,
                              left: (screenWidth / 2) - (logoWidth / 2) - 10,
                              child: Center(
                                child: Container(
                                  alignment: Alignment.center,
                                  width: logoWidth,
                                  child: Image(
                                    image: const AssetImage('assets/images/logo.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            if (_showResetPassword)
                              Positioned(
                                top: 0,
                                left: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: _backToLogin,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _showResetPassword
                          ? _buildResetPasswordForm(generalColor)
                          : _buildLoginForm(generalColor),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginFAB(Color generalColor) {
    return FloatingActionButton.extended(
      onPressed: (){
        if(_showPassword){
          _formKey.currentState?.validate();
          if(_isPasswordEntered) {
            _formKey.currentState?.save();
            _login();
          }
        } else {
          if (_isValidPhonenumberEntered) {
            _formKey.currentState?.save();
          } else {
            Toast.show("Veuillez entrer un numéro de téléphone valide",
                duration: Toast.lengthLong, gravity: Toast.top);
          }
        }
      },
      icon: const Icon(Icons.arrow_forward),
      label: Text(_showPassword ? "Se connecter" : "Continuer"),
      backgroundColor: generalColor,
      foregroundColor: Colors.white,
      elevation: 5.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
    );
  }

  Widget _buildResetPasswordFAB(Color generalColor) {
    return FloatingActionButton.extended(
      onPressed: () {
        switch (_resetStep) {
          case ResetPasswordStep.phoneInput:
            if (_isValidPhonenumberEntered) {
              _sendResetCode();
            }
            break;
          case ResetPasswordStep.codeVerification:
            if (_resetCodeController.text.length == 6) { // Assuming 6-digit code
              _verifyResetCode();
            }
            break;
          case ResetPasswordStep.newPassword:
            if (_newPasswordController.text.isNotEmpty &&
                _newPasswordController.text == _confirmPasswordController.text) {
              _resetPassword();
            }
            break;
        }
      },
      icon: const Icon(Icons.arrow_forward),
      label: Text(
          _resetStep == ResetPasswordStep.phoneInput ? "Envoyer le code" :
          _resetStep == ResetPasswordStep.codeVerification ? "Vérifier" :
          "Réinitialiser"
      ),
      backgroundColor: generalColor,
      foregroundColor: Colors.white,
      elevation: 5.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
    );
  }

  Widget _buildLoginForm(Color generalColor) {
    return Form(
        key: _formKey,
        child: Container(
          margin: const EdgeInsets.only(left: 35),
          child: Column(
            children: [
              _showPassword ? Row(
                children: [
                  Text(
                    "Tel: $_phoneNumber",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: generalColor,
                      fontFamily: 'Sora',
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                      onPressed: (){
                        setState(() {
                          _showPassword = false;
                          _isValidPhonenumberEntered = false;
                          _isPasswordEntered = false;
                          _phoneNumber = "";
                          _countryCode = "";
                          _usernameController.clear();
                        });
                      },
                      child: Text("changer", style: TextStyle(

                      ))
                  )
                ],
              ) : Text(
                "Votre numéro ?",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: generalColor,
                  fontFamily: 'Sora',
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    !_showPassword ? InternationalPhoneNumberInput(
                      hintText: "Numéro téléphone",
                      errorMessage: "Numéro invalide",
                      initialValue: PhoneNumber(isoCode: 'CM'),
                      onInputChanged: (PhoneNumber number) {
                        _phoneNumber = number.phoneNumber ?? "";
                        _countryCode = number.dialCode ?? "";
                      },
                      onInputValidated: (bool value) {
                        _isValidPhonenumberEntered = value;
                      },
                      selectorConfig: SelectorConfig(
                        selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                        useBottomSheetSafeArea: true,
                      ),
                      ignoreBlank: true,
                      autoValidateMode: AutovalidateMode.disabled,
                      selectorTextStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Sora',
                        color: Colors.black54,
                      ),
                      textFieldController: _usernameController,
                      formatInput: true,
                      keyboardType: TextInputType.numberWithOptions(signed: true, decimal: false),
                      onSaved: (PhoneNumber number) {
                        if(_isValidPhonenumberEntered) {
                          setState(() {
                            _showPassword = true;
                          });
                        }
                      },
                    ) : TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Mot de Passe",
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Le mot de passe est requis";
                        }
                        if (value.length < 6) {
                          return "Le mot de passe n'est pas correct";
                        }

                        _isPasswordEntered = true;
                        return null;
                      },
                    ),
                    _showPassword ?
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _showResetPassword = true;
                              _resetStep = ResetPasswordStep.phoneInput;
                            });
                          },
                          child: Text("Mot de passe oublié ?", style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Sora',
                          ),
                          ),
                        ),
                      ),) : const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
        )
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connexion en cours...'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildResetPasswordForm(Color generalColor) {

    return Form(
      child: Container(
        margin: const EdgeInsets.only(left: 10),
        child: Column(
          children: [
            Text(
              _resetStep == ResetPasswordStep.phoneInput ? "Réinitialiser le mot de passe" :
              _resetStep == ResetPasswordStep.codeVerification ? "Vérification du code" :
              "Nouveau mot de passe",
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 22,
                color: generalColor,
                fontFamily: 'Sora',
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_resetStep == ResetPasswordStep.phoneInput)
                    InternationalPhoneNumberInput(
                      errorMessage: "Numéro invalide",
                      initialValue: PhoneNumber(phoneNumber: _phoneNumber, isoCode: 'CM'),
                      onInputChanged: (PhoneNumber number) {
                        _phoneNumber = number.phoneNumber ?? "";
                        _countryCode = number.dialCode ?? "";
                      },
                      onInputValidated: (bool value) {
                        _isValidPhonenumberEntered = value;
                      },
                      selectorConfig: SelectorConfig(
                        selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                        useBottomSheetSafeArea: true,
                      ),
                      ignoreBlank: true,
                      autoValidateMode: AutovalidateMode.disabled,
                      selectorTextStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Sora',
                        color: Colors.black54,
                      ),
                      formatInput: true,
                      keyboardType: TextInputType.numberWithOptions(signed: true, decimal: false),
                    ),

                  if (_resetStep == ResetPasswordStep.codeVerification)
                    TextFormField(
                      controller: _resetCodeController,
                      decoration: const InputDecoration(
                        labelText: "Code de vérification",
                        prefixIcon: Icon(Icons.sms_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),

                  if (_resetStep == ResetPasswordStep.newPassword) ...[
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNewPassword,
                      decoration: InputDecoration(
                        labelText: "Nouveau mot de passe",
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureNewPassword = !_obscureNewPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Le mot de passe est requis";
                        }
                        if (value.length < 6) {
                          return "Le mot de passe doit contenir au moins 6 caractères";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: "Confirmer le mot de passe",
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value != _newPasswordController.text) {
                          return "Les mots de passe ne correspondent pas";
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
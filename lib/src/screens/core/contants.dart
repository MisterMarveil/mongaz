import 'package:flutter/material.dart';

String kSSEUrl = 'http://162.0.224.101:9000/.well-known/mercure';
String kSSESecretKey = '78c6e0cf57e0182e2ef6270175529c59d9924efb74ae1c2c92ebb502df355967';
String kSSEIssuer = 'mongaz-app';
String kSSEGeneralNotificationTopic = "mongaz:system:all";
String kSSEDriverLocationTopic = "mongaz:system:driver:location";
String kSSESpecificUserNotificationTopic = 'mongaz:system:user:';
String kSSEAdminRoleTopic = 'mongaz:system:role:ROLE_ADMIN';
String kSSEDriverRoleTopic = 'mongaz:system:role:ROLE_DRIVER';

final kPrincipalTextStyle = TextStyle(
    fontSize: 14,
    fontFamily: 'Sora',
    color: Colors.black87
);

const Color kPrimaryBarBackgroundColor = Colors.indigo;
const Color kSecondaryBarBackgroundColor = Colors.white;
const Color kSelectedMenuItemColor = Colors.white;
const Color kUnselectedMenuItemColor = Colors.white70;
const Color kMenuItemBackgroundColor = Colors.indigoAccent;
const Color kSecondaryBarActionButtonColor = Colors.indigo;


final kPrimaryBarStyle = kPrincipalTextStyle.copyWith(
    fontSize: 20,
    color: Colors.white70
);

final kSecondaryBarStyle = kPrincipalTextStyle.copyWith(
    fontSize: 16,
    color: Colors.indigoAccent
);
// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:badges/badges.dart' as badges;
import 'package:provider/provider.dart';

class NotificationBadgeWidget extends StatefulWidget {
  const NotificationBadgeWidget({
    super.key,
    this.width,
    this.height,
    required this.iconColor,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.iconSize,
  });

  final double? width;
  final double? height;
  final Color iconColor;
  final Color badgeColor;
  final Color badgeTextColor;
  final double iconSize;

  @override
  State<NotificationBadgeWidget> createState() =>
      _NotificationBadgeWidgetState();
}

class _NotificationBadgeWidgetState extends State<NotificationBadgeWidget> {
  @override
  Widget build(BuildContext context) {
    final int count =
        context.watch<FFAppState>().homePageEvents.unreadNotifications;

    return InkWell(
      onTap: () => context.pushNamed('Notifications'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: count > 0
            ? badges.Badge(
                badgeContent: Text(
                  count.toString(),
                  style: TextStyle(
                    color: widget.badgeTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                badgeStyle: badges.BadgeStyle(
                  badgeColor: widget.badgeColor,
                  shape: badges.BadgeShape.circle,
                  padding: const EdgeInsets.all(6),
                ),
                position: badges.BadgePosition.custom(top: -8, start: -8),
                child: Icon(
                  Icons.notifications_sharp,
                  size: widget.iconSize,
                  color: widget.iconColor,
                ),
              )
            : Icon(
                Icons.notifications_sharp,
                size: widget.iconSize,
                color: widget.iconColor,
              ),
      ),
    );
  }
}

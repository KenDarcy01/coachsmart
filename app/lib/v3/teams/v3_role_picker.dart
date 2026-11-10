// Bottom sheet that picks one or more roles for a new member. Used when
// approving a join request from Notifications and from the team Requests
// page. Roles are rows with role_id, role_name and role_level, shown
// players first.
import 'package:flutter/material.dart';

import '../v3_theme.dart';

/// Opens the sheet; null when dismissed, else the picked role ids.
Future<List<int>?> pickRoles(BuildContext context,
    {required List roles, required String title}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    backgroundColor: V3.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => V3RolePicker(roles: roles, title: title),
  );
}

class V3RolePicker extends StatefulWidget {
  const V3RolePicker({super.key, required this.roles, required this.title});
  final List roles;
  final String title;
  @override
  State<V3RolePicker> createState() => _V3RolePickerState();
}

class _V3RolePickerState extends State<V3RolePicker> {
  final Set<int> _picked = {};

  List<Map> get _roles {
    final l = [
      for (final r in widget.roles)
        if (r is Map) r
    ];
    l.sort((a, b) => _i(a['role_level']).compareTo(_i(b['role_level'])));
    return l;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(top: 14, bottom: 14),
                      decoration: BoxDecoration(
                          color: V3.barGrey,
                          borderRadius: BorderRadius.circular(3)))),
              Text('Approve with which roles?', style: V3.tight(20)),
              const SizedBox(height: 2),
              Text(widget.title, style: V3.inter(14, color: V3.muted)),
              const SizedBox(height: 6),
              for (final r in _roles)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: V3.green,
                  checkColor: V3.bg,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _picked.contains(_i(r['role_id'])),
                  title: Text('${r['role_name'] ?? ''}',
                      style: V3.inter(16, weight: FontWeight.w500)),
                  onChanged: (v) => setState(() => v == true
                      ? _picked.add(_i(r['role_id']))
                      : _picked.remove(_i(r['role_id']))),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                    onPressed: _picked.isEmpty
                        ? null
                        : () => Navigator.pop(context, _picked.toList()),
                    style: FilledButton.styleFrom(
                        backgroundColor: V3.green,
                        disabledBackgroundColor: V3.card2,
                        foregroundColor: V3.bg,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: Text('Confirm',
                        style: V3.inter(16,
                            weight: FontWeight.w700,
                            color: _picked.isEmpty ? V3.muted : V3.bg))),
              ),
            ]),
      ),
    );
  }

  static int _i(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
}

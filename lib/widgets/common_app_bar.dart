import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final User user;
  final VoidCallback onLogout;

  const CommonAppBar({
    super.key,
    required this.title,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.blue[600],
      elevation: 4,
      automaticallyImplyLeading: false,
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              // Icon removed as per request

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _getRoleDisplayName(user.role),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _showLogoutDialog(context),
                icon: const Icon(
                  Icons.logout,
                  color: Colors.white,
                ),
                tooltip: 'Logout',
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.user:
        return Icons.camera_alt;
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.doctor || UserRole.pg:
        return Icons.local_hospital;
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.user:
        return 'Clinic Doctor';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.doctor || UserRole.pg:
        return 'Doctor';
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              AuthService.logout();
              onLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
